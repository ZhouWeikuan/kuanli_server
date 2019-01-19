local skynet = skynet or require "skynet"

require "Cocos2dServer"

local Box = require "Box"
local NumSet = require "NumSet"

local packetHelper  = require "PacketHelper"

local const     = require "Const_Rocket"

local math = math

local class = {mt = {}}
class.mt.__index = class

class.create = function (gameServer)
    local self = {}
    setmetatable(self, class.mt)

    local userInfo  = self:createClient()
    self.userInfo   = userInfo
    self.gameServer = gameServer

    self.disconnect = -1
    self.name = userInfo.FNickName or ""

    self.nodeAdditionQueue  = NumSet.create()
    self.nodeDestroyQueue   = NumSet.create()
    self.visibleNodes       = NumSet.create()

    self.isBot      = true
    self.skin       = nil
    self.score      = 0

    self.plane              = nil
    self.moveDir            = nil

    self.tickViewBox        = 0
    self.tickPlane          = 0

    self.teamId     = nil

    local config = gameServer.config
    -- Viewing box
    self.centerPos = cc.p((config.BorderLeft + config.BorderRight) * 0.5,
                        (config.BorderTop + config.BorderBottom) * 0.5)
    self.box = Box.createWithBox(self.centerPos.x, self.centerPos.x, self.centerPos.y, self.centerPos.y);

    -- Gamemode function
    if gameServer then
        gameServer.gameMode:onPlayerInit(self);
    end

    return self
end

