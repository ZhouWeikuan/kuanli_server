------------------------------------------------------------
---! @file
---! @brief hall agents
------------------------------------------------------------

---! core libraries
local skynet        = require "skynet"

---! helpers
local packetHelper  = (require "PacketHelper").create("protos/CGGame.pb")

---! variables
local botPlayer     = nil
local service       = nil

local agentInfo      = {}
local tickInterval  = 50

---! skynet service handlings
local CMD = {}

---! @brief start service
function CMD.start (botName, uid, TickInterval)
    if botName and botName ~= "" and botPlayer == nil then
        print ("Bot Name is ", botName)
        --[[
        botPlayer = packetHelper.createObject(botName, CMD, uid)

        agentInfo.FUniqueID = uid
        agentInfo.FNickName = uid
        agentInfo.client_fd = -skynet.self()
        agentInfo.agent     = skynet.self()

        tickInterval       = TickInterval or tickInterval


        pcall(skynet.call, service, "lua", JoinAgent, agentInfo.client_fd, agentInfo)
        --]]
        print("join agent")
    end

    return 0
end

function CMD.command_handler (cmd, user, packet)
    local args = packetHelper:decodeMsg("CGGame.ProtoInfo", packet)
    pcall(skynet.call, service, "lua", GameData, agentInfo.client_fd, args)
end

function CMD.sendProtocolPacket (packet)
    print("botAgent send protocol packet")
    if botPlayer then
        botPlayer:recvPacket(packet)
    end
end

---! @brief 通知agent主动结束
function CMD.disconnect ()
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

