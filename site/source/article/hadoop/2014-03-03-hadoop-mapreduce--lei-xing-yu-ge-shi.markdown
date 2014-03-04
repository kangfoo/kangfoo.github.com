---
layout: post
title: Hadoop MapReduce 类型与格式
date: '2014-03-03 22:18'
comments: true
published: true
keywords: Hadoop MapReduce 类型与格式
description: Hadoop MapReduce 类型与格式
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---

MapReduce 的 map和reduce函数的输入和输出是键/值对(key/value pair) 形式的数据处理模型。

## MapReduce 的类型
Hadoop1.x MapReduce 有2套API.旧api偏向与接口，新api偏向与抽象类，如无特殊默认列举为旧的api作讨论.

在Hadoop的MapReduce中，map和reduce函数遵循如下格式：

* map(K1, V1) –> list (K2, V2)   // map：对输入分片数据进行过滤数据，组织 key/value 对等操作         
* combine(K2, list(V2)) –> list(K2, V2) // 在map端对输出进行预处理，类似 reduce。combine 不一定适用任何情况，如：对总和求平均数。选用。
* partition(K2, V2) –> integer    // 将中间键值对划分到一个 reduce 分区，返回分区索引号。实际上，分区单独由键决定(值是被忽略的)，分区内的键会排序，相同的键的所有值会合成一个组（list(V2)）          
* reduce(K2, list(V2)) –> list(K3, V3) // 每个 reduce 会处理具有某些特性的键，每个键上都有值的序列，是通过对所有 map 输出的值进行统计得来的，reduce 根据所有map传来的结果，最后进行统计合并操作，并输出结果。

旧api类代码
```java
public interface Mapper<K1, V1, K2, V2> extends JobConfigurable, Closeable {  
  void map(K1 key, V1 value, OutputCollector<K2, V2> output, Reporter reporter) throws IOException;
}
//
public interface Reducer<K2, V2, K3, V3> extends JobConfigurable, Closeable {
  void reduce(K2 key, Iterator<V2> values, OutputCollector<K3, V3> output, Reporter reporter) throws IOException;
}
//
public interface Partitioner<K2, V2> extends JobConfigurable {
   int getPartition(K2 key, V2 value, int numPartitions);
}
```
新api类代码
```java
public class Mapper<KEYIN, VALUEIN, KEYOUT, VALUEOUT> {
… …
  protected void map(KEYIN key, VALUEIN value, 
                     Context context) throws IOException, InterruptedException {
    context.write((KEYOUT) key, (VALUEOUT) value);
  }
… …
}
//
public class Reducer<KEYIN,VALUEIN,KEYOUT,VALUEOUT> {
… …
 protected void reduce(KEYIN key, Iterable<VALUEIN> values, Context context
                        ) throws IOException, InterruptedException {
    for(VALUEIN value: values) {
      context.write((KEYOUT) key, (VALUEOUT) value);
    }
  }
… …
}
//
public interface Partitioner<K2, V2> extends JobConfigurable {
  int getPartition(K2 key, V2 value, int numPartitions);
}
```

默认的 partitioner 是 HashPartitioner，对键进行哈希操作以决定该记录属于哪个分区让 reduce 处理，每个分区对应一个 reducer 任务。总槽数 solt＝集群中节点数 ＊ 每个节点的任务槽。实际值应该比理论值要小，以空闲一部分在错误容忍是备用。

HashPartitioner的实现
```java
public class HashPartitioner<K, V> extends Partitioner<K, V> {
    public int getPartition(K key, V value, int numReduceTasks) {
        return (key.hashCode() & Integer.MAX_VALUE) % numReduceTasks;
    }
}
```

hadooop1.x 版本中
* 旧的api,map 默认的 IdentityMapper, reduce 默认的是 IdentityReducer
* 新的api,map 默认的 Mapper, reduce 默认的是 Reducer

