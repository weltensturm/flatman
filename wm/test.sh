#!/bin/bash
set -e
dub build --build=debug --debug=Remove
set +e
echo STARTING XEPHYR
Xephyr -ac -br -noreset -screen 1920x1080 :9999 &
XEPHYR_PID=$!
sleep 1
echo STARTING DEBUG
#DISPLAY=:9999 valgrind ./flatman-wm
DISPLAY=:9999 ./flatman-wm
kill $XEPHYR_PID
