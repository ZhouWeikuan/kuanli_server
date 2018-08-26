---------------------------------------------------
---! @file
---! @brief 客户端辅助处理
---------------------------------------------------

---! 依赖库
local skynet    = require "skynet"

---! 帮助库
local packetHelper  = (require "PacketHelper").create("protos/CGGame.pb")

local protoTypes    = require "ProtoTypes"

---! AgentUtils 模块定义
local class = {mt = {}}
class.mt.__index = class

---! 创建AgentUtils实例
local function create (agentInfo, cmd, callback)
    local self = {}
    setmetatable(self, class.mt)

    self.authInfo   = {}
    self.agentInfo  = agentInfo
    self.cmd        = cmd
    self.callback   = callback

    return self
end
class.create = create

---! send options
class.sendHeartBeat = function (self)
    local info = {
        fromType = protoTypes.CGGAME_PROTO_HEARTBEAT_FROM_SERVER,
        timestamp = skynet.time()
    }
    local data = packetHelper:encodeMsg("CGGame.HeartBeat", info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                protoTypes.CGGAME_PROTO_SUBTYPE_HEARTBEAT, data)
    self.cmd.sendProtocolPacket(packet)
end

class.reqQuit = function (self, fd)
end

class.kickMe = function (self, fd)
    fd = fd or self.agentInfo.client_fd
    pcall(skynet.send, agentInfo.watchdog, "lua", "closeAgent", fd)
end

---! handle options
class.handle_basic = function (self, args)
    if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_HEARTBEAT then
        local info = packetHelper:decodeMsg("CGGame.HeartBeat", args.msgBody)
        if info.fromType == protoTypes.CGGAME_PROTO_HEARTBEAT_FROM_CLIENT then
            local packet = packetHelper:makeProtoData(args.mainType, args.subType, args.msgBody)
            self.cmd.sendProtocolPacket(packet)
            -- skynet.error("client heart beat")

        elseif info.fromType == protoTypes.CGGAME_PROTO_HEARTBEAT_FROM_SERVER then
            local now = skynet.time()
            info.timestamp = info.timestamp or now
            self.agentInfo.speed_diff = (now - info.timestamp) * 0.5
            skynet.error("server speed diff is ", now, info.timestamp, self.agentInfo.speed_diff)
        else
            skynet.error("unknown heart beat fromType", info.fromType, " timestamp: ", info.timestamp)
        end

    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_AGENTLIST then
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ACL then
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_MULTIPLE then
        self.multiInfo = self.multiInfo or {}
        local info = packetHelper:decodeMsg("CGGame.MultiBody", args.msgBody)
        self.multiInfo[info.curIndex] = info.msgBody
        if info.curIndex == info.maxIndex then
            local data = table.concat(self.multiInfo, "")
            self.multiInfo = nil
            self:command_handler(data)
        end
    else
        skynet.error("unhandled basic", args.mainType, args.subType, args.msgBody)
    end
end

class.handle_auth = function (self, args)
    skynet.error("unhandled auth", args.mainType, args.subType, args.msgBody)
end

class.handle_hall = function (self, args)
    skynet.error("unhandled hall", args.mainType, args.subType, args.msgBody)
end

class.handle_club = function (self, args)
    skynet.error("unhandled club", args.mainType, args.subType, args.msgBody)
end

class.handle_room = function (self, args)
    skynet.error("unhandled room", args.mainType, args.subType, args.msgBody)
end

class.handle_game = function (self, args)
    skynet.error("unhandled game", args.mainType, args.subType, args.msgBody)
end

