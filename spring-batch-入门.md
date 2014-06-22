1. 批处理
在企业级应用系统当中，面对日益复杂的义务及一定规模的数据量，频繁的人机操作会引入一定的时间成本和管理风险。可以采取定时读取大批数据，在执行相应的工作流程，并归档。我首先想到的就是直接使用批处理进行解决。以解决我可能要面对的与特定时间周期相关、数据量大、尽量少人工干涉、自动完成、事后督察等工作。这些工作可以用 存储过程 + shell 等方式实现，但作为应用程序而言，我倾向于使用JAVA api. jdk 7 才有原生的API支持(这是 [JAVA 7 Batch Processing Tutorial](http://docs.oracle.com/javaee/7/tutorial/doc/batch-processing.htm))。貌似6要费费劲。我一直是spring 的粉丝。SpringBatch 自然会上场的。

2. spring batch
一般的批处理都分有三个阶段
读数据（我的数据目前大部分来自于文件）
处理数据（业务逻辑）
写数据（将业务结果写入数据库）
这些过程又必选考虑效率、事物的粒度、监控、资源开销。读和写、业务处理一般都是独立的模块可直接解耦。谷歌了一番，看中了 spring batch。

那么 spring batch 可以给我们带来什么好处？
Spring Batch作为Spring的一个顶级子项目，是一款优秀的大数据量并行处理框架。通过Spring Batch可以构建出轻量级的健壮的并行处理应用，支持事务、并发、监控，提供统一的接口管理和任务管理。 

谷歌文档一堆呀。先列举下我认为不错的。

* [spring-batch-quick-start](http://projects.spring.io/spring-batch/#quick-start) 
* [spring-batch-docs](http://docs.spring.io/spring-batch/) 
* [2.1.8 中文版的翻译](http://blog.csdn.net/shorn/article/details/7744579)
* [基​于​S​p​r​i​n​g​ ​B​a​t​c​h​的​大​数​据​量​并​行​处​理](http://wenku.baidu.com/view/9134505a0b1c59eef8c7b456)
* [使用 Spring Batch 构建企业级批处理应用: 第 1 部分](http://www.ibm.com/developerworks/cn/java/j-lo-springbatch1/)
* [spring 官方教程示例](http://spring.io/guides/gs/batch-processing/)
* [maven-springbatch-archetype](https://github.com/chrisjs/maven-springbatch-archetype)  maven archetype 插件默认使用的是 springbatch 2.2.5 稳定版的。其默认生成的示例和[ spring batch 官方文档](http://spring.io/guides/gs/batch-processing/)上提供的数据完全一致，官方介绍。

好吧工具算是找的差不多了。
也要开始我的第一个 demo 了。具体的概念先放放。东西弄出来了，在慢慢细嚼。

1. 首先 git clone [maven-springbatch-archetype](https://github.com/chrisjs/maven-springbatch-archetype) maven 插件。同时请确保你自己的版本，我当前使用的 1.4-SNAPSHOT ，按照 readme 一步步执行吧。

1. 生成我们自己的样板工程代码结构
```shell
mvn archetype:generate \
    -DarchetypeGroupId=com.dtzq \
    -DarchetypeArtifactId=maven-springbatch-archetype \
    -DarchetypeVersion=1.4-SNAPSHOT \
    -DgroupId=com.kangfoo.study.hygeia \
    -DartifactId=springbatch.test \
    -Dversion=1.0-SNAPSHOT \
    -Dpackage=com.kangfoo.study.hygeia.springbatch.test
```

1. 题外话。第一次在 github 向他人维护的项目提交代码，弄了会儿，玩转了。
主要借鉴[花20分钟写的-大白话讲解如何给github上项目贡献代码]( http://site.douban.com/196781/widget/notes/12161495/note/269163206/)
先记录在案。

1. spring batch + quartz
http://www.mkyong.com/spring-batch/spring-batch-and-quartz-scheduler-example/


















