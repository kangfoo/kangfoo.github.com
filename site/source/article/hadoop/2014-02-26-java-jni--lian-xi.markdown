---
layout: post
title: Java JNI练习
date: '2014-02-26 00:55'
comments: true
published: true
keywords: Java JNI练习
description: Java JNI练习
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---
在 Hadoop 中大量使用了 JNI 技术以提高性能并利用其他语言已有的成熟算法简化开发难度。如压缩算法、pipes 等。那么在具体学习 native hadoop, hadoop io 前先简单复习下相关知识。在此我主要是参见了 Oracle 官方网站 + IBM developerworks + csdn 论坛 写了个简单的 Hello World 程序。

此处主要是将我参考的资源进行了列举，已备具体深入学习参考。

* [JAVA JNI oracle 官方文档]
* [IBM 使用 Java Native Interface 的最佳实践]
* [JNI hello world]

**JNI 编程主要步骤**

1. 编写一个.java
1. javac *.java
1. javah -jni className -> *.h
1. 创建一个.so/.dll 动态链接库文件

**编程注意事项**

1. 不要直接使用从java里面传递过来的value.(在java里面的对象在本地调用前可能被jvm析构函数了)
1. 一旦不使用某对象或者变量，要去ReleaseXXX()。
1. 不要在 native code 里面去申请内存
1. 使用 javap -s 查看java 签名

[JAVA JNI oracle 官方文档]: http://docs.oracle.com/javase/6/docs/technotes/guides/jni/
[IBM 使用 Java Native Interface 的最佳实践]: http://www.ibm.com/developerworks/cn/java/j-jni/
[JNI hello world]: http://blog.csdn.net/yangguo_2011/article/details/17379297#1536434-youdao-1-7173-6552c87762fd890a5b54a8bfc2e2f443


