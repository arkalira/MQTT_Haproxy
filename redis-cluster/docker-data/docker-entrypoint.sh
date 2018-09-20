#!/bin/sh

if [ "$1" = 'redis-cluster' ]; then
    sleep 10
    echo "yes" | ruby /redis/src/redis-trib.rb create --replicas 1 10.80.254.5:7000 10.80.254.5:7001 10.80.254.5:7002 10.80.254.5:7003 10.80.254.5:7004 10.80.254.5:7005
    echo "DONE"
else
  exec "$@"
fi
