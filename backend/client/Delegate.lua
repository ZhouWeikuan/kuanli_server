local skynet = require "skynet"

local WaitList = require "WaitList"
local LoginHelper = require "LoginHelper"
local AuthUtils = require "AuthUtils"

local BotPlayer = require "BotPlayer_YunCheng"

local protoTypes = require "ProtoTypes"
local const = require "Const_YunCheng"

---! create the class metatable
local class = {mt = {}}
class.mt.__index = class


---! create delegate object
class.create = function ()
    local self = {}
    setmetatable(self, class.mt)

    self.exes = WaitList.create()

    class.initAuth()
    self.authInfo = AuthUtils.getAuthInfo()

    self.lastUpdate = skynet.time()
    self.login = LoginHelper.create(const)

    local agent = BotPlayer.create(self, self.authInfo)
    self.agent  = agent

    return self
end

class.initAuth = function ()
    AuthUtils.setItem(AuthUtils.keyPlayerId, "G:1293841824")
    AuthUtils.setItem(AuthUtils.keyPassword, "apple")
    AuthUtils.setItem(AuthUtils.keyNickname, "test")
    AuthUtils.setItem(AuthUtils.keyOSType, "client")
    AuthUtils.setItem(AuthUtils.keyPlatform, "client")
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

    self.exes:resume()
end

class.stage_login = function (self)
    local login = self.login
    login:getOldLoginList(true, true)

    self.exes:pause()

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
    self.exes:pause()

    skynet.sleep(100)
    login:getAgentList()
    self.exes:pause()

    skynet.sleep(100)
    self.agent:sendAuthOptions(protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME)

    while not self.authOK do
        self.exes:pause()
    end
    print("auth OK!")

    login:tryGame()
    self.exes:pause()

    skynet.sleep(100)
    self.agent:sendSitDownOptions()
    self.exes:pause()

    return true
end

return class

