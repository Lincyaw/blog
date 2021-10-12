---
title: model-view in qt
date: 2021-02-23 
tags: 
    - qt
    - 架构
categories: 
    - 学习
---

本文是在设计软件架构时学习的一些东西，关于一个软件如何分层，每层之间应该定义哪些接口。

<!--more-->

# 问题

当前需要设计一个桌面整理软件，支持以下特征：

1. 兼容Ubuntu 20.04版本运行
2. 满足x86_64、arm64等多架构支持
3. 使用Qt进行开发
4. 支持自动整理、自动重排
5. 支持跟随系统主题变化

要如何设计软件架构，定义接口，从而正确分工?



# 搜集资料

- [阮一峰的网络日志](http://www.ruanyifeng.com/blog/2007/11/mvc.html)对于MVC设计模式举了一些形象的例子以便于理解MVC。
- [菜鸟教程](https://www.runoob.com/design-pattern/mvc-pattern.html)针对MVC提供了代码示例。
- MVC是[图说设计模式](https://design-patterns.readthedocs.io/zh_CN/latest/behavioral_patterns/observer.html)中的观察者模式的扩展，如文中所说：
	- MVC模式是一种架构模式，它包含三个角色：模型(Model)，视图(View)和控制器(Controller)。观察者模式可以用来实现MVC模式，观察者模式中的观察目标就是MVC模式中的模型(Model)，而观察者就是MVC中的视图(View)，控制器(Controller)充当两者之间的中介者(Mediator)。当模型层的数据发生改变时，视图层将自动改变其显示内容。

对MVC设计模式有了一些了解之后，下面学习一下qt官方对于[ModelView](https://doc.qt.io/qt-5/modelview.html)的文档。

# Qt Model/View

qt设计了两种外观相同的widget，但是他们与数据的交互方式是不同的。标准的widget有着一系列的数据，是在这个类本身上的，而所谓的View classes操作的数据是在外部的。

官方文档举了表格widget为例子。

> A table widget is a 2D array of the data elements that the user can change. The table widget can be integrated into a program flow by reading and writing the data elements that the table widget provides. This method is very intuitive and useful in many applications, but displaying and editing a database table with a standard table widget can be problematic. Two copies of the data have to be coordinated: one outside the widget; one inside the widget. The developer is responsible for synchronizing both versions. Besides this, the tight coupling of presentation and data makes it harder to write unit tests.

大致翻译一下：

table widget 是用户可以更改的数据元素的2D数组。可以通过读写表小部件提供的数据元素将表小部件集成到程序流中。此方法非常直观，在许多应用程序中很有用，但是使用标准表窗口小部件显示和编辑数据库表可能会出现问题：数据的两个副本必须协调一致：一个在小部件外部；另一个在小部件外部。开发人员负责同步两个版本。除此之外，presentation和data 的紧密耦合使编写单元测试更加困难。

文档提出了标准widget出现的困难，从而引入Model/view的作用。

- Model/view消除了标准小部件可能发生的数据一致性问题。
- Model/view还使使用同一数据的多个视图变得更加容易，因为一个模型可以传递给许多视图。
- Model/view小部件不在表单元格后面存储数据，而是直接操作提供的数据。
	- 想法：好像有点像传引用的作用？

由于视图类(view class)不知道提供的数据结构是怎么样的，因此需要一个包装器(wrapper)来符合[QAbstractItemModel](https://doc.qt.io/qt-5/qabstractitemmodel.html) 的接口标准。一个类一旦实现了这个接口，在Qt中就可以被认为是一个model。只要传递一个model的指针给一个view，view就可以读取和显示数据（在ui上）。

上面描述了如何将数据从model传递到view，下面就要说如何修改model的数据了。(个人觉得model有点像是数据库的存在)

文档给出了两个适配器（adapter）。一个是[QDataWidgetMapper](https://doc.qt.io/qt-5/qdatawidgetmapper.html)，可以将widget映射到一个表单的行，并且很容易构建成一个数据库的表。

>  个人理解：例如一个pushbutton，其包含的数据包括自身的位置、名称等，这些数据都可以作为一张表的一行，每一行就是一个pushbutton实例。

另一个叫做 [QCompleter](https://doc.qt.io/qt-5/qcompleter.html)，暂时不明白`auto-completion`是什么意思，自己并没有使用过他提到的这些widget，因此给出原文，以后思考。

> Another example of an adapter is [QCompleter](https://doc.qt.io/qt-5/qcompleter.html). Qt has [QCompleter](https://doc.qt.io/qt-5/qcompleter.html) for providing auto-completions in Qt widgets such as [QComboBox](https://doc.qt.io/qt-5/qcombobox.html) and, as shown below, [QLineEdit](https://doc.qt.io/qt-5/qlineedit.html). [QCompleter](https://doc.qt.io/qt-5/qcompleter.html) uses a model as its data source.

## 代码实例

代码在下载安装了qt之后就会在本地出现。在我的电脑上的路径为
`C:\Qt\Examples\Qt-6.0.1\widgets\tutorials\modelview`

```C++
//! [Quoting ModelView Tutorial]
// main.cpp
#include <QApplication>
#include <QTableView>
#include "mymodel.h"

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    QTableView tableView;
    MyModel myModel;
    // 传递了指针给tableView，tableView将调用它收到的指针的方法以发现两件事：
    //    应显示多少行和多少列。
    //    每个单元格应打印什么内容。
    tableView.setModel(&myModel);
    tableView.show();
    return a.exec();
}
//! [Quoting ModelView Tutorial]

```

这里提到了本文中的第四个类：[QAbstractTableModel](https://doc.qt.io/qt-5/qabstracttablemodel.html)

```C++
#ifndef MYMODEL_H
#define MYMODEL_H

//! [Quoting ModelView Tutorial]
// mymodel.h
#include <QAbstractTableModel>

class MyModel : public QAbstractTableModel
{
    Q_OBJECT
public:
    MyModel(QObject *parent = nullptr);
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
};
//! [Quoting ModelView Tutorial]

#endif // MYMODEL_H
```

`MyModel`继承了QAbstractTableModel，为什么不用上文提到的QAbstractItemModel呢，他说因为前者更好用。MyModel重载了父类的三个方法（即父类提供的接口），从而使view能够接收到这些数据。

![演示结果](http://lincyaw.xyz/images/eg.png)

### 修改表格样式

`QAbstractTableModel::Data()`的作用远不止只能控制`view`显示的内容这么简单。只需要在`data()`中添加一些代码即可设置字体、背景色、对齐方式和复选框。

```C++
// mymodel.cpp
QVariant MyModel::data(const QModelIndex &index, int role) const
{
    int row = index.row();
    int col = index.column();
    // generate a log message when this method gets called
    qDebug() << QString("row %1, col%2, role %3")
            .arg(row).arg(col).arg(role);

    switch (role) {
    case Qt::DisplayRole:
        if (row == 0 && col == 1) return QString("<--left");
        if (row == 1 && col == 1) return QString("right-->");

        return QString("Row%1, Column%2")
                .arg(row + 1)
                .arg(col +1);
    case Qt::FontRole:
        if (row == 0 && col == 0) { //change font only for cell(0,0)
            QFont boldFont;
            boldFont.setBold(true);
            return boldFont;
        }
        break;
    case Qt::BackgroundRole:
        if (row == 1 && col == 2)  //change background only for cell(1,2)
            return QBrush(Qt::red);
        break;
    case Qt::TextAlignmentRole:
        if (row == 1 && col == 1) //change text alignment only for cell(1,1)
            return int(Qt::AlignRight | Qt::AlignVCenter);
        break;
    case Qt::CheckStateRole:
        if (row == 1 && col == 0) //add a checkbox to cell(1,0)
            return Qt::Checked;
        break;
    }
    return QVariant();
}
```

对比第一版的代码，可以知道这次的代码添加了一个switch语句，枚举了不同的“Role”。

很明显，这些“role”是传入`data()`的参数之一，下面给出有哪些枚举变量。

| [enum Qt::ItemDataRole](https://doc.qt.io/qt-5/qt.html#ItemDataRole-enum) |                           Meaning                            |                             Type                             |
| :----------------------------------------------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: |
| [Qt::DisplayRole](https://doc.qt.io/qt-5/qt.html#ItemDataRole-enum) |                             text                             |        [QString](https://doc.qt.io/qt-5/qstring.html)        |
| [Qt::FontRole](https://doc.qt.io/qt-5/qt.html#ItemDataRole-enum) |                             font                             |          [QFont](https://doc.qt.io/qt-5/qfont.html)          |
| [BackgroundRole](https://doc.qt.io/qt-5/qt.html#ItemDataRole-enum) |             brush for the background of the cell             |         [QBrush](https://doc.qt.io/qt-5/qbrush.html)         |
| [Qt::TextAlignmentRole](https://doc.qt.io/qt-5/qt.html#ItemDataRole-enum) |                        text alignment                        | [enum Qt::AlignmentFlag](https://doc.qt.io/qt-5/qt.html#AlignmentFlag-enum) |
| [Qt::CheckStateRole](https://doc.qt.io/qt-5/qt.html#ItemDataRole-enum) | suppresses checkboxes with [QVariant()](https://doc.qt.io/qt-5/qvariant.html),sets checkboxes with [Qt::Checked](https://doc.qt.io/qt-5/qt.html#CheckState-enum) or [Qt::Unchecked](https://doc.qt.io/qt-5/qt.html#CheckState-enum) | [enum Qt::ItemDataRole](https://doc.qt.io/qt-5/qt.html#ItemDataRole-enum) |

详情可以了解[Qt :: ItemDataRole](https://doc.qt.io/qt-5/qt.html#ItemDataRole-enum)。

在代码中有这样一行代码打印信息

```C++
    qDebug() << QString("row %1, col%2, role %3").arg(row).arg(col).arg(role);
```

通过运行程序可以知道，在启动时`data()`将被调用42次，一个单元格调用7次。每次光标悬停在某个单元格上时，`data()`又会被调用7次。

> 注意，此处笔者觉得文档有误。在笔者的测试中，悬停只会调用一次`data()`。而 点击将会增加几十次（数字不确定）

### 在只读表格中添加计时器

类中添加一个成员和一个槽

```C++
private:
    QTimer *timer;
private slots:
    void timerHit();
```

在构造函数中将定时器和这个槽连接起来

```C++
timer->setInterval(1000);
connect(timer, &QTimer::timeout , this, &MyModel::timerHit);
timer->start();
```

槽函数定义如下

```C++
void MyModel::timerHit()
{
    //we identify the top left cell
    QModelIndex topLeft = createIndex(0,0);
    //emit a signal to make the view reread identified data
    emit dataChanged(topLeft, topLeft, {Qt::DisplayRole});
}
```

通过发出`datachchanged()`信号，我们要求视图再次读取左上角单元格中的数据。注意，我们没有显式地将`datachchanged()`信号连接到view。当我们调用`setModel()`时，这将自动发生。(`setModel`在`main`函数中调用)

### 剩余示例

TODO

## 小结

文档提到了四个重要的类，前两个是提供了作为model的必要条件(接口)，其余两个是包装器，实现了从model到view的数据“连接”。

- [QAbstractItemModel](https://doc.qt.io/qt-5/qabstractitemmodel.html) 
- [QAbstractTableModel](https://doc.qt.io/qt-5/qabstracttablemodel.html)
- [QDataWidgetMapper](https://doc.qt.io/qt-5/qdatawidgetmapper.html)
- [QCompleter](https://doc.qt.io/qt-5/qcompleter.html)

# 如何设计接口

TODO