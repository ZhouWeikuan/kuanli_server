local skynet    = skynet or require "skynet"
-- use skynet.init to determine server or client

require "Cocos2dServer"

local Box       = require "Box"
local QuadTree  = require "QuadTree"

local NumSet    = require "NumSet"
local NumArray  = require "NumArray"

local packetHelper  = (require "PacketHelper").create("protos/Rocket.pb")

local const     = require "Const_Rocket"

local math = math

------------------------------- Entity Object ----------------------------------
local
__Entity_Object__ = function() end


local class = {mt = {}}
local Entity = class
class.mt.__index = class

class.create = function (nodeId, nodeType, position)
    local self = {}
    setmetatable(self, class.mt)

    self.nodeId     = nodeId
    self.nodeType   = nodeType
    self.createTime = skynet.time()
    self.isTerminated = false

    if const.isRocketType(nodeType) or const.isPlaneType(nodeType) then
        self.sendUpdate = true
    else
        self.sendUpdate = nil
    end

    self:updatePosition(position)

    return self
end

class.getSize = function (self)
    return 56
end

class.updatePosition = function (self, position)
    self.position = cc.p(position.x, position.y)

    local size = self:getSize()
    self.box = Box.createWithBox(position.x - size, position.x + size, position.y - size, position.y + size)
end

class.onRemove = function(self, gameServer)
end

class.onAdd = function (self, gameServer)
end

class.die = function (self)
    if not self.isTerminated then
        self.isTerminated = true
        return true
    end
    return false
end

-------------------------------- Rocket Object -------------------------
local
__Rocket_Object__ = function() end


local class = {mt = {}}
local Rocket = class
class.mt.__index = class

local base = Entity
setmetatable(class, base.mt)

class.create = function (gameServer, nodeType, position)
    local nodeId    = gameServer:getNextNodeId()
    if not nodeType then
        nodeType  = math.random(const.kTypeRocketStart, const.kTypeRocketEnd)
    end
    local self = base.create(nodeId, nodeType, position)
    setmetatable(self, class.mt)

    self.gameServer = gameServer

    self.moveDir = nil
    self.traceObj = nil

    local cfg = gameServer.config.StuffConfig[nodeType]
    self.config = cfg
    assert(cfg)

    return self
end

class.getSize = function (self)
    return 56
end

class.updateTrace = function (self, obj)
    self.traceObj = obj
end

class.moveBy = function (self, dir, speedScale)
    if not self.moveDir then
        return
    end

    if dir then
        dir = cc.pNormalize(dir)
        local cfg = self.config
        local mov = cc.pAdd(self.moveDir, cc.pMul(dir, cfg.MaxForce))
        local len = cc.pGetLength(mov)

        local maxSpeed = cfg.MaxSpeed * speedScale
        if len > maxSpeed then
            mov = cc.pMul(mov, maxSpeed/len)
        end
        self.moveDir = mov
    end

    local pos = cc.pAdd(self.position, self.moveDir)
    self:updatePosition(pos)
    self.gameServer:moveNode(self)
end

class.adjustDir = function (self, old)
    local angle = math.deg(cc.pGetAngle(self.moveDir, old))
    local dir = nil
    if math.abs(angle) >= 90 then
        dir = cc.pForAngle(math.rad(angle * 0.6))
        dir = cc.pRotate(self.moveDir, dir)
    else
        dir = old
    end
    dir = cc.pNormalize(dir)
    return dir
end

class.isOutOfWorld = function (self)
    local half   = self:getSize() * 0.8
    local config = self.gameServer.config
    local newPos = self.position

    if newPos.x - half <= config.BorderLeft or newPos.x + half >= config.BorderRight or
        newPos.y - half <= config.BorderBottom or newPos.y + half >= config.BorderTop then
        -- hit bounder
        return true
    end
end

