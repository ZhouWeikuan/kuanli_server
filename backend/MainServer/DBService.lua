------------------------------------------------------
---! @file
---! @brief DBService, 数据库服务，调用redis/mysql
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
local cluster   = require "skynet.cluster"

---! 帮助库
local clsHelper    = require "ClusterHelper"

---! 全局常量
local redis_srv
local mysql_srv

---! lua commands
local CMD = {}

---! 单独执行 sql 命令
function CMD.execDB (cmd)
    return skynet.call(mysql_srv, "lua", "execDB", cmd)
end

---! 单独执行 redis 命令
function CMD.runCmd (cmd, key, ...)
    return skynet.call(redis_srv, "lua", "runCmd", cmd, key, ...)
end

---! load from mysql, and update redis too
function CMD.loadDB (tableName, keyName, keyValue, noInsert)
    local ret = skynet.call(mysql_srv, "lua", "loadDB", tableName, keyName, keyValue, noInsert)
    skynet.call(redis_srv, "lua", "loadDB", tableName, keyName, keyValue, ret)
    return ret
end

---! update to redis, and mysql; 直接覆盖
function CMD.updateDB (tableName, keyName, keyValue, fieldName, fieldValue)
    local ret = skynet.call(mysql_srv, "lua", "updateDB", tableName, keyName, keyValue, fieldName, fieldValue)
    ret = ret and skynet.call(redis_srv, "lua", "updateDB", tableName, keyName, keyValue, fieldName, fieldValue)
    return ret
end

---! 增量修改
function CMD.deltaDB (tableName, keyName, keyValue, fieldName, deltaValue)
    local ret = skynet.call(mysql_srv, "lua", "deltaDB", tableName, keyName, keyValue, fieldName, deltaValue)
    ret = ret and skynet.call(redis_srv, "lua", "deltaDB", tableName, keyName, keyValue, fieldName, deltaValue)
    return ret
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

    ---! 启动 redis & mysql 服务
    redis_srv = skynet.newservice("RedisService")
    mysql_srv = skynet.newservice("MySQLService")

    ---! 注册自己的地址
    local srv = skynet.uniqueservice(clsHelper.kNodeInfo)
    skynet.call(srv, "lua", "updateConfig", skynet.self(), clsHelper.kDBService)
end)

