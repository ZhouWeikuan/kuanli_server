local skynet = require "skynet"
local crypt  = require "skynet.crypt"

local protoTypes = require "ProtoTypes"

local strHelper     = require "StringHelper"
local packetHelper  = (require "PacketHelper").create("protos/CGGame.pb")

local PriorityQueue = require "PriorityQueue"
local Queue         = require "Queue"

---! create the class metatable
local class = {mt = {}}
class.mt.__index = class

---! create delegate object
class.create = function (delegate, authInfo, handler)
    local self = {}
    setmetatable(self, class.mt)

    self.delegate   = delegate

    self.authInfo   = authInfo

    self.selfUserCode   = nil
    self.selfSeatId     = nil

    self.tableInfo   = {}
    self.allUsers    = {}
    self:resetTableInfo()

    self.handler = handler or self

    self.recv_list = PriorityQueue.create(function (obj) return obj end, function (obj) return obj.timeout end, "[RECVIDX]")
    self.delay_list = PriorityQueue.create(function (obj) return obj end, function (obj) return obj.timeout end, "[SENDIDX]")
    self.direct_list = Queue.create()

    return self
end

class.resetTableInfo  = function(self)
    self.tableInfo = {}

    --[[
    local SeatArray = require "SeatArray"
    self.tableInfo.standbyUsers = NumSet:create()
    self.tableInfo.playerUsers = SeatArray:create()
    self.tableInfo.playingUsers = SeatArray:create()
    --]]

    self.tableInfo.gameInfo = {}
end

------------------ send & recv ----------------------
class.recvPacket = function (self, packet)
    local obj = {}
    obj.timeout = skynet.time() + (self.handler == self and 0.1 or 0)
    obj.packet  = packet
    self.recv_list:addObject(obj)
end

class.sendPacket = function (self, packet, delay)
    delay = delay or 0

    local obj = {}
    obj.timeout = skynet.time() + delay
    obj.packet  = packet

    if delay <= 0.00001 then
        self.direct_list:pushBack(obj)
        return
    end

    self.delay_list:addObject(obj)
end

class.tickFrame = function (self, dt)
    local now = skynet.time()

    local obj = self.recv_list:top()
    while obj and obj.timeout <= now do
        obj = self.recv_list:pop()

        xpcall(function()
            self:handlePacket(obj.packet)
        end,
        function(err)
            print(err)
            print(debug.traceback())
        end)

        obj = self.recv_list:top()
    end

    obj = self.direct_list:front()
    while obj do
        obj = self.direct_list:popFront()

        xpcall(function()
            self.delegate:command_handler(obj.packet)
        end,
        function(err)
            print(err)
            print(debug.traceback())
        end)

        obj = self.direct_list:front()
    end


    obj = self.delay_list:top()
    while obj and obj.timeout <= now do
        obj = self.delay_list:pop()

        xpcall(function()
            self.delegate:command_handler(obj.packet)
        end,
        function(err)
            print(err)
            print(debug.traceback())
        end)

        obj = self.delay_list:top()
    end
end

--------------------------- send packet options -------------------------
class.sendAuthOptions = function (self, authType)
    local info = self.authInfo
    if authType == protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME then
        local packet = nil
        if strHelper.isNullKey(info.username) or strHelper.isNullKey(info.password)
            or strHelper.isNullKey(info.challenge) or strHelper.isNullKey(info.secret) then
            print("ask for new auth")
            packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_AUTH, authType, nil)
        else
            info.authIndex = info.authIndex or 0
            print("try old auth", info.authIndex)

            local ret = {}
            ret.username    = info.username
            ret.authIndex   = info.authIndex
            local data  = packetHelper:encodeMsg("CGGame.AuthInfo", ret)

            ret.password    = crypt.desencode(info.secret, info.password)
            ret.etoken      = crypt.desencode(info.secret, "token code")
            ret.hmac        = crypt.hmac64(crypt.hashkey(info.challenge .. data), info.secret)
            data   = packetHelper:encodeMsg("CGGame.AuthInfo", ret)

            packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_AUTH, authType, data)
        end
        self:sendPacket(packet)
    elseif authType == protoTypes.CGGAME_PROTO_SUBTYPE_CLIENTKEY then
        info.clientkey = crypt.randomkey()
        local ret = {}
        ret.clientkey = crypt.dhexchange(info.clientkey)
        print("send client key", crypt.hexencode(info.clientkey), "dhexchange", crypt.hexencode(ret.clientkey))
        local data = packetHelper:encodeMsg("CGGame.AuthInfo", ret)
        local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_AUTH, authType, data)
        self:sendPacket(packet)
    elseif authType == protoTypes.CGGAME_PROTO_SUBTYPE_CHALLENGE
        or authType == protoTypes.CGGAME_PROTO_SUBTYPE_SERVERKEY
        or authType == protoTypes.CGGAME_PROTO_SUBTYPE_RESUME_OK then
        print("Cannot send authType", authType, "from client")
    else
        print("Unknown authType ", authType, "from client")
    end
