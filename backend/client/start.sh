#!/bin/bash

### example
### sh client/start.sh 1

export ClientNo=$1

if [[ "x$ClientNo" == "x" ]]
then
    echo "You must set ClientNo"
    exit
fi

echo "start client/start.sh $ClientNo "

../skynet/skynet client/config.lua $ClientNo

