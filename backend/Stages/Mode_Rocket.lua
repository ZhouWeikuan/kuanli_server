local NumSet    = require "NumSet"
local const     = require "Const_Rocket"

local math      = math

------------------------ GameMode ------------------------------
local class = {mt = {}}
local GameMode = class
class.mt.__index = class

class.create = function ()
    local self = {}
    setmetatable(self, class.mt)

    self.modeId = -1
    self.name = "Blank"

    self.specByLeaderboard = false -- false = spectate from player list instead of leaderboard

    return self
end

-- Override these
class.onServerInit = function(self, gameServer)
    -- Called when the server starts
    gameServer.run = true
end

class.onTick = function(self, gameServer)
    -- Called on every game tick
end

class.onChange = function(self, gameServer)
    -- Called when someone changes the gamemode via console commands
end

class.onPlayerInit = function(self, player)
    -- Called after a player object is constructed
end

class.onPlayerSpawn = function(self, gameServer, player)
    -- Called when a player is spawned
    -- if not player.skin then
    --     player.skin = gameServer:getOneSkin() -- Random skin
    -- end
    gameServer:spawnPlayer(player)
end

class.onCellAdd = function(self, cell)
    -- Called when a player cell is added
end

class.onCellRemove = function(self, cell)
    -- Called when a player cell is removed
end

class.onCellMove = function(self, x1, y1,cell)
    -- Called when a player cell is moved
end

class.onCellCollide = function (self, nodeA, nodeB)
    -- Called when two player cell is collided
end

class.updateLB = function(self, gameServer)
    -- Called when the leaderboard update function is called
end

class.isSameTeam = function (self, teamA, teamB)
    return teamA == teamB
end

------------------------ Mode_FFA ----------------------------------
local class = {mt = {}}
local Mode_FreeForAll = class
class.mt.__index = class

local base = GameMode
setmetatable(class, base.mt)

class.create = function (...)
    local self = base.create(...)
    setmetatable(self, class.mt)

    self.modeId = 1
    self.name = "Free For All"
    self.specByLeaderboard = false -- true

    return self
end

-- Gamemode Specific Functions

class.leaderboardAddSort = function(self, player, leaderboard)
    -- Adds the player and sorts the leaderboard
    local len = leaderboard:getCount()
    local loop = true
    while len >= 1 and loop do
        -- Start from the bottom of the leaderboard
        if player:getScore(false) <= leaderboard:getObjectAt(len):getScore(false) then
            leaderboard:insertObject(player, len+1)
            loop = false -- End the loop if a spot is found
        end
        len = len - 1
    end

    if loop then
        -- Add to top of the list because no spots were found
        leaderboard:insertObject(player, 1)
    end
end

-- Override
class.updateLB = function(self, gameServer)
    local top
    local lb = gameServer.leaderboard
    -- Loop through all clients
    local handler = function(client)
        local tracker = client.playerTracker
        local playerScore = tracker:getScore(true)
        if tracker.plane then
            if lb:getCount() == 0 then
                -- Initial player
                lb:insertObject(tracker)
            elseif lb:getCount() < 10 then
                self:leaderboardAddSort(tracker,lb)
            else
                -- 10 in leaderboard already
                if playerScore > lb:getObjectAt(10):getScore(false) then
                    lb:removeObjectAt(10)
                    self:leaderboardAddSort(tracker,lb)
                end
            end
        end
    end
    gameServer.clients:forEach(handler)

    local info = {
        ffa_data = {},
    }
    lb:forEach(function (tracker)
        local one = {
            nodeId = tracker.plane and tracker.plane.nodeId or nil,
            name   = tracker:getName(),
            score  = tracker:getScore(),
        }

        if not top then
            top = {
                name    = one.name,
                score   = one.score,
            }
        end

        table.insert(info.ffa_data, one)
    end)

    return info, top
end


----------- return the game mode -------------------------------
GameMode.get = function(mode)
    local cls = Mode_FreeForAll

    return cls.create()
end

return GameMode

