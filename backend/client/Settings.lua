local tableHelper = require "TableHelper"

local path = "client/saved.tmp"
local data = nil

---! create the class metatable
local class = {}

---! class variables
class.keyAgentList = "com.cronlygames.agentservers.list"
class.keyHallCount = "com.cronlygames.hallservers.count"
class.keyGameMode  = "com.cronlygames.gameMode"

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
    local f = io.open(path, "w+")
    if not f then
        return
    end
    local text = tableHelper.encode(data)
    f:write(text)
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

return class

