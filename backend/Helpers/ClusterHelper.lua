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

---! 防止读nil的key
setmetatable(class, {
    __index = function (t, k)
        return function()
            print("retrieve unknown field from ClusterHelper: ", k)
        end
    end
    })

---! 节点类型常量 serverKind
class.kNodeInfo = "NodeInfo"
class.kNodeLink = "NodeLink"
class.kMainInfo = "MainInfo"
class.kMainNode = "MainNode"

class.kAgentServer = "AgentServer"
class.kHallServer  = "HallServer"
class.kMainServer  = "MainServer"

class.kHallConfig   = "HallConfig"
class.kHallService  = "HallService"
class.kDBService    = "DBService"
class.kMySQLService = "MySQLService"
class.kRedisService = "RedisService"
class.kWatchDog     = "WatchDog"

---! 获取config.cluster列表和各服务器列表
class.getAllNodes = function (cfg, info)
    local all = {class.kAgentServer, class.kHallServer, class.kMainServer}
    local ret = {}
    for nodeName, nodeValue in pairs(cfg.MySite) do
        for _, serverKind in ipairs(all) do
            local list = info[serverKind] or {}
            info[serverKind] = list

            if not nodeValue[2] and serverKind == class.kAgentServer then
                -- AgentServer must have public address
            else
                local srv = cfg[serverKind]
                for i=0,srv.maxIndex do
                    local name  = string.format("%s_%s%d", nodeName, serverKind, i)
                    local value = string.format("%s:%d", nodeValue[1], srv.nodePort + i)
                    ret[name] = value
                    table.insert(list, name)
                end
            end
        end
    end
    return ret
end

---! 获取当前节点信息
class.getNodeInfo = function (cfg)
    local ret = {}
    ret.appName     = skynet.getenv("app_name")
    ret.nodeName    = skynet.getenv("NodeName")

    local node = cfg.MySite[ret.nodeName]
    ret.privAddr = node[1]
    ret.publAddr = node[2]

    ret.serverKind    = skynet.getenv("ServerKind")
    ret.serverIndex   = tonumber(skynet.getenv("ServerNo"))
    ret.serverName    = ret.serverKind .. ret.serverIndex
    ret.numPlayers    = 0

    local conf = cfg[ret.serverKind]
    assert(ret.serverIndex >= 0 and ret.serverIndex <= conf.maxIndex )
    local all = {"debugPort", "tcpPort", "webPort"}
    for _, one in ipairs(all) do
        if conf[one] then
            ret[one] = conf[one] + ret.serverIndex
        end
    end

    return ret
end

---! 解析集群内节点配置
class.parseConfig = function (info)
    local cfg = packetHelper.load_config("./config/config.nodes")

    info.nodeInfo       = class.getNodeInfo(cfg)
    info.clusterList    = class.getAllNodes(cfg, info)
end

-----------------------------------------------------
---! @brief create a handy proxy to skynet service on other cluster node
---! @note node is cluster app, addr is an address or @REG_NAME
-----------------------------------------------------
local function skynet_proxy(node, addr)
    if not node then
        return
    end

    local ret, proxy = pcall(cluster.proxy, node, addr)
    if proxy == nil then
        skynet.error(node, " is not online")
    end

    return proxy
end
class.skynet_proxy = skynet_proxy

-----------------------------------------------------------
---! @brief via proxy, safely call to skynet service on other cluster node,
---! @note node is cluster app, addr is an address or @REG_NAME
---! handler should be like this:
---! @code
---! function(proxy)
---!     skynet.call(proxy, "lua", name, addr, config)
---! end
---! @endcode
-------------------------------------------------------------
local function proxy_call (node, addr, handler)
    local proxy = skynet_proxy(node, addr)
    if proxy then
        handler(proxy)
    end
end
class.proxy_call = proxy_call


---! get an address for remote service that register in appNode:NodeInfo
class.cluster_addr = function (app, service)
    local proxyName = "@" .. class.kNodeInfo
    if service == class.kNodeInfo then
        return proxyName
    end

    local ret, addr = pcall(cluster.call, app, proxyName, "getServiceAddr", service)
    if not ret then
        skynet.error(app, "is not online")
        return
    elseif addr == "" then
        skynet.error(app, "can't get", service, "from NodeInfo's config")
        return
    end
    return addr
end

---! get a proxy for cluster's node: app, serviceName: service
class.cluster_proxy = function (app, service)
    local addr = class.cluster_addr(app, service)
    if not addr then
        return
    end

    proxy = class.skynet_proxy(app, addr)
    if not proxy then
        skynet.error(app, "or ", service, "is not online")
    end
    return proxy
end

---! execute handler in cluster's node: app, serviceName: service
class.cluster_action = function (app, service, handler)
    local proxy = class.cluster_proxy(app, service)
    if not proxy then
        return
    end

    handler(proxy)
end

class.getMainAppAddr = function (service)
    local nodeInfo = skynet.uniqueservice("NodeInfo")
    local appName = skynet.call(nodeInfo, "lua", "getConfig", class.kMainNode)
    if not appName then
        return
    end

    local addr = class.cluster_addr(appName, service)
    return appName, addr
end


return class

