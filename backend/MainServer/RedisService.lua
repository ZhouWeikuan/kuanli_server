------------------------------------------------------
---! @file
---! @brief DBService, 数据库服务，调用redis/mysql
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
local redis     = require "skynet.db.redis"

---! 帮助库
local clsHelper    = require "ClusterHelper"

---! 全局常量
local conf
local redis_conn
local wait_list = {}

---! 从哨兵那里获取真正的master
local function get_master_info ()
    local conn = {
        port = conf.port,
    }
    for _, h in ipairs(conf.hosts) do
        conn.host = h
        local ret, db = pcall(redis.connect, conn)
        if ret and db then
            local ret = db:sentinel("get-master-addr-by-name", "master")
            db:disconnect()
            return ret[1], ret[2]
        end
    end
end

---! 恢复等候的队列
local function resume ()
    while true do
        local co = table.remove(wait_list)
        if not co then
            return
        end
        skynet.wakeup(co)
    end
end

---! do make
local function do_make_redis_conn ()
    local conn = {}
    conn.host, conn.port = get_master_info ()
    if not conn.host then
        return
    end

	local ret, db = pcall(redis.connect, conn)
    if ret and db then
        if redis_conn then
            redis_conn:disconnect()
        end
        redis_conn = db
        resume()
        return true
    else
        skynet.error("can't connect to master", conn.host, conn.port)
    end
end

---! make a redis connection
local function make_redis_conn ()
    if redis_conn then
        return
    end

    local ret
    repeat
        ret = pcall(do_make_redis_conn)
        skynet.sleep(100)
    until ret
end

---! wait for connection
local function pause ()
    skynet.fork(make_redis_conn)
    local co = coroutine.running()
    table.insert(wait_list, co)
    skynet.wait(co)
end

---! run redis command in protected mode
local function checked_call (cmd, key, ...)
    while true do
        if not redis_conn then
            pause()
        end
        local ret, val = pcall(redis_conn[cmd], redis_conn, key, ...)
        if not ret then
            skynet.error("redis cmd failed", cmd, key, ...)
            redis_conn:disconnect()
            redis_conn = nil
            pause()
        else
            return val or ""
        end
    end
end

---! generate redis path
local function format_path (tableName, keyName, keyValue)
    return string.format("DB_CGGame.%s.%s.%s", tableName, keyName, keyValue)
end

---! lua commands
local CMD = {}

---! run redis cmd
function CMD.runCmd (cmd, key, ...)
    return checked_call(cmd, key, ...)
end

---! load db from redis
function CMD.loadDB (tableName, keyName, keyValue, info)
    local path = format_path(tableName, keyName, keyValue)
    for field, value in pairs(info) do
        local old = checked_call("HGET", path, field)
        checked_call("HSET", path, field, value)
    end
    return checked_call("EXPIRE", path, conf.expire)
end

---! update to redis, and mysql; 直接覆盖
function CMD.updateDB (tableName, keyName, keyValue, fieldName, fieldValue)
    local path = format_path(tableName, keyName, keyValue)
    checked_call("HSET", path, fieldName, fieldValue)
    return checked_call("EXPIRE", path, conf.expire)
end

---! 增量修改
function CMD.deltaDB (tableName, keyName, keyValue, fieldName, deltaValue)
    local path = format_path(tableName, keyName, keyValue)
    checked_call("HINCRBYFLOAT", path, fieldName, deltaValue)
    return checked_call("EXPIRE", path, conf.expire)
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

    ---! 加载配置
    local packetHelper  = require "PacketHelper"
    conf = packetHelper.load_config("./config/config.redis")

    ---! 注册自己的地址
    local srv = skynet.uniqueservice(clsHelper.kNodeInfo)
    skynet.call(srv, "lua", "updateConfig", skynet.self(), clsHelper.kRedisService)
end)

