---
title: 弘量科技面试&Repomono笔试
date: 2020-10-23
tags: 
    - 软件测试
    - 后端开发
categories: 
    - 工作
---

投了一些小公司练练手。弘量科技是金融+科技类的企业；Repomono是美国的初创企业。

<!--more-->

# 弘量科技

投的是测试岗位。

首先让我自我介绍。我介绍了一些自己的项目，以及自己的兴趣爱好。

然后开始问一些测试的基础知识，我按我[准备的内容](/hexo/2020/10/20/软件测试面试准备)去回答，应该没有太大的问题。

接着开始问我的项目经历，自己感觉到不顺畅的是大一的那个项目，以后不能再写上去了。自己实际上也没做出来，讲不出细节，如果以后再有人问这个项目的细节，也圆不过去。

因此对于自己不熟悉的项目一定不能写上去。写在简历上的一定要是自己比较熟悉的，能够详细的讲出自己做了什么，并且有自己的思考的内容。

比如操作系统的那个项目，我认为我自己可以再整理整理，方便以后说（吹逼。

再者，面试官问我，为什么选择测试岗。我说，选择测试岗是因为我现在的能力不够，希望看看在实际工程中的代码是怎么样的，需要什么样的能力。在测试的过程中我可以学习，然后以后做开发工作。

在面试结束之后，我认为这有些不妥。当时说的时候，我觉得我这样可以显示我有上进心，但是仔细想想，这样也显得我不想留在他们公司干活。

最后，在今天，他们跟我说是否愿意去他们公司实习。这也算一个比较好的结果吧。第一次面试体验也不算差。



# Repomono

这个公司在美国，由于疫情关系接受远程实习。远程实习对于正在上课的学生来说其实比去实地的更香。可以随时随地工作，对比其他公司每天需要花费一个多小时在路程上，远程实习可以节约更多的时间。并且是弹性制工作，不要求打卡。

但是，笔试使用c语言去解析一个url地址。我以前没有接触过这一类的东西。

他的要求应该就是从`http://example.com/test?q=type&id=12&name=john`这样的网址中提取出`q=type`,`id=12`这样的内容，并且把它放到一个结构体中，再转成json文件。

其实挺简单的，但是我遇到的困难就是那个结构体。由于太久没有用c语言，导致我在给一个二维的结构体指针申请空间的操作上浪费了过多的时间。题目中，在给出的`main.c`文件中故意留了一个内存相关的bug，其实就是`fopen`函数没有成功打开文件。但是我死活打不开那个文件...明明就在同一个路径下。打算重新试试。

题目中还需要自己给出一定量的测试用例，验证自己程序的健壮性。这些就更加没有做出来了。

这次的笔试算是凉了，也可以看出自己的水平与真正的开发还有一定距离。如果想要做开发，必然是要学更多的东西。但是不知道自己要在哪方面入手，是python，还是golang，还是其他的。可能就应该随便挑一个学一学，把一种学懂了之后，另一种也懂了。