默认MapReduce函数实例程序
```java
public class MinimalMapReduceWithDefaults extends Configured implements Tool {
    @Override
    public int run(String[] args) throws Exception {
        Job job = JobBuilder.parseInputAndOutput(this, getConf(), args);
        if (job == null) {
            return -1;
            }
        //
        job.setInputFormatClass(TextInputFormat.class);
        job.setMapperClass(Mapper.class);
        job.setMapOutputKeyClass(LongWritable.class);
        job.setMapOutputValueClass(Text.class);
        job.setPartitionerClass(HashPartitioner.class);
        job.setNumReduceTasks(1);
        job.setReducerClass(Reducer.class);
        job.setOutputKeyClass(LongWritable.class);
        job.setOutputValueClass(Text.class);
        job.setOutputFormatClass(TextOutputFormat.class);
        return job.waitForCompletion(true) ? 0 : 1;
        }
    //
    public static void main(String[] args) throws Exception {
        int exitCode = ToolRunner.run(new MinimalMapReduceWithDefaults(), args);
        System.exit(exitCode);
        }
}
```

## 输入格式

### 输入分片与记录

一个输入分片(input split)是由单个 map 处理的输入块，即每一个 map 只处理一个输入分片，每个分片被划分为若干个记录( records )，每条记录就是一个 key/value 对，map 一个接一个的处理每条记录，输入分片和记录都是逻辑的，不必将他们对应到文件上。数据分片由数据块大小决定的。

注意，一个分片不包含数据本身，而是指向数据的引用( reference )。

输入分片在Java中被表示为InputSplit抽象类
```java
public interface InputSplit extends Writable {
  long getLength() throws IOException;
  String[] getLocations() throws IOException;
}
```
InputFormat负责创建输入分片并将它们分割成记录，抽象类如下：
```java
public interface InputFormat<K, V> {
  InputSplit[] getSplits(JobConf job, int numSplits) throws IOException;
  RecordReader<K, V> getRecordReader(InputSplit split,
                                     JobConf job, 
                                     Reporter reporter) throws IOException;
}
```

客户端通过调用 getSpilts() 方法获得分片数目(怎么调到的？)，在 TaskTracker 或 NodeManager上，MapTask 会将分片信息传给 InputFormat 的
createRecordReader() 方法，进而这个方法来获得这个分片的 RecordReader，RecordReader 基本就是记录上的迭代器，MapTask 用一个 RecordReader 来生成记录的 key/value 对，然后再传递给 map 函数，如下步骤：

1. jobClient调用getSpilts()方法获得分片数目，将numSplits作为参数传入，以参考。InputFomat实现有自己的getSplits()方法。 
2. 客户端将他们发送到jobtracker
3. jobtracker使用其存储位置信息来调度map任务从而在tasktracker上处理分片数据
4. 在tasktracker上，map任务把输入分片传给InputFormat上的getRecordReader()方法，来获取分片的RecordReader。
5. map 用一个RecordReader来生成纪录的键值对。
6. RecordReader的next()方法被调用，知道返回false。map任务结束。

MapRunner 类部分代码（旧api）
```java
public class MapRunner<K1, V1, K2, V2>
    implements MapRunnable<K1, V1, K2, V2> {
… … 
 public void run(RecordReader<K1, V1> input, OutputCollector<K2, V2> output,
                  Reporter reporter)
    throws IOException {
    try {
      // allocate key & value instances that are re-used for all entries
      K1 key = input.createKey();
      V1 value = input.createValue();
      //
      while (input.next(key, value)) {
        // map pair to output
        mapper.map(key, value, output, reporter);
        if(incrProcCount) {
          reporter.incrCounter(SkipBadRecords.COUNTER_GROUP, 
              SkipBadRecords.COUNTER_MAP_PROCESSED_RECORDS, 1);
        }
      }
    } finally {
      mapper.close();
    }
  }
……
}
```

### FileInputFormat类

FileInputFormat是所有使用文件为数据源的InputFormat实现的基类，它提供了两个功能：一个定义哪些文件包含在一个作业的输入中；一个为输入文件生成分片的实现，把分片割成记录的作业由其子类来完成。

