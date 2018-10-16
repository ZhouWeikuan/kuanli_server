-------------------------------------------------------------
---! @file  HallService
---! @brief 游戏大厅核心服务
--------------------------------------------------------------

---! 系统库
local skynet = require "skynet"

---! 依赖库
local clsHelper     = require "ClusterHelper"
local packetHelper  = (require "PacketHelper").create("protos/CGGame.pb")

---! hall interface
local hallInterface = nil

local function getValidPlayer(code, sign)
    local player = hallInterface.onlineUsers:getObject(code)
    if not player then
        print("No such user found", code, sign)
        return
    elseif player.FUserCode ~= code or player.agentSign ~= sign then
        print("User info not match", player.FUserCode, code, player.agentSign, sign)
        return
    end
    return player
end

---! 服务接口
local CMD = {}

function CMD.createInterface (conf)
    hallInterface = hallInterface or packetHelper.createObject(conf.Interface, conf)
    return 0
end

function CMD.agentQuit (code, sign)
    local player = getValidPlayer(code, sign)
    hallInterface:agentQuit(player)
    return 0
end

function CMD.joinHall (agentInfo)
    agentInfo.apiLevel = 0
    local userCode = hallInterface:addPlayer(agentInfo)
    hallInterface:SendHallText(userCode)
    return userCode
end

function CMD.hallData (code, sign, hallType, data)
    local player = getValidPlayer(code, sign)
    hallInterface:handleHallData(player, hallType, data)
    return 0
end

function CMD.joinGame (agentInfo)
    agentInfo.apiLevel = 1
    local userCode = hallInterface:addPlayer(agentInfo)
    hallInterface:SendGameText(userCode)
    return userCode
end

function CMD.clubData (code, sign, clubType, data)
    local player = getValidPlayer(code, sign)
    hallInterface:handleClubData(player, clubType, data)
    return 0
end

function CMD.roomData (code, sign, roomType, data)
    local player = getValidPlayer(code, sign)
    hallInterface:handleRoomData(player, roomType, data)
    return 0
end

function CMD.gameData (code, sign, gameType, data)
    local player = getValidPlayer(code, sign)
    hallInterface:handleGameData(player, gameType, data)
    return 0
end

function CMD.logStat ()
    hallInterface:logStat()
    return 0
end

function CMD.nodeOff ()
    print ("TODO: get node off")
    return 0
end

local function game_loop()
    if hallInterface then
        skynet.timeout(hallInterface.tickInterval, game_loop)
        xpcall( function()
            hallInterface:tick(hallInterface.tickInterval/100)
        end,
        function(err)
            skynet.error(err)
            skynet.error(debug.traceback())
        end)
    else
        skynet.timeout(100, game_loop)
    end
end

skynet.start(function()
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

    ---! 获得NodeInfo 服务 注册自己
    local nodeInfo = skynet.uniqueservice(clsHelper.kNodeInfo)
    skynet.call(nodeInfo, "lua", "updateConfig", skynet.self(), clsHelper.kHallService)

    ---! 游戏循环
    skynet.timeout(5, game_loop)
end)

