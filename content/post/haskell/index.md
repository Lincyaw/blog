---
title: "Haskell 入个门"
date: 2021-10-10T11:36:04+08:00
draft: false
image: "method-draw-image.svg"
slug: hashkell
description: "体会一下函数式编程思想"
categories:
    - 学习
tags:
    - functional programming
---

## 环境配置

初学者最简单的方法是安装 haskell stack。

```sh
curl -sSL https://get.haskellstack.org/ | sh
or 
wget -qO- https://get.haskellstack.org/ | sh
```

但是因为墙的原因，可能下载不了，因此我直接将这段 [shell 脚本](./install.sh)复制到自己的服务器上了。

安装完成之后，输入 `stack ghci` 进入交互式命令行，类似于 bash 这类的 shell，或者是 python 的交互式窗口。

`:l` 可以装载对应的文件，比如：

add.hs 中的内容如下

```haskell
doubleMe x = x + x 
doubleUs x y = x*2 + y*2  
```

编译这个文件，并且运行一下 doubleMe 这个函数。

```haskell
Prelude> :l add.hs
[1 of 1] Compiling Main             ( add.hs, interpreted )
Ok, one module loaded.
*Main> doubleMe 3
6
```

输入 `:q` 退出。

到此为止，一个非常简单的程序示例就完成了。之后我的学习步骤是：

