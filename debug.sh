#!/bin/bash
dub build --build=debug
echo STARTING XEPHYR
Xephyr -ac -br -noreset -screen 1280x720 :1 &
XEPHYR_PID=$!
sleep 1
echo STARTING DEBUG
DISPLAY=:1 gdb /home/weltensturm/Projects/d/flatman/flatman
kill $XEPHYR_PID
