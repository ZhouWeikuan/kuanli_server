local skynet = require "skynet"

local WaitList = require "WaitList"
local LoginHelper = require "LoginHelper"
local Settings = require "Settings"

local BotPlayer = require "BotPlayer_Base"

local protoTypes = require "ProtoTypes"
local const = require "Const_YunCheng"

---! create the class metatable
local class = {mt = {}}
class.mt.__index = class


---! create delegate object
class.create = function ()
    local self = {}
    setmetatable(self, class.mt)

    self.authInfo = Settings.getAuthInfo()

    self.lastUpdate = skynet.time()
    self.login = LoginHelper.create(const)

    local agent = BotPlayer.create(self, self.authInfo)
    self.agent  = agent

    return self
end

class.command_handler  = function (self, user, packet)
    local login = self.login
    if login.remotesocket then
        login.remotesocket:sendPacket(packet)
    end
end

class.tickFrame = function (self)
    local now = skynet.time()
    local login = self.login
    --[[
    if login:tickCheck(self) then
        -- local networkLayer = require "NetworkLayer"
        -- networkLayer.create(self)

        self.lastUpdate = now
    end
    --]]

    local delta = now - self.lastUpdate
    if delta > 3.0 then
        login:closeSocket()
    elseif delta > 1.0 then
        login:sendHeartBeat()
    end

    while login.remotesocket do
        local p = login.remotesocket:recvPacket()
        if p then
            self.lastUpdate = now
            self.agent:recvPacket(p)
        else
            break
        end
    end

    self.agent:tickFrame()
end

class.stage_login = function (self)
    local login = self.login
    login:getOldLoginList(true, true)

    local hasAgent = nil
    for k, v in pairs(login.agentList) do
        hasAgent = true
        break
    end
    if not hasAgent then
        print("no agent list found")
        return
    end

    skynet.sleep(100)
    login:tryConnect()

    skynet.sleep(100)
    login:getAgentList()

    skynet.sleep(100)
    self.agent:sendAuthOptions(protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME)

    while not self.authOK do
        WaitList.pause()
    end
    print("auth OK!")

    login:tryGame()

    skynet.sleep(100)
    self.agent:sendSitDownOptions()
end

class.stage_loop = function (self)
    while true do
        self:tickFrame(0.2)
        skynet.sleep(20)
    end
end

---! main loop for delegate
class.main_loop = function (self)
    self:stage_login()
    self:stage_loop()
end


return class

