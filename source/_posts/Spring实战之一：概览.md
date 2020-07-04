---
title: Spring实战之一：概览
categories: java
tags:
  - java
  - Spring
abbrlink: 129
date: 2017-04-22 00:09:35
---
第一章：Spring之旅
Spring是一个开源框架，出现的目的是为了解决企业级应用开发的复杂性。Spring使用了以下4种策略来降低Java开发的复杂性：
1）基于POJO的轻量级和最小侵入性编程
2）通过依赖注入和面向接口实现松耦合
3）基于切面和惯例进行声明式编程
4）通过切面和模板减少样板式代码

<!-- more -->

POJO：Plain Old Java Object，普通Java对象。
它是普通的Java类，有一些private的参数（属性），然后为其中的每个参数定义了getter和setter作为访问的接口。例：

```java
public class User {
    private name;

    public String getName() {
        return name;
    }
    public void setName(String name) {
        this.name = name;
    }
}
```

依赖注入：
依赖注入（DI）是控制反转（IoC）的一种方式，所谓依赖注入就是把实例变量传入到一个对象中去。例：
```java
    public class DamselRescuingKnight implements Knight {
        private RescueDamselQuest quest;
        
        public DamselRescuingKnight() {
            // 紧耦合，一个对象在运行过程中需要创建另外一个跟它有依赖关系的对象
            this.quest = new RescueDamselQuest();
        }
    
        public void embarkOnQuest() {
            quest.embark();
        }
    }
    
    public class BraveKnight implements Knight {
        private Quest quest;
        
        public BraveKnight(Quest quest) {
            // 依赖注入，对象不需要创建另外一个对象，只需要关注自身的逻辑
            this.quest = quest;   
        }
        
        public void embarkOnQuest() {
            quest.embark();
        }
    }
```
了解Ioc和DI，可以参考：http://blog.xiaohansong.com/2015/10/21/IoC-and-DI/

Spring模块：
Spring框架由20多个模块组成，这20多个模块可以分为6大类：
核心容器：Core、Context、Bean、Expression、Context support
Web与远程调用：Web、WebSocket、Web servlet、Web portlet
数据访问与集成：JDBC、ORM、OXM、Transaction、Messaging、JMS
面向切面：AOP、Aspects
Instrumentation：Instrument、Instrument Tomcat
测试：Test

见下图：![modules](/images/SpringModules.png)
对于数据访问与集成，相比较JDBC而言，ORM会更流行一些，Spring本身不提供ORM解决方案，而是对许多流行的ORM进行了集成，包括Hibernate、Mybatis等。
对于Web与远程调用，Spring能够与许多流行的MVC框架集成，但它本身也提供了一个MVC框架：Spring MVC

RestTemplate：
这是3.2版本以后提供的，这是个好东西。
