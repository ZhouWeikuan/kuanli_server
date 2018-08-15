-------------------------------------------------------------
---! @file  NodeInfo.lua
---! @brief 保存当前节点信息，供其它服务使用
--------------------------------------------------------------

local skynet    = require "skynet"
local cluster   = require "skynet.cluster"

local clusterHelper = require "ClusterHelper"

---! 信息
local info = {}

---! 接口
local CMD = {}

function CMD.initNode ()
    clusterHelper.parseConfig(info)

    cluster.reload(info.clusterList)
    cluster.open(info.appName)

    return 0
end

function CMD.getConfig (...)
    local args = table.pack(...)
    local ret = info
    for _, key in ipairs(args) do
        if ret[key] then
            ret = ret[key]
        else
            return -1
        end
    end

    ret = ret or -1
    return ret
end

function CMD.updateConfig (value, ...)
    local args = table.pack(...)
    local last = table.remove(args)
    local ret = info
    for _, key in ipairs(args) do
        local one = ret[key]
        if not one then
            one = {}
            ret[key] = one
        elseif type(one) ~= "table" then
            return -1
        end
        ret = one
    end

    ret[last] = value
    return 0
end


---! 启动函数
skynet.start(function()
    ---! 注册skynet消息服务
    skynet.dispatch("lua", function(_,_, cmd, ...)
        local f = CMD[cmd]
        if f then
            local ret = f(...)
            if ret then
                skynet.ret(skynet.pack(ret))
            end
        else
            skynet.error("unknown command ", cmd)
        end
    end)
end)

