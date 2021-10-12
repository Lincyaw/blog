---
title: linux 页面回收
date: 2021-04-07
tags: 
    - linux kernel
categories: 
    - 学习
---

最近在研究匿名页面压缩相关的优化算法，记录一下最近在看的东西。都是自己的理解，如果有错误请指出。

<!--more-->

匿名页，实际上就是程序在运行时产生的页面。即通常的博客里所说的非文件页。为了加快速度，内核会把存放在磁盘中的页面读取到内存中，这些页面有存放代码的，有存放数据的；而匿名页则是这些代码在运行时动态产生的。

下面从匿名页的生命周期的角度，使我们对匿名页有一个总体的了解。

# 匿名页的生命周期

这部分将是这篇博客的重点，所有的内容将围绕着匿名页的生命周期进行阐述。

![流程图 ](http://lincyaw.xyz/images/流程图.jpg)

## 匿名页的产生

从内核的角度看，在下面的情况中会产生匿名页

1. 用户空间通过`malloc()/mmap()`接口函数来分配内存，在内核空间中发生缺页中断时，会调用`do_anonymous_page()`函数，从而产生匿名页面。


> `do_anonymous_page()`函数实现在`<mm/memory.c>`文件中。是缺页中断处理匿名页面的核心函数。
2. 发生写时复制。当缺页中断出现写保护错误时，新分配的页面是匿名页面，又分为两种情况。
- 调用`do_wp_page()`
	-  分配只读的特殊映射的页面，如映射到零页面的页面。
	-  分配非单身匿名页面（有多个映射的匿名页面，即`page->_ mapcount>0`）。
	-  分配只读的私有映射的内容缓存页面。
	-  分配KSM页面
- 调用`do_cow_page()`共享的匿名映射（Shard Anonymous Mapping，SHMM）页面。

3. `do_swap_page()`，从交换分区读回数据时会分配匿名页面。

4. 迁移页面

	以`do_anonymous_page()`分配一个匿名页面为例，匿名页面刚分配时的状态如下。

	- `page->_refcount = 1`
	- `page->_mapcount = 0`
	- 设置`PG_swapbacked`标志位
	- 加入`LRU_ACTIVE_ANON`链表中，并设置`PG_lru`标志位
	- `page->mapping`指向VMA中的`anon_vma`数据结构

## 匿名页面的使用

匿名页面在缺页中断中分配完成后，就建立了进程虚拟地址空间和物理页面的映射关系，用户进程访问虚拟地址即访问匿名页面的内容。



## 匿名页面的换出

当系统内存紧张时，需要会受一些页面来释放内存。匿名页面刚分配时会加入LRU链表（LRU_ACTIVE_ANON)的头部，在活跃LRU链表移动一段时间后，该匿名页面到了尾部。`shrink_active_list()`函数会把该页面加入不活跃LRU链表中。

`shrink_inactive_list()`函数会扫描不活跃的LRU链表。**第一次扫描不活跃链表**的时候，`shrink_page()->add_to_swap()`会为该页面分配交换分区。

此时，该页面的`_refcount,_mapcount,flags`的状态如下所示

> page->_refcount = 3
>
> page->_mapcount = 0
>
> page->flags = [PG_lru | PG_swapbacked | PG_swapcache | PG_dirty | PG_uptodate | PG_locked]

为什么`_refcount`是3呢？

分配页面时，分离页面（分离LRU链表）时，`add_to_swap()`函数都会让这个页面的`_refcount`加一。

`add_to_swap()`也会增加一些标志位，比如`PG_swapcache `表示这个页面已经分配了交换分区，`PG_dirty `表示该页面是脏页，等下要把内容写回交换分区，`PG_uptodate `表示这个页面的数据是有效的。

`shrink_page()->tru_to_unmap()`运行后，状态如下

> page->_refcount = 2
>
> page->_mapcount = -1

因为`tru_to_unmap()`会通过RMAP系统去寻找映射该页面的所有VMA和对应的PTE，并且将这些页面解除映射。因为该页面只和父进程建立了映射关系，所以`_refcount,_mapcount`都要减1。如果`_mapcount`变成-1，则说明没有PTE映射到这个页面。

`shrink_page()->page_out()`会把这个页面写回交换分区，并且设置状态位，此时状态如下：

> page->_refcount = 2
>
> page->_mapcount = -1
>
> page->flags = [PG_lru | PG_swapbacked | PG_swapcache | PG_uptodate | PG_reclaim | PG_writeback]

`page_out()`的作用如下：

- 检查该页面是否可以释放
- 清除`PG_dirty`标志位
- 设置`PG_reclaim`标志位
- 通过`swap_writepage()`设置`PG_writeback`标志位，清除`PG_locked`，向交换分区写内容。

交换分区并不是在内存中的，很显然，内核不应该去等待这个过程。因此内核线程`kswapd`不会等待这个页面写完，所以该页面将被放回到不活跃LRU链表头部。

第二次扫描不活跃LRU链表时，刚刚的那个页面又经历了一次不活跃LRU链表的移动过程。如果此时`PG_writeback`标志位还在，说明页面还没有写完，则这个页面又会被放到不活跃LRU链表头部。

