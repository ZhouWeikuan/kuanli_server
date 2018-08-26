
---!
local NumSet = require "NumSet"

---! HallInterface
local class = {mt = {}}
class.mt.__index = class

---! creator
class.create = function (conf)
    local self = {}
    setmetatable(self, class.mt)
    self.config = conf

    --- self.onlineUser 存放用户信息，可以通过getObject()获得其中的用户信息data【uid】
    self.onlineUsers = NumSet.create()

    return self
end


return class

-
