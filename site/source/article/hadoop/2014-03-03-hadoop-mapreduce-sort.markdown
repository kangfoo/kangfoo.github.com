---
layout: post
title: Hadoop MapReduce Sort
date: '2014-03-03 22:24'
comments: true
published: true
keywords: Hadoop MapReduce Sort
description: Hadoop MapReduce Sort 排序
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---

排序是 MapReduce 的核心。排序可分为四种排序：普通排序、部分排序、全局排序、辅助排序

## 普通排序

Mapreduce 本身自带排序功能；Text 对象是不适合排序的；IntWritable，LongWritable 等实现了WritableComparable 类型的对象都是可以排序的。

## 部分排序

map 和 reduce 处理过程中包含了默认对 key 的排序，那么如果不要求全排序，可以直接把结果输出，每个输出文件中包含的就是按照key执行排序的结果。

### 控制排序顺序

键的排序是由 RawComparator 控制的，规则如下：

1. 若属性 mapred.output.key.comparator.class 已设置，则使用该类的实例。调用 JobConf 的 setOutputKeyComparatorClass() 方法进行设置。
2. 否则，键必须是 WritableComparable 的子类，并使用针对该键类的已登记的 comparator.
3. 如果没有已登记的 comparator ,则使用 RawComparator 将字节流反序列化为一个对象，再由 WritableComparable 的 compareTo() 方法进行操作。

## 全局排序（对所有数据排序）
Hadoop 没有提供全局数据排序,而全局排序是非常普遍的需求。

### 实现方案
* 首先，创建一系列的排好序的文件；
* 其次，串联这些文件；
* 最后，生成一个全局排序的文件。

主要思路是使用一个partitioner来描述全局排序的输出。该方法关键在于如何划分各个分区。

例，对整数排序，[0,10000] 的在 partition 0 中，(10000，20000] 在 partition 1 中… …即第n个reduce 所分配到的数据全部大于第 n-1 个 reduce 中的数据。每个 reduce 的结果都是有序的。</br>
然后再将所有的输出文件顺序合并成一个大的文件，那么就实现了全局排序。

在比较理想的数据分布均匀的情况下，每个分区内的数据量要基本相同。

但实际中数据往往分布不均匀，出现数据倾斜，这时按照此方法进行的分区划分数据就不适用，可对数据进行采样。

### 采样器

通过对 key 空间进行采样，可以较为均匀的划分数据集。采样的核心思想是只查看一小部分键，获取键的相似分布，并由此构建分区。采样器是在 map 阶段之前进行的, 在提交 job 的 client 端完成的。

#### Sampler接口

Sampler 接口是 Hadoop 的采样器，它的 getSample() 方法返回一组样本。此接口一般不由客户端调用，而是由 InputSampler 类的静态方法 writePartitionFile() 调用，以创建一个顺序文件来存储定义分区的键。

Sampler接口声明如下：
```java
  public interface Sampler<K,V> {
   K[] getSample(InputFormat<K,V> inf, JobConf job) throws IOException;
  }
```
继承 Sample 的类还有 IntervalSampler 间隔采样器，RandomSampler 随机采样器，SplitSampler 分词采样器。它们都是 InputSampler 的静态内部类。

getSample() 方法根据 job 的配置信息以及输入格式获得抽样结果，三个采样类各自有不同的实现。

**IntervalSampler 根据一定的间隔从 s 个分区中采样数据，非常适合对排好序的数据采样。**
```java
public static class IntervalSampler<K,V> implements Sampler<K,V> {
    private final double freq;// 哪一条记录被选中的概率
    private final int maxSplitsSampled;// 采样的最大分区数
    /**
     * For each split sampled, emit when the ratio of the number of records
     * retained to the total record count is less than the specified
     * frequency.
     */
    @SuppressWarnings("unchecked") // ArrayList::toArray doesn't preserve type
    public K[] getSample(InputFormat<K,V> inf, JobConf job) throws IOException {
      InputSplit[] splits = inf.getSplits(job, job.getNumMapTasks());// 1. 得到输入分区数组
      ArrayList<K> samples = new ArrayList<K>();
      int splitsToSample = Math.min(maxSplitsSampled, splits.length);
      int splitStep = splits.length / splitsToSample; // 2. 分区采样时的间隔splitStep = 输入分区总数 除以 splitsToSample的 商；
      long records = 0;
      long kept = 0;
      for (int i = 0; i < splitsToSample; ++i) {
        RecordReader<K,V> reader = inf.getRecordReader(splits[i * splitStep], // 3. 采样下标为i * splitStep的数据
            job, Reporter.NULL);
        K key = reader.createKey();
        V value = reader.createValue();
        while (reader.next(key, value)) {// 6. 循环读取下一条记录
          ++records;
          if ((double) kept / records < freq) { // 4. 如果当前样本数与已经读取的记录数的比值小于freq，则将这条记录添加到样本集合
            ++kept;
            samples.add(key);// 5. 将记录添加到样本集合中
            key = reader.createKey();
          }
        }
        reader.close();
      }
      return (K[])samples.toArray();
    }
  }
… … 
}
```

