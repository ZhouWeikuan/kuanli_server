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

## 运行结果

```shell
[vagrant@node2 backend]$ sh HallServer/start.sh node2 3 config/yuncheng.cfg 
NodeName = node2, ServerName = HallServer, ServerNo = 3, HallConfig=config/yuncheng.cfg
debug port is   9003
load    5       client bots
joinGame        100161
joinGame        100166
got selfSeatId  3
joinGame        100171
got selfSeatId  2
joinGame        100071
got selfSeatId  1
check game start
joinGame        100031
got selfSeatId  2
got selfSeatId  3
check game start
handCards : M m ♦️2 ♦️A ♣️A ♦️K ♣️K ♠️Q ♥️Q ♣️Q ♠️J ♥️J ♠️T ♣️T ♥️9 ♦️9 ♣️8 ♣️7 ♦️5 ♥️4 ♠️3 
direct    : ♣️A ♣️K ♣️Q ♥️J ♣️T ♦️9 ♣️8 ♣️7 

handCards : ♠️2 ♥️2 ♣️2 ♠️A ♠️K ♦️J ♣️J ♥️T ♠️8 ♥️8 ♥️7 ♦️7 ♠️6 ♥️6 ♣️6 ♠️5 ♦️3 
othercards: ♣️A ♣️K ♣️Q ♥️J ♣️T ♦️9 ♣️8 ♣️7 
follow    : 

handCards : F ♥️A ♥️K ♦️Q ♦️T ♠️9 ♣️9 ♦️8 ♠️7 ♦️6 ♥️5 ♣️5 ♠️4 ♦️4 ♣️4 ♥️3 ♣️3 
othercards: ♣️A ♣️K ♣️Q ♥️J ♣️T ♦️9 ♣️8 ♣️7 
follow    : F ♠️4 ♦️4 ♣️4 

handCards : M m ♦️2 ♦️A ♦️K ♠️Q ♥️Q ♠️J ♠️T ♥️9 ♦️5 ♥️4 ♠️3 
othercards: F ♠️4 ♦️4 ♣️4 
follow    : M m 

handCards : ♦️3 ♠️5 ♣️6 ♥️6 ♠️6 ♦️7 ♥️7 ♥️8 ♠️8 ♥️T ♣️J ♦️J ♠️K ♠️A ♣️2 ♥️2 ♠️2 
othercards: M m 
follow    : 

handCards : ♥️A ♥️K ♦️Q ♦️T ♠️9 ♣️9 ♦️8 ♠️7 ♦️6 ♥️5 ♣️5 ♥️3 ♣️3 
othercards: M m 
follow    : 

handCards : ♦️2 ♦️A ♦️K ♠️Q ♥️Q ♠️J ♠️T ♥️9 ♦️5 ♥️4 ♠️3 
direct    : ♠️3 

handCards : ♦️3 ♠️5 ♣️6 ♥️6 ♠️6 ♦️7 ♥️7 ♥️8 ♠️8 ♥️T ♣️J ♦️J ♠️K ♠️A ♣️2 ♥️2 ♠️2 
othercards: ♠️3 
follow    : ♠️5 

handCards : ♥️A ♥️K ♦️Q ♦️T ♠️9 ♣️9 ♦️8 ♠️7 ♦️6 ♥️5 ♣️5 ♥️3 ♣️3 
othercards: ♠️5 
follow    : ♣️9 

handCards : ♦️2 ♦️A ♦️K ♠️Q ♥️Q ♠️J ♠️T ♥️9 ♦️5 ♥️4 
othercards: ♣️9 
follow    : ♥️Q 

handCards : ♠️2 ♥️2 ♣️2 ♠️A ♠️K ♦️J ♣️J ♥️T ♠️8 ♥️8 ♥️7 ♦️7 ♠️6 ♥️6 ♣️6 ♦️3 
othercards: ♥️Q 
follow    : ♠️K 

handCards : ♥️A ♥️K ♦️Q ♦️T ♠️9 ♦️8 ♠️7 ♦️6 ♥️5 ♣️5 ♥️3 ♣️3 
othercards: ♠️K 
follow    : ♥️A 

handCards : ♦️2 ♦️A ♦️K ♠️Q ♠️J ♠️T ♥️9 ♦️5 ♥️4 
othercards: ♥️A 
follow    : ♦️2 

handCards : ♠️2 ♥️2 ♣️2 ♠️A ♦️J ♣️J ♥️T ♠️8 ♥️8 ♥️7 ♦️7 ♠️6 ♥️6 ♣️6 ♦️3 
othercards: ♦️2 
follow    : 

handCards : ♥️K ♦️Q ♦️T ♠️9 ♦️8 ♠️7 ♦️6 ♥️5 ♣️5 ♥️3 ♣️3 
othercards: ♦️2 
follow    : 

handCards : ♦️A ♦️K ♠️Q ♠️J ♠️T ♥️9 ♦️5 ♥️4 
direct    : ♦️A ♦️K ♠️Q ♠️J ♠️T ♥️9 

handCards : ♦️3 ♣️6 ♥️6 ♠️6 ♦️7 ♥️7 ♥️8 ♠️8 ♥️T ♣️J ♦️J ♠️A ♣️2 ♥️2 ♠️2 
othercards: ♦️A ♦️K ♠️Q ♠️J ♠️T ♥️9 
follow    : 

handCards : ♣️3 ♥️3 ♣️5 ♥️5 ♦️6 ♠️7 ♦️8 ♠️9 ♦️T ♦️Q ♥️K 
othercards: ♦️A ♦️K ♠️Q ♠️J ♠️T ♥️9 
follow    : 

handCards : ♦️5 ♥️4 
direct    : ♥️4 

handCards : ♦️3 ♣️6 ♥️6 ♠️6 ♦️7 ♥️7 ♥️8 ♠️8 ♥️T ♣️J ♦️J ♠️A ♣️2 ♥️2 ♠️2 
othercards: ♥️4 
follow    : ♣️6 

handCards : ♣️3 ♥️3 ♣️5 ♥️5 ♦️6 ♠️7 ♦️8 ♠️9 ♦️T ♦️Q ♥️K 
othercards: ♣️6 
follow    : ♦️Q 

handCards : ♦️5 
othercards: ♦️Q 
follow    : 

handCards : ♠️2 ♥️2 ♣️2 ♠️A ♦️J ♣️J ♥️T ♠️8 ♥️8 ♥️7 ♦️7 ♠️6 ♥️6 ♦️3 
othercards: ♦️Q 
follow    : ♠️A 

handCards : ♥️K ♦️T ♠️9 ♦️8 ♠️7 ♦️6 ♥️5 ♣️5 ♥️3 ♣️3 
othercards: ♠️A 
follow    : 

handCards : ♦️5 
othercards: ♠️A 
follow    : 

handCards : ♠️2 ♥️2 ♣️2 ♦️J ♣️J ♥️T ♠️8 ♥️8 ♥️7 ♦️7 ♠️6 ♥️6 ♦️3 
direct    : ♠️8 ♥️8 ♥️7 ♦️7 ♠️6 ♥️6 

handCards : ♣️3 ♥️3 ♣️5 ♥️5 ♦️6 ♠️7 ♦️8 ♠️9 ♦️T ♥️K 
othercards: ♠️8 ♥️8 ♥️7 ♦️7 ♠️6 ♥️6 
follow    : 

handCards : ♦️5 
othercards: ♠️8 ♥️8 ♥️7 ♦️7 ♠️6 ♥️6 
follow    : 

handCards : ♠️2 ♥️2 ♣️2 ♦️J ♣️J ♥️T ♦️3 
direct    : ♦️3 

handCards : ♣️3 ♥️3 ♣️5 ♥️5 ♦️6 ♠️7 ♦️8 ♠️9 ♦️T ♥️K 
othercards: ♦️3 
follow    : ♣️5 

handCards : ♦️5 
othercards: ♣️5 
follow    : 

handCards : ♠️2 ♥️2 ♣️2 ♦️J ♣️J ♥️T 
othercards: ♣️5 
follow    : ♥️T 

handCards : ♥️K ♦️T ♠️9 ♦️8 ♠️7 ♦️6 ♥️5 ♥️3 ♣️3 
othercards: ♥️T 
follow    : ♥️K 

handCards : ♦️5 
othercards: ♥️K 
follow    : 

handCards : ♠️2 ♥️2 ♣️2 ♦️J ♣️J 
othercards: ♥️K 
follow    : ♣️2 

handCards : ♦️T ♠️9 ♦️8 ♠️7 ♦️6 ♥️5 ♥️3 ♣️3 
othercards: ♣️2 
follow    : 

handCards : ♦️5 
othercards: ♣️2 
follow    : 

handCards : ♠️2 ♥️2 ♦️J ♣️J 
direct    : ♦️J ♣️J 

handCards : ♣️3 ♥️3 ♥️5 ♦️6 ♠️7 ♦️8 ♠️9 ♦️T 
othercards: ♦️J ♣️J 
follow    : 

handCards : ♦️5 
othercards: ♦️J ♣️J 
follow    : 

handCards : ♠️2 ♥️2 
direct    : ♠️2 ♥️2 

got selfSeatId  nil
got selfSeatId  3
```

## 使用惯例

### lua代码中 区分客户端和服务器端

为了方便客户端和服务器端代码的一致性，在客户端代码里，我们实现了skynet库里 skynet.time, skynet.error等函数，但没有实现skynet.init这个函数，因此在客户端和服务器端的通用代码里，我们使用 if skynet.init (是否服务器) 或者 if not skynet.init (是否客户端) 这样的语句判断是否服务器端，是否客户端，在相应语句中执行对应端相关的代码。

