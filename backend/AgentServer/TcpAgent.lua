--------------------------------------------------------------
---! @file
---! @brief tcp socket的客户连接
--------------------------------------------------------------

---! 依赖库
local skynet = require "skynet"
local socket = require "skynet.socket"

---! 帮助库
local clsHelper = require "ClusterHelper"
local taskHelper = require "TaskHelper"

local AgentUtils = require "AgentUtils"

---! 全局变量
local agentInfo = {}
local agentUtil = nil

---! 回调和命令
local utilCallBack = {}
local CMD = {}

---! @brief start service
function CMD.start (info)
    for k, v in pairs(info) do
        agentInfo[k] = v
    end

    skynet.error("CMD start called on fd ", agentInfo.client_fd)
    skynet.call(agentInfo.gate, "lua", "forward", agentInfo.client_fd)

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
    if agentInfo.client_fd then
        local data = string.pack(">s2", packet)
        socket.write(agentInfo.client_fd, data)
    end
end

---! @brief 通知agent主动结束
function CMD.disconnect ()
    agentUtil:hallReqQuit()

    if agentInfo.client_fd then
        socket.close(agentInfo.client_fd)
    end

    skynet.exit()
end

---! handle socket data
skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return skynet.tostring(msg,sz)
	end,
	dispatch = function (session, address, text)
        skynet.ignoreret()

        agentInfo.last_update = skynet.time()

        local worker = function ()
            agentUtil:command_handler(text)
        end

        xpcall( function()
            taskHelper.queue_task(worker)
        end,
        function(err)
            skynet.error(err)
            skynet.error(debug.traceback())
        end)
	end
}

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

