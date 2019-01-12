-------------------------------------------------------------
---! @file
---! @brief watchdog, 监控游戏连接
--------------------------------------------------------------

---! 系统依赖
local skynet    = require "skynet"
local cluster   = require "skynet.cluster"
local socket    = require "skynet.socket"
local httpd     = require "http.httpd"
local sockethelper = require "http.sockethelper"

---! 辅助依赖
local clsHelper = require "ClusterHelper"
local NumSet    = require "NumSet"

local myInfo = nil
---! NodeInfo's address
local nodeInfo = nil
---! gateserver's gate service
local gate  = nil
local web_sock_id = nil

---! all agents
local tcpAgents = NumSet.create()
local webAgents = NumSet.create()

---! @brief close agent on socket fd
local function close_agent(fd)
    local info = webAgents:getObject(fd)
    if info then
        webAgents:removeObject(fd)
        ---! close web socket, kick web agent
        pcall(skynet.send, info.agent, "lua", "disconnect")
        return
    end

    info = tcpAgents:getObject(fd)
    if info then
        tcpAgents:removeObject(fd)

        ---! close tcp socket, kick tcp agent
        pcall(skynet.send, info.agent, "lua", "disconnect")
    else
        skynet.error("unable to close agent, fd = ", fd)
    end
end

---!  socket handlings, SOCKET.error, SOCKET.warning, SOCKET.data
---!         may not called after we transfer it to agent
local SOCKET = {}

---! @brief new client from gate, start an agent and trasfer fd to agent
function SOCKET.open(fd, addr)
    local info = tcpAgents:getObject(fd)
    if info then
        close_agent(fd)
    end

    skynet.error("watchdog tcp agent start", fd, addr)
    local agent = skynet.newservice("TcpAgent")

    info = {}
    info.watchdog   = skynet.self()
    info.gate       = gate
    info.client_fd  = fd
    info.address    = string.gsub(addr, ":%d+", "")
    info.agent      = agent
    info.appName    = myInfo.appName

    tcpAgents:addObject(info, fd)

    skynet.call(agent, "lua", "start", info)
    return 0
end

---! @brief close fd, is this called after we transfer it to agent ?
function SOCKET.close(fd)
    skynet.error("socket close",fd)

    skynet.timeout(10, function()
        close_agent(fd)
    end)

    return ""
end

---! @brief error on socket, is this called after we transfer it to agent ?
function SOCKET.error(fd, msg)
    skynet.error("socket error", fd, msg)

    skynet.timeout(10, function()
        close_agent(fd)
    end)
end

---! @brief warnings on socket, is this called after we transfer it to agent ?
function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    skynet.error("socket warning", fd, size)
end

---! @brief packets on socket, is this called after we transfer it to agent ?
function SOCKET.data(fd, msg)
end

---! skynet service handlings
local CMD = {}

---! @brief this function may not be called after we transfer fd to agent
function CMD.closeAgent(fd)
    skynet.timeout(10, function()
        close_agent(fd)
    end)

    return 0
end

---! @brief place holder, we may use it later
function CMD.noticeAll (msg)
    webAgents:forEach(function (info)
        pcall(skynet.send, info.agent, "lua", "sendProtocolPacket", msg)
    end)

    tcpAgents:forEach(function (info)
        pcall(skynet.send, info.agent, "lua", "sendProtocolPacket", msg)
    end)

    return 0
end

function CMD.getStat ()
    local stat = {}
    stat.web = webAgents:getCount()
    stat.tcp = tcpAgents:getCount()
    stat.sum = stat.web + stat.tcp
    return stat
end

function CMD.gateOff ()
    if gate then
        xpcall(function ()
            skynet.call(gate, "lua", "close")
        end,
        function (err)
            print("gateOff -> close gate: error is ", err)
        end)
    end
    if web_sock_id then
        xpcall(function ()
            socket.close(web_sock_id)
        end,
        function (err)
            print("gateOff -> close web: error is ", err)
        end)
    end
end

---! 注册LoginWatchDog的处理函数，一种是skynet服务，一种是socket
local function registerDispatch ()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            if f then
                f(...)
            else
                skynet.error("unknown sub command ", subcmd, " for cmd ", cmd)
            end
            -- socket api don't need return
        else
            local f = CMD[cmd]
            if f then
                local ret = f(subcmd, ...)
                if ret then
                    skynet.ret(skynet.pack(ret))
                end
            else
                skynet.error("unknown command ", cmd)
            end
        end
    end)
end

---! 处理 web socket 连接
local function handle_web(id, addr)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
    if code and url == "/tun" then
        local info = webAgents:getObject(id)
        if info then
            close_agent(id)
        end

        skynet.error("watchdog web agent start", id, addr)
        local agent = skynet.newservice("WebAgent")

        local info = {}
        info.watchdog   = skynet.self()
        info.gate       = nil
        info.client_fd  = id
        info.address    = string.gsub(addr, ":%d+", "")
        info.agent      = agent
        info.appName    = myInfo.appName

        webAgents:addObject(info, id)
        skynet.call(agent, "lua", "start", info, header)
    end
end

---! 开启 watchdog 功能, tcp/web
local function startWatch ()
    ---! 获得NodeInfo 服务 注册自己
    nodeInfo = skynet.uniqueservice(clsHelper.kNodeInfo)
    skynet.call(nodeInfo, "lua", "updateConfig", skynet.self(), clsHelper.kWatchDog)

    myInfo = skynet.call(nodeInfo, "lua", "getConfig", "nodeInfo")

    ---! 启动gate
    local publicAddr = "0.0.0.0"
    gate = skynet.newservice("gate")
    skynet.call(gate, "lua", "open", {
        address = publicAddr,
        port = myInfo.tcpPort,  ---! 监听端口 8200 + serverIndex
        maxclient = 2048,       ---! 最多允许 2048 个外部连接同时建立  注意本数值，当客户端很多时，避免阻塞
        nodelay = true,         ---! 给外部连接设置  TCP_NODELAY 属性
    })

    -- web tunnel, 监听 8300 + serverIndex
    local address = string.format("%s:%d", publicAddr, myInfo.webPort)
    local id = assert(socket.listen(address))
    web_sock_id = id
    socket.start(id , function(id, addr)
        socket.start(id)
        xpcall(function ()
            handle_web(id, addr)
        end,
        function (err)
            print("error is ", err)
        end)
    end)
end

-- 心跳, 汇报在线人数
local function loopReport ()
    local timeout = 60  -- 60 seconds
    while true do
        local stat = CMD.getStat()
        skynet.call(nodeInfo, "lua", "updateConfig", stat.sum, "nodeInfo", "numPlayers")
        local ret, nodeLink = pcall(skynet.call, nodeInfo, "lua", "getServiceAddr", clsHelper.kNodeLink)
        if ret and nodeLink ~= "" then
            pcall(skynet.send, nodeLink, "lua", "heartBeat", stat.sum)
        end

        skynet.sleep(timeout * 100)
    end
end

---! 启动函数
skynet.start(function()
    registerDispatch()
    startWatch()
    skynet.fork(loopReport)
end)

