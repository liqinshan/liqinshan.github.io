---
title: Maven仓库设置
tags:
  - java
categories: java
abbrlink: 41722
date: 2017-06-19 18:50:43
---

如果一个软件既有全局性配置，又有个性化配置，一般而言，个性化配置要比全局性配置的优先级要高，就像git，如果全局性配置和项目仓库里的配置有冲突，以项目仓库里的配置为准。
但Maven仓库的优先级比较奇葩，项目repository（pom.xml中）的优先级比全局性的repository（settings.xml中）要低！

<!-- more -->

这意味着全局性配置给覆盖掉项目自身的配置。如果手头既有公司的项目，又有私人的项目，你没办法在项目里单独设置Maven仓库，除非你完全抛弃全局配置。

我手里有两个公司的项目，一个私人的项目，公司的项目使用公司的Maven仓库，私人的项目使用阿里云的Maven仓库，怎么配置才能让这个两个Maven仓库正确的生效？
并不是完全没有办法的，Maven的settings.xml里支持根据条件激活特定的配置项profile，只是比较复杂，而且功能偏弱。

假设你对Maven的设置已经有了基本的了解。
最初的想法，在profile里的file节点中，使用exists或missing来组合多个条件，确保指定项目能够正确的设置指定的repository，类似于：
```java
<file>
	<exists>${basedir}/src/main/java/...</exists>
	<missing>${basedir}/src/main/java/...</missing>
</file>
```
试了一下，发现这个方案只是看起来很美。一个file节点中同时使用多个exists或missing，或混合使用exists和missing是没有办法达到我们想要的效果的，因为Maven匹配到第一个条件就结束了，不会再往下匹配了。
stackoverflow上也有这个相关的问题：
![stackoverflow](/images/stackoverflow.png)

Refer to: https://stackoverflow.com/questions/11134636/maven-profile-activation-based-on-existence-of-several-files

所以只能使用单个exists或missing，一般而言，项目的源码文件路径中都会包含组织id（pom.xml中的groupId），可以使用它来匹配项目。
单个条件的潜在问题是，容易匹配到多个项目，产生歧义，就像Spring的@Profile注解一样。不过这个潜在的问题基本可以忽略，公司的项目，一般都会使用同一个Maven仓库。

我手里的两个项目蛋疼的地方在于，其中一个项目使用了多模块结构，不是标准的Spring项目结构， 所以需要单独为它写一个profile。所以，三个项目，三个profile，虽然啰嗦了些，方案是可行的。

其实如果想简便，最有效，也是最简单的方法是使用activeProfile，在公司的时候就启用公司的profile，在家启用家里的profile。麻烦的地方在于需要每次进行手工修改，还不如上面那个啰嗦的方案。
总体来说，Maven很操蛋。

确定settings.xml里的profile是否被正确的激活，可以进入项目的根目录（pom.xml同级目录），执行命令：
```java
mvn help:active-profiles
```
上述命令会显示哪个profile被激活，如下图。避免敏感信息，只显示私人项目：
![active](/images/active-profile.png)

或者直接执行如下命令进行下载依赖：
```java
mvn dependency:purge-local-repository -X
```
它会显示详细的日志，可以关键字搜索是否是从正确的repository下载的文件，如下图：
![purge](/images/purge.png)

参考文档：
官方文档：
https://maven.apache.org/settings.html#Activation
http://maven.apache.org/guides/introduction/introduction-to-profiles.html

中文文档：
http://blog.csdn.net/tomato__/article/details/13025187
http://blog.csdn.net/wangjunjun2008/article/details/17761355
http://toozhao.com/2012/07/13/compare-priority-of-maven-repository/