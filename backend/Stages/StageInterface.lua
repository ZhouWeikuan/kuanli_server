local skynet        = skynet or require "skynet"
-- use skynet.init to determine server or client

local protoTypes    = require "ProtoTypes"

local debugHelper   = require "DebugHelper"
local packetHelper  = require "PacketHelper"

local baseClass     = require "HallInterface"

local math = math

local class = {mt = {}}
class.mt.__index = class

setmetatable(class, baseClass.mt)

---!@brief 创建StageInterface的对象
---!@param conf        游戏配置文件
---!@return slef       返回创建的StageInterface
class.create = function (conf)
    local self = baseClass.create(conf)
    setmetatable(self, class.mt)

    xpcall(function()
        local GameStage = require(conf.GameStage)
        local server = GameStage.create(self, conf)
        self.stage   = server

        server:start()
    end, function (err)
        print(err)
        print(debug.traceback())
    end)

    return self
end

---！@brief  TODO
---! @param
---! @return
class.tick = function(self, dt)
    self:executeEvents()

    local server = self.stage
    server:mainLoop(dt)
end

---！@brief StageInterface中的默认消息
---! @param player        用户的数据
---! @param gameType      游戏类型
---！@param data          TODO
class.handleGameData = function (self, player, gameType, data)
    local user = player and self:getUserInfo(player.FUserCode)
    if user then
        player = user
    end

    if gameType == protoTypes.CGGAME_PROTO_SUBTYPE_QUITSTAGE  then
        self:QuitStage(player)
    elseif gameType == protoTypes.CGGAME_PROTO_SUBTYPE_READY  then
        self:PlayerReady(player)
    elseif gameType == protoTypes.CGGAME_PROTO_SUBTYPE_GIFT then
        self:SendUserGift(player.FUserCode, data)
    elseif player.playerTracker then
        self.stage:handleGameData(player, gameType, data)
    else
        debugHelper.cclog("unknown handleGameData %s", tostring(gameType))
    end
end


---! 收集用户信息 self.config.DBTableName
class.CollectUserStatus = function (self, user)
    local info = {}
    info.FUserCode  = user.FUserCode
    info.status     = user.status
    if user.is_offline then
        info.status = protoTypes.CGGAME_USER_STATUS_OFFLINE
    end

    local gameStage = require(self.config.GameStage)
    for k, f in ipairs(gameStage.UserStatus_Fields or {}) do
        info[f] = user[f]
    end

    local data   = packetHelper:encodeMsg(gameStage.UserStatus_ProtoName, info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                        protoTypes.CGGAME_PROTO_SUBTYPE_USERSTATUS, data)
    return packet
end

---! @brief 发送用户包
class.SendUserPacket = function (self, fromCode, packet, sendFunc)
    self.onlineUsers:forEach(function(user)
        sendFunc(self, packet, user.FUserCode)
    end)
end

---! @brief 玩家准备
---! @param player      玩家的游戏数据
---! @rerurn true   玩家已经成功的ready
---! @rerurn nil
class.PlayerReady = function(self, player)
end

---! @brief 玩家离开桌子但是还在房间里
---! @param palyer         玩家的数据
---！@return true          玩家已经成功的离开了桌子
---！@retuen nil           玩家离开桌子失败
class.QuitStage = function(self, player)
    if not player.playerTracker then
        return true
    end

    if not self.stage:ForceLeave(player) then
        return nil
    end

    self.stage:removeClient(player)

    if player.is_offline then
        self:ClearUser(player)
    end

    return true
end


---! @brief
---! @param
class.PlayerBreak = function(self, player)
    if not player then
        return
    end

    if self:QuitStage(player) then
        -- 是否可以立刻退出
        self:ClearUser(player)
    elseif not player.is_offline then
        -- 不能立刻退出，设置离线标志
        player.is_offline = true
        if skynet.init then
            self:remoteAddAppGameUser(player)
        end
    end

    local delay = skynet.time() - player.start_time
    player.FTotalTime = (player.FTotalTime or 0) + delay

    local keyName = "FUserCode"
    self:remoteUpdateDB(self.config.DBTableName, keyName, player[keyName], "FTotalTime", player.FTotalTime)

    local fields = {
        "appName", "agent", "gate", "client_fd", "address", "watchdog",
    }
    for _, key in ipairs(fields) do
        player[key] = nil
    end
end

---! @brief 玩家是否已经坐下
---! @param
---! is player sit down or not? make it sit down anyway
class.PlayerContinue = function(self, player)
    if skynet.init then
        self:remoteDelAppGameUser(player)
    end

    self:SendUserInfo(player.FUserCode, player.FUserCode)
    self:SendGameInfo(player)

    if not player.playerTracker then
        player.playerTracker = packetHelper.createObject(self.config.PlayerTracker, player, self.stage)
        self.stage:addClient(player)
    end

    self.stage:RefreshTracker(player.playerTracker)
end

class.ClearUser = function (self, player)
    self.onlineUsers:removeObject(player, player.FUserCode)
end

class.SendGameInfo = function (self, player)
    local config = self.config
    local gameInfo = {
        gameId          = config.GameId,
        gameVersion     = config.Version,
        lowVersion      = config.LowestVersion,
        gameMode        = config.GameMode,
        numPlayers      = self.onlineUsers:getCount(),
        maxPlayers      = config.MaxConnections,

        FUserCode       = player.FUserCode,
        appName         = config.HallName,
    }

    local data   = packetHelper:encodeMsg("CGGame.HallInfo", gameInfo)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME,
            protoTypes.CGGAME_PROTO_SUBTYPE_GAMEINFO, data)
    self:gamePacketToUser(packet, player.FUserCode)
end

---!@brief 获得系统内部状态
---!@return info 内部状态的描述
class.logStat = function (self)
    debugHelper.cclog("StageInterface log stats")
    debugHelper.cclog(string.format("online player: %d\n", self.onlineUsers:getCount()))
end

return class

