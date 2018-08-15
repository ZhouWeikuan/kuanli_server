------------------------------------------------------
---! @file
---! @brief MainServer的启动文件
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

    local srv = skynet.uniqueservice("NodeInfo")
    skynet.call(srv, "lua", "initNode")

    ---! 启动console服务
    skynet.newservice("console")

    ---! 启动 info :d 节点状态信息 服务
    skynet.uniqueservice("NodeStat")

    ---! 启动debug_console服务
    local port = skynet.call(srv, "lua", "getConfig", "server", "debugPort")
    assert(port >= 0)
    print("debug port is", port)
    skynet.newservice("debug_console", port)

    ---! 完成初始化，退出本服务
    skynet.exit()
end)
