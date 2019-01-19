local skynet = skynet or require "skynet"

require "Cocos2dServer"

local Box       = require "Box"
local NumSet    = require "NumSet"

local packetHelper  = require "PacketHelper"

local const     = require "Const_Rocket"

local math = math

local class = {mt = {}}
class.mt.__index = class

class.create = function (userInfo, gameServer)
    local self = {}
    setmetatable(self, class.mt)

    self.userInfo   = userInfo
    self.gameServer = gameServer

    self.disconnect = -1
    self.name = userInfo.FNickName or ""

    self.nodeAdditionQueue  = NumSet.create()
    self.nodeDestroyQueue   = NumSet.create()
    self.visibleNodes       = NumSet.create()

    self.skin       = nil
    self.score      = 0

    self.plane              = nil
    self.moveDir            = nil

    self.tickLeaderboard    = 0
    self.tickViewBox        = 0

    self.teamId     = nil
    self.spectate   = false
    self.spectatedPlayer = nil -- Current player that this player is watching

    local config = gameServer.config
    -- Viewing box
    self.sightRangeX = 0
    self.sightRangeY = 0
    self.centerPos = cc.p((config.BorderLeft + config.BorderRight) * 0.5,
                        (config.BorderTop + config.BorderBottom) * 0.5)
    self.box = Box.createWithBox(self.centerPos.x, self.centerPos.x, self.centerPos.y, self.centerPos.y)

    -- Gamemode function
    if gameServer then
        gameServer.gameMode:onPlayerInit(self)
    end

    return self
end

class.applyActionCode = function (self, code)
    if not self.plane then
        return
    end

    local bufId = nil
    local score = 0
    if code == const.kActionMaskSpeed then
        bufId = const.kTypeFood_Speed
        score = const.kCostSpeed
    elseif code == const.kActionMaskShield then
        bufId = const.kTypeFood_Shield
        score = const.kCostShield
    elseif code == const.kActionMaskLight then
        bufId = const.kTypeFood_Light
        score = const.kCostLight
    else
        return
    end

    if self.plane.currScore < score then
        return
    end

    self.plane.currScore = self.plane.currScore - score
    if code == const.kActionMaskLight then
        self.plane:useLight()
    else
        self.plane:addBuff(bufId)
    end
end

-- Setters/Getters
class.setName = function(self, name)
    self.name = name
end

class.getName = function(self)
    return self.name
end

class.setSkin = function(self, skin)
    local one = self.gameServer:getOneSkin(skin)
    self.skin = one
end

class.getSkin = function(self)
    if not self.skin then
        class.setSkin()
    end
    return self.skin
end

class.getScore = function(self, reCalcScore)
    if reCalcScore then
        local s = 0
        if self.plane then
            s = self.plane.histScore
        end
        self.score = s
    end
    return self.score
end

class.getTeam = function(self)
    return self.teamId
end

-- Viewing box
class.getZoomFactor = function (self)
    return 1.0
end

class.updateSightRange = function(self)  -- For view distance
    local factor = self:getZoomFactor()
    local config = self.gameServer.config
    self.sightRangeX = config.ViewBaseWidth * factor
    self.sightRangeY = config.ViewBaseHeight * factor
end

class.updateCenter = function(self, pos) -- Get center of cells
    if self.plane then
        pos = self.plane.position
    elseif not pos then
        return
    end

    self.centerPos.x = pos.x
    self.centerPos.y = pos.y

    local tree = self.gameServer.clientTree
    self.box = Box.create(self.centerPos.x, self.centerPos.y, self.sightRangeX, self.sightRangeY)
    tree:updateObject(self)
end

class.calcViewBox = function(self)
    if self.spectate then
        -- Spectate mode
        return self:getSpectateNodes()
    end

    -- Main function
    self:updateSightRange()
    self:updateCenter()

    local newVisible = NumSet.create()
    self.gameServer.nodeTree:queryBox(self.box, function(node)
        if self.box:intersect(node.box) then
            -- Cell is in range of view box
            newVisible:addObject(node)
        end
    end)

    return newVisible
end

class.getSpectateNodes = function(self)
    local retNodes = NumSet.create()
    local specPlayer = self.spectatedPlayer
    local gameServer = self.gameServer

    if specPlayer then
        -- If selected player has died/disconnected, switch spectator and try again next tick
        if not specPlayer.plane then
            gameServer:switchSpectator(self)
            return retNodes
        end

        -- Get spectated player's location and calculate zoom amount
        local specZoom = self:getZoomFactor()
        local posInfo = {
            x = specPlayer.centerPos.x,
            y = specPlayer.centerPos.y,
            s = specZoom,
        }
        local data = packetHelper:encodeMsg("Rocket.Position", posInfo)
        gameServer:SendGameDataToTracker(self, const.ROCKET_GAMEDATA_UPDATEPOSITION, data)

        self:updateCenter(posInfo)

        -- TODO: Recalculate visible nodes for spectator to match specZoom
        specPlayer.visibleNodes:forEach(function(node)
            retNodes:addObject(node)
        end)
    end
    return retNodes
