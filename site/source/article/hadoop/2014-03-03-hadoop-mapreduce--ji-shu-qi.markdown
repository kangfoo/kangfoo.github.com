---
layout: post
title: Hadoop MapReduce 计数器
date: '2014-03-03 22:22'
comments: true
published: true
keywords: Hadoop MapReduce 计数器
description: Hadoop MapReduce 计数器
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---

计数器是一种收集系统信息有效手段，用于质量控制或应用级统计。可辅助诊断系统故障。计数器可以比日志更方便的统计事件发生次数。

### 内置计数器

Hadoop 为每个作业维护若干内置计数器，主要用来记录作业的执行情况。

#### 内置计数器包括

* MapReduce 框架计数器（Map-Reduce Framework）
* 文件系统计数器（FielSystemCounters）
* 作业计数器（Job Counters）
* 文件输入格式计数器（File Output Format Counters）
* 文件输出格式计数器（File Input Format Counters）

<!--表格数据太多，暂缓。 TODO-->
<!--<div  style="height:0px;border-bottom:1px dashed red"></div>
<table width="100%" border="1" cellpadding="3"  cellspacing="0" bordercolor="#eeeeee">
<tbody>
<tr>
	<td><em>组别 </em></td>
	<td><em>计数器名称 </em></td>
	<td><em>说明 </em></td>
</tr>
<tr>
	<th rowspan=13>Map-Reduce <br>Framework </th>
	<td>Map input records </td>
	<td>作业中所有的 map 已处理的输入纪录数。每次 RecordReader 读到一条纪录并将其传递给 map 的 map() 函数时，此计数器的值增加 </td>
</tr>
<tr>
	<td>Map skipped records </td>
	<td>作业中所有 map 跳过的输入纪录数。 </td>
</tr>
</tbody>
</table>
-->

计数器由其关联的 task 进行维护，定期传递给 tasktracker，再由 tasktracker 传给 jobtracker。因此，计数器能够被全局地聚集。内置计数器实际由 jobtracker 维护，不必在整个网络发送。

一个任务的计数器值每次都是完整传输的，仅当一个作业执行成功之后，计数器的值才完整可靠的。

### 自定义Java计数器

MapReduce 允许用户自定义计数器，MapReduce 框架将跨所有 map 和 reduce 聚集这些计数器，并在作业结束的时候产生一个最终的结果。

计数器的值可以在 mapper 或者 reducer 中添加。多个计数器可以由一个 java 枚举类型来定义，以便对计数器分组。一个作业可以定义的枚举类型数量不限，个个枚举类型所包含的数量也不限。

枚举类型的名称即为组的名称，枚举类型的字段即为计数器名称。

在 TaskInputOutputContext 中的 counter
```java
 public Counter getCounter(Enum<?> counterName) {
    return reporter.getCounter(counterName);
  }
  public Counter getCounter(String groupName, String counterName) {
    return reporter.getCounter(groupName, counterName);
  }
```
####计数器递增
org.apache.hadoop.mapreduce.Counter类
```java
  public synchronized void increment(long incr) {
    value += incr;
  }
```

#### 计数器使用
* WebUI 查看（50030）；
* 命令行方式：hadoop job [-counter <job-id> <group-name> <counter-name>]；
* 使用Hadoop API。
通过job.getCounters()得到Counters,而后调用counters.findCounter()方法去得到计数器对象；可参见《Hadoop权威指南》第8章 示例 8-2 MissingTemperaureFields.java

#### 命令行方式示例
```shell
$ ./bin/hadoop job -counter  job_201402211848_0004 FileSystemCounters HDFS_BYTES_READ
177
```

### 自定义计数器

统计词汇行中词汇数超过2个或少于2个的行数。 源代码： [TestCounter.java]TestCounter.java

#### 输入数据文件值 counter.txt:
```text
hello world
hello
hello world 111
hello world 111 222
```
执行参数
```java
hdfs://master11:9000/counter/input/a.txt hdfs://master11:9000/counter/output1
```

计数器统计(hadoop eclipse 插件执行)结果：
```shell
2014-02-21 00:03:38,676 INFO  mapred.JobClient (Counters.java:log(587)) -   ERROR_COUNTER
2014-02-21 00:03:38,677 INFO  mapred.JobClient (Counters.java:log(589)) -     Above_2=2
2014-02-21 00:03:38,677 INFO  mapred.JobClient (Counters.java:log(589)) -     BELOW_2=1
```

[TestCounter.java]: https://github.com/kangfoo/hadoop1.study/blob/master/kangfoo/study.hdfs/src/main/java/com/kangfoo/study/hadoop1/mp/counter/TestCounter.java


