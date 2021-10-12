---
title: "【golang】heap 堆"
date: 2021-08-10T10:29:12+08:00
draft: false
image: "go.png"
description: "golang heap 的用法及其实现"
categories:
    - 学习
tags: 
    - golang
    - heap
---

个人链接汇总：[https://www.lincyaw.xyz](https://www.lincyaw.xyz)

因为缺乏了泛型的支持，golang 的 heap 实现非常神奇——神奇之处在于，他只提供了一组 heap 的方法集。至于底层的存储，则是完全地交给了用户去实现。这种实现方式也是鸭子类型的体现。

只要一个结构体实现了下面的接口，这个接口就可以被认为是一个 heap。

```go
type Interface interface {
	sort.Interface
	Push(x interface{}) // add x as element Len()
	Pop() interface{}   // remove and return element Len() - 1.
}

// 其中 sort.Interface 的定义如下
type Interface interface {
	Len() int
	Less(i, j int) bool
	Swap(i, j int)
}
```

> golang 时时刻刻都体现着用[组合实现继承](https://zhuanlan.zhihu.com/p/60282972)的特点，在一定程度上避免了继承带来的许多问题。

## heap 的使用

先看看 golang 标准库中的 heap_test.go 是如何实现一个 heap 的。

```go
type myHeap []int

func (h *myHeap) Less(i, j int) bool {
	return (*h)[i] < (*h)[j]
}

func (h *myHeap) Swap(i, j int) {
	(*h)[i], (*h)[j] = (*h)[j], (*h)[i]
}

func (h *myHeap) Len() int {
	return len(*h)
}

func (h *myHeap) Pop() (v interface{}) {
	*h, v = (*h)[:h.Len()-1], (*h)[h.Len()-1]
	return
}

func (h *myHeap) Push(v interface{}) {
	*h = append(*h, v.(int))
}
```

上面的代码中使用了 int 数组作为底层的存储。可以注意到，Push 和 Pop 的实现仅仅是实现了一个**栈(stack)**。Push 把新元素加到了数组的末尾，而 Pop 则是把数组末尾的数字返回，并且将数组最后一个数删除。

那么，标准库到底是怎么实现 heap 的操作的呢？这里按下不表，先看看如何操作这个数组。

```go
func main()  {
	h := &myHeap{}
	heap.Init(h)
	heap.Push(h, 3)
	heap.Push(h, 6)
	heap.Push(h, 1)
	heap.Push(h, -2)
	heap.Push(h, 10)
	fmt.Println(h)
	fmt.Println(heap.Pop(h))
	fmt.Println(heap.Pop(h))
	fmt.Println(heap.Pop(h))
	fmt.Println(h)
}
// &[-2 1 3 6 10]
// -2
// 1
// 3
// &[6 10]
```

上面的代码进行了一个简单的测试。不难发现，在实际操作的时候，并不是调用我们自己实现的 myHeap 里的 Push 和 Pop 操作，而是将 h 作为一个参数传入 heap 包中实现的 Push 操作。(这里又非常的像 C 语言)。

根据结果，我们可以发现这个库默认实现的是小根堆。关键点在于 Less 函数的定义：

```go
func (h *myHeap) Less(i, j int) bool {
	return (*h)[i] < (*h)[j]
}
```

如何记忆这样的一个函数呢，一个常用的方法是假设 `i<j`，如果 `h[i] < h[j]`，则可以认为这个数组的排序是从小到大的，则这个堆将是一个小根堆。反之，则是一个大根堆。

如果底层的存储的数据是 int 类型，或者是 string 类型，则可以直接使用 sort 包中已经实现好的 IntSlice 和 StringSlice。里面已经为我们实现好了 sort.Interface。也就只说我们只需要实现 Push 和 Pop 即可。

```go
type IntSlice []int
type StringSlice []string
```

但是很不幸的是默认实现的是小根堆，我们能不能用 sort.IntSlice 实现一个大根堆呢？答案是可以的。只需要重新实现一下 Less 即可。

> 注意，golang 与 C 语言相比弱化了指针的概念。可以发现下面的代码与上面的相比，Push 和 Pop 操作并没有加上`“*”`间接运算符，因为 golang 编译器会自动进行转换。

```go
type hp struct{ sort.IntSlice }
func (h *hp) Push(v interface{}) { h.IntSlice = append(h.IntSlice, v.(int)) }
func (h *hp) Pop() (v interface{}) {
	v = h.IntSlice[len(h.IntSlice)-1]
	h.IntSlice = h.IntSlice[:len(h.IntSlice)-1]
	return
}
func (h hp) Less(i, j int) bool {
	return h.IntSlice[i] > h.IntSlice[j]
}
func main() {
	h := &hp{}
	heap.Init(h)
	heap.Push(h, 3)
	heap.Push(h, 6)
	heap.Push(h, 1)
	heap.Push(h, -2)
	heap.Push(h, 10)
	fmt.Println(h)
	fmt.Println(heap.Pop(h))
	fmt.Println(heap.Pop(h))
	fmt.Println(heap.Pop(h))
	fmt.Println(h)
	fmt.Println(heap.Pop(h))
}
```


## heap 的实现

上面学习了 heap 怎么使用，并且提出了一个问题：标准库是怎么把我们定义的 “栈” 操作转换成一个 堆 应该有的行为呢？

现在看一下 golang 的标准库是怎么实现的。下面给出堆的最重要的两个操作：上浮和下沉。

```go
// 小数上浮
func up(h Interface, j int) {
	for {
		i := (j - 1) / 2 // parent
        // 如果 自己是根 或者 自己不比父亲小（比父亲大）则退出循环
		if i == j || !h.Less(j, i) {
			break
		}
        // 父亲比儿子大，就使自己与父亲交换，小数就会一直往上浮
		h.Swap(i, j)
		j = i
	}
}
// 大数下沉
// i0: 起始的位置
// n: 堆的大小
func down(h Interface, i0, n int) bool {
	i := i0
	for {
		j1 := 2*i + 1
        // 判断是否越界
		if j1 >= n || j1 < 0 { // j1 < 0 after int overflow
			break
		}
		j := j1 // left child
        // 如果右节点存在，并且右节点比左节点小
		if j2 := j1 + 1; j2 < n && h.Less(j2, j1) {
			j = j2 // = 2*i + 2  // right child
		}
        // 若 儿子不比父亲小（父亲比儿子小），则退出
		if !h.Less(j, i) {
			break
		}
        // 儿子比父亲小，则父亲应该下沉
		h.Swap(i, j)
		i = j
	}
	return i > i0
}
```

接下来看 Init, Push 和 Pop 操作:

```go
// Init establishes the heap invariants required by the other routines in this package.
// Init is idempotent with respect to the heap invariants
// and may be called whenever the heap invariants may have been invalidated.
// The complexity is O(n) where n = h.Len().
// 建堆的复杂度为 O(n)
func Init(h Interface) {
	// heapify
	n := h.Len()
    // 从树的倒数第二层开始，让大数下沉
	for i := n/2 - 1; i >= 0; i-- {
		down(h, i, n)
	}
}

// Push pushes the element x onto the heap.
// The complexity is O(log n) where n = h.Len().
// 在前面我们定义的 h 的 Push 操作是把新的数 push 到数组的末尾
// 因此这里的 up 的 index 就是数组的长度了
// 插入的复杂度为 O(log n)
func Push(h Interface, x interface{}) {
	h.Push(x)
	up(h, h.Len()-1)
}

// Pop removes and returns the minimum element (according to Less) from the heap.
// The complexity is O(log n) where n = h.Len().
// Pop is equivalent to Remove(h, 0).
// Pop 操作是将堆里的最小的数弹出去。（假设是最小堆）
// 则将最小的数与最后一个数交换，将堆的大小减 1, 然后执行一次下沉后
// 这个数组又符合堆的定义了
// 删除的复杂度为 O(log n)
func Pop(h Interface) interface{} {
	n := h.Len() - 1
	h.Swap(0, n)
	down(h, 0, n)
	return h.Pop()
}
```