------------------------------------------------------
---! @file
---! @brief AgentServer的启动文件
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
local cluster   = require "skynet.cluster"

---! helper class
local clsHelper     = require "ClusterHelper"
local Delegate      = require "Delegate"

local delegate = nil

local function main_loop ()
    delegate:stage_login()
end

local function tickFrame ()
    while true do
        delegate:tickFrame()
        skynet.sleep(10)
    end
end

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

    delegate = Delegate.create()

    skynet.fork(tickFrame)
    skynet.fork(main_loop)
end)

