---
title: "【golang】context包"
date: 2021-08-08T17:28:05+08:00
draft: false
image: "go.png"
description: "context 包的一些使用方法以及注意事项"
categories:
    - 学习
tags: 
    - golang
    - context
---

个人链接汇总：[https://www.lincyaw.xyz](https://www.lincyaw.xyz)

7 月面虾皮的时候被问了 golang 的 context 包有啥用，我支支吾吾了半天没说出个名堂来。自己平时就是用这玩意让主协程通知一下其他协程任务结束了，也不知道有啥其他的功能，今天就仔细看看。

---

平时见的最多 context 地方是在写一些 web 服务的时候，下面的代码正常的运行流程为：

1. 开启服务
2. 访问 localhost:8090/hello 后，http 包启动一个协程处理这个请求（调用 hello handler），打印 "server: hello handler started"
3. 等待 2 秒后，计时器超时，在客户端显示 "hello"。这里的等待模拟的是服务端正在处理数据。
4. 服务关闭，打印 "server: hello handler ended"

```go
// 来自于 https://gobyexample-cn.github.io/context
package main
import (
    "fmt"
    "net/http"
    "time"
)
func hello(w http.ResponseWriter, req *http.Request) {
    ctx := req.Context()
    fmt.Println("server: hello handler started")
    defer fmt.Println("server: hello handler ended")

    // 监听 channel，两者都是阻塞操作
    select {
    case <-time.After(2 * time.Second):
        fmt.Fprintf(w, "hello\n")
    case <-ctx.Done():
        err := ctx.Err()
        fmt.Println("server:", err)
        internalError := http.StatusInternalServerError
        http.Error(w, err.Error(), internalError)
    }
}
func main() {
    http.HandleFunc("/hello", hello)
    http.ListenAndServe(":8090", nil)
}
```
但如果服务端在处理数据的过程中，客户端取消了请求，则会触发 `case <-ctx.Done()`。打印结果如下：

```
server: hello handler started
server: context canceled
server: hello handler ended
```

## [context](https://pkg.go.dev/context#pkg-index) 包的成员函数

包里有三个函数。

```go
func WithCancel(parent Context) (ctx Context, cancel CancelFunc)
func WithDeadline(parent Context, d time.Time) (Context, CancelFunc)
func WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc)
```

查看描述得知，返回值里的 context.Done 这个 channel 会被 close，当且仅当 **父 context.Done 被 close** 或者 **调用了 cancel 函数**。

### WithDeadline && WithTimeout
WithTimeout 相当于只是封装了一下 WithDeadline。WithDeadline 的作用是，在本地时间到达约定好的时间后，通知所有的 context 任务要停止了；而 WithTimeout 是在调用时的时间上加上 timeout 的时间，作为约定好的时间。

```go
import (
	"context"
	"fmt"
	"time"
)
func main() {
	d := time.Now().Add(1 * time.Second)
	ctx, cancel := context.WithDeadline(context.Background(), d)
    // 按道理，WithDeadline 以及 WithTimeout 是不需要下面这行语句的
    // 因为超时之后，会执行下面的 ctx.Done 部分，去掉和不去掉的效果是一样的
    // 但官方建议不去掉，因为可能会导致 这个 context 以及 他的父亲 没有按照需求的被停止
    // goland 会提示 warning: 
    // The cancel function should be called, not discarded, to avoid a context leak
    // 但是我自己并没有想到一个场景会导致这样的情况
	defer cancel()

	select {
	case <-time.After(1 * time.Second):
		fmt.Println("overslept")
	case <-ctx.Done():
		fmt.Println(ctx.Err())
	}

}
```

个人感觉使用场景为：单次的限时任务。


### WithCancel

直接看示例代码，gen 函数的返回值是一个 int 类型的 channel。函数内部启动了一个协程来不停地生成数字送入 channel。由于
这个 channel 在定义时没有定义大小，因此这个 channel 是阻塞的，没有缓冲区。当 main 从 channel 里获得的数等于 5 时，
将会停止在 channel 里获取数字(break)，然后调用 cancel() 函数，从而杀死 gen 函数里调用的协程。

```go
package main
import (
	"context"
	"fmt"
)
func main() {
	gen := func(ctx context.Context) <-chan int {
		dst := make(chan int)
		n := 4
		go func() {
			for {
				select {
				case <-ctx.Done():
					return // returning not to leak the goroutine
				case dst <- n:
					n++
				}
			}
		}()
		return dst
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel() // cancel when we are finished consuming integers
	for n := range gen(ctx) {
		fmt.Println(n)
		if n == 5 {
			break
		}
	}
}
```

可能最后 for 循环来遍历 channel 的代码有些难以理解，其实他是等价于下面的代码：

```go
ch := gen(ctx)
for {
    n := <-ch
    fmt.Println(n)
    if n == 5 {
        break
    }
}
```

如果 channel 里一直有值的话，for range 函数就会一直运行。（阻塞的话就阻塞了）

另一个值得关注的关于 channel 的点是, 可以用`n, more <- ch`来判断 channel 是否关闭。当且仅当 ch 里没有数据，并且 ch 被关闭时，返回值 more 才会是 false。如下代码，ch 是带 5 个缓冲区的通道，main 在传输了 4 个数之后关闭了通道。但是后续启动的协程里还能读到这 4 个数，直到全部取完后，返回值 more 变成了 false。

当 main 要发送超过 5 个数时，会导致程序无法执行。原因是发送操作被 ch 阻塞了，导致后续的协程没有被启动。

```go
package main
import (
	"fmt"
)
func main() {
	ch := make(chan int, 5)
	for i := 0; i < 4; i++ {
		ch <- i
	}
	close(ch)
	done := make(chan int)
	go func() {
		for {
			n, more := <-ch
			if more {
				fmt.Println(n)
			} else {
				fmt.Println("work done")
				done <- 1
				break
			}
		}
	}()
	<-done
}
```


## [context](https://pkg.go.dev/context#pkg-index) 包的成员 Context

### Context

Context 有三种产生来源，更准确地说是两种，即 `Background()` 和 `TODO()`。因为其他的所有函数的入参中都有一个 parent，而`Background()` 和 `TODO()`则是真正的“父亲”。
```go 
type Context
    func Background() Context
    func TODO() Context
    func WithValue(parent Context, key, val interface{}) Context
```

Context 的定义如下：

```go
type Context interface {
	Deadline() (deadline time.Time, ok bool)
	Done() <-chan struct{}
	Err() error
	Value(key interface{}) interface{}
}
```

`Deadline()` 函数主要与 WithDeadline && WithTimeout 两种类型的 context 产生联系，几乎不需要什么使用。使用的更多的是 `Done()`，如最开始的代码所示，Done 的情况里就已经包含了 deadline。而 `Err()` 用于在 Done 时，查看是因为哪种方式 Done 的。

```go
select {
    case <-ctx.Done():
  	    return ctx.Err()
	case out <- v:
}
```

### Background && TODO

这两个函数产生的 Context 辈分是最大的。

Background 用于 main 函数中初始化顶层的 Context。

而 TODO 则是字面意思：todo。当不清楚使用哪个 Context 或者 它还不可用时（因为周围的函数还不能接受Context参数）。



### WithValue && Context.Value()

最后出场的带 key/value 的 Context，直接上代码。

```go
import (
	"context"
	"fmt"
)

func main() {
	type favContextKey string

	f := func(ctx context.Context, k favContextKey) {
		if v := ctx.Value(k); v != nil {
			fmt.Println("found value:", v)
			return
		}
		fmt.Println("key not found:", k)
	}

	k := favContextKey("language")
	ctx := context.WithValue(context.Background(), k, "Go")

	f(ctx, k)
	f(ctx, favContextKey("color"))

}
```

`ctx := context.WithValue(context.Background(), k, "Go")`

这行代码构造了一个 Context 是带有 ["language", "Go"] 这样一个键值对的。f 函数则是查看这个 Context 是否带有这个 key。 `ctx.Value(k)` 返回的是 k 对应的 value 是什么。   

这一对兄弟在 gin 框架里特别常见，可以存储相当多的键值对。而且他的函数设计实现也意味着他可以一直套娃：

```go
k := favContextKey("kk")
l := favContextKey("oo")
ctx := context.WithValue(context.Background(), k, "Go")
ctx = context.WithValue(ctx, l, "ll")
f(ctx, k)
f(ctx, l)
```

ctx 将存有 `[kk,GO]`, `[oo,ll]` 两对键值对。


## 例子

下面的代码每 80 ms 产生斐波那契数列中的一个数，一共持续 1 s。

```go
package main

import (
	"context"
	"fmt"
	"time"
)

func fibonacci(ctx context.Context, c chan int) {
	x, y := 0, 1
	for {
		select {
		case c <- x:
			x, y = y, x+y
		case <-ctx.Done():
			fmt.Println("quit")
			return
		}
	}
}
func main() {
	ch := make(chan int)
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	go fibonacci(ctx, ch)
	cnt := 0
	for {
		select {
		case  c := <-ch:
			fmt.Println(cnt, " ", c, " ", time.Now())
			cnt++
			time.Sleep(80 * time.Millisecond)
		case <-ctx.Done():
			return
		}
	}
}
```

一种结果是：

```go
0   0   2021-08-08 23:11:14.2926712 +0800 CST m=+0.000173201
1   1   2021-08-08 23:11:14.3731489 +0800 CST m=+0.080650901
2   1   2021-08-08 23:11:14.4536001 +0800 CST m=+0.161102201
3   2   2021-08-08 23:11:14.5339946 +0800 CST m=+0.241496601
4   3   2021-08-08 23:11:14.614256 +0800 CST m=+0.321758001
5   5   2021-08-08 23:11:14.6945427 +0800 CST m=+0.402044701
6   8   2021-08-08 23:11:14.7748316 +0800 CST m=+0.482333701
7   13   2021-08-08 23:11:14.8551425 +0800 CST m=+0.562644501
8   21   2021-08-08 23:11:14.9355948 +0800 CST m=+0.643096801
9   34   2021-08-08 23:11:15.0158757 +0800 CST m=+0.723377701
10   55   2021-08-08 23:11:15.0962239 +0800 CST m=+0.803725901
11   89   2021-08-08 23:11:15.1765104 +0800 CST m=+0.884012501
12   144   2021-08-08 23:11:15.256839 +0800 CST m=+0.964341001
quit
```