local botNames = {
    "Flash You", "Chase Me", "Gentle Kiss", "Let me fly", "Reddit", "CIA", "Sina", "Baidu", "QQ", "Sir", "Russia",
    "Circle", "Line", "Curve", "FBI", "Facebook", "Apple", "Google", "NASA", "God", "Eve", "Parasite", "Square",
    "Round", "Bug", "Ice", "India", "Arab", "South Korea", "Germany", "Uber", "Blade", "Japan", "IRS", "USA", "China",
    "Hong Kong", "Qing Dynasty", "Prodota", "Harry Potter", "Steam", "Ireland", "Tumblr", "Canada", "Sun", "Tailand",
    "Taiwan", "England", "加油", "Lenovo", "HIV", "AIDS", "ISIS", "Train", "Car", "Truck", "Auto", "BMW", "BYD", "Cherry",
    "Twig", "Tank 90", "Gomoku Online", "Chess Online", "Lucky Stars", "Fruits Link", "放飞自己", "大胆爱", "围住你", "喷气",
    "吐火", "毒龙", "闪电", "lightning", "bad guy", "拖尾", "tail", "turning", "反围剿", "摇曳生姿", "翱翔", "展翅", "fly", "wings",
    "Pets", "Ludo Online", "Fishing", "Free Cell", "Checkers", "Little Stars", "Mahjong Gril", "撞死你", "玉米蛇", "蜿蜒",
    "伯劳", "蜂鸟", "秃鹫", "蛇雕", "雄鹰", "燕子", "apache", "阿帕奇", "鸵鸟", "黄鹂", "百灵", "翠鸟", "鹃隼", "白头翁", "白鹭",
    "信天翁", "孔雀", "喜鹊", "金鸡", "锦鸡", "天鹅", "goose", "swan", "bird", "大雁", "杜鹃", "山雀", "企鹅", "鹦鹉", "苇莺", "燕鸥",
    "loon", "penguin", "petrel", "grebe", "flamingo", "stork", "duck", "crane", "wader", "owl", "auk", "swift", "roller", "hawk",
    "eagle", "hornbill", "woodpecker", "啄木鸟", "pilot", "jay", "magpie", "crow", "raven", "robin", "swallow", "lark", "myna",
    "大国崛起", "大中华", "中国万岁", "我是屎", "合作共赢", "求合体", "我是女生", "Little Girl", "LadyGaga", "爬行动物", "五毛",
    "共和党", "民主自由", "民主女神", "中国合作", "强国人", "来战", "消灭棒子", "缠住你", "轻轻地咬一口", "0.0", "o^o", "o_o", "醉了",
    "饿死鬼投胎", "群魔乱舞", "我爱北京天安门", "女儿红", "状元红", "盘绕", "高铁", "观察员", "Turkey", "吃我是小狗", "汪汪", "小强",
    "庆丰包子", "肉包子来打狗", "窒息", "小猫钓鱼","蛇影杯弓", "Struck","茶叶蛋", "谁吃谁怀孕", "雅蔑蝶", "龟儿子吃我", "贱气侧漏", "隔壁老王",
    "有种你别跑", "有种你别追", "大王派我来巡山", "火箭炮", "空天飞机", "飞艇", "无人驾驶", "自动送货", "不怕死", "来撞我啊", "无头苍蝇",
    "Sunbeam", "soooos", "凤姐说爱你", "罗密欧和猪过夜", "唐伯虎点蚊香", "你爹武大郎", "卖身不卖艺", "东邪吸毒", "南帝缺钙", "Stiletto",
    "北帝卖菜", "贪吃蛇在线", "撑死你", "导弹大作战", "飞机大作战", "细胞吞食", "龙虎斗", "东海龙王", "NX-25", "P-45", "RM-10", "V-65",
    "F-16", "F-117A", "AH-46", "白金汉", "Buckingham", "爱快-Z1", "Alpha-Z1", "原子飞船", "Atomic Blimp", "西部雀鹰", "Western Besra",
    "货机", "Cargo Plane", "古邦", "Cuban", "嘟嘟鸟", "Dodo", "洒药机", "Duster", "霍华德", "Howard", "九头蛇喷射机", "Hydra", "巨像",
    "Mammoth", "喷射机", "Jet", "LF-22", "星椋", "LF-22 Starling", "乐梭", "Luxor", "特技飞机", "Mallard", "天行巨兽", "Mammatus",
    "军用喷射机", "Miljet", "莫古尔", "Mogul", "尼姆巴思", "Nimbus", "诺科塔", "Nokota", "天煞", "Lazer", "邦布须卡", "Bombushka", "恶棍",
    "Rogue", "海风", "Seabreeze", "夏玛尔客机", "Shamal", "泰坦号", "Titan", "图拉", "Tula", "轻极", "Ultralight", "莫洛托克", "Molotok",
    "梅杜莎", "Velum", "威斯特拉", "Vestra", "希罗飞船", "Xero Blimp", "狂焰", "Pyro", "复仇者", "Avenger",  "沃拉托", "Volatol",
    "单翼飞机", "monoplane", "滑翔机", "glider", "水上飞机", "seaplane", "超音速", "supersonic", "波音", "Boeing", "协和", "Concord",
    "依柳辛", "Ilyusin", "麦道", "McDonald-Douglas", "三叉戟", "Trident", "图波列夫", "Tupolev", "空中客车", "Airbus", "亚音速", "subsonic",
    "上海宽立", "宽立斗地主", "宽立拖拉机", "宽立八十分",  "空档接龙", "俄罗斯方块", "中国跳棋在线", "中国象棋在线", "宽立中国象棋",  "摘下满天星",
    "闪闪满天星", "宽立21点", "宽立诈金花", "宽立德州扑克", "国际象棋在线", "美女找茬", "Beauty Hunt", "坦克大战", "90坦克", "飞行棋在线",
    "五子棋在线", "麻将十三张", "麻将二人行", "果蔬连连看", "宠物连连看", "CronlyGames", "宽立信息技术",
}

class.getNextBotName = function (self)
    class.botNames = class.botNames or {}
    local num = #class.botNames
    if num <= 0 then
        for i, v in ipairs(botNames) do
            class.botNames[i] = v
        end
        num = #class.botNames
    end
    local idx = math.random(1, num)
    local name = class.botNames[idx]
    table.remove(class.botNames, idx)
    return name
