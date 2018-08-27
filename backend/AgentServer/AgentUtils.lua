---------------------------------------------------
---! @file
---! @brief 客户端辅助处理
---------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
local crypt     = require "skynet.crypt"
local cluster   = require "skynet.cluster"

---! 帮助库
local clsHelper     = require "ClusterHelper"
local strHelper     = require "StringHelper"
local packetHelper  = (require "PacketHelper").create("protos/CGGame.pb")

local protoTypes    = require "ProtoTypes"

---! const
local API_LEVEL_NONE = 0
local API_LEVEL_AUTH = 1
local API_LEVEL_HALL = 2
local API_LEVEL_GAME = 3

---! variables
local nodeInfo

---! global functions
local function getAuthValue (username, info)
    local appName, addr  = clsHelper.getMainAppAddr(clsHelper.kDBService)
    if not appName or not addr then
        return
    end

    local path = string.format("auth.%s", username)
    local flg, ret = pcall(cluster.call, appName, addr, "runCmd", "HMGET", path, "challenge", "secret", "authIndex")
    if flg and ret then
        info.challenge  = crypt.base64decode(ret[1] or "")
        info.secret     = crypt.base64decode(ret[2] or "")
        info.authIndex  = (ret[3] or 0) + 0
    end
end

local function setAuthValue (username, info)
    local appName, addr  = clsHelper.getMainAppAddr(clsHelper.kDBService)
    if not appName or not addr then
        return
    end

    local path = string.format("auth.%s", username)
    local flg, ret = pcall(cluster.call, appName, addr, "runCmd", "HMSET", path,
                        "challenge", crypt.base64encode(info.challenge or ""),
                        "secret", crypt.base64encode(info.secret or ""),
                        "authIndex", info.authIndex or 0)
    if flg and ret then
        pcall(cluster.call, appName, addr, "runCmd", "EXPIRE", path, 8 * 60 * 60)
    end
end


---! AgentUtils 模块定义
local class = {mt = {}}
class.mt.__index = class

---! 创建AgentUtils实例
local function create (agentInfo, cmd, callback)
    local self = {}
    setmetatable(self, class.mt)

    self.apiLevel   = API_LEVEL_NONE
    self.authInfo   = {}
    self.agentInfo  = agentInfo
    self.cmd        = cmd
    self.callback   = callback

    nodeInfo = nodeInfo or skynet.uniqueservice("NodeInfo")

    return self
end
class.create = create

---! send options
class.sendHeartBeat = function (self)
    local info = {
        fromType = protoTypes.CGGAME_PROTO_HEARTBEAT_SERVER,
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
        if info.fromType == protoTypes.CGGAME_PROTO_HEARTBEAT_CLIENT then
            local packet = packetHelper:makeProtoData(args.mainType, args.subType, args.msgBody)
            self.cmd.sendProtocolPacket(packet)
            -- skynet.error("client heart beat")

        elseif info.fromType == protoTypes.CGGAME_PROTO_HEARTBEAT_SERVER then
            local now = skynet.time()
            info.timestamp = info.timestamp or now
            self.agentInfo.speed_diff = (now - info.timestamp) * 0.5
            -- skynet.error("server speed diff is ", now, info.timestamp, self.agentInfo.speed_diff)
        else
            skynet.error("unknown heart beat fromType", info.fromType, " timestamp: ", info.timestamp)
        end

    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_AGENTLIST then
        local appName, addr  = clsHelper.getMainAppAddr(clsHelper.kMainInfo)
        if not appName or not addr then
            return
        end

        local flg, ret = pcall(cluster.call, appName, addr, "getAgentList")
        if not flg then
            return
        end

        local data = packetHelper:encodeMsg("CGGame.AgentList", ret)
        local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                            protoTypes.CGGAME_PROTO_SUBTYPE_AGENTLIST, data)
        self.cmd.sendProtocolPacket(packet)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_NOTICE then
        skynet.error("Server should not receive notice:", args.mainType, args.subType, args.msgBody)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ACL then
        skynet.error("Server should not receive ACL:", args.mainType, args.subType, args.msgBody)
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
        skynet.error("Unknown basic", args.mainType, args.subType, args.msgBody)
    end
