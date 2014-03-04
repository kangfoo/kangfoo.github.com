---
layout: post
title: Hadoop MapReduce Partitioner 组件
date: '2014-03-03 22:20'
comments: true
published: true
keywords: Hadoop MapReduce Partitioner 组件
description: Hadoop MapReduce Partitioner 组件练习
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---

Partitioner 过程发生在循环缓冲区发生溢写文件之后，merge 之前。可以让 Map 对 Key 进行分区，从而可以根据不同的 key 来分发到不同的 reducer 中去处理；

Hadoop默认的提供的是HashPartitioner。

可以自定义 key 的分发规则，自定义Partitioner：

* 继承抽象类Partitioner，实现自定义的getPartition（）方法；
* 通过job.setPartitionerClass（）来设置自定义的Partitioner；

### Partitioner 类

旧api
```java
public interface Partitioner<K2, V2> extends JobConfigurable {
  int getPartition(K2 key, V2 value, int numPartitions);
}
```
新api
```java
public abstract class Partitioner<KEY, VALUE> {
  public abstract int getPartition(KEY key, VALUE value, int numPartitions);  
}
```

### Partitioner应用场景演示
需求：利用 Hadoop MapReduce 作业 Partitioner 组件分别统计每种商品的周销售情况。源代码 [TestPartitioner.java]。**出自于 [开源力量] LouisT 老师的[开源力量培训课-Hadoop Development]课件。** (可使用 PM2.5 数据代替此演示程序)

* site1的周销售清单（a.txt,以空格分开）：
```text
shoes	20
hat	10
stockings	30
clothes	40
```

* site2的周销售清单（b.txt，以空格分开）：
```text
shoes	15
hat	1
stockings	90
clothes	80
```

* 汇总结果：
```text
shoes     35
hat       11
stockings 120
clothes   120
```

* 准备测试数据
```shell
$ ./bin/hadoop fs -mkdir /testPartitioner/input
$ ./bin/hadoop fs -put a.txt /testPartitioner/input
$ ./bin/hadoop fs -put b.txt /testPartitioner/input
$ ./bin/hadoop fs -lsr /testPartitioner/input
-rw-r--r--   2 hadoop supergroup         52 2014-02-18 22:53 /testPartitioner/input/a.txt
-rw-r--r--   2 hadoop supergroup         50 2014-02-18 22:53 /testPartitioner/input/b.txt
```

* 执行 MapReduce 作业
此处使用 hadoop jar 命令执行，eclipse 插件方式有一定的缺陷。(hadoop eclipse 执行出现java.io.IOException: Illegal partition for hat (1))
```shell
$ ./bin/hadoop jar study.hdfs-0.0.1-SNAPSHOT.jar TestPartitioner /testPartitioner/input /testPartitioner/output10
```

* 结果。 四个分区，分别存储上述四种产品的总销量的统计结果值。
```shell
-rw-r--r--   2 hadoop supergroup          9 2014-02-19 00:18 /testPartitioner/output10/part-r-00000
-rw-r--r--   2 hadoop supergroup          7 2014-02-19 00:18 /testPartitioner/output10/part-r-00001
-rw-r--r--   2 hadoop supergroup         14 2014-02-19 00:18 /testPartitioner/output10/part-r-00002
-rw-r--r--   2 hadoop supergroup         12 2014-02-19 00:18 /testPartitioner/output10/part-r-00003
```

[TestPartitioner.java]: https://github.com/kangfoo/hadoop1.study/blob/master/kangfoo/study.hdfs/src/main/java/com/kangfoo/study/hadoop1/mp/typeformat/TestPartitioner.java

[开源力量]: http://new.osforce.cn/?mu=20140227220525KZol8ENMYdFQ6SjMveU26nEZ

[开源力量培训课-Hadoop Development]: http://new.osforce.cn/course/101?mc101=20140301233857au7XG16o9ukfev1pmFCOfv2s