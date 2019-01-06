------------------------------------------------------
---! @file
---! @brief MainInfo, 保存所有连接节点信息
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
local cluster   = require "skynet.cluster"

---! 帮助库
local clsHelper    = require "ClusterHelper"
local filterHelper = require "FilterHelper"
local strHelper = require "StringHelper"

---! 全局常量
local nodeInfo = nil
local appName = nil

local servers = {}
local main = {}

---! detect master MainServer
local function do_detectMaster (app, addr)
    if app < appName then
        if main[app] then
            return
        end
        main[app] = addr
        skynet.error("hold the main server", app)
        pcall(cluster.call, app, addr, "LINK", true)
        skynet.error("disconnect the main server", app)
        main[app] = nil
    else
        addr = clsHelper.cluster_addr(app, clsHelper.kMainInfo)
        if addr then
            pcall(cluster.call, app, addr, "holdMain", appName)
        end
    end
end

---! loop in the back to detect master
local function detectMaster ()
    local list = skynet.call(nodeInfo, "lua", "getConfig", clsHelper.kMainServer)
    table.sort(list, function (a, b)
        return a < b
    end)

    for _, app in ipairs(list) do
        if app ~= appName then
            local addr = clsHelper.cluster_addr(app, clsHelper.kNodeLink)
            if addr then
                skynet.fork(function ()
                    do_detectMaster(app, addr)
                end)
            end
        end
    end
end

---! other node comes to register, check if any master
local function checkBreak ()
    for app, _ in pairs(main) do
        if app < appName then
            skynet.error(appName, "find better to break", app)
            skynet.call(nodeInfo, "lua", "nodeOff")
            skynet.sleep(3 * 100)
            skynet.newservice("NodeLink")
            break
        end
    end
end

---! 对方节点断线
local function disconnect_kind_server (kind, name)
    local list = servers[kind] or {}
    local one = list[name]

    --! remove from server kind reference
    list[name] = nil

    --! remove from game id reference
    if one.gameId then
        list = servers[one.gameId] or {}
        list[name] = nil
    end
end

---! 维持与别的节点的联系
local function hold_kind_server (kind, name)
    local addr = clsHelper.cluster_addr(name, clsHelper.kNodeLink)
    if not addr then
        disconnect_kind_server(kind, name)
        return
    end

    skynet.error("hold kind server", kind, name)
    pcall(cluster.call, name, addr, "LINK", true)
    skynet.error("disconnect kind server", kind, name)

    disconnect_kind_server(kind, name)
end


---! lua commands
local CMD = {}

---! hold other master
function CMD.holdMain (otherName)
    if otherName >= appName or main[otherName] then
        return 0
    end

    local addr = clsHelper.cluster_addr(otherName, clsHelper.kNodeLink)
    if not addr then
        return 0
    end

    main[otherName] = addr

    skynet.fork(function ()
        skynet.error("hold the main server", otherName)
        pcall(cluster.call, otherName, addr, "LINK", true)
        skynet.error("disconnect the main server", otherName)
        main[otherName] = nil
    end)

    skynet.fork(checkBreak)

    return 0
end

---! get noticed of my node off
function CMD.nodeOff ()
    servers = {}
end

---! ask all possible nodes to register them
function CMD.askAll ()
    servers = {}

    local all = skynet.call(nodeInfo, "lua", "getConfig", clsHelper.kAgentServer)
    local list = skynet.call(nodeInfo, "lua", "getConfig", clsHelper.kHallServer)
    for _, v in ipairs(list) do
        table.insert(all, v)
    end

    for _, app in ipairs(all) do
        local addr = clsHelper.cluster_addr(app, clsHelper.kNodeLink)
        if addr then
            pcall(cluster.call, app, addr, "askReg")
        end
    end
end

---! get agent list
function CMD.getAgentList ()
    local ret = {}
    ret.agents = {}
    local list = servers[clsHelper.kAgentServer] or {}
    for k, v in pairs(list) do
        local one = {}
        one.name = v.clusterName
        one.addr = v.address
        one.port = v.port
        one.numPlayers = v.numPlayers
        table.insert(ret.agents, one)
    end

    return ret
end

---! get hall list
function CMD.getHallList (uid, args)
    local prevServer = CMD.getAppGameUser(uid, args.gameId)

    args.gameId     = args.gameId or 0
    args.gameMode   = args.gameMode or nil
    args.gameVersion = args.gameVersion or 0

    local arr = {}
    local list = servers[args.gameId]
    if not list then
        skynet.error("HallServer empty")
        return arr
    end

    for _, info in pairs(list) do
        local thumb = {}
        thumb.app   = info.clusterName
        thumb.pri   = info.numPlayers

        if info.numPlayers > info.highPlayers then
            info.busy = true
        elseif info.numPlayers < info.lowPlayers then
            info.busy = nil
        end

        if info.busy then
            thumb.pri = thumb.pri - 1200
        end

        local versionOK = (args.gameVersion <= info.gameVersion and args.gameVersion >= info.lowVersion)
        if args.gameMode ~= nil and (args.gameMode ~= gameMode or not versionOK) then
            thumb.pri = thumb.pri - 1200
        end

        if info.clusterName == prevServer then
            thumb.pri = thumb.pri + 8000
        end

        table.insert(arr, thumb)
    end

    table.sort(arr, function(a, b) return a.pri > b.pri end)
    return arr
