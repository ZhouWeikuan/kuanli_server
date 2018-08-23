-------------------------------------------------------------
---! @file  NodeStat.lua
---! @brief 调试当前节点，获取运行信息
--------------------------------------------------------------

---! 依赖库
local skynet = require "skynet"

---! 帮助
local clsHelper = require "ClusterHelper"
local strHelper = require "StringHelper"

---! MainServer信息
local function main_info ()
    local srv = skynet.uniqueservice("MainInfo")
    return skynet.call(srv, "lua", "getStat")
end

---! AgentServer信息
local function agent_info (nodeInfo, watchdog)
    local stat = skynet.call(watchdog, "lua", "getStat")
    local arr = {nodeInfo.appName}
    table.insert(arr, string.format("Web: %d", stat.web))
    table.insert(arr, string.format("Tcp: %d", stat.tcp))
    table.insert(arr, string.format("总人数: %d", stat.sum))
    return strHelper.join(arr, "\t")
end

---! 显示节点信息
local function dump_info()
    local srv = skynet.uniqueservice("NodeInfo")
    local nodeInfo = skynet.call(srv, "lua", "getConfig", "nodeInfo")
    if nodeInfo.serverKind == clsHelper.kMainServer then
        return main_info()
    end

    local watchdog = skynet.call(srv, "lua", "getServiceAddr", clsHelper.kWatchDog)
    if watchdog ~= "" then
        return agent_info(nodeInfo, watchdog)
    end

    ---! HallServer信息
    local arr = {nodeInfo.appName}
    local conf = skynet.call(srv, "lua", "getConfig", clsHelper.kHallConfig)
    if conf ~= "" then
        table.insert(arr, conf.HallName)
        table.insert(arr, string.format("gameId: %d", conf.GameId))
    end

    table.insert(arr, string.format("num: %d", nodeInfo.numPlayers))
    local ret = strHelper.join(arr, "\t")
    return ret
end

skynet.start(function()
    skynet.info_func(dump_info)
end)

