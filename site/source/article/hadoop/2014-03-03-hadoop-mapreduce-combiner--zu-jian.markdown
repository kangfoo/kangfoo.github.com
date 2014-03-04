---
layout: post
title: Hadoop MapReduce Combiner 组件
date: '2014-03-03 22:19'
comments: true
published: true
keywords: hadoop combiner 组件练习
description: hadoop combiner 组件练习
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---

<!-- 参考博客，学习怎么写明了。 http://blog.csdn.net/heyutao007/article/details/5725379-->

combiner 作用是把一个 map 产生的多个 <key,valeu> 合并成一个新的 <key,valeu>，然后再将新的 <key,valeu> 作为 reduce 的输入；

combiner 函数在 map 函数与 reduce 函数之间，目的是为了减少 map 输出的中间结果，减少 reduce 复制 map 输出的数据，减少网络传输负载；

并不是所有情况下都能使用 Combiner 组件，它适用于对记录汇总的场景（如求和，平均数不适用）

#### 什么时候运行 Combiner

* 当 job 设置了 Combiner，并且 spill 的个数达到 min.num.spill.for.combine (默认是3)的时候，那么 combiner 就会 Merge 之前执行；
* 但是有的情况下，Merge 开始执行，但 spill 文件的个数没有达到需求，这个时候 Combiner 可能会在Merge 之后执行；
* Combiner 也有可能不运行，Combiner 会考虑当时集群的一个负载情况。

#### 测试 Combinner 过程

代码 [TestCombiner]

1. 以 wordcount.txt 为输入的词频统计
```shell
$ ./bin/hadoop fs -lsr /test3/input
drwxr-xr-x   - hadoop supergroup          0 2014-02-18 00:28 /test3/input/test
-rw-r--r--   2 hadoop supergroup        983 2014-02-18 00:28 /test3/input/test/wordcount.txt
-rw-r--r--   2 hadoop supergroup        626 2014-02-18 00:28 /test3/input/test/wordcount2.txt
```

1. **不启用 Reducer** (输出，字节变大)
```shell
drwxr-xr-x   - kangfoo-mac supergroup          0 2014-02-18 00:29 /test3/output1
-rw-r--r--   3 kangfoo-mac supergroup          0 2014-02-18 00:29 /test3/output1/_SUCCESS
-rw-r--r--   3 kangfoo-mac supergroup       1031 2014-02-18 00:29 /test3/output1/part-m-00000 (-m 没有 reduce 过程的中间结果，每个数据文件对应一个数据分片,每个分片对应一个map任务)
-rw-r--r--   3 kangfoo-mac supergroup        703 2014-02-18 00:29 /test3/output1/part-m-00001
```
结果如下（map过程并不合并相同key的value值）：
```shell
drwxr-xr-x	1
${'-'}	1
hadoop	1
supergroup	1
0	1
2014-02-17	1
21:03	1
/home/hadoop/env/mapreduce	1
drwxr-xr-x	1
${'-'}	1
hadoop	1
```
1. **启用 Reducer**
```shell
drwxr-xr-x   - kangfoo-mac supergroup          0 2014-02-18 00:29 /test3/output1
-rw-r--r--   3 kangfoo-mac supergroup          0 2014-02-18 00:29 /test3/output1/_SUCCESS
-rw-r--r--   3 kangfoo-mac supergroup       1031 2014-02-18 00:29 /test3/output1/part-m-00000
-rw-r--r--   3 kangfoo-mac supergroup        703 2014-02-18 00:29 /test3/output1/part-m-00001
drwxr-xr-x   - kangfoo-mac supergroup          0 2014-02-18 00:31 /test3/output2
-rw-r--r--   3 kangfoo-mac supergroup          0 2014-02-18 00:31 /test3/output2/_SUCCESS
-rw-r--r--   3 kangfoo-mac supergroup        705 2014-02-18 00:31 /test3/output2/part-r-00000
```
结果：
```text
0:17:31,680	6
014-02-18	1
2014-02-17	11
2014-02-18	5
21:02	7
```

1. 在日志或者 http://master11:50030/jobtracker.jsp 页面查找是否执行过 Combine 过程。
日志截取如下：
```text
2014-02-18 00:31:29,894 INFO  SPLIT_RAW_BYTES=233
2014-02-18 00:31:29,894 INFO  Combine input records=140
2014-02-18 00:31:29,894 INFO  Reduce input records=43
2014-02-18 00:31:29,894 INFO  Reduce input groups=42
2014-02-18 00:31:29,894 INFO  Combine output records=43
2014-02-18 00:31:29,894 INFO  Reduce output records=42
2014-02-18 00:31:29,894 INFO  Map output records=140
```

[TestCombiner]: https://github.com/kangfoo/hadoop1.study/blob/fa6e68e52aa12ed0e22f98e6109f376ffbb6431f/kangfoo/study.hdfs/src/main/java/com/kangfoo/study/hadoop1/mp/typeformat/TestCombiner.java
