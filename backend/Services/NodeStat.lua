-------------------------------------------------------------
---! @file  NodeStat.lua
---! @brief 调试当前节点，获取运行信息
--------------------------------------------------------------

---!
local skynet = require "skynet"

---!
local clsHelper = require "ClusterHelper"
local strHelper = require "StringHelper"

local function main_info ()
    local srv = skynet.uniqueservice("MainInfo")
    return skynet.call(srv, "lua", "getStat")
end

local function dump_info()
    local srv = skynet.uniqueservice("NodeInfo")
    local nodeInfo = skynet.call(srv, "lua", "getConfig", "nodeInfo")
    if nodeInfo.serverKind == clsHelper.kMainServer then
        return main_info()
    end

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

