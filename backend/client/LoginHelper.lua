local skynet = require "skynet"

local Settings = require "Settings"
local WaitList = require "WaitList"
local packetHelper = require "PacketHelper"

local RemoteSocket = require "RemoteSocket"

local protoTypes    = require "ProtoTypes"


---! create the class metatable
local class = {mt = {}}
class.mt.__index = class

---! create delegate object
class.create = function (const)
    local self = {}
    setmetatable(self, class.mt)

    self.message = ""
    self.agentList = {}
    self.const = const

    return self
end

class.createFromLayer = function (delegate, botName, authInfo, const)
    if delegate.login then
        delegate.login:releaseFromLayer(delegate)
    end

    local login = class.create(const)
    delegate.login = login

    login:getOldLoginList()
    login:tryLogin()

    if login.remotesocket then
        local BotPlayer = require(botName)
        local agent = BotPlayer.create(delegate, authInfo, self)
        delegate.agent  = agent

        local packet = login:tryHall(Settings.getItem(Settings.keyGameMode, 0))
        agent:sendPacket(packet)

        return true
    end
end

class.tickCheck = function (self, delegate)
    if self.remotesocket and self.remotesocket:isClosed() then
        self.remotesocket = nil
    end

    if not self.remotesocket then
        self:tryLogin()

        if not self.remotesocket then
            print("请确定网络正常后再重试，或联系我们客服QQ群: 543221539", "网络出错")

            --[[
            local app = cc.exports.appInstance
            local view = app:createView("LineScene")
            view:showWithScene()
            --]]
            return
        end

        local packet = self:tryHall(Settings.getGameMode())
        delegate.agent:sendPacket(packet)

        return true
    end
end

class.closeSocket = function (self)
    if self.remotesocket then
        self.remotesocket:close()
        self.remotesocket = nil
    end
end

class.releaseFromLayer = function (self, delegate)
    self:closeSocket()
    delegate.login = nil
end

---! agent list, maybe better two host:port for each site
local def_agent_list = {"11.11.1.11:8201", "11.11.1.12:8201"}

---! check for all agents, find the best one if doCheck
class.checkAllLoginServers = function (self, doCheck)
    local best = table.concat(def_agent_list, ",")
    if not doCheck then
        return best
    end

    local probs = def_agent_list
    local diff  = 9999
    for i, item in ipairs(probs) do
        local oldTime = skynet.time()
        local host, port = string.match(item, "(%d+.%d+.%d+.%d+):(%d+)")
        local conn = RemoteSocket.create(host, port)
        if conn and conn.sockfd then
            local tmp = skynet.time() - oldTime
            print("diff for item ", item, " is ", tmp)
            if not best or diff > tmp then
                diff = tmp
                best = item
            end
            conn:close()
        end
    end

    return best
end

local function getOldLoginList (self, refreshLogin, checkForeign)
	self.message = "msgParsingOldLoginServers"

	local data = Settings.getItem(Settings.keyLoginList, "")
	if refreshLogin or data == "" then
		data = self:checkAllLoginServers(checkForeign)
	end

	self.agentList = {}

	local arr = {}
	for w in string.gmatch(data, "[^,]+") do
        table.insert(arr, w)
    end

    if #arr < 1 then
		arr = def_agent_list
    end

    for _, v in ipairs(arr) do
    	local host, port = string.match(v, "(%d+.%d+.%d+.%d+):(%d+)")
    	local one = {}
    	one.host = host
    	one.port = port

    	local r = tostring(math.random())
    	self.agentList[r] = one
    end
end
class.getOldLoginList = getOldLoginList

class.sendHeartBeat = function (self)
    local info = {}
    info.fromType  = protoTypes.CGGAME_PROTO_HEARTBEAT_FROM_CLIENT
    info.timestamp = skynet.time()

    local data = packetHelper:encodeMsg("CGGame.HeartBeat", info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                        protoTypes.CGGAME_PROTO_SUBTYPE_HEARTBEAT, data)
    self.remotesocket:sendPacket(packet)
    -- print("sendHeartBeat", self.remotesocket)
end

class.tryLogin = function (self)
	self.message = "msgTryLoginServers"

	for k, v in pairs(self.agentList) do
		local conn = RemoteSocket.create(v.host, v.port)
		if conn and conn.sockfd then
            if self.remotesocket then
                self.remotesocket:close()
                self.remotesocket = nil
            end

			self.remotesocket = conn
			print("agent to %s:%s success", v.host, v.port)
			return conn
		end
	end

	return nil
end

local function getLoginList (self)
    local info = {
        gameId = self.const.GAMEID,
    }
    local data = packetHelper:encodeMsg("CGGame.AgentList", info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
        protoTypes.CGGAME_PROTO_SUBTYPE_AGENTLIST, data)
	self.remotesocket:sendPacket(packet)
end
class.getLoginList = getLoginList

local function parseLoginList (self, packet)
    local m = packetHelper:decodeMsg("CGGame.ProtoInfo", packet)
    local p = packetHelper:decodeMsg("CGGame.AgentList", m.msgBody)

    local list = {}
	for k, v in ipairs(p.agentList or {}) do
        table.insert(list, string.format("%s:%d", v.addr, v.port))
	end
    local str = table.concat(list, ",")

	Settings.setItem(Settings.keyLoginList, str)
    return p.hallCount
end
class.parseLoginList = parseLoginList

--[[
local function getHallList (self, gameMode)
    local packet = self:hallPacket(gameMode, protoTypes.CGGAME_PROTO_SUBTYPE_LIST_DIRECT)
    self.remotesocket:sendPacket(packet)
end
class.getHallList = getHallList

local function parseHallList (self, packet, gameMode)
    if not packet then
        packet = class.raw_hall_list_packet or ""
    else
        class.raw_hall_list_packet = packet
    end

    local p = packetHelper:decodeMsg("CGGame.ProtoInfo", packet)
    p = packetHelper:decodeMsg("CGGame.InfoList", p.msgBody)

    gameMode = gameMode or 0

	local login = nil
	local list = p.server_list
    self.hallCount = 0
	for k, v in ipairs(list) do
        local myMode = v.gameInfo and v.gameInfo.gameMode or 0
        if gameMode == 0 or gameMode == myMode then
            if not login then
                login = string.format("%s:%d", v.addr, v.port)
            else
                login = login .. "," .. string.format("%s:%d", v.addr, v.port)
            end
            self.hallCount = self.hallCount + v.numPlayers + 1
        end
	end

    print ("hall count is ", self.hallCount)
    if not login then
        return
    end

	cc.UserDefault:getInstance():setIntegerForKey(keyHallCount, self.hallCount)
	cc.UserDefault:getInstance():flush()
end
class.parseHallList = parseHallList
--]]

local function tryHall (self, gameMode)
    local const = self.const

    local body          = {}
    body.gameId         = const.GAMEID
    body.gameMode       = gameMode or 0
    body.gameVersion    = const.GAMEVERSION
    body.lowVersion     = const.LOWVERSION and const.LOWVERSION or const.GAMEVERSION
    --- UniqueID here
    body.FUniqueID      = Settings.getPlayerId()

    local msgBody = packetHelper:encodeMsg("CGGame.GameInfo", body)

    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GETHALLLIST, listType, msgBody)
    return packet
end
class.tryHall = tryHall


return class

