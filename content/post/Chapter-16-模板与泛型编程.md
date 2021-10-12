---
title: Chapter 16 模板与泛型编程
date: 2021-01-07 
tags: 
    - C++
categories: 
    - 学习
---

参考内容: `C++ Primer`, [现代C++教程](https://changkun.de/modern-cpp/zh-cn/02-usability/index.html#2-5-%E6%A8%A1%E6%9D%BF), 

<!--more-->

# 函数模板

## 模板类型参数

```C++
template <typename T, typename U>
T calculate(const T&, const U&)
```

这个例子中，模板参数是**类型参数(type parameter)**，已经比较熟悉了。

## 非类型模板参数

除了定义类型参数，还可以在模板中定义非类型参数（nontype parameter）。一个非类型参数表示一个值而非一个类型。我们通过一个特定的类型名而非关键字 `class` 或 `typename`来指定非类型参数。

当一个模板被实例化时，非类型参数被一个用户提供的或编译器推断出的值所代替。这些值必须是**常量表达式**，从而允许编译器在编译时实例化模板。

> 常量表达式:	
>
> - 经过`const`限定的表达式或对象
> - 经过`constexpr`限定的表达式或对象
> - 字面量，比如算术类型、引用、指针。

```C++
template<unsigned N, unsigned M>
int compare(const char (&p1)[N], const char (&p2)[M]){
    return strcmp(p1, p2);
}
```

当我们调用这个版本的 compare 时∶

```C++
compare ("hi","mom")
```

编译器会使用字面常量的大小来代替N和M，从而实例化模板。记住，编译器会在一个字符串字面常量的末尾插入一个空字符作为终结符，因此编译器会实例化出如下版本∶

```C++
int compare(const char (&pl)[3],const char(&p2)[4])
```

> 非类型模板参数的模板实参必须是常量表达式

函数模板可以被`inline`和`constexpr`修饰。例如：

```C++
template <typename T>
inline T min(const T&, const T&);

template <typename T>
constexpr T min(const T&, const T&);
```



## 模板编译过程

当编译器遇到一个模板定义时，它并不生成代码。只有当我们实例化出模板的一个特定版本时，编译器才会生成代码。当我们使用（而不是定义）模板时，编译器才生成代码，这一特性影响了我们如何组织代码以及错误何时被检测到。

通常，当我们调用一个函数时，编译器只需要掌握函数的声明。类似的，当我们使用一个类类型的对象时，类定义必须是可用的，但成员函数的定义不必已经出现。因此，我们将类定义和函数声明放在头文件中，而普通函数和类的成员函数的定义放在源文件中。模板则不同∶ 为了生成一个实例化版本，编译器需要掌握**函数模板或类模板成员函数的定义**。因此，与非模板代码不同，模板的头文件通常既包括声明也包括定义。



# 类模板

与函数模板的不同之处是，编译器不能为类模板推断模板参数类型。下面直接给出一个模板类的定义。

```C++
template<typename T>
class Blob {
public:
    typedef T value_type;
    typedef typename std::vector<T>::size_type size_type;

    Blob();

    Blob(std::initializer_list<T> il);

    size_type size() const { return data->size(); }

    bool empty() const { return data->empty(); }

    void push_back(const T &t) { data->push_back(t); }

    void push_back(T &&t) { data->push_back(std::move(t)); }

    void pop_back();

    T &back();

    T &operator[](size_type u);

private:
    std::shared_ptr<std::vector<T>> data;

    void check(size_type i, const std::string &msg) const;
};

template<typename T>
void Blob<T>::check(Blob::size_type i, const string &msg) const {
    if (i >= data->size())
        throw std::out_of_range(msg);
}

template<typename T>
T &Blob<T>::back() {
    check(0, "back on empty Blob");
    return data->back();
}

template<typename T>
T &Blob<T>::operator[](Blob::size_type u) {
    check(u, "subscript out of range");
    return (*data)[u];
}

template<typename T>
void Blob<T>::pop_back() {
    check(0, "back on empty Blob");
    data->pop_back();
}

/**
 * 此构造函数分配一个新的 vector。在本例中，我们用参数il来初始化此 vector。
 * 为了使用这个构造函数，我们必须传递给它一个initializer_1ist，
 * 其中的元素必须与Blob的元素类型兼容
 * @tparam T
 * @param il
 */
template<typename T>
Blob<T>::Blob(initializer_list<T> il): data(std::make_shared<std::vector<T>>(il)) {}

/**
 * 这段代码在作用域Blob<T>中定义了名为Blob的成员函数。此构造函数分配一个空 vector，并将指向 vector的指针保存在 data中。
 * @tparam T
 */
template<typename T>
Blob<T>::Blob(): data(std::make_shared<std::vector<T>>()) {}
```

在该`Blob`中的私有成员`data`中，使用了[智能指针](https://changkun.de/modern-cpp/zh-cn/05-pointers/index.html#5-2-std-shared-ptr)。

```C++
template<typename T>
class BlobPtr {
public:
    BlobPtr() : curr(0) {}

    BlobPtr(Blob<T> &a, size_t sz = 0) : wptr(a.data), curr(sz) {}

    T &operator*() const {
        auto p = check(curr, "dereference past end");
        return (*p)[curr];
    }

    BlobPtr &operator++();

    BlobPtr &operator--();


private:
    std::shared_ptr<std::vector<T>> check(std::size_t, const std::string &) const;

    std::weak_ptr<std::vector<T>> wptr;
    std::size_t curr;

};


template<typename T>
BlobPtr<T> &BlobPtr<T>::operator++() {
    BlobPtr ret = *this;
    ++*this;
    return ret;
}

```

在函数体内，我们已经进入类的作用域，因此在定义 ret 时无须重复模板实参。如果不提供模板实参，则编译器将假定我们使用的类型与成员实例化所用类型一致。因此，ret 的定义与如下代码等价∶

`BlobPtr<T> ret `

