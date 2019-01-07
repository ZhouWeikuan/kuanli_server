-------------------------------------------------------------
---! @file  NodeInfo.lua
---! @brief 保存当前节点信息，供其它服务使用
--------------------------------------------------------------

---! 依赖
local skynet    = require "skynet"
local cluster   = require "skynet.cluster"

local clsHelper = require "ClusterHelper"

---! 信息
local info = {}

---! 接口
local CMD = {}

function CMD.initNode ()
    clsHelper.parseConfig(info)

    return ""
end

function CMD.getServiceAddr(key)
    local ret = info[key]
    ret = ret or ""
    return ret
end

function CMD.getConfig (...)
    local args = table.pack(...)
    local ret = info
    for _, key in ipairs(args) do
        if ret[key] then
            ret = ret[key]
        else
            return ""
        end
    end

    ret = ret or ""
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
            return ""
        end
        ret = one
    end

    ret[last] = value
    return ""
end

---! 获得本节点的注册信息
function CMD.getRegisterInfo ()
    local nodeInfo = info.nodeInfo
    local ret = {}
    ret.kind = nodeInfo.serverKind
    ret.name = nodeInfo.appName
    ret.addr = nodeInfo.privAddr
    ret.port = nodeInfo.debugPort
    ret.numPlayers = nodeInfo.numPlayers

    ret.conf = info[clsHelper.kHallConfig]

    return ret
end

---! 下线NodeLink
local function doNodeOff ()
    local old = info[clsHelper.kNodeLink]
    if old then
        skynet.send(old, "lua", "exit")
        info[clsHelper.kNodeLink] = nil
    end
end

---! 实时监控NodeLink
local function monitorMyNodeLink (nodeLink)
    pcall(skynet.call, nodeLink, "debug", "LINK")
    skynet.error("my nodelink is offline", nodeLink)
    if info[clsHelper.kNodeLink] == nodeLink then
        info[clsHelper.kNodeLink] = nil
    end
end

---! 收到通知，NodeLink已经上线
function CMD.nodeOn (nodeLink)
    doNodeOff()

    info[clsHelper.kNodeLink] = nodeLink
    skynet.fork(function()
        monitorMyNodeLink(nodeLink)
    end)

    return ""
end

---! 获得下线通知
function CMD.nodeOff ()
    doNodeOff()

    ---! 通知 MainInfo, MainServer;
    ---!    HallService, HallServer
    ---!    watchDog, AgentServer
    local poss = {clsHelper.kMainInfo, clsHelper.kHallService, clsHelper.kWatchDog}
    for _, name in ipairs(poss) do
        old = info[name]
        if old then
            skynet.send(old, "lua", "nodeOff")
        end
    end

    return ""
end


---! 启动函数
skynet.start(function()
    cluster.register("NodeInfo", skynet.self())
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

