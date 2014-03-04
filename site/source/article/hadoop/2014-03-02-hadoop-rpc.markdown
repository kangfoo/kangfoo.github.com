---
layout: post
title: Hadoop RPC
date: '2014-03-02 23:33'
comments: true
published: true
keywords: Hadoop RPC
description: Hadoop RPC
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---

Remote Procedure Call 远程方法调用。不需要了解网络细节，某一程序即可使用该协议请求来自网络内另一台及其程序的服务。它是一个 Client/Server 的结构,提供服务的一方称为Server，消费服务的一方称为Client。

Hadoop 底层的交互都是通过 rpc 进行的。例 如：datanode 和 namenode、tasktracker 和 jobtracker、secondary namenode 和 namenode 之间的通信都是通过 rpc 实现的。

TODO: 此文未写明了。明显需要画 4张图， rpc 原理图，Hadoop rpc 时序图， 客户端 流程图，服端流程图。最好帖几个包图＋ 类图（组件图）。待完善。
 
**要实现远程过程调用，需要有3要素**： 
1、server 必须发布服务 
2、在 client 和 server 两端都需要有模块来处理协议和连接 
3、server 发布的服务，需要将接口给到 client 
 
## Hadoop RPC

1. 序列化层。 Client 与 Server  端通讯传递的信息采用实现自 Writable 类型
2. 函数调用层。 Hadoop RPC 通过动态代理和 java 反射实现函数调用
3. 网络传输层。Hadoop RPC 采用 TCP/IP socket 机制
4. 服务器框架层。Hadoop RPC 采用 java NIO 事件驱动模型提高 RPC Server 吞吐量

TODO 缺个 RPC 图

Hadoop RPC 源代码主要在org.apache.hadoop.ipc包下。org.apache.hadoop.ipc.RPC 内部包含5个内部类。

* Invocation ：用于封装方法名和参数，作为数据传输层，相当于VO（Value Object）。
* ClientCache ：用于存储client对象，用 socket factory 作为 hash key,存储结构为 hashMap <SocketFactory, Client>。
* Invoker ：是动态代理中的调用实现类，继承了 java.lang.reflect.InvocationHandler。
* Server ：是ipc.Server的实现类。
* VersionMismatch : 协议版本。

### 从客户端开始进行通讯源代码分析

org.apache.hadoop.ipc.Client 有5个内部类

* Call: A call waiting for a value.
* Connection: Thread that reads responses and notifies callers.  Each connection owns a socket connected to a remote address.  Calls are multiplexed through this socket: responses may be delivered out of order. 
* ConnectionId: This class holds the address and the user ticket. The client connections to servers are uniquely identified by <remoteAddress, protocol, ticket>
* ParallelCall: Call implementation used for parallel calls. 
* ParallelResults: Result collector for parallel calls. 

**客户端和服务端建立连接的大致执行过程为**：

1. 在 Object org.apache.hadoop.ipc.RPC.Invoker.invoke(Object proxy, Method method, Object[] args) 方法中调用</br>
 client.call(new Invocation(method, args), remoteId);
