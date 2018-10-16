---! 实现一个碰撞矩形
local class = {mt = {}}
class.mt.__index = class

---! center point for (x, y) with half width and half height(default half width if not set)
class.create = function(x, y, hw, hh)
    hh = hh or hw
    local self = {
        leftX  = x - hw,
        bottomY  = y - hh,
        rightX  = x + hw,
        topY  = y + hh,
    }

    setmetatable(self, class.mt)
    return self
end

---! 上下左右线
class.createWithBox = function(l, r, b, t)
    local x = (l + r)/2
    local y = (b + t)/2
    local w = (r - l)/2
    local h = (t - b)/2

    return class.create(x, y, w, h)
end

class.debug = function(self)
    local debugHelper = require "DebugHelper"
    local box = self
    debugHelper.cclog(" (%f, %f, %f, %f)", box.leftX, box.rightX, box.bottomY, box.topY)
end

---! 中心点位置
class.getCenter = function(self)
    local x = (self.leftX + self.rightX) / 2
    local y = (self.bottomY + self.topY) / 2
    return x, y
end

---! 宽 高
class.getSize  = function (self)
    local w = (self.rightX - self.leftX)
    local h = (self.topY - self.bottomY)

    return w,h
end

---! 拆分成4个小矩形
class.getSplits = function(self)
    local boxes = {}
    local w,h = self:getSize()
    local x,y = self:getCenter()

    local hw, hh = w/4, h/4

    table.insert(boxes, class.create(x+hw, y+hh, hw, hh))
    table.insert(boxes, class.create(x-hw, y+hh, hw, hh))
    table.insert(boxes, class.create(x-hw, y-hh, hw, hh))
    table.insert(boxes, class.create(x+hw, y-hh, hw, hh))

    return boxes
end

---! 相交测试
class.intersect = function(self, other)
    return self.leftX < other.rightX and self.rightX > other.leftX and self.bottomY < other.topY and self.topY > other.bottomY
end

---! 矩形 包含测试
class.containsBox = function(self, other)
    return self.leftX <= other.leftX and self.rightX >= other.rightX and self.bottomY <= other.bottomY and self.topY >= other.topY
end

---! 点包含测试
class.containsPoint = function(self, x, y)
    return (x >= self.leftX and x <= self.rightX) and (y >= self.bottomY and y <= self.topY)
end

return class

