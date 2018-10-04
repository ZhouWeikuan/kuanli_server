------------------------------------------------------------
---! @file
---! @brief hall agents
------------------------------------------------------------

---! core libraries
local skynet        = require "skynet"

---! helpers
local clsHelper     = require "ClusterHelper"
local packetHelper  = (require "PacketHelper").create("protos/CGGame.pb")

---! headers
local protoTypes    = require "ProtoTypes"

---! variables
local botPlayer     = nil
local service       = nil

local agentInfo     = {}
local tickInterval  = 50

---! skynet service handlings
local CMD = {}

---! @brief start service
function CMD.start (botName, uid, TickInterval)
    if botName and botName ~= "" and botPlayer == nil then
        local nodeInfo = skynet.uniqueservice(clsHelper.kNodeInfo)
        local myInfo   = skynet.call(nodeInfo, "lua", "getConfig", "nodeInfo")

        agentInfo.playerId  = uid
        agentInfo.FUniqueID = uid
        agentInfo.FNickName = uid
        agentInfo.client_fd = -skynet.self()
        agentInfo.agent     = skynet.self()
        agentInfo.appName   = myInfo.appName
        agentInfo.agentSign = os.time()

        tickInterval       = TickInterval or tickInterval

        botPlayer = packetHelper.createObject(botName, CMD, agentInfo)
        local ret, code = pcall(skynet.call, service, "lua", "joinGame", agentInfo)
        if ret then
            agentInfo.FUserCode = code
            botPlayer.selfUserCode = code
        end

        skynet.sleep(200)
        local info = {
            roomId = nil,
            seatId = nil,
        }
        local data = packetHelper:encodeMsg("CGGame.SeatInfo", info)
        pcall(skynet.call, service, "lua", "gameData", code, agentInfo.agentSign, protoTypes.CGGAME_PROTO_SUBTYPE_SITDOWN, data)
    end

    return 0
end

function CMD.command_handler (cmd, user, packet)
    local args = packetHelper:decodeMsg("CGGame.ProtoInfo", packet)
    if args then
        local cmd = args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_HALL and "hallData" or "gameData"
        pcall(skynet.call, service, "lua", cmd, agentInfo.FUserCode, agentInfo.agentSign, args.subType, args.msgBody)
    end
end

function CMD.sendProtocolPacket (packet)
    if botPlayer then
        botPlayer:recvPacket(packet)
    end
end

---! @brief 通知agent主动结束
function CMD.disconnect ()
    skynet.exit()
end

---! loop exec botPlayer tick frame
local function loopTick ()
    while true do
        if botPlayer then
            botPlayer:tickFrame(tickInterval * 0.01)
        end

        skynet.sleep(tickInterval)
    end
end

---! @brief hall agent的入口函数
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

    service = skynet.uniqueservice("HallService")
    skynet.fork(loopTick)
end)

