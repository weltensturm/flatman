#!/bin/bash
dub build --build=debug
echo STARTING XEPHYR
Xephyr -ac -br -noreset -screen 1280x720 :1 &
XEPHYR_PID=$!
sleep 1
echo STARTING DEBUG
DISPLAY=:1 gdb ./flatman
kill $XEPHYR_PID
