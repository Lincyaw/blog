---
title: 康威生命游戏-rustWebassembly
date: 2020-10-07 
tags: 
    - Rust
categories: 
    - 学习
---

主要参考自[Rust and WebAseembly](https://rustwasm.github.io/docs/book/game-of-life/introduction.html)

目的是作为实现过程中的笔记。

<!--more-->

# 概述

## 前提条件

能够阅读和编写基本的Rust、JavaScript和HTML，不需要非常熟悉。

## 目标人群

为已经有基本的Rust和JavaScript经验的人提供如何一起使用Rust、WebAssembly和JavaScript的教程。

## 通过这个教程能获得什么

- 如何设置Rust工具链，用于编译到WebAssembly。
- 熟悉Rust、WebAssembly、JavaScript、HTML和CSS组成的多语言程序的工作流。
- 如何设计API，以最大限度地利用Rust和WebAssembly的优势以及JavaScript的优势。
- 如何调试从Rust编译的WebAssembly模块。
- 如何对Rust和WebAssembly程序进行调优，使其速度更快。
- 如何调整Rust和WebAssembly程序的大小，使.wasm二进制文件更小，更快地从网络上下载。



## 环境配置

需要rust-toolchain, wasm-pack, cargo-generate, npm。

具体参考[官方教程](https://rustwasm.github.io/docs/book/game-of-life/setup.html)



# 实现Helloworld

由于墙的问题，在配置npm， cargo-generate等环境的时候经常断连，无法下载。在更换镜像源、翻墙等各种操作无果之后，我决定使用[Codespace](https://github.com/features/codespaces/)进行开发(真香!!), 国外的服务器没有墙真是好！



在配置好环境后，就可以用下面的命令下载一个项目模板

```rust
cargo generate --git https://github.com/rustwasm/wasm-pack-template
```

接下来会提示让你输入project name, 在官方教程中使用的名称为`wasm-game-of-life`。

在下载好之后目录结构如下：

```
wasm-game-of-life/
├── Cargo.toml
├── LICENSE_APACHE
├── LICENSE_MIT
├── README.md
└── src
    ├── lib.rs
    └── utils.rs
```

下面介绍一下这些文件的作用:

**Cargo.toml**

rust项目必备文件, 指定了Cargo的依赖关系和元数据。这个文件预先配置了`wasm-bindgen`依赖关系，一些我们稍后会深入研究的可选依赖关系，以及为了生成`.wasm`库而如何正确初始化`crate-type`。



**/src/lib.rs**

src/lib.rs文件是我们要编译成WebAssembly的Rust crate的根,它使用wasm-bindgen与JavaScript进行交互。在这个初始文件里, 他导入了js的`alert()`函数, 并且导出了rust的`greet`函数

```rust
mod utils;

use wasm_bindgen::prelude::*;

// When the `wee_alloc` feature is enabled, use `wee_alloc` as the global
// allocator.
#[cfg(feature = "wee_alloc")]
#[global_allocator]
static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;

#[wasm_bindgen]
extern {
    fn alert(s: &str);
}

#[wasm_bindgen]
pub fn greet() {
    alert("Hello, wasm-game-of-life!");
}
```



**/src/utils.rs**

以后再说



## build

运行`wasm-pack build`, 结束后生成的pkg目录如下:

```
pkg/
├── package.json
├── README.md
├── wasm_game_of_life_bg.wasm
├── wasm_game_of_life.d.ts
└── wasm_game_of_life.js
```

Readme是从主项目中复制来的,其他的是现场生成的。



**wasm_game_of_life_bg.wasm**

.wasm文件是由Rust编译器从我们的Rust源代码中生成的WebAssembly二进制文件，它包含了所有Rust函数和数据的编译到wasm版本。例如，它有一个导出的 "greet "函数。

**wasm_game_of_life.js**

.js文件是由wasm-bindgen生成的，它包含了JavaScript胶水，用于将DOM和JavaScript函数导入到Rust中，并将WebAssembly函数暴露给JavaScript一个不错的API。例如，有一个JavaScript greet函数，它包装了从WebAssembly模块导出的greet函数。现在，这个胶水并没有做什么，但当我们开始在wasm和JavaScript之间来回传递更多有趣的值时，它将帮助牧羊人将这些值越过边界。

```rust
import * as wasm from './wasm_game_of_life_bg';

// ...

export function greet() {
    return wasm.greet();
}

```

**wasm_game_of_life.d.ts**

.d.ts文件中包含了JavaScript胶水的[TypeScript](https://www.typescriptlang.org/)类型声明，如果你使用TypeScript，你可以让你对WebAssembly函数的调用进行类型检查，你的IDE可以提供自动完成和建议。如果你没有使用TypeScript，你可以安全地忽略这个文件。

```.
export function greet(): void;
```

**package.json**

[package.json](https://docs.npmjs.com/files/package.json)文件包含了关于生成的JavaScript和WebAssembly包的元数据。这被npm和JavaScript捆绑程序用来确定不同包之间的依赖关系、包名、版本和其他一系列东西。它帮助我们集成JavaScript工具，并允许我们将我们的包发布到npm。

```
{
  "name": "wasm-game-of-life",
  "collaborators": [
    "Your Name <your.email@example.com>"
  ],
  "description": null,
  "version": "0.1.0",
  "license": null,
  "repository": null,
  "files": [
    "wasm_game_of_life_bg.wasm",
    "wasm_game_of_life.d.ts"
  ],
  "main": "wasm_game_of_life.js",
  "types": "wasm_game_of_life.d.ts"
}
```

## 将其放入web page

在`wasm-game-of-lit`目录里运行`npm init wasm-app www`，创建之后`www`目录下包括:

```
wasm-game-of-life/www/
├── bootstrap.js
├── index.html
├── index.js
├── LICENSE-APACHE
├── LICENSE-MIT
├── package.json
├── README.md
└── webpack.config.js
```

### package.json

这个pack.json预先配置了webpack和webpack-dev-server的依赖，以及对hello-wasm-pack的依赖，它是已经发布到npm的wasm-pack-template初始包的一个版本。

### webpack.config.js

这个文件配置了webpack和它的本地开发服务器。它是预先配置好的，你不需要调整这个文件就可以让webpack和它的本地开发服务器工作。

### index.html

这是网页的HTML根文件。除了加载bootstrap.js之外，它并没有做太多其他的事情，bootstrap.js是index.js的一个非常薄的封装器。

### index.js

index.js是我们网页的JavaScript的主要入口。它导入了hello-wasm-pack npm包，其中包含了默认的wasm-pack-template的编译WebAssembly和JavaScript胶水，然后它调用hello-wasm-pack的greet函数。

```rust
import * as wasm from "hello-wasm-pack";

wasm.greet();
```

## 安装依赖

进入`www/`目录, 执行`npm install`,这个命令只需要运行一次，就可以安装webpack JavaScript bundler和它的开发服务器。



在`www`中用`wasm-game-of-life`包

我们想要用`wasm-game-of-life`去替换npm中的`hello-wasm-pack`包。

打开`wasm-game-of-life/www/package.json`, 在"devDependencies"的**旁边**, 添加`"dependencies"`字段, 向下面这样:

```json
{
  // ...
  "dependencies": {                     // Add this three lines block!
    "wasm-game-of-life": "file:../pkg"
  },
  "devDependencies": {
    //...
  }
}
```

然后在`wasm-game-of-life/www/index.js`文件中导入`wasm-game-of-life`, 把`hello-wasm-pack`删掉

```rust
import * as wasm from "wasm-game-of-life";

wasm.greet();
```

因为我们声明了新的以来, 所以要安装一下

```javascript
npm install
```

## 在本地开启服务

接下来，为开发服务器打开一个新的终端。在新的终端中运行服务器，我们可以让它在后台运行，并且不会阻止我们在此期间运行其他命令。在新的终端中，从`wasm-game-of-life/www`目录下运行这个命令。

```
npm run start
```

![Screenshot](https://rustwasm.github.io/docs/book/images/game-of-life/hello-world.png)





# [游戏规则介绍]([https://zh.wikipedia.org/wiki/%E5%BA%B7%E5%A8%81%E7%94%9F%E5%91%BD%E6%B8%B8%E6%88%8F](https://zh.wikipedia.org/wiki/康威生命游戏))

生命游戏中，对于任意细胞，规则如下：

- 每个细胞有两种状态 - 存活或死亡，每个细胞与以自身为中心的周围**八格**细胞产生互动（如图，黑色为存活，白色为死亡）
- 当前细胞为存活状态时，当周围的存活细胞低于2个时（不包含2个），该细胞变成死亡状态。（模拟生命数量稀少）
- 当前细胞为存活状态时，当周围有2个或3个存活细胞时，该细胞保持原样。
- 当前细胞为存活状态时，当周围有超过3个存活细胞时，该细胞变成死亡状态。（模拟生命数量过多）
- 当前细胞为死亡状态时，当周围有3个存活细胞时，该细胞变成存活状态。（模拟繁殖）

可以把最初的细胞结构定义为种子，当所有在种子中的细胞**同时**被以上规则处理后，可以得到第一代细胞图。按规则继续处理当前的细胞图，可以得到下一代的细胞图，周而复始。

## 概述

生命游戏是一个[零玩家游戏](https://zh.wikipedia.org/wiki/零玩家遊戲)。它包括一个[二维](https://zh.wikipedia.org/wiki/二維)[矩形](https://zh.wikipedia.org/wiki/矩形)[世界](https://zh.wikipedia.org/wiki/世界)，这个世界中的每个方格居住着一个活着的或死了的[细胞](https://zh.wikipedia.org/wiki/细胞)。一个细胞在下一个时刻生死取决于相邻八个方格中活着的或死了的细胞的数量。如果相邻方格活着的细胞数量过多，这个细胞会因为资源匮乏而在下一个时刻死去；相反，如果周围活细胞过少，这个细胞会因太孤单而死去。实际中，玩家可以设定周围活细胞的数目怎样时才适宜该细胞的生存。如果这个数目设定过高，世界中的大部分细胞会因为找不到太多的活的邻居而死去，直到整个世界都没有生命；如果这个数目设定过低，世界中又会被生命充满而没有什么变化。

实际中，这个数目一般选取2或者3；这样整个生命世界才不至于太过荒凉或拥挤，而是一种动态的平衡。这样的话，游戏的规则就是：当一个方格周围有2或3个活细胞时，方格中的活细胞在下一个时刻继续存活；即使这个时刻方格中没有活细胞，在下一个时刻也会“[诞生](https://zh.wikipedia.org/w/index.php?title=诞生&action=edit&redlink=1)”活细胞。

在这个游戏中，还可以设定一些更加复杂的规则，例如当前方格的状况不仅由父一代决定，而且还考虑祖父一代的情况。玩家还可以作为这个世界的“[上帝](https://zh.wikipedia.org/wiki/上帝)”，随意设定某个方格细胞的死活，以观察对世界的影响。

在游戏的进行中，杂乱无序的细胞会逐渐演化出各种精致、有形的结构；这些结构往往有很好的[对称](https://zh.wikipedia.org/wiki/对称)性，而且每一代都在变化形状。一些形状已经锁定，不会逐代变化。有时，一些已经成形的结构会因为一些[无序](https://zh.wikipedia.org/w/index.php?title=无序&action=edit&redlink=1)细胞的“入侵”而被破坏。但是形状和[秩序](https://zh.wikipedia.org/w/index.php?title=秩序&action=edit&redlink=1)经常能从杂乱中产生出来。

这个游戏被许多[计算机程序](https://zh.wikipedia.org/wiki/计算机程序)实现了。[Unix](https://zh.wikipedia.org/wiki/Unix)世界中的许多[骇客](https://zh.wikipedia.org/wiki/駭客)喜欢玩这个游戏，他们用[字符](https://zh.wikipedia.org/wiki/字符)代表一个细胞，在一个[计算机](https://zh.wikipedia.org/wiki/计算机)[屏幕](https://zh.wikipedia.org/wiki/屏幕)上进行演化。比较著名的例子是，[GNU Emacs](https://zh.wikipedia.org/wiki/GNU_Emacs)编辑器中就包括这样一个小游戏。





# 方案思考

生命游戏是在一个无限的宇宙中进行的，但我们并没有无限的内存和计算能力。所以下面的三种选择中我们选择第三种.

- 追踪宇宙中哪个子集有有趣的事情发生 然后根据需要扩大这个区域的范围 在最坏的情况下，这种扩张是没有限制的，实现会越来越慢，最终耗尽内存。

- 创建一个固定大小的宇宙，边缘的细胞比中间的细胞有更少的邻居。这种方法的缺点是，像滑翔机一样的无限模式，到达宇宙的尽头就会被扼杀。

- 创造一个固定大小的周期性宇宙，边缘的细胞有邻居，可以绕到宇宙的另一边。因为邻居环绕在宇宙的边缘，所以滑翔机可以永远保持运行。



## 接口设计

关于[这一段](https://rustwasm.github.io/docs/book/game-of-life/implementing.html#interfacing-rust-and-javascript)非常重要, 但是我没怎么看明白。大概意思是要减少不必要的拷贝，减少序列化和反序列化（不懂)， 来来减少开销。

第一点：我们不需要实时地把整个宇宙复制到webassembly中，处理完之后再复制出去；也不需要为每个单元分配对象；也不想为每个单元你的读写添加一个跨界调用。那么我们可以用什么来表示这个宇宙呢？

答案是一个数组，数组中的一个单元表示一个细胞，0表示死亡，1表示存活。

用一维数组去表示二维数组：

![a 4 by 4 universe](https://rustwasm.github.io/docs/book/images/game-of-life/universe.png)

则横坐标为`row`, 纵坐标为`column`所在的`index=row*width+column`

我们有几种方法可以将宇宙的单元格暴露给JavaScript。首先，我们将为Universe实现std::fmt::Display的功能，我们可以用它来生成一个渲染为文本字符的单元格的Rust String，然后将这个Rust String从WebAssembly线性内存复制到JavaScript的垃圾回收堆中的JavaScript String中。然后通过设置HTML textContent来显示。在本章的后面，我们将对这个实现进行优化，以避免在堆之间复制宇宙的单元，并渲染到canvas。

## 实现

删除`wasm-game-of-life/src/lib.rs`中的`import`和`greet`函数

添加以下代码, **定义状态**

```rust
#[wasm_bindgen]
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)] // 为Cell添加左边的这些trait
pub enum Cell {
    Dead = 0,
    Alive = 1,
}
```

`#[repr(u8)]`很重要,因为通过它可以使每个单元都是一个字节(byte)



**定义宇宙**

```rust
#[wasm_bindgen]
pub struct Universe {
    width: u32,
    height: u32,
    cells: Vec<Cell>,
}
```

为`Universe`添加上面所说的`index`转换函数:

```rust
impl Universe {
    fn get_index(&self, row: u32, column: u32) -> usize {
        (row * self.width + column) as usize
    }
}
```

同样, 为了知道当前cell下个状态是什么, 我们需要计算他周围有多少cell是存活的

```rust
impl Universe {
    fn get_index(&self, row: u32, column: u32) -> usize {
        (row * self.width + column) as usize
    }
    fn live_neighbor_count(&self, row: u32, column: u32) -> u8 {
        let mut count = 0;
        // 遍历四周, 将-1定义为height-1是为了防止越界
        for delta_row in [self.height - 1, 0, 1].iter().cloned() {
            for delta_col in [self.width - 1, 0, 1].iter().cloned() {
                if delta_row == 0 && delta_col == 0 {
                    continue;
                }
                let neighbor_row = (row + delta_row) % self.height;
                let neighbor_col = (column + delta_col) % self.width;
                let idx = self.get_index(neighbor_row, neighbor_col);
                count += self.cells[idx] as u8;
            }
        }
        count
    }
}
```

接下来们再写一个判断逻辑, 把这个方法暴露给js, 因此需要`#[wasm_bindgen]`

```rust
/// Public methods, exported to JavaScript.
#[wasm_bindgen]
impl Universe {
    pub fn tick(&mut self) {
        let mut next = self.cells.clone();

        for row in 0..self.height {
            for col in 0..self.width {
                let idx = self.get_index(row, col);
                let cell = self.cells[idx];
                let live_neighbors = self.live_neighbor_count(row, col);

                let next_cell = match (cell, live_neighbors) {
                    // Rule 1: Any live cell with fewer than two live neighbours
                    // dies, as if caused by underpopulation.
                    (Cell::Alive, x) if x < 2 => Cell::Dead,
                    // Rule 2: Any live cell with two or three live neighbours
                    // lives on to the next generation.
                    (Cell::Alive, 2) | (Cell::Alive, 3) => Cell::Alive,
                    // Rule 3: Any live cell with more than three live
                    // neighbours dies, as if by overpopulation.
                    (Cell::Alive, x) if x > 3 => Cell::Dead,
                    // Rule 4: Any dead cell with exactly three live neighbours
                    // becomes a live cell, as if by reproduction.
                    (Cell::Dead, 3) => Cell::Alive,
                    // All other cells remain in the same state.
                    (otherwise, _) => otherwise,
                };

                next[idx] = next_cell;
            }
        }

        self.cells = next;
    }
}
```



再写一个文本渲染器, 将01的结果变成黑白方块

```rust
impl fmt::Display for Universe {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        for line in self.cells.as_slice().chunks(self.width as usize) {
            for &cell in line {
                let symbol = if cell == Cell::Dead { '◻' } else { '◼' };
                write!(f, "{}", symbol)?;
            }
            write!(f, "\n")?;
        }

        Ok(())
    }
}
```





最后在定义一个构造函数, 初始化宇宙. 同样,这个方法也是要暴露给js的, 所以放到有`#[wasm_bindgen]`的impl里

```rust
pub fn new() -> Universe {
    let width = 64;
    let height = 64;

    let cells = (0..width * height)
    .map(|i| {
        if i % 2 == 0 || i % 7 == 0 {
            Cell::Alive
        } else {
            Cell::Dead
        }
    })
    .collect();

    Universe {
        width,
        height,
        cells,
    }
}

pub fn render(&self) -> String {
    self.to_string()
}
```





然后再次运行`wasm-pack build`命令

...未完待续