1. 上述的 new Invocation(method, args) 是 org.apache.hadoop.ipc.RPC 的内部类，它包含被调用的方法名称及其参数。此处主要是设置方法和参数。 client 为 org.apache.hadoop.ipc.Client 的实例对象。
1. org.apache.hadoop.ipc.Client.call() 方法的具体源代码。在call()方法中 getConnection()内部获取一个 org.apache.hadoop.ipc.Client.Connection 对象并启动 io 流 setupIOstreams()。
```java
Writable org.apache.hadoop.ipc.Client.call(Writable param, ConnectionId remoteId) throwsInterruptedException, IOException {
Call call = new Call(param); //A call waiting for a value.   
  // Get a connection from the pool, or create a new one and add it to the
  // pool.  Connections to a given ConnectionId are reused. 
    Connection connection = getConnection(remoteId, call);// 主要在 org.apache.hadoop.net 包下。
    connection.sendParam(call); //客户端发送数据过程
    boolean interrupted = false;
    synchronized (call) {
       while (!call.done) {
        try {
          call.wait();                           // wait for the result
        } catch (InterruptedException ie) {
          // save the fact that we were interrupted
          interrupted = true;
        }
      }
… …
    }
  }
  // Get a connection from the pool, or create a new one and add it to the
  // pool.  Connections to a given ConnectionId are reused. 
   private Connection getConnection(ConnectionId remoteId,
                                   Call call)
                                   throws IOException, InterruptedException {
    if (!running.get()) {
      // the client is stopped
      throw new IOException("The client is stopped");
    }
    Connection connection;
    // we could avoid this allocation for each RPC by having a  
    // connectionsId object and with set() method. We need to manage the
    // refs for keys in HashMap properly. For now its ok.
    do {
      synchronized (connections) {
        connection = connections.get(remoteId);
        if (connection == null) {
          connection = new Connection(remoteId);
          connections.put(remoteId, connection);
        }
      }
    } while (!connection.addCall(call)); 
    //we don't invoke the method below inside "synchronized (connections)"
    //block above. The reason for that is if the server happens to be slow,
    //it will take longer to establish a connection and that will slow the
    //entire system down.
    connection.setupIOstreams(); // 向服务段发送一个 header 并等待结果
    return connection;
  }
```

3. setupIOstreams() 方法。
```java
void org.apache.hadoop.ipc.Client.Connection.setupIOstreams() throws InterruptedException {
// Connect to the server and set up the I/O streams. It then sends
// a header to the server and starts
// the connection thread that waits for responses.
 while (true) {
          setupConnection();//  建立连接
          InputStream inStream = NetUtils.getInputStream(socket); // 输入
          OutputStream outStream = NetUtils.getOutputStream(socket); // 输出
          writeRpcHeader(outStream);
          }
  … … 
   // update last activity time
      touch();
  // start the receiver thread after the socket connection has been set up       	  start(); 
  }        
```

1. 启动org.apache.hadoop.ipc.Client.Connection
客户端获取服务器端放回数据过程
```java
void org.apache.hadoop.ipc.Client.Connection.run()
 while (waitForWork()) {//wait here for work - read or close connection
        receiveResponse();
      }
```

### ipc.Server源码分析

ipc.Server 有6个内部类：

* Call ：用于存储客户端发来的请求
* Listener ： 监听类，用于监听客户端发来的请求，同时Listener内部还有一个静态类，Listener.Reader，当监听器监听到用户请求，便让Reader读取用户请求。
* ExceptionsHandler: 异常管理
* Responder ：响应RPC请求类，请求处理完毕，由Responder发送给请求客户端。
* Connection ：连接类，真正的客户端请求读取逻辑在这个类中。
* Handler ：请求处理类，会循环阻塞读取callQueue中的call对象，并对其进行操作。

大致过程为：
1. Namenode的初始化时，RPC的server对象是通过ipc.RPC类的getServer()方法获得的。
```java
void org.apache.hadoop.hdfs.server.namenode.NameNode.initialize(Configuration conf) throwsIOException
 // create rpc server
    InetSocketAddress dnSocketAddr = getServiceRpcServerAddress(conf);
    if (dnSocketAddr != null) {
      int serviceHandlerCount =
        conf.getInt(DFSConfigKeys.DFS_NAMENODE_SERVICE_HANDLER_COUNT_KEY,
                    DFSConfigKeys.DFS_NAMENODE_SERVICE_HANDLER_COUNT_DEFAULT);
      this.serviceRpcServer = RPC.getServer(this, dnSocketAddr.getHostName(), 
          dnSocketAddr.getPort(), serviceHandlerCount,
          false, conf, namesystem.getDelegationTokenSecretManager());
      this.serviceRPCAddress = this.serviceRpcServer.getListenerAddress();
      setRpcServiceServerAddress(conf);
    }
… …
this.server.start();  //start RPC server  
```
2. 启动 server
```java
void org.apache.hadoop.ipc.Server.start()
 // Starts the service.  Must be called before any calls will be handled.
  public synchronized void start() {
    responder.start();
    listener.start();
    handlers = new Handler[handlerCount];
    for (int i = 0; i < handlerCount; i++) {
      handlers[i] = new Handler(i);
      handlers[i].start(); //处理call
    }
  }
```

