---
layout: post
title: Hadoop MapReduce 工作机制
date: '2014-03-03 22:17'
comments: true
published: true
keywords: Hadoop MapReduce 工作机制
description: Hadoop MapReduce 工作机制
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---

## 工作流程

1. 作业配置
2. 作业提交
3. 作业初始化
4. 作业分配
5. 作业执行
6. 进度和状态更新
7. 作业完成
8. 错误处理
9. 作业调度
10. shule（mapreduce核心）和sort


### 作业配置
相对不难理解。 具体略。

### 作业提交

![image](http://zhaomingtai.u.qiniudn.com/mapredurce1.png)

首先熟悉上图，4个实例对象： client jvm、jobTracker、TaskTracker、SharedFileSystem

MapReduce 作业可以使用 JobClient.runJob(conf) 进行 job 的提交。如上图，这个执行过程主要包含了4个独立的实例。

* 客户端。提交MapReduce作业。
* jobtracker：协调作业的运行。jobtracker一个java应用程序。
* tasktracker：运行作业划分后的任务。tasktracker一个java应用程序。
* shared filesystem(分布式文件系统，如:HDFS)


以下是Hadoop1.x 中旧版本的 MapReduce JobClient API. **org.apache.hadoop.mapred.JobClient**
```java
/** JobClient is the primary interface for the user-job to interact with the JobTracker. JobClient provides facilities to submit jobs, track their progress, access component-tasks' reports/logs, get the Map-Reduce cluster status information etc.
The job submission process involves:
Checking the input and output specifications of the job.
Computing the InputSplits for the job.
Setup the requisite accounting information for the DistributedCache of the job, if necessary.
Copying the job's jar and configuration to the map-reduce system directory on the distributed file-system.
Submitting the job to the JobTracker and optionally monitoring it's status.
Normally the user creates the application, describes various facets of the job via JobConf and then uses the JobClient to submit the job and monitor its progress. */ 
Here is an example on how to use JobClient:
     // Create a new JobConf
     JobConf job = new JobConf(new Configuration(), MyJob.class);
     // Specify various job-specific parameters     
     job.setJobName("myjob");
     job.setInputPath(new Path("in"));
     job.setOutputPath(new Path("out"));
     job.setMapperClass(MyJob.MyMapper.class);
     job.setReducerClass(MyJob.MyReducer.class);
     // Submit the job, then poll for progress until the job is complete
     JobClient.runJob(job);   
// JobClient.runJob(job) --> JobClient. submitJob(job) -->  submitJobInternal(job) 
```
新API放在 org.apache.hadoop.mapreduce.* 包下. 使用 Job 类代替 JobClient。又由job.waitForCompletion(true) 内部进行 JobClient.submitJobInternal() 封装。

新旧API请参考博文 [Hadoop编程笔记（二）：Hadoop新旧编程API的区别]

hadoop1.x 旧 API JobClient.runJob(job) 调用submitJob() 之后，便每秒轮询作业进度monitorAndPrintJob。并将其进度、执行结果信息打印到控制台上。

接着再看看 JobClient 的 submitJob() 方法的实现基本过程。上图步骤 2，3，4.

1. 向 jobtracker 请求一个新的 jobId. (`JobID jobId = jobSubmitClient.getNewJobId();` `void org.apache.hadoop.mapred.JobClient.init(JobConf conf) throws IOException` , 集群环境下是 RPC JobSubmissionProtocol 代理。本地环境使用 LocalJobRunner。

2. 检查作业的相关的输出路径并提交 job 以及相关的 jar 到 job tracker, 相关的 libjar 通过distributedCache 传递给 jobtracker.
```java
submitJobInternal(… …); 
// -->
copyAndConfigureFiles(jobCopy, submitJobDir); 
// --> 
copyAndConfigureFiles(job, jobSubmitDir, replication); 
… 
// --> 
output.checkOutputSpecs(context);
```
3. 计算作业的分片。将 SplitMetaInfo 信息写入 JobSplit。 Maptask 的个数 ＝ 输入的文件大小除以块的大小。
```java
int maps = writeSplits(context, submitJobDir);
(JobConf)jobCopy.setNumMapTasks(maps);
// --> 
maps = writeNewSplits(job, jobSubmitDir); 
// --> （重写，要详细）
JobSplitWriter.createSplitFiles(jobSubmitDir, conf,
        jobSubmitDir.getFileSystem(conf), array); // List<InputSplit> splits = input.getSplits(job); 
// -->
 SplitMetaInfo[] info = writeNewSplits(conf, splits, out);
``` 
4. 写JobConf信息到配置文件 job.xml。 `jobCopy.writeXml(out);`
 
5. 准备提交job。 RPC 通讯到 JobTracker 或者 LocalJobRunner. 
```java
jobSubmitClient.submitJob(jobId, submitJobDir.toString(), jobCopy.getCredentials());
```

### 作业初始化

1. 当 JobTracker 接收到了 submitJob() 方法的调用后，会把此调用放入一个内部队列中，交由作业调度器(job scheduler)进行调度。
```java
submitJob(jobId, jobSubmitDir, null, ts, false);
// -->
jobInfo = new JobInfo(jobId, new Text(ugi.getShortUserName()),
          new Path(jobSubmitDir));
```

2. 作业调度器并对job进行初始化。初始化包括创建一个表示正在运行作业的对象——封装任务和纪录信息，以便跟踪任务的状态和进程（步骤5）。
```java
 job = new JobInProgress(this, this.conf, jobInfo, 0, ts);
// -->
status = addJob(jobId, job);
// -->
 synchronized (jobs) {
      synchronized (taskScheduler) {
        jobs.put(job.getProfile().getJobID(), job);
        for (JobInProgressListener listener : jobInProgressListeners) {
          listener.jobAdded(job);
        }
      }
    }
```
3. 创建任务列表。在 JobInProgress的 initTask()方法中
* 从共享文件系统中获取 JobClient 已计算好的输入分片信息（步骤6）
* 创建 Map 任务和 Reduce 任务，为每个 MapTask 和 ReduceTask 生成 TaskProgress 对象。
* 创建的 reduce 任务的数量由 JobConf 的 mapred.reduce.task 属性决定，可用 setNumReduceTasks() 方法设置，然后调度器创建相应数量的要运行的 reduce 任务。任务被分配了 id。
```java
JobInProgress initTasks() 
… …
TaskSplitMetaInfo[] splits = createSplits(jobId); // read input splits and create a map per a split
// -->
 allSplitMetaInfo[i] = new JobSplit.TaskSplitMetaInfo(splitIndex, 
          splitMetaInfo.getLocations(), 
          splitMetaInfo.getInputDataLength());
maps = new TaskInProgress[numMapTasks]; // 每个分片创建一个map任务
this.reduces = new TaskInProgress[numReduceTasks]; // 创建reduce任务
```

### 任务分配

Tasktracker 和 JobTracker 通过心跳通信分配一个任务

1. TaskTracker 定期发送心跳，告知 JobTracker, tasktracker 是否还存活，并充当两者之间的消息通道。

2. TaskTracker 主动向 JobTracker 询问是否有作业。若自己有空闲的 solt,就可在心跳阶段得到 JobTracker 发送过来的 Map 任务或 Reduce 任务。对于 map 任务和 task 任务，TaskTracker 有固定数量的任务槽，准确数量由 tasktracker 核的个数核内存的大小来确定。默认调度器在处理 reduce 任务槽之前，会填充满空闲的 map 任务槽，因此，如果 tasktracker 至少有一个空闲的 map 任务槽，tasktracker 会为它选择一个 map 任务，否则选择一个 reduce 任务。选择 map 任务时，jobTracker 会考虑数据本地化（任务运行在输入分片所在的节点），而 reduce 任务不考虑数据本地化。任务还可能是机架本地化。

3. TaskTracker 和 JobTracker heartbeat代码
```java
TaskTracker.transmitHeartBeat()
// -->
    //
    // Check if we should ask for a new Task
    //
 if (askForNewTask) {
      askForNewTask = enoughFreeSpace(localMinSpaceStart);
      long freeDiskSpace = getFreeSpace();
      long totVmem = getTotalVirtualMemoryOnTT();
      long totPmem = getTotalPhysicalMemoryOnTT();
      long availableVmem = getAvailableVirtualMemoryOnTT();
      long availablePmem = getAvailablePhysicalMemoryOnTT();
      long cumuCpuTime = getCumulativeCpuTimeOnTT();
      long cpuFreq = getCpuFrequencyOnTT();
      int numCpu = getNumProcessorsOnTT();
      float cpuUsage = getCpuUsageOnTT();
// -->
    // Xmit the heartbeat
    HeartbeatResponse heartbeatResponse = jobClient.heartbeat(status, 
                                                              justStarted,
                                                              justInited,
                                                              askForNewTask, 
                                                              heartbeatResponseId);
注： InterTrackerProtocol jobClient RPC 到 JobTracker.heartbeat() 
JobTracker.heartbeat()
// -->
 // Process this heartbeat 
    short newResponseId = (short)(responseId + 1);
    status.setLastSeen(now);
    if (!processHeartbeat(status, initialContact, now)) {
      if (prevHeartbeatResponse != null) {
        trackerToHeartbeatResponseMap.remove(trackerName);
      }
      return new HeartbeatResponse(newResponseId, 
                   new TaskTrackerAction[] {new ReinitTrackerAction()});
    }
```

### 任务执行
tasktracker 执行任务大致步骤：

1. 被分配到一个任务后，从共享文件中把作业的jar复制到本地，并将程序执行需要的全部文件（配置信息、数据分片）复制到本地
2. 为任务新建一个本地工作目录
3. 内部类TaskRunner实例启动一个新的jvm运行任务

Tasktracker.TaskRunner.startNewTask()代码
```java
// -->
RunningJob rjob = localizeJob(tip);
// -->
launchTaskForJob(tip, new JobConf(rjob.getJobConf()), rjob); 
// -->
tip.launchTask(rjob);
// -->
setTaskRunner(task.createRunner(TaskTracker.this, this, rjob));
this.runner.start(); // MapTaskRunner 或者 ReduceTaskRunner
//
//startNewTask 方法完整代码：
void startNewTask(final TaskInProgress tip) throws InterruptedException {
    Thread launchThread = new Thread(new Runnable() {
      @Override
      public void run() {
        try {
          RunningJob rjob = localizeJob(tip);//初始化job工作目录
          tip.getTask().setJobFile(rjob.getLocalizedJobConf().toString());
          // Localization is done. Neither rjob.jobConf nor rjob.ugi can be null
          launchTaskForJob(tip, new JobConf(rjob.getJobConf()), rjob); // 启动taskrunner执行task
        } catch (Throwable e) {
          String msg = ("Error initializing " + tip.getTask().getTaskID() + 
                        ":\n" + StringUtils.stringifyException(e));
          LOG.warn(msg);
          tip.reportDiagnosticInfo(msg);
          try {
            tip.kill(true);
            tip.cleanup(false, true);
          } catch (IOException ie2) {
            LOG.info("Error cleaning up " + tip.getTask().getTaskID(), ie2);
          } catch (InterruptedException ie2) {
            LOG.info("Error cleaning up " + tip.getTask().getTaskID(), ie2);
          }
          if (e instanceof Error) {
            LOG.error("TaskLauncher error " + 
                StringUtils.stringifyException(e));
          }
        }
      }
    });
    launchThread.start();
  }
```

### 进度和状态更新

1. 状态包括：作业或认为的状态（成功，失败，运行中）、map 和 reduce 的进度、作业计数器的值、状态消息或描述
2. task 运行时，将自己的状态发送给 TaskTracker,由 TaskTracker 心跳机制向 JobTracker 汇报
3. 状态进度由计数器实现

如图：
![image](http://zhaomingtai.u.qiniudn.com/updateStatusMapredurce.png)

### 作业完成

1. jobtracker收到最后一个任务完成通知后，便把作业任务状态置为成功
2. 同时jobtracker,tasktracker清理作业的工作状态

### 错误处理

#### task 失败

1. map 或者 reduce 任务中的用户代码运行异常，子 jvm 在进程退出之前向其父 tasktracker 发送报告, 并打印日志。tasktracker 会将此 task attempt 标记为 failed,释放一个任务槽 slot，以运行另一个任务。streaming 任务以非零退出代码，则标记为 failed.
2. 子进程jvm突然退出（jvm bug）。tasktracker 注意到会将其标记为 failed。
3. 任务挂起。tasktracker 注意到一段时间没有收到进度的更新，便将任务标记为 failed。此 jvm 子进程将被自动杀死。任务超时时间间隔通常为10分钟，使用 mapred.task.timeout 属性进行配置。以毫秒为单位。超时设置为0表示将关闭超时判定，长时间运行不会被标记为 failed，也不会释放任务槽。
4. tasktracker 通过心跳将子任务标记为失败后，自身计数器减一，以便向 jobtracker 申请新的任务
5. jobtracker 通过心跳知道一个 task attempt 失败之后，便重新调度该任务的执行（避开将失败的任务分配给执行失败的tasktracker）。默认执行失败尝试4次，若仍没有执行成功，整个作业就执行失败。

#### tasktracker 失败

1. 一个 tasktracker 由于崩溃或者运行过于缓慢而失败，就会停止将 jobtracker 心跳。默认间隔可由 mapred.tasktracker.expriy.interval 设置，毫秒为单位。
2. 同时 jobtracker 将从等待任务调度的 tasktracker 池将此 tasktracker 移除。jobtracker 重新安排此 tasktracker 上已运行并成功完成的 map 任务重新运行。
3. 若 tasktracker 上面的失败任务数远远高于集群的平均失败数，tasktracker 将被列入黑名单。重启后失效。

#### jobtracker失败
Hadoop jobtracker 失败是一个单点故障。作业失败。可在后续版本中启动多个 jobtracker,使用zookeeper协调控制（YARN）。

### 作业调度

1. hadoop默认使用先进先出调度器（FIFO）
先遵循优先级优先，在按作业到来顺序调度。缺点：高优先级别的长时间运行的task占用资源，低级优先级，短作业得不到调度。
2. 公平调度器（FairScheduler）
目标：让每个用户公平的共享集群的能力.默认情况下，每个用户都有自己的池。支持抢占，若一个池在特定的时间内未得到公平的资源分配共享，调度器将终止运行池中得到过多资源的任务，以便将任务槽让给资源不足的池。
详细文档参见：http://hadoop.apache.org/docs/r1.2.1/fair_scheduler.html
3. 容量调度器（CapacityScheduler）
支持多队列，每个队列配置一定的资源，采用FIFO调度策略。对每个用户提交的作业所占的资源进行限定。
详细文档参见：http://hadoop.apache.org/docs/r1.2.1/capacity_scheduler.html


### shuffle和sort
mapreduce 执行排序，将 map 输出作为输入传递给 reduce 称为 shuffle。其确保每个 reduce 的输入都时按键排序。shuffle 是调优 mapreduce 重要的阶段。

mapreduce 的 shuffle 和排序如下图：
![image](http://zhaomingtai.u.qiniudn.com/shuffle_sort.png)

#### map端

1. map端并不是简单的将中间结果输出到磁盘。而是先用缓冲的方式写到内存，并预排序。
2. 每个map任务都有一个环形缓冲区，用于存储任务的输出。默认100mb，由 io.sort.mb 设置。 io.sort.spill.percent 设置阀值，默认80%。
3. 一旦内存缓冲区到达阀值，由一个后台线程将内存中内容 spill 到磁盘中。在写磁盘前，线程会根据数据最终要传送的 reducer 数目划分成相应的分区。每一个分区中，后台线程按键进行内排序，如果有一个 combiner 它会在排序后的输出上运行。
4. 在任务完成之前，多个溢出写文件会被合并成一个已分区已排序的输出文件。最终成为 reduce 的输入文件。属性 io.sort.factor 控制一次最多能合并多少流（分区），默认10.
5. 如果已指定 combiner,并且溢出写文件次数至少为3（min.num.spills.for.combiner 属性），则 combiner 就会在输出文件写到磁盘之前运行。目的时 map 输出更紧凑，写到磁盘上的数据更少。combiner 在输入上反复运行并不影响最终结果。
6. 压缩 map 输出。写磁盘速度更快、节省磁盘空间、减少传给 reduce 数据量。默认不压缩。可使 mapred.compress.map.output=true 启用压缩，并指定压缩库, mapred.map.output.compression.codec。
7. reducer 通过HTTP方式获取输出文件的分区。由于文件分区的工作线程数量任务的 tracker.http.threads 属性控制。

MapTask代码,内部类MapOutputBuffer.collect()方法在收集key/value到容器中,一旦满足预值，则开始溢出写文件由sortAndSpill() 执行。
```java
// sufficient acct space
          kvfull = kvnext == kvstart;
          final boolean kvsoftlimit = ((kvnext > kvend)
              ? kvnext - kvend > softRecordLimit
              : kvend - kvnext <= kvoffsets.length - softRecordLimit);
          if (kvstart == kvend && kvsoftlimit) {
            LOG.info("Spilling map output: record full = " + kvsoftlimit);
            startSpill();
          }
// --> startSpill();
 spillReady.signal(); //    private final Condition spillReady = spillLock.newCondition();
// --> 溢出写文件主要由内部类 SpillThread（Thread） 执行
	try {
              spillLock.unlock();
              sortAndSpill(); // 排序并溢出
            } 
// --> sortAndSpill()
 // create spill file
        final SpillRecord spillRec = new SpillRecord(partitions);
 // sorter = ReflectionUtils.newInstance(job.getClass("map.sort.class", QuickSort.class, IndexedSorter.class), job);
… …
 sorter.sort(MapOutputBuffer.this, kvstart, endPosition, reporter);
// -->
 if (combinerRunner == null) {
… …
 // Note: we would like to avoid the combiner if we've fewer
              // than some threshold of records for a partition
              if (spstart != spindex) {
                combineCollector.setWriter(writer);
                RawKeyValueIterator kvIter =
                  new MRResultIterator(spstart, spindex);
                combinerRunner.combine(kvIter, combineCollector);
              }
}
```

#### reduce 端

1. reduce 端 shuffle 过程分为三个阶段：复制 map 输出、排序合并、reduce 处理
2. reduce 可以接收多个 map 的输出。若 map 相当小，则会复制到 reduce tasktracker 的内存中（mapred.job.shuffle.input.buffer.pecent控制百分比）。一旦内存缓冲区达到阀值大小（由 mapped.iob.shuffle.merge.percent 决定）或者达到map输出阀值( mapred.inmem.merge.threshold 控制)，则合并后溢出写到磁盘
3. map任务在不同时间完成，tasktracker 通过心跳从 jobtracker 获取 map 输出位置。并开始复制 map 输出文件。
4. reduce 任务由少量复制线程，可并行复制 map 输出文件。由属性 mapred.reduce.parallel.copies 控制。
5. reduce 阶段不会等待所有输入合并成一个大文件后在进行处理，而是把部分合并的结果直接进行处理。

ReduceTask源代码,run()方法
```java
// --> 3个阶段
 if (isMapOrReduce()) {
      copyPhase = getProgress().addPhase("copy");
      sortPhase  = getProgress().addPhase("sort");
      reducePhase = getProgress().addPhase("reduce");
    }
// --> copy 阶段
if (!isLocal) {
      reduceCopier = new ReduceCopier(umbilical, job, reporter);
      if (!reduceCopier.fetchOutputs()) {
        if(reduceCopier.mergeThrowable instanceof FSError) {
          throw (FSError)reduceCopier.mergeThrowable;
        }
        throw new IOException("Task: " + getTaskID() + 
            " - The reduce copier failed", reduceCopier.mergeThrowable);
      }
    }
    copyPhase.complete();                         // copy is already complete
// --> sort 阶段
setPhase(TaskStatus.Phase.SORT);
    statusUpdate(umbilical);
    final FileSystem rfs = FileSystem.getLocal(job).getRaw();
    RawKeyValueIterator rIter = isLocal
      ? Merger.merge(job, rfs, job.getMapOutputKeyClass(),
          job.getMapOutputValueClass(), codec, getMapFiles(rfs, true),
          !conf.getKeepFailedTaskFiles(), job.getInt("io.sort.factor", 100),
          new Path(getTaskID().toString()), job.getOutputKeyComparator(),
          reporter, spilledRecordsCounter, null)
      : reduceCopier.createKVIterator(job, rfs, reporter);
    // free up the data structures
    mapOutputFilesOnDisk.clear();
    sortPhase.complete();                         // sort is complete
// --> reduce 阶段
setPhase(TaskStatus.Phase.REDUCE); 
    statusUpdate(umbilical);
    Class keyClass = job.getMapOutputKeyClass();
    Class valueClass = job.getMapOutputValueClass();
    RawComparator comparator = job.getOutputValueGroupingComparator();
    if (useNewApi) {
      runNewReducer(job, umbilical, reporter, rIter, comparator, 
                    keyClass, valueClass);
    } else {
      runOldReducer(job, umbilical, reporter, rIter, comparator, 
                    keyClass, valueClass);
    }
// --> done 执行结果
    done(umbilical, reporter);
```
    
#### 有关mapreduce shuffle和sort 原理、过程和调优
[hadoop作业调优参数整理及原理], [MapReduce:详解Shuffle过程] 介绍的非常详尽。


[Hadoop编程笔记（二）：Hadoop新旧编程API的区别]: http://www.cnblogs.com/beanmoon/archive/2012/12/06/2804905.html
[hadoop作业调优参数整理及原理]: http://www.alidata.org/archives/1470 
[MapReduce:详解Shuffle过程]: http://langyu.iteye.com/blog/992916