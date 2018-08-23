---------------------------------------------------
---! @file
---! @brief 任务处理辅助
---------------------------------------------------

---! 依赖库 skynet
local skynet    = require "skynet"
local queue = require "skynet.queue"

---! 顺序序列
local critical  = nil

---! TaskHelper 模块定义
local class = {}

---! @brief 执行异步任务worker, 如果有callback，对返回值进行callback(ret)处理
---! @param worker 异步的任务
---! @param callback 任务完成时的回调
---! @note skynet服务可能会阻塞，尽量不要改变状态
local function async_task(worker, callback)
    skynet.fork(function()
        local ret = worker()
        if callback then
            callback(ret)
        end
    end)
end
class.async_task = async_task

---! @brief 把worker加入执行序列 按顺序执行
---! @brief worker 需要执行的任务序列 一般是一个函数
local function queue_task(worker)
    if not critical then
        critical = queue()
    end
    critical(worker)
end
class.queue_task = queue_task

---! @brief close a agent gate's socket
---! @param agent client's agent gate
---! @sock socket
local function closeGateAgent(gate, sock)
    skynet.call(gate, "lua", "kick", sock)
end
class.closeGateAgent = closeGateAgent


return class

