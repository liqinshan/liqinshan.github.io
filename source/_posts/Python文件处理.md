---
title: Python文件处理
date: 2017-01-01 12:21:42
tags: 
- 生成器
- 多进程
categories: python
---
python中处理大量文件时，生成器是个不错的选择。
<!-- more -->

最近一段时间（非博客上显示的成文时间。这是之前写的，也是保留下来的少数几篇博文之一）忙于充实我们的CMDB，上周采集了我们的交换机数据，预处理后生成了113个文件，总大小275KB，平均每个文件大约2.5KB。这些文件需要进一步的处理。文件内容的格式大致如此：
```text
            GE0/0/14 abc1-a123-1234 51023423541234003472
            GE1/0/28 abc1-a123-5678 51023423541234000569
Eth-Trunk48 GigabitEthernet0/0/48 abc1-a123-5566 51023423541234003472
Eth-Trunk48 GigabitEthernet1/0/48 abc1-a123-5566 51023423541234000569
```
第一列为聚合口，第二列为物理口，第三列为接在该口上的服务器MAC地址，第四列为交换机SN号。若交换机没有做堆叠，聚合口为空。我们需要对交换机上采集到的MAC地址的格式进行进一步的处理，格式化成常见的ab:c1:a1:23:12:34格式。
即使一次性全部读入，100多个小文件处理起来也毫无压力，不过考虑到通用性，我在工具里使用生成器技术来解析这些文件，即使再多的文件也可以顺畅的处理，内存上不会有压力：
```python
# -*- coding:utf-8 -*-

import os
import os.path
import fnmatch

__author__ = "lqs"

def _parse(lines):
    for line in lines:
        *_, port, mac, sn = line.split()
        yield ':'.join(['{}:{}'.format(m[:2], m[2:]) for m in mac.split('-')])

def _gen_fp(files):
    for fp in files:
        f = open(fp)
        yield f
        f.close()

def _gen_file(dir_path, wildcard='*.txt'):
    for file in fnmatch.filter(os.listdir(dir_path), wildcard):
        yield os.path.join(dir_path, file)

# `yield from <iterator>` 语句遍历迭代器对象, 并返回其每一个值. 具体到这里, 实际上它是在读取文件, 并返回每一行. 功效跟 `for` 循环一样, 但更简洁:
#     for f in iterators:
#         for line in f:
#             yield line
#
def _gen_lines(iterators):
    for it in iterators:
        yield from it

def main(dir_path):
    if not os.path.exists(dir_path):
        raise IOError('Empty directory!')
    
    f = _gen_file(dir_path)
    fp = _gen_fp(f)
    lines = _gen_lines(fp)
    for line in _parse(lines):
        print(line)

if __name__ == '__main__':
    dp = os.path.expanduser('~/Desktop/data')
    main(dp)
```
在解析多文件，大文件时，使用生成器以管道方式来处理是常用的手段，可以参考： A Curious Course on Coroutines and Concurrency 。

完成工作后，浏览文档时看到了多进程，想到也可以使用多进程技术来充分利用多核，以加快任务的运行：
```python
# -*- coding:utf-8 -*-

import os
import os.path
import fnmatch
from concurrent.futures import ProcessPoolExecutor

__author__ = "lqs"

def _parse(fp):
    mac_addrs = set()

    with open(fp) as f:
        for line in f:
            *_, port, mac, sn = line.split()
            mac_addrs.add(':'.join(['{}:{}'.format(m[:2], m[2:]) for m in mac.split('-')]))
    
    return mac_addrs

def _parse_files(dir_path, wildcard='*.txt'):
    files = [os.path.join(dir_path, f) for f in fnmatch.filter(os.listdir(dir_path), wildcard)]
    ret = set()
    
    # 使用ProcessPoolExecutor进行多进程任务, 默认的进程数为CPU个数.
    # `map()`是Python中很有用的小玩意, 借助正确的库可以实现并行化等强大的功能.
    with ProcessPoolExecutor() as p:
        for mac in p.map(_parse, files):
            ret.update(mac)
    
    return ret

def main(dir_path):
    if not os.path.exists(dir_path):
        raise IOError('Empty directory!')
    
    for mac in _parse_files(dir_path):
        print(mac)

if __name__ == '__main__':
    dp = os.path.expanduser('~/Desktop/data')
    main(dp)
```
代码看起来简洁不少！至于哪一种方式更快，内存占用更少，不好判断，所有文件总大小也不到300KB，看不出什么效果。

题外话：concurrent.futures库提供一个高级接口用于异步执行调用，借助该库，我们可以轻松地实现简单的并行编程。
模块中的两个子类ThreadPoolExecutor和ProcessPoolExecutor分别使用多线程或多进程来异步执行函数，对于简单的并行任务而言，使用concurrent.futures比使用multiprocessing更加方便。