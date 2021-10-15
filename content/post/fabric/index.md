---
title: "初探 Fabric 架构"
date: 2021-10-15T16:04:56+08:00
draft: false
image: "method-draw-image.svg"
description: "学习 fabric 的设计理念"
categories:
    - 学习
tags: 
    - fabric
---

## 整体架构

本节参考了[Hyperledger Fabric: A Distributed Operating System for Permissioned Blockchains](https://arxiv.org/abs/1801.10228)论文。

根据官网对于 fabric 的一些定义，不难发现 fabric 与一般的构建弹性程序的方法别无二致。比如产生交易都是想要把 ledger 复制到不同的 peer 节点上，再通过一定的验证机制来保证数据的一致性和可靠性。但其实 fabric 与**普通的构建弹性程序的方法**——SMR（state-machine replication) 还是有几点区别的：

> (1) not only one, but many distributed applications run concurrently; 
>
> (2) applications may be deployed dynamically and by anyone;
>
> (3) the application code isuntrusted, potentially even malicious.

1. 复制操作可能是并发的，甚至并行的。
2. 应用可能随时随地地被任何人部署。
3. 不能完全信任应用的代码，可能会存在应用恶意攻击的可能。

现在（提出 fabric 的那几年）很多支持智能合约的区块链走的都是 SMR 的老路—— active replication: 通过一个共识的或者能够保证原子传播的协议，这个协议先将事务排序，并且发送给所有的 peer，每个 peer 按照顺序执行这些事务。（note：交易、事务都被称为 transaction，此处语境使用交易或者事务都可用）

这样的操作被称为**顺序执行架构**；它要求所有节点执行每一个事务，并且所有事务都是确定性的。市面上几乎所有的区块链项目都是基于这样的架构，这导致了几个问题：

1. 采用的共识协议被硬编码到了平台中（区块链服务可被称为一个平台，Paas）。这样的做法是非常经典的“一刀切”，没有根据实际情况来选择不同的共识协议。
2. 如上所说，交易验证的信任模型是被共识协议决定的，不能修改共识协议意味着不能同时满足不同智能合约的需求。
3. 智能合约必须用特定的编程语言编写，这会阻碍社区的发展。
4. 要求所有节点顺序执行事务导致了性能瓶颈，并且可能会引来 dos（denial-of-service) 攻击
5. 交易必须是确定性的，这在程序上可能很难保证。
6. 每个智能合约运行在所有的 peer 节点上，这与保密性产生了冲突，并且拒绝把智能合约的代码传播给这个 peer 节点的子集。

因此，fabric 设计了一个新的架构来实现 resiliency,flexibility,scalability,confidentiality（弹性、灵活性、可扩展性和保密性），允许使用标准编程语言写的智能合约代码在不同的节点上一致地执行。因此，fabric 自称为**为联盟链设计的操作系统**。

这种架构允许不被信任的代码分布式地在不被信任的环境中执行，被称为 execute-order-validate 范式。它将交易流程分为三个步骤，可以在系统中的不同实体上运行：

1. 执行交易并检查其正确性，从而为它背书(endorse)（对应其他区块链中的“交易验证”）；
2. 通过共识协议排序这些交易，而不是根据交易语义进行排序； 
3. 根据特定应用的信任假设进行交易验证，这也是为了防止并发带来的竞争。

针对复制，fabric 结合了两种主流的复制方式：被动复制和主动复制。

fabric 用的被动复制也可以被称为主从备份，在分布式数据库中非常常见，但是增加了**基于中间件的不对称更新（asymmetric update）处理**，并被移植到有拜占庭故障的不信任环境。在 fabric 中，每笔交易只需要一系列 peer 中的子集执行（背书）即可，这意味着可以并行地执行这些操作，并且解决了潜在的不确定性问题（借鉴了 execute-verify BFT 的流程）。灵活的背书策略可以适应不同的智能合约的需求，比如需要多少人来背书。

> In Fabric, every transaction is executed (endorsed) only by a subset of the peers, which allows for parallel execution and addresses potential non-determinism, draw-ing on “execute-verify” BFT replication
>
> 为什么可以解决 potential non-determinism ？

fabric 的主动复制指的是每个单独的 peer 节点会单独执行一个具有决定性的验证步骤，交易只在这次验证达成**全序范围内的共识（total order）**时才写入账本。这使得 fabric 可以根据不同的背书策略来建立不同的信任假设。