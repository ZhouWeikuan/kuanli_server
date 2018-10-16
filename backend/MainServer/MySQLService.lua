------------------------------------------------------
---! @file
---! @brief DBService, 数据库服务，调用redis/mysql
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
local mysql     = require "skynet.db.mysql"

---! 帮助库
local clsHelper    = require "ClusterHelper"

---! 全局常量
local hosts
local conf
local mysql_conn
local wait_list = {}

---! 恢复之前的执行序列
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
local function do_make_mysql_conn (host)
    conf.host = host
	local db = mysql.connect(conf)
    if db then
        if mysql_conn then
            mysql_conn:disconnect()
        end
        mysql_conn = db
        resume()
        return true
    else
        skynet.error("can't connect to mysql ", conf.host, conf.port)
    end
end

---! 连接到数据库
local function make_mysql_conn ()
    if mysql_conn then
        return
    end

    local ret
    repeat
        for _, h in ipairs(hosts) do
            ret = pcall(do_make_mysql_conn, h)
            if ret then
                break
            end
        end
        skynet.sleep(100)
    until ret
end

---! mysql数据库连接不正常，暂停
local function pause ()
    skynet.fork(make_mysql_conn)
    local co = coroutine.running()
    table.insert(wait_list, co)
    skynet.wait(co)
end

---! checked call sql cmd
local function checked_call (cmd)
    while true do
        if not mysql_conn then
            pause()
        end
        local ret, val = pcall(mysql_conn.query, mysql_conn, cmd)
        if not ret then
            mysql_conn:disconnect()
            mysql_conn = nil
            pause()
        else
            return val
        end
    end
end


---! lua commands
local CMD = {}

---! exec sql command
function CMD.execDB (cmd)
    return checked_call(cmd)
end

---! load all from table
function CMD.loadDB (tableName, keyName, keyValue, noInsert)
    local cmd = string.format("SELECT * FROM %s WHERE %s='%s' LIMIT 1", tableName, keyName, keyValue)
    local ret = checked_call(cmd)
    local row = ret[1] or {}

    ---! insert where there is no such key/value
    if not noInsert and not row[keyName] then
        skynet.error(keyName, "=", keyValue, "is not found in ", tableName, ", should insert")
        local ins = string.format("INSERT %s (%s) VALUES ('%s')", tableName, keyName, keyValue)
        ret = checked_call(ins)

        ret = checked_call(cmd)
        row = ret[1] or {}
    end

    return row
end

---! update value
function CMD.updateDB (tableName, keyName, keyValue, fieldName, fieldValue)
    local cmd = string.format("UPDATE %s SET %s='%s' WHERE %s='%s'",
                        tableName, fieldName, fieldValue, keyName, keyValue)
    return checked_call(cmd)
end

---! delta value
function CMD.deltaDB (tableName, keyName, keyValue, fieldName, deltaValue)
    local cmd = string.format("UPDATE %s SET %s=%s+'%s' WHERE %s='%s'",
                        tableName, fieldName, fieldName,
                        deltaValue, keyName, keyValue)
    return checked_call(cmd)
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
    local config = packetHelper.load_config("./config/config.mysql")
    conf  = config.DB_Conf
    conf.on_connect = function (db)
        db:query("set charset utf8");
    end

    hosts = config.Hosts

    ---! 注册自己的地址
    local srv = skynet.uniqueservice(clsHelper.kNodeInfo)
    skynet.call(srv, "lua", "updateConfig", skynet.self(), clsHelper.kMySQLService)
end)

