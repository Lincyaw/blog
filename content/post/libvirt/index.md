---
title: "Libvirt踩坑记录"
date: 2022-01-21T18:38:47+08:00
draft: false
image: "method-draw-image.svg"
slug: libvirt
categories:
    - 学习
tags:
    - 虚拟化
    - linux
---

毕设需要用到libvirt库，在使用中发现了一些坑点。

## 快照相关操作

根据[Snapshot XML相关格式定义的文档](https://libvirt.org/formatsnapshot.html)
以及[Snapshot相关的API文档](https://libvirt.org/html/libvirt-libvirt-domain-snapshot.html)，一个
直观的理解是`virDomainSnapshotCreateXML()`函数根据XML创建出当前Domain的快照。

快照类型分为三类，分别是内存快照、磁盘快照和整机快照。
- 磁盘快照是把磁盘在某个时间点的状态保存下来。对于正在运行的客户机来说，磁盘快照更像是crash-consistent，就像突然断电时磁盘的状态，可能需要fsck检查工具来重新变得一致。对于不运行的客户机来说，磁盘快照就没有这种烦恼了。磁盘快照可以被保存到单个文件里，即保存到原始镜像文件中（比如qcow2格式的文件）；也可以写到单独的另外的文件里。
- 内存快照是把客户机的RAM状态和其他被VM使用的资源保存下来。如果使用这种方式，若磁盘在两个快照之间没有被改变，则恢复快照可以保证状态的一致。如果磁盘被改变了，可能会导致数据污染。
- 整机快照则是两者的结合，就像平时使用的VMwareWorkStation中的快照功能。

虽然文档说磁盘快照可以产生internal和external两种类型的，但是我在尝试之后发现产生的磁盘快照一直都是写到单独的文件里的，文档称其为 external。Libvirt对于external snapshot的支持不太好，只管生成快照，却不管恢复（revert），删除（delete）。[网上也有遇到相同的问题](https://serverfault.com/questions/990041/how-to-create-internal-snapshot-with-a-virsh-command)。

> unsupported configuration: deletion of 1 external disk snapshots not supported yet.

如果想要恢复到、删除到之前的磁盘快照，则会出现如上报错。数字“1”则取决于删除的快照有几个子节点。如下所示，如果删除snapshot2，则数字会变成“3”。

```
snapshot1->snapshot2->snapshot3
              |
              +------>snapshot4
```

在谷歌了许多次之后，最后得出的结论是**对于external snapshot只能选择手动管理的方式**。因此我开始找如何手动管理的文档。

### blockpull


经过尝试，[Redhat提供的文档](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/virtualization_administration_guide/sub-sect-domain_commands-using_blockpull_to_shorten_a_backing_chain)**似乎**可以将backing-chain中所有的磁盘镜像合到当前的镜像里。

e.g.：

```sh
# fangaoyang @ hangliu-MS-7B98 in ~/work [10:33:09]
$ svirsh domblklist 123
 Target   Source
----------------------------------------------------------------------------
 hda      /home/fangaoyang/work/e9216248-3cbc-4a01-9a67-496dfd2cc4ec.forth
 hdc      /home/fangaoyang/work/ubuntu-20.04.3-desktop-amd64.iso


# fangaoyang @ hangliu-MS-7B98 in ~/work [10:34:57]
$ svirsh blockpull --help
  NAME
    blockpull - Populate a disk from its backing image.

  SYNOPSIS
    blockpull <domain> <path> [--bandwidth <number>] [--base <string>] [--wait] [--verbose] [--timeout <number>] [--async] [--keep-relative] [--bytes]

  DESCRIPTION
    Populate a disk from its backing image.

  OPTIONS
    [--domain] <string>  domain name, id or uuid
    [--path] <string>  fully-qualified path of disk
    --bandwidth <number>  bandwidth limit in MiB/s
    --base <string>  path of backing file in chain for a partial pull
    --wait           wait for job to finish
    --verbose        with --wait, display the progress
    --timeout <number>  with --wait, abort if pull exceeds timeout (in seconds)
    --async          with --wait, don't wait for cancel to finish
    --keep-relative  keep the backing chain relatively referenced
    --bytes          the bandwidth limit is in bytes/s rather than MiB/s

# fangaoyang @ hangliu-MS-7B98 in ~/work [10:36:57]
$ svirsh blockpull 123 /home/fangaoyang/work/e9216248-3cbc-4a01-9a67-496dfd2cc4ec.forth --wait

Pull complete
```

在此之后，就可以使用`virsh snapshot-delete $domainName --metadata $snapshotName`删除之前的元数据了。因为所有的数据都已经在最新的这个镜像文件里了。

> Ps:在文档中只给出了下面的例子，镜像链不长。
>
> - Before: base.img ← Active
> - After: base.img is no longer used by the guest and Active contains all of the data.
>
> 经过我的测试，我删除了之前所有快照的镜像文件，没有影响客户机使用。因此blockpull命令应该是将之前所有的快照都合为一个了。

### blockcommit

libvirt官方文档里给出了[如何合并镜像链的示例](https://libvirt.org/kbase/merging_disk_image_chains.html)。

```sh
virsh blockcommit vm1 vda \
    --base=/var/lib/libvirt/images/base.raw
    --top=/var/lib/libvirt/images/b.qcow2
```

上面的命令可以将`base.raw`和`b.qcow2`之间的快照合并，并保存在`base.raw`中。

Starting the earlier image chain:

```sh
base.raw <-- a.qcow2 <-- b.qcow2 <-- c.qcow2 (live QEMU)
```

Reduce the length of the chain by two images, with the resulting chain being:

```sh
base.raw <-- c.qcow2 (live QEMU)
```

此时再去删除libvirt管理的snapshot metadata即可实现快照的删除、切换操作。



### qemu-img: commit + rebase

因为qcow文件本身就有记录子镜像的父镜像是谁。下面展示了`*.third`镜像的父亲是`*.first`，`*.first`的父亲是`*`。

```sh
# fangaoyang @ hangliu-MS-7B98 in ~/work [10:24:35]
$ sudo qemu-img info -U --backing-chain e9216248-3cbc-4a01-9a67-496dfd2cc4ec.third
image: e9216248-3cbc-4a01-9a67-496dfd2cc4ec.third
file format: qcow2
virtual size: 40 GiB (42949672960 bytes)
disk size: 836 KiB
cluster_size: 65536
backing file: /home/fangaoyang/work/e9216248-3cbc-4a01-9a67-496dfd2cc4ec.first
backing file format: qcow2
Format specific information:
    compat: 1.1
    lazy refcounts: false
    refcount bits: 16
    corrupt: false

image: /home/fangaoyang/work/e9216248-3cbc-4a01-9a67-496dfd2cc4ec.first
file format: qcow2
virtual size: 40 GiB (42949672960 bytes)
disk size: 1.44 GiB
cluster_size: 65536
backing file: /home/fangaoyang/work/e9216248-3cbc-4a01-9a67-496dfd2cc4ec
backing file format: qcow2
Snapshot list:
ID        TAG                     VM SIZE                DATE       VM CLOCK
1         second                 1.38 GiB 2022-01-22 10:13:06   00:04:11.724
Format specific information:
    compat: 1.1
    lazy refcounts: false
    refcount bits: 16
    corrupt: false

image: /home/fangaoyang/work/e9216248-3cbc-4a01-9a67-496dfd2cc4ec
file format: qcow2
virtual size: 40 GiB (42949672960 bytes)
disk size: 20.7 GiB
cluster_size: 65536
Snapshot list:
ID        TAG                     VM SIZE                DATE       VM CLOCK
1         vmname-snapshot1       3.83 GiB 2022-01-16 17:03:47   96:42:42.610
Format specific information:
    compat: 1.1
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
```

通过qemu-img的操作也可以实现类似的效果，可以[参考该文档](https://blog.programster.org/qemu-img-cheatsheet)。

### 小结

[blockpull](https://libvirt.org/manpages/virsh.html#blockpull)和[blockcommit](https://libvirt.org/manpages/virsh.html#blockcommit)都是virsh的命令。这两者的区别在于一个向前合并，一个向后合并：

blockpull：

- forward in time
- pulls older data to newer images (external snapshot)
- increases size of newer images (external snapshot)

blockcommit
- backward in time
- merges new data into older images(base or external snapshot)
-  increases size of older images

