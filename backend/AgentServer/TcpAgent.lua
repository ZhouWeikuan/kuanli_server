-------------------------------------------------------------
---! @file
---! @brief tcp socket的客户连接
--------------------------------------------------------------

---! 依赖库
local skynet = require "skynet"

---! 帮助库
local clsHelper = require "ClusterHelper"
local taskHelper = require "TaskHelper"

local AgentUtils = require "AgentUtils"

---! 全局变量
local userInfo  = {}
local agentInfo = {}
local agentUtil = nil

---! 回调和命令
local utilCallBack = {}
local CMD = {}

---! @brief start service
function CMD.start (info)
    agentInfo = info

    skynet.error("CMD start called on fd ", agentInfo.client_fd)

    skynet.call(agentInfo.gate, "lua", "forward", agentInfo.client_fd)
    userInfo.client_sock = agentInfo.client_fd

    agentInfo.last_update = skynet.time()
    skynet.fork(function()
        local heartbeat = 7   -- 7 seconds to send heart beat
        local timeout   = 60  -- 60 seconds, 1 minutes
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

function CMD.sendProtocolPacket (packet)
    if agentInfo.client_fd then
        local data = string.pack(">s2", packet)
        socket.write(agentInfo.client_fd, data)
    end
end

---! @brief 通知agent主动结束
function CMD.disconnect ()
    agentUtil:reqQuit(agentInfo.client_fd)

    skynet.exit()
end


skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return skynet.tostring(msg,sz)
	end,
	dispatch = function (session, address, text)
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

    userInfo.sign = os.time()
    agentUtil = AgentUtils.create(agentInfo, userInfo, CMD, utilCallBack)
end)