class.update = function (self)
    local cfg = self.config
    if self.traceObj and self.traceObj.isTerminated then
        self.traceObj = nil
    end

    if self.traceObj and not self.moveDir then
        local dir = cc.pSub(self.traceObj.position, self.position)
        dir = cc.pNormalize(dir)
        self.moveDir = cc.pMul(dir, cfg.MaxForce)
    end

    if not self.moveDir then
        return true
    end

    local dir = nil
    if self.traceObj then
        dir = cc.pSub(self.traceObj.position, self.position)
    else
        dir = self.moveDir
    end
    dir = self:adjustDir(dir)
    self:moveBy(dir, 1.0)

    if self:isOutOfWorld() then
        self:die()
        return nil
    end

    if not const.isRocketType(self.nodeType) then
        return true
    end

    local check     = NumSet.create()
    local half      = self:getSize()
    local newPos    = cc.p(self.position.x, self.position.y)
    local box       = Box.create(newPos.x, newPos.y, half, half)
    self.gameServer.nodeTree:queryBox(box, function(node)
        if node == self then
            return
        end

        local size = (node:getSize() + half) * 0.5
        local shortSQ = size * size
        local sq = cc.pDistanceSQ(newPos, node.position)
        if sq > shortSQ then
            return
        end

        if const.isRocketType(node.nodeType) then
            check:addObject(node)
        end
    end)

    local die = nil
    check:forEach(function (node)
        node:die()
        die = true
    end)

    if die then
        self:die()
        return nil
    end
    return true
end

class.onRemove = function(self, gameServer)
    gameServer.moveObjs:removeObject(self)
end

class.onAdd = function (self, gameServer)
    gameServer.moveObjs:addObject(self)
end

class.die = function (self)
    if not base.die(self) then
        return
    end
    self.gameServer:removeNode(self)
    return true
end

------------------------------- Plane Object ---------------------------
local
__Plane_Object__ = function() end


local class = {mt = {}}
local Plane = class
class.mt.__index = class

local base = Rocket
setmetatable(class, base.mt)

class.create = function (gameServer, player, position)
    local nodeType = math.random(const.kTypePlaneStart, const.kTypePlaneEnd)
    local self = base.create(gameServer, nodeType, position)
    setmetatable(self, class.mt)

    self.tracker    = player
    if player then
        self.name = player.name
    end

    player.lastPlayerNodeId = nil
    self.currScore  = 0
    self.histScore  = 0
    self.buffs = {}

    return self
end

class.getSize = function (self)
    return 80
end

class.refreshPlayerInfo = function (self)
    -- Adds to the owning player's screen
    local info = self:collectMyInfo()
    local data = packetHelper:encodeMsg("Rocket.PlayerInfo", info)
    self.gameServer:SendGameDataToTracker(self.tracker, const.ROCKET_GAMEDATA_ADDNODE, data)
end

class.collectMyInfo = function (self)
    local info = {
        playerId    =   self.nodeId,
        currScore   =   self.currScore,
        histScore   =   self.histScore,
    }
    return info
end

class.die = function (self)
    if not Entity.die(self) then
        return
    end

    local gameServer    = self.gameServer

    local num = math.floor(self.currScore * 0.3333 + 1)
    for i = 1, num do
        local pos = cc.p((math.random() - 0.5) * 200 + self.position.x, (math.random() - 0.5) * 200 + self.position.y)
        local f = Entity.create(gameServer:getNextNodeId(), const.kTypeFood_Star, gameServer:getRandomPosition(pos))
        gameServer:addNode(f)
    end

    gameServer:removeNode(self)
    gameServer.gameMode:onCellRemove(self)

    local tracker = self.tracker
    if tracker then
        local info = {
            playerId      =   self.nodeId
        }
        local data = packetHelper:encodeMsg("Rocket.PlayerInfo", info)
        gameServer:SendGameDataToTracker(tracker, const.ROCKET_GAMEDATA_CLEARNODE, data)

        tracker.lastPlayerNodeId = self.nodeId
        tracker.plane       = nil
        tracker.moveDir     = nil
    end

    self.tracker     = nil
    return true
end

