---
layout: post
title: Hadoop 机架感知
date: '2014-02-26 00:52'
published: true
keywords: Hadoop 机架感知
description: Hadoop 机架感知
categories: ['hadoop']
tags: ['hadoop1']
---

HDFS 和 Map/Reduce 的组件是能够感知机架的。

NameNode 和 JobTracker 通过调用管理员配置模块中的 API resolve 来获取集群里每个 slave 的机架id。该 API 将 slave 的 DNS 名称（或者IP地址）转换成机架id。使用哪个模块是通过配置项 topology.node.switch.mapping.impl 来指定的。模块的默认实现会调用 topology.script.file.name 配置项指定的一个的脚本/命令。 如果 topology.script.file.name 未被设置，对于所有传入的IP地址，模块会返回 /default-rack 作为机架 id。

在 Map/Reduce 部分还有一个额外的配置项 mapred.cache.task.levels ，该参数决定 cache 的级数（在网络拓扑中）。例如，如果默认值是2，会建立两级的 cache—— 一级针对主机（主机 -> 任务的映射）另一级针对机架（机架 -> 任务的映射）。

我目前没有模拟环境先纪录个参考博客 [机架感知] 以备后用。

[机架感知]: http://www.cnblogs.com/ggjucheng/archive/2013/01/03/2843015.html