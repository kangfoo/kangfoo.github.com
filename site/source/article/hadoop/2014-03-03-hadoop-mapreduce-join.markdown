---
layout: post
title: Hadoop MapReduce Join
date: '2014-03-03 22:23'
comments: true
published: true
keywords: Hadoop MapReduce Join
description: Hadoop MapReduce Join
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---

在 Hadoop 中可以通过 MapReduce，Pig，hive，Cascading编程进行大型数据集间的连接操作。连接操作如果由 Mapper 执行，则称为“map端连接”；如果由 Reduce 执行，则称为“Reduce端连接”。

连接操作的具体实现技术取决于数据集的规模以及分区方式。</br>
若一个数据集很大而另一个数据集很小，以至于可以分发到集群中的每一个节点之中，则可以执行一个 MapReduce 作业，将各个数据集的数据放到一起，从而实现连接。</br>
若两个数据规模均很大，没有哪个数据集可以完全复制到集群的每个节点，可以使用 MapReduce 作业进行连接，使用 Map 端连接还是 Reduce 端连接取决于数据的组织方式。</br>

Map端连接将所有的工作在 map 中操作，效率高但是不通用。而 Reduce 端连接利用了 shuff 机制，进行连接，效率不高。

DistributedCache 能够在任务运行过程中及时地将文件和存档复制到任务节点进行本地缓存以供使用。各个文件通常只复制到一个节点一次。可用 api 或者命令行在需要的时候将本地文件添加到 hdfs 文件系统中。

本文中的示例 **出自于 [开源力量] LouisT 老师的[开源力量培训课-Hadoop Development]课件。** 

### Map端连接

Map 端联接是指数据到达 map 处理函数之前进行合并的。它要求 map 的输入数据必须先分区并以特定的方式排序。各个输入数据集被划分成相同数量的分区，并均按相同的键排序（连接键）。同一键的所有输入纪录均会放在同一个分区。以满足 MapReduce 作业的输出。

若作业的 Reduce 数量相同、键相同、输入文件是不可切分的，那么 map 端连接操作可以连接多个作业的输出。

在 Map 端连接效率比 Reduce 端连接效率高（Reduce端Shuff耗时），但是要求比较苛刻。

#### 基本思路

1. 将需要 join 的两个文件，一个存储在 HDFS 中，一个使用 DistributedCache.addCacheFile() 将需要 join 另一个文件加入到所有 Map 的缓存里(DistributedCache.addCacheFile() 需要在作业提交前设置)；
1. 在 Map 函数里读取该文件，进行 Join；
1. 将结果输出到 reduce 端；

#### 使用步骤

1. 在 HDFS 中上传文件（文本文件、压缩文件、jar包等）；
2. 调用相关API添加文件信息；
3. task运行前直接调用文件读写API获取文件；


### Reduce端Join

reduce 端联接比 map 端联接更普遍，因为输入的数据不需要特定的结构；效率低（所有数据必须经过shuffle过程）。

#### 基本思路

1. Map 端读取所有文件，并在输出的内容里加上标识代表数据是从哪个文件里来的；
1. 在 reduce 处理函数里，对按照标识对数据进行保存；
1. 然后根据 Key 的 Join 来求出结果直接输出；

### 示例程序

使用 MapReduce map 端join 或者 reduce 端 join 实现如下两张表 emp, dep 中的 SQL 联合查询的数据效果。
```text
Table EMP：（新建文件EMP，第一行属性名不要）
----------------------------------------
Name      Sex      Age     DepNo
zhang      male     20           1     
li              female  25           2
wang       female  30           3
zhou        male     35           2
----------------------------------------
Table Dep：（新建文件DEP，第一行属性名不要）
DepNo     DepName
     1            Sales
     2            Dev
     3            Mgt
------------------------------------------------------------     
SQL：
select name,sex ,age, depName from emp inner join DEP on EMP.DepNo = Dep.DepNo
----------------------------------------
实现效果：
$ ./bin/hadoop fs -cat /reduceSideJoin/output11/part-r-00000
zhang male 20 sales
li female 25 dev
wang female 30 dev
zhou male 35 dev
```

Map 端 Join 的例子：[TestMapSideJoin] </br>
Reduce 端 Join 的例子：[TestReduceSideJoin] </br>

[TestMapSideJoin]: https://github.com/kangfoo/hadoop1.study/blob/master/kangfoo/study.hdfs/src/main/java/com/kangfoo/study/hadoop1/mp/join/TestMapSideJoin.java

[TestReduceSideJoin]: https://github.com/kangfoo/hadoop1.study/blob/master/kangfoo/study.hdfs/src/main/java/com/kangfoo/study/hadoop1/mp/join/TestReduceSideJoin.java


[开源力量]: http://new.osforce.cn/?mu=20140227220525KZol8ENMYdFQ6SjMveU26nEZ

[开源力量培训课-Hadoop Development]: http://new.osforce.cn/course/101?mc101=20140301233857au7XG16o9ukfev1pmFCOfv2s