end

---! node info to register
function CMD.regNode (node)
    local kind = node.kind
    assert(filterHelper.isElementInArray(kind, {clsHelper.kAgentServer, clsHelper.kHallServer}))

    local list = servers[kind] or {}
    servers[kind] = list

    local one = {}
    one.clusterName   = node.name
    one.address       = node.addr
    one.port          = node.port
    one.numPlayers    = node.numPlayers
    one.lastUpdate    = os.time()

    local config = node.conf
    if config then
        one.gameId         = tonumber(config.GameId) or 0
        one.gameMode       = tonumber(config.GameMode) or 0
        one.gameVersion    = tonumber(config.Version) or 0
        one.lowVersion     = tonumber(config.LowestVersion) or 0
        one.hallName       = config.HallName
        one.lowPlayers     = config.Low
        one.highPlayers    = config.High
    end

    -- add into server kind list
    list[node.name] = one

    if one.gameId then
        -- add into game id list
        list = servers[one.gameId] or {}
        list[node.name] = one
        servers[one.gameId] = list
    end

    skynet.fork(function()
        hold_kind_server(kind, node.name)
    end)
    skynet.fork(checkBreak)

    return 0
end

---! 心跳，更新人数
function CMD.heartBeat (kind, name, num)
    local list = servers[kind] or {}
    local one = list[name]
    if not one then
        return 0
    end
    one.numPlayers = num
end

---! 记住游戏玩家所做的服务节点
local appGameUserDelayTime = 10 * 60
local function get_path_hall_user (uid, gameId)
    return string.format("onlinePlayers.%s.%s", uid, gameId)
end

---! 记录游戏玩家
function CMD.addAppGameUser (uid, gameId, appName)
    local path = get_path_hall_user(uid, gameId)
    local redis = skynet.call(nodeInfo, "lua", "getConfig", clsHelper.kRedisService)
    skynet.call(redis, "lua", "runCmd", "SET", path, appName)
    return skynet.call(redis, "lua", "runCmd", "EXPIRE", path, appGameUserDelayTime)
end

---! 清除游戏玩家
function CMD.delAppGameUser (uid, gameId)
    local path = get_path_hall_user(uid, gameId)
    local redis = skynet.call(nodeInfo, "lua", "getConfig", clsHelper.kRedisService)
    return skynet.call(redis, "lua", "runCmd", "DEL", path)
end

---! 获得游戏玩家所在的节点
function CMD.getAppGameUser (uid, gameId)
    local path = get_path_hall_user(uid, gameId)
    local redis = skynet.call(nodeInfo, "lua", "getConfig", clsHelper.kRedisService)
    return skynet.call(redis, "lua", "runCmd", "GET", path)
end

---! get the server stat
function CMD.getStat ()
    local agentNum, hallNum = 0,0

    local str = nil
    local arr = {}
    table.insert(arr, "\n" .. os.date() .. "\n")
    table.insert(arr, "[Agent List]\n")

    local agentCount = 0
    local list = servers[clsHelper.kAgentServer] or {}
    for _, one in pairs(list) do
        agentCount = agentCount + one.numPlayers
        agentNum = agentNum + 1
        str = string.format("%s\t%s:%d num:%d\n", one.clusterName, one.address, one.port, one.numPlayers)
        table.insert(arr, str)
    end

    local hallCount = 0
    table.insert(arr, "\n[Hall List]\n")
    list = servers[clsHelper.kHallServer] or {}
    table.sort(list, function(a, b)
        return a.clusterName < b.clusterName
    end)
    for _, one in pairs(list) do
        hallCount = hallCount + one.numPlayers
        hallNum = hallNum + 1
        str = string.format("%s\t%s:%d num:%d \t=> [%d, %d]", one.clusterName, one.address, one.port, one.numPlayers, one.lowPlayers, one.highPlayers)
        table.insert(arr, str)
        str = string.format("\t%s id:%s mode:%s version:%s low:%s\n", one.hallName, one.gameId, one.gameMode, one.gameVersion, one.lowVersion or "0")
        table.insert(arr, str)
    end

    str = string.format("\n大厅服务器数目:%d \t客户服务器数目:%d \t登陆人数:%d \t游戏人数:%d\n",
                            hallNum, agentNum, agentCount, hallCount)
    table.insert(arr, str)

    return strHelper.join(arr, "")
end

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

    ---! 注册skynet消息服务
    skynet.dispatch("lua", function(_,_, cmd, ...)
        local f = CMD[cmd]
        if f then
            local ret = f(...)
            if ret then
                skynet.ret(skynet.pack(ret))
            end
        else
            skynet.error("unknown command ", cmd)
        end
    end)

    ---! 获得NodeInfo 服务
    nodeInfo = skynet.uniqueservice(clsHelper.kNodeInfo)

    ---! 注册自己的地址
    skynet.call(nodeInfo, "lua", "updateConfig", skynet.self(), clsHelper.kMainInfo)

    ---! 获得appName
    appName = skynet.call(nodeInfo, "lua", "getConfig", "nodeInfo", "appName")

    ---! ask all nodes to register
    skynet.fork(CMD.askAll)

    ---! run in the back, detect master
    skynet.fork(detectMaster)
end)

