---
layout: post
title: HDFS API 练习使用
date: '2014-02-26 00:53'
comments: true
published: true
keywords: HDFS API 练习使用
description: HDFS API 练习使用
excerpt: 
categories: ['hadoop']
tags: ['hadoop']
---
经过前几页博客的知识巩固，现在开始使用 Hadoop API 不是什么难事。此处不重点讲述。参考 Hadoop API 利用 FileSystem 实例对象操作 FSDataInputStream/FSDataOutputStream 基本不是问题。

#### HDFS API入门级别的使用 ####

1. 获取 FileSystem 对象</br> 
get(Configuration conf)</br> 
Configuration 对象封装了客户端或者服务器端的 conf/core-site.xml 配置</b>

1. 通过 FileSystem 对象进行文件操作</br>
读数据：open()获取FSDataInputStream(它支持随机访问),</br>
写数据：create()获取FSDataOutputStream</br>

参考代码：[HDFSTest.java]

代码中主要利用 FileSystem 对象进行文件的 读、写、重命名、删除、文件信息获取等操作。

[HDFSTest.java]: https://github.com/kangfoo/hadoop1.study/blob/master/kangfoo/study.hdfs/src/test/java/com/kangfoo/study/hadoop1/htfs/HDFSTest.java