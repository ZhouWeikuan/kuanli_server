-------------------------------------------------------------
---! @file  NodeLink.lua
---! @brief 监控当前节点，察觉异常退出
--------------------------------------------------------------

---! 依赖
local skynet = require "skynet"
local cluster = require "skynet.cluster"

local clsHelper = require "ClusterHelper"

---! 信息
local nodeInfo = nil
local theMainNode = nil

---! 保持远程节点，对方断线时切换
local function holdMainServer(thisInfo, list)
    if theMainNode then
        return
    end

    for _, appName in ipairs(list) do
        local addr = clsHelper.cluster_addr(appName, clsHelper.kNodeLink)
        if addr then
            theMainNode = appName
            skynet.call(nodeInfo, "lua", "updateConfig", appName, clsHelper.kMainNode)

            local mainInfoAddr = clsHelper.cluster_addr(appName, clsHelper.kMainInfo)
            pcall(cluster.call, appName, mainInfoAddr, "regNode", thisInfo)

            skynet.fork(function()
                skynet.error("hold the main server", appName)
                pcall(cluster.call, appName, addr, "LINK", true)
                skynet.error("disconnect the main server", appName)

                theMainNode = nil
                skynet.call(nodeInfo, "lua", "updateConfig", nil, clsHelper.kMainNode)
                holdMainServer(thisInfo, list)
            end)
            return
        end
    end
end

---! 向 MainServer 注册自己
local function registerSelf ()
    if theMainNode then
        return
    end

    local thisInfo = skynet.call(nodeInfo, "lua", "getRegisterInfo")
    skynet.error("thisInfo.kind = ", thisInfo.kind)
    if thisInfo.kind == clsHelper.kMainServer then
        skynet.error("MainServer should not register itself", thisInfo.name)
        return
    end

    local list = skynet.call(nodeInfo, "lua", "getConfig", clsHelper.kMainServer)
    holdMainServer(thisInfo, list)
end

---! 通讯
local CMD = {}

---! 收到通知，需要向cluster里的MainServer注册自己
function CMD.askReg ()
    skynet.fork(registerSelf)
    return 0
end

---! 收到通知，结束本服务
function CMD.exit ()
    skynet.exit()

    return 0
end

function CMD.LINK (hold)
    if hold then
        skynet.wait()
    end
    skynet.error("return from LINK")
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

