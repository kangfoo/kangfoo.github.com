---
layout: post
title: native-hadoop 编译
date: '2014-02-26 00:57'
comments: true
published: true
keywords: native-hadoop 编译
description: native-hadoop 编译
excerpt: 
categories: ['hadoop']
tags: ['hadoop1']
---
对我来讲编译 native hadoop 并不是很顺利。现将问题纪录在案。

### 主要问题 ###

1. ivy 联网获取资源并不稳定
2. hadoop-1.2.1/build.xml:62: Execute failed: java.io.IOException: Cannot run program “autoreconf” (in directory “/home/userxxx/hadoop/hadoop-1.2.1/src/native”): java.io.IOException: error=2, No such file or directory
3. [exec] configure: error: Zlib headers were not found... native-hadoop library needs zlib to build. Please install the requisite zlib development package.
4. 多次编译失败之后要记得执行 make distclean 清理一下。
5. 编译完 ant compile-native 之后，启动 hadoop 使用 http 访问 /dfshealth.jsp /jobtracker.jsp HTTP ERROR 404
6. 在 Linux 平台下编译 native hadoop 是不可以的，目前。错误：/hadoop-1.2.1/build.xml:694: exec returned: 1

### 解决方案 ###

1. 第一个问题只能多次尝试。
2. 第二，第三个问题主要是是没有安装 zlib。顺便请保证 gcc c++, autoconf, automake, libtool, openssl,openssl-devel 也安装。安装 zlib 请参考 http://www.zlib.net/ 。
3. 第四个问题就是 基本的 make 三部曲的步骤。
4. 第五个问题原因是在 build native 库的同时,生成了 webapps 目录(在当前的 target 这个目录是个基本的结构，没有任何 jsp 等资源，404找不到很正常)。那么当我们编译过build之后，hadoop启动时又指向了这个目录，就导致这个错误。我们就可以直接将这个 build 文件夹删除了或者改脚本。问题搞定了。
5. 第六个问题，援引官方
<pre>
Supported Platforms
The native hadoop library is supported on *nix platforms only. The library does not to work with Cygwin or the Mac OS X platform.
</pre>
那就老实点用 *nix platforms，就没事了。