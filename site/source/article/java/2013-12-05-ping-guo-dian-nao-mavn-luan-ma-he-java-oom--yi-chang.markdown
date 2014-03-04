---
layout: post
title: Mac java乱码 maven OOM 异常
date: '2013-12-05 23:55'
comments: true
published: true
keywords: Mac java乱码,maven java oom
description: 苹果电脑java/javac乱码，java maven OOM 异常
excerpt: 
categories: ['java']
tags: ['java','mac','maven']
---
在中文环境下苹果电脑中的 **java，javac 默认以GBK编码**输出信息到控制台，**终端terminal默认以UTF-8编码**，就出现了编码错误。

可如下2种方式修改:

1. 更改系统语言环境
```
export LC_ALL=en 或者 export LANG=zh_CN.UTF-8
```
1. 指定输出编码方式
```
javac -Dfile.encoding=UTF-8
```

但在有maven的情况下还需要这么设置：**先调整JVM大小，避免工程太大中途出现OOM，再设置文件的编码。**
```
export MAVEN_OPTS="-Xmx1024m －Dfile.encoding=UTF-8"
```



