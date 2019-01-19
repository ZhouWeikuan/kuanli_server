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

---! variables
local nodeInfo

---! global functions
local function remoteGetAuthValue (playerId, info)
    local appName, addr = clsHelper.getMainAppAddr(clsHelper.kDBService)
    if not appName or not addr then
        return
    end

    local path = string.format("auth.%s", playerId)
    local flg, ret = pcall(cluster.call, appName, addr, "runCmd", "HMGET", path, "challenge", "secret", "authIndex")
    if flg and ret then
        info.challenge  = crypt.base64decode(ret[1] or "")
        info.secret     = crypt.base64decode(ret[2] or "")
        info.authIndex  = (ret[3] or 0) + 0
    end
end

local function remoteSetAuthValue (playerId, info)
    local appName, addr = clsHelper.getMainAppAddr(clsHelper.kDBService)
    if not appName or not addr then
        return
    end

    local path = string.format("auth.%s", playerId)
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

---! const
class.API_LEVEL_NONE = 0
class.API_LEVEL_AUTH = 1
class.API_LEVEL_HALL = 2
class.API_LEVEL_GAME = 3

---! 创建AgentUtils实例
local function create (agentInfo, cmd, callback)
    local self = {}
    setmetatable(self, class.mt)

    self.apiLevel   = class.API_LEVEL_NONE
    self.connApp    = nil
    self.connAddr   = nil

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

class.sendACL = function(self, aclType)
    local aclInfo = {
        aclType = aclType,
    }
    local data = packetHelper:encodeMsg("CGGame.AclInfo", aclInfo)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                        protoTypes.CGGAME_PROTO_SUBTYPE_ACL, data)
    self.cmd.sendProtocolPacket(packet)
end

---! close the agent
class.kickMe = function (self, fd)
    fd = fd or self.agentInfo.client_fd
    print("kick me", fd)
    pcall(skynet.send, self.agentInfo.watchdog, "lua", "closeAgent", fd)
end

---! handle basic protocols, heart beat
class.basicHeartBeat = function (self, args)
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
end

---! handle basic protocols, get agent list
class.basicAgentList = function (self, args)
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
end

---! handle basic protocols, multiple packets
class.basicMultiple = function (self, args)
    self.multiInfo = self.multiInfo or {}
    local info = packetHelper:decodeMsg("CGGame.MultiBody", args.msgBody)
    self.multiInfo[info.curIndex] = info.msgBody
    if info.curIndex == info.maxIndex then
        local data = table.concat(self.multiInfo, "")
        self.multiInfo = nil
        self:command_handler(data)
    end
end

---! handle basic options
class.handle_basic = function (self, args)
    if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_HEARTBEAT then
        self:basicHeartBeat(args)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_AGENTLIST then
        self:basicAgentList(args)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_NOTICE then
        skynet.error("Server should not receive notice:", args.mainType, args.subType, args.msgBody)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ACL then
        skynet.error("Server should not receive ACL:", args.mainType, args.subType, args.msgBody)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_MULTIPLE then
        self:basicMultiple(args)
    else
        skynet.error("Unknown basic", args.mainType, args.subType, args.msgBody)
    end
end

---! handle auth protocol, send auth challenge
class.authSendChallenge = function (self)
    self.authInfo.authIndex = 0
    self.authInfo.challenge = crypt.randomkey()

    local ret = {}
    ret.challenge = self.authInfo.challenge
    local data = packetHelper:encodeMsg("CGGame.AuthInfo", ret)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_AUTH,
                        protoTypes.CGGAME_PROTO_SUBTYPE_CHALLENGE, data)
    self.cmd.sendProtocolPacket(packet)
end

---! send auth fail acl, and then challenge
class.authSendFail = function (self, msg)
    local info = {
        aclType = protoTypes.CGGAME_ACL_STATUS_AUTH_FAILED,
        aclMsg  = msg
    }
    local data = packetHelper:encodeMsg("CGGame.AclInfo", info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                        protoTypes.CGGAME_PROTO_SUBTYPE_ACL, data)
    self.cmd.sendProtocolPacket(packet)

    self:authSendChallenge()
end

---! check hmac with our secret and index
class.authCheckHmac = function (self, info)
    local auth = self.authInfo

    local ret = {}
    ret.playerId  = info.playerId
    ret.authIndex = math.floor(auth.authIndex + 0.01)
    local data = ret.playerId .. ";" .. ret.authIndex
    ret.hmac   = crypt.hmac64(crypt.hashkey(auth.challenge .. data), auth.secret)
    if ret.hmac ~= info.hmac then
        self:authSendFail(string.format("Wrong HMac : %s %s", crypt.hexencode(ret.hmac), crypt.hexencode(info.hmac)))
        return false
    end
    return true
end