end

class.createClient = function (self)
    local userInfo = {
        FNickName = "",
    }
    userInfo.playerTracker = self
    return userInfo
end

class.sendNickname = function (self)
    self.userInfo.FNickName = self:getNextBotName()
    local nameInfo = {
        nickname = self.userInfo.FNickName,
    }

    self.gameServer:setNickname(self, nameInfo)
end

-- Setters/Getters
class.setName = function(self, name)
    self.name = name
end

class.getName = function(self)
    return self.name
end

class.setSkin = function(self, skin)
    local one = self.gameServer:getOneSkin(skin)
    self.skin = one
end

class.getSkin = function(self)
    if not self.skin then
        class.setSkin()
    end
    return self.skin
end

class.getScore = function(self, reCalcScore)
    if reCalcScore then
        local s = 0
        if self.plane then
            s = self.plane.histScore
        end
        self.score = s
    end
    return self.score
end

class.getTeam = function(self)
    return self.teamId
end

-- handle game data from server
class.handleGameData = function(self, subType, data)
end

class.updateCenter = function(self) -- Get center of cells
    if not self.plane then
        return  -- End the function if no cells exist
    end

    local pos = self.plane.position
    self.centerPos.x = pos.x
    self.centerPos.y = pos.y
end

class.calcViewBox = function(self, distance)
    -- Main function
    self:updateCenter()

    -- Box
    self.box = Box.create(self.centerPos.x, self.centerPos.y, distance, distance)

    local tree = self.gameServer.clientTree
    tree:updateObject(self)

    local newVisible = NumSet.create()
    self.gameServer.nodeTree:queryBox(self.box, function(node)
        if self.box:intersect(node.box) then
            -- Cell is in range of view box
            newVisible:addObject(node);
        end
    end)

    return newVisible
end

-- Functions
class.update = function(self)
    -- Actions buffer (So that people cant spam packets)
    local gameServer    = self.gameServer
    local updateNodes   = NumSet.create()  -- Nodes that need to be updated via packet

    -- Get visible nodes every 400 ms
    local nonVisibleNodes = NumSet.create()  -- Nodes that are not visible
    if (self.tickViewBox <= 0) then
        -- Reset Ticks
        self.tickViewBox = 20

        if self.plane then
            local dis = const.kSpeedNormal * const.kNodeInterval * 22
            if self.plane.buffs[const.kTypeFood_Speed] then
                dis = dis * 2.4
            end
            self.visibleNodes = self:calcViewBox(dis)
            self:decide()
        else
            self.tickPlane = self.tickPlane + 1
            if self.tickPlane > 30 then
                self.tickPlane = 0
                self:sendNickname()
            end
        end

        self.tickViewBox = self.tickViewBox - 18
    else
        self.tickViewBox = self.tickViewBox - 1
    end

    self.nodeDestroyQueue:clear()       -- Reset destroy queue
    self.nodeAdditionQueue:clear()      -- Reset addition queue
end

class.calcWeight = function (node, other, isEnemy)
    local myPos     = cc.p(node.position.x, node.position.y)
    local otherPos  = cc.p(other.position.x, other.position.y)

    local dis       = cc.pGetDistance(myPos, otherPos)
    local range     = const.kSpeedNormal * const.kNodeInterval * 16
    if isEnemy and dis > range then
        return nil
    elseif not isEnemy and dis < range * 0.10 then
        return nil
    end

    local vec = nil
    if isEnemy then
        vec = cc.pSub(myPos, otherPos)

        local meet = node:getSize() + other:getSize()
        if dis < meet * 3 and other.moveDir then
            if cc.pCross(vec, other.moveDir) <= 0 then
                vec = cc.pPerp(vec)
            else
                vec = cc.RPerp(vec)
            end
        end
    else
        vec = cc.pSub(otherPos, myPos)
    end
    vec = cc.pNormalize(vec)

    local factor = 4.0/(dis * dis)
    vec = cc.pMul(vec, factor)

    return factor, vec
