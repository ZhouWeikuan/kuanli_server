# kuanli_server 宽立游戏服务器

基于skynet实现的宽立游戏服务器，支持斗地主等棋牌游戏和贪吃蛇大作战等在线类休闲游戏。



## 环境设置

使用vagrant搭建的集群环境，机器名称和IP地址分别为 node1(11.11.1.11)， node2(11.11.1.12)，node3(11.11.1.13)。

数据库用的是MySQL 主-主-主 结构，三台机器上的MySQL互为主从，**auto_increment_increment=5**, **auto_increment_offset**分别是**1**, **2**, **3**，避免**auto_increment**自动生成的主键冲突。Redis也是三台服务器上都有，分别各是一个redis-server，一个redis-sentinel；三台机器上的redis-server只有一个主服务器，其它两个是从服务器；使用redis-sentinel监控主服务器的健康，一有问题就把某一台从服务器切换成主服务器；之前的主服务器恢复后，自动变成从服务器。



## 运行说明

最主要的服务器节点分别是MainServer, HallServer, AgentServer。MainServer是监控服务器，提供其它功能服务器的查询和数据库服务；HallServer是游戏服务器；AgentServer是连接服务器，管理玩家来自TCP和Web socket的连接。

文件config/config.nodes是服务器各机器各节点的配置文件。所有机器都是同等的，给各服务器节点保留了相应的端口，可以运行上述的任何一类服务器。

启动MainServer如下所示:

```shell
# sh MainServer/start.sh node3 1
NodeName = node3, ServerKind = MainServer, ServerNo = 1
debug port is   8501
```

启动HallServer如下所示:

```shell
# sh HallServer/start.sh node2 1 config/landlord.cfg
NodeName = node2, ServerName = HallServer, ServerNo = 1, HallConfig=config/landlord.cfg
debug port is   9001
load    8       client bots
```

启动AgentServer如下所示:

```shell
# sh AgentServer/start.sh node1 1
NodeName = node1, ServerKind = AgentServer, ServerNo = 1
debug port is   8001
```



以上服务器启动后，会显示本节点的调试端口，可以在本机上使用一下命令进入调试控制台:

```shell
# telnet localhost 8501
Trying ::1...
telnet: connect to address ::1: Connection refused
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
Welcome to skynet console

list
:00000004       snlua cdummy
:00000006       snlua datacenterd
:00000007       snlua service_mgr
:00000009       snlua clusterd
:0000000a       snlua NodeInfo
:0000000b       snlua debug_console 8501
:0000000c       snlua gate
:0000000d       snlua NodeStat
:0000000e       snlua NodeLink
:0000000f       snlua MainInfo
:00000010       snlua DBService
:00000011       snlua RedisService
:00000013       snlua MySQLService
:00000014       snlua clusteragent 9 12 29
:00000020       snlua clusteragent 9 12 58
<CMD OK>

info :d
Mon Aug 27 10:16:06 2018
[Agent List]
node1_AgentServer1      11.11.1.11:8001 num:0

[Hall List]
node2_HallServer1       11.11.1.12:9001 num:0   => [400, 800]   天天斗地主 id:2011 mode:1 version:20180901 low:20180901

大厅服务器数目:1        客户服务器数目:1        登陆人数:0      游戏人数:0

<CMD OK>
```

其中，**list** 和 **info :d** 这两个命令是我们在调试控制台的输入。我们保证各服务启动的顺序，这样任何一个节点的调试控制台输入 **info :d** 都会定位到**NodeStat**服务，显示相应的节点状态。

