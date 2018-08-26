local skynet = require "skynet"

local class = {}

---! class functions
local wait_list = {}

class.resume = function ()
    local co = table.remove(wait_list)
    if not co then
        return
    end
    skynet.wakeup(co)
end

class.pause = function ()
    local co = coroutine.running()
    table.insert(wait_list, co)
    skynet.wait(co)
end

return class