1. 看语法
2. 同时在[这个网站](https://exercism.org/tracks/haskell/exercises)上做一些习题，练习语法。

道理很简单，就是中学时候的看教材、做练习。函数式对于我个人而言，也没有写实际项目的需求，所以怎么开心怎么来~。

## Haskell's interesting Problem

### Pangram

判断一个字符串是否包含了所有 26 个字母，函数签名：`isPangram :: String -> Bool`

```haskell
module Pangram (isPangram) where

import Data.Char (toLower)
isPangram :: String -> Bool
isPangram xs = all (`elem` fixedText) ['a'..'z']
  where fixedText = map toLower xs
```

这段代码用到了 `all`, `elem`, `map`，以及 Data.Char 包中的 toLower 函数。

- `all predicate list`，如果 list 中的所有的元素都满足 predicate 这个谓词，则返回 true，否则返回 false。
- `map toLower xs`，将 toLower 这个函数应用到 list 中的每一个元素，本题的语义就是将输入的参数 xs 全部变成小写，并且赋值给 fixedText。
- ```a `elem` b```，b 中包含 a，则返回 true，否则返回 false。

难点是怎么理解 ```all (`elem` fixedText) ['a'..'z']``` 这句话

(func arg2) 是一个不全调用的函数，在这里就是将 fixedText 作为 elem 这个函数的第二个参数，而第一个函数缺省。(func arg2) 这个带括号的返回的是一个函数，这个函数接受的一个参数就是 arg1。将这两个函数组合调用后，最终的结果实际上就是 `arg1 func arg2` 这样的调用流程。

所以 `all (`elem` fixedText) ['a'..'z']` 的意思是对于 'a','b',...'z' 这 26 个字母，如果全都在 fixedText 中，则返回 true，否则返回 false。

具体的 curry 函数和不完全调用可以看这篇[文章](https://www.w3cschool.cn/hsriti/1u6f2ozt.html)

## Haskell CheatSheet

### List

取 list 第一个

```haskell
ghci> head [5,4,3,2,1]  
5
```

取 list 第一个之后的

```haskell
ghci> tail [5,4,3,2,1]   
[4,3,2,1]  
```

取 list 的最后一个

```haskell
ghci> last [5,4,3,2,1]   
1  
```

取除了最后一个之外的部分

```haskell
ghci> init [5,4,3,2,1]   
[5,4,3,2]  
```

length 返回长度

```haskell
ghci> length [5,4,3,2,1]   
5 
```

reverse 翻转 list

```haskell
ghci> reverse [5,4,3,2,1]   
[1,2,3,4,5] 
```

take返回一个List的前几个元素

```haskell
ghci> take 3 [5,4,3,2,1]   
[5,4,3]  
ghci> take 0 [6,6,6]  
[] 
```

drop 会删除一个List中的前几个元素

```haskell
ghci> drop 3 [8,4,2,1,5,6]   
[1,5,6]   
```

maximum, minimum 返回最大最小的

```haskell
ghci> minimum [8, 4, 2, 1, 5, 6]   
1   
ghci> maximum [1, 9, 2, 3, 4]   
9  
```

sum返回一个List中所有元素的和。product返回一个List中所有元素的积。

```haskell
ghci> sum [5,2,1,6,3,2,5,7]   
31   
ghci> product [6,2,1,2]   
24   
```

elem判断一个元素是否在包含于一个List，通常以中缀函数的形式调用它。

```haskell
ghci> 4 `elem` [3,4,5,6]   
True   
```

range 区间生成，使用 `..` 符号即可。

```haskell
ghci> ['K'..'Z']   
"KLMNOPQRSTUVWXYZ"
ghci> [1..20]   
[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]   

ghci> [3,6..20]    // 加前两个元素，自动推导序列
[3,6,9,12,15,18]  
```

take 配合 cycle

```haskell
ghci> take 10 (cycle [1,2,3])   
[1,2,3,1,2,3,1,2,3,1]   
ghci> take 12 (cycle "LOL ")   
"LOL LOL LOL "  
```

数学的集合的概念

```haskell
ghci> [x*2 | x <- [1..10]]   
[2,4,6,8,10,12,14,16,18,20]

ghci> [x*2 | x <- [1..10], x*2 >= 12]   
[12,14,16,18,20] 

boomBangs xs = [ if x < 10 then "BOOM!" else "BANG!" | x <- xs, odd x]  

// 两个集合的笛卡尔积
ghci> [ x*y | x <- [2,5,10], y <- [8,10,11]]   
[16,20,22,40,50,55,80,100,110]  

ghci> [ x*y | x <- [2,5,10], y <- [8,10,11], x*y > 50]   
[55,80,100,110]  
```

集合的骚操作：

这个函数将一个 List 中所有元素置换为1，并且使其相加求和。得到的结果便是我们的 List 长度。

```haskell
length' xs = sum [1 | _ <- xs]  
```

除去字符串中所有非大写字母的函数：

```haskell
removeNonUppercase st = [ c | c <- st, c `elem` ['A'..'Z']]  
```

### Tuple

用 `()` 表示元组。使用 Tuple 前应当事先明确一条数据中应该由多少个项。每个不同长度的 Tuple 都是独立的类型，所以你就不可以写个函数来给它追加元素。而唯一能做的，就是通过函数来给一个 List 追加序对，三元组或是四元组等内容。

fst 返回一个**序对**的首项。

```haskell
ghci> fst (8,11)   
8   
ghci> fst ("Wow", False)   
"Wow"
```

snd 返回**序对**的尾项。

```haskell
ghci> snd (8,11)   
11   
ghci> snd ("Wow", False)   
False
```

 zip 可以用来生成一组序对 (Pair) 的 List 。它取两个 List ，然后将它们交叉配对，形成一组序对的 List 。

```haskell
ghci> zip [1,2,3,4,5] [5,5,5,5,5]   
[(1,5),(2,5),(3,5),(4,5),(5,5)]   
ghci> zip [1 .. 5] ["one", "two", "three", "four", "five"]   
[(1,"one"),(2,"two"),(3,"three"),(4,"four"),(5,"five")]
```

由于 haskell 是惰性的，使用 zip 同时处理有限和无限的 List 也是可以的：

```haskell
ghci> zip [1..] ["apple", "orange", "cherry", "mango"]   
[(1,"apple"),(2,"orange"),(3,"cherry"),(4,"mango")]
```

应用题：如何取得所有三边长度皆为整数且小于等于10，周长为 24 的直角三角形？

```haskell
// 列出边长小于 10 的所有的三角形。
ghci> let triangles = [ (a,b,c) | c <-  [1..10], b <-  [1..10], a <- [1..10] ]
// 令 c 是长边，b 是次长边，a 是短边，且这个三角形是直角三角形
ghci> let rightTriangles = [ (a,b,c) | c <- [1..10], b <- [1..c], a <- [1..b], a^2 + b^2 == c^2] 
// 再加上一个限制条件：周长是 24
ghci> let rightTriangles' = [ (a,b,c) | c <- [1..10], b <- [1..c], a <- [1..b], a^2 + b^2 == c^2, a+b+c == 24]  
```
