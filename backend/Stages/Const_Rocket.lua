-----------------------------------------------------
---! @file
---! @brief
------------------------------------------------------
local const = {}
setmetatable(const, {
    __index = function (t, k)
        return function()
            print("unknown field from const: ", k, t)
        end
    end
    })

const.GAMEID                = 3003
const.GAMEVERSION           = 20180901
const.LOWVERSION            = 20180901

const.epsilon         = 1e-06

const.kMaxFoodIndex     = 11


const.kModeMin        =   0
const.kModeMax        =   2

const.kModeTest       =   0
const.kModeFFA        =   1

const.kNoticeTypeKillings   =   1       -- 击杀数目
const.kNoticeTypeKilledBy   =   2       -- 被人杀死
const.kNoticeTypeSuicide    =   3       -- 撞墙而死
const.kNoticeTypeTopRank    =   4       -- 最高排名


-- node size range: [40, 160]  scale: [0.5, 2.0]
const.kNodeSize       = 40

-- const.kNodeDistance   = 32.0
const.kNodeInterval   = 2
const.kSpeedNormal    = 15
const.kIteratorNum    = 1

----------- types define start -------------
const.kTypeUnknown      = -1

const.kTypeFoodStart        = 1000
const.kTypeFoodEnd          = 1005  -- max 1099

const.kTypeFood_Rocket      = 1000
const.kTypeFood_Star        = 1001
const.kTypeFood_Shield      = 1002
const.kTypeFood_Speed       = 1003
const.kTypeFood_Light       = 1004
const.kTypeFood_Harm        = 1005


const.kTypePlaneStart       = 1100
const.kTypePlaneEnd         = 1100  -- max 1199

const.kTypeRocketStart      = 1200
const.kTypeRocketEnd        = 1200  -- max 1299

const.isFoodType = function (nodeType)
    nodeType = nodeType and nodeType or const.kTypeUnknown
    return (nodeType >= const.kTypeFoodStart and nodeType <= const.kTypeFoodEnd)
end

const.isPlaneType = function (nodeType)
    nodeType = nodeType and nodeType or const.kTypeUnknown
    return (nodeType >= const.kTypePlaneStart and nodeType <= const.kTypePlaneEnd)
end

const.isRocketType = function (nodeType)
    nodeType = nodeType and nodeType or const.kTypeUnknown
    return (nodeType >= const.kTypeRocketStart and nodeType <= const.kTypeRocketEnd)
end
---------- types define end --------------

---! action mask  for stageInfo.actionCode
const.kActionMaskSpeed          = 0x01      -- 加速
const.kActionMaskShield         = 0x02      -- 保护
const.kActionMaskLight          = 0x03      -- 闪电
const.kActionMaskHarmed         = 0x04      -- 被电到

const.kCostSpeed                = 5
const.kCostShield               = 10
const.kCostLight                = 5

---! game data, start from user define no. 100
const.ROCKET_GAMEDATA_START           = 100  -- 加入游戏，相当于join game?
const.ROCKET_GAMEDATA_MOVE            = 101  -- 移动方向，是绝对的，还是对当前方向有力道的改变(合成)？
const.ROCKET_GAMEDATA_ACTIONS         = 102  -- 更新操作码，根据actionMask来判断，比如是不是加速？
const.ROCKET_GAMEDATA_SPECTATE        = 103  -- 进入观察模式
const.ROCKET_GAMEDATA_NICKNAME        = 104  -- 设置昵称

const.ROCKET_GAMEDATA_SETBORDER       = 110
const.ROCKET_GAMEDATA_ADDNODE         = 111   -- PlayerInfo ? 你加入后服务器端发来你的消息
const.ROCKET_GAMEDATA_UPDATEPOSITION  = 112
const.ROCKET_GAMEDATA_CLEARNODE       = 113   -- 清除自己
const.ROCKET_GAMEDATA_DRAWLINE        = 114
const.ROCKET_GAMEDATA_LEADERBOARD     = 115
const.ROCKET_GAMEDATA_UPDATENODES     = 116


--! acl status
const.ROCKET_ACL_STATUS_VERSION_MISMATCH =   101  -- 版本不对


return const

