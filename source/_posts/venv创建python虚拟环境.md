---
title: venv创建python虚拟环境
tags:
  - venv
categories: python
abbrlink: 43617
date: 2017-01-03 09:59:38
---
pyenv曾经是Python的官方版本管理工具，不过从Python 3.6开始，官方推荐使用venv模块来管理虚拟环境，在使用pyenv创建虚拟环境时会弹出相关提示。

<!-- more -->

Python 3.6前几天刚release，我准备尝个鲜，首要的就是创建虚拟环境。

```python
	python3.6 -m venv ~/.venvs/codex
	source ~/.venvs/codex/bin/activate
```
这样就创建并启用了一个Python3.6的虚拟环境，shell界面的最前方会显示当前的虚拟环境名称，这时使用pip安装的包都会安装该虚拟环境下。

退出虚拟环境也很简单，运行下面的命令即可退出当前虚拟环境：

```python
deactivate
```

若需要删除虚拟环境，直接删除相关的目录即可。