class.useLight = function (self)
    local half      = 500
    local lightSQ   = 500 * 500
    local newPos    = cc.p(self.position.x, self.position.y)
    local box       = Box.create(newPos.x, newPos.y, half, half)
    self.gameServer.nodeTree:queryBox(box, function(node)
        if node == self then
            return
        end

        local sq = cc.pDistanceSQ(newPos, node.position)
        local vc = cc.pSub(node.position, newPos)
        if const.isPlaneType(node.nodeType)
            and sq <= lightSQ
            and math.deg(cc.pGetAngle(self.moveDir, vc)) <= 60
        then
            node:addBuff(const.kTypeFood_Harm)
        end
    end)
    self.buffs[const.kTypeFood_Light] = skynet.time() + 0.6
end

class.addBuff = function (self, bufId)
    local otherId
    if bufId == const.kTypeFood_Harm then
        if self.buffs[const.kTypeFood_Shield] then
            return
        end

        otherId = const.kTypeFood_Speed
        if self.buffs[otherId] then
            self.buffs[otherId] = nil
            return
        end
    elseif bufId == const.kTypeFood_Speed then
        otherId = const.kTypeFood_Harm
        if self.buffs[otherId] then
            self.buffs[otherId] = nil
            return
        end
    end

    self.buffs[bufId] = skynet.time() + 5.0
end

class.addScore = function (self, score)
    self.currScore = self.currScore + score
    self.histScore = self.histScore + score
end

class.handleFood = function (self, node)
    self.gameServer:removeNode(node)
    if node.nodeType == const.kTypeFood_Star then
        self:addScore(1)
    else
        self:addScore(2)
    end
    self:addBuff(node.nodeType)
end

class.checkBuffs = function (self)
    local now = skynet.time()

    local arr = {}
    for kind, timeout in pairs(self.buffs) do
        if timeout < now then
            table.insert(arr, kind)
        end
    end

    for _, kind in ipairs(arr) do
        self.buffs[kind] = nil
    end
end

class.update = function(self)
    local gameServer    = self.gameServer
    local tracker       = self.tracker

    self:checkBuffs()
    if not tracker.moveDir then
        return true
    end

    if not self.moveDir then
        self.moveDir = cc.pMul(cc.p(0, 1), self.config.MaxForce)
    end

    local speedScale = 1.0
    if self.buffs[const.kTypeFood_Speed] ~= nil then
        speedScale = 2.0
    elseif self.buffs[const.kTypeFood_Harm] ~= nil then
        speedScale = 0.5
    end
    local dir = self:adjustDir(tracker.moveDir)
    self:moveBy(dir, speedScale)

    if self:isOutOfWorld() then
        self:die()
        return nil
    end

    local check     = NumSet.create()
    local availTime = skynet.time()
    local half      = 500
    local longSQ    = half * half
    local newPos    = cc.p(self.position.x, self.position.y)
    local box       = Box.create(newPos.x, newPos.y, half, half)
    gameServer.nodeTree:queryBox(box, function(node)
        if node == self then
            return
        end

        local size = (node:getSize() + self:getSize()) * 0.8
        local shortSQ = size * size

        local sq = cc.pDistanceSQ(newPos, node.position)
        if sq <= longSQ then
            if node.nodeType == const.kTypeFood_Rocket then
                if node.createTime + 3.0 <= availTime then
                    check:addObject(node)
                end
                return
            elseif const.isRocketType(node.nodeType) and node.traceObj ~= self then
                if node.traceObj == nil or sq < cc.pDistanceSQ(node.position, node.traceObj.position) then
                    -- print("update node's traceObj, node: ", node, " plane: ", self)
                    node:updateTrace(self)
                end
            end
        else
            return
        end

        if sq > shortSQ then
            return
        end

        if const.isFoodType(node.nodeType) then
            check:addObject(node)
        elseif const.isRocketType(node.nodeType) then
            check:addObject(node)
        elseif const.isPlaneType(node.nodeType) then
            if node.createTime + 3.0 <= availTime then
                check:addObject(node)
            end
        end
    end)

    local die = nil
    check:forEach(function (node)
        if node.nodeType == const.kTypeFood_Rocket then
            local rocket = Rocket.create(gameServer, const.kTypeRocketStart, node.position)
            rocket:updateTrace(self)
            gameServer.moveObjs:addObject(rocket)
            gameServer:addNode(rocket)

            gameServer:removeNode(node)
        elseif const.isFoodType(node.nodeType) then
            self:handleFood(node)
        elseif const.isRocketType(node.nodeType)
            or const.isPlaneType(node.nodeType) then

            node:die()
            die = true
        end
    end)

    if die then
        if self.buffs[const.kTypeFood_Shield] == nil then
            self:die()
            return nil
        else
            self:addScore(2)
        end
    end

    return true
