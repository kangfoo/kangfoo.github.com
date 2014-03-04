---
layout: post
title: 模拟使用 SecondaryNameNode 恢复 NameNode
date: '2014-02-26 00:50'
comments: true
published: true
keywords: 模拟使用 SecondaryNameNode 恢复 NameNode
description: 模拟使用 SecondaryNameNode 恢复 NameNode
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---
## SecondaryNameNode##
在试验前先了解下什么是 SecondaryNameNode、它的原理、检查点等知识点。再依次从开始配置 SecondaryNameNode 检查点、准备测试环境、模拟正常的 NameNode 故障，并手动启动 NameNode 并从 SecondaryNameNode 中恢复 fsimage。

**注**：此试验思路主要借鉴于[开源力量]的[LouisT 老师 Hadoop Development 课程]中的SecondaryNameNode章节。

### 作用 ###
 主要是为了解决namenode单点故障。不是 namenode 的备份。它周期性的合并 fsimage ( namenode 的镜像)和 editslog（或者 edits——所有对 fsimage 镜像文件操作的步骤）,并推送给 namenode 以辅助恢复namenode。

SecondaryNameNode 定期合并 fsimage 和 edits 日志，将 edits 日志文件大小控制在一个限度下。因为内存需求和 NameNode 在一个数量级上，所以通常 SecondaryNameNode 和 NameNode 运行在不同的机器上。SecondaryNameNode 通过bin/start-dfs.sh 在 conf/masters 中指定的节点上启动。

在hadoop 2.x 中它的作用可以被两个节点替换：checkpoint node(于 SecondaryNameNode 作用相同), backup node( namenode 的完全备份)

### 原理（具体可参见《Hadoop权威指南》第10章 管理Hadoop）###

edits 文件纪录了所有对 fsimage 镜像文件的写操作的步骤。文件系统客户端执行写操作时，这些操作首先会被记录到 edits 文件中。Nodename 在内存中维护文件系统的元数据；当 edits 被修改时，相关元数据也同步更新。内存中的元数据可支持客户端的读请求。

在每次执行写操作之后，且在向客户端发送成功代码之前，edits 编辑日志都需要更新和同步。当 namedone 向多个目录写数据时，只有在所有写操作执行完毕之后方可返回成功代码，以保证任何操作都不会因为机器故障而丢失。

fsimage 文件是文件系统元数据的一个永久检查点。它包含文件系统中的所有目录和文件 inode 的序列化谢谢。每个 inode 都是一个文件或目录的元数据的内部描述方式。对于文件来说，包含的信息有“复制级别”、修改时间、访问时间、访问许可、块大小、组成一个文件的块等；对于目录来说，包含的信息有修改时间、访问许可和配额元数据等信息。

fsimage 是一个大型文件，频繁执行写操作，会使系统运行极慢。并非每一写操作都会更新到 fsimage 文件。
SecondaryNameNode 辅助 namenode，为 namenode 内存中的文件系统元数据创建检查点，并最终合并并更新 fsimage 镜像和减小 edits 文件。

### SecondaryNameNode 的检查点###
SecondaryNameNode 进程启动是由两个配置参数控制的。

* fs.checkpoint.period，指定连续两次检查点的最大时间间隔， 默认值是1小时。
* fs.checkpoint.size 定义了 edits 日志文件的最大值，一旦超过这个值会导致强制执行检查点（即使没到检查点的最大时间间隔）。默认值是64MB。

