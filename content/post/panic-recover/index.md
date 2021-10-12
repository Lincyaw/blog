---
title: "Panic Recover"
date: 2021-08-09T16:11:58+08:00
draft: false
image: "go.png"
description: "golang 错误处理"
categories:
    - 学习
tags: 
    - golang
    - 错误处理
---

个人链接汇总：[https://www.lincyaw.xyz](https://www.lincyaw.xyz)

在一些框架的代码中经常能看到错误处理，了解这些东西有助于未来的开发。下面看一段嵌套的 panic recovery 代码。

```go
package main
import (
	"fmt"
	"time"
)
func main() {
	defer fmt.Println("main function end")

	go func() {
		defer func() {
			fmt.Println("in goroutine")
			defer func() {
				defer func() {
					panic("panic again and again")
				}()
				panic("panic again")
			}()

			if err:=recover(); err != nil {
			   fmt.Println(err)
			}
		}()
		panic("go routine occur panic")
	}()

	time.Sleep(1 * time.Second)
}
```

执行结果如下：

```
in goroutine
go routine occur panic
panic: go routine occur panic [recovered]
	panic: panic again
	panic: panic again and again

```

上面的代码示例说明了：

1. panic 可以嵌套
2. 必须在 defer 函数中直接调用recover；不在 defer，或者包装了 recovery 都无法捕获异常

标准库中的json包，在内部递归解析JSON数据的时候如果遇到错误，会通过抛出异常的方式来快速跳出深度嵌套的函数调用，然后由最外一级的接口通过recover捕获panic，然后返回相应的错误信息。

Go语言库的实现习惯: 即使在包内部使用了panic，但是在导出函数时会被转化为明确的错误值。

更详细的可以看下面的两篇文章：

1. [Go语言高级编程](https://chai2010.cn/advanced-go-programming-book/ch1-basic/ch1-07-error-and-panic.html)
2. [Go语言设计与实现](https://draveness.me/golang/docs/part2-foundation/ch05-keyword/golang-panic-recover/#54-panic-%E5%92%8C-recover)