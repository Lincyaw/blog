---
title: "编程语言内存模型"
date: 2021-09-13T10:18:57+08:00
image: "cover.svg"
draft: false
slug: plmm
description: "Russ Cox 三篇内存模型文章的第二篇"
categories:
    - 学习
tags:
    - 内存模型
---

2021 年 06 月 09 日，Go 语言的父亲之一 Russ Cox 发布了 [三篇内存模型相关的推文](https://research.swtch.com/mm)，从硬件内存模型，逐步地引申到 Go 语言的内存模型。这里仅对这三篇文章进行翻译，这是第二篇，Programming Language Memory Models.

---

编程语言的内存模型回答了并行程序可以依靠什么样的行为来使其可以在其线程之间共享内存的问题。例如，考虑这个类似 C 语言的程序，其中 x 和 done 开始时都是零。

```c
// Thread 1           // Thread 2
x = 1;                while(done == 0) { /* loop */ }
done = 1;             print(x);
```

这段程序尝试通过 x 从线程 1 向线程 2 传递一条消息，使用 done 作为信号，来表示这条消息已经被接收。如果线程 1 和线程 2 各自运行在自己专用的处理器上，并且都运行结束了，这个程序能够保证打印 1 吗？编程语言模型回答了这个问题。

尽管每种编程语言在细节上有所不同，但一些通用的答案基本上适用于所有现代多线程语言，包括 C、C++、Go、Java、JavaScript、Rust 和 Swift：

* 首先，如果 x 和 done 是普通变量，那么线程 2 的循环可能永远不会停止。一个常见的编译器优化是在变量第一次使用时将其加载到寄存器中，然后尽可能长时间地重复使用该寄存器以供将来访问该变量。如果线程 2 在线程 1 执行之前将 done 复制到寄存器中，它可能会在整个循环中继续使用该寄存器，而不会注意到线程 1 后来修改了 done。

* 其次，即使线程 2 的循环确实停止了，在观察到 done == 1 之后，它仍然可能会打印出 x 为 0。编译器经常根据启发式的优化或者仅仅通过哈希表（也可以是其他的中间数据结构）在生成汇编代码的时候来重排程序的读写操作。线程 1 的编译代码可能会在 `done = 1` 之后写入 `x = 1`，或者线程 2 的编译代码可能会在循环之前就读取了 x。

现在我们了解了这个程序的问题所在，那么如何改进他呢？

现代语言以原子变量或原子操作的形式提供特殊功能，以允许程序同步其线程。如果我们把 done 变成一个原子变量（或者用原子操作来操作他），那么我们的程序一定能够既定目标：打印 1。实现变量 done 的原子化有很多要求：

* 线程 1 编译后的代码必须确保对变量 x 的写入，并且确保在写入 done 之前使对其他的线程可见这个写入 x 操作。
* 线程 2 编译后的代码在每次迭代时必须重新读取 done 的值
* 线程 2 编译后的代码必须在读完 done 之后才能读取 x
* 编译后的代码必须做一些操作来禁止重新引入上述优化的操作。（禁止编译器优化）

将 done 变量原子化后，我们就能够使这个程序按我们设想的运行，成功地将 x 的值从线程 1 传递到了线程 2。

在最开始的程序中，编译器重排代码后，线程 1 在写 x 时，线程 2 可能在读 x。这意味着存在着数据竞争。在修正后的代码里，原子变量 done 用于同步对 x 的访问，此时线程 1 不可能在线程 2 读取 x 时写入 x。因此此时是无数据竞争的。一般来说，现代语言通过保证没有数据竞争来确保顺序一致地执行代码，就好像不同线程的操作被任意地交错执行，但是没有重新排列。编程语言采用了[硬件内存模型中的 DRF-SC](https://research.swtch.com/hwmm#drf), (Data-Race-Free Sequential Consistency)。

另外，这些原子变量或原子操作更恰当地被称为 “同步原子”(synchronizing atomics)。这些操作在数据库意义下是原子的，允许同时读取和写入，就像按照某种顺序执行一样：在使用普通变量时产生的竞争不会在使用原子变量时出现。更重要的其实是原子变量同步了剩余的代码，提供了一种消除非原子变量的数据竞争的办法。

编程语言内存模型指定了程序员和编译器所需内容的确切细节。上面概述的一般特征基本上适用于所有现代语言，但直到最近大家才达成了这个共识。而在 2000 年代初期，在这方面的讨论更是五花八门，即使在今天，仍有非常多的关于 second-order 的讨论：

* 原子变量本身的排序是通过什么保证的？
* 原子操作和非原子操作都可以访问变量吗?
* 除了原子之外还有同步机制吗？
* 是否有不能同步的原子操作？
* 对于有竞态的程序可以保证同步吗？

在进行了上述的准备之后，本文的其余部分将研究不同的语言如何回答这些问题和相关问题，以及它们达到目标的方法。本文还强调了历史上出现的一些错误，以强调我们的学习中，哪些是有效的，哪些是无效的。

## Hardware, Litmus Tests, Happens Before, and DRF-SC

在我们了解任何特定语言的细节之前，先简要总结一下我们需要牢记的[硬件内存模型](../hdmm)的经验教训。

不同的体系结构允许不同数量的指令重新排序，因此在多个处理器上并行运行的代码可以根据体系结构获得不同的允许结果。限制最强的标准是[顺序一致性](../hdmm/#顺序一致性-sequential--consistency)，其中任何执行都必须表现得就像在不同处理器上执行的程序只是以某种顺序交错到单个处理器上一样。对于开发人员来说，该模型更容易推理，但由于较弱的保证实现了性能提升，因此今天没有重要的架构实现了它。

比较不同的内存模型很难做出完全一般的陈述。相反，它可以帮助专注于特定的测试用例，称为石蕊测试 (Litmus Tests)。如果两个内存模型允许给定的试金石测试有不同的行为，这证明它们是不同的。并且通常可以帮助我们了解，至少对于那个测试用例，一个比另一个弱还是强。例如，这里是我们之前检查过的程序的试金石：

```c
Litmus Test: Message Passing
Can this program see r1 = 1, r2 = 0?

// Thread 1           // Thread 2
x = 1                 r1 = y
y = 1                 r2 = x

On sequentially consistent hardware: no.
On x86 (or other TSO): no.
On ARM/POWER: yes!
In any modern compiled language using ordinary variables: yes!
```

和上一篇文章一样，我们假设每个示例都以所有共享变量设置为零开始。名称 rN 表示私有存储，如寄存器或函数局部变量；其他名称如 x 和 y 是不同的共享（全局）变量。我们询问在执行结束时是否可以进行特定的寄存器结果。在回答硬件的试金石测试时，我们假设没有编译器来重新排序线程中发生的事情：程序中的指令直接转换为提供给处理器执行的汇编指令。

结果 r1 = 1, r2 = 0 对应于原始程序的线程 2 完成其循环（done 就是 y）但随后打印 0。在程序操作的任何顺序一致交错中，此结果是不可能的。对于汇编语言版本，无法在 x86 上打印 0，但由于处理器本身的重新排序优化，在更宽松的架构（如 ARM 和 POWER）上可以打印 0。在现代语言中，编译期间可能发生的重新排序使这种结果成为可能，无论底层硬件是什么。

正如我们之前提到的，今天的处理器并没有保证顺序一致性，而是保证了一种称为 “data-race-free sequential-consistency” 或 DRF-SC（有时也称为 SC-DRF）的属性。
保证 DRF-SC 的系统必须定义称为同步指令的特定指令，这些指令提供了一种协调不同处理器（相当于线程）的方法。程序使用这些指令在一个处理器上运行的代码和另一个处理器上运行的代码之间创建一种 “发生在之前” 的关系。

例如，这里描述了一个程序在两个线程上的短暂执行；像往常一样，假设每个都在自己的专用处理器上：

![](pic1.png)

我们在上一篇文章中也看到了这个程序。线程 1 和线程 2 执行同步指令 S(a)。在程序的这个特定执行中，两条 S(a) 指令建立了从线程 1 到线程 2 的先发生关系，因此线程 1 中的 W(x) 发生在线程 2 中的 R(x) 之前。

不同处理器上的两个未按 happens-before 排序的事件可能同时发生：** 确切的顺序不清楚 **。我们说它们是并发执行的。数据竞争是指对变量的写入与对同一变量的读取或另一次写入同时执行。提供 DRF-SC 的处理器（现在所有这些处理器）保证没有数据竞争的程序的行为就像它们在顺序一致的架构上运行一样。这是使在现代处理器上编写正确的多线程汇编程序成为可能的基本保证。

正如我们之前看到的，DRF-SC 也是现代语言采用的基本保证，可以用更高级别的语言编写正确的多线程程序。

## Compilers and Optimizations

我们已经多次提到编译器可能会在生成最终可执行代码的过程中对输入程序中的操作重新排序。让我们仔细看看这个方面以及可能导致问题的其他优化。

人们普遍认为，编译器可以几乎任意地对普通的内存读取和写入重新排序，前提是重新排序不能改变观察到的代码单线程执行。例如，考虑这个程序：

```c
w = 1
x = 2
r1 = y
r2 = z
```

由于 w、x、y 和 z 都是不同的变量，因此这四个语句可以按编译器认为最佳的任何顺序执行。

正如我们上面提到的，如此自由地重新排序读取和写入的能力使得普通编译程序的保证至少与 ARM/POWER 宽松内存模型一样弱，因为编译程序未能通过试金石测试的消息。事实上，编译程序的保证更弱。

在硬件文章中，我们将一致性视为 ARM/POWER 架构确实保证的一个例子：

```c
Litmus Test: Coherence
Can this program see r1 = 1, r2 = 2, r3 = 2, r4 = 1?
(Can Thread 3 see x = 1 before x = 2 while Thread 4 sees the reverse?)

// Thread 1    // Thread 2    // Thread 3    // Thread 4
x = 1          x = 2          r1 = x         r3 = x
                              r2 = x         r4 = x

On sequentially consistent hardware: no.
On x86 (or other TSO): no.
On ARM/POWER: no.
In any modern compiled language using ordinary variables: yes!
```

所有现代硬件都保证一致性，也可以将其视为单个内存位置上操作的顺序一致性。在这个程序中，一个写入必须覆盖另一个，整个系统必须就哪个是哪个达成一致。事实证明，由于编译期间程序重新排序，现代语言甚至不提供一致性。

假设编译器对线程 4 中的两次读取重新排序，然后指令就好像按此顺序交错运行一样：

```c
// Thread 1    // Thread 2    // Thread 3    // Thread 4
                                             // (reordered)
(1) x = 1                     (2) r1 = x     (3) r4 = x
               (4) x = 2      (5) r2 = x     (6) r3 = x
```

结果是 r1 = 1, r2 = 2, r3 = 2, r4 = 1，这在汇编程序中是不可能的，但在高级语言中是可能的。从这个意义上说，编程语言内存模型都比最宽松的硬件内存模型弱。

但是有一些保证。每个人都同意需要提供 DRF-SC，它不允许引入新读取或写入的优化，即使这些优化在单线程代码中是有效的。

例如，考虑以下代码：

```c
if(c) {
	x++;
} else {
	... lots of code ...
}
```

有一个 if 语句，在 else 中有很多代码，而在 if 主体中只有一个 x++。拥有更少的分支并完全消除 if 代价可能会更少。我们可以通过在 if 之前运行 x++ 来做到这一点，如果我们错了，然后在大的 else 主体中使用 x-- 进行调整。也就是说，编译器可能会考虑将该代码重写为：

```c
x++;
if(!c) {
	x--;
	... lots of code ...
}
```

这是一个安全的编译器优化吗？在单线程程序中，是的。在多线程程序中，当 c 为 false 时 x 与另一个线程共享，就不是了：优化将在 x 上引入原始程序中不存在的竞争。

这个例子源自 Hans Boehm 2004 年的论文 “[Threads Cannot Be Implemented As a Library](https://www.hpl.hp.com/techreports/2004/HPL-2004-209.pdf)” 中的一个，这说明语言不能对多线程执行的语义保持沉默。

编程语言内存模型试图准确回答这些问题，哪些优化是允许的，哪些是不允许的。通过检查过去几十年尝试编写这些模型的历史，我们可以了解哪些有效，哪些无效，并了解事情的发展方向。

## Original Java Memory Model (1996)

Java 是第一个尝试写下它对多线程程序的保证的主流语言。它包括了 mutexes 并定义了它们所隐含的内存排序要求。它还包括了 "易失的" 原子变量：易失性变量的所有读写都需要直接在主内存中按程序顺序执行，使易失性变量的操作以顺序一致的方式进行。最后，Java 还规定了（或至少试图规定）有数据竞争的程序的行为。其中的一部分是为普通变量规定了一种一致性的形式，我们将在下文中进一步研究。不幸的是，在第一版的[《Java 语言规范》](http://titanium.cs.berkeley.edu/doc/java-langspec-1.0.pdf)（1996）中，这种尝试至少有两个严重的缺陷。事后看，用我们已经定下的预案的话，这些缺陷很容易解释。在当时，这些缺陷却不那么明显。

### Atomics need to synchronize

第一个缺陷是 volatile 原子变量是非同步的，因此它们无助于消除程序其余部分中的竞争。我们上面看到的消息传递程序的 Java 版本是：

```java
int x;
volatile int done;

// Thread 1           // Thread 2
x = 1;                while(done == 0) { /* loop */ }
done = 1;             print(x);
```

因为 done 被声明为 volatile，所以循环保证完成：编译器不能将它缓存在寄存器中并导致无限循环。但是，程序不能保证打印 1。编译器没有被禁止对 x 和 done 的访问重新排序，也没有被要求禁止硬件做同样的事情。

由于 Java volatile 是非同步原子，因此您无法使用它们来构建新的同步原语。从这个意义上说，原始的 Java 内存模型太弱了。

### Coherence is incompatible with compiler optimizationsCoherence

原始的 Java 内存模型限制性太强了：强制一致性，这意味着一旦线程读取了内存位置的新值，它以后似乎无法读取旧值——不允许基本的编译器优化。之前我们研究了重新排序读取如何破坏一致性，但您可能会想，好吧，只要不是重新排序读取就能保证不破坏一致性。这里有另一种更微妙的优化方式，但可能会破坏一致性：公共子表达式消除。

考虑这个 Java 程序：

```java
// p and q may or may not point at the same object.
int i = p.x;
// ... maybe another thread writes p.x at this point ...
int j = q.x;
int k = p.x;
```

在这个程序中，公共子表达式消除会注意到 p.x 计算了两次并将最后一行优化为 k = i。但是如果 p 和 q 指向同一个对象并且另一个线程在读取 i 和 j 之间写入 p.x，那么将旧值 i 重用于 k 违反了一致性：读取 i 看到了旧值，读取 j 看到了 a 较新的值，但随后读入 k 重用 i 将再次看到旧值。无法优化掉冗余读取会妨碍大多数编译器，使生成的代码变慢。

硬件比编译器更容易提供一致性，因为硬件可以动态优化：它可以根据给定的内存读取和写入序列中涉及的确切地址调整优化路径。相比之下，编译器只能应用静态优化：他们必须提前写出一个指令序列，无论涉及什么地址和值，它都是正确的。在示例中，编译器无法根据 p 和 q 是否碰巧指向同一个对象来轻松更改所发生的情况，至少在不为这两种可能性编写代码的情况下无法更改，从而导致大量的时间和空间开销。编译器对内存位置之间可能存在的别名的不完整信息意味着实际提供一致性将需要放弃基本的优化。

Bill Pugh 在 1999 年的论文 “[Fixing the Java Memory Model](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.17.7914&rep=rep1&type=pdf)” 中发现了这个问题和其他问题。

## New Java Memory Model (2004)

由于这些问题，原始的 Java 内存模型即使是专家也难以理解，Pugh 和其他人开始努力为 Java 定义一个新的内存模型。该模型称为 JSR-133，并在 2004 年发布的 Java 5.0 中采用。规范参考是 Jeremy Manson、Bill Pugh 和 Sarita Adve 撰写的 “[The Java Memory Model](http://rsim.cs.uiuc.edu/Pubs/popl05.pdf)”（2005 年），[Manson 博士的论文](https://drum.lib.umd.edu/bitstream/handle/1903/1949/umi-umd-1898.pdf;jsessionid=4A616CD05E44EA7D47B6CF4A91B6F70D?sequence=1)。新模型遵循 DRF-SC 方法：保证无数据竞争的 Java 程序以顺序一致的方式执行。

### Synchronizing atomics and other operations

正如我们之前看到的，为了编写一个无数据竞争的程序，程序员需要可以建立发生前面的同步操作，以确保一个线程不会在另一个线程读取或写入它的同时写入非原子变量。在 Java 中，主要的同步操作有：

* 线程的创建发生在线程中的第一个操作之前。
* 互斥锁 m 的解锁发生在 m 的任何 ** 后续 ** 加锁之前。
* 对 volatile 变量 v 的写入发生在对 v 的任何 ** 后续 ** 读取之前。

“后续” 是什么意思？ Java 定义所有锁定、解锁和 volatile 变量访问的行为就好像它们以某种顺序一致的交错方式发生，从而给出整个程序中所有这些操作的总顺序。 “后续” 是指在该总顺序中的较晚。即：加锁、解锁和 volatile 变量访问的总顺序定义了 “后续” 的含义，然后 “后续” 定义了某些特定语句的执行创建了哪些发生之前，发生之前定义了该特定执行是否具有数据竞争。如果没有竞争，则执行以顺序一致的方式运行。

访问 volatile 变量必须像在某种全序中一样，这一事实意味着在存储缓冲区试金石测试中，您不能以 r1 = 0 和 r2 = 0 结束：

```c
Litmus Test: Store Buffering
Can this program see r1 = 0, r2 = 0?

// Thread 1           // Thread 2
x = 1                 y = 1
r1 = y                r2 = x

On sequentially consistent hardware: no.
On x86 (or other TSO): yes!
On ARM/POWER: yes!
On Java using volatiles: no.
```

在 Java 中，对于 volatile 变量 x 和 y，读和写不能重新排序：一个写必须排在第二位，而且第二个写之后的读必须看到第一个写。如果我们没有顺序一致的要求 -- 比如说，只要求易失性是一致的，那么两个读可能会错过写。

这里有一个重要但微妙的观点：所有同步操作的总顺序与 "在 xx 之前发生" 的关系是分离的。在程序中的每一个加锁、解锁或易失性变量访问之间，并不是真的有一条发生在 "之前的边"(happen-before edge, 意为区分前后)：你只得到一条发生在之前的边，从一个写到观察到这个写的读。例如，不同 mutex 的锁和解锁之间没有这样的边，不同变量的易失性访问也没有，尽管这些操作总体上都表现得像遵循一个顺序一致的交错执行。

### Semantics for racy programs

DRF-SC 只保证没有数据竞赛的程序的顺序一致行为。新的 Java 内存模型和原来的一样，定义了竞态程序的行为，原因有很多。

* 为了支持 Java 的一般安全性和安全保证。
* 为了使程序员更容易发现错误。
* 使攻击者更难利用问题，因为由于竞态而可能造成的损害更加有限。
* 让程序员更清楚他们的程序是干什么的。

新的模型不再依赖一致性，而是重新使用 happens-before 关系（已经用于决定程序是否有竞态）来决定竞争性读写的结果。

Java 的具体规则是，对于字大小或更小的变量，对一个变量（或字段）x 的读取必须看到对 x 的某个单一写所存储的值。对 x 的 w 可以被一个读 r 观察到，只要 r 不发生在 w 之前。这意味着 r 可以观察在 r 之前发生的写入（但在 r 之前也不会被覆盖），并且它可以观察与 r 竞争的 w。

以这种方式使用 happen-before，再加上可以建立新的 happen-before 边的同步原子（volatiles），是对原始 Java 内存模型的一个重大改进。它为程序员提供了更有用的保证，并使大量重要的编译器优化得到了明确的允许。这项工作仍然是现在 Java 的内存模型要做的事。也就是说，它也仍然不完全正确：这种使用 happens-before 来试图定义竞态程序的语义的做法有问题。

### Happens-before does not rule out incoherence

happens-before 的第一个问题是定义的程序语义有连贯性（coherence）方面的问题。(下面的例子来自 Jaroslav Ševčík 和 David Aspinall 的论文 “[On the Validity of Program Transformations in the Java Memory Model”（2007）](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.112.1790&rep=rep1&type=pdf))。

这里有一个有三个线程的程序。我们假设线程 1 和线程 2 已知在线程 3 开始之前完成。

```java
// Thread 1           // Thread 2           // Thread 3
lock(m1)              lock(m2)
x = 1                 x = 2
unlock(m1)            unlock(m2)
                                            lock(m1)
                                            lock(m2)
                                            r1 = x
                                            r2 = x
                                            unlock(m2)
                                            unlock(m1)
```

线程 1 在持有 mutex m1 的同时写下 x = 1。线程 2 写 x = 2，同时持有 mutex m2。m1 和 m2 是不同的互斥锁，所以这个写法是有竞争的。在这个程序中，只有线程 3 读取 x，而且是在获得了两个 mutex 之后。对 r1 的读可以读取任何一个写：这两个写都发生在它之前，而且都没有明确地说是哪个写操作覆盖另一个。根据同样的论点，读到 r2 的时候可以读到任何一个写。但是严格来说，在 Java 内存模型中没有任何东西说这两个读必须是一致的：r1 和 r2 可以在读取不同的 x 值后离开。当然，没有真正的实现会产生不同的 r1 和 r2，互斥锁的相互排斥意味着在这两个 read 之间不会发生任何 write 操作。他们必须得到相同的值。但是，内存模型允许不同的读 (两次读到不同的值)，这一事实表明，在某种技术上，它并没有精确地描述真实的 Java 实现。

如果我们在这两个读数操作之间再加一条指令，x = r1，会怎样呢？

```java
// Thread 1           // Thread 2           // Thread 3
lock(m1)              lock(m2)
x = 1                 x = 2
unlock(m1)            unlock(m2)
                                            lock(m1)
                                            lock(m2)
                                            r1 = x
                                            x = r1   // !?
                                            r2 = x
                                            unlock(m2)
                                            unlock(m1)
```

现在，显然 r2=x 的读取必须使用 x=r1 所写的值，所以程序必须在 r1 和 r2 中得到相同的值。现在两个值 r1 和 r2 被保证是相等的。

这两个程序之间的差异意味着一个编译器需要处理的问题。编译器在看到 r1=x 和 x=r1 之后，很可能想删除第二个赋值，因为它 "显然" 是多余的。但是这种 "优化" 将第二个程序（它必须在 r1 和 r2 中看到相同的值）变成了第一个程序，从技术上讲，它的 r1 与 r2 是不同的。因此，根据 Java 内存模型，这种优化在技术上是无效的：它 ** 改变了程序的意义 **。说白了，这种优化不会改变在任何你能想象到的真实 JVM 上执行的 Java 程序的意义。但不知何故，Java 内存模型不允许这样做，这表明还有更多需要说明的地方。

关于这个例子和其他例子的更多信息，请参见 Ševčík and Aspinall 的论文

### Happens-before does not rule out acausality

最后一个例子被证明是一个简单的问题。这里有一个更难的问题，考虑一下这个试金石测试，使用普通的（non volatile）Java 变量。

```java
Litmus Test: Racy Out Of Thin Air Values
Can this program see r1 = 42, r2 = 42?

// Thread 1           // Thread 2
r1 = x                r2 = y
y = r1                x = r2

(Obviously not!)
```

这个程序中的所有变量一开始都是零，就像往常一样，然后这个程序在一个线程中有效地运行 y=x，在另一个线程中运行 x=y。x 和 y 最终会是 42 吗？在现实生活中，显然不能。但为什么不能呢？事实证明，内存模型并不允许这种结果。

假设 "r1 = x" 确实读取了 42。然后 "y = r1" 会把 42 写入 y，然后竞态的 "r2 = y" 可以读取 42 ，导致 "x = r2" 把 42 写入 x，而这个写入与原来的 "r1 = x" 竞争（因此可以观察到），似乎证明了原来的假设。在这个例子中，42 被称为空中楼阁，因为它的出现没有任何理由，但随后用循环逻辑为自己辩护。如果内存在当前的 0 之前曾有一个 42，而硬件错误地推测它仍然是 42，那会怎样？这种猜测可能会成为一个自圆其说的预言。(在 [Spectre 和相关攻击](https://spectreattack.com/)表明硬件的猜测有多么积极之前，这种说法似乎更加牵强。即便如此，也没有哪个硬件会以这种方式发明空穴来风的数值）。)

这个程序不可能在 r1 和 r2 设置为 42 的情况下结束似乎看起来很正常，但是  happens-before 本身并没有解释为什么这不可能发生。这再次表明这个理论存在着某种不完整性。新的 Java 内存模型花了很多时间来解决这种不完整性，关于这一点，很快就会有答案。

这个程序有一个竞争 -- x 和 y 的读取与其他线程的写入竞争，所以我们可能会回过头来争论说这是一个不正确的程序。但这里有一个无数据竞争的版本。

```java
Litmus Test: Non-Racy Out Of Thin Air Values
Can this program see r1 = 42, r2 = 42?

// Thread 1           // Thread 2
r1 = x                r2 = y
if (r1 == 42)         if (r2 == 42)
    y = r1                x = r2

(Obviously not!)
```

由于 x 和 y 开始时是零，任何顺序一致的执行都不会执行写，所以这个程序没有写操作，所以没有数据竞争。不过，仅仅是 happens-before 并不能排除这样的可能性：假设 r1=x 看到了竞态，而没有去写 r1，然后从这个假设出发，条件最后都是真的，x 和 y 在最后都是 42。这是另一种无中生有的情况，但这次是在一个没有数据竞争的程序中。任何保证 DRF-SC 的模型都必须保证这个程序在最后只看到所有的零，然而 happens-before 并没有解释为什么。

Java 内存模型花了很多篇幅在这上面，试图排除这类无因假设的情况。不幸的是，五年后，Sarita Adve 和 Hans Boehm 对这项工作有这样的评价。

> 禁止这种违反因果关系的行为，同时又不禁止其他想要的优化，结果是出乎意料的困难。... 经过许多建议和五年的激烈辩论，目前的模型被认为是最好的折衷方案。不幸的是，这个模型非常复杂，已知有一些令人惊讶的行为，而且最近被证明有一个错误。

(Adve and Boehm, [“Memory Models: A Case For Rethinking Parallel Languages and Hardware, ” August 2010](https://cacm.acm.org/magazines/2010/8/96610-memory-models-a-case-for-rethinking-parallel-languages-and-hardware/fulltext))

## C++11 Memory Model (2011)

让我们把 Java 放在一边，研究一下 C++。受到 Java 新内存模型明显成功的启发，许多人开始为 C++ 定义类似的内存模型，最终在 C++11 中被采用。 与 Java 相比，C++ 在两个重要方面有所不同。首先，C++ 对有数据竞争的程序完全没有保证，这似乎消除了 Java 模型的大部分复杂性。其次，C++ 提供了三种原子学：强同步（"sequentially consistent"）、弱同步（"acquire/release"，仅有一致性）和无同步（"relaxed"，用于隐藏数据竞争）。relaxed atomics 重新引入了 Java 定义等价竞态程序的复杂性。其结果是，C++ 模型比 Java 模型更复杂，但对程序员的帮助更小。

C++11 也定义了 atomic fences 作为 atomic variables 的替代，但它们并不常用，我不打算讨论它们。

### DRF-SC or Catch Fire

与 Java 不同，C++ 对有数据竞争的程序没有任何保证。任何带有竞争的程序都属于 "undefined behavior"。在程序执行的最初几微秒内的数据竞争被允许在数小时或数天后引起任意的 "undefined behavior"。这通常被称为 “DRF-SC or Catch Fire”：如果程序是无数据竞争的，它就会以顺序一致的方式运行；如果不是，它可以做任何事情。

关于 DRF-SC 或 Catch Fire 的论点的较长介绍，见 Boehm，“[Memory Model Rationales](http://open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2176.html#undefined)” (2007) 以及 Boehm and Adve, “[Foundations of the C++ Concurrency Memory Model](https://www.hpl.hp.com/techreports/2008/HPL-2008-56.pdf)” (2008).

简而言之，这一立场有四个共同的理由。

* C 和 C++ 已经充斥着各种 undefined behavior，编译器的优化肆意妄为，用户最好不要乱来，否则。多一个又有什么坏处呢？
* 现有的编译器和库是在不考虑线程的情况下编写的，可能会以任意的方式破坏竞态程序。要找到并修复所有的问题太难了，或者说，不清楚那些未修复的编译器和库是如何处理 relaxed atomics 的。
* 真正知道自己在做什么并想避免 undefined behavior 的程序员可以使用 relaxed atomics。
* 不定义竞态语义，可以让执行者检测和诊断出竞态，并停止执行。

就我个人而言，最后一个理由是我认为唯一有说服力的理由，尽管我认为 "允许使用数据竞争检测器" 和 "一个整数的数据竞争让整个程序失效" 只能取其中之一。

这里有一个来自 "Memory Model Rationales" 的例子，我认为它抓住了 C++ 方法的本质以及它的问题。考虑一下这个程序，它提到了一个全局变量 x。

```c++
unsigned i = x; 

if (i < 2) {

	foo: ...
	switch (i) {
	case 0:
		...;
		break;
	case 1:
		...;
		break;
	}

}

```

C++ 编译器可能将 i 保存在一个寄存器中，但是如果标签 foo 处的代码很复杂的话，就可能需要重新使用这些寄存器。编译器可能不会将 i 的当前值存到函数栈中，而是决定在到达 switch 语句时从全局 x 中第二次加载 i。其结果是，在 if 主体的中途，i<2 可能会停止为真。如果编译器做了一些事情，比如将 switch 编译成一个使用 i 索引的表格来计算跳转，那么这段代码将索引到表格之外，并跳转到一个意外的地址，这可能是相当糟糕的。

从这个例子和其他类似的例子中，C++ 内存模型的作者得出结论，必须允许任何竞争访问对程序的未来执行造成无限制的破坏。我个人的结论是，在一个多线程程序中，编译器不应该假定他们可以通过重新执行初始化 i 的内存读取来重新加载一个局部变量。指望现有的为单线程世界编写的 C++ 编译器发现并修复像这样的代码生成问题很可能是不切实际的，但在新语言中，我认为我们应该有更高的目标。

### Digression: Undefined behavior in C and C++

顺便说一句，C 和 C++ 坚持编译器有能力对程序中的 bug 做出任意恶劣的行为，这导致了真正荒谬的结果。例如，考虑这个程序，它是 [2017 年 Twitter](https://twitter.com/andywingo/status/903577501745770496) 上的一个讨论话题：

```c++
#include <cstdlib>

typedef int (*Function)();

static Function Do;

static int EraseAll() {
	return system("rm -rf slash");
}

void NeverCalled() {
	Do = EraseAll;
}

int main() {
	return Do();
}
```

如果你是一个像 Clang 这样的现代 C++ 编译器，你可能会对这个程序进行如下思考。

* 在 main 中，显然 Do 不是 null 就是 EraseAll 。
* 如果 Do 是 EraseAll，那么 Do() 和 EraseAll() 是一样的。
* 如果 Do 是空的，那么 Do() 就是未定义的行为，我可以随心所欲地实现它，包括无条件地变成 EraseAll()。
* 因此，我可以将间接调用 Do() 优化为直接调用 EraseAll()。
* 在这里，我也可以内联 EraseAll。

最终的结果是，Clang 将程序优化到了。

```c++
int main() {

	return system("rm -rf slash");

}

```

你必须承认：在 Memory Model Rationales 这个例子里，局部变量 i 可能在 if(i < 2) 的中途突然停止小于 2，这似乎并不是不合理的。

从本质上讲，现代 C 和 C++ 编译器假定没有程序员敢于尝试 undefined behavior。一个程序员写了一个有错误的程序？[难以想象!](https://www.youtube.com/watch?v=qhXjcZdk5QQ)（译者注：C++ 将所有的信任都交给了程序员）

### Acquire/release atomics

C++ 采用了顺序一致的原子变量，很像（新）Java 的 volatile 变量（与 C++ 的 volatile 没有关系）。在我们的消息传递例子中，我们可以声明为

```c++
atomic<int> done;
```

然后像在 Java 中一样，把 done 当作一个普通的变量来使用。或者我们可以声明一个普通的 `int done;` 然后用

```c++
atomic_store(&done, 1); 

while(atomic_load(&done) == 0) { /* loop */ }

```

去访问他。无论哪种方式，对所做的操作都会保持原子操作上的顺序一致的全序，并同步程序的其他部分。

C++ 还增加了较弱的 atomics，可以使用 `atomic_store_explicit` 和 `atomic_load_explicit` 来访问，并增加一个内存排序参数。使用 `memory_order_seq_cst` 使得显式调用等同于上面的短调用。

weaker atomics 被称为 acquire/release atomics，其中一个被后来的 acquire 观察到的 release 创造了一个从 acquire 到 release 的 happens-before 边。这个术语是为了唤起 mutex：release 就像解锁一个 mutex，而 acquire 就像锁定同一个 mutex。在 release 之前执行的写必须对随后的 acquire 之后执行的读可见，就像在解锁一个 mutex 之前执行的写必须对后来锁定同一 mutex 之后执行的读可见。

为了使用 weaker atomics，我们可以改变我们的消息传递的例子，使用

```c++
atomic_store(&done, 1, memory_order_release);

while(atomic_load(&done, memory_order_acquire) == 0) { /* loop */ }
```

而且它仍然是正确的。但不是所有的程序都会这样。

回顾一下，顺序一致的 atomics 要求程序中所有 atomics 的行为是全序一致的。而 Acquire/release atomics 则不需要。它们只需要对单个内存位置的操作进行顺序上一致的交错。也就是说，它们只需要一致性。其结果是，一个用了 Acquire/release atomics 的程序如果执行了多个内存位置的观测，则可能会看到一个并不是顺序一致的行为，可以说违反了 DRF-SC。

为了说明区别，这里再举一个存储缓冲区的例子。

```c++
Litmus Test: Store Buffering
Can this program see r1 = 0, r2 = 0?

// Thread 1           // Thread 2
x = 1                 y = 1
r1 = y                r2 = x

On sequentially consistent hardware: no.
On x86 (or other TSO): yes!
On ARM/POWER: yes!
On Java (using volatiles): no.
On C++11 (sequentially consistent atomics): no.
On C++11 (acquire/release atomics): yes!

```

C++ 的顺序一致 atomics 与 Java 的 volatile 相匹配。但是 Acquire/release atomics 在 x 的排序和 y 的排序之间没有任何关系。而且其允许程序表现出好像 r1 = y 发生在 y = 1 之前，而同时 r2 = x 发生在 x = 1 之前，允许 r1 = 0，r2 = 0，这与整个程序的顺序一致性相矛盾。这些可能只是因为它们在 x86 上是自由存在的。

需要注意的是，对于一组特定的读操作，来观测一组写操作，C++ 的顺序一致 atomics 和 C++ 的 Acquire/release atomics 会创建相同的 happens-before 边界。这两者的区别是一部分的读观测写操作在顺序一致的要求中是不被允许的。比如在 store buffering 测试中，`r1=0, r2=0` 这个结果是不被允许的。

### A real example of the weakness of acquire/release

与提供顺序一致性的 atomics 相比，Acquire/release atomics 在实践中的作用较小。这里有一个例子。假设我们有一个新的同步原语，即一个具有两个方法 Notify 和 Wait 的单用途条件变量。为了简单起见，只有一个线程会调用 Notify，只有一个线程会调用 Wait。我们想安排 Notify 在另一个线程还没有等待时是无锁的。我们可以用一对原子整数来做到这一点。

```c++
class Cond {
	atomic<int> done;
	atomic<int> waiting;
	...
};

void Cond::notify() {
	done = 1;
	if (!waiting)
		return;
	// ... wake up waiter ...
}

void Cond::wait() {
	waiting = 1;
	if(done)
		return;
	// ... sleep ...
}
```

这段代码的重要部分是，notify 在检查 waiting 之前设置了 done，而 wait 在检查 done 之前设置了 waiting，所以对 notify 和 wait 的并发调用不能导致 notify 立即返回且 wait 处于睡眠状态。但是在 C++ 的 acquire/release atomics 中，它们可以。(更糟糕的是，在某些架构上，如 64 位 ARM，实现 acquire/release atomics 的最佳方式是顺序一致的 atomics，所以你可能会写出在 64 位 ARM 上运行良好的代码，但在移植到其他系统时才发现它是不正确的。)

基于这种理解，"acquire/release" 对于这些 atomics 来说是一个不幸的名字，因为顺序一致的 atomics 也做同样多的 acquire/release。这些 atomics 的不同之处在于失去了顺序一致性。把这些原子学称为 "coherence" atomics 可能更好。但这为时已晚。

### Relaxed atomics

C++ 并没有停留在仅仅是一致性的 acquire/release atomics 上。它还引入了非同步化的 atomics，称为 relaxed atomics（memory_order_relaxed）。这些 atomics 完全没有同步的效果 -- 它们没有创建任何 happens-before 的边界 -- 而且它们也没有排序保证。事实上，除了在 relaxed atomics 上的竞争不被认为是竞争，并且不会起火之外，relaxed atomics 读 / 写和普通的读 / 写之间没有任何区别。

修订后的 Java 内存模型的大部分复杂性来自于对有数据竞争的程序行为的定义。如果 C++ 采用了 DRF-SC 或 Catch Fire，有效地禁止了有数据竞赛的程序，就意味着我们可以丢掉我们之前看到的那些奇怪的例子，从而使 C++ 语言规范最终比 Java 语言更简单，那就更好了。不幸的是，包括 relaxed atomics，最终还是保留了所有这些问题，这意味着 C++11 的规范最终并不比 Java 简单。

与 Java 的内存模型一样，C++11 的内存模型最终也是不正确的。考虑一下之前的无中生有测试：

```c++
Litmus Test: Non-Racy Out Of Thin Air Values
Can this program see r1 = 42, r2 = 42?

// Thread 1           // Thread 2
r1 = x                r2 = y
if (r1 == 42)         if (r2 == 42)

    y = r1                x = r2

(Obviously not!)

C++11 (ordinary variables): no.
C++11 (relaxed atomics): yes!

```

在他们的论文 [“Common Compiler Optimisations are Invalid in the C11 Memory Model and what we can do about it” (2015) ](https://fzn.fr/readings/c11comp.pdf)中, Viktor Vafeiadis 和其他人表明，当 x 和 y 是普通变量时，C++11 规范保证这个程序必须以 x 和 y 设置为零结束。但如果 x 和 y 是 relaxed atomics，那么严格来说，C++11 规范并没有排除 r1 和 r2 都可能以 42 结束。

详细情况请看论文，但在高层次上，C++11 规范有一些正式的规则，试图禁止这样的无中生有，并结合一些模糊的词语来阻止其他类型的问题值。这些正式的规则是问题所在，所以 C++14 放弃了它们，只留下了模糊的词语。引用删除这些规则的理由，C++11 的表述被证明是 "既不充分，因为它使人们基本上无法解释具有 memory_order_relaxed 的程序，又严重有害，因为它可以说不允许在 ARM 和 POWER 等架构上对 memory_order_relaxed 进行所有合理的实现。"

简而言之，Java 试图正式排除所有无因（uncasual）执行，但失败了。然后，利用 Java 的后见之明，C++11 试图只正式排除一部分无因执行，也失败了。然后，C++14 完全没有说任何正式的东西。这并不是在往正确的方向发展。

事实上，马克 - 巴蒂（Mark Batty）等人在 2015 年发表的一篇题为 [“The Problem of Programming Language Concurrency Semantics” ](https://www.cl.cam.ac.uk/~jp622/the_problem_of_programming_language_concurrency_semantics.pdf)的论文给出了这样一个清醒的评价。

> 令人不安的是，在第一个 relaxed-memory 硬件（IBM 370/158MP）推出 40 多年后，该领域仍然没有一个可靠的建议，用于任何通用高级语言的并发语义，包括高性能基于共享内存的并发原语。

即使是定义弱序硬件（weakly-ordered hardware）的语义（忽略了软件和编译器优化的复杂性）也不是非常顺利。张思卓等人在 2018 年发表了一篇题为[ “Constructing a Weak Memory Model” ](https://arxiv.org/abs/1805.07886)的论文，叙述了更多最近的事件。

Sarkar 等人在 2011 年发表了 POWER 的操作模型，Mador-Haim 等人在 2012 年发表了一个公理模型，该模型被证明与操作模型匹配。然而，在 2014 年，Alglave 等人表明，原来的操作模型以及相应的公理模型都排除了在 POWER 机器上新观察到的一种行为。另一个例子是，在 2016 年，Flur 等人给出了 ARM 的操作模型，但没有相应的公理模型。一年后，ARM 在其 ISA 手册中发布了一个修订版，明确禁止 Flur 的模型所允许的行为，这导致了另一个拟议的 ARM 内存模型的出现。显然，以经验方式正式确定弱存储器模型是容易出错的，而且具有挑战性。

在过去的十年中，一直致力于定义和形式化所有这些的研究人员是非常聪明、有才华和坚持不懈的，我无意于通过指出结果中的不足之处来减损他们的努力和成就。我的结论是，即使没有数据竞争，指定线程程序的确切行为的这个问题也是非常微妙和困难的。今天，即使是最好和最聪明的研究人员，似乎也无法掌握这个问题。即使不是这样，当一种编程语言的定义能够被日常开发者所理解时，它的效果也是最好的，而不需要花费十年时间来研究并发程序的语义。

## C, Rust and Swift Memory Models

C11 也采用了 C++11 的内存模型，使之成为 C/C++11 内存模型。

2015 年的 [Rust 1.0.0 ](https://doc.rust-lang.org/std/sync/atomic/)和 [2020 年的 Swift 5.3](https://github.com/apple/swift-evolution/blob/master/proposals/0282-atomics.md) 都完全采用了 C/C++ 的内存模型，包括 DRF-SC 或 Catch Fire 以及所有的原子类型和原子栅栏。

这两种语言采用 C/C++ 模型并不奇怪，因为它们都建立在 C/C++ 编译器工具链（LLVM）上，并强调与 C/C++ 代码紧密结合。

## Hardware Digression: Efficient Sequentially Consistent Atomics

早期的多处理器架构有各种同步机制和内存模型，可用性各不相同。在这种多样性中，不同同步抽象的效率取决于它们与架构所提供的映射程度。为了构建顺序一致的原子变量的抽象，有时唯一的选择是使用屏障，这些屏障的作用和成本远远超过严格意义上的需求，尤其是在 ARM 和 POWER 上。

由于 C、C++ 和 Java 都提供了顺序一致的同步原子的相同抽象，因此硬件设计人员有责任使该抽象变得高效。ARMv8 架构（包括 32 位和 64 位）引入了 ldar 和 stlr 加载和存储指令，提供了直接实现。在 2017 年的一次谈话中，[Herb Sutter 声称 IBM 已经](https://youtu.be/KeLBd2EJLOU?t=3432)批准他说，他们打算未来的 POWER 实现也对顺序一致的 atomics 有某种更有效的支持，让程序员 "更没有理由使用 relaxed atomics"。我无法判断这是否发生了，尽管在 2021 年，POWER 已经变成了比 ARMv8 更不重要的东西。

这种趋同的效果是，顺序一致的原子学现在已经被很好地理解，并且可以在所有主要的硬件平台上有效地实现，使其成为编程语言内存模型的良好目标。

## JavaScript Memory Model (2017)

你可能会认为，JavaScript 是一种臭名昭著的单线程语言，不需要担心代码在多个处理器上并行运行时的内存模型。我当然这么认为。但你和我都错了。

JavaScript 有网络工作者，它允许在另一个线程中运行代码。按照最初的设想，工作者只能通过明确的消息复制来与 JavaScript 主线程进行交流。由于没有共享的可写内存，所以不需要考虑数据竞争等问题。然而，ECMAScript 2017（ES2017）增加了 SharedArrayBuffer 对象，它让主线程和工作者共享一个可写内存块。为什么要这样做呢？[在提案的早期草案中](https://github.com/tc39/ecmascript_sharedmem/blob/master/historical/Spec_JavaScriptSharedMemoryAtomicsandLocks.pdf)，列出的第一个原因是将多线程的 C++ 代码编译为 JavaScript。

当然，拥有共享的可写内存也需要定义同步的原子操作和内存模型。JavaScript 在三个重要方面偏离了 C++。

* 首先，它将原子操作限制在只有顺序一致的原子操作。其他的原子操作可以被编译成顺序一致的原子操作，也许在效率上有损失，但在正确性上没有损失，而且只有一种原子操作的话可以简化系统的其他部分。
* 第二，JavaScript 没有采用 "DRF-SC 或 Catch Fire"。相反，像 Java 一样，它仔细地定义了竞态访问的可能结果。其理由与 Java 基本相同，特别是安全性。允许竞态的读取返回任何值，允许（可以说是鼓励）实现者返回不相关的数据，这可能导致在[运行时泄漏私人数据](https://github.com/tc39/ecmascript_sharedmem/blob/master/DISCUSSION.md#races-leaking-private-data-at-run-time)。
* 第三，部分原因是 JavaScript 为 racy 程序提供了语义，它定义了在同一内存位置上使用原子和非原子操作，以及使用不同粒度的访问来访问同一内存位置时的情况。

精确地定义竞态程序的行为会导致相当多的复杂情况，即 relaxed memory 语义以及如何不允许无中生有等。除了这些挑战（这些挑战大多与其他地方相同），ES2017 的定义还有两个有趣的错误，这些错误是由于与新的 ARMv8 原子指令的语义不匹配而产生的。这些例子改编自 Conrad Watt 等人的 2020 年论文 “[Repairing and Mechanising the JavaScript Relaxed Memory Model.](https://www.cl.cam.ac.uk/~jp622/repairing_javascript.pdf)”

正如我们在上一节中指出的，ARMv8 增加了 ldar 和 stlr 指令，提供顺序一致的原子加载和存储。这些指令是针对 C++ 的，C++ 并没有定义任何具有数据竞争的程序的行为。因此，毫不奇怪，这些指令在竞态程序中的行为不符合 ES2017 作者的期望，特别是它不满足 ES2017 对竞态程序行为的要求。

```c
Litmus Test: ES2017 racy reads on ARMv8
Can this program (using atomics) see r1 = 0, r2 = 1?

// Thread 1           // Thread 2
x = 1                 y = 1
r1 = y                x = 2 (non-atomic)
                      r2 = x

C++: yes (data race, can do anything at all).
Java: the program cannot be written.
ARMv8 using ldar/stlr: yes.
ES2017: no! (contradicting ARMv8)
```

在这个程序中，所有的读和写都是顺序一致的 atomics，但 x = 2 除外：线程 1 使用原子存储写 x = 1，但线程 2 使用非原子存储写 x = 2。在 C++ 中，这是一个数据竞争，所以所有的赌注都被取消了。在 Java 中，这个程序不能写：x 必须被声明为易失性，或者不被声明为易失性；它不能只在某些时候被原子访问。在 ES2017 中，内存模型原来是不允许 r1=0，r2=1。如果 r1 = y 读取 0，线程 1 必须在线程 2 开始之前完成，在这种情况下，非原子 x = 2 似乎发生在 x = 1 之后并覆盖了 x = 1，导致原子 r2 = x 读取 2。这种解释似乎完全合理，但这并不是 ARMv8 处理器的工作方式。

事实证明，对于 ARMv8 指令的等效序列，对 x 的非原子写入可以在对 y 的原子写入之前重新排序，因此该程序实际上产生了 r1 = 0，r2 = 1。这在 C++ 中不是一个问题，因为竞态意味着程序可以做任何事情，但对于 ES2017 来说是一个问题，它将竞态的行为限制在不包括 r1=0，r2=1 的结果集上。

由于 ES2017 的明确目标是使用 ARMv8 指令来实现顺序一致的原子操作，Watt 等人报告说，他们建议的修正（预计将包括在标准的下一个修订版中）将削弱竞态行为约束，足以允许这种结果。(我不清楚当时的 "下一版" 是指 ES2020 还是 ES2021）。)

Watt 等人建议的修改还包括对第二个错误的修复，这个错误首先由 Watt、Andreas Rossberg 和 Jean Pichon-Pharabod 发现，ES2017 规范没有给一个无竞态的程序提供顺序一致的语义。该程序如下

```c++
Litmus Test: ES2017 data-race-free program
Can this program (using atomics) see r1 = 1, r2 = 2?
// Thread 1           // Thread 2
x = 1                 x = 2

                      r1 = x
                      if (r1 == 1) {
                          r2 = x // non-atomic
                      }

On sequentially consistent hardware: no.
C++: I'm not enough of a C++ expert to say for sure.
Java: the program cannot be written.
ES2017: yes! (violating DRF-SC).
```

在这个程序中，所有的读和写都是顺序一致的原子，只有 r2 = x 除外，正如所标记的。这个程序是无数据竞争的：非原子读只在 r1 = 1 时执行，这证明线程 1 的 x = 1 发生在 r1 = x 之前，因此也发生在 r2 = x 之前。 DRF-SC 意味着程序必须以顺序一致的方式执行，因此 r1 = 1，r2 = 2 是不可能的，但 ES2017 规范允许它。

因此，ES2017 对程序行为的规范同时过于强势（它不允许竞态程序的真正 ARMv8 行为）和过于弱势（它允许非静态程序的非顺序一致行为）。如前所述，这些错误已被修正。即便如此，这也再次提醒我们，准确地使用 happens-before 来指定无数据竞争和竞态程序的语义是多么微妙，以及将语言内存模型与底层硬件内存模型相匹配是多么微妙。

令人鼓舞的是，至少在目前，JavaScript 避免了在顺序一致的原子之外添加任何其他原子，并且抵制了 "DRF-SC 或 Catch Fire"。其结果是，内存模型与 C/C++ 编译目标一样有效，但更接近于 Java。

## Conclusions

看看 C、C++、Java、JavaScript、Rust 和 Swift，我们可以做出以下观察。
* 它们都提供了顺序一致的同步原子，用于协调并行程序的非原子部分。
* 它们的目的都是为了保证使用适当的同步技术实现无竞态的程序表现得如同以顺序一致的方式执行。
* 在 Java 9 引入 VarHandle 之前，Java 一直抵制添加弱（acquire/release）同步原子。在撰写本文时，JavaScript 也避免了添加它们。
* 它们都为程序提供了一种方法，以执行 "有意" 的数据竞争而不使程序的其他部分失效。在 C、C++、Rust 和 Swift 中，这种机制是宽松的、非同步的原子，一种特殊形式的内存访问。在 Java 中，这种机制是普通内存访问或 Java 9 VarHandle "普通" 访问模式。在 JavaScript 中，这种机制是普通的内存访问。
* 这些语言都没有找到一种方法来正式禁止无中生有这样的悖论，但全都非正式地禁止它们。

同时，处理器制造商似乎已经接受了顺序一致的同步原子的抽象性对于有效实现是很重要的，并且开始这样做了。ARMv8 和 RISC-V 都提供了直接支持。

最后，大量的验证和形式分析工作已经用于理解这些系统并精确地说明其行为。特别令人鼓舞的是，Watt 等人在 2020 年能够给出 JavaScript 的重要子集的形式化模型，并使用定理检验器来证明编译到 ARM、POWER、RISC-V 和 x86-TSO 的正确性。

在第一个 Java 内存模型出现的 25 年后，经过许多人世纪的研究努力，我们可能已经开始能够将整个内存模型形式化。也许，有一天，我们也会完全理解它们。

本系列的下一篇文章是 "Go 内存模型"。

## Acknoledgements

这一系列的文章极大地受益于与一长串工程师的讨论和反馈，我很幸运能在谷歌工作。我对他们表示感谢。我对任何错误或不受欢迎的意见承担全部责任。

下一篇：[发展的 Go 内存模型](../gomm)