**RandomSampler 是常用的采样器，它随机地从输入数据中抽取 Key**。
```java
  public static class RandomSampler<K,V> implements Sampler<K,V> {
    private double freq;// 一个Key被选中的 概率
    private final int numSamples;// 从所有被选中的分区中获得的总共的样本数目
    private final int maxSplitsSampled;// 需要检查扫描的最大分区数目
/**
     * Randomize the split order, then take the specified number of keys from
     * each split sampled, where each key is selected with the specified
     * probability and possibly replaced by a subsequently selected key when
     * the quota of keys from that split is satisfied.
     */
    @SuppressWarnings("unchecked") // ArrayList::toArray doesn't preserve type
    public K[] getSample(InputFormat<K,V> inf, JobConf job) throws IOException {
      InputSplit[] splits = inf.getSplits(job, job.getNumMapTasks());// 1. 获取所有的输入分区
      ArrayList<K> samples = new ArrayList<K>(numSamples);// 2. 确定需要抽样扫描的分区数目
      int splitsToSample = Math.min(maxSplitsSampled, splits.length);// 3. 取最小的为采样的分区数
      Random r = new Random();
      long seed = r.nextLong();
      r.setSeed(seed);
      LOG.debug("seed: " + seed);
      // shuffle splits 4. 对输入分区数组shuffle排序
      for (int i = 0; i < splits.length; ++i) {
        InputSplit tmp = splits[i];
        int j = r.nextInt(splits.length);// 5. 打乱其原始顺序
        splits[i] = splits[j];
        splits[j] = tmp;
      }
      // our target rate is in terms of the maximum number of sample splits,
      // but we accept the possibility of sampling additional splits to hit
      // the target sample keyset
// 5. 然后循环逐 个扫描每个分区中的记录进行采样，
      for (int i = 0; i < splitsToSample ||
                     (i < splits.length && samples.size() < numSamples); ++i) {
        RecordReader<K,V> reader = inf.getRecordReader(splits[i], job,
            Reporter.NULL);
       // 6. 取出一条记录
        K key = reader.createKey();
        V value = reader.createValue();
        while (reader.next(key, value)) {
          if (r.nextDouble() <= freq) {
            if (samples.size() < numSamples) {// 7. 判断当前的采样数是否小于最大采样数
              samples.add(key); //8. 小于则这条记录被选中，放进采样集合中，
            } else {
              // When exceeding the maximum number of samples, replace a
              // random element with this one, then adjust the frequency
              // to reflect the possibility of existing elements being
              // pushed out
              int ind = r.nextInt(numSamples);// 9. 从[0，numSamples]中选择一个随机数
              if (ind != numSamples) {
                samples.set(ind, key);// 10. 替换掉采样集合随机数对应位置的记录，
              }
              freq *= (numSamples - 1) / (double) numSamples;// 11. 调小频率
            }
            key = reader.createKey();// 12. 下一条纪录的key
          }
        }
        reader.close();
      }
      return (K[])samples.toArray();// 13. 返回
    }
  }
… … 
}
```

**SplitSampler 从 s 个分区中采样前 n 个记录，是采样随机数据的一种简便方式。**
```java
  public static class SplitSampler<K,V> implements Sampler<K,V> {
    private final int numSamples;// 最大采样数
    private final int maxSplitsSampled;// 最大分区数
    … … 
    /**
     * From each split sampled, take the first numSamples / numSplits records.
     */
    @SuppressWarnings("unchecked") // ArrayList::toArray doesn't preserve type
    public K[] getSample(InputFormat<K,V> inf, JobConf job) throws IOException {
      InputSplit[] splits = inf.getSplits(job, job.getNumMapTasks());
      ArrayList<K> samples = new ArrayList<K>(numSamples);
      int splitsToSample = Math.min(maxSplitsSampled, splits.length);// 1. 采样的分区数
      int splitStep = splits.length / splitsToSample; // 2. 分区采样时的间隔 = 分片的长度 与 输入分片的总数的 商
      int samplesPerSplit = numSamples / splitsToSample; // 3. 每个分区的采样数 
      long records = 0;
      for (int i = 0; i < splitsToSample; ++i) {
        RecordReader<K,V> reader = inf.getRecordReader(splits[i * splitStep], // 4.采样下标为i * splitStep的数据
            job, Reporter.NULL);
        K key = reader.createKey();
        V value = reader.createValue();
        while (reader.next(key, value)) {
          samples.add(key);// 5. 将记录添加到样本集合中
          key = reader.createKey();
          ++records;
          if ((i+1) * samplesPerSplit <= records) { // 6. 当前样本数大于当前的采样分区所需要的样本数，则停止对当前分区的采样。
            break;
          }
        }
        reader.close();
      }
      return (K[])samples.toArray();
    }
  }
```

**Hadoop为顺序文件提供了一个 TotalOrderPartitioner 类，可以用来实现全局排序**；TotalOrderPartitioner 源代码理解。TotalOrderPartitioner 内部定义了多个字典树（内部类）。
```java
interface Node<T> 
// 特里树，利用字符串的公共前缀来节约存储空间，最大限度地减少无谓的字符串比较，查询效率比哈希表高
static abstract class TrieNode implements Node<BinaryComparable> 
static class InnerTrieNode extends TrieNode 
static class LeafTrieNode extends TrieNode
… … 
```

由 TotalOrderPartitioner 调用 getPartition() 方法返回分区，由 buildTrieRec() 构建特里树.
```java
 private TrieNode buildTrieRec(BinaryComparable[] splits, int lower,
      int upper, byte[] prefix, int maxDepth, CarriedTrieNodeRef ref) {
… … 
}
```

#### 采样器使用示例 

1. 新建文件，名为 random.txt，里面每行存放一个数据。可由 RandomGenerator 类生成准备数据
2. 执行 TestTotalOrderPartitioner.java

## 辅助排序

先按 key 排序，在按 相同的 key 不同的 value 再排序。可实现对值分组的效果。

* 可参考博客 [Hadoop二次排序关键点和出现时机（也叫辅助排序、Secondary Sort）]
* 或者 hadoop example 工程下参考 SecondarySort.java


[Hadoop二次排序关键点和出现时机（也叫辅助排序、Secondary Sort）]: http://heipark.iteye.com/blog/1990237