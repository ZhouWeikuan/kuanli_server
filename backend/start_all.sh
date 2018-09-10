#!/bin/bash

sh MainServer/start.sh node3 1 &
sleep 3
sh AgentServer/start.sh node1 1 &
sleep 3
sh HallServer/start.sh node2 1 ./config/yuncheng.cfg &
