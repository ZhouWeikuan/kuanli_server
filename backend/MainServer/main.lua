------------------------------------------------------
---! @file
---! @brief MainServer的启动文件
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
local cluster   = require "skynet.cluster"

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

    local srv = skynet.uniqueservice("NodeInfo")
    skynet.call(srv, "lua", "initNode")

    ---! 启动debug_console服务
    local port = skynet.call(srv, "lua", "getConfig", "nodeInfo", "debugPort")
    assert(port >= 0)
    print("debug port is", port)
    skynet.newservice("debug_console", port)

    ---! 集群处理
    local list = skynet.call(srv, "lua", "getConfig", "clusterList")
    list["__nowaiting"] = true
    cluster.reload(list)

    local appName = skynet.call(srv, "lua", "getConfig", "nodeInfo", "appName")
    cluster.open(appName)

    ---! 启动 info :d 节点状态信息 服务
    skynet.uniqueservice("NodeStat")

    ---! 启动 NodeLink 服务
    skynet.newservice("NodeLink")

    ---! 启动 MainInfo 服务
    skynet.uniqueservice("MainInfo")

    ---! 启动用户信息的数据库服务
    skynet.newservice("DBService")


    ---! 完成初始化，退出本服务
    skynet.exit()
end)

