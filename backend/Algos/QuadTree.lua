---! 四叉树

local NumSet = require "NumSet"
local debugHelper = require "DebugHelper"

local class = {mt = {}}
class.mt.__index = class

class.maxDepth = 6
class.maxNodeCount = 16
-- class.maxNodeCount = 2

class.create = function(box, parent)
    local self = {
        box         = box,
        parent      = parent,
        children    = nil,

        nodes       = NumSet.create(),
    }

    if parent and parent.depth then
        self.depth = parent.depth + 1
    else
        self.depth = 0
    end

    setmetatable(self, class.mt)
    return self
end

class.checkObjectBox = function(self, box, nodeFunc, childFunc, checkIntersect)
    if not self.children then
        if self.nodes:getCount() > class.maxNodeCount then
            self:createChildren()
        end
    end

    if self.children then
        for _, tree in ipairs(self.children) do
            if tree.box:containsBox(box) then
                childFunc(tree)
                if not checkIntersect then
                    return
                end
            elseif checkIntersect and tree.box:intersect(box) then
                childFunc(tree)
            end
        end
    end

    nodeFunc(self)
end

class.moveObjectsToChildren = function(self)
    if not self.children then
        return
    end

    local list = NumSet.create()
    self.nodes:forEach(function(obj)
        local alone = true
        for _, child in ipairs(self.children) do
            if child.box:containsBox(obj.box) then
                child:addObject(obj)
                alone = nil
                break
            end
        end

        if alone then
            list:addObject(obj)
        end
    end)

    self.nodes = list
end

class.createChildren = function(self)
    if self.depth >= class.maxDepth or self.children then
        return
    end

    self.children = {}
    local boxes = self.box:getSplits()
    for _, box in ipairs(boxes) do
        local tree = class.create(box, self)
        table.insert(self.children, tree)
    end

    self:moveObjectsToChildren()
end

class.isEmpty = function(self)
    return self.nodes:getCount() <= 0 and self.children == nil
end

class.checkChildren = function(self)
    if self.children then
        for _, child in ipairs(self.children) do
            if not child:isEmpty() then
                return
            end
        end
        self.children = nil
    end

    if self:isEmpty() and self.parent then
        self.parent:checkChildren()
    end
end

class.addNodeObject = function(self, entity)
    if not self.nodes:hasObject(entity) then
        entity.treeNode = self
        self.nodes:addObject(entity)
    end
end

class.addObject = function(self, entity)
    assert(entity.box ~= nil)
    self:checkObjectBox(entity.box, function(node)
        node:addNodeObject(entity)
    end,
    function(tree)
        tree:addObject(entity)
    end)
end

class.removeObject = function(self, entity)
    assert(entity.box ~= nil)
    local tree = entity.treeNode
    if not tree or not tree.nodes:hasObject(entity) then
        xpcall(function ()
            debugHelper.cclog("remove node %s failed", tostring(entity.nodeId))
            debugHelper.cclog(debug.traceback())
            debugHelper.printDeepTable(entity, 1)
            debugHelper.printDeepTable(tree, 1)
        end,
        function(err)
            print(err)
        end)
        return
    end

    entity.treeNode = nil
    tree.nodes:removeObject(entity)
    if tree.nodes:getCount() <= 0 then
        tree:checkChildren()
    end
end

class.updateObject = function(self, entity)
    self:removeObject(entity)
    self:addObject(entity)
end

class.queryBox = function(self, box, handler)
    self:checkObjectBox(box, function(tree)
        tree.nodes:forEach(function(obj)
            handler(obj)
        end)
    end,
    function(subtree)
        subtree:queryBox(box, handler)
    end,
    true)
end

class.applyAnyTree = function(self, handler, except, box)
    local ret = nil
    self.nodes:forEach(function(obj)
        if handler(obj) then
            ret = obj
            return true
        end
    end)
    if ret then
        return ret
    end

    if self.children then
        for _, tree in ipairs(self.children) do
            if tree ~= except and tree.box:intersect(box) then
                ret = tree:applyAnyTree(handler, nil, box)
                if ret then
                    return ret
                end
            end
        end
    end
    return ret
end

class.findLeafNode = function(self, point)
    if not self.children then
        return self
    end

    for _, tree in ipairs(self.children) do
        if tree.box:containsPoint(point.x, point.y) then
            return tree:findLeafNode(point)
        end
    end
    return nil
end

class.queryNearObject = function(self, box, handler)
    local x, y = box:getCenter()
    local point = {x = x, y = y}
    local ret = nil
    local leaf = self:findLeafNode(point)
    local unuse = nil
    while leaf and leaf.box:intersect(box) do
        ret = leaf:applyAnyTree(handler, unuse, box)
        if ret then
            break;
        end

        unuse = leaf
        leaf = leaf.parent
    end

    return ret
end

class.traverseTree = function(self, handler)
    handler(self)

    if self.children then
        for _, child in ipairs(self.children) do
            child:traverseTree(handler)
        end
    end
end

return class

