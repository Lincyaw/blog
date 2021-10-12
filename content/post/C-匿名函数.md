---
title: C++匿名函数
date: 2020-10-07 
tags: 
    - 算法
    - C++
categories: 
    - 学习
---

在做[354. 俄罗斯套娃信封问题](https://leetcode-cn.com/problems/russian-doll-envelopes/)时在思考如何给`sort()`加个判断的函数。自己不是很想新写一个函数来用于判断，想着要是有个匿名函数就好了，结果发现是自己孤陋寡闻了QAQ 然后才反应过来在qt中自己就已经用过匿名函数了, 不过时间有点久了忘了...    经典的中括号小括号大括号

<!--more-->

# sort

先了解一下`sort`函数

`sort(begin, end, cmp)`，其中`begin`为指向待`sort()`的数组的第一个元素的指针，`end`为指向待`sort()`的数组的**`最后一个元素的下一个位置`**的指针，`cmp`参数为排序准则，如果没有的话，默认以非降序排序。

## 自定义cmp参数

```cpp
#include <iostream>
#include <algorithm>
using namespace std;
bool cmp(int x, int y) {
    return x > y;
}
int main() {
    int a[5] = {1, 3, 4, 2, 5};
    sort(a, a + 5, cmp);
    for (int i = 0; i < 5; i++) cout << a[i] << ' ';
    return 0;
}
```

输出结果为：`5 4 3 2 1`





# 匿名函数

匿名函数的基本语法为：

```c++
//[捕获列表](参数列表)->返回类型{函数体}
int main()
{
	auto Add = [](int a, int b)->int {
		return a + b;
	};
	std::cout << Add(1, 2) << std::endl;
	return 0;
}
```

这个返回类型和rust的有点像, 但是也可以不填返回类型, 编译器一般来说能能够自动推断出来

```c++
//[捕获列表](参数列表)->返回类型{函数体}
int main()
{
	auto Add = [](int a, int b) {
		return a + b;
	};
	std::cout << Add(1, 2) << std::endl;
	return 0;
}
```

## 捕获列表

试图在Lambda内使用外部变量是错误的，例如：

```c++
#include <iostream>

int main()
{
	int c = 12;
	auto Add = [](int a, int b)->int {
		return c;
	};
	std::cout << Add(1, 2) << std::endl;
	return 0;
}
```

但是有些时候我们需要使用外部变量，所以需要使用捕获列表，上述代码改写成一下形式便可以通过编译。

```c++
#include <iostream>

int main()
{
	int c = 12;
	auto Add = [c](int a, int b)->int {
		return c;
	};
	std::cout << Add(1, 2) << std::endl;
	return 0;
}
```

但是如果你更改一下lambda表达式中代码块的内容，比如在上述代码中添加一句

```c++
c = a;
```

这样又会无法编译通过了，因为你的c是按值传递的，所以要将捕获列表改成

```c++
[&c](int a, int b)->int{……}；
```

这样c的值便是按引用传递了，便可以进行修改。

补充知识：

1. 如果捕获列表为[&]，则表示所有的外部变量都按引用传递给lambda使用
2. 如果捕获列表为[=]，则表示所有的外部变量都按值传递给lambda使用
3. 匿名函数构建的时候对于按值传递的捕获列表，会立即将当前可以取到的值拷贝一份作为常数，然后将该常数作为参数传递，即：

```c++
int main()
{
	int c = 12;
    //Add构建的时候实际是：[12](int a,int b)->int{}
	auto Add = [c](int a, int b)->int {
		return c;
	};
	std::cout << Add(1, 2) << std::endl;
	return 0;
}
```





|                     | 捕获列表参数一览                                             |
| :-----------------: | :----------------------------------------------------------- |
|       [names]       | names是一个逗号分隔的名字列表，这些名字都是Lambda所在函数的局部变量。默认情况下，这些变量会被拷贝，然后按值传递，名字前面如果使用了&，则按引用传递 |
|         [&]         | 隐式捕获列表，Lambda体内使用的局部变量都按引用方式传递       |
|         [=]         | 隐式捕获列表，Lanbda体内使用的局部变量都按值传递             |
| [&,identifier_list] | identifier_list是一个逗号分隔的列表，包含0个或多个来自所在函数的变量，这些变量采用值捕获的方式，其他变量则被隐式捕获，采用引用方式传递，identifier_list中的名字前面不能使用&。 |
| [=,identifier_list] | identifier_list中的变量采用引用方式捕获，而被隐式捕获的变量都采用按值传递的方式捕获。identifier_list中的名字不能包含this，且这些名字面前必须使用&。 |
|         []          | 空捕获列表，Lambda不能使用所在函数中的变量。                 |





# 函数对象包装器 std::funtion

> 引用自[现代C++教程]([https://changkun.de/modern-cpp/zh-cn/03-runtime/index.html#3-2-%E5%87%BD%E6%95%B0%E5%AF%B9%E8%B1%A1%E5%8C%85%E8%A3%85%E5%99%A8](https://changkun.de/modern-cpp/zh-cn/03-runtime/index.html#3-2-函数对象包装器))

C++11的`std::function`是一种通用、多态的函数封装， 它的实例可以对任何可以调用的目标实体进行存储、复制和调用操作， 它也是对 C++中现有的可调用实体的一种类型安全的包裹（相对来说，函数指针的调用不是类型安全的）， 换句话说，就是函数的容器。当我们有了函数的容器之后便能够更加方便的将函数、函数指针作为对象进行处理。

如下面的代码:

```C++
#include <functional>
#include <iostream>

int foo(int para) {
    return para;
}

int main() {
    // std::function 包装了一个返回值为 int, 参数为 int 的函数
    std::function<int(int)> func = foo;

    int important = 10;
    std::function<int(int)> func2 = [&](int value) -> int {
        return 1+value+important;
    };
    std::cout << func(10) << std::endl;
    std::cout << func2(10) << std::endl;
}
```



## std::bind和std::placeholder

而 `std::bind` 则是用来绑定函数调用的参数的， 它解决的需求是我们有时候可能并不一定能够一次性获得调用某个函数的全部参数，通过这个函数， 我们可以将部分调用参数提前绑定到函数身上成为一个新的对象，然后在参数齐全后，完成调用。 例如：

```c++
#include <iostream>
#include <functional>
using namespace std;
int foo(int a, int b, int c) {
    cout<<a<<" "<<b<<" "<<c<<endl;
    return a+b+c;
}
int main() {
    // 将参数1,2绑定到函数 foo 上，但是使用 std::placeholders::_1 来对第一个参数进行占位
    auto bindFoo = std::bind(foo, 1, std::placeholders::_1,2);
    cout<<bindFoo(2)<<endl;
    auto bindFoo2 = std::bind(foo, 1, std::placeholders::_4,2);
    cout<<bindFoo2(9,2,3,5)<<endl;
}
```

`std::placeholders::_4`表示输入的第四个参数是作为调用`foo`的第二个参数(因为在第二个参数的位置)

上述代码的结果为:

```C++
1 2 2
5
1 5 2
8
```