若写入交换分区的过程已经结束，则块层的回调函数`end_swap_bio_write()->end_page_writeback()`会进行如下操作：

- 清除`PG_writeback`标志位
- 唤醒正在等待该页面写回的线程，见`wake_up_page(page,PG_writeback)`函数

`shrink_page_list()->__remove_mapping()`函数的作用为：

- `page_freeze_refs(page,2)`判断当前`page->_refcount`是否为2，并且将其设置为0
- 清除`PG_swapcache`标志位
- 清除`PG_locked`标志位

此时匿名页的状态如下：

> page->_refcount = 0
>
> page->_mapcount = -1
>
> page->flags = [PG_uptodate | PG_swapbacked]

最后把页面加入`free_page`链表中，释放该页面。因此该匿名页面的状态是匿名页面已经被写入交换分区，实际物理页面已经被释放。

![可以另存为，然后放大查看该图](http://lincyaw.xyz/images/subsystem.png)

## 匿名页面的换入

匿名页面被换出到交换分区后，如果应用程序需要读写这个页面，则会发生缺页中断，由于PTE中的present位显示该页面不在内存中，但PTE不为空，说明该页面在交换分区中，因此调用`do_swap_page()`函数重新读取该页面的内容。

## 匿名页面的销毁

当用户进程关闭或者退出时，会扫描这个用户进程所有的VMA，并且清除这些VMA上所有的映射。如果符合释放标准，相关页面会被释放。本例中的匿名页面只映射了父进程的VMA，所以这个页面也会被释放。

# 页面产生的细节

## 缺页中断

在匿名页面的产生的第一条和第二条都提到了缺页中断，从而产生了匿名页面。

`handle_mm_fault()`函数是处理进程地址空间缺页异常的核心函数，他的实现与架构无关。

如下图所示，异常的地址出现在用户地址空间，通过`find_vma()`函数查找该VMA，如果没有找到，说明就有问题。因此返回`vm_fault_t`类型的错误。

如果找到了VMA，则根据不同的判断条件来确定缺页中断是哪一种类型。

![](http://lincyaw.xyz/images/interrupt.jpg)

匿名页产生涉及到的函数就包括了`do_anonymous_page()`，`do_swap_page()`，`do_wp_page()`。





在上面还提到了page数据结构的两个成员：`_refcount`以及`_mapcount`。这是page中非常重要的两个引用计数，两者看起来相似，但又不同。

下面进行详细说明

## `_refcount`

**`_refcount`表示内核中引用该页面的次数；**

当`_refcount`为0的时候，表示该页面为空闲页面或即将被释放的页面。

当`_refcount`大于0的时候，表示该页面已经被分配且内核正在使用，暂时不会被释放。

`_refcount`通常被用于跟踪页面的使用情况。比如页面被加入LRU链表**时**，此时他的使用者是内核线程`kswapd`，因此`_refcount`会加1。当页面已经被加到LRU链表之后，`_refcount`又会减1，这样的目的是为了防止页面在被添加到LRU链表的过程中被释放。

再比如被映射到其他用户进程的PTE时，`_refcount`会加1。如创建子进程时共享父进程的地址空间，设置父进程的PTR内容到子进程中，并增加该页面的`_refcount`。


## `_mapcount`

`_mapcount`表示这个页面被进程映射的个数，即已经映射了多少个用户PTE；

`_mapcount`若等于-1，表示没有PTE映射到页面。

`_mapcount`若等于0，表示只有父进程映射到页面。匿名页面刚分配时，`_mapcount`初始化为0。

若`_mapcount`大于0，表示除了父进程外还有其他进程映射到这个页面。同样以fork为例，设置父进程的PTE内容到子进程中并且增加该页面的`_mapcount`。

# 页面换出的细节

linux内核维护了5个LRU链表来管理页面。

- 在内核分配页面0。跃匿名页面链表 LRU_INACTIVE_ANON
- 活跃**匿名**页面链表 LRU_ACTIVE_ANON
- 不活跃文件映射页面链表 LRU_INACTIVE_FILE
- 活跃文件映射页面链表 LRU_ACTIVE_FILE
- 不可回收页面链表 LRU_UNEVICTABLE

之所以分成5个链表，是因为当内存紧缺时总是优先换出文件映射的文件缓存页面，而不是匿名页面。因为大多数情况下，文件缓存页面不需要被回写到磁盘（除非被修改，变成了脏页），而匿名页面总是要在写入交换分区之后才能被换出。

问题来了，他为什么要针对同一种页面维护两个链表呢？有一个原因是，如果只维护一个链表的话，在换出页面时，没有考虑该页面是频繁使用的，还是很少使用的。频繁使用的页面仍然会因为在LRU链表的末尾而被换出。

因此，内核使用两个链表，给经常使用的页面第二次机会，从而使其被换出的几率减小。内核在`page`这个数据结构中设置了两个标志位来实现这个逻辑。

`PG_active`表示这个页面是否活跃，`PG_referenced`表示这个页面是否被引用过。在LRU_INACTIVE_ANON 链表末尾的页面，如果 `PG_active==0 && PG_referenced==1`，则再给他一次复活的机会，将其放入`LRU_ACTIVE_ANON`链表的头，并且清空`PG_referenced`，表示其消耗了这次机会。

