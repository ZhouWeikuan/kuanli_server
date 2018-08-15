---------------------------------------------------
---! @file
---! @brief 远程集群节点调用辅助 ClusterHelper
---------------------------------------------------

---! 依赖库 skynet
local skynet    = require "skynet"
local snax      = require "skynet.snax"
local cluster   = require "skynet.cluster"

local packetHelper = require "PacketHelper"

---! ClusterHelper 模块定义
local class = {}

class.getAllNodes = function (cfg)
    local all = {"AgentServer", "GameServer", "MainServer"}
    local ret = {}
    for nodeName, nodeValue in pairs(cfg.MySite) do
        for _, serverName in ipairs(all) do
            local srv = cfg[serverName]
            for i=0,srv.maxIndex do
                local name  = string.format("%s_%s%d", nodeName, serverName, i)
                local value = string.format("%s:%d", nodeValue[1], srv.nodePort + i)
                ret[name] = value
            end
        end
    end
    return ret
end

class.getNodeInfo = function (cfg)
    local ret = {}
    ret.name    = skynet.getenv("NodeName")

    local node = cfg.MySite[ret.name]
    ret.privateAddr = node[1]
    ret.publicAddr  = node[2]

    return ret
end

class.getServerInfo = function (cfg)
    local ret = {}
    ret.kind    = skynet.getenv("ServerName")
    ret.index   = tonumber(skynet.getenv("ServerNo"))
    ret.name    = ret.kind .. ret.index

    local conf = cfg[ret.kind]
    assert(ret.index >= 0 and ret.index <= conf.maxIndex )
    local all = {"debugPort", "tcpPort", "webPort"}
    for _, one in ipairs(all) do
        if conf[one] then
            ret[one] = conf[one] + ret.index
        end
    end

    return ret
end

class.parseConfig = function (info)
    local cfg = packetHelper.load_config("./config/config.nodes")

    info.appName        = skynet.getenv("app_name")
    info.node           = class.getNodeInfo(cfg)
    info.server         = class.getServerInfo(cfg)
    info.clusterList    = class.getAllNodes(cfg)
end

return class

