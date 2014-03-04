---
layout: post
title: Hadoop MapReduce RecordReader 组件
date: '2014-03-03 22:21'
comments: true
published: true
keywords: Hadoop MapReduce RecordReader 组件练习
description: Hadoop MapReduce RecordReader 组件练习
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---

由 RecordReader 决定每次读取以什么样的方式读取数据分片中的一条数据。Hadoop 默认的 RecordReader 是 LineRecordReader（TextInputFormat 的 getRecordReader() 方法返回即是 LineRecordReader。二进制输入 SequenceFileInputFormat 的 getRecordReader() 方法返回即是SequenceFileRecordReader。）。LineRecordReader是用每行的偏移量作为 map 的 key，每行的内容作为 map 的 value；

它可作用于，自定义读取每一条记录的方式；自定义读入 key 的类型，如希望读取的 key 是文件的路径或名字而不是该行在文件中的偏移量。

### 自定义RecordReader一般步骤
1. 继承抽象类 RecordReader，实现 RecordReader 的实例；
1. 实现自定义 InputFormat 类，重写 InputFormat 中 createRecordReader() 方法，返回值是自定义的 RecordReader 实例；
（3）配置 job.setInputFormatClass() 设置自定义的 InputFormat 类型；

### TextInputFormat类源代码理解
源码见 org.apache.mapreduce.lib.input.TextInputFormat 类(新API)；

Hadoop 默认 TextInputFormat 使用 LineRecordReader。具体分析见注释。

```java
  public RecordReader<LongWritable, Text> 
    createRecordReader(InputSplit split,
                       TaskAttemptContext context) {
    return new LineRecordReader();
  }
// --> LineRecordReader
 public void initialize(InputSplit genericSplit,
                         TaskAttemptContext context) throws IOException {
    FileSplit split = (FileSplit) genericSplit;
    Configuration job = context.getConfiguration();
    this.maxLineLength = job.getInt("mapred.linerecordreader.maxlength",
                                    Integer.MAX_VALUE);
    start = split.getStart();  // 当前分片在整个文件中的起始位置
    end = start + split.getLength(); // 当前分片，在整个文件的位置
    final Path file = split.getPath();
    compressionCodecs = new CompressionCodecFactory(job);// 压缩
    codec = compressionCodecs.getCodec(file);
//
    // open the file and seek to the start of the split
    FileSystem fs = file.getFileSystem(job);
    FSDataInputStream fileIn = fs.open(split.getPath()); // 获取 FSDataInputStream
//
    if (isCompressedInput()) {
      decompressor = CodecPool.getDecompressor(codec);
      if (codec instanceof SplittableCompressionCodec) {
        final SplitCompressionInputStream cIn =
          ((SplittableCompressionCodec)codec).createInputStream(
            fileIn, decompressor, start, end,
            SplittableCompressionCodec.READ_MODE.BYBLOCK);
        in = new LineReader(cIn, job); //一行行读取
        start = cIn.getAdjustedStart(); // 可能跨分区读取
        end = cIn.getAdjustedEnd();// 可能跨分区读取
        filePosition = cIn;
      } else {
        in = new LineReader(codec.createInputStream(fileIn, decompressor),
            job);
        filePosition = fileIn;
      }
    } else {
      fileIn.seek(start);//  调整到文件起始偏移量
      in = new LineReader(fileIn, job); 
      filePosition = fileIn;
    }
    // If this is not the first split, we always throw away first record
    // because we always (except the last split) read one extra line in
    // next() method.
    if (start != 0) {
      start += in.readLine(new Text(), 0, maxBytesToConsume(start));
    }
    this.pos = start; // 在当前分片的位置
  }
//  --> getFilePosition() 指针读取到哪个位置
// filePosition 为 Seekable 类型
  private long getFilePosition() throws IOException {
    long retVal;
    if (isCompressedInput() && null != filePosition) {
      retVal = filePosition.getPos();
    } else {
      retVal = pos;
    }
    return retVal;
  }
//
// --> nextKeyValue() 
public boolean nextKeyValue() throws IOException {
    if (key == null) {
      key = new LongWritable();
    }
    key.set(pos);
    if (value == null) {
      value = new Text();
    }
    int newSize = 0;
    // We always read one extra line, which lies outside the upper
    // split limit i.e. (end - 1)
    // 预读取下一条纪录
    while (getFilePosition() <= end) {
      newSize = in.readLine(value, maxLineLength,
          Math.max(maxBytesToConsume(pos), maxLineLength));
      if (newSize == 0) {
        break;
      }
      pos += newSize; // 下一行的偏移量
      if (newSize < maxLineLength) {
        break;
      }
//
      // line too long. try again
      LOG.info("Skipped line of size " + newSize + " at pos " + 
               (pos - newSize));
    }
    if (newSize == 0) {
      key = null;
      value = null;
      return false;
    } else {
      return true;
    }
  }
```

### 自定义 RecordReader 演示

假设，现有如下数据 10 ～ 70 需要利用自定义 RecordReader 组件分别计算数据奇数行和偶数行的数据之和。结果为：奇数行之和等于 160，偶数和等于 120。**出自于 [开源力量] LouisT 老师的[开源力量培训课-Hadoop Development]课件。**

数据：</br>
10</br>
20</br>
30</br>
40</br>
50</br>
60</br>
70</br>

#### 源代码

[TestRecordReader.java]

#### 数据准备
```shell
$ ./bin/hadoop fs -mkdir /inputreader
$ ./bin/hadoop fs -put ./a.txt /inputreader
$ ./bin/hadoop fs -lsr /inputreader
-rw-r--r--   2 hadoop supergroup         21 2014-02-20 21:04 /inputreader/a.txt
```

#### 执行
```shell
$ ./bin/hadoop jar study.hdfs-0.0.1-SNAPSHOT.jar TestRecordReader  /inputreader /inputreaderout1
##
$ ./bin/hadoop fs -lsr /inputreaderout1
-rw-r--r--   2 hadoop supergroup          0 2014-02-20 21:12 /inputreaderout1/_SUCCESS
drwxr-xr-x   - hadoop supergroup          0 2014-02-20 21:11 /inputreaderout1/_logs
drwxr-xr-x   - hadoop supergroup          0 2014-02-20 21:11 /inputreaderout1/_logs/history
-rw-r--r--   2 hadoop supergroup      16451 2014-02-20 21:11 /inputreaderout1/_logs/history/job_201402201934_0002_1392901901142_hadoop_TestRecordReader
-rw-r--r--   2 hadoop supergroup      48294 2014-02-20 21:11 /inputreaderout1/_logs/history/job_201402201934_0002_conf.xml
-rw-r--r--   2 hadoop supergroup         23 2014-02-20 21:12 /inputreaderout1/part-r-00000
-rw-r--r--   2 hadoop supergroup         23 2014-02-20 21:12 /inputreaderout1/part-r-00001
##
$ ./bin/hadoop fs -cat /inputreaderout1/part-r-00000
偶数行之和：	120
##
$ ./bin/hadoop fs -cat /inputreaderout1/part-r-00001
奇数行之和：	160
```

[TestRecordReader.java]: https://github.com/kangfoo/hadoop1.study/blob/master/kangfoo/study.hdfs/src/main/java/com/kangfoo/study/hadoop1/mp/typeformat/TestRecordReader.java

[开源力量]: http://new.osforce.cn/?mu=20140227220525KZol8ENMYdFQ6SjMveU26nEZ

[开源力量培训课-Hadoop Development]: http://new.osforce.cn/course/101?mc101=20140301233857au7XG16o9ukfev1pmFCOfv2s

