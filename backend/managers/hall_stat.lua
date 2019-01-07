------------------------------------------------------
---! @file
---! @brief InfoServer的启动文件
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"


local function log_hall_stat ()
    local hall = skynet.uniqueservice("HallService")
    skynet.send(hall, "lua", "logStat")
end

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

    local srv = skynet.uniqueservice("NodeInfo")
    local kind = skynet.call(srv, "lua", "getConfig", "nodeInfo", "serverKind")

    if kind == "HallServer" then
        log_hall_stat()
    else
        print("hall_stat should not run in server kind: ", kind)
    end

    skynet.sleep(20)

    -- 启动好了，没事做就退出
    skynet.exit()
end)

