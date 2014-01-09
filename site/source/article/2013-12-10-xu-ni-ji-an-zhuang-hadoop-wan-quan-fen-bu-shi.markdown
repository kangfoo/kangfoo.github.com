---
layout: post
title: 在oracle virtual box 虚拟机中搭建hadoop1.2.1完全分布式环境
date: '2013-12-10 17:32'
comments: true
published: true
keywords: hadoop,centos,virtual box,hadoop完全分布式安装
description: 
excerpt: 
categories: ['hadoop']
tags: 
---
## 一、初衷

对于学习Hadoop的我来将，没有足够的硬件设备，但又想安装完全分布式的Hadoop，一个master两个slave。手上就一台能联网的笔记本，那就使用oracle vitual box进行环境搭建把。环境搭建的效果为：在虚拟机中虚拟3台centos6.4 64位系统，每台都配置双网卡NAT,host-only模式。在宿主机器上安装eclipse进行Hadoop开发。

Hadoop环境搭建很大部分是在准备操作系统。具体如何搭建Hadoop其实就像解压缩普通的tar类似。然后再适当的配置Hadoop的dfs,mapredurce相关的配置，调整操作系统就可以开始着手学习Hadoop了。

## 二、拓补图

图片制作中… …

* master11:192.168.56.11
* slave12:192.168.56.12
* slave14:192.168.56.14


## 三、介质准备
* 虚拟机 [oracle virtual box Mac]
* 操作系统镜像 [centos 6.4 64位 网易镜像]
* java [jdk-7u45-linux-x64.rpm] 或者 [jdk-6u45-linux-x64-rpm.bin]
* hadoop1.x [hadoop1.2.1]
* eclipse [eclipse mac版64位]

**其他版本可到相关官方网站根据需要自行下载**

## 四、虚拟机和基础环境搭建

这里主要操作有：安装一个新的oracle virtual box，并先安装一个centos6.4 的64位的操作系统。配置操作系统双网卡、修改机器名为master11、新建hadoop用户组和hadoop用户、配置sudo权限、安装配置java环境、同步系统时间、关闭防火墙。其中有些步骤需要重启操作系统后成效，建议一切都配置后再重启并再次验证是否生效，并开始克隆两个DataNode节点服务器slave12\slave14。

### 4.1 安装虚拟机

可参见官方文档安装oracle virtual box

### 4.2 在虚拟机里安装centos6.4

此处使用的是mini版的centos6.4 64位网易提供的镜像。在安装中内存调整大于等于1g，默认为视图安装界面，小于1g则为命令行终端安装方式。可更具实际情况调整虚拟机资源分配。此处为内存1g,存储20g.网络NAT模式。

具体可参见[centos安装]

### 4.3 配置双网卡

使用自己的笔记本经常遇到的问题就是在不同的网络下ip是不一样的。那么我们在学习hadoop的时候岂不是要经常修改这些ip呢。索性就直接弄个host-only模式的让oracle virtual box提供一个虚拟的网关。具体步骤：

