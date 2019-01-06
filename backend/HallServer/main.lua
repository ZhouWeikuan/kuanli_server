------------------------------------------
----! @file
----! @brief start service for HallServer
----! @author Zhou Weikuan hr@cronlygames.com
------------------------------------------

---! core functions like skynet, skymgr, cluster
local skynet    = require "skynet"
local cluster   = require "skynet.cluster"

---! helper class
local packetHelper  = require "PacketHelper"
local clsHelper     = require "ClusterHelper"

local function addBotAgents (config)
    local num = 53
    local players = {}
    for i=1,num do
        players[i] = i
    end
    for i=1,num do
        local t = math.random(1, num)
        players[i], players[t] = players[t], players[i]
    end

    skynet.sleep(100)
    local bn = config.BotNum or 0
    for i=1, bn do
        skynet.sleep(30)
        local bot = skynet.newservice("BotAgent")
        local uid = string.format("uid%05d", 1000 + players[i])
        skynet.call(bot, "lua", "start", config.BotName, uid, config.TickInterval)
    end
    print("load ", bn, "client bots")
end

--! @brief start services
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

    ---! 启动NodeInfo
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

    ---! 游戏配置读取
    ---! Hall config
    local conf = skynet.getenv("HallConfig")
    skynet.error("conf is ", conf)

    ---! 启动 HallService 服务
    local hall = skynet.uniqueservice("HallService")

    ---! 本房间的配置
    if conf then
        local config = packetHelper.load_config(conf)
        skynet.call(srv, "lua", "updateConfig", config, clsHelper.kHallConfig)
        skynet.call(hall, "lua", "createInterface", config)
        skynet.fork(function ()
            addBotAgents(config)
        end)
    end

    ---! 启动 NodeLink 服务
    skynet.newservice("NodeLink")

    ---! 没事啦 休息去吧
    skynet.sleep(100 * 100)
    skynet.exit()
end)