end

class.sendNodesUpdate = function (self, nodes, nonVisibleNodes)
    local gameServer = self.gameServer
    local config     = gameServer.config

    local packet = {}

    if self.plane then
        packet.playerInfo = self.plane:collectMyInfo()
    end

    self.lastNodes = self.lastNodes or NumSet.create()
    self.thisNodes = NumSet.create()

    packet.destroyNodes= {}
    self.nodeDestroyQueue:forEach(function(node)
        local one = {
            nodeId      = node.nodeId
        }
        table.insert(packet.destroyNodes, one)
    end)

    packet.updateNodes = {}
    nodes:forEach(function(node)
        local one = {}
        one.nodeId = node.nodeId

        self.thisNodes:addObject(node.nodeId)

        if not self.lastNodes:hasObject(node.nodeId) then
            one.nodeType    = node.nodeType
            one.name        = node.name
        end

        one.pos_x       = node.position.x
        one.pos_y       = node.position.y
        if node.moveDir then
            one.moveAngle   = math.deg(cc.pToAngleSelf(node.moveDir))
        else
            one.moveAngle   = 90
        end

        one.buffs = {}
        if node.buffs then
            for k, _ in pairs(node.buffs) do
                table.insert(one.buffs, k)
            end
        end

        table.insert(packet.updateNodes, one)
    end)

    self.lastNodes = self.thisNodes
    self.thisNodes = nil

    packet.invalidNodes = {}
    nonVisibleNodes:forEach(function(node)
        table.insert(packet.invalidNodes, node.nodeId)
    end)

    local data = packetHelper:encodeMsg("Rocket.UpdateView", packet)
    gameServer:SendGameDataToTracker(self, const.ROCKET_GAMEDATA_UPDATENODES, data)
end

-- Functions
class.update = function(self)
    -- Actions buffer (So that people cant spam packets)
    local gameServer    = self.gameServer
    local updateNodes   = NumSet.create() -- Nodes that need to be updated via packet

    -- Remove nodes from visible nodes if possible
    local list = {}
    self.nodeDestroyQueue:forEach(function(node)
        if self.visibleNodes:hasObject(node) then
            self.visibleNodes:removeObject(node)
        else
            -- Node was never visible anyways
            table.insert(list, node)
        end
    end)
    self.nodeDestroyQueue:removeObjects(list)

    -- Get visible nodes every 400 ms
    local nonVisibleNodes = NumSet.create() -- Nodes that are not visible
    if self.tickViewBox <= 0 then
        local newVisible = self:calcViewBox()

        -- Compare and destroy nodes that are not seen
        local toRemove = {}
        self.visibleNodes:forEach(function(node)
            if not newVisible:hasObject(node) then
                -- Not seen by the client anymore
                nonVisibleNodes:addObject(node)
                table.insert(toRemove, node)
            end
        end)
        self.visibleNodes:removeObjects(toRemove)

        -- Add nodes to client's screen if client has not seen it already
        newVisible:forEach(function(node)
            if not self.visibleNodes:hasObject(node) then
                updateNodes:addObject(node)
            end
        end)

        self.visibleNodes = newVisible
        -- Reset Ticks
        self.tickViewBox = 10
    else
        self.tickViewBox = self.tickViewBox - 1
        -- Add nodes to screen

        self.nodeAdditionQueue:forEach(function(node)
            self.visibleNodes:addObject(node)
            updateNodes:addObject(node)
        end)
    end

    -- Update moving nodes
    self.visibleNodes:forEach(function(node)
        if not self.lastNodes or node.sendUpdate then
            -- Sends an update if cell is moving
            updateNodes:addObject(node)
        end
    end)

    -- Send packet
    self:sendNodesUpdate(updateNodes, nonVisibleNodes)

    self.nodeDestroyQueue:clear() -- Reset destroy queue
    self.nodeAdditionQueue:clear() -- Reset addition queue

    -- Update leaderboard
    if (self.tickLeaderboard <= 0) then
		if gameServer.lb_packet then
            gameServer:SendGameDataToTracker(self, const.ROCKET_GAMEDATA_LEADERBOARD, gameServer.lb_packet)
		end
        self.tickLeaderboard = 50 -- 20 ticks = 1 second
    else
        self.tickLeaderboard = self.tickLeaderboard - 1
    end
end

return class
