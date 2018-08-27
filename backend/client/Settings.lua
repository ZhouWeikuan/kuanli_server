local crypt = require "skynet.crypt"

local tableHelper = require "TableHelper"

local path = "client/saved.tmp"
local data = nil

---! create the class metatable
local class = {}

---! class variables
class.keyAgentList = "com.cronlygames.agentservers.list"
class.keyHallCount = "com.cronlygames.hallservers.count"
class.keyGameMode  = "com.cronlygames.gameMode"

class.base64AuthChallenge = "com.cronlygames.auth.challenge"
class.base64AuthSecret    = "com.cronlygames.auth.secret"
class.keyAuthIndex        = "com.cronlygames.auth.index"

class.keyUsername = "com.cronlygames.auth.username"
class.keyPassword = "com.cronlygames.auth.password"
class.keyNickname = "com.cronlygames.auth.nickname"

---! class functions
class.load = function ()
    local f = io.open(path)
    if not f then
        data = {}
        return
    end
    local source = f:read "*a"
    f:close()
    data = tableHelper.decode(source) or {}
end

class.save = function ()
    local f = io.open(path, "w")
    if not f then
        return
    end
    local text = tableHelper.encode(data)
    f:write(text)
    f:close()
end

class.getItem = function (key, def)
    if not data then
        class.load()
    end
    def = def or ""
    return data[key] or def
end

class.setItem = function (key, obj)
    if not data then
        class.load()
    end

    data[key] = obj or ""
    class.save()
end

class.getAuthInfo = function ()
    local ret = {}
    ret.username = class.getItem(class.keyUsername)
    if ret.username == "" then
        class.setItem(class.keyUsername, "G:1293841824")
        class.setItem(class.keyPassword, "apple")
        class.setItem(class.keyNickname, "test")
    end

    ret.username    = class.getItem(class.keyUsername)
    ret.password    = class.getItem(class.keyPassword)
    ret.nickname    = class.getItem(class.keyNickname)
    ret.authIndex   = class.getItem(class.keyAuthIndex, 0)
    ret.challenge   = crypt.base64decode(class.getItem(class.base64AuthChallenge))
    ret.secret      = crypt.base64decode(class.getItem(class.base64AuthSecret))
    return ret
end


return class

