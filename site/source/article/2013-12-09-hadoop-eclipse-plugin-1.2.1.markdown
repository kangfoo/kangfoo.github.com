---
layout: post
title:  编译hadoop 1.2.1 hadoop-eclipse-plugin插件
date: '2013-12-09 22:52'
comments: true
published: true
keywords: hadoop,hadoop-eclipse-plugin
description: 使用ant编译hadoop 1.2.1 hadoop-eclipse-plugin插件
excerpt: 
categories: ['hadoop']
tags: ['java','ant','hadoop']
---
编译hadoop1.x.x版本的eclipse插件为何如此繁琐？


个人理解，ant的初衷是打造一个本地化工具，而编译hadoop插件的资源间的依赖超出了这一目标。导致我们在使用ant编译的时候需要手工去修改配置。那么自然少不了设置环境变量、设置classpath、添加依赖、设置主函数、javac、jar清单文件编写、验证、部署等步骤。

那么我们开始动手

#### 主要步骤如下####
*  设置环境变量 
*  设置ant初始参数
*  调整java编译参数 
*  设置java classpath 
*  添加依赖 
*  修改META-INF文件 
*  编译打包、部署、验证

#### 具体操作####
1. 设置语言环境
<!-- lang:shell-->
```shell
$ export LC_ALL=en
```
1. 设置ant初始参数
修改build-contrib.xml文件
<!--- lang:shell -->
```shell
  $ cd /hadoop-1.2.1/src/contrib
  $ vi build-contrib.xml
```  
编辑并修改hadoop.root值为实际hadoop解压的根目录
<!--- lang:xml -->
```xml
<property name="hadoop.root" location="/Users/kangfoo-mac/study/hadoop-1.2.1"/>
```
添加eclipse依赖
<!--- lang:xml -->
```xml
<property name="eclipse.home" location="/Users/kangfoo-mac/work/soft/eclipse-standard-kepler-SR1-macosx-cocoa" />
```
设置版本号
<!--- lang:xml -->
```xml
<property name="version" value="1.2.1"/>
```
1. 调整java编译设置
启用javac.deprecation
<!--- lang:shell -->
```shell
 $ cd /hadoop-1.2.1/src/contrib
 $ vi build-contrib.xml
```
将  
<!--- lang:xml -->
```xml
<property name="javac.deprecation" value="off"/>
```
改为
<!--- lang:xml -->
```xml
<property name="javac.deprecation" value="on"/>
```
1. ant 1.8+ 版本需要额外的设置javac includeantruntime="on" 参数
<!--- lang:xml -->
```xml
  <!-- ====================================================== -->
  <!-- Compile a Hadoop contrib's files                       -->
  <!-- ====================================================== -->
  <target name="compile" depends="init, ivy-retrieve-common" unless="skip.contrib">
    <echo message="contrib: ${'$'}{name}"/>
    <javac
     encoding="${'$'}{build.encoding}"
     srcdir="${'$'}{src.dir}"
     includes="**/*.java"
     destdir="${'$'}{build.classes}"
     debug="${'$'}{javac.debug}"
     deprecation="${'$'}{javac.deprecation}"
     includeantruntime="on">
     <classpath refid="contrib-classpath"/>
    </javac>
  </target> 
```
1. 修改编译hadoop插件 classpath
<!--- lang:shell -->
```shell
  $ cd hadoop-1.2.1/src/contrib/eclipse-plugin
  $ vi build.xml
```
添加 文件路径 hadoop-jars
<!--- lang:xml -->
```xml 
  <path id="hadoop-jars">
      <fileset dir="${'$'}{hadoop.root}/">
        <include name="hadoop-*.jar"/>
      </fileset>
  </path>
```  
将hadoop-jars 添加到classpath
<!--- lang:xml -->
```xml  
  <path id="classpath">
      <pathelement location="${'$'}{build.classes}"/>
      <pathelement location="${'$'}{hadoop.root}/build/classes"/>
      <path refid="eclipse-sdk-jars"/>
      <path refid="hadoop-jars"/>
  </path> 
```
1. 修改或添加额外的jar依赖
因为我们根本都没有直接编译过hadoop,所以就直接使用${'$'}{HADOOP_HOME}/lib下的资源.需要注意，这里将依赖jar的版本后缀去掉了。
同样还是在hadoop-1.2.1/src/contrib/eclipse-plugin/build.xml文件中修改或添加
<!--- lang:shell -->
```shell
  $ cd hadoop-1.2.1/src/contrib/eclipse-plugin
  $ vi build.xml
```
找到 `<!-- Override jar target to specify manifest -->` 修改target name为 jar 中的 copy file 的路径，具体如下：
<!--- lang:xml -->
```xml  
<copy file="${'$'}{hadoop.root}/hadoop-core-${'$'}{version}.jar" tofile="${'$'}{build.dir}/lib/hadoop-core.jar" verbose="true"/>
<copy file="${'$'}{hadoop.root}/lib/commons-cli-${'$'}{commons-cli.version}.jar"  tofile="${'$'}{build.dir}/lib/commons-cli.jar" verbose="true"/>
<copy file="${'$'}{hadoop.root}/lib/commons-configuration-1.6.jar"  tofile="${'$'}{build.dir}/lib/commons-configuration.jar" verbose="true"/>
<copy file="${'$'}{hadoop.root}/lib/commons-httpclient-3.0.1.jar"  tofile="${'$'}{build.dir}/lib/commons-httpclient.jar" verbose="true"/>
<copy file="${'$'}{hadoop.root}/lib/commons-lang-2.4.jar"  tofile="${'$'}{build.dir}/lib/commons-lang.jar" verbose="true"/>
<copy file="${'$'}{hadoop.root}/lib/jackson-core-asl-1.8.8.jar"  tofile="${'$'}{build.dir}/lib/jackson-core-asl.jar" verbose="true"/>
<copy file="${'$'}{hadoop.root}/lib/jackson-mapper-asl-1.8.8.jar"  tofile="${'$'}{build.dir}/lib/jackson-mapper-asl.jar" verbose="true"/>
```
1. 修改 jar 清单文件
<!--- lang:xml -->
```shell
 $ cd ./hadoop-1.2.1/src/contrib/eclipse-plugin/META-INF
 $ vi MANIFEST.MF
``` 
找到这个文件的Bundle-ClassPath这一行，然后，修改成
<!--- lang:xml -->
```shell
Bundle-ClassPath: classes/,lib/commons-cli.jar,lib/commons-httpclient.jar,lib/hadoop-core.jar,lib/jackson-mapper-asl.jar,lib/commons-configuration.jar,lib/commons-lang.jar,lib/jackson-core-asl.jar
```
请保证上述字符占用一行，或者满足osgi bundle 配置文件的换行标准语法也行的。省事就直接写成一行，搞定。
1. 新建直接打包并部署jar到eclipse/plugin目录的target
<!--- lang:shell -->
```shell
  $ cd hadoop-1.2.1/src/contrib/eclipse-plugin
  $ vi build.xml
```  
添加target直接将编译的插件拷贝到eclipse插件目录
<!--- lang:xml -->
```xml
<target name="deploy" depends="jar" unless="skip.contrib"> 
	<copy file="${'$'}{build.dir}/hadoop-${'$'}{name}-${'$'}{version}.jar" todir="${'$'}{eclipse.home}/plugins" verbose="true"/> </target>
```
修改ant默认target为deploy
<!--- lang:xml -->
```xml
<project default="deploy" name="eclipse-plugin">
```
1. 编译并启动eclipse验证插件
<!--- lang:shell -->
```shell
$ ant -f ./hadoop-1.2.1/src/contrib/eclipse-plugin/build.xml
```
启动eclipse，新建Map/Reduce Project,配置hadoop location.验证插件完全分布式的插件配置截图和core-site.xml端口配置
1. 效果图
![image](http://zhaomingtai.u.qiniudn.com/hadoop-eclipse-plugins-1.2.1.png?token=aq6Vqqet0FuJ5-au0uAsoWmT8velHmW1zuXJ56PU:b0nXaq4z_psXKmgw0yBWCQIlw9w=:eyJTIjoiemhhb21pbmd0YWkudS5xaW5pdWRuLmNvbS9oYWRvb3AtZWNsaXBzZS1wbHVnaW5zLTEuMi4xLnBuZyIsIkUiOjEzODY3Mzg2NjB9)

#### 相关源文件####
* [hadoop-1.2.1/src/contrib/build-contrib.xml]
* [hadoop-1.2.1/src/contrib/eclipse-plugin/build.xml]
* [hadoop-1.2.1/src/contrib/eclipse-plugin/META-INF/MANIFEST.MF]
* [hadoop-eclipse-plugin-1.2.1.jar] 

*在此非常感谢[kinuxroot]这位博主的的博文参考。*


[kinuxroot]:http://www.cnblogs.com/kinuxroot/archive/2013/05/06/linux_hadoop_eclipse_plugin.html

[hadoop-1.2.1/src/contrib/build-contrib.xml]:http://zhaomingtai.u.qiniudn.com/hadoop-eclipse-plugins-1.2.1-build-contrib.xml?token=aq6Vqqet0FuJ5-au0uAsoWmT8velHmW1zuXJ56PU:UGF5ciPhL5L_71XPMfHcyczxfbY=:eyJTIjoiemhhb21pbmd0YWkudS5xaW5pdWRuLmNvbS9oYWRvb3AtZWNsaXBzZS1wbHVnaW5zLTEuMi4xLWJ1aWxkLWNvbnRyaWIueG1sIiwiRSI6MTM4Njc0NzQxN30=&download

[hadoop-1.2.1/src/contrib/eclipse-plugin/build.xml]:http://zhaomingtai.u.qiniudn.com/hadoop-eclipse-plugins-1.2.1-build.xml?token=aq6Vqqet0FuJ5-au0uAsoWmT8velHmW1zuXJ56PU:s_IcusoS1921HGL4jPYW0mkGZUw=:eyJTIjoiemhhb21pbmd0YWkudS5xaW5pdWRuLmNvbS9oYWRvb3AtZWNsaXBzZS1wbHVnaW5zLTEuMi4xLWJ1aWxkLnhtbCIsIkUiOjEzODY3NDc0MDd9&download

[hadoop-1.2.1/src/contrib/eclipse-plugin/META-INF/MANIFEST.MF]:http://zhaomingtai.u.qiniudn.com/hadoop-eclipse-plugins-1.2.1-build.xml?token=aq6Vqqet0FuJ5-au0uAsoWmT8velHmW1zuXJ56PU:s_IcusoS1921HGL4jPYW0mkGZUw=:eyJTIjoiemhhb21pbmd0YWkudS5xaW5pdWRuLmNvbS9oYWRvb3AtZWNsaXBzZS1wbHVnaW5zLTEuMi4xLWJ1aWxkLnhtbCIsIkUiOjEzODY3NDc0MDd9&download

[hadoop-eclipse-plugin-1.2.1.jar]:http://zhaomingtai.u.qiniudn.com/hadoop-eclipse-plugin-1.2.1.jar?token=aq6Vqqet0FuJ5-au0uAsoWmT8velHmW1zuXJ56PU:PrPGIRgkUtbfDjTJqjyrc7mgWB4=:eyJTIjoiemhhb21pbmd0YWkudS5xaW5pdWRuLmNvbS9oYWRvb3AtZWNsaXBzZS1wbHVnaW4tMS4yLjEuamFyIiwiRSI6MTM4Njc0ODc0NH0=&download