end

--------------------------- packet content handler ----------------------
class.handlePacket = function (self, packet)
    local args = packetHelper:decodeMsg("CGGame.ProtoInfo", packet)

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
        print("uknown main type", args.mainType, args.subType, args.msgBody)
    end
end

class.handle_basic = function (self, args)
	if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_HEARTBEAT then
        local info = packetHelper:decodeMsg("CGGame.HeartBeat", args.msgBody)
        if info.fromType == protoTypes.CGGAME_PROTO_HEARTBEAT_CLIENT then
            local now = skynet.time()
            info.timestamp = info.timestamp or now
            self.authInfo.speed_diff = (now - info.timestamp) * 0.5
            -- print("client speed diff is ", now, info.timestamp, self.authInfo.speed_diff)

        elseif info.fromType == protoTypes.CGGAME_PROTO_HEARTBEAT_SERVER then
            local packet = packetHelper:makeProtoData(args.mainType, args.subType, args.msgBody)
            self:sendPacket(packet)
            -- print("server heartbeat")
        else
            print("unknown heart beat fromType", info.fromType, " timestamp: ", info.timestamp)
        end

    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_AGENTLIST then
        local p = packetHelper:decodeMsg("CGGame.AgentList", args.msgBody)

        local list = {}
        for k, v in ipairs(p.agents or {}) do
            table.insert(list, string.format("%s:%d", v.addr, v.port))
        end
        local str = table.concat(list, ",")
        print("agent list is", str)

        local Settings = require "Settings"
        if Settings then
            Settings.setItem(Settings.keyAgentList, str)
        end

    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_NOTICE then
        self.handler:handleNotice(args.msgBody)

    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ACL then
        self.handler:handleACL(args.msgBody)

    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_MULTIPLE then
        self.multiInfo = self.multiInfo or {}
        local info = packetHelper:decodeMsg("CGGame.MultiBody", args.msgBody)
        self.multiInfo[info.curIndex] = info.msgBody
        if info.curIndex == info.maxIndex then
            local data = table.concat(self.multiInfo, "")
            self.multiInfo = nil
            self:handlePacket(data)
        end

    else
        print("unhandled basic", args.mainType, args.subType, args.msgBody)
    end
end

class.handle_auth = function (self, args)
    local info = packetHelper:decodeMsg("CGGame.AuthInfo", args.msgBody)
    if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_CHALLENGE then
        self.authInfo.authIndex = 0
        self.authInfo.challenge = info.challenge
        print("get challenge", crypt.hexencode(info.challenge))
        self:sendAuthOptions(protoTypes.CGGAME_PROTO_SUBTYPE_CLIENTKEY)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_SERVERKEY then
        print("get serverkey", crypt.hexencode(info.serverkey))
        self.authInfo.serverkey = info.serverkey
        self.authInfo.secret = crypt.dhsecret(info.serverkey, self.authInfo.clientkey)
        print("get secret", crypt.hexencode(self.authInfo.secret))
        self:sendAuthOptions(protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_RESUME_OK then
        local Settings = require "Settings"
        self.authInfo.authIndex = (self.authInfo.authIndex or 0) + 1
        Settings.setItem(Settings.keyAuthIndex, self.authInfo.authIndex)
        Settings.setItem(Settings.base64AuthChallenge, crypt.base64encode(self.authInfo.challenge))
        Settings.setItem(Settings.base64AuthSecret, crypt.base64encode(self.authInfo.secret))
        self.delegate.authOK = true
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME
        or args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_CLIENTKEY then
        print("Client should not receive auth:", args.mainType, args.subType, args.msgBody)
    else
        print("Unknown auth", args.mainType, args.subType, args.msgBody)
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

---------------------------- handler's handle function ------------------
class.handleACL = function (self, data)
    local aclInfo = packetHelper:decodeMsg("CGGame.AclInfo", data)
    print("ACL type:", aclInfo.aclType, "msg:", aclInfo.aclMsg)
end

class.handleNotice = function (self, data)
    local notice = packetHelper:decodeMsg("CGGame.NoticeInfo", data)
    print("Notice type:", notice.noticeType, "text:", notice.noticeText)
end


return class

