#!/bin/bash

### example
### sh HallServer/start.sh node1 1 config/game1.cfg

## NodeName = node1
## ServerNo = 1
## HallConfig = "game.cfg"

### so we can use getenv in skynet
export NodeName=$1
export ServerNo=$2
export HallConfig=$3

### check valid for NodeName, ServerNo, HallConfig
if [[ "x$NodeName" == "x" || "x$ServerNo" == "x" || "x$HallConfig" == "x" ]]
then
    echo "You must set NodeName, ServerNo and HallConfig"
    exit
fi

echo "NodeName = $NodeName, ServerName = HallServer, ServerNo = $ServerNo, HallConfig=$HallConfig"

### so we can distinguish different skynet processes
../skynet/skynet HallServer/config.lua $NodeName $ServerNo $HallConfig