---! check for input command
class.command_handler = function (self, text)
    local args = packetHelper:decodeMsg("CGGame.ProtoInfo", text)
    args.subType = args.subType or 0
    if args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_BASIC then
        self:handle_basic(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_AUTH then
        self:handle_auth(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_HALL then
        self:handle_hall(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_CLUB then
        self:handle_club(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_ROOM then
        self:handle_room(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_GAME then
        self:handle_game(args)
    else
        skynet.error("Unknown mainType", args.mainType, args.subType, args.msgBody)
    end
end

--[[

----- mist functions -----
local function action_to_watchdog(act, cmd, subcmd, ...)
    local func = skynet[act]
    if not func then
        skynet.error("Action ", act, " not found for skynet")
        return
    end
    local watchdog = skynet.uniqueservice("HallWatchDog")
    return func(watchdog, "lua", cmd, subcmd, ...)
end

---! request handlings
local REQ = {}

REQ.list = function(args)
    local list = helper.snax_call(helper.get_InfoServer(), "NodeService", function(proxy)
        return proxy.req.get_pipe_list()
    end)

    local deltaPort = -200

    list = list or {}
    local servers = {}
    for k,v in pairs(list) do
        local one = {}
        one.name = k
        one.addr = v.address
        one.port = v.port + deltaPort
        one.numPlayers = v.numPlayers

        table.insert(servers, one)
    end

    list = {}
    list.server_list = servers

    local text = packetHelper:encodeMsg("CGGame.InfoList", list)
    return text
end

REQ.hall = function(args)
    local param = packetHelper:decodeMsg("CGGame.GameInfo", args.msgBody)

    local list = helper.snax_call(helper.get_InfoServer(), "NodeService", function(proxy)
        ---! lowVersion is FUserID when request from client for hall list
        return proxy.req.get_hall_list(param)
    end)

    if not list or #list <= 0 then
        list = helper.snax_call(helper.get_InfoServer(), "NodeService", function(proxy)
            ---! lowVersion is FUserID when request from client for hall list
            return proxy.req.get_hall_list(param, true)
        end)
    end

    ---! TODO: check previous playing game to re-connect

    list = list or {}

    local servers = {}
    for _, node in ipairs(list) do
        local one = {}
        one.name        = node.clusterName
        one.addr        = node.address
        one.port        = node.port
        one.numPlayers  = node.numPlayers

        one.gameInfo    = {}
        local info = one.gameInfo
        info.gameId         = node.gameId
        info.gameMode       = node.gameMode
        info.gameVersion    = node.gameVersion
        info.lowVersion     = node.lowVersion
        info.gameName       = node.hallName
        info.numPlayers     = node.numPlayers
        info.maxPlayers     = node.highPlayers

        table.insert(servers, one)
    end

    list = {}
    list.server_list = servers

    return list
end

local function command_handler(text)
    local args = packetHelper:decodeMsg("CGGame.ProtoInfo", text)
    args.subType = args.subType or 0

    local msg = {}
    if args.mainType == protoTypes.CGGAME_PROTO_TYPE_GETLOGINLIST then
        if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_LIST_PIPE then
            msg.mainType = args.mainType
            msg.msgBody = REQ.list(args)
        else
            skynet.error("error traceback: illegal login type", args.subType)
        end
    elseif args.mainType == protoTypes.CGGAME_PROTO_TYPE_GETHALLLIST then
        msg.mainType = args.mainType
        local list = REQ.hall(args)
        if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_LIST_PIPE then
            connect_address(list)
            return
        else
            msg.msgBody = packetHelper:encodeMsg("CGGame.InfoList", list)
        end
    elseif hall_sock then
        if args.mainType == protoTypes.CGGAME_PROTO_TYPE_SETUSERINFO then
            local user = packetHelper:decodeMsg("CGGame.UserInfo", args.msgBody)
            user.FLastIP = from_address
            args.msgBody = packetHelper:encodeMsg("CGGame.UserInfo", user)
            text = packetHelper:encodeMsg("CGGame.ProtoInfo", args)
        end

        local pack = string.pack(">s2", text)
        socket.write(hall_sock, pack)

        return
    else
        skynet.error("error traceback: ignore Unhandled proto type: ", args.mainType, " subType: ", args.subType, " data: ", args.msgBody)
        return
    end

    local buf = packetHelper:encodeMsg("CGGame.ProtoInfo", msg);
    socket.write(client_sock, string.pack(">s2", buf))
end


REQ.join = function (args, reqTableId)
    if not service then
        skynet.error("HallService not found")
        return
    end

    local user = protobuf.decode("CGGame.UserInfo", args.msgBody)
    userInfo.FUniqueID = user.FUniqueID
    userInfo.FNickName = user.FNickName
    userInfo.FOSType   = user.FOSType

    userInfo.reqTableId  = reqTableId

    service.post.join_agent(userInfo.client_fd, userInfo)
end

REQ.game = function (args)
    service.post.game_data(userInfo.client_fd, args)
end

REQ.main_data = function (args)
    local uid, acl = service.req.main_data(args)

    if type(acl) == 'number' then
        local msg = {}
        msg.mainType = protoTypes.CGGAME_PROTO_TYPE_ACL;
        msg.subType  = acl

        local packet = protobuf.encode("CGGame.ProtoInfo", msg);
        CMD.sendProtocolPacket (packet)
        return uid
    elseif acl then
        CMD.sendProtocolPacket (acl)
        return uid
    elseif uid == "" then
        local msg = {}
        msg.mainType = protoTypes.CGGAME_PROTO_TYPE_ACL;
        msg.subType  = protoTypes.CGGAME_ACL_STATUS_INVALID_INFO;

        local packet = protobuf.encode("CGGame.ProtoInfo", msg);
        CMD.sendProtocolPacket (packet)
        return uid
    end

    local list = service.req.get_user_info_packets(uid)
    for _, packet in ipairs(list) do
        CMD.sendProtocolPacket (packet)
    end
    return uid
end

REQ.room_data = function (args)
    local acl, packet = service.req.main_data(args)
    if packet then
        CMD.sendProtocolPacket (packet)
    end
    return acl
end

REQ.notice = function (args)
    local chatMsg = protobuf.decode("CGGame.ChatInfo", args.msgBody)
    if chatMsg then
        if not userInfo.FNickName then
            userInfo.FNickName = service.req.get_userInfo(userInfo.FUniqueID, "FNickName")
        end
        chatMsg.speakerNick = userInfo.FNickName
        local data = protobuf.encode("CGGame.ChatInfo", chatMsg)
        chatMsg = {}
        chatMsg.msgBody = data
        chatMsg.mainType = protoTypes.CGGAME_PROTO_TYPE_NOTICE

        data = protobuf.encode("CGGame.ProtoInfo", chatMsg)
        action_to_watchdog("send", "notice", data)
    end
end

REQ.quit = function (args)
    service.post.quit_agent(userInfo.client_fd)
end

local function command_handler(text)
    local args = protobuf.decode("CGGame.ProtoInfo", text)

    local msg = {}
    if args.mainType == protoTypes.CGGAME_PROTO_TYPE_JOINGAME   then
        REQ.join(args, args.subType)
        msg.mainType = args.mainType
    elseif args.mainType == protoTypes.CGGAME_PROTO_TYPE_QUITGAME then
        REQ.quit(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_TYPE_SUBMIT_GAMEDATA then
        REQ.game(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_TYPE_NOTICE then
        REQ.notice(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_TYPE_HEARTBEAT then
    elseif args.mainType == protoTypes.CGGAME_PROTO_TYPE_BUYCHIP or args.mainType == protoTypes.CGGAME_PROTO_TYPE_BUYSCORE then
        if REQ.main_data(args) ~= "" then
            msg = args
        end
    elseif args.mainType == protoTypes.CGGAME_PROTO_TYPE_SETUSERINFO or
        args.mainType == protoTypes.CGGAME_PROTO_TYPE_SETUSERSTATUS or
        args.mainType == protoTypes.CGGAME_PROTO_TYPE_SETLOCATION then
        REQ.main_data(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_TYPE_DAILYBONUS or
            args.mainType == protoTypes.CGGAME_PROTO_TYPE_BONUS then
        REQ.main_data(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_TYPE_ROOMDATA then
        msg.mainType = protoTypes.CGGAME_PROTO_TYPE_ACL;
        msg.subType  = REQ.room_data(args)
    else
        skynet.error("Unhandled proto type: ", args.mainType, " subType: ", args.subType, " data: ", args.msgBody)
        msg.mainType = protoTypes.CGGAME_PROTO_TYPE_ACL;
        msg.subType  = protoTypes.CGGAME_ACL_STATUS_INVALID_INFO;
    end

    if msg.mainType ~= nil then
        local packet = protobuf.encode("CGGame.ProtoInfo", msg);
        CMD.sendProtocolPacket (packet)
    end
end
--]]

return class