end

class.sendChallenge = function (self)
    self.authInfo.authIndex = 0
    self.authInfo.challenge = crypt.randomkey()

    local ret = {}
    ret.challenge = self.authInfo.challenge
    print("send challenge", crypt.hexencode(ret.challenge))
    local data = packetHelper:encodeMsg("CGGame.AuthInfo", ret)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_AUTH,
                        protoTypes.CGGAME_PROTO_SUBTYPE_CHALLENGE, data)
    self.cmd.sendProtocolPacket(packet)
end

class.failAuth = function (self, msg)
    local info = {
        aclType = protoTypes.CGGAME_ACL_STATUS_AUTH_FAILED,
        aclMsg  = msg
    }
    local data = packetHelper:encodeMsg("CGGame.AclInfo", info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                        protoTypes.CGGAME_PROTO_SUBTYPE_ACL, data)
    self.cmd.sendProtocolPacket(packet)

    self:sendChallenge()
end

class.checkAuth = function (self, info)
    local auth = self.authInfo
    if not strHelper.isNullKey(info.username) then
        if strHelper.isNullKey(auth.challenge) or strHelper.isNullKey(auth.secret) then
            getAuthValue(info.username, auth)
        end
    end

    if strHelper.isNullKey(auth.challenge) or strHelper.isNullKey(auth.secret) then
        self:sendChallenge()
        return
    end

    info.authIndex = info.authIndex or 0
    if info.authIndex ~= auth.authIndex then
        self:failAuth("Wrong Auth Index: " .. info.authIndex)
        return
    end

    local ret = {}
    ret.username = info.username
    ret.authIndex = auth.authIndex
    local data = packetHelper:encodeMsg("CGGame.AuthInfo", ret)
    ret.hmac   = crypt.hmac64(crypt.hashkey(auth.challenge .. data), auth.secret)
    if ret.hmac ~= info.hmac then
        self:failAuth(string.format("Wrong HMac : %s %s", crypt.hexencode(ret.hmac), crypt.hexencode(info.hmac)))
        return
    end

    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_AUTH,
                        protoTypes.CGGAME_PROTO_SUBTYPE_RESUME_OK, nil)
    self.cmd.sendProtocolPacket(packet)

    ret.password = crypt.desdecode(auth.secret, info.password)
    ret.etoken   = crypt.desdecode(auth.secret, info.etoken)

    auth.authIndex = auth.authIndex + 1
    setAuthValue(info.username, auth)
end

class.handle_auth = function (self, args)
    local info = packetHelper:decodeMsg("CGGame.AuthInfo", args.msgBody)
    if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME then
        if strHelper.isNullKey(info.hmac) or strHelper.isNullKey(info.username)
            or strHelper.isNullKey(info.password) or strHelper.isNullKey(info.etoken) then

            self:sendChallenge()
        else
            -- check hmac & etoken
            self:checkAuth(info)
        end
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_CLIENTKEY then
        self.authInfo.clientkey = info.clientkey
        local key = crypt.randomkey()
        self.authInfo.serverkey = key

        local ret = {}
        ret.serverkey = crypt.dhexchange(key)
        print("send serverkey", crypt.hexencode(key), "exchanged:", crypt.hexencode(ret.serverkey))
        local data = packetHelper:encodeMsg("CGGame.AuthInfo", ret)
        local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_AUTH,
                            protoTypes.CGGAME_PROTO_SUBTYPE_SERVERKEY, data)
        self.cmd.sendProtocolPacket(packet)

        self.authInfo.secret = crypt.dhsecret(self.authInfo.clientkey, key)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_CHALLENGE
        or args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_SERVERKEY
        or args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_RESUME_OK then
        skynet.error("Server should not receive auth:", args.mainType, args.subType, args.msgBody)
    else
        skynet.error("Unknown auth", args.mainType, args.subType, args.msgBody)
    end
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

