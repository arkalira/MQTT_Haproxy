#!/bin/sh

if [ "$1" = 'redis-cluster' ]; then
    sleep 10
    echo "yes" | ruby /redis/src/redis-trib.rb create --replicas 1 10.168.80.101:7000 10.168.80.102:7001 10.168.80.103:7002 10.168.80.104:7003 10.168.80.105:7004 10.168.80.106:7005
    echo "DONE"
else
  exec "$@"
fi
