local skynet = require "skynet"

local WaitList = require "WaitList"
local LoginHelper = require "LoginHelper"
local Settings = require "Settings"

local BotPlayer = require "Base_BotPlayer"

local protoTypes = require "ProtoTypes"
local const = require "Const_Landlord"

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

class.command_handler  = function (self, packet)
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
    login:tryConnect()
    login:getAgentList()

    self.agent:sendAuthOptions(protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME)

    while not self.authOK do
        print("wait for authOK")
        WaitList.pause()
    end
    print("auth OK!")

    -- local packet = login:tryHall(Settings.getItem(Settings.keyGameMode, 0))
    -- agent:sendPacket(packet)
end

class.stage_loop = function (self)
    while true do
        if self.agent and self.login and self.login.remotesocket then
            local p = self.login.remotesocket:recvPacket()
            if p then
                self.agent:recvPacket(p)
            end
        end
    end
end

---! main loop for delegate
class.main_loop = function (self)
    self:stage_login()
    self:stage_loop()
end


return class

