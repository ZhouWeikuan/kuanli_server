------------------------------------------------------
---! @file
---! @brief MainInfo, 保存所有连接节点信息
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )


end)