end

------------------------------- Server Snake --------------------------
local
__Server_Rocket__ = function() end


local class = {mt = {}}
local Server_Rocket = class
class.mt.__index = class

local base = require "GameServer"
setmetatable(class, base.mt)

class.UserStatus_ProtoName = "Rocket.UserStatus"
class.UserStatus_Fields = {
    "FUserCode", "FCounter", "FScore",
    "FLastGameTime", "FSaveDate", "FSaveCount",
    "gameSkin", "status", "killNum",
}

class.create = function (hallInterface)
    -- init
    local self = base.create(hallInterface)
    setmetatable(self, class.mt)

    self:loadConfig()

    self.tickInterval = self.config.TickInterval * 0.01

    -- Startup
    self.clients    = NumSet.create()
    self.moveObjs   = NumSet.create()

    self.leaderboard    = NumArray.create()
    self.lb_packet      = nil               -- Leaderboard packet

    -- Main loop tick
    self.time       = skynet.time()
    self.startTime  = self.time
    self.tick       = 0     -- 1 second ticks of mainLoop
    self.tickMain   = 0     -- 50 ms ticks, 20 of these = 1 leaderboard update
    self.tickSpawns = {}    -- Used with spawning food

    -- world
    local l, r, b, t = self.config.BorderLeft, self.config.BorderRight, self.config.BorderBottom, self.config.BorderTop
    local box       = Box.createWithBox(l, r, b, t)
    self.clientTree = QuadTree.create(box)

    box             = Box.createWithBox(l, r, b, t)
    self.nodeTree   = QuadTree.create(box)

    -- Gamemodes
    local GameMode = require "Mode_Rocket"
    self.gameMode = GameMode.get(self.config.GameMode)

    return self
end

-- you must check for mainLoop and getStats yourself
class.start = function(self)
    -- Gamemode configurations
    self.gameMode:onServerInit(self)

    -- Start the server
    -- Spawn starting stuffs
    self:startStuffs()

    -- Player bots (Experimental)
    if self.config.ServerBotNum > 0 then
        for i = 1, self.config.ServerBotNum do
            local botPlayer = packetHelper.createObject(self.config.ServerBotName, self)
            self:addClient(botPlayer.userInfo)

           botPlayer:sendNickname()
        end
        print("[Game] Loaded " .. self.config.ServerBotNum .. " server bots")
    end
end

class.SendGameDataToTracker = function (self, tracker, subType, data)
    if not tracker.isBot then
        base.SendGameDataToUser(self, tracker.userInfo.FUserCode, subType, data)
    else
        tracker:handleGameData(subType, data)
    end
end

class.notifyAll = function (self, typeId, speakerNick, text)
    do return end
    self.lastNotifyTime = self.lastNotifyTime or 0
    local now = skynet.time()
    if now - self.lastNotifyTime < 10 then
        return
    end

    self.lastNotifyTime = now

    if not skynet.init then
        return
    end

    local target = skynet.uniqueservice("HallService")
    if not target then
        skynet.error("failed to get unique service HallService")
        return
    end

    local chatInfo = {
        gameId      = -1,
        speekerId   = typeId and typeId or "-1",
        speakerNick = speakerNick,
        chatText    = text,
    }
    local data   = packetHelper:encodeMsg("CGGame.ChatInfo", chatInfo)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                        protoTypes.CGGAME_PROTO_SUBTYPE_CHAT, data)
    skynet.call(target, "lua", "noticeAll", packet)
end

class.notifyKilling = function (self, name, num)
    do return end

    local info = {
        name    = name,
        count   = num,
    }

    local text = packetHelper:encodeMsg("Rocket.NoticeInfo", info)

    self:notifyAll(tostring(const.kNoticeTypeKillings), "msgTypeHonor", text)
