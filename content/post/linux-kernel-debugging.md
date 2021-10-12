---
title: linux kernel debugging
date: 2021-03-01 
tags: 
    - linux
categories: 
    - 学习
---

内核调试器kgdb、QEMU之类的管理程序或基于jtag的硬件接口允许在运行时使用gdb调试Linux内核及其模块。gdb为python提供了一个强大的脚本接口。内核提供了一组帮助脚本(helper scripts)，可以简化典型的内核调试步骤。

这是一个关于如何启用和使用它们的简短教程。它以QEMU/KVM虚拟机为目标，但是示例也可以转移到其他gdb stubs。

# 要求

- gdb 7.2+ (recommended: 7.4+) with python support enabled (typically true for distributions)

如果不满足条件的话需要重新编译一个新版本的gdb，或者升级原有的gdb。

# 设置

- 创建一个基于QEMU/KVM的虚拟机。这里我选择了基于QEMU创建虚拟机，官方文档为[qemu](https://qemu-project.gitlab.io/qemu/)。[这里](https://consen.github.io/2018/01/17/debug-linux-kernel-with-qemu-and-gdb/)是网上搜集的一份相关博客，可以参考一下。

- 在准备编译kernel的时候会有一个`make menuconfig`的步骤，我们需要打开`CONFIG_GDB_SCRIPTS`，关闭`CONFIG_DEBUG_INFO_REDUCED`。如果架构支持`CONFIG_FRAME_POINTER`的话，就启用它。

- 在客户机上安装这个编译好的内核（这里我们的客户机就是QEMU）。如果必要的话，可以在内核的命令行（command line)中添加`nokaslr`来关闭[KASLR](https://zh.wikipedia.org/wiki/%E4%BD%8D%E5%9D%80%E7%A9%BA%E9%96%93%E9%85%8D%E7%BD%AE%E9%9A%A8%E6%A9%9F%E8%BC%89%E5%85%A5)（ kernel address space layout randomization）。另外，QEMU允许使用`-kernel`，`-append`和`-initrd`命令行开关直接引导内核。 通常，仅在不依赖模块的情况下才有用。 有关此模式的更多详细信息，请参见QEMU文档。 在这种情况下，如果体系结构支持`KASLR`，则应在禁用`CONFIG_RANDOMIZE_BASE`的情况下构建内核。

	- [qemu文档](https://qemu-project.gitlab.io/qemu/system/invocation.html)的`Linux/Multiboot boot specific`节提到了上述命令。

- 在开始的命令行中添加`-s`以开启gdb，或者在运行时通过从QEMU监视控制台发出“ gdbserver”

- 进入到编译好的linux目录，`gdb vmlinux`开启gdb调试。

	- 注意：某些发行版可能会将gdb脚本的自动加载限制为已知的安全目录。 如果gdb报告拒绝加载vmlinux-gdb.py，请添加：`add-auto-load-safe-path /path/to/linux-build`到`~/.gdbinit`文件。

	> 我遇到了这个问题

- 连接到对应的客户机。

	```
	(gdb) target remote :1234
	```

# 未完待续

[翻译连接](https://www.kernel.org/doc/html/latest/dev-tools/gdb-kernel-debugging.html#examples-of-using-the-linux-provided-gdb-helpers)

https://qemu.readthedocs.io/en/latest/system/gdb.html

https://www.linuxidc.com/linux/2016-03/129600.htm