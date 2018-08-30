---! 系统库
local cluster   = require "skynet.cluster"

---! 依赖库
local NumSet = require "NumSet"

local protoTypes    = require "ProtoTypes"

local packetHelper  = require "PacketHelper"

---! HallInterface
local class = {mt = {}}
class.mt.__index = class

---! creator
class.create = function (conf)
    local self = {}
    setmetatable(self, class.mt)
    self.config = conf

    --- self.onlineUser 存放用户信息，可以通过getObject()获得其中的用户信息data【uid】
    self.onlineUsers = NumSet.create()

    self.tickInterval = conf.TickInterval or 20

    return self
end

class.tick = function (self, dt)
    -- print("game tick frame")
end

class.addPlayer = function (self, player)
    local old = self.onlineUsers:getObject(player.FUniqueID)
    if old then
        if old.agentSign == player.agentSign and old.agent == player.agent and old.appName == player.appName then
            print("old api level", old.apiLevel, "new api level", player.apiLevel)
        else
            self:removePlayer(old)
        end
    end
    self.onlineUsers:addObject(player, player.FUniqueID)

    local debugHelper = require "DebugHelper"
    debugHelper.cclog("add player", player)
    debugHelper.printDeepTable(player)
end

class.removePlayer = function (self, player)
    self.onlineUsers:removeObject(player, player.FUniqueID)
end

class.agentQuit = function (self, uid, sign)
    local player = self.onlineUsers:getObject(uid)
    if not player then
        print("No such user found", uid, sign)
        return
    elseif player.FUniqueID ~= uid or player.agentSign ~= sign then
        print("User info not match", player.FUniqueID, uid, player.agentSign, sign)
        return
    end
    self:removePlayer(player)
end

class.handleHallData = function (self, uid, sign, hallType, data)
    local player = self.onlineUsers:getObject(uid)
    if not player then
        print("No such user found", uid, sign)
        return
    elseif player.FUniqueID ~= uid or player.agentSign ~= sign then
        print("User info not match", player.FUniqueID, uid, player.agentSign, sign)
        return
    end

    print("handle hall data", uid, sign, hallType, data)
    local info = {}
    info.FUniqueID  = player.FUniqueID
    info.FLastIP    = player.FLastIP
    info.FOSType    = player.FOSType
    local data = packetHelper:encodeMsg("CGGame.UserInfo", info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                        protoTypes.CGGAME_PROTO_SUBTYPE_USERINFO, data)
    print("cluster.send to", player.appName, player.agent)
    local flg = pcall(cluster.send, player.appName, player.agent,
                        "sendProtocolPacket", packet, "another args")
    if not flg then
        self:removePlayer(player)
    end
    print("returns", flg)
end

class.handleGameData = function (self, uid, sign, hallType, data)
    local player = self.onlineUsers:getObject(uid)
    if not player then
        print("No such user found", uid, sign)
        return
    elseif player.FUniqueID ~= uid or player.agentSign ~= sign then
        print("User info not match", player.FUniqueID, uid, player.agentSign, sign)
        return
    end

    print("handle game data", uid, sign, hallType, data)
end

class.logStat = function (self)
    print (string.format("online player: %d\n", self.onlineUsers:getCount()))
end


return class

