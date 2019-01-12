------------------------------------------------------
---! @file
---! @brief InfoServer的启动文件
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"

local function off_notice (target)
    local packetHelper  = (require "PacketHelper").create("protos/CGGame.pb")
    local protoTypes    = require "ProtoTypes"

    local aclInfo = {
        aclType = protoTypes.CGGAME_ACL_STATUS_NODE_OFF,
    }
    local data = packetHelper:encodeMsg("CGGame.AclInfo", aclInfo)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                        protoTypes.CGGAME_PROTO_SUBTYPE_ACL, data)

    skynet.call(target, "lua", "noticeAll", packet)
end

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

    local srv = skynet.uniqueservice("NodeInfo")
    local kind = skynet.call(srv, "lua", "getConfig", "nodeInfo", "serverKind")

    local target = nil
    if kind == "AgentServer" then
        target = skynet.uniqueservice("WatchDog")
    elseif kind == "HallServer" then
        target = skynet.uniqueservice("HallService")
    else
        print("off_notice should not run in server kind: ", kind)
    end

    if target then
        off_notice(target)
    end

    skynet.sleep(20)

    -- 启动好了，没事做就退出
    skynet.exit()
end)

