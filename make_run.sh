#!/bin/sh

pkill aa-server

fbc -w all "aa-server.bas"
fbc -w all "aa-client.bas"

./aa-server &
wait 1000
./aa-client

