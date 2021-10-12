---
title: Chapter 15 面向对象程序设计
date: 2020-12-05 
tags: 
    - C++
    - 虚函数
categories: 
    - 学习
---

在C++语言中，基类将**类型相关的函数**与派生类**不做改变直接继承的函数**区分对待。对于某些函数，基类希望它的派生类各自定义适合自身的版本，此时基类就将这些函数声明成虚函数( virtual function)。

<!--more-->

# 简介

```c++
class Quote {
public:
    virtual double net_price(std::size_t n) const;
};
```

```C++
class Bulk_quote: public Quote {
public:
    double net_price(std::size_t n) const override;
};
```

考虑下面的一段代码：

```C++
double print_total(const Quote &item，size_t n){
    double ret = item.net_price(n);
    return ret;
}
```

暂时不考虑代码是否能正常运行，思考当传入的`item`分别是`Quote`的对象，以及`Bulk_quote`的对象时发生的事。

答案是:

​	由于函数`print_total`的`item`形参是基类`Quote`的一个引用，所以我们既能使用基类的对象调用该函数，也能用派生类的对象调用该函数。而具体函数里调用的`net_price`函数的版本取决于传入的`item`对象的类型。这被称为**运行时绑定**（动态绑定） run-time binding.

# 定义基类和派生类

## 定义基类

```c++
class Quote {
public:
    Quote() = default;
    // clang++提示: pass by value， and use std::move
    // 原书代码: bookNo(book)
    Quote(std::string book，double sales_price): bookNo(std::move(book))， price(sales_price){}
    std::string isbn() const;
    virtual double net_price(std::size_t n) const;
    virtual ~Quote() = default;
private:
    std::string bookNo;
protected:
    double price = 0.0;
};
```