end

class.notifyDeath = function (self, name, killer, length)
    do return end

    local info = {
        name    = name,
        count   = length,
    }
    if killer then
        if killer.name then
            info.killer = killer.name
        else
            info.nodeId = killer.nodeId
        end
    end

    local text = packetHelper:encodeMsg("Rocket.NoticeInfo", info)
    if info.killer then
        self:notifyAll(tostring(const.kNoticeTypeKilledBy), "msgTypeHate", text)
    else
        self:notifyAll(tostring(const.kNoticeTypeSuicide), "msgTypeHaha", text)
    end
end

class.notifyTopRank = function (self, name, length)
    do return end

    local info = {
        name    = name,
        count   = length,
    }

    local text = packetHelper:encodeMsg("Rocket.NoticeInfo", info)
    self:notifyAll(tostring(const.kNoticeTypeTopRank), "msgTypeTop", text)
end


-- game's main loop function on each tick
class.mainLoop = function(self, dt)
    -- Timer
    local now = skynet.time()
    self.tick = self.tick + (now - self.time)
    self.time = now

    local count = self.clients:getCount()
    if count <= self.config.ServerBotNum then
        -- ignore if only server bots
        return
    end

    local interval = self.tickInterval

    if (self.tick >= interval) then
        -- -- Loop main functions
        self:moveTick()
        self:spawnTick()
        self:gamemodeTick()

        -- Update the client's maps
        self:updateClients()

        -- Update cells/leaderboard loop
        self.tickMain = self.tickMain + 1
        if (self.tickMain >= 25) then -- 1 Second
            -- Update leaderboard with the gamemode's method
            self.leaderboard:clear()
            local info, top = self.gameMode:updateLB(self)
            self.lb_packet = packetHelper:encodeMsg("Rocket.LeaderBoard", info)

            self.tickTop = 1 + (self.tickTop or 0)
            if top and self.tickTop > 30 then
                self.tickTop = 0
                self:notifyTopRank(top.name, top.score)
            end

            self.tickMain = 0 -- Reset
        end

        -- Reset
        self.tick = 0
    end
end

class.moveTick = function(self)
    local toRemove = {}
    self.moveObjs:forEach(function (obj)
        local isAlive = nil
        if const.isRocketType(obj.nodeType) then
            isAlive = obj:update()
        elseif const.isPlaneType(obj.nodeType) then
            if obj.tracker then
                isAlive = obj:update()
            end
        end

        if not isAlive then
            table.insert(toRemove, obj)
        end
    end)

    self.moveObjs:removeObjects(toRemove)
end

class.spawnTick = function(self)
    -- Spawn stuff
    for nodeType, stuffData in pairs(self.config.StuffData) do
        local tickSpawn =  self.tickSpawns[nodeType] or 0
        tickSpawn = tickSpawn + 1
        if tickSpawn >= stuffData.spawnInterval then
            self:updateStuff(nodeType)
            tickSpawn = 0   -- Reset
        end
        self.tickSpawns[nodeType] = tickSpawn
    end
end

class.gamemodeTick = function(self)
    -- Gamemode tick
    self.gameMode:onTick(self)
end

class.updateClients = function(self)
    local list = {}
    self.clients:forEach(function(client)
        local tracker = client.playerTracker

        if not tracker.plane or client.is_offline then
            local now = skynet.time()
            if tracker.disconnect ~= -1 then
                if now > tracker.disconnect then
                    table.insert(list, client)
                    return
                end
            elseif client.is_offline then
                tracker.disconnect = now + 30
            end
        end

        tracker:update()
    end)

    for _, client in ipairs(list) do
        self:removeClient(client)
        if client.is_offline then
            self.hallInterface:ClearUser(client)
        end
    end
end

-- each client has at least
-- 1) playerTracker to update its view box
-- 2) packetHandler to pass in&out message
-- 3) socket        to write on
class.addClient = function (self, client)
    self.clientTree:addObject(client.playerTracker)
    self.clients:addObject(client)
