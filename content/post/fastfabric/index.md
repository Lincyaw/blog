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
2. 将排序后的交易区块发送给所有的peer

orderers 收到 transaction proposal 后，会进行以下几个操作：

1. 检查 transaction proposal 是否被客户端授权
2. 如果已经授权，则将这个 transaction proposal 发送给 Kafka 集群。每个Fabric Channel 都对应着一个 Kafka topic。在 Fabric v2.0后，已经建议将 raft 作为[排序服务的底层实现](https://hyperledger-fabric.readthedocs.io/zh_CN/latest/orderer/ordering_service.html)。每个通道都在 Raft 协议的**单独**实例上运行，该协议允许每个实例选择不同的领导者。
3. 将 Kafka（raft）返回的交易序列打包成区块，并签名
4. 将区块发送给peers。可以只发送给少数的peer，其余的通过gossip协议传播。



在peer收到排序服务的消息后：

1. 解析区块头和元数据，并且检查其句法结构（syntactic  structure）。
2. 根据指定的政策验证orderers的签名。
3. 第一步验证：
   1. 解包区块
   2. 检查句法
   3. 验证背书
   4. 若上述3个没有被通过，则标记该交易为 invalid，但仍然留在区块中
4. 第二步验证
   1. 确保invalid的交易不会产生一个invalid的世界状态
   2. 确保交易的rwset中的version是相同的。如果不同，则说明之前的交易写了某个key，更新了version，从而使交易失效。这个操作防止了 double-spending的发生
5. 第三步，peer将区块写入账本，更新世界状态。
6. 最后，区块被加入到一个队列中，追加到当前的区块链中。

