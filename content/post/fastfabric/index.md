---
title: "FastFabric"
date: 2021-11-01T22:12:29+08:00
draft: false
slug: fastfabric
image: "method-draw-image.svg"
description: "改进 fabric"
categories:
    - 学习
tags: 
    - fabric
---

本节参考了 [FastFabric: Scaling Hyperledger Fabric to 20,000 Transactions per Second](https://arxiv.org/abs/1901.00910) 论文。

## 回顾

在讨论该论文对于 Fabric 的优化之前，我们先回顾一下 Fabric 的整体架构。

![](elements.png)

在 Fabric 的网络中有上图所示的几个重要的概念：peer 节点、ledger 账本、smart contrast 智能合约、orderer 排序节点、由排序节点提供的排序服务、网络、联盟、通道。

根据上一篇文章，我们可以知道 Fabric  提出的 execute-order-validation 架构的整体流程

0. 客户端发起一个 transaction proposal。

1. 背书者们（endorsers) 收到这个 proposal 后，计算这个 transaction 的读写集，对其加密，返回给客户端（proposal response）。
2. 客户端收集这些 proposal response。
3. 当满足背书条件时，会将 proposal response 发送给排序服务。
4. 排序节点将传入的 transaction 进行排序，然后将这个队列分割成区块。并将其发送给所有的 peer 节点（包括 endorser 和非 endorser）。
5. 所有的 peer 节点验证这些交易，若验证成功则提交。

![Fabric high level transaction flow](fig1.png)

下面针对 order-validate 这两个步骤详细说明：

客户端收到足够的 proposal response 后，会将 transactions 打包、签名然后发送给排序服务，包含的内容如下图所示。

![transaction proposal's content](pic3.png)

排序服务有两个职责：

1. 将这些交易排序，达成一个顺序的共识
2. 将排序后的交易区块发送给所有的 peer

orderers 收到 transaction proposal 后，会进行以下几个操作：

1. 检查 transaction proposal 是否被客户端授权
2. 如果已经授权，则将这个 transaction proposal 发送给 Kafka 集群。每个 Fabric Channel 都对应着一个 Kafka topic。在 Fabric v2.0 后，已经建议将 raft 作为 [排序服务的底层实现](https://hyperledger-fabric.readthedocs.io/zh_CN/latest/orderer/ordering_service.html)。每个通道都在 Raft 协议的**单独**实例上运行，该协议允许每个实例选择不同的领导者。
3. 将 Kafka（raft）返回的交易序列打包成区块，并签名
4. 将区块发送给 peers。可以只发送给少数的 peer，其余的通过 gossip 协议传播。

在 peer 收到排序服务的消息后：

1. 解析区块头和元数据，并且检查其句法结构（syntactic  structure）。
2. 根据指定的 policy 验证 orderers 的签名。
3. 第一步验证：
   1. 解包区块
   2. 检查句法
   3. 验证背书
   4. 若上述 3 个没有被通过，则标记该交易为 invalid，但仍然留在区块中
4. 第二步验证
   1. 确保 invalid 的交易不会产生一个 invalid 的世界状态
   2. 确保交易的 rwset 中的 version 是相同的。如果不同，则说明之前的交易写了某个 key，更新了 version，从而使交易失效。这个操作防止了 double-spending 的发生
5. 第三步，peer 将区块写入账本，更新世界状态。
6. 最后，区块被加入到一个队列中，追加到当前的区块链中。



## 前言

在 Hyperledger 中使用 BFT 共识算法的代价很高，往往会成为性能的瓶颈。因为 BFT 共识算法很难有很好的可扩展性。除此之外：

- 在许可链中没有使用BFT算法的必要。因为在许可链中参与者的身份和信息都是可知的，不会像公链中那样出现恶意节点。
- BFT 共识已经有很多人研究，在未来（论文发布于2019年）可能会有更高的吞吐量解决方案。
- Fabric v1.2 中没有使用 BFT 共识算法，而是使用了 Kafka 作为交易排序的服务。

该论文针对排序服务进行了两个优化，剩余的优化是针对 peer 的。

## Orderer的改进

### 将 transcation header 与 payload 分离

在 Fabric v1.2 中，orderers 将整个交易都发给了 Kafka 来排序。每个交易可能有好几个 KB，给网络带来了负担。但是，要使所有的交易有序只需要交易ID即可进行排序，所以一个非常显著的提升就是将原来的**发送整个交易**修改为**只发送交易ID**给Kafka集群。

orderers 在收到客户端发送的交易后，将 transaction ID 从 交易头里取出来，然后发送给 Kafka 集群。其对应的 payload 是被存储在本地的数据结构中（估计是一个哈希表，key 是 transaction ID，value 是 payload）。等Kafka集群返回 ID 后，再将两者组装起来。随后，就像原来一样，orderers将交易集分割成块，并将其交付给peer节点。这样的改进不需要对原有的架构进行修改。



### Message pipelining

在 Fabric v1.2 里，排序服务是一个一个处理客户端发来的交易的。当一个交易来的时候，识别出了它对应的channel，在通过了一系列的检查之后，会被转发到共识系统里。

类似于指令执行时大致可以分为取指、译码、执行、访存、写回 5 个步骤，可以流水线化。这里同理。

为此，我们维护一个线程池，并行处理传入的请求，每个传入的请求有一个线程。一个线程调用 Kafka API来发布交易ID，并在成功后向客户端发送一个响应。下图展示了论文对于 orderer 的优化。

![New   orderer   architecture.   Incoming   transactions   are   processedconcurrently.  Their  TransactionID  is  sent  to  the  Kafka  cluster  for  ordering.When  receiving  ordered  TransactionIDs  back,  the  orderer  reassembles  themwith their payload and collects them into blocks](fig4.png)



## Peer 的任务

一个 peer 节点有以下几个任务：

- 验证接收到的消息的合法性
- 验证块头和块中每个交易的每个背书签名
- 验证交易的读写集
- 更新 LevelDB 或 CouchDB 中的世界状态
- 使用 LevelDB 中的对应索引将区块链日志存储在文件系统中

优化的目的是尽可能地在某个交易流程上增加交易的吞吐量。论文团队观察到，首先，验证一个交易的读写集需要快速访问世界状态。 因此，我们可以通过使用内存哈希表而不是数据库来加快这一过程。

第二，交易流程中不需要区块链日志，所以我们可以在交易流程结束后将其存储到一个专门的存储和数据分析服务器上。

第三，如果一个peer节点也是一个背书节点，它需要处理新的transaction proposal。然而，committer和endorser的角色是不同的，这使得为每项任务提供不同的物理硬件成为可能。 

第四，传入的区块和事务必须在peer节点得到验证和解决。 最重要的是，通过事务写集对状态变化的验证必须按顺序进行，阻塞所有其他任务。因此，尽可能地提高这个任务的速度是很重要的。

最后，通过缓存Protocol Buffers解析块的结果可以获得显着的性能提升。总体的改进结果如下图所示：

![New  peer  architecture.  The  fast  peer  uses  an  in-memory  hash  tableto  store  the  world  state.  The  validation  pipeline  is  completely  concurrent,validating  multiple  blocks  and  their  transactions  in  parallel.  The  endorserrole and the persistent storage are separated into scalable clusters and givenvalidated  blocks  by  the  fast  peer.  All  parts  of  the  pipeline  make  use  ofunmarshaled blocks in a cache.](fig5.png)

### 将世界状态数据库替换为哈希表



### 用peer集群存储区块



### 将commitment和endorsement分离



### 并行化validation



### 缓存解析后的区块

