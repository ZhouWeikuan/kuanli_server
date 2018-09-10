-------------------------------------------------------------
---! @file
---! @brief web socket的客户连接
--------------------------------------------------------------

---!
local skynet = require "skynet"

---!
local clsHelper = require "ClusterHelper"
local taskHelper = require "TaskHelper"

local AgentUtils = require "AgentUtils"

---!
local agentInfo = {}
local agentUtil = nil
local client_sock = nil

local handler = {}
function handler.on_open(ws)
    agentInfo.last_update = os.time()
end

function handler.on_message(ws, msg)
    agentInfo.last_update = os.time()

    local worker = function ()
        agentUtil:command_handler(msg)
    end

    xpcall( function()
        taskHelper.queue_task(worker)
    end,
    function(err)
        skynet.error(err)
        skynet.error(debug.traceback())
    end)
end

function handler.on_error(ws, msg)
    agentUtil:kickMe()
end

function handler.on_close(ws, code, reason)
    agentUtil:kickMe()
end

---!
local utilCallBack = {}

---!
local CMD = {}

---! @brief start service
function CMD.start (info, header)
    if client_sock then
        return
    end

    for k, v in pairs(info) do
        agentInfo[k] = v
    end

    local id = info.client_fd
    socket.start(id)
    pcall(function ()
        client_sock = websocket.new(id, header, handler)
    end)
    if client_sock then
        skynet.fork(function ()
            client_sock:start()
        end)
    end

    agentInfo.last_update = skynet.time()
    skynet.fork(function()
        local heartbeat = 3   -- 3 seconds to send heart beat
        local timeout   = 10  -- 10 seconds to break
        while true do
            local now = skynet.time()
            if now - agentInfo.last_update >= timeout then
                agentUtil:kickMe()
                return
            end

            agentUtil:sendHeartBeat()
            skynet.sleep(heartbeat * 100)
        end
    end)

    return 0
end

---! send protocal back to user socket
function CMD.sendProtocolPacket (packet)
    if client_sock then
        client_sock:send_binary(packet)
    end
end


---! @brief 通知agent主动结束
function CMD.disconnect ()
    agentUtil:hallReqQuit()

    if client_sock then
        client_sock:close()
        client_sock = nil
    end

    skynet.exit()
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

    agentInfo.agentSign = os.time()
    agentUtil = AgentUtils.create(agentInfo, CMD, utilCallBack)
end)