end

class.removeClient = function (self, client)
    -- should we die once offline, or just go whatever as we went?
    --
    local tracker = client.playerTracker
    local plane = tracker and tracker.plane or nil
    if plane then
        plane:die()
    end

    self.clientTree:removeObject(tracker)
    self.clients:removeObject(client)
end

class.ForceLeave = function (self, client)
    local tracker = client.playerTracker
    if tracker and tracker.plane then
        return nil
    end

    return true
end

class.RefreshTracker = function (self, playerTracker)
    if playerTracker then
        playerTracker.disconnect = -1
        playerTracker.lastNodes = nil
        if playerTracker.plane then
            playerTracker.plane:refreshPlayerInfo()
        end
    end
end

class.getNextNodeId = function(self)
    -- Resets integer
    self.lastNodeId = self.lastNodeId or 0
    if self.lastNodeId > 2147483647 then
        self.lastNodeId = 0
    end

    self.lastNodeId = self.lastNodeId + 1
    return self.lastNodeId
end

class.getRandomPosition = function(self, pos)
    local config = self.config
    if not pos then
        pos = {
            x =  math.random() * (config.BorderRight - config.BorderLeft) + config.BorderLeft,
            y =  math.random() * (-config.BorderBottom + config.BorderTop) + config.BorderBottom
        }
    end

    local edge = const.kNodeSize * 4
    if pos.x - edge <= config.BorderLeft then
        pos.x = config.BorderLeft + edge
    elseif pos.x + edge >= config.BorderRight then
        pos.x = config.BorderRight - edge
    end

    if pos.y - edge <= config.BorderBottom then
        pos.y = config.BorderBottom + edge
    elseif pos.y + edge >= config.BorderTop then
        pos.y = config.BorderTop - edge
    end

    return pos
end

class.getOneSkin = function(self, skin)
    return 1001
end

class.handleGameData = function (self, client, gameType, data)
    local tracker = client.playerTracker
    if not tracker then
        print("No player tracker for client ", client.FNickName)
        return
    end

    local hallInterface = self.hallInterface
    if gameType == const.ROCKET_GAMEDATA_START then
        local config = self.config
        local borderInfo = {
            left    = config.BorderLeft,
            right   = config.BorderRight,
            bottom  = config.BorderBottom,
            top     = config.BorderTop,

            sightViewWidth  = config.ViewBaseWidth,
            sightViewHeight = config.ViewBaseHeight,
        }
        data = packetHelper:encodeMsg("Rocket.BorderInfo", borderInfo)
        self:SendGameDataToTracker(tracker, const.ROCKET_GAMEDATA_SETBORDER, data)

    elseif gameType == const.ROCKET_GAMEDATA_MOVE then
        -- 移动方向，是绝对的，还是对当前方向有力道的改变(合成)？
        local pos = packetHelper:decodeMsg("Rocket.Position", data)
        if pos then
            local p = cc.p(pos.x or 0, pos.y or 0)
            if p.x ~= p.x or p.y ~= p.y then
            else
                tracker.moveDir = cc.pNormalize(p)
            end
        end
    elseif gameType == const.ROCKET_GAMEDATA_ACTIONS then
        local code
        if data then
            local actionInfo = packetHelper:decodeMsg("Rocket.ActionInfo", data)
            code = actionInfo.actionCode or 0
        else
            code = 0
        end
        tracker:applyActionCode(code)
    elseif gameType == const.ROCKET_GAMEDATA_SPECTATE then
        -- 进入观察模式
        if not tracker.plane then
            -- Make sure client has no cells, specify the FUserCode or nil
            local code = data and math.tointeger(data) or nil
            self:switchSpectator(tracker, code)
            tracker.spectate = true
        end

    elseif gameType == const.ROCKET_GAMEDATA_NICKNAME then
        -- 设置昵称
        local nameInfo = packetHelper:decodeMsg("Rocket.NicknameInfo", data)
        self:setNickname(tracker, nameInfo)

    else
        print("Unknow game data from stage client: ", gameType, data)
    end
end