end

class.decide = function (self)
    local dir = self.moveDir
    if not dir then
        dir = cc.pForAngle(math.rad(math.random(1, 360)))
    end

    local findHarm, findFood = nil, nil
    local harmDir  = cc.p(0, 0)
    local foodDir  = cc.p(0, 0)

    local gameServer = self.gameServer
    local gameMode   = gameServer.gameMode
    local plane  = self.plane

    local half   = const.kSpeedNormal * const.kNodeInterval * 8
    local config = gameServer.config
    local newPos = plane.position

    local diffX = math.min(newPos.x - config.BorderLeft, config.BorderRight - newPos.x)
    local diffY = math.min(config.BorderTop - newPos.y, newPos.y - config.BorderBottom)
    if diffX < diffY then
        if (newPos.x - half <= config.BorderLeft and dir.x < 0) or (newPos.x + half >= config.BorderRight and dir.x > 0) then
            findHarm        = true
            self.moveDir    = cc.p(-dir.x, dir.y)
            harmDir         = cc.pMul(self.moveDir, 4.0/(diffX * diffX))
        end
    else
        if (newPos.y - half <= config.BorderBottom and dir.y < 0) or (newPos.y + half >= config.BorderTop and dir.y > 0) then
            findHarm        = true
            self.moveDir    = cc.p(dir.x, -dir.y)
            harmDir         = cc.pMul(self.moveDir, 4.0/(diffY * diffY))
        end
    end

    self.visibleNodes:forEach(function(one)
        if plane == one then
            return
        end

        if const.isPlaneType(one.nodeType) then
            self:checkUseLight(one)
        end

        if const.isPlaneType(one.nodeType) or
            const.isRocketType(one.nodeType) or
            one.nodeType == const.kTypeFood_Rocket then

            local add, pos = class.calcWeight(plane, one, true)
            if add then
                findHarm = true
                harmDir = cc.pAdd(harmDir, pos)
            end
        elseif const.isFoodType(one.nodeType) then
            local add, pos = class.calcWeight(plane, one)
            if add and (not findFood or findFood < add) then
                findFood = add
                foodDir  = cc.pAdd(foodDir, pos)
            end
        end
    end)

    local newActionCode = 0
    if findHarm then
        dir = harmDir
        self:tryActionCodes()
    elseif findFood then
        dir = foodDir
    end

    self.moveDir = cc.pNormalize(dir)
end

class.checkUseLight = function (self, one)
    if one.buffs[const.kTypeFood_Harm] then
        -- already harmed
        return
    end

    local plane = self.plane
    if plane.buffs[const.kTypeFood_Light] or plane.currScore < const.kCostLight then
        -- already use light
        -- no enough coins
        return
    end

    local dis = cc.pGetDistance(plane.position, one.position)
    if dis >= 500 then
        -- distance exceed
        return
    end

    local vc = cc.pSub(one.position, plane.position)
    if math.deg(cc.pGetAngle(plane.moveDir, vc)) <= 45 and math.random() < 0.40 then
        plane:useLight()
    end
end

class.tryActionCodes = function (self)
    local plane = self.plane
    if not plane then
        return
    end

    local actions = {const.kActionMaskShield, const.kActionMaskSpeed}
    for _, code in ipairs(actions) do
        local bufId = nil
        local score = 0
        local limit = 0.01
        if code == const.kActionMaskSpeed then
            bufId = const.kTypeFood_Speed
            score = const.kCostSpeed
            limit = 0.06
        elseif code == const.kActionMaskShield then
            bufId = const.kTypeFood_Shield
            score = const.kCostShield
            limit = 0.30
        end

        if not plane.buffs[bufId] and plane.currScore >= score and math.random() < limit then
            plane.currScore = plane.currScore - score
            plane:addBuff(bufId)
            return true
        end
    end
end

return class

