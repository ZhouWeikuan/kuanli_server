---------------------------------------------------
---! @file
---! @brief 文件和网络读写，打包解包等
---------------------------------------------------

--! create the class metatable
local class = {mt = {}}
class.mt.__index = class

---! @brief 加载配置文件, 文件名为从 backend目录计算的路径
local function load_config(filename)
    local f = assert(io.open(filename))
    local source = f:read "*a"
    f:close()
    local tmp = {}
    assert(load(source, "@"..filename, "t", tmp))()

    return tmp
end
class.load_config = load_config

---! @brief 通过名称，创建类的对象
---! @param name 类名
---! @param ...  类的对象创建时所需要的其它参数
---! for hall interface: PacketHelper.createObject(conf.Interface, conf)
---! for game class:     PacketHelper.createObject(conf.GameClass, conf)
local function createObject(name, ...)
    local cls = require(name)
    if not cls then
        print("failed to load class", name)
    end

    return cls.create(...)
end
class.createObject = createObject


return class

