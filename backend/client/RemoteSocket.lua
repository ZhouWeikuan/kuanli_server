local skynet = require "skynet"
local socket = require "client.socket"


---! create the class metatable
local class = {mt = {}}
class.mt.__index = class

class.getTCPSocket = function(self, host, port)
    local sock
    xpcall(function ()
        sock = socket.connect(host, port)
    end,
    function (err)
        skynet.error(err)
    end)

    if not sock then
        return nil
    end

    self.host = addr
    self.port = port

    return sock
end

---! create delegate object
local function create (addr, port)
    local self = {}
    setmetatable(self, class.mt)

    self.pack_len  = nil
    self.partial   = ""
    self.packet    = nil

    self.sockfd = self:getTCPSocket(addr, port)
    if not self.sockfd then
        return nil
    end

    return self
end
class.create = create

class.resetPartial = function (self)
    self.packet   = nil
    self.pack_len = nil
    self.partial  = ""
end

class.readHead = function (self)
    local flag = true
    xpcall(function ()
        local partial = socket.recv(self.sockfd)
        if not partial or partial == "" then
            flag = false
        else
            self.partial = self.partial .. partial
        end
        if string.len(self.partial) >= 2 then
            local head = string.sub(self.partial, 1, 2)
            self.pack_len = string.unpack(">I2", head)
            self.partial = string.sub(self.partial, 3)
            self.packet = nil
        end
    end,
    function (err)
        flag = false
        print(err)
        self:abort()
    end)
    return flag
end

class.readBody = function (self)
    local flag = true
    xpcall(function ()
        local partial = socket.recv(self.sockfd)
        if not partial or partial == "" then
            flag = false
        else
            self.partial = self.partial .. partial
        end
        if string.len(self.partial) >= self.pack_len then
            self.packet = string.sub(self.partial, 1, self.pack_len)
            self.partial = string.sub(self.partial, self.pack_len + 1)
            self.pack_len = nil
        end
    end,
    function (err)
        flag = false
        print(err)
        self:abort()
    end)
    return flag
end

--! @brief receive one valid packet from server
--! @param self   the remote socket
--! @param delaySecond  delay time, like 5.0, nil means no delay, -1.0 means blocked wait until some bytes arrive
--! @param the packet or nil
local function recvPacket (self, delaySecond)
    if not self.sockfd then
        return
    end

    while true do
        if self.packet then
            local p = self.packet
            self.packet = nil

            return p
        end

        if self.pack_len == nil then
            if not self:readHead() then
                return
            end
        else
            if not self:readBody() then
                return
            end
        end
    end
end
class.recvPacket = recvPacket

---! @breif send a packet to remote
---! @param pack  is a valid proto data string
local function sendPacket (self, pack)
    if not self.sockfd then
        return
    end

    pack = string.pack(">s2", pack)

    xpcall(function ()
        socket.send(self.sockfd, pack)
    end,
    function (err)
        self:abort(err)
    end)
end
class.sendPacket = sendPacket

class.isClosed = function (self)
    return (self.sockfd == nil)
end

---! @brief close
local function close (self, err)
    local c = self.sockfd
    if c then
        socket.close(c)
    end

    self:resetPartial()
    self.sockfd     = nil
end
class.close = close
class.abort = close


return class

