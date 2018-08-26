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
        class.CGGAME_PROTO_HEARTBEAT_FROM_CLIENT    =   1       -- heart beat from client
        class.CGGAME_PROTO_HEARTBEAT_FROM_SERVER    =   2       -- heart beat from server
    class.CGGAME_PROTO_SUBTYPE_AGENTLIST    =   4               -- ask for agent list

class.CGGAME_PROTO_MAINTYPE_AUTH    = 10                        -- auth proto type
    class.CGGAME_PROTO_SUBTYPE_ASKRESUME    =   1               -- client -> server, ask resume/ask auth
    class.CGGAME_PROTO_SUBTYPE_CHALLENGE    =   2               -- server -> client, give a challenge key
    class.CGGAME_PROTO_SUBTYPE_CLIENTKEY    =   3               -- client -> server, give a client key
    class.CGGAME_PROTO_SUBTYPE_SERVERKEY    =   4               -- server -> client, give a server key
    class.CGGAME_PROTO_SUBTYPE_RESUME_OK    =   5               -- server -> client, give a server key

class.CGGAME_PROTO_MAINTYPE_HALL    = 20
    class.CGGAME_PROTO_SUBTYPE_HALLQUIT     =   1
    class.CGGAME_PROTO_SUBTYPE_HALLJOIN     =   2
    class.CGGAME_PROTO_SUBTYPE_NOTICE       =   3

class.CGGAME_PROTO_MAINTYPE_CLUB    = 30

class.CGGAME_PROTO_MAINTYPE_ROOM    = 40

class.CGGAME_PROTO_MAINTYPE_GAME    = 50
    class.CGGAME_PROTO_SUBTYPE_GAMEJOIN     =   1
    class.CGGAME_PROTO_SUBTYPE_GAMETRACE    =   2

return class

