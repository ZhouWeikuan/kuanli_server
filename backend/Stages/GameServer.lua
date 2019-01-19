local skynet        = skynet or require "skynet"
-- use skynet.init to determine server or client

local protoTypes    = require "ProtoTypes"
local packetHelper  = (require "PacketHelper").create("protos/CGGame.pb")

local class = {mt = {}}
class.mt.__index = class

class.create = function (hallInterface)
    local self = {}
    setmetatable(self, class.mt)

    self.hallInterface  = hallInterface
    self.config         = hallInterface.config

    return self
end

---! @brief 发送给玩家的游戏数据
---! @brief 发送游戏数据到用户
---! @param uid         用户Id
---! @param subType     数据类型
---! @param data        数据内容
class.SendGameDataToUser = function (self, code, subType, data)
    if not subType or subType == 0 then
        print(debug.traceback())
    end
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME, subType, data);
    self.hallInterface:gamePacketToUser(packet, code)
end

---!@brief  TODO 注释函数作用
---!@param userInfo        用户信息
---!@param data            TODO 注释data意义
class.handleGameData = function (self, userInfo, gameType, data)
    print ("Unknown game data, subType = ", gameType)
end

return class

