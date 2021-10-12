---
title: "【操作系统】【golang】Synchronization Primitives"
date: 2021-08-22T16:45:48+08:00
draft: true
image: "cover.png"
description: "从操作系统的同步原语出发，探究 golang 标准库的锁的实现"
categories:
    - 学习
tags: 
    - os
    - golang
---

同步原语并非多核时代的产物，在单核中也存在多个线程之间的同步需求。这是由于调度器可以调度不同的线程交错执行，从而营造每个线程都运行在一个单独的 CPU 上的假象。因此，当多个线程访问共享资源时，也会出现正确性问题。而在多核 CPU 中，任务可以被划分给运行在不同 CPU 核心上的线程来同时处理。这使线程之间的同步更加频繁，也为同步原语的实现带来了新的挑战。

## 原子操作

最常见的原子操作包括 CAS（ Compare-And-Swap）和 FAA（Fetch-And-Add)。

下面用一段伪代码来说明 CAS 的原理。

```c
int CAS(int *addr, int expected, int new_value){
    int tmp = *addr;
    if(*addr == expected)
        *addr = new_value;
    return tmp;
}
```

CAS 操作会比较地址 addr 上的值与期望值 expected 是否相等，如果相等则将 addr 上的值置换为新的值 new_value，否则不进行置换。最后 CAS 返回了addr 所存放的旧值。

FAA 则是将原来的值加上对应的值，然后返回原来的值。伪码如下：

```c
int FAA(int *addr, int add_value){
    int tmp = *addr;
    *addr = tmp + add_value;
    return tmp;
}
```

> 假设这两段伪代码在被执行时是顺序执行的。因为如果不是顺序执行的话，倘若有两个线程同时执行这两个函数，则会因为CPU的乱序执行导致程序发生不可预测的错误。

为了保证这些操作的原子性，需要在硬件层面提供支持。Golang 在 `runtime/internal/atomic/`中给出了基于不同平台实现的汇编代码。下面仅展示 amd64 平台的 CAS 代码：

```go
// bool Cas(int32 *val, int32 old, int32 new)
// Atomically:
//	if(*val == old){
//		*val = new;
//		return 1;
//	} else
//		return 0;
TEXT runtime∕internal∕atomic·Cas(SB),NOSPLIT,$0-17
	MOVQ	ptr+0(FP), BX
	MOVL	old+8(FP), AX
	MOVL	new+12(FP), CX
	LOCK
	CMPXCHGL	CX, 0(BX)
	SETEQ	ret+16(FP)
	RET
```

有了 CAS 这样的原子操作，后面就可以根据 CAS 实现互斥锁了。

## Golang 互斥锁实现

Golang 里的互斥锁没有包含非常多的成员，只包含一个状态以及一个信号量。

```go
type Mutex struct {
	state int32
	sema  uint32
}
```

### Lock

先抛开代码不谈。想象一下 Lock 的行为：

1. 当锁没有被锁上时，可以被锁上。
2. 当锁被锁上，而又想锁这把锁时，就会被阻塞。

因此下面的代码就体现了这个思想，其中`atomic.CompareAndSwapInt32`便是上面提到的原子操作。

```go
func (m *Mutex) Lock() {
	// Fast path: grab unlocked mutex.
	if atomic.CompareAndSwapInt32(&m.state, 0, mutexLocked) {
		if race.Enabled {
			race.Acquire(unsafe.Pointer(m))
		}
		return
	}
	// Slow path (outlined so that the fast path can be inlined)
	m.lockSlow()
}
```

当锁已经被锁上的时候`m.lockSlow()`会被执行。

## 参考资料

[《现代操作系统原理与实现》](https://book.douban.com/subject/35208251/)

[sync.go](sync.go)
   