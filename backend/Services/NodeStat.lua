-------------------------------------------------------------
---! @file  NodeDebug.lua
---! @brief 调试当前节点，获取运行信息
--------------------------------------------------------------

local skynet = require "skynet"

local function dump_info()
    local srv = skynet.uniqueservice("NodeInfo")
    local name = skynet.call(srv, "lua", "getConfig", "appName")
    local ret = table.concat({"Curr Node: ", skynet.self(), "appName", name}, "\t")
    return ret
end

skynet.start(function()
    skynet.info_func(dump_info)
end)

