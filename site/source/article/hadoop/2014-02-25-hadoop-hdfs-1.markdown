---
layout: post
title: Hadoop 分布式文件系统
date: '2014-02-25 22:46'
comments: true
published: true
keywords: hadoop
description: hadoop hdfs 分布式文件系统
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---

  管理网络跨多台计算机存储的文件系统称为分布式文件系统。当数据的大小超过单台物理计算机存储能力，就需要对它进行分区存储。**Hadoop提供了一个综合性的文件系统抽象**， Hadoop Distributed FileSystem 简称 HDFS或者DFS，Hadoop 分布式文件系统。它是Hadoop 3大组件之一。其他两大组件为 Hadoop-common 和 Hadoop-mapreduce。
  
  传统以文件为基本单位的存储缺点：首先它很难实现并行化处理某个文件。单个节点一次只能处理一个文件，无法同时处理其他文件；再者，文件大小不同很难实现负载均衡。
  
###  HDFS的设计 ###
* HDFS以流式数据访问模式来存储超大文件，部署运行于廉价的机器上。
* 可存储超大文件；流式访问，一次写入，多次读取；商用廉价PC,并不需要高昂的高可用的硬件。
* 但不适用于，低时间延迟的访问；大小文件处理（浪费namenode内存，浪费磁盘空间。）；多用户写入，任意修改文件(不支持并发写入。 同一时刻只能一个进程写入，不支持随机修改。)。