**下图为InputFormat类的层次结构**：
![image](http://zhaomingtai.u.qiniudn.com/FileInputFormat.png)

#### FileInputFormat 类输入路径

FileInputFormat 提供四种静态方法来设定 Job 的输入路径，其中下面的 addInputPath() 方法  addInputPaths() 方法可以将一个或多个路径加入路径列表，setInputPaths() 方法一次设定完整的路径列表(可以替换前面所设路 径)
```java
public static void addInputPath(Job job, Path path);
public static void addInputPaths(Job job, String commaSeparatedPaths);
public static void setInputPaths(Job job, Path... inputPaths);
public static void setInputPaths(Job job, String commaSeparatedPaths);
```
如果需要排除特定文件，可以使用 FileInputFormat 的 setInputPathFilter() 设置一个过滤器：
`public static void setInputPathFilter(Job job, Class<? extends PathFilter> filter);`
它默认过滤隐藏文件中以"_"和"."开头的文件
```java
  private static final PathFilter hiddenFileFilter = new PathFilter(){
      public boolean accept(Path p){
        String name = p.getName(); 
        return !name.startsWith("_") && !name.startsWith("."); 
      }
    }; 
```

#### FileInputFormat 类的输入分片

FileInputFormat 类一般分割超过 HDFS 块大小的文件。通常分片与 HDFS 块大小一样，然后分片大小也可以改变的,下面展示了控制分片大小的属性：

待补。 TODO
```java
FileInputFormat computeSplitSize(long goalSize, long minSize,long blockSize) {
    return Math.max(minSize, Math.min(goalSize, blockSize));
}
```
即： 
`minimumSize < blockSize < maximumSize 分片的大小即为块大小。`

重载 FileInputFormat 的 isSplitable() ＝false 可以避免 mapreduce 输入文件被分割。

#### 小文件与CombineFileInputFormat

1. CombineFileInputFormat 是针对小文件设计的，CombineFileInputFormat 会把多个文件打包到一个分片中，以便每个 mapper 可以处理更多的数据；减少大量小文件的另一种方法可以使用 SequenceFile 将这些小文件合并成一个或者多个大文件。

2. CombineFileInputFormat 不仅对于处理小文件实际上对于处理大文件也有好处，本质上，CombineFileInputFormat 使 map 操作中处理的数据量与 HDFS 中文件的块大小之间的耦合度降低了

3. CombineFileInputFormat 是一个抽象类，没有提供实体类，所以需要实现一个CombineFileInputFormat 具体
类和 getRecordReader() 方法(旧的接口是这个方法，新的接口InputFormat中则是createRecordReader())

#### 把整个文件作为一条记录处理
有时，mapper 需要访问问一个文件中的全部内容。即使不分割文件，仍然需要一个 RecordReader 来读取文件内容为 record 的值，下面给出实现这个功能的完整程序，详细解释见《Hadoop权威指南》。

#### 文本处理
1. **TextInputFileFormat** 是默认的 InputFormat，每一行就是一个纪录
2. TextInputFileFormat 的 key 是 LongWritable 类型，存储该行在整个文件的偏移量，value 是每行的数据内容，不包括任何终止符(换行符和回车符)，它是Text类型.
如下例
On the top of the Crumpetty Tree</br>
</br>
The Quangle Wangle sat,</br>
But his face you could not see,</br>
On account of his Beaver Hat.</br>
每条记录表示以下key/value对</br>
(0, On the top of the Crumpetty Tree)</br>
(33, The Quangle Wangle sat,)</br>
(57, But his face you could not see,)</br>
(89, On account of his Beaver Hat.

3. 输入分片与 HDFS 块之间的关系：TextInputFormat 每一条纪录就是一行，很可能某一行跨数据库存放。

![image](http://zhaomingtai.u.qiniudn.com/Figure%207-3.%20Logical%20records%20and%20HDFS%20blocks%20for%20TextInputFormat.png)

4. **KeyValueTextInputFormat**。对下面的文本，KeyValueTextInputFormat 比较适合处理，其中可以通过 
mapreduce.input.keyvaluelinerecordreader.key.value.separator 属性设置指定分隔符，默认
值为制表符，以下指定"→"为分隔符
</br>
line1→On the top of the Crumpetty Tree</br>
line2→The Quangle Wangle sat,</br>
line3→But his face you could not see,</br>
line4→On account of his Beaver Hat.

5. **NLineInputFormat**。如果希望 mapper 收到固定行数的输入，需要使用 NLineInputFormat 作为 InputFormat 。与 TextInputFormat 一样，key是文件中行的字节偏移量，值是行本身。

N 是每个 mapper 收到的输入行数，默认时 N=1，每个 mapper 会正好收到一行输入，mapreduce.input.lineinputformat.linespermap 属性控制 N 的值。以刚才的文本为例。
如果N=2，则每个输入分片包括两行。第一个 mapper 会收到前两行 key/value 对：

(0, On the top of the Crumpetty Tree)</br>
(33, The Quangle Wangle sat,)</br>
另一个mapper则收到：</br>
(57, But his face you could not see,)</br>
(89, On account of his Beaver Hat.)</br>

#### 二进制输入

**SequenceFileInputFormat**
如果要用顺序文件数据作为 MapReduce 的输入，应用 SequenceFileInputFormat。key 和 value 顺序文件，所以要保证map输入的类型匹配

SequenceFileInputFormat 可以读 MapFile 和 SequenceFile，如果在处理顺序文件时遇到目录，SequenceFileInputFormat 类会认为值正在读 MapFile 数据文件。

**SequenceFileAsTextInputFormat** 是 SequenceFileInputFormat 的变体。将顺序文件(其实就是SequenceFile)的 key 和 value 转成 Text 对象

**SequenceFileAsBinaryInputFormat**是 SequenceFileInputFormat 的变体。将顺序文件的key和value作为二进制对象

#### 多种输入

对于不同格式，不同表示的文本文件输出的处理，可以用 **MultipleInputs** 类里处理，它允许为每条输入路径指定 InputFormat 和 Mapper。

MultipleInputs 类有一个重载版本的 addInputPath()方法：

* 旧api列举
```java
 public static void addInputPath(JobConf conf, Path path, Class<? extends InputFormat> inputFormatClass) 
```
* 新api列举
```java
public static void addInputPath(Job job, Path path, Class<? extends InputFormat> inputFormatClass) 
```
在有多种输入格式只有一个mapper时候(调用Job的setMapperClass()方法)，这个方法会很有用。

#### DBInputFormat
JDBC从关系数据库中读取数据的输入格式(参见权威指南)


## 输出格式

OutputFormat类的层次结构

![image](http://zhaomingtai.u.qiniudn.com/Figure%207-4.%20OutputFormat%20class%20hierarchy.png)

### 文本输出

默认输出格式是 **TextOutputFormat**，它本每条记录写成文本行，key/value 任意，这里 key和value 可以用制表符分割，用 mapreduce.output.textoutputformat.separator 书信可以改变制表符，与TextOutputFormat 对应的输入格式是 KeyValueTextInputFormat。

可以使用 NullWritable 来省略输出的 key 和 value。

### 二进制输出

* **SequenceFileOutputFormat** 将它的输出写为一个顺序文件，因为它的格式紧凑，很容易被压缩，所以易于作为 MapReduce 的输入
* 把key/value对作为二进制格式写到一个 SequenceFile 容器中
* MapFileOutputFormat 把 MapFile 作为输出，MapFile 中的 key 必需顺序添加，所以必须确保 reducer 输出的 key 已经排好序。

### 多个输出
* **MultipleOutputFormat** 类可以将数据写到多个文件中，这些文件名称源于输出的键和值。MultipleOutputFormat是个抽象类，它有两个子类：**MultipleTextOutputFormat** 和 **MultipleSequenceFileOutputFormat** 。它们是 TextOutputFormat 的和 SequenceOutputFormat 的多版本。

* **MultipleOutputs** 类
用于生成多个输出的库，可以为不同的输出产生不同的类型，无法控制输出的命名。它用于在原有输出基础上附加输出。输出是制定名称的。

#### MultipleOutputFormat和MultipleOutputs的区别

这两个类库的功能几乎相同。MultipleOutputs 功能更齐全，但 MultipleOutputFormat 对 目录结构和文件命令更多de控制。 
				
<div  style="height:0px;border-bottom:1px dashed red"></div>
<table width="100%" border="1" cellpadding="3"  cellspacing="0" bordercolor="#eeeeee">
<tbody>
<tr>
	<td><em>特征	 </em></td>
	<td><em>MultipleOutputFormat </em></td>
	<td><em>MultipleOutputs </em></td>
</tr>
<tr>
	<td>完全控制文件名和目录名 </td>
	<td>是 </td>
	<td>否 </td>
</tr>
<tr>
	<td>不同输出有不同的键和值类型 </td>
	<td>否 </td>
	<td>是 </td>
</tr>
<tr>
	<td>从同一作业的map和reduce使用 </td>
	<td>否 </td>
	<td>是 </td>
</tr>
<tr>
	<td>每个纪录多个输出 </td>
	<td>否 </td>
	<td>是 </td>
</tr>
<tr>
	<td>与任意OutputFormat一起使用 </td>
	<td>否，需要子类 </td>
	<td>是 </td>
</tr>
</tbody>
</table>

### 延时输出

有些文件应用倾向于不创建空文件，此时就可以利用 LazyOutputFormat (Hadoop 0.21.0版本之后开始提供)，它是一个封装输出格式，可以保证指定分区第一条记录输出时才真正的创建文件，要使用它，用JobConf和相关输出格式作为参数来调用 setOutputFormatClass() 方法.

Streaming 和 Pigs 支持 -LazyOutput 选项来启用 LazyOutputFormat功能。

### 数据库输出
参见 关系数据和 HBase的输出格式。
 
## 练习代码

代码路径
https://github.com/kangfoo/hadoop1.study/blob/master/kangfoo/study.hdfs/src/main/java/com/kangfoo/study/hadoop1/mp/typeformat </br>
使用 maven 打包之后用 hadoop jar 命令执行</br>
步骤同 Hadoop example jar 类

1. 使用 TextInputFormat 类型测试 wordcount
TestMapreduceInputFormat
上传一个文件
```shell
$ ./bin/hadoop fs -mkdir /test/input1
$ ./bin/hadoop fs -put ./wordcount.txt /test/input1
```
使用maven 打包 或者用eclipse hadoop 插件, 执行主函数时设置如下参数</br>
```text
hdfs://master11:9000/test/input1/wordcount.txt hdfs://master11:9000/numbers.seq hdfs://master11:9000/test/output5
```
没改过端口默认 namenode RPC 交互端口 8020 将上述的 9000 改成你自己的端口即可。</br>
部分日志
```shell
## 准备运行程序和测试数据
lrwxrwxrwx.  1 hadoop hadoop      86 2月  17 21:02 study.hdfs-0.0.1-SNAPSHOT.jar -> /home/hadoop/env/kangfoo.study/kangfoo/study.hdfs/target/study.hdfs-0.0.1-SNAPSHOT.jar
-rw-rw-r--.  1 hadoop hadoop    1983 2月  17 20:18 wordcount.txt
##执行
$ ./bin/hadoop jar study.hdfs-0.0.1-SNAPSHOT.jar TestMapreduceInputFormat /test/input1/wordcount.txt /test/output1
```

1. 使用SequenceInputFormat类型测试wordcound 
使用Hadoop权威指南中的示例创建 /numbers.seq 文件
```shell
$ ./bin/hadoop fs -text /numbers.seq
$ ./bin/hadoop jar study.hdfs-0.0.1-SNAPSHOT.jar TestMapreduceSequenceInputFormat /numbers.seq /test/output2
```

1. 多文件输入
```shell
$  ./bin/hadoop jar study.hdfs-0.0.1-SNAPSHOT.jar TestMapreduceMultipleInputs /test/input1/wordcount.txt /numbers.seq /test/output3
```


## 博客参考
 [淘宝博客]

[淘宝博客]: http://www.taobaotest.com/categories/12/blogs

