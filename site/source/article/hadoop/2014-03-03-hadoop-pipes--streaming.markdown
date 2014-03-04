---
layout: post
title: Hadoop Pipes & Streaming
date: '2014-03-03 22:26'
comments: true
published: true
keywords: Hadoop Pipes & Streaming
description: Hadoop Pipes & Streaming
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---

申明：本文大部分出自于 [开源力量] LouisT 老师的[开源力量培训课-Hadoop Development]课件 和 Apache 官方文档。

## Streaming

* Streaming 是 hadoop 里面提供的一个工具
* Streaming 框架允许任何程序语言实现的程序在 Hadoop MapReduce 中使用，方便任何程序向 Hadoop 平台移植，具有很强的扩展性；
* mapper 和 reducer 会从标准输入中读取用户数据，一行一行处理后发送给标准输出。Streaming 工具会创建 MapReduce 作业，发送给各个 tasktracker，同时监控整个作业的执行过程；
* 如果一个文件（可执行或者脚本）作为 mapper，mapper 初始化时，每一个 mapper 任务会把该文件作为一个单独进程启动，mapper 任务运行时，它把输入切法成行并把每一行提供给可执行文件进程的标准输入。同 时，mapper 收集可执行文件进程标准输出的内容，并把收到的每一行内容转化成 key/value，作为 mapper的输出。默认情况下，一行中第一个 tab 之前的部分作为 key，之后的（不包括）作为value。如果没有 tab，整行作为 key 值，value值为null。对于reducer，类似；

### Streaming 优点

1. 开发效率高，便于移植。Hadoop Streaming 使用 Unix 标准流作为 Hadoop 和应用程序之间的接口。在单机上可按照 cat input | mapper | sort | reducer > output 进行测试，若单机上测试通过，集群上一般控制好内存也可以很好的执行成功。

2. 提高运行效率。对内存要求较高，可用C/C++控制内存。比纯java实现更好。

### Streaming缺点

1. Hadoop Streaming 默认只能处理文本数据，（0.21.0之后可以处理二进制数据）。

2. Steaming 中的 mapper 和 reducer 默认只能想标准输出写数据，不能方便的多路输出。

更详细内容请参考于： http://hadoop.apache.org/docs/r1.2.1/streaming.html

```shell
$HADOOP_HOME/bin/hadoop  jar $HADOOP_HOME/hadoop-streaming.jar \
    -input myInputDirs \
    -output myOutputDir \
    -mapper /bin/cat \
    -reducer /bin/wc
```

### streaming示例
perl 语言的[streaming示例] 代码
```perl
-rw-rw-r--. 1 hadoop hadoop     48 2月  22 10:47 data
-rw-rw-r--. 1 hadoop hadoop 107399 2月  22 10:41 hadoop-streaming-1.2.1.jar
-rw-rw-r--. 1 hadoop hadoop    186 2月  22 10:45 mapper.pl
-rw-rw-r--. 1 hadoop hadoop    297 2月  22 10:55 reducer.pl
##
$ ../bin/hadoop jar hadoop-streaming-1.2.1.jar -mapper mapper.pl -reducer reducer.pl -input /test/streaming -output /test/streamingout1 -file mapper.pl -file reducer.pl 
```

## Hadoop pipes 

1. Hadoop pipes 是 Hadoop MapReduce 的 C++ 的接口代称。不同于使用标准输入和输出来实现 map 代码和 reduce 代码之间的 Streaming。
2. Pipes 使用套接字 socket 作为 tasktracker 与 C++ 版本函数的进程间的通讯，未使用 JNI。
3. 与 Streaming 不同，Pipes 是 Socket 通讯，Streaming 是标准输入输出。

### 编译 Hadoop Pipes
编译c++ pipes( 确保操作系统提前安装好了 openssl,zlib,glib,openssl-devel)
Hadoop更目录下执行 
ant -Dcompile.c++=yes examples 

具体请参见《Hadoop Pipes 编译》

### Hadoop官方示例：
```shell
hadoop/src/examples/pipes/impl
 config.h.in
 sort.cc
wordcount-nopipe.cc
wordcount-part.cc
wordcount-simple.cc
```

运行前需要把可执行文件和输入数据上传到 hdfs：
```shell
$ ./bin/hadoop fs -mkdir /test/pipes/input
$ ./bin/hadoop fs -put a.txt /test/pipes/input 
$ ./bin/hadoop fs -cat /test/pipes/input/a.txt 
hello hadoop hello hive hello hbase hello zk
```
上传执行文件，重新命名为/test/pipes/exec
```shell
$ ./bin/hadoop fs -put ./build/c++-examples/Linux-amd64-64/bin/wordcount-simple /test/pipes/exec
```
在编译好的文件夹目录下执行
```
$ cd hadoop/build/c++-examples/Linux-amd64-64/bin
$ ../../../../bin/hadoop pipes -Dhadoop.pipes.java.recordreader=true -Dhadoop.pipes.java.recordwriter=true -reduces 4 -input /test/pipes/input -output /test/pipes/input/output1 -program /test/pipes/execs
```
执行结果如下：
```
$ ./bin/hadoop fs -cat /test/pipes/input/output1/part-00000 hbase 1 
$ ./bin/hadoop fs -cat /test/pipes/input/output1/part-00001 hello 4 hive 1 
$ ./bin/hadoop fs -cat /test/pipes/input/output1/part-00002 hadoop 1 zk 1 
$ ./bin/hadoop fs -cat /test/pipes/input/output1/part-00003
```

### 参考博客：
* [Hadoop pipes编程]
* [Hadoop Pipes运行机制]



[streaming示例]: https://github.com/kangfoo/hadoop1.study/tree/master/kangfoo/study.hdfs/src/main/java/com/kangfoo/study/hadoop1/streaming

[开源力量]: http://new.osforce.cn/?mu=20140227220525KZol8ENMYdFQ6SjMveU26nEZ

[开源力量培训课-Hadoop Development]: http://new.osforce.cn/course/101?mc101=20140301233857au7XG16o9ukfev1pmFCOfv2s

[Hadoop pipes编程]: http://dongxicheng.org/mapreduce/hadoop-pipes-programming/

[Hadoop Pipes运行机制]: http://hongweiyi.com/2012/05/hadoop-pipes-src/

