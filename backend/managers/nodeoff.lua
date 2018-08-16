------------------------------------------------------
---! @file
---! @brief 通知NodeLink服务退出，
---!        所有监控NodeLink的都可以收到这个信号
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

    ---! 通知NodeInfo, 退出NodeLink
    local NodeInfo = skynet.uniqueservice("NodeInfo")
    skynet.call(NodeInfo, "lua", "nodeOff")

    ---! 启动好了，没事做就退出
    skynet.exit()
end)