class.setNickname = function (self, tracker, nameInfo)
    if not tracker.plane then
        -- Set name first
        tracker:setName(nameInfo.nickname)
        local skin = nameInfo.skinId
        if const.isPlaneType(skin) then
            tracker:setSkin(skin)
        else
            tracker:setSkin()
        end

        -- If client has no cells... then spawn a player
        self.gameMode:onPlayerSpawn(self, tracker)
        self:RefreshTracker(tracker)

        -- Turn off spectate mode
        tracker.spectate = false
    end
end

class.addNode = function(self, node)
    self.nodeTree:addObject(node)

    local oneStuff = self.stuff[node.nodeType]
    if oneStuff then
        oneStuff:addObject(node)
    end

    -- Special on-add actions
    node:onAdd(self)

    -- Add to visible nodes
    self.clientTree:queryBox(node.box, function(client)
        if node.box:intersect(client.box) then
            client.nodeAdditionQueue:addObject(node)
        end
    end)
end

class.moveNode = function (self, node)
    self.nodeTree:updateObject(node)
end

class.removeNode = function(self, node)
    -- Remove from main nodes list
    self.nodeTree:removeObject(node)

    local oneStuff = self.stuff[node.nodeType]
    if oneStuff then
        oneStuff:removeObject(node)
    end

    -- Special on-remove actions
    node:onRemove(self)

    -- Animation when eating
    self.clientTree:queryBox(node.box, function(client)
        if node.box:intersect(client.box) then
            client.nodeDestroyQueue:addObject(node)
        end
    end)
end

class.spawnPlayer = function(self, player, pos)
    -- Get random pos
    pos = pos or self:getRandomPosition()

    -- Spawn player and add to world
    player.plane = Plane.create(self, player, pos)
    self.moveObjs:addObject(player.plane)
    self:addNode(player.plane)
    self.gameMode:onCellAdd(player.plane)

    -- Set initial mouse coords
    player.moveDir = nil
end

class.loadConfig = function(self)
    local config = self.config

    local stuff = config.StuffData
    self.stuff = {}
    for nodeType,_ in pairs(stuff) do
        self.stuff[nodeType] = NumSet.create()
        --如果stuff有存活时间，则方便遍历
    end
end

class.startStuffs = function(self)
    -- Spawns the starting amount of food cells
    local config = self.config
    for nodeType,data in pairs(config.StuffData) do
        for i = 1, data.startAmount do
            local success = self:spawnStuff(nodeType)
            if not success then
                break
            end
        end
    end
end

class.updateStuff = function(self, nodeType)
    local stuffData = self.config.StuffData[nodeType]
    local toSpawn = math.min(stuffData.spawnAmount, stuffData.maxAmount - self.stuff[nodeType]:getCount())

    for i = 1, toSpawn do
        local success = self:spawnStuff(nodeType)
        if not success then
            return
        end
    end
end

class.spawnStuff = function(self, nodeType)
    local ns = self.stuff[nodeType]
    if not ns or ns:getCount() >= self.config.StuffData[nodeType].maxAmount then
        return nil
    end

    local pos = self:getRandomPosition()
    local f = Entity.create(self:getNextNodeId(), nodeType, pos)
    self:addNode(f)

    return true
end

class.switchSpectator = function(self, player, otherCode)
    local firstTracker = nil
    local nextTracker  = nil

    local group = nil
    if self.gameMode.specByLeaderboard then
        group = self.leaderboard
    else
        group = self.clients
    end

    group:forEach(function(client)
        local tracker = client
        if client.playerTracker then
            tracker = client.playerTracker
        end

        if not tracker.plane then
            return
        end

        if not firstTracker then
            firstTracker = tracker
        end

        if otherCode then
            if tracker.userInfo.FUserCode == otherCode then
                nextTracker = tracker
                return true
            end
        elseif tracker == player.spectatedPlayer then
            player.spectatedPlayer = nil
        elseif not player.spectatedPlayer then
            nextTracker = tracker
            return true
        end
    end)

    if not nextTracker then
        nextTracker = firstTracker
    end

    player.spectatedPlayer = nextTracker
end

return class