---! handle auth protocol, check etoken, return the result
class.authCheckToken = function (self, info)
    local auth = self.authInfo
    self.apiLevel = class.API_LEVEL_AUTH
    local userInfo = self.agentInfo
    userInfo.FUniqueID = info.playerId
    userInfo.FPassword = crypt.desdecode(auth.secret, info.password)
    userInfo.etoken   = crypt.desdecode(auth.secret, info.etoken)

    userInfo.FLastIP = self.agentInfo.address
    -- userInfo.FOSType =

    return true
end

---! handle auth protocol, check incoming variables
class.authCheckInput = function (self, info)
    local auth = self.authInfo
    if not strHelper.isNullKey(info.playerId) then
        if strHelper.isNullKey(auth.challenge) or strHelper.isNullKey(auth.secret) then
            remoteGetAuthValue(info.playerId, auth)
        end
    end

    if strHelper.isNullKey(auth.challenge) or strHelper.isNullKey(auth.secret) then
        self:authSendChallenge()
        return
    end

    info.authIndex = info.authIndex or 0
    if info.authIndex ~= auth.authIndex then
        self:authSendFail("Wrong Auth Index: " .. info.authIndex)
        return
    end

    if not self:authCheckHmac(info) or not self:authCheckToken(info) then
        return
    end

    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_AUTH,
                        protoTypes.CGGAME_PROTO_SUBTYPE_RESUME_OK, nil)
    self.cmd.sendProtocolPacket(packet)

    auth.authIndex = auth.authIndex + 1
    remoteSetAuthValue(info.playerId, auth)
end

---! handle auth protocol, send challenge for new auth, or ask resume for existing auth
class.authAskResume = function (self, info)
    if strHelper.isNullKey(info.hmac) or strHelper.isNullKey(info.playerId)
        or strHelper.isNullKey(info.password) or strHelper.isNullKey(info.etoken) then

        self:authSendChallenge()
    else
        -- check hmac & etoken
        self:authCheckInput(info)
    end
end

---! handle auth protocol, recv exchanged client key, send exchanged server key
class.authExchangeKeys = function (self, info)
    self.authInfo.clientkey = info.clientkey
    local key = crypt.randomkey()
    self.authInfo.serverkey = key

    local ret = {}
    ret.serverkey = crypt.dhexchange(key)
    local data = packetHelper:encodeMsg("CGGame.AuthInfo", ret)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_AUTH,
                        protoTypes.CGGAME_PROTO_SUBTYPE_SERVERKEY, data)
    self.cmd.sendProtocolPacket(packet)

    self.authInfo.secret = crypt.dhsecret(self.authInfo.clientkey, key)
end

---! handle auth protocols
class.handle_auth = function (self, args)
    local info = packetHelper:decodeMsg("CGGame.AuthInfo", args.msgBody)
    if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME then
        self:authAskResume(info)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_CLIENTKEY then
        self:authExchangeKeys(info)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_CHALLENGE
        or args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_SERVERKEY
        or args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_RESUME_OK then
        skynet.error("Server should not receive auth:", args.mainType, args.subType, args.msgBody)
    else
        skynet.error("Unknown auth", args.mainType, args.subType, args.msgBody)
    end
end

---! request to exit hall or game
class.hallReqQuit = function (self, data)
    if not self.connApp or not self.connAddr then
        return
    end
    local flg, ret = pcall(cluster.call, self.connApp, self.connAddr, "agentQuit",
                            self.agentInfo.FUserCode, self.agentInfo.agentSign)
    if not flg or not ret then
        self:kickMe()
    end
end

class.sendJoinInfo = function (self, mainType, joinType)
    local info = {}
    info.appName = self.connApp
    info.FUserCode = self.agentInfo.FUserCode
    local data = packetHelper:encodeMsg("CGGame.HallInfo", info)
    local packet = packetHelper:makeProtoData(mainType, joinType, data)
    self.cmd.sendProtocolPacket(packet)
end

class.handleJoin = function (self, cmd, data)
    if self.connApp and self.connAddr then
        print("already conn to remote HallService", self.connApp, self.connAddr)
        return
    end

    local app, addr = clsHelper.getMainAppAddr(clsHelper.kMainInfo)
    if not app or not addr then
        return
    end

    local info = packetHelper:decodeMsg("CGGame.HallInfo", data)
    local flg, all = pcall(cluster.call, app, addr, "getHallList", self.agentInfo.FUniqueID, info)
    if not flg or #all <= 0 then
        return
    end

    app = all[1].app
    addr = clsHelper.cluster_addr(app, clsHelper.kHallService)
    if not addr then
        return
    end

    local flg, ret = pcall(cluster.call, app, addr, cmd, self.agentInfo)
    if not flg or not ret then
        print("failed to ", cmd, app, addr)
        return
    end

    self.connApp = app
    self.connAddr = addr
    self.agentInfo.FUserCode = ret
    return true
