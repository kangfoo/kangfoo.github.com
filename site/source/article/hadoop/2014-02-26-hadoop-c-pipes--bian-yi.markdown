---
layout: post
title: Hadoop pipes 编译
date: '2014-02-26 01:01'
comments: true
published: true
keywords: Hadoop pipes 编译
description: Hadoop pipes 编译
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---
我在编译 Hadoop Pipes 的时候，出现了些小问题。主要是我没有安装 openssl-devel。本以为安装 openssl 就差不多了，可这个就是问题的根源, 我现在是自己动手编译 pipes, 而 Hadoop 的 pipes 编译需要 openssl 的依赖，那么在编译的时候最好还是将 openssl-devel 开发支持的依赖补上比较省事。在解决问题的时发现网上向我一样的同学还是有的。在此我就贴下我编译时的部分日志。

1. 在Hadoop 根目录下执行
```shell
 ant -Dcompile.c++=yes examples
##错误
    [exec] checking for HMAC_Init in -lssl... no
BUILD FAILED
/home/hadoop/env/hadoop-1.2.1/build.xml:2164: exec returned: 255
… … 
./configure: line 5234: exit: please: numeric argument required
##具体日志：
… … 
     [exec] configure: error: Cannot find libssl.so ## 没有 libssl.so
     [exec] /home/hadoop/env/hadoop-1.2.1/src/c++/pipes/configure: line 5234: exit: please: numeric argument required
     [exec] /home/hadoop/env/hadoop-1.2.1/src/c++/pipes/configure: line 5234: exit: please: numeric argument required
     [exec] checking for HMAC_Init in -lssl... no 
```

1. 检查 ssl
```shell
$ yum info openssl
$ ll /usr/lib64/libssl*
-rwxr-xr-x. 1 root root 221568 2月  23 2013 /usr/lib64/libssl3.so
lrwxrwxrwx. 1 root root     16 12月  8 18:14 /usr/lib64/libssl.so.10 -> libssl.so.1.0.1e
-rwxr-xr-x. 1 root root 436984 12月  4 04:21 /usr/lib64/libssl.so.1.0.1e
## 缺个 libssl.so 的文件, 于是添加软链接：
sudo ln -s /usr/lib64/libssl.so.1.0.1e /usr/lib64/libssl.so
```
1. 切换目录到 pipes 下再次编译
```shell
$cd /home/hadoop/env/hadoop/src/c++/pipes
执行
$ make distclean
$ ./configure 
[hadoop@master11 pipes]$ ./configure 
checking for a BSD-compatible install... /usr/bin/install -c
… … 
checking whether it is safe to define __EXTENSIONS__... yes
checking for special C compiler options needed for large files... no
checking for _FILE_OFFSET_BITS value needed for large files... no
checking pthread.h usability... yes
checking pthread.h presence... yes
checking for pthread.h... yes
checking for pthread_create in -lpthread... yes
checking for HMAC_Init in -lssl... no
configure: error: Cannot find libssl.so ## 还是没找到
./configure: line 5234: exit: please: numeric argument required
./configure: line 5234: exit: please: numeric argument required
```

1. 安装openssl-devel, `sudo yum install openssl-devel`

1. 再切换到Hadoop根目录下执行
```shell
ant -Dcompile.c++=yes examples
##搞定，编译通过
compile-examples:
    [javac] /home/hadoop/env/hadoop-1.2.1/build.xml:742: warning: 'includeantruntime' was not set, defaulting to build.sysclasspath=last; set to false for repeatable builds
    [javac] Compiling 24 source files to /home/hadoop/env/hadoop-1.2.1/build/examples
    [javac] 警告: [options] 未与 -source 1.6 一起设置引导类路径
    [javac] 注: /home/hadoop/env/hadoop-1.2.1/src/examples/org/apache/hadoop/examples/MultiFileWordCount.java使用或覆盖了已过时的 API。
    [javac] 注: 有关详细信息, 请使用 -Xlint:deprecation 重新编译。
    [javac] 1 个警告
examples:
      [jar] Building jar: /home/hadoop/env/hadoop-1.2.1/build/hadoop-examples-1.2.2-SNAPSHOT.jar
BUILD SUCCESSFUL
Total time: 1 minute 11 seconds
```
 