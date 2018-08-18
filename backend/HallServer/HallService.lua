-------------------------------------------------------------
---! @file  HallService
---! @brief 游戏大厅核心服务
--------------------------------------------------------------

---!
local skynet = require "skynet"

---!
local clsHelper = require "ClusterHelper"
local packetHelper = require "PacketHelper"

---!
local hallInterface = nil

---!
local CMD = {}

function CMD.createInterface (conf)
    -- hallInterface = hallInterface or packetHelper.createObject(conf.Interface, conf)

    return ""
end

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

    ---! 获得NodeInfo 服务 注册自己
    local nodeInfo = skynet.uniqueservice(clsHelper.kNodeInfo)
    skynet.call(nodeInfo, "lua", "updateConfig", skynet.self(), clsHelper.kHallService)
end)

