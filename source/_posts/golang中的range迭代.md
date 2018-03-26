---
title: golang中的range迭代
tags: range
categories: Golang
abbrlink: 47031
date: 2018-03-19 22:47:30
---

工作中，遍历元素并修改其值是一个很常见的需求，而Golang中使用range遍历slice或者map非常方便，所以遇到此类需求时，我们会自然而然地想到使用range。

<!-- more -->

但是我们需要了解一下range的工作方式，否则很容易被"坑"。

```go
package main

import (
	"fmt"
)

type Person struct {
    Name string
    Age  string
}

func main() {
    originList := []Person{
        {Name: "allen", Age: 20},
        {Name: "jason", Age: 30},
        {Nmae: "william", Age: 40},
    }
    
    result := make(map[string]*Person)
    
    for _, item := range originList {
        result[item.Name] = &item
    }
    
    fmt.Println(result)
}
```

上面这段代码，目的是拷贝originList里的值到result。但是它不会得到你想要的结果。

原因在于，range遍历时使用的值拷贝，就是说，range在遍历的时候，会拷贝其遍历对象的值，并写入一个临时的内存地址，而这个临时内存地址在遍历过程中是复用的，就是说，在遍历第一个元素时，它拷贝该元素的值并写入临时内存地址，然后遍历第二个元素，同样拷贝第二个元素的值并写入该临时内存地址，后一个值会覆盖掉前一个值。

所以，代码中range代码块中的指针`&item`，指向的是临时内存地址，而非原始元素，其存储的是当前遍历元素的值。由此可以推断出，result对象的value是相同的，指向同一个内存地址。

运行代码，打印结果大致如下（每次的运行的内存地址可能不同）：

`map[allen:0xc42000a060 jason:0xc42000a060 william:0xc42000a060]`

所以，我们应该尽量避免在range中使用指针，除非你明确知道自己在干什么！

如果想遍历元素并修改其值，怎么办？可以使用看起来"很挫"的下标遍历：

```go
for i := 0; i < len(originList); i++ {
    result[originList[i].Name] = &originList[i]
}
```

或者：

```go
for index, _ := range originList {
    result[originList[index].Name] = &originList[index]
}
```

