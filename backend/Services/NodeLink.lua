-------------------------------------------------------------
---! @file  NodeLink.lua
---! @brief 监控当前节点，察觉异常退出
--------------------------------------------------------------

local skynet = require "skynet"

local clsHelper = require "ClusterHelper"

local nodeInfo = nil

---! 向 MainServer 注册自己
local function registerSelf ()
    local thisInfo = skynet.call(nodeInfo, "lua", "getConfig", "nodeInfo")
    skynet.error("thisInfo.serverKind = ", thisInfo.serverKind)
    if thisInfo.serverKind == clsHelper.kMainServer then
        return
    end
end

---! 通讯
local CMD = {}

---! 收到通知，需要向cluster里的MainServer注册自己
function CMD.askReg ()
    skynet.error("ask this node to register")
    return 0
end

---! 收到通知，结束本服务
function CMD.exit ()
    skynet.exit()

    return 0
end

---! 启动服务
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

    ---! 向NodeInfo注册自己
    nodeInfo = skynet.uniqueservice("NodeInfo")
    skynet.call(nodeInfo, "lua", "nodeOn", skynet.self())

    ---! 通知MainServer
    skynet.fork(registerSelf)

end)

