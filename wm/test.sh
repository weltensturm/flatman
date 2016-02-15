#!/bin/bash
set -e
dub build --build=debug
set +e
echo STARTING XEPHYR
Xephyr -ac -br -noreset -screen 1280x720 :1 &
XEPHYR_PID=$!
sleep 1
echo STARTING DEBUG
DISPLAY=:1 ./flatman-wm
kill $XEPHYR_PID
