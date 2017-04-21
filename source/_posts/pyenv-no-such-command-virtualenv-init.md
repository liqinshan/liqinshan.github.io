---
title: 'pyenv: no such command ''virtualenv-init'''
tags: pyenv
categories: python
abbrlink: 7972
date: 2016-12-31 23:56:35
---

Pyenv安装完成后，一般要按照官方文档所述，在~/.bash_profile，或/etc/profile中添加如下配置项：

<!-- more -->

```bash
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
```
但是如果Pyenv没有安装在默认位置（~/.pyenv）时，需要export PATH之前设置PYENV_ROOT，否则可能会报错：
```bash
	pyenv: no such command 'virtualenv-init'
```
示例：
```bash
export PYENV_ROOT=/usr/local/pyenv
export PATH="/usr/local/pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
```