### SecondaryNameNode 检查点的具体步骤###
![image](http://zhaomingtai.u.qiniudn.com/snn.png)

1. SecondaryNameNode 请求主 namenode 停止使用 edits 文件，暂时将新的操作记录到 edits.new 文件中；
2. SecondaryNameNode 以 http get 复制 主 namenode 中的 fsimage, edits 文件；
3. SecondaryNameNode 将 fsimage 载入到内存，并逐一执行 edits 文件中的操作，创建新的fsimage.ckpt 文件；
4. SecondaryNameNode 以 http post 方式将新的fsimage.ckp 复制到主namenode.
5. 主 namenode 将 fsimage 文件替换为 fsimage.ckpt，同时将 edits.new 文件重命名为 edits。并更新 fstime 文件来记录下次检查点时间。

SecondaryNameNode 保存最新检查点的目录与 NameNode 的目录结构相同。 所以 NameNode 可以在需要的时候读取 SecondaryNameNode上的检查点镜像。

### 模拟 NameNode 故障以从 SecondaryNameNode 恢复###
场景假设：如果NameNode上除了最新的检查点以外，所有的其他的历史镜像和 edits 文件都丢失了，NameNode 可以引入这个最新的检查点以恢复。具体模拟步骤如下：

1. 在配置参数 dfs.name.dir 指定的位置建立一个空文件夹；
2. 把检查点目录的位置赋值给配置参数 fs.checkpoint.dir；
3. 启动NameNode，并加上-importCheckpoint。

NameNode 会从 fs.checkpoint.dir 目录读取检查点，并把它保存在 dfs.name.dir 目录下。 如果 dfs.name.dir 目录下有合法的镜像文件，NameNode 会启动失败。 NameNode 会检查fs.checkpoint.dir 目录下镜像文件的一致性，但是不会去改动它。

### 试验从 SecondaryNameNode 中备份恢复 NameNode###

**注意**：此步骤执行并不能将原的数据文件系统从物理磁盘上移除，同样也不能在新格式化的 namenode 中查看旧的文件系统文件。请确定无误再试验。

#### 试验知识准备 ####

命令的使用方法请参考 [SecondaryNameNode 命令]。在试验前，可先了解些 hadoop 的默认配置
[core-site.xml-default], 
[hdfs-site.xml-default], 
[mapred-site.xml-default]

SecondarynameNode 相关属性描述：
<pre>
属性：fs.checkpoint.dir	 
值：${'$'}{hadoop.tmp.dir}/dfs/namesecondary
描述：Determines where on the local filesystem the DFS secondary name node should store the temporary images to merge. If this is a comma-delimited list of directories then the image is replicated in all of the directories for redundancy.
fs.checkpoint.edits.dir

属性：${'$'}{fs.checkpoint.dir}	 
值：Determines where on the local filesystem the DFS secondary name node should 
描述：store the temporary edits to merge. If this is a comma-delimited list of directoires then teh edits is replicated in all of the directoires for redundancy. Default value is same as fs.checkpoint.dir

属性：fs.checkpoint.period	 
值：3600	 
描述：The number of seconds between two periodic checkpoints.

属性：fs.checkpoint.size	 
值：67108864	 
描述：The size of the current edit log (in bytes) that triggers a periodic checkpoint even if the fs.checkpoint.period hasn't expired.
</pre>

#### 试验环境配置 ####
1. 首先修改 core-site.xml 文件中的配置，主要是调小了 checkpoint 的周期并指定 SSN 的目录。
```xml
<property>
  <name>fs.checkpoint.period</name>
  <value>120</value>
</property>
<property>
  <name>fs.checkpoint.dir</name>
  <value>/home/${'$'}{user.name}/env/data/snn</value>
</property>
```
`vi hdfs-site.xml ` 查看 NameNode 数据文件存储路径
```xml
<property>
     <name>dfs.name.dir</name>
     <value>/home/${'$'}{user.name}/env/data/name</value>
    </property>
    <property>
     <name>dfs.data.dir</name>
     <value>/home/${'$'}{user.name}/env/data/data</value>
    </property>
```

1. 再次，format namenode 。 `./bin/hadoop namenode -format`。查看当前的 master namenode namespaceID `cat ./name/current/VERSION`
```shell
#Tue Jan 21 15:14:40 CST 2014
namespaceID=1816120670 ## 文件系统的唯一标识符
cTime=0 ## namenode的创建时间，刚格式化为0，升级之后为时间戳
storageType=NAME_NODE ## 存储类型
layoutVersion=-41 ## 负的整数。描述了hdfs永久性数据结构的版本。与Hadoop的版本无关。与升级有关。
```

1. 查看 datanode 下的version。`cat data/current/VERSION`
```shell
#Tue Jan 21 09:51:42 CST 2014
namespaceID=80003531
storageID=DS-949100596-192.168.56.12-50010-1387691685116
cTime=0
storageType=DATA_NODE
layoutVersion=-41
```
若 namespaceID 不相同，请将 datanode 中的id修改为 namenode 相同的 namespaceID。
同样的步骤修改其他的 datanode.
若是第一次format可以跳过此步骤。此步骤要注意避免如下错误(Incompatible namespaceID)：
```shell
2014-01-21 15:07:54,890 ERROR org.apache.hadoop.hdfs.server.datanode.DataNode: java.io.IOException: Incompatible namespaceIDs in /home/hadoop/env/data/data: namenode namespaceID = 2020545490; datanode namespaceID = 80003531
```

#### 查看 NameNode 试验前正常环境状况 ####
1. 启动hdfs./bin/start-dfs.sh

1. jps 检查所有的进程(当前NameNode进程正常)
```shell
5832 SecondaryNameNode
6293 Jps
5681 NameNode
2212 DataNode
2198 DataNode
```

1. 创建测试数据
```shell
$ ./bin/hadoop fs -mkdir /test
$ ./bin/hadoop fs -lsr /
drwxr-xr-x   - hadoop supergroup          0 2014-01-21 15:21 /test
[hadoop@master11 hadoop]$ ./bin/hadoop fs -put ivy.xml /test
[hadoop@master11 hadoop]$ ./bin/hadoop fs -lsr /
drwxr-xr-x   - hadoop supergroup          0 2014-01-21 15:22 /test
-rw-r--r--   2 hadoop supergroup      10525 2014-01-21 15:22 /test/ivy.xml
```

1. 查看 SecondaryNameNode 文件目录
```shell
watch ls ./data/snn/ 
current
image
in_use.l
```
1. namenode 对应日志
```shell
2014-01-21 15:54:02,654 INFO org.apache.hadoop.hdfs.server.namenode.FSNamesystem: Roll Edit Log from 192.168.56.11
2014-01-21 15:54:02,654 INFO org.apache.hadoop.hdfs.server.namenode.FSEditLog: Number of transactions: 0 Total time for transactions(ms): 0 Number of transactions batched in Syncs: 0 Number of syncs: 0 SyncTimes(ms): 0
2014-01-21 15:54:02,655 INFO org.apache.hadoop.hdfs.server.namenode.FSEditLog: closing edit log: position=4, editlog=/home/hadoop/env/data/name/current/edits
2014-01-21 15:54:02,655 INFO org.apache.hadoop.hdfs.server.namenode.FSEditLog: close success: truncate to 4, editlog=/home/hadoop/env/data/name/current/edits
2014-01-21 15:54:02,778 INFO org.apache.hadoop.hdfs.server.namenode.TransferFsImage: Opening connection to http://0.0.0.0:50090/getimage?getimage=1
2014-01-21 15:54:02,781 INFO org.apache.hadoop.hdfs.server.namenode.GetImageServlet: Downloaded new fsimage with checksum: 4a75545e83f108e21ef321fb0066ede4
2014-01-21 15:54:02,781 INFO org.apache.hadoop.hdfs.server.namenode.FSNamesystem: Roll FSImage from 192.168.56.11
2014-01-21 15:54:02,781 INFO org.apache.hadoop.hdfs.server.namenode.FSEditLog: Number of transactions: 0 Total time for transactions(ms): 0 Number of transactions batched in Syncs: 0 Number of syncs: 1 SyncTimes(ms): 56
2014-01-21 15:54:02,784 INFO org.apache.hadoop.hdfs.server.namenode.FSEditLog: closing edit log: position=4, editlog=/home/hadoop/env/data/name/current/edits.new
2014-01-21 15:54:02,784 INFO org.apache.hadoop.hdfs.server.namenode.FSEditLog: close success: truncate to 4, editlog=/home/hadoop/env/data/name/current/edits.new
```

1. namenode 文件目录
```shell
$ cd name/
$ tree
.
├── current
│   ├── edits
│   ├── fsimage
│   ├── fstime
│   └── VERSION
├── image
│   └── fsimage
├── in_use.lock
└── previous.checkpoint
    ├── edits
    ├── fsimage
    ├── fstime
    └── VERSION
```

#### 模拟 NameNode 故障 ####
1. 人为的杀掉 namenode 进程
```shell
kill -9 6690 ## 6690 NameNode
删除 namenode 元数据
$ rm -rf ./data/name/*
删除 Secondary NameNode in_use.lock 文件 
$ rm -rf ./snn/in_use.lock
```

#### 从 SecondaryNameNode 中恢复 NameNode ####

1. 启动以 importCheckpoint 方式启动 NameNode。`$ ./bin/hadoop namenode -importCheckpoint`

2. 验证是否恢复成功
```shell
## HDFS 文件系统正常
$ ./bin/hadoop fsck /
The filesystem under path '/' is HEALTHY
$ ./bin/hadoop fs -lsr /
## 元文件信息已恢复
drwxr-xr-x   - hadoop supergroup          0 2014-01-21 15:22 /test
-rw-r--r--   2 hadoop supergroup      10525 2014-01-21 15:22 /test/ivy.xml
$ tree
.
├── data
├── name(已恢复)
│   ├── current
│   │   ├── edits
│   │   ├── fsimage
│   │   ├── fstime
│   │   └── VERSION
│   ├── image
│   │   └── fsimage
│   ├── in_use.lock
│   └── previous.checkpoint
│       ├── edits
│       ├── fsimage
│       ├── fstime
│       └── VERSION
├── snn
│   ├── current
│   │   ├── edits
│   │   ├── fsimage
│   │   ├── fstime
│   │   └── VERSION
│   ├── image
│   │   └── fsimage
│   └── in_use.lock
└── tmp
9 directories, 16 files
```
3. 查看恢复日志信息(截取部分信息)
```shell
## copy fsimage
14/01/21 16:57:52 INFO common.Storage: Storage directory /home/hadoop/env/data/name is not formatted.
14/01/21 16:57:52 INFO common.Storage: Formatting ...
14/01/21 16:57:52 INFO common.Storage: Start loading image file /home/hadoop/env/data/snn/current/fsimage
14/01/21 16:57:52 INFO common.Storage: Number of files = 3
14/01/21 16:57:52 INFO common.Storage: Number of files under construction = 0
14/01/21 16:57:52 INFO common.Storage: Image file /home/hadoop/env/data/snn/current/fsimage of size 274 bytes loaded in 0 seconds.
##copy edits
4/01/21 16:57:52 INFO namenode.FSEditLog: Start loading edits file /home/hadoop/env/data/snn/current/edits
14/01/21 16:57:52 INFO namenode.FSEditLog: EOF of /home/hadoop/env/data/snn/current/edits, reached end of edit log Number of transactions found: 0.  Bytes read: 4
14/01/21 16:57:52 INFO namenode.FSEditLog: Start checking end of edit log (/home/hadoop/env/data/snn/current/edits) ...
14/01/21 16:57:52 INFO namenode.FSEditLog: Checked the bytes after the end of edit log (/home/hadoop/env/data/snn/current/edits):
14/01/21 16:57:52 INFO namenode.FSEditLog:   Padding position  = -1 (-1 means padding not found)
14/01/21 16:57:52 INFO namenode.FSEditLog:   Edit log length   = 4
14/01/21 16:57:52 INFO namenode.FSEditLog:   Read length       = 4
14/01/21 16:57:52 INFO namenode.FSEditLog:   Corruption length = 0
14/01/21 16:57:52 INFO namenode.FSEditLog:   Toleration length = 0 (= dfs.namenode.edits.toleration.length)
14/01/21 16:57:52 INFO namenode.FSEditLog: Summary: |---------- Read=4 ----------|-- Corrupt=0 --|-- Pad=0 --|
14/01/21 16:57:52 INFO namenode.FSEditLog: Edits file /home/hadoop/env/data/snn/current/edits of size 4 edits # 0 loaded in 0 seconds.
14/01/21 16:57:52 INFO common.Storage: Image file /home/hadoop/env/data/name/current/fsimage of size 274 bytes saved in 0 seconds.
14/01/21 16:57:54 INFO namenode.FSEditLog: closing edit log: position=4, editlog=/home/hadoop/env/data/name/current/edits
14/01/21 16:57:54 INFO namenode.FSEditLog: close success: truncate to 4, editlog=/home/hadoop/env/data/name/current/edits
14/01/21 16:57:54 INFO namenode.FSEditLog: Number of transactions: 0 Total time for transactions(ms): 0 Number of transactions batched in Syncs: 0 Number of syncs: 0 SyncTimes(ms): 0 
## 恢复 fsimage
14/01/21 16:57:54 INFO namenode.FSNamesystem: Finished loading FSImage in 1971 msecs
14/01/21 16:57:54 INFO hdfs.StateChange: STATE* Safe mode ON
... ...
14/01/21 16:58:26 INFO hdfs.StateChange: STATE* Safe mode termination scan for invalid, over- and under-replicated blocks completed in 15 msec
14/01/21 16:58:26 INFO hdfs.StateChange: STATE* Leaving safe mode after 33 secs
## 离开安全模式 Safe mode is OFF
14/01/21 16:58:26 INFO hdfs.StateChange: STATE* Safe mode is OFF
14/01/21 16:58:26 INFO hdfs.StateChange: STATE* Network topology has 1 racks and 2 datanodes
14/01/21 16:58:26 INFO hdfs.StateChange: STATE* UnderReplicatedBlocks has 0 blocks
```

[secondarynamenode 命令]: http://hadoop.apache.org/docs/r1.2.1/commands_manual.html#secondarynamenode
[core-site.xml-default]: http://hadoop.apache.org/docs/r1.1.2/core-default.html
[hdfs-site.xml-default]: http://hadoop.apache.org/docs/r1.1.2/hdfs-default.html
[mapred-site.xml-default]: http://hadoop.apache.org/docs/r1.1.2/mapred-default.html
[开源力量]: http://new.osforce.cn/?mu=20140227220525KZol8ENMYdFQ6SjMveU26nEZ
[LouisT 老师 Hadoop Development 课程]: http://new.osforce.cn/course/101?mc101=20140301233857au7XG16o9ukfev1pmFCOfv2s

