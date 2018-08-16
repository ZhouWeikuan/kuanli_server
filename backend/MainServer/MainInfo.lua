------------------------------------------------------
---! @file
---! @brief MainInfo, 保存所有连接节点信息
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"

local clsHelper = require "ClusterHelper"

---! 全局常量
local nodeInfo = nil
local appName = nil

local info = {}

---! detect master MainServer
local function do_detectMaster (list)
    for _, app in ipairs(list) do
        if app >= appName then
            return
        end

        local proxy = clsHelper.cluster_proxy(app, clsHelper.kNodeLink)
        if proxy then
            pcall(skynet.call, nodeInfo, "lua", "nodeOff")
            skynet.sleep(3 * 100)
            skynet.newservice("NodeLink")
            return
        end
    end
end

---! loop in the back to detect master
local function detectMaster ()
    local list = skynet.call(nodeInfo, "lua", "getConfig", clsHelper.kMainServer)
    table.sort(list, function (a, b)
        return a < b
    end)

    while true do
        detectMaster(list)

        local sec = 10
        skynet.sleep(sec * 100)
    end
end

---! lua commands
local CMD = {}

---! ask all possible nodes to register them
function CMD.askAll ()
    local all = skynet.call(nodeInfo, "lua", "getConfig", clsHelper.kAgentServer)
    local list = skynet.call(nodeInfo, "lua", "getConfig", clsHelper.kHallServer)
    for _, v in ipairs(list) do
        table.insert(all, v)
    end

    local func = function (proxy)
        pcall(skynet.call, proxy, "lua", "askReg")
    end
    for _, app in ipairs(all) do
        clsHelper.cluster_action(app, clsHelper.kNodeLink, func)
    end
end

---! node info to register
function CMD.regNode ()

    return
end

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

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

    ---! 获得NodeInfo 服务
    nodeInfo = skynet.uniqueservice(clsHelper.kNodeInfo)
    skynet.call(nodeInfo, "lua", "updateConfig", clsHelper.kMainInfo, skynet.self())

    appName = skynet.call(nodeInfo, "lua", "getConfig", "nodeInfo", "appName")

    ---! ask all nodes to register
    skynet.fork(CMD.askAll)

    ---! run in the back, detect master
    skynet.fork(detectMaster)
end)