### 数据块 ###
块是磁盘进行数据读写的最小单位，默认是512字节，构建单个磁盘之上的文件系统通过磁盘块来管理文件系统的来管理该文件系统中的块。HDFS的块默认是64MB,**HDFS上的文件也被划分为块大小的多个分块(chunk)，作为独立的存储单元**。HDFS块默认64MB的好处是为了简化[磁盘寻址](https://community.emc.com/thread/149881)的开销。

### HDFS块的抽象好处 ###
* **一个文件的大小，可以大于网络中任意一个硬盘的大小**。文件的块并不需要存储在同一个硬盘上可以存储在分布式文件系统集群中任意一个硬盘上。
* **大大简化系统设计**。这点对于故障种类繁多的分布式系统来说尤为重要。以块为单位，不仅简化存储管理（块大小是固定的，很容易计算一个硬盘放多少个块）；而且，消除了元数据的顾虑（因为Block仅仅是存储的一块数据，其文件的元数据，例如权限等就不需要跟数据块一起存储，可以交由另外的其他系来处理）。适合批处理。支持离线的批量数据处理，支持高吞吐量。
* **块更适合于数据备份**。进而提供数据容错能力和系统可用性（将每个块复制至少几个独立的机器上，可以确保在发生块、磁盘或机器故障后数据不丢失。一旦发生某个块不可用，系统将从其他地方复制一份复本。以保证复本的数量恢复到正常水平）。容错性高，容易实现负载均衡。

### Namenode 和 Datanode ###
HDFS采用master/slave架构。一个HDFS集群是由一个Namenode和一定数目的 Datanodes 组成。**Namenode**是一个中心服务器，负责管理文件系统的名字空间(namespace)以及客户端对文件的访问。集群中的**Datanode**一般是一个节点一个，负责管理它所在节点上的存储。HDFS暴露了文件系统的名字空间，用户能够以文件的形式在上面存储数据。从内部看，一个文件其实被分成一个或多个数据块，这些块存储在一组Datanode上。Namenode执行文件系统的namespace操作。比如打开、关闭、重命名文件或目录。它也负责确定数据块到具体Datanode节点的 映射。Datanode负责处理文件系统客户端的读写请求。在Namenode的统一调度下进行数据块的创建、删除和复制。

NameNode上维护文件系统树及整棵树内所有的文件和目录，并永久保存在本地磁盘，fsimage和editslog。

NameNode 将对文件系统的改动追加保存到本地文件系统上的一个日志文件（edits）。当一个 NameNode 启动时，它首先从一个映像文件（fsimage）中读取 HDFS 的状态，接着应用日志文件中的 edits 操作。然后它将新的 HDFS 状态写入（fsimage）中，并使用一个空的 edits 文件开始正常操作。因为 NameNode 只有在启动阶段才合并 fsimage 和 edits，所以久而久之日志文件可能会变得非常庞大，特别是对大型的集群。日志文件太大的副作用是下一次 NameNode 启动会花很长时间。


#### Hadoop HDFS 架构图 ####
![image](http://zhaomingtai.u.qiniudn.com/hdfs-architecture.gif)

在上图中NameNode是Master上的进程，复制控制底层文件的io操作，处理mapreduce任务等。
DataNode运行在slave机器上，负责实际的地层文件io读写。由NameNode存储管理文件系统的命名空间。

**客户端**代表用户通过与NameNode和DataNode交互来访问整个文件系统。
#### HDFS 读过程 ####
![image](http://zhaomingtai.u.qiniudn.com/hdfs-read.png)

1. 客户端通过调用 FileSystem 对象的 open() 方法来打开要读取的文件。（步骤 1）在HDFS中是个 DistributedFileSystem 中的一个实例对象。
1. （步骤 2）DistributedFileSystem 通过PRC[需要提供一个外链接介绍RPC技术]调用 namenode ,获取文件起始块的位置。对于每个块，namenode 返回存有该块复本的 datanode 地址。Datanode 根据它们于该客户端的距离排序，如果该客户端就是一个 datanode 并保存有该数据块的一个复本，该节点就直接从本地 datanode 中读取数据。反之取网路拓扑最短路径。
1. DistributedFileSystem 返回 FSDataInputStream 给客户端，用来读取数据。FSDataInputStream  类封装 DFSInputStream 对象。由 DFSInputStream 负责管理 DataNode 和 NameNode 的 I/O。
1. （步骤 3）客户端调用 stream 的 read() 函数开始读取数据。
1. 存储着文件起始块的 DataNode 地址的 DFSInputStream 随即连接距离最近的 DataNode。反复 read() 方法，将数据从 datanode 传输到客户端。（网络拓扑与Hadoop[机架感知] ？ 连接待补。）
1. 到达块的末端时，DFSInputStream 关闭和此数据节点的连接，然后连接此文件下一个数据块的最佳DataNode。
1. 客户端读取数据时，块也是按照打开 DFSInputStream 与 datanode 建立连接的顺序读取的。以通过询问NameNode 来检索下一批所需块的 datanode。当客户端读取完毕数据的时候，调用 FSDataInputStream 的 close() 函数。
1. 在读取数据的过程中，如果客户端在与数据节点通信出现错误，则尝试连接包含此数据块的下一个数据节点。失败的数据节点将被记录，以后不再连接。

##### 源代码理解 #####  
1. 在客户端执行 class DistributedFileSystem open() 方法（装饰模式），打开文件并返回 DFSInputStream。
```java
// DistributedFileSystem extends FileSystem --> 调用 open() 方法
public FSDataInputStream open(Path f, int bufferSize) throws IOException {
        statistics.incrementReadOps(1);
		return new DFSClient.DFSDataInputStream(
        	dfs.open(getPathName(f), bufferSize, verifyChecksum, statistics));
}
```
```java
// dfs 是 DFSClient 的实例对象。
public DFSInputStream open(String src, int buffersize, boolean verifyChecksum,
                   FileSystem.Statistics stats
    ) throws IOException {
        checkOpen(); 
        //    Get block info from namenode
        return new DFSInputStream(src, buffersize, verifyChecksum);
}
```
```java
// DFSInputStream 是 DFSClient 的内部类，继承自 FSInputStream。
// 调用的构造函数（具体略）中调用了 openInfo() 方法。在 openInfo() 中 重要的是 fetchLocatedBlocks() 向 NameNode 询问所需要的数据的元信息，通过 callGetBlockLocations() 实现。 此过程若没有找到将尝试3次。 
//
// 由 callGetBlockLocations()通过 RPC 方式询问 NameNode 获取到 LocatedBlocks 信息。
static LocatedBlocks callGetBlockLocations(ClientProtocol namenode,
      String src, long start, long length) throws IOException {
… … 
        return namenode.getBlockLocations(src, start, length);
… … 
  }    
```
```java
// 此处的 namenode 是通过代理模式创建的。它是 namenode  ClientProtocol 的实现（interface ClientProtocol extends VersionedProtocol）。
private static ClientProtocol createNamenode(ClientProtocol rpcNamenode,
    Configuration conf) throws IOException {
… … 
        final ClientProtocol cp = (ClientProtocol)RetryProxy.create(ClientProtocol.class, rpcNamenode, defaultPolicy, methodNameToPolicyMap);
        RPC.checkVersion(ClientProtocol.class, ClientProtocol.versionID, cp);
… … 
}  
```

2. 在 class NameNode 端获取数据块位置信息并排序
```java
  public LocatedBlocks   getBlockLocations(String src, long offset, long length) throws IOException {
        myMetrics.incrNumGetBlockLocations();
        // 获取数据块信息。namenode 为 FSNamesystem 实例。
        // 保存的是NameNode的name space树，其属性 FSDirectory dir 关联着 FSImage fsimage 信息，
        // fsimage 关联 FSEditLog editLog。
        return namesystem.getBlockLocations(getClientMachine(), src, offset, length);
  }
```
```java 
// 类 FSNamesystem.getBlockLocationsInternal() 是具体获得块信息的实现。
 private synchronized LocatedBlocks getBlockLocationsInternal(String src,
  long offset, long length, int nrBlocksToReturn, 
  boolean doAccessTime,  boolean needBlockToken) throws IOException {
        … … 
}  
```

2. 在客户端DFSClient将步骤1中打开的读文件， DFSDataInputStream 对象内部的 DFSInputStream 对象的 read(long position, byte[] buffer, int offset, int length)方法进行实际的文件读取
```java
// class DFSInputStream
public int read(long position, byte[] buffer, int offset, int length)
      throws IOException {
      // sanity checks
      checkOpen();
      if (closed) {
        throw new IOException("Stream closed");
      }
      failures = 0;
      long filelen = getFileLength();
      if ((position < 0) || (position >= filelen)) {
        return -1;
      }
      int realLen = length;
      if ((position + length) > filelen) {
        realLen = (int)(filelen - position);
      }
      //
      // determine the block and byte range within the block
      // corresponding to position and realLen
      // 判断块内的块和字节范围,位置和实际的长度
      List<LocatedBlock> blockRange = getBlockRange(position, realLen);
      int remaining = realLen;
      for (LocatedBlock blk : blockRange) {
        long targetStart = position - blk.getStartOffset();
        long bytesToRead = Math.min(remaining, blk.getBlockSize() - targetStart);
        fetchBlockByteRange(blk, targetStart, 
                            targetStart + bytesToRead - 1, buffer, offset);
        remaining -= bytesToRead;
        position += bytesToRead;
        offset += bytesToRead;
      }
      assert remaining == 0 : "Wrong number of bytes read.";
      if (stats != null) {
        stats.incrementBytesRead(realLen);
      }
      return realLen;
} 
```
```java
// fetchBlockByteRange() 通过 socket 连接一个最优的 DataNode 来读取数据
private void fetchBlockByteRange(LocatedBlock block, long start,
                                     long end, byte[] buf, int offset) throws IOException {
      //
      // Connect to best DataNode for desired Block, with potential offset
      //
      Socket dn = null;
      int refetchToken = 1; // only need to get a new access token once
      //      
      while (true) {
        // cached block locations may have been updated by chooseDataNode()
        // or fetchBlockAt(). Always get the latest list of locations at the 
        // start of the loop.
        block = getBlockAt(block.getStartOffset(), false);
        DNAddrPair retval = chooseDataNode(block); // 选者最DataNode
        DatanodeInfo chosenNode = retval.info;
        InetSocketAddress targetAddr = retval.addr;
        BlockReader reader = null;
        try {
          Token<BlockTokenIdentifier> accessToken = block.getBlockToken();
          int len = (int) (end - start + 1);
      //
          // first try reading the block locally.
          if (shouldTryShortCircuitRead(targetAddr)) {// 本地优先
            try {
              reader = getLocalBlockReader(conf, src, block.getBlock(),
                  accessToken, chosenNode, DFSClient.this.socketTimeout, start);
            } catch (AccessControlException ex) {
              LOG.warn("Short circuit access failed ", ex);
              //Disable short circuit reads
              shortCircuitLocalReads = false;
              continue;
            }
          } else {
            // go to the datanode
            dn = socketFactory.createSocket(); // socke datanode
            LOG.debug("Connecting to " + targetAddr);
            NetUtils.connect(dn, targetAddr, getRandomLocalInterfaceAddr(),
                socketTimeout);
            dn.setSoTimeout(socketTimeout);
            reader = RemoteBlockReader.newBlockReader(dn, src, 
                block.getBlock().getBlockId(), accessToken,
                block.getBlock().getGenerationStamp(), start, len, buffersize, 
                verifyChecksum, clientName);
          }
          int nread = reader.readAll(buf, offset, len); // BlockReader 负责读取数据
          return;
        }
        … … 
        finally {
          IOUtils.closeStream(reader);
          IOUtils.closeSocket(dn);
        }
        // Put chosen node into dead list, continue
        addToDeadNodes(chosenNode); // dead datanode
      }
    }
```

3. NameNode 实例化启动时便监听客户端请求
```java
DataNode(final Configuration conf,
           final AbstractList<File> dataDirs, SecureResources resources) throws IOException {
    super(conf);
    SecurityUtil.login(conf, DFSConfigKeys.DFS_DATANODE_KEYTAB_FILE_KEY, 
        DFSConfigKeys.DFS_DATANODE_USER_NAME_KEY);
//
    datanodeObject = this;
    durableSync = conf.getBoolean("dfs.durable.sync", true);
    this.userWithLocalPathAccess = conf
        .get(DFSConfigKeys.DFS_BLOCK_LOCAL_PATH_ACCESS_USER_KEY);
    try {
      startDataNode(conf, dataDirs, resources);// startDataNode
    } catch (IOException ie) {
      shutdown();
      throw ie;
    }   
  }
```
```java
// startDataNode
void startDataNode(Configuration conf, 
                     AbstractList<File> dataDirs, SecureResources resources
                     ) throws IOException {
… …                      
    // find free port or use privileged port provide
    ServerSocket ss;
    if(secureResources == null) {
      ss = (socketWriteTimeout > 0) ? 
        ServerSocketChannel.open().socket() : new ServerSocket();
      Server.bind(ss, socAddr, 0);
    } else {
      ss = resources.getStreamingSocket();
    }
    ss.setReceiveBufferSize(DEFAULT_DATA_SOCKET_SIZE); 
    // adjust machine name with the actual port
    tmpPort = ss.getLocalPort();
    selfAddr = new InetSocketAddress(ss.getInetAddress().getHostAddress(),
    //                                     tmpPort);
    this.dnRegistration.setName(machineName + ":" + tmpPort);
    LOG.info("Opened data transfer server at " + tmpPort);
    //
    this.threadGroup = new ThreadGroup("dataXceiverServer");
    this.dataXceiverServer = new Daemon(threadGroup, 
        new DataXceiverServer(ss, conf, this));
    this.threadGroup.setDaemon(true); // DataXceiverServer为守护线程监控客户端连接
  }
```
```java
// class DataXceiverServer.run()
 public void run() {
    while (datanode.shouldRun) {
      try {
        Socket s = ss.accept();
        s.setTcpNoDelay(true);
        new Daemon(datanode.threadGroup, 
            new DataXceiver(s, datanode, this)).start();
      } catch (SocketTimeoutException ignored) {
      }
    }
 }   
```
```java
// class DataXceiver.run()
// Read/write data from/to the DataXceiveServer.
// 操作类型：OP_READ_BLOCK,OP_WRITE_BLOCK,OP_REPLACE_BLOCK,
// OP_COPY_BLOCK,OP_BLOCK_CHECKSUM
  public void run() {
    DataInputStream in=null; 
    try {
      in = new DataInputStream(
          new BufferedInputStream(NetUtils.getInputStream(s), 
                                  SMALL_BUFFER_SIZE));
… … 
      switch ( op ) {
      case DataTransferProtocol.OP_READ_BLOCK:
        readBlock( in );// 读数据
        datanode.myMetrics.addReadBlockOp(DataNode.now() - startTime);
        if (local)
          datanode.myMetrics.incrReadsFromLocalClient();
        else
          datanode.myMetrics.incrReadsFromRemoteClient();
        break;
… … 
      default:
        throw new IOException("Unknown opcode " + op + " in data stream");
      }
  }  
```
```java
// class DataXceiver.readBlock()
// Read a block from the disk.
  private void readBlock(DataInputStream in) throws IOException {
    //
    // Read in the header,读指令
    //
    long blockId = in.readLong();          
    Block block = new Block( blockId, 0 , in.readLong());
// 
    long startOffset = in.readLong();
    long length = in.readLong();
    String clientName = Text.readString(in);
    Token<BlockTokenIdentifier> accessToken = new Token<BlockTokenIdentifier>();
    accessToken.readFields(in);
    // 向客户端写数据
    OutputStream baseStream = NetUtils.getOutputStream(s, 
        datanode.socketWriteTimeout);
    DataOutputStream out = new DataOutputStream(
                 new BufferedOutputStream(baseStream, SMALL_BUFFER_SIZE));
   … … 
    // send the block,读取本地的block的数据，并发送给客户端
    BlockSender blockSender = null;
    final String clientTraceFmt =
      clientName.length() > 0 && ClientTraceLog.isInfoEnabled()
        ? String.format(DN_CLIENTTRACE_FORMAT, localAddress, remoteAddress,
            "%d", "HDFS_READ", clientName, "%d", 
            datanode.dnRegistration.getStorageID(), block, "%d")
        : datanode.dnRegistration + " Served " + block + " to " +
            s.getInetAddress();
    try {
      try {
        blockSender = new BlockSender(block, startOffset, length,
            true, true, false, datanode, clientTraceFmt);
      } catch(IOException e) {
        out.writeShort(DataTransferProtocol.OP_STATUS_ERROR);
        throw e;
      }
      out.writeShort(DataTransferProtocol.OP_STATUS_SUCCESS); // send op status
      long read = blockSender.sendBlock(out, baseStream, null); // send data,发送数据
      … … 
    } finally {
      IOUtils.closeStream(out);
      IOUtils.closeStream(blockSender);
    }
  }
```

#### HDFS 写过程 ####
![image](http://zhaomingtai.u.qiniudn.com/hdfs-write.png)

1. 客户端通过对 DistributedFileSystem 对象调用 create() 方法来创建文件（步骤1）。
2. DistributedFileSystem 通过 PRC 对 namenode 调用create() 方法，在文件系统的命名空间中创建一个新的没有数据块文件（步骤2）。
3. namenode 检查并确保此文件不存在，并且客户端由创建该文件的权限。通过 namenode 即为创建的新文件创建一条纪录；否则，创建失败，并向客户端抛出 IOException 异常。
4. DistributedFileSystem 向客户端返回一个 FSDataOutputStream 对象。客户端可以开始写数据。FSDataOutputStream 同样封装一个 DFSoutPutstream 对象。由 DFSInputStream 负责处理 DataNode 和 NameNode 的 I/O。
5. （步骤3）在客户端写数据时，DFSoutPutstream 将它分成一个个的数据包，并写入内部队列（数据队列）。
6. 由 DataStreamer(DFSClient 内部类) 处理数据队列。它根据 datanode 列表要求 namenode 分配适合的新块来存储数据备份。这组 datanode 构成一个管线。假设当前复制数为3，那么管线中将有3个节点。DataStreamer 将数据包流式传输到管线（pipeline）的第一个 datanode 节点。该 datanode 存储数据包并将它发送到管线中的第2个 datanode。 同样地，第二个 datanode 存储该数据包并发哦少年宫到管线中的第3个 datanode（步骤4）。
7. DFSOutputStream 内部维护一个对应的数据包队列等待 datanode 收到确认确认回执(ack queue)，当 DFSOutputStream 收到所有的 datanode 确认信息之后，该数据包才从确认队列中删除。
8. 若在写数据时，datanode 发生故障。则先关闭管线，确认把队列中任何数据包都添加回数据队列的最前端，以确保故障节点下游的 datanode 不会漏掉任何一个数据包。并为存储在另一个 datanode 的当前数据块指定一个新的标志，并将该标志发送个 namenode，以便故障的 datanode 在恢复后可以删除存储的部分数据块。从管线中删除故障 datanode 节点并把余下的数据块写入管线中的2个 datanode。Namenode 注意到块复本量不足时，会在另一个节点上创建一个新的复本。后续数据块继续正常处理。一个块在写入期间发生多个 datanode 故障的概率不高，只要写入了最小复本数（dfs.replication.min默认为1），写入即为成功。此块由异步执行复制以达到目标复本数，默认为3。
9. 当客户端结束写入数据，则调用 stream 的 close()函数。此操作将剩余所有的数据包写入 datanode  pipeline 中，并等待 ack queue 返回成功。最后通知元数据节点写入完毕。namenode 是通过 Datastreamer 询问的数据块的分配，它在返回成功前只需要等待数据块进行最小量的复制。

##### 源代码理解 #####
TODO，原笔记已丢失，待补。
hdfs 架构一页。且读过程和写过程各独立一页。

#### NadeNode 和 DataNode 实现的协议 ####
TODO ，独立 一页

#### 补充
详细介绍[HDFS读写过程解析]

[TFS淘宝针对海量非结构化数据存储]: http://code.taobao.org/p/tfs/wiki/intro/
[硬盘分区、寻址和系统启动过程]: http://java7.iteye.com/blog/932679
[磁盘读写访问瓶颈]: http://www.freebsd.org/doc/zh_CN/books/handbook/vinum-access-bottlenecks.html
[HDFS Architecture Guide]: http://hadoop.apache.org/docs/r1.2.1/hdfs_design.html
[HDFS读写过程解析]: http://www.cnblogs.com/forfuture1978/archive/2010/11/10/1874222.html