1. 先关闭计算机 sudo poweroff
1. 打开virtualbox主界面,依次点击屏幕左上角virtualbox->偏好设置->网络->点击右侧添加图标添加一个Host-Only网络vboxnet0,再设置参数值<pre>
主机虚拟网络界面（A）
IPv4地址（I）：192.168.56.1
IPv4网络掩码（M）：255.255.255.0
IPv6地址（P）：空
IPv6网络掩码长度（L）：0</pre><pre>
DHCP服务器（D）
选择启动服务器
服务器地址(r):192.168.56.100
服务器网络掩码(M):255.255.255.0
最小地址(L):192.168.56.254
最大地址(U):192.168.56.254
</pre>
截图：![image](http://zhaomingtai.u.qiniudn.com/nat-host-only.jpg)
1. 配置网卡1。选中你刚新建的虚拟机，右键设置->网络->网卡1->点击启动网络连接（E）<pre>
连接方式（A）:仅主机（Host-Only）适配器
界面名称（N）:vboxnet0(此处需要注意，如果没有进行步骤1那么这里可能无法选择，整个设置流程会提示有错误而无法继续)
高级
控制芯片（T）:xxx
混杂模式（P）:拒绝
MAC地址（M）:系统随机即可
接入网线（C）：选中
</pre>

1. 配置网卡2。点击网卡2->点击启动网络连接（E） <pre>
连接方式（A）:网络地址装换(NAT)
界面名称（N）:
高级(d)
控制芯片（T）:xxx
混杂模式（P）:拒绝
MAC地址（M）:系统随机即可
接入网线（C）：选中
</pre>

1. 配置网络。启动操作系统，使用root用户进行网络配置。
<!--- lang:shell -->
```shell
   cd /etc/sysconfig/network-scripts/
   cp ifcfg-eth0 ifcfg-eth1
```
配置ifcfg-eth0,ifcfg-eth1两个文件与virtual box 中的网卡mac值一一对应, `ONBOOT=yes`开机启动。并将ifcfg-eth1中的网卡名称eth0改为eth1,再重启网路服务。
<!--- lang:shell -->
```shell
   service network start
```
其中eth0的网关信息比较多，需要根据情况具体配置。如，这里使用eth0为host-only模式，eth1为nat模式,eth0为固定ip，eth1为开机自动获取ip。可参考如下：
<pre>
[root@master11 network-scripts]# cat ifcfg-eth0
DEVICE=eth0
HWADDR=08:00:27:55:99:EA（必须和virtual box 中的mac地址一致）
TYPE=Ethernet
UUID=dc6511c2-b5bb-4ccc-9775-84679a726db3（没有可不填）
ONBOOT=yes
NM_CONTROLLED=yes
BOOTPROTO=static
NETMASK=255.255.255.0
BROADCAST=192.168.56.255
IPADDR=192.168.56.11</pre><pre>
[root@master11 network-scripts]# cat ifcfg-eth1
DEVICE=eth1
HWADDR=08:00:27:13:36:C3
TYPE=Ethernet
UUID=b8f8485e-b731-4b64-8363-418dbe34880d
ONBOOT=yes
NM_CONTROLLED=yes
BOOTPROTO=dhcp
</pre>

### 4.4 检查机器名称

检查机器名称。修改后，重启生效。
<!--- lang:shell -->
```shell
   cat /etc/sysconfig/network
```
这里期望得机器名称信息是：
<pre>
 NETWORKING=yes
 HOSTNAME=master11
</pre>

### 4.5 建立hadoop用户组和用户

新建hadoop用户组和用户(以下步骤如无特殊说明默认皆使用hadoop)
<!--- lang:shell -->
```shell
groupadd hadoop
useradd hadoop -g hadoop
passwd hadoop
```

### 4.6 配置sudo权限

CentOS普通用户增加sudo权限的简单配置<br/>
查看sudo是否安装:
<!--- lang:shell -->
```shell
rpm -qa|grep sudo
```
修改/etc/sudoers文件，修改命令必须为visudo才行
<!--- lang:shell -->
```shell
visudo -f /etc/sudoers
```
在root ALL=(ALL) ALL 之后增加
<!--- lang:shell -->
```shell
hadoop ALL=(ALL) ALL
Defaults:hadoop timestamp_timeout=-1,runaspw
```
<pre>
增加普通账户hadoop的sudo权限
timestamp_timeout=-1 只需验证一次密码，以后系统自动记忆
runaspw  需要root密码，如果不加默认是要输入普通账户的密码</pre>
修改普通用户的.bash_profile文件(vi /home/hadoop/.bash_profile)，在PATH变量中增加
`/sbin:/usr/sbin:/usr/local/sbin:/usr/kerberos/sbin`

### 4.7 安装java

使用hadoop用户`sudo rpm -ivh jdk-7-linux-x64.rpm`进行安装jdk7。
配置环境变量参考[CentOS-6.3安装配置JDK-7]

### 4.8 同步服务

安装时间同步服务`sudo yum install -y ntp`
设置同步服务器 `sudo ntpdate us.pool.ntp.org` 

### 4.9 关闭防火墙

hadoop使用的端口太多了，图省事，关掉。`chkconfig iptables off`。需要重启。 

### 4.10 克隆

使用虚拟机进行克隆2个datanode节点。配置网卡（参见第五步）。配置主机名（参见第六步）。配置hosts,最好也包括宿主机（`sudo vi /etc/hosts`）
<pre>
192.168.56.11 master11
192.168.56.12 slave12
192.168.56.14 slave14
</pre>
同步时间
<!--- lang:shell -->
```shell
sudo ntpdate us.pool.ntp.org
```
重启服务`service network start`。可能出现错误参见[device eth0 does not seem to be present, delaying initialization]

### 4.11 配置ssh
1. 单机ssh配置并回环测试
<!--- lang:shell -->
```shell
ssh-keygen -t dsa -P '' -f ~/.ssh/id_dsa   
chmod 700 ~/.ssh
cat ~/.ssh/id_dsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```
输入`ssh localhost`不用输入密码直接登陆，表明ssh配置成功。（若未重新权限分配，可能无法实现ssh免密码登陆的效果。浪费了我不少时间。）
2. 配置master和slave间的ssh
在slave12上执行
<!--- lang:shell -->
```shell
scp hadoop@master11:~/.ssh/id_dsa.pub ./master_dsa.pub
cat master_dsa.pub >>authorized_keys
```
在master上执行`ssh slave12`若，不输入密码直接登陆，配置即通过。
3. 相同的步骤需要也在slave14和master11上重复一遍。

机器环境确认无误后可以轻松的安装hadoop。

## 五、hadoop1.2.1 安装与配置

经过了以上步骤准备Hadoop1.2.1的环境搭建就相对容易多了。此处就仅需要解压缩安装并配置Hadoop，再验证是否正常便可大功告成。

### 5.1 安装

1. 重启master11,准备工作环境目录
<!--- lang:shell -->
```shell
cd ~/
mkdir env
```
1. 解压Hadoop 1.2.1 tar
<!--- lang:shell -->
```shell
tar -zxvf hadoop-1.2.1.tar.gz -C ~/env/
```
1. 建立软链接
<!--- lang:shell -->
```shell
ln -s hadoop-1.2.1/ hadoop
```
1. 配置环境变量（`vi ～/.bashrc`）
<!--- lang:shell -->
```shell
export JAVA_HOME=/usr/java/jdk1.7.0_45
source ~/.bashrc
```
1. 同步.bashrc
```shell
scp ~/.bashrc hadoop@slave12:~/
scp ~/.bashrc hadoop@slave14:~/
```
1. 创建数据文件存放路径。主要便于管理Hadoop的数据文件。
<!--- lang:shell -->
```shell
cd /home/hadoop/env
mkdir data
mkdir data/tmp
mkdir data/name
mkdir data/data
chmod 755 data/data/
mkdir mapreduce
mkdir mapreduce/system
mkdir mapreduce/local
```
效果如下
<pre>
├── env
│   ├── data
│   │   ├── data
│   │   ├── name
│   │   └── tmp
│   ├── hadoop -> hadoop-1.2.1/
│   ├── hadoop-1.2.1
│   │   ├── bin
│   │   ├── build.xml
│   └── mapreduce
│       ├── local
│       └── system

</pre>

### 5.2 配置

1. 配置 conf/core-site.xml
指定hdfs协议下的存储和临时目录
<!--- lang:xml -->
```xml
    <property>
      <name>fs.default.name</name>
      <value>hdfs://master11:9000</value>
    </property>
    <property>
      <name>hadoop.tmp.dir</name>
      <value>/home/${'$'}{user.name}/env/data/tmp</value>
    </property>
```

1. 配置 conf/hdfs-site.xml
配置关于hdfs相关的配置。这里将原有默认复制3个副本调整为2个。学习时可根据需求适当调整。
<!--- lang:xml -->
```xml
    <property>
     <name>dfs.name.dir</name>
     <value>/home/${'$'}{user.name}/env/data/name</value>
    </property>
    <property>
     <name>dfs.data.dir</name>
     <value>/home/${'$'}{user.name}/env/data/data</value>
    </property>
    <property>
     <name>dfs.replication</name>
      <value>2</value>
    </property>
    <property>
     <name>dfs.web.ugi</name>
     <value>hadoop,supergroup</value>
     <final>true</final>
     <description>The user account used by the web interface. Syntax: USERNAME,GROUP1,GROUP2, ……</description>
   </property>
```

1. 配置 conf/mapred-site.xml
<!--- lang:xml -->
```xml
    <property>
     <name>mapred.job.tracker</name>
     <value>master11:9001</value>
    </property>
    <property>
     <name>mapred.system.dir</name>
     <value>/home/${'$'}{user.name}/env/mapreduce/system</value>
    </property>
    <property>
     <name>mapred.local.dir</name>
     <value>/home/${'$'}{user.name}/env/mapreduce/local</value>
    </property>
```
1. 配置masters
<!--- lang:shell -->
```shell
vi masters
```
写为
<!--- lang:shell -->
```shell
master11
```

1. 配置slaves
<!--- lang:shell -->
```shell
vi slaves
```
写为
<!--- lang:shell -->
```shell
slave12
slave14
```

1. 同步hadoop到子节点 
<!--- lang:shell -->
```shell
scp -r ~/env/ hadoop@slave12:~/
scp -r ~/env/ hadoop@slave14:~/
```

### 5.3 启动hadoop

1. 在主节点上格式化namenode
<!--- lang:shell -->
```shell
./bin/hadoop namenode -format
```

1. 在主节点上启动Hadoop
<!--- lang:shell -->
```shell
./bin/start-all.sh
```

### 5.4 检查运行状态
1. 通过web查看Hadoop状态
<pre>
http://192.168.56.11:50030/jobtracker.jsp
http://192.168.56.11:50070/dfshealth.jsp
</pre>

1. 验证Hadoop mapredurce
执行`hadoop jar hadoop-xx-examples.jar` 验证jobtracker和tasktracker
<!--- lang:shell -->
```shell
./bin/hadoop jar hadoop-0.16.0-examples.jar wordcount input output
```
可wordcount参考[Hadoop集群（第6期）_WordCount运行详解]


## 六、常见错误

* expected: rwxr-xr-x, while actual: rwxrwxr-x
WARN org.apache.hadoop.hdfs.server.datanode.DataNode: Invalid directory in dfs.data.dir: Incorrect permission for /home/hadoop/env/data/data, expected: rwxr-xr-x, while actual: rwxrwxr-x <br/>
**解决方案**：chmod 755 /home/hadoop/env/data/data

* 节点之间不能通信
java.io.IOException: File xxx/jobtracker.info could only be replicated to 0 nodes, instead of 1 <br/>
java.net.NoRouteToHostException: No route to host <br/>
**解决方案**：关闭iptables，`sudo /etc/init.d/iptables stop`

* got exception trying to get groups for user webuser
<pre>
org.apache.hadoop.util.Shell$ExitCodeException: id: webuser：无此用户
         at org.apache.hadoop.util.Shell.runCommand(Shell.java:255)
         at org.apache.hadoop.util.Shell.run(Shell.java:182)
</pre>
**解决方案**：
在hdfs-site.xml文件中添加
<!--- lang:xml -->
```xml
<property>
     <name>dfs.web.ugi</name>
     <value>hadoop,supergroup</value>
     <final>true</final>
     <description>The user account used by the web interface.Syntax: USERNAME,GROUP1,GROUP2, ……
     </description>
   </property>
```
加上这个配置。可以解决了
<pre>
value  第一个为你自己搭建hadoop的用户名,第二个为用户所属组因为默认  
</pre>
web访问授权是webuser用户。访问的时候。我们一般用户名不是webuser所有要覆盖掉默认的webuser 

## 七、附录
* 无意中Google到的一个[hadoop]
* 参考博文：[hadoop学习之hadoop完全分布式集群安装] 图文并茂
* 参考博文：[用 Hadoop 进行分布式并行编程, 第 1 部分] 理论与实践相结合 
* 参考博文：[centos安装]

[oracle virtual box Mac]:http://dlc.sun.com.edgesuite.net/virtualbox/4.2.18/VirtualBox-4.2.18-88780-OSX.dmg
[centos 6.4 64位 网易镜像]:http://mirrors.163.com/centos/6.4/isos/x86_64/CentOS-6.4-x86_64-minimal.iso
[jdk-7u45-linux-x64.rpm]: http://download.oracle.com/otn-pub/java/jdk/7u45-b18/jdk-7u45-linux-x64.rpm?AuthParam=1386411925_f85a151e16f1c54da8a0451e59270b4a
[jdk-6u45-linux-x64-rpm.bin]: http://cd.ctfs.ftn.qq.com/ftn_handler/5b6bcdbb17aada3096f04db2183249eba3560a4b273bcad2993899a61afc06b5803fbcc0a64f564c0c295f339092089fcae828c2f76fccbb07e55ff3e96905c8/jdk-6u45-linux-x64-rpm.bin
[hadoop1.2.1]: http://apache.fayea.com/apache-mirror/hadoop/common/hadoop-1.2.1/hadoop-1.2.1.tar.gz
[eclipse mac版64位]:http://mirrors.yun-idc.com/eclipse//technology/epp/downloads/release/kepler/R/eclipse-standard-kepler-R-macosx-cocoa-x86_64.tar.gz
[hadoop]:http://t3serv002.mit.edu:50070/dfshealth.jsp
[hadoop学习之hadoop完全分布式集群安装]:http://blog.csdn.net/ab198604/article/details/8250461
[用 Hadoop 进行分布式并行编程, 第 1 部分]:http://www.ibm.com/developerworks/cn/opensource/os-cn-hadoop1/
[centos安装]:http://www.jb51.net/os/78318.html
[CentOS-6.3安装配置JDK-7]:http://www.cnblogs.com/zhoulf/archive/2013/02/04/2891608.html
[device eth0 does not seem to be present, delaying initialization]:http://blog.sina.com.cn/s/blog_77126fa501018s3d.html
[Hadoop集群（第6期）_WordCount运行详解]:http://www.cnblogs.com/xia520pi/archive/2012/05/16/2504205.html