end

---! request to join hall
class.hallReqJoin = function (self, data)
    if not self:handleJoin("joinHall", data) then
        self:sendACL(protoTypes.CGGAME_ACL_STATUS_SERVER_BUSY)
        return
    end

    self.apiLevel = class.API_LEVEL_HALL
    self:sendJoinInfo(protoTypes.CGGAME_PROTO_MAINTYPE_HALL, protoTypes.CGGAME_PROTO_SUBTYPE_HALLJOIN)
end

---! request to set user info
class.hallRemoteData = function (self, subType, data)
    if not self.connApp or not self.connAddr then
        return
    end
    local flg, ret = pcall(cluster.call, self.connApp, self.connAddr, "hallData",
                        self.agentInfo.FUserCode, self.agentInfo.agentSign, subType, data)
    if not flg or not ret then
        self:kickMe()
    end
end

---! hall related
class.handle_hall = function (self, args)
    if self.apiLevel < class.API_LEVEL_AUTH then
        skynet.error("recv hall data in apiLevel", self.apiLevel, args.mainType, args.subType, args.msgBody)
        return
    end

    if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_QUIT then
        self:hallReqQuit(args.msgBody)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_HALLJOIN then
        self:hallReqJoin(args.msgBody)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_MYINFO
        or args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_MYSTATUS
        or args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_USERINFO
        or args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_USERSTATUS
        or args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_BONUS
        or args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_CHAT then
        self:hallRemoteData(args.subType, args.msgBody)
    else
        skynet.error("unhandled hall", args.mainType, args.subType, args.msgBody)
    end
end

---! club related
class.handle_club = function (self, args)
    if self.apiLevel < class.API_LEVEL_AUTH then
        skynet.error("recv club data in apiLevel", self.apiLevel, args.mainType, args.subType, args.msgBody)
        return
    end

    if not self.connApp or not self.connAddr then
        return
    end
    local flg, ret = pcall(cluster.call, self.connApp, self.connAddr, "clubData",
                        self.agentInfo.FUserCode, self.agentInfo.agentSign, args.subType, args.msgBody)
    print("club remote data returns", flg, ret)
    if not flg or not ret then
        self:kickMe()
    end

    skynet.error("unhandled club", args.mainType, args.subType, args.msgBody)
end

---! room related
class.handle_room = function (self, args)
    if self.apiLevel < class.API_LEVEL_AUTH then
        skynet.error("recv room data in apiLevel", self.apiLevel, args.mainType, args.subType, args.msgBody)
        return
    end

    if not self.connApp or not self.connAddr then
        return
    end
    local flg, ret = pcall(cluster.call, self.connApp, self.connAddr, "roomData",
                        self.agentInfo.FUserCode, self.agentInfo.agentSign, args.subType, args.msgBody)
    if not flg or not ret then
        self:kickMe()
    end
end

---! request to join hall
class.gameReqJoin = function (self, data)
    if not self:handleJoin("joinGame", data) then
        self:sendACL(protoTypes.CGGAME_ACL_STATUS_SERVER_BUSY)
        return
    end

    self.apiLevel = class.API_LEVEL_GAME
    self:sendJoinInfo(protoTypes.CGGAME_PROTO_MAINTYPE_GAME, protoTypes.CGGAME_PROTO_SUBTYPE_GAMEJOIN)
end

---! request to set user info
class.gameRemoteData = function (self, subType, data)
    if not self.connApp or not self.connAddr then
        return
    end
    local flg, ret = pcall(cluster.call, self.connApp, self.connAddr, "gameData",
                        self.agentInfo.FUserCode, self.agentInfo.agentSign, subType, data)
    if not flg or not ret then
        self:kickMe()
    end
end

---! game related
class.handle_game = function (self, args)
    if self.apiLevel < class.API_LEVEL_AUTH then
        skynet.error("recv game data in apiLevel", self.apiLevel, args.mainType, args.subType, args.msgBody)
        return
    end

    if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_GAMEJOIN then
        self:gameReqJoin(args.msgBody)
    elseif args.subType <= protoTypes.CGGAME_PROTO_SUBTYPE_QUITSTAGE then
        self:gameRemoteData(args.subType, args.msgBody)
    elseif args.subType >= protoTypes.CGGAME_PROTO_SUBTYPE_USER_DEFINE then
        self:gameRemoteData(args.subType, args.msgBody)
    else
        skynet.error("unhandled game", args.mainType, args.subType, args.msgBody)
    end
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
    elseif args.mainType == protoTypes.CGGAME_PROTO_TYPE_DAILYBONUS
            or args.mainType == protoTypes.CGGAME_PROTO_TYPE_BONUS then
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

