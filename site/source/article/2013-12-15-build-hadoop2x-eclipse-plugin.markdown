---
layout: post
title: 编译hadoop 2.x Hadoop-eclipse-plugin插件
date: '2013-12-15 00:19'
comments: true
published: true
keywords: hadoop,hadoop-eclipse-plugin
description: 使用ant编译hadoop 2.x hadoop-eclipse-plugin插件
excerpt: 
categories: ['hadoop']
tags: ['java','ant','hadoop']
---

经过hadoop1.x的发展，编译hadoop2.x版本的eclipse插件视乎比之前要轻松的多。如果你不在意编译过程中提示的警告，那么根据[how to build - hadoop2x-eclipse-plugin]文档就可一步到位。若想自己设置部分变量，可参考[编译hadoop 1.2.1 Hadoop-eclipse-plugin插件]。

#### 主要步骤####
* 介质准备
* 执行
* 安装验证

#### 具体操作####
1. 设置语言环境
<!-- lang:shell-->
```shell
$ export LC_ALL=en
```

1. 检查ANT_HOME,JAVA_HOME

1. 下载hadoop2x-eclipse-plugin
目前hadoop2的eclipse-plugins源代码由github脱管，下载地址[how to build - hadoop2x-eclipse-plugin] 右侧的 "Download ZIP" 或者 克隆到桌面. 当然你也可以fork到你自己的帐户下,在使用git clone。

1. 执行
<!-- lang:shell-->
```shell
$ cd src/contrib/eclipse-plugin
$ ant jar -Dversion=2.2.0 -Declipse.home=/opt/eclipse -Dhadoop.home=/usr/share/hadoop
```
将上述java system property eclipse.home 和 hadoop.home 设置成你自己的环境路径。 执行上述命令可能很快或者很慢。请耐心等待。主要慢的target:ivy-download，ivy-resolve-common。最后jar生成在
`$root/build/contrib/eclipse-plugin/hadoop-eclipse-plugin-2.2.0.jar`路径下。

1. 安装验证
将生成好的jar,复制到`${'$'}{eclipse.home}/plugins`目录下。启动eclipse，新建Map/Reduce Project,配置hadoop location.验证插件完全分布式的插件配置截图和core-site.xml端口配置。

1. 效果图
使用插件访问本地的伪分布式hadoop环境。查看文件texst1.txt和test2.txt同使用命令 hadoop dfs -ls /in 效果相同。
![image](http://zhaomingtai.u.qiniudn.com/hadoop2x-eclipse-plugin-success.jpg)

1. 已编译的插件
[hadoop-eclipse-plugin-2.2.0.jar]

1. 备注
 
目前我在使用这个版本的插件时发现还时挺不稳定的。发现了两个缺陷。我的环境为：Java HotSpot(TM) 64-Bit Server VM、 eclipse-standard-kepler-SR1-macosx-cocoa、 hadoop2.2.0。

缺陷:

*  Editor could not be initalized.
*  NullPointException

截图如下：
![image](http://zhaomingtai.u.qiniudn.com/hadoop2x-eclipse-plugin-exeception.jpg)





[how to build - hadoop2x-eclipse-plugin]:https://github.com/winghc/hadoop2x-eclipse-plugin
[编译hadoop 1.2.1 Hadoop-eclipse-plugin插件]:http://kangfoo.u.qiniudn.com/article/2013/12/hadoop-eclipse-plugin-1.2.1/
[hadoop-eclipse-plugin-2.2.0.jar]:http://zhaomingtai.u.qiniudn.com/hadoop-eclipse-plugin-2.2.0.jar


