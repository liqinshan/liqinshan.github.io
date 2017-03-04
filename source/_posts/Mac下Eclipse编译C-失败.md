---
title: Mac下Eclipse编译C++失败
date: 2017-03-04 22:27:47
tags: 
- c++
categories: c++
---

在Eclipse中编译C++时失败，无法通过，报错：ld: symbol(s) not found for architecture x86_64。

<!-- more -->

运行环境：
OS：macOS Sierra
Eclipse：Eclipse IDE for C/C++ Neon.2
GCC：
```text
> g++ -v
Configured with: --prefix=/Applications/Xcode.app/Contents/Developer/usr --with-gxx-include-dir=/usr/include/c++/4.2.1
Apple LLVM version 8.0.0 (clang-800.0.42.1)
```

被这个问题困扰了两三天，最后还是Stackoverflow上的方案尝试成功。链接：http://stackoverflow.com/questions/19637164/c-linking-error-after-upgrading-to-mac-os-x-10-9-xcode-5-0-1

在macOS X中，C++标准库有两种实现：libstdc++和libc++，而自从10.9开始，系统默认使用libc++作为标准库的实现。如果使用libstdc++作为编译选项，会收到一个警告：libstdc++ is deprecated; move to libc++。但是libc++会导致很多编译错误，如果以相关关键字搜索，Goole上有大量的案例。

知道了原因，解决起来也很简单：打开项目的Properties（快捷键：command+i），在C/C++ Build下的Settings —>Tool Settings —>MacOS X C++ Linker，在编译选项中增加 -libstd=libstdc++。

错误截图：
![error](images/error.png)



添加libstdc++：

![solution](images/solution.png)