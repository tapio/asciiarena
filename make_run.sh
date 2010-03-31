#!/bin/sh

pkill aa-server

fbc -w all -exx -g -mt "aa-server.bas"
fbc -w all -exx -g -mt "aa-client.bas"

./aa-server &
wait 1000
./aa-client

