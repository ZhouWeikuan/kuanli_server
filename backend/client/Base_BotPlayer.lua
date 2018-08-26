local skynet = require "skynet"

local protoTypes = require("ProtoTypes")

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
        if info.fromType == protoTypes.CGGAME_PROTO_HEARTBEAT_FROM_CLIENT then
            local now = skynet.time()
            info.timestamp = info.timestamp or now
            self.authInfo.speed_diff = (now - info.timestamp) * 0.5
            -- print("client speed diff is ", now, info.timestamp, self.authInfo.speed_diff)

        elseif info.fromType == protoTypes.CGGAME_PROTO_HEARTBEAT_FROM_SERVER then
            local packet = packetHelper:makeProtoData(args.mainType, args.subType, args.msgBody)
            self:sendPacket(packet)
            -- print("server heartbeat")
        else
            print("unknown heart beat fromType", info.fromType, " timestamp: ", info.timestamp)
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
            self:handlePacket(data)
        end
    else
        skynet.error("unhandled basic", args.mainType, args.subType, args.msgBody)
    end
end

class.handle_auth = function (self, msg)
end

class.handle_hall = function (self, msg)
end

class.handle_club = function (self, msg)
end

class.handle_room = function (self, msg)
end

class.handle_game = function (self, msg)
end


return class