> 为什么使用`std::move`需参考[右值引用]([https://changkun.de/modern-cpp/zh-cn/03-runtime/index.html#3-3-%E5%8F%B3%E5%80%BC%E5%BC%95%E7%94%A8](https://changkun.de/modern-cpp/zh-cn/03-runtime/index.html#3-3-右值引用))

这里插入一点`const`的知识：

1. `const`成员函数不能修改成员变量的值，除非有`mutable`修饰；只能访问成员变量。
2. 不能调用非常量成员函数，以防修改成员变量的值。

总结一下就是进行的任何操作都不能有改变成员变量的值的机会。



在基类中，我们希望派生类定义各自的`net_price`函数，因此派生类需要访问`Quote`的`price`成员，所以将`price`定义为`protected`。而派生类访问`bookNo`成员的方式与其他用户是一样的，都是通过调用`isbn`函数，所以`bookNo`被定义为私有的，即使`Quote`派生出来的类也不能访问他。

### 回顾public\private\protected

有public， protected， private三种继承方式，它们相应地改变了基类成员的访问属性。

- **public 继承：**基类 public 成员，protected 成员，private 成员的访问属性在派生类中分别变成：public， protected， private
- **protected 继承：**基类 public 成员，protected 成员，private 成员的访问属性在派生类中分别变成：protected， protected， private
- **private 继承：**基类 public 成员，protected 成员，private 成员的访问属性在派生类中分别变成：private， private， private

但无论哪种继承方式，上面两点都没有改变：

- **private** 成员只能被本类成员（类内）和友元访问，不能被派生类访问；
- **protected** 成员可以被派生类访问。

| 继承方式      | 基类的public成员  | 基类的protected成员 | 基类的private成员 | 继承引起的访问控制关系变化概括         |
| :------------ | :---------------- | :------------------ | :---------------- | :------------------------------------- |
| public继承    | 仍为public成员    | 仍为protected成员   | 不可见            | 基类的非私有成员在子类的访问属性不变   |
| protected继承 | 变为protected成员 | 变为protected成员   | 不可见            | 基类的非私有成员都为子类的保护成员     |
| private继承   | 变为private成员   | 变为private成员     | 不可见            | 基类中的非私有成员都称为子类的私有成员 |

## 定义派生类

上面的`Quote`基类将`net_price`定义为虚函数，表明派生类必须重写上述函数。（通过后面虚函数的工作原理的例子，好像不是必须要重写，可以进行操作）

```C++
class Bulk_quote: public Quote {
public:
    Bulk_quote() = default;
    Bulk_quote(const std::string&， double，std::size_t，double );
    double net_price(std::size_t n) const override;
private:
    std::size_t min_qty = 0;
    double discount = 0.0;
};
```

`Bulk_quote`是公有继承了`Quote`类，因此可以将`Bulk_quote`的对象当做`Quote`的对象来使用。

注意，在函数末尾添加了`override`关键字后，即说明该派生类使用该成员函数改写基类的的虚函数。

### 派生类对象及派生类向基类的类型转换

再次说明简介中的代码为什么能**动态绑定**：

如果一个派生是公有的，则基类的公有成员也是派生类接口的组成部分。此外，我们能**将公有派生类型的对象绑定到基类的引用或指针上**。因为我们在派生列表中使用了`public`，所以`Bulk_quote`的接口隐式地包含`isbn`函数，同时再任何需要`Quote`的引用或指针的地方我们都能使用`Bulk_quote`的对象。(注意: 只有表达式是引用或者是指针时才会发生类型转换， **即基类的指针或引用的静态类型可能与其动态类型不一致**)

这称为**派生类到基类的类型转换**(**derived-to-base** 编译器隐式执行。

### 派生类构造函数

虽然派生类对象中含有从基类继承而来的成员，但是派生类不能直接初始化这些成员，必须使用基类的构造函数来初始化他的基类部分。

设计一个接受4个参数的`Bulk_quote`构造函数如下所示:

```C++
Bulk_quote(const std::string& book， double p，
          std::size_t qty， double disc) : Quote(book，p)， min_qty(qty)， discount(disc) {}
```

该函数将它的前两个参数(分别表示ISBN和价格)传递给`Quote`的构造函数，由 `Quote`的构造函数负责初始化`Bulk _quote`的基类部分（即` bookNo`成员和 `price `成员)。当(空的）`Quote`构造函数体结束后，我们构建的对象的**基类部分**也就完成初始化了。

接下来初始化由派生类直接定义的`min_qty`成员和`discount`成员。最后运行`Bulk_quote`构造函数的（空的）函数体。
除非我们特别指出，否则派生类对象的基类部分会像数据成员一样执行默认初始化。如果想使用其他的基类构造函数，我们需要以类名加圆括号内的实参列表的形式为构造函数提供初始值。这些实参将帮助编译器决定到底应该选用哪个构造函数来初始化派生类对象的基类部分。

# 虚函数

如上所说，当我们使用基类的引用或指针调用一个虚成员函数时会执行**动态绑定**。因为我们直到运行时才能知道到底调用了哪个版本的虚函数，所以所有虚函数必须有定义。通常情况下，如果我们不使用某个函数，就不需要为该函数提供定义。但是我们要为每个虚函数都提供定义，不管他们是否会用到。

>  再次注意：动态绑定只有当我们通过指针或引用调用虚函数时才会发生。
>
> 当且仅当对通过指针或引用调用虚函数时，才会在运行时解析该调用，也只有在这种情况下对象的动态类型才有可能与静态类型不同。

## 派生类中的虚函数

一个派生类的函数如果覆盖了某个继承而来的虚函数，那么它的形参类型必须与被他覆盖的基类函数完全一致。

同样，派生类的虚函数类型也必须与基类函数匹配。但是有一个例外，当类的虚函数返回类型是类本身的指针或引用时，上述规则无效。换句话说，如果D由B派生得到，则基类的虚函数可以返回B\*而派生类的对应函数可以返回D\*，前提是D到B的类型转换是可访问的。

## final和override说明符

override说明符显式指定该函数为覆盖的虚函数

final说明符指定该函数不能再被覆盖

## 虚函数的工作原理

> C++ Primer Plus 504页 && [CSDN](https://blog.csdn.net/lihao21/article/details/50688337)

通常，编译器处理虚函数的方法是∶给每个对象添加一个隐藏成员。隐藏成员中保存了一个**指向函数地址数组的指针**。这种数组称为**虚函数表**（vitual function table，vtbl）。虚函数表中存储了为类对象进行声明的虚函数的地址。

例如，**基类对象**包含一个指针，该指针指向**基类**中所有虚函数的地址表。**派生类对象**将包含一个指向独立地址表的指针。如果**派生类**提供了虚函数的新定义，该虚函数表将保存新函数的地址;如果**派生类**没有重新定义虚函数，该`vtbl`将保存函数原始版本的地址。如果**派生类**定义了新的虚函数，则该函数的地址也将被添加到`vtbl`中。注意，无论类中包含的虚函数是1个还是 10个，都只需要在对象中添加1个地址成员，只是表的大小不同而已。

虚表是属于**类**的，而**不属于**某个具体的对象，一个类只需要一个虚表即可。同一个类的所有对象都使用同一个虚表。 如上所说，为了指定对象的虚表，对象内部包含一个虚表的指针，来指向自己所使用的虚表。**为了让每个包含虚表的类的对象都拥有一个虚表指针**，编译器在类中添加了一个指针`*__vptr`，用来指向虚表。这样，当类的对象在创建时便拥有了这个指针，且这个指针的值会自动被设置为指向类的虚表。

为了方便，下面给出博文中修改后的代码（原博中代码版本已经有点旧了）

```C++
class A {
public:
    virtual void vfunc1(){
        cout<<"A's vfunc1"<<endl;
    };
    virtual void vfunc2() {
        cout<<"A's vfunc2"<<endl;
    };
    void func1(){
        cout<<"A's func1"<<endl;
    };
    void func2(){
        cout<<"A's func2"<<endl;
    };
};

class B : public A {
public:
    void vfunc1() override{
        cout<<"B's vfunc1"<<endl;
    }
    void func2(){
        cout<<"B's func2"<<endl;
    };
};

class C: public B {
public:
    void vfunc2() override{
        cout<<"C's vfunc2"<<endl;
    }
    void func2(){
        cout<<"C's func2"<<endl;
    };
};
```

下面运行以下代码:

```C++
int main() {
    B bOb;
    bOb.vfunc1();
    bOb.vfunc2();
    bOb.func1();
    bOb.func2();
    return 0;
}
```

运行结果为:

```C++
B's vfunc1
A's vfunc2
A's func1
B's func2
```

很显然，结果和我们想象的一样。B重写了A的`vfunc1`，因此调用的是B重写后的函数。B又写了一个和A一样的`func2`，所以结果是B写的函数的结果。但是这里不提倡这种行为，编译器会提醒如下，意思就是建议我们把A中的`func2`改成虚函数。

```C++
Clang-Tidy: Function 'func2' hides a non-virtual function from class 'A'
```

再看下面的代码，唯一不同是修改了第2和3行的代码

```C++
int main() {
    B bOb2;
    A &bOb = bOb2;
    bOb.vfunc1();
    bOb.vfunc2();
    bOb.func1();
    bOb.func2();
    return 0;
}
```

运行结果为，体现了动态绑定的特性。B重写了`vfunc1`，使用A类型去通过引用来调用B对象中的`vfunc1`，从而使得调用的`vfunc1`是B类中的`vfunc1`.

```C++
B's vfunc1
A's vfunc2
A's func1
A's func2
```

将B替换为C，运行以下代码

```C++
int main() {
    C bOb;
    bOb.vfunc1();
    bOb.vfunc2();
    bOb.func1();
    bOb.func2();
    return 0;
}
```

```C++
// 结果
B's vfunc1
C's vfunc2
A's func1
C's func2
```

```C++
int main() {
    C bOb2;
    A &bOb = bOb2;
    bOb.vfunc1();
    bOb.vfunc2();
    bOb.func1();
    bOb.func2();
    return 0;
}
```
```C++
// 结果
B's vfunc1
C's vfunc2
A's func1
A's func2
```

现在我们对调用的结果有了一些了解，接下来开始看虚函数表的构造图。
当B和C还没有重写虚函数时，虚函数表是长这样的。类A，B，C都指向了A的虚函数。

<img src="http://lincyaw.xyz/images/vtbl0.png" alt="图1" style="zoom:40%;" />

由于B重写了A的vfunc1，C继承了B，又重写了B的vfunc2（即重写了A的vfunc2），所以此时的指向应该如下

<img src="http://lincyaw.xyz/images/vtbl1.png" alt="图1" style="zoom:40%;" />

这个现象其实很好理解，儿子只会去改爸爸的虚函数，而爸爸才是去改爷爷的虚函数的。

而一个对象通过指针可以找到这个类的虚表，从而找到自己对应的虚函数。不管是下面的哪种场景，虽然**bOb**是**基类**的**指针（引用）**，只能指向基类的部分，但是虚表指针亦属于基类部分。所以`bOb`可以访问到对象`bOb2`的虚表指针。`bOb2`的虚表指针指向类`B`的虚表，所以`bOb`可以访问到类`B(或C`)的`vtbl`。

```C++
// 1
B bOb2;
A &bOb = bOb2;
// 2
C bOb2;
B &bOb = bOb2;
// 3
C bOb2;
A &bOb = bOb2;
// 4
C bOb2;
A *bOb = &bOb2;
```



# 抽象基类

当我们定义出一个抽象的类型，并且不希望用户能够创建一个对象时，可以将该类的一个或者多个函数定义为纯虚函数(**pure virtual**).

**含有(或者未经覆盖直接继承)纯虚函数的类**是**抽象基类**。抽象基类负责定义接口，而后续的其他类可以覆盖该接口。



# 访问控制与继承

## protected

可以看做是`public`和`private`中和后的产物。

- 与私有成员类似： 受保护的成员对于类的用户来说是不可访问的
- 与公有成员类似：受保护的成员对于派生类的成员和友元来说是可访问的
- 派生类的成员或友元只能通过**派生类对象**来访问**基类的受保护成员**。派生类对于**一个基类对象中的受保护成员**没有任何访问权限。

考虑如下代码，观察有什么问题:

```C++
class Base{
protected:
    int prot_mem;
};
class Sneaky: public Base{
    friend void clobber(Sneaky&);   // 能访问Sneaky::prot_mem
    friend void clobber(Base&);     // 不能访问Base::prot_mem
    int j;
};
// 正确: 能访问Sneaky对象的private和protected成员
void clobber(Sneaky &s){
    s.j = s.prot_mem = 0;
}
// 错误: 不能访问Sneaky对象的protected成员
void clobber(Base &b){
    b.prot_mem =0;
}
```

> 派生类的成员和友元只能访问**派生类对象中**的**基类部分的受保护成员**; 对于普通的基类对象中的成员不具有特殊的访问权限

如果派生类(及其友元)能够访问基类的受保护成员，而**不是**派生类对象中的基类部分的受保护成员，则上面的第二个`clobber`将是合法的.该函数不是`Base`的友元，但他仍然能够改变一个`Base`对象的内容。

## 公有、私有和受保护继承

| 继承方式      | 基类的public成员  | 基类的protected成员 | 基类的private成员 | 继承引起的访问控制关系变化概括         |
| :------------ | :---------------- | :------------------ | :---------------- | :------------------------------------- |
| public继承    | 仍为public成员    | 仍为protected成员   | 不可见            | 基类的非私有成员在子类的访问属性不变   |
| protected继承 | 变为protected成员 | 变为protected成员   | 不可见            | 基类的非私有成员都为子类的保护成员     |
| private继承   | 变为private成员   | 变为private成员     | 不可见            | 基类中的非私有成员都称为子类的私有成员 |

## 派生类向基类转换的可访问性

假设D继承自B

- 只有当D**公有地继承**B时，用户代码才能使用派生类向基类的转换；如果D继承B的方式是受保护的或者私有的，则用户代码不能使用该转换
- 不论D以什么方式继承B，D的**成员函数和友元**都能使用派生类向基类的转换；**派生类**向其**直接基类**的类型转换**对于派生类的成员和友元**来说是可访问的。
- 如果D继承B的方式是**公有的或者受保护**的，则D的**派生类的成员和友元**可以使用D向B的类型转换；反之，如果D继承B的方式是私有的，则不能使用。