3. Server处理请求, server 同样使用非阻塞 nio 以提高吞吐量
```java
org.apache.hadoop.ipc.Server.Listener.Listener(Server) throws IOException
 public Listener() throws IOException {
      address = new InetSocketAddress(bindAddress, port);
      // Create a new server socket and set to non blocking mode
      acceptChannel = ServerSocketChannel.open();
      acceptChannel.configureBlocking(false);
 … … }     
```

1. 真正建立连接
```java
void org.apache.hadoop.ipc.Server.Listener.doAccept(SelectionKey key) throws IOException,OutOfMemoryError
```
Reader 读数据接收请求
```java
void org.apache.hadoop.ipc.Server.Listener.doRead(SelectionKey key) throws InterruptedException
 try {
        count = c.readAndProcess();
      } catch (InterruptedException ieo) {
        LOG.info(getName() + ": readAndProcess caught InterruptedException", ieo);
        throw ieo;
      }
```
```java
int org.apache.hadoop.ipc.Server.Connection.readAndProcess() throws IOException,InterruptedException
 if (!rpcHeaderRead) {
          //Every connection is expected to send the header.
          if (rpcHeaderBuffer == null) {
            rpcHeaderBuffer = ByteBuffer.allocate(2);
          }
          count = channelRead(channel, rpcHeaderBuffer);
          if (count < 0 || rpcHeaderBuffer.remaining() > 0) {
            return count;
          }
          int version = rpcHeaderBuffer.get(0);
… … 
 processOneRpc(data.array()); // 数据处理
```

1. 下面贴出Server.Connection类中的processOneRpc()方法和processData()方法的源码。
```java
void org.apache.hadoop.ipc.Server.Connection.processOneRpc(byte[] buf) throws IOException,InterruptedException
private void processOneRpc(byte[] buf) throws IOException,
        InterruptedException {
      if (headerRead) {
        processData(buf);
      } else {
        processHeader(buf);
        headerRead = true;
        if (!authorizeConnection()) {
          throw new AccessControlException("Connection from " + this
              + " for protocol " + header.getProtocol()
              + " is unauthorized for user " + user);
        }
      }
    }
```
1. 处理call
```java
void org.apache.hadoop.ipc.Server.Handler.run()
 while (running) {
        try {
          final Call call = callQueue.take(); // pop the queue; maybe blocked here
          … … 
          CurCall.set(call);
          try {
            // Make the call as the user via Subject.doAs, thus associating
            // the call with the Subject
            if (call.connection.user == null) {
              value = call(call.connection.protocol, call.param, 
                           call.timestamp);
            } else {
… …}
```

1. 返回请求 

下面贴出Server.Responder类中的doRespond()方法源码： 
```java
void org.apache.hadoop.ipc.Server.Responder.doRespond(Call call) throws IOException
	//
    // Enqueue a response from the application.
    //
    void doRespond(Call call) throws IOException {
      synchronized (call.connection.responseQueue) {
        call.connection.responseQueue.addLast(call);
        if (call.connection.responseQueue.size() == 1) {
          processResponse(call.connection.responseQueue, true);
        }
      }
    }
```

补充：
notify()让因wait()进入阻塞队列里的线程（blocked状态）变为runnable，然后发出notify()动作的线程继续执行完，待其完成后，进行调度时，调用wait()的线程可能会被再次调度而进入running状态。

 

参考资源：

[大致了解下Hadoop RPC机制]: http://langyu.iteye.com/blog/1183337

[源码级强力分析hadoop的RPC机制]: http://weixiaolu.iteye.com/blog/1504898

[Alex && OpenCould]: http://blademaster.ixiezi.com/