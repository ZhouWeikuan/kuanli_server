----------------------------------------------------------------
---! @file
---! @brief protocol type status
----------------------------------------------------------------

local class = {}

--- main proto types
class.CGGAME_PROTO_MAINTYPE_BASIC   = 1                         -- basic proto type
    class.CGGAME_PROTO_SUBTYPE_MULTIPLE     =   1               -- mulitiple message
    class.CGGAME_PROTO_SUBTYPE_ACL          =   2               -- acl info
    class.CGGAME_PROTO_SUBTYPE_HEARTBEAT    =   3               -- heart beat
        class.CGGAME_PROTO_HEARTBEAT_CLIENT    =   1            -- heart beat from client
        class.CGGAME_PROTO_HEARTBEAT_SERVER    =   2            -- heart beat from server
    class.CGGAME_PROTO_SUBTYPE_AGENTLIST    =   4               -- ask for agent list
    class.CGGAME_PROTO_SUBTYPE_NOTICE       =   5               -- system notice

class.CGGAME_PROTO_MAINTYPE_AUTH    = 10                        -- auth proto type
    class.CGGAME_PROTO_SUBTYPE_ASKRESUME    =   1               -- client -> server, ask resume/ask auth
    class.CGGAME_PROTO_SUBTYPE_CHALLENGE    =   2               -- server -> client, give a challenge key
    class.CGGAME_PROTO_SUBTYPE_CLIENTKEY    =   3               -- client -> server, give a client key
    class.CGGAME_PROTO_SUBTYPE_SERVERKEY    =   4               -- server -> client, give a server key
    class.CGGAME_PROTO_SUBTYPE_RESUME_OK    =   5               -- server -> client, tell resume ok

class.CGGAME_PROTO_MAINTYPE_HALL    = 20
    class.CGGAME_PROTO_SUBTYPE_HALLQUIT     =   1
    class.CGGAME_PROTO_SUBTYPE_HALLJOIN     =   2
    class.CGGAME_PROTO_SUBTYPE_USERINFO     =   3
    class.CGGAME_PROTO_SUBTYPE_USERSTATUS   =   4
    class.CGGAME_PROTO_SUBTYPE_BONUS        =   5
        class.CGGAME_PROTO_BONUS_DAILY  =   1
        class.CGGAME_PROTO_BONUS_SHARE  =   2


class.CGGAME_PROTO_MAINTYPE_CLUB    = 30

class.CGGAME_PROTO_MAINTYPE_ROOM    = 40

class.CGGAME_PROTO_MAINTYPE_GAME    = 50
    class.CGGAME_PROTO_SUBTYPE_GAMEJOIN     =   1
    class.CGGAME_PROTO_SUBTYPE_GAMETRACE    =   2
    class.CGGAME_PROTO_SUBTYPE_BROADCAST    =   3




---! ACL status code 用于回应客户端消息的状态码
--- 0 ~ 9  for success
class.CGGAME_ACL_STATUS_SUCCESS					            =   0

--- 100 ~ 999 for each game

---- 1000 for common handler
class.CGGAME_ACL_STATUS_SERVER_BUSY						    =   1000
class.CGGAME_ACL_STATUS_INVALID_INFO						=   1001
class.CGGAME_ACL_STATUS_INVALID_COMMAND						=   1002
class.CGGAME_ACL_STATUS_AUTH_FAILED			                =   1003
class.CGGAME_ACL_STATUS_COUNTER_FAILED                      =   1004
class.CGGAME_ACL_STATUS_SERVER_ERROR						=   1005
class.CGGAME_ACL_STATUS_SHARE_EXCEED						=   1006
class.CGGAME_ACL_STATUS_OLDVERSION						    =   1007

class.CGGAME_ACL_STATUS_INVALID_AGENTCODE			        =   1010
class.CGGAME_ACL_STATUS_ALREADY_AGENTCODE			        =   1011

class.CGGAME_ACL_STATUS_ROOM_DB_FAILED					    =   1020
class.CGGAME_ACL_STATUS_ROOM_CREATE_FAILED					=   1021
class.CGGAME_ACL_STATUS_ROOM_FIND_FAILED					=   1022
class.CGGAME_ACL_STATUS_ROOM_JOIN_FULL						=   1023
class.CGGAME_ACL_STATUS_ROOM_NOT_SUPPORT					=   1024
class.CGGAME_ACL_STATUS_ROOM_NO_SUCH_PAYTYPE                =   1025


local function isACLSuccess (status)
    return status < 100
end
class.isACLSuccess = isACLSuccess

local function isACLFailed (status)
    return status >= 100
end
class.isACLFailed = isACLFailed


return class

