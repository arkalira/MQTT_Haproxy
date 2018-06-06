## Testing Redis-cluster


- If you want to test your redis-cluster i suggest the following: 

- Stop one master

```
docker stop rediscluster_redismaster1_1
```

- See if one of the slaves turns green in the haproxy stats panel. It should!

- Then check logs of the new promoted master: 

```
docker logs rediscluster_redislave3_1 -f --tail 1m
```

- See something like that?

```
1:S 06 Jun 09:41:57.570 # Connection with master lost.
1:S 06 Jun 09:41:57.570 * Caching the disconnected master state.
1:S 06 Jun 09:41:58.343 * Connecting to MASTER 10.168.80.102:7001
1:S 06 Jun 09:41:58.343 * MASTER <-> SLAVE sync started
1:S 06 Jun 09:42:03.340 * Marking node 472363a3cf79a3c955d534e6e042f0c81349d2b5 as failing (quorum reached).
1:S 06 Jun 09:42:03.340 # Cluster state changed: fail
1:S 06 Jun 09:42:03.357 # Start of election delayed for 787 milliseconds (rank #0, offset 11816).
1:S 06 Jun 09:42:04.158 # Starting a failover election for epoch 9.
1:S 06 Jun 09:42:13.374 # Currently unable to failover: Waiting for votes, but majority still not reached.
1:S 06 Jun 09:42:14.176 # Currently unable to failover: Failover attempt expired.
1:S 06 Jun 09:42:24.195 # Start of election delayed for 988 milliseconds (rank #0, offset 11816).
1:S 06 Jun 09:42:24.295 # Currently unable to failover: Waiting the delay before I can start a new failover.
1:S 06 Jun 09:42:25.196 # Starting a failover election for epoch 10.
1:S 06 Jun 09:42:25.410 # Currently unable to failover: Waiting for votes, but majority still not reached.
1:S 06 Jun 09:42:25.480 # Failover election won: I'm the new master.
1:S 06 Jun 09:42:25.480 # configEpoch set to 10 after successful failover
1:M 06 Jun 09:42:25.480 # Setting secondary replication ID to c092dcc8c3ad5c8a30ceeb6981a0fab336c6f11b, valid up to offset: 11817. New replication ID is dbd9be3bd5390b5e002905fae4ccea42c112926a
1:M 06 Jun 09:42:25.480 * Discarding previously cached master state.
1:M 06 Jun 09:42:25.480 # Cluster state changed: o

```

- And the logs of an existing master would be like: 

```
1:M 06 Jun 09:42:04.257 # Failover auth denied to 9d045197be1d6a431c38f4369ce16a69d197842f: its master is up
1:M 06 Jun 09:42:04.355 * Marking node 472363a3cf79a3c955d534e6e042f0c81349d2b5 as failing (quorum reached).
1:M 06 Jun 09:42:04.355 # Cluster state changed: fail
1:M 06 Jun 09:42:25.410 # Failover auth granted to 9d045197be1d6a431c38f4369ce16a69d197842f for epoch 10
1:M 06 Jun 09:42:25.482 # Cluster state changed: ok

```

- If you see this status, all is working like a charm. 

- Now, revert to its original state:

  - Start the previous master. 
  - Stop the promoted replica and then the old master will catch the master role. 
  - Confirm that the 3 master are green and replicas appear red in the HAProxy Stats panel. 
 
- Get a coffee! :)

## Set and get operations

### Use a smart client to set, get operations

- Now we need to insert values in the new cluster. We need a smart client that will be able to understand MOVE and other commands used by the redis cluster ops. 

### Set a simple client to insert simple keys

```
python
from rediscluster import StrictRedisCluster
startup_nodes = [{"host": "127.0.0.1", "port": "6379"}]
rdb = StrictRedisCluster(startup_nodes=startup_nodes, decode_responses=True)
rdb.set("foo","bar")
rdb.set("foo1","bar1")
rdb.set("foo2","bar2")
print(rdb.get("foo"))
print(rdb.get("foo1"))
print(rdb.get("foo2"))
``` 
- Setting keys with **rdb.set** must return "True" and **rdb.get** should return the key value. 

- Now is time to free the chaos monkey. Stop a master, enter the cli and search for key values: 

```
docker stop rediscluster_redismaster2_1
redis-cli -h 127.0.0.1 -p 6379
127.0.0.1:6379> cluster nodes
472363a3cf79a3c955d534e6e042f0c81349d2b5 10.168.80.102:7001@17001 master,fail - 1528279514747 1528279514545 11 connected 5461-10922
9d045197be1d6a431c38f4369ce16a69d197842f 10.168.80.106:7005@17005 slave 472363a3cf79a3c955d534e6e042f0c81349d2b5 0 1528279523859 11 connected
73c5a1d20b75a692b723840acce320527b236d42 10.168.80.101:7000@17000 master - 0 1528279523558 8 connected 0-5460
bbeb14b902c9ec504ebad5940df9957b25d87092 10.168.80.103:7002@17002 myself,master - 0 1528279522000 3 connected 10923-16383
b011850b7b258f60e2c0cac91373b859dd3adec6 10.168.80.105:7004@17004 slave 73c5a1d20b75a692b723840acce320527b236d42 0 1528279523359 8 connected
81d82b5c82aafae9842f282458c13fbaa38ea8e8 10.168.80.104:7003@17003 slave bbeb14b902c9ec504ebad5940df9957b25d87092 0 1528279522000 4 connected
127.0.0.1:6379> cluster nodes
472363a3cf79a3c955d534e6e042f0c81349d2b5 10.168.80.102:7001@17001 master,fail - 1528279514747 1528279514545 11 connected
9d045197be1d6a431c38f4369ce16a69d197842f 10.168.80.106:7005@17005 master - 0 1528279586536 13 connected 5461-10922
73c5a1d20b75a692b723840acce320527b236d42 10.168.80.101:7000@17000 master - 0 1528279588038 8 connected 0-5460
bbeb14b902c9ec504ebad5940df9957b25d87092 10.168.80.103:7002@17002 myself,master - 0 1528279587000 3 connected 10923-16383
b011850b7b258f60e2c0cac91373b859dd3adec6 10.168.80.105:7004@17004 slave 73c5a1d20b75a692b723840acce320527b236d42 0 1528279587037 8 connected
81d82b5c82aafae9842f282458c13fbaa38ea8e8 10.168.80.104:7003@17003 slave bbeb14b902c9ec504ebad5940df9957b25d87092 0 1528279586536 4 connected
127.0.0.1:6379>
127.0.0.1:6379> get foo
(error) MOVED 12182 10.168.80.103:7002
127.0.0.1:6379> get foo2
(error) MOVED 1044 10.168.80.101:7000
127.0.0.1:6379> get foo1
"bar1"
127.0.0.1:6379>
```

- Ok, redis-cli give us where is the slot but doesnt give us the value. We need to do it with the smart client now. 

```
python
Python 2.7.15rc1 (default, Apr 15 2018, 21:51:34) 
[GCC 7.3.0] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> from rediscluster import StrictRedisCluster
>>> startup_nodes = [{"host": "127.0.0.1", "port": "6379"}]
>>> rdb = StrictRedisCluster(startup_nodes=startup_nodes, decode_responses=True)
>>> print(rdb.get("foo"))
bar
>>> print(rdb.get("foo1"))
bar1
>>> print(rdb.get("foo2"))
bar2
>>> rdb.set("foo3","bar3")
True
>>> rdb.set("foo4","bar4")
True
>>> rdb.set("foo3","bar33")
True
>>> rdb.set("foo5","bar5")
True
```

- Now start the master and wait for the logs: 

```
docker start rediscluster_redismaster2_1 && docker logs rediscluster_redismaster2_1 -f --tail 1m
```

- Special focus on this part: 

```
...
1:M 06 Jun 10:13:38.507 * Ready to accept connections
1:M 06 Jun 10:13:38.509 # Configuration change detected. Reconfiguring myself as a replica of 9d045197be1d6a431c38f4369ce16a69d197842f
1:S 06 Jun 10:13:38.509 * Before turning into a slave, using my master parameters to synthesize a cached master: I may be able to synchronize with the new master with just a partial transfer.
1:S 06 Jun 10:13:38.509 # Cluster state changed: ok
1:S 06 Jun 10:13:39.577 * Connecting to MASTER 10.168.80.106:7005
1:S 06 Jun 10:13:39.577 * MASTER <-> SLAVE sync started
1:S 06 Jun 10:13:39.577 * Non blocking connect for SYNC fired the event.
1:S 06 Jun 10:13:39.577 * Master replied to PING, replication can continue...
1:S 06 Jun 10:13:39.578 * Trying a partial resynchronization (request 9fa1047221813ab494d16c69ee985fc3ee7a58fc:1).
1:S 06 Jun 10:13:39.578 * Full resync from master: 7eaf460c2d4380b8cb81a35db280b9f1cc51c8e6:13034
1:S 06 Jun 10:13:39.578 * Discarding previously cached master state.
1:S 06 Jun 10:13:39.661 * MASTER <-> SLAVE sync: receiving 192 bytes from master
1:S 06 Jun 10:13:39.662 * MASTER <-> SLAVE sync: Flushing old data
1:S 06 Jun 10:13:39.662 * MASTER <-> SLAVE sync: Loading DB in memory
1:S 06 Jun 10:13:39.662 * MASTER <-> SLAVE sync: Finished with success
1:S 06 Jun 10:13:39.662 * Background append only file rewriting started by pid 17
1:S 06 Jun 10:13:39.698 * AOF rewrite child asks to stop sending diffs.
17:C 06 Jun 10:13:39.698 * Parent agreed to stop sending diffs. Finalizing AOF...
17:C 06 Jun 10:13:39.698 * Concatenating 0.00 MB of AOF diff received from parent.
17:C 06 Jun 10:13:39.698 * SYNC append only file rewrite performed
17:C 06 Jun 10:13:39.698 * AOF rewrite: 0 MB of memory used by copy-on-write
1:S 06 Jun 10:13:39.777 * Background AOF rewrite terminated with success
1:S 06 Jun 10:13:39.777 * Residual parent diff successfully flushed to the rewritten AOF (0.00 MB)
1:S 06 Jun 10:13:39.777 * Background AOF rewrite finished successfully
...
``` 

- Check cluster nodes through redis-cli: 

```
redis-cli -h 127.0.0.1 -p 6379
127.0.0.1:6379> cluster nodes
b011850b7b258f60e2c0cac91373b859dd3adec6 10.168.80.105:7004@17004 slave 73c5a1d20b75a692b723840acce320527b236d42 0 1528280148039 8 connected
bbeb14b902c9ec504ebad5940df9957b25d87092 10.168.80.103:7002@17002 master - 0 1528280147000 3 connected 10923-16383
81d82b5c82aafae9842f282458c13fbaa38ea8e8 10.168.80.104:7003@17003 slave bbeb14b902c9ec504ebad5940df9957b25d87092 0 1528280148138 4 connected
9d045197be1d6a431c38f4369ce16a69d197842f 10.168.80.106:7005@17005 master - 0 1528280148039 13 connected 5461-10922
472363a3cf79a3c955d534e6e042f0c81349d2b5 10.168.80.102:7001@17001 slave 9d045197be1d6a431c38f4369ce16a69d197842f 0 1528280147138 13 connected
73c5a1d20b75a692b723840acce320527b236d42 10.168.80.101:7000@17000 myself,master - 0 1528280146000 8 connected 0-5460

```
- We confirm that is a slave of the promoted replica. Stop the promoted replica and then check if the slave is promoted OK. 

```
127.0.0.1:6379> cluster nodes
472363a3cf79a3c955d534e6e042f0c81349d2b5 10.168.80.102:7001@17001 master - 0 1528280299000 14 connected 5461-10922
9d045197be1d6a431c38f4369ce16a69d197842f 10.168.80.106:7005@17005 master,fail - 1528280284761 1528280284000 13 connected
73c5a1d20b75a692b723840acce320527b236d42 10.168.80.101:7000@17000 master - 0 1528280299608 8 connected 0-5460
bbeb14b902c9ec504ebad5940df9957b25d87092 10.168.80.103:7002@17002 myself,master - 0 1528280298000 3 connected 10923-16383
b011850b7b258f60e2c0cac91373b859dd3adec6 10.168.80.105:7004@17004 slave 73c5a1d20b75a692b723840acce320527b236d42 0 1528280299000 8 connected
81d82b5c82aafae9842f282458c13fbaa38ea8e8 10.168.80.104:7003@17003 slave bbeb14b902c9ec504ebad5940df9957b25d87092 0 1528280298505 4 connected

```

- And start again the stoped node. This time, the node will join as a slave of his master (472363a3cf79a3c955d534e6e042f0c81349d2b5). 

```
127.0.0.1:6379> cluster nodes
472363a3cf79a3c955d534e6e042f0c81349d2b5 10.168.80.102:7001@17001 master - 0 1528280446596 14 connected 5461-10922
9d045197be1d6a431c38f4369ce16a69d197842f 10.168.80.106:7005@17005 slave 472363a3cf79a3c955d534e6e042f0c81349d2b5 0 1528280446000 14 connected
73c5a1d20b75a692b723840acce320527b236d42 10.168.80.101:7000@17000 master - 0 1528280445094 8 connected 0-5460
bbeb14b902c9ec504ebad5940df9957b25d87092 10.168.80.103:7002@17002 myself,master - 0 1528280446000 3 connected 10923-16383
b011850b7b258f60e2c0cac91373b859dd3adec6 10.168.80.105:7004@17004 slave 73c5a1d20b75a692b723840acce320527b236d42 0 1528280447096 8 connected
81d82b5c82aafae9842f282458c13fbaa38ea8e8 10.168.80.104:7003@17003 slave bbeb14b902c9ec504ebad5940df9957b25d87092 0 1528280446000 4 connected
```

- OK! 

- Check that the value of the keys are returning as expected: 

```
python
Python 2.7.15rc1 (default, Apr 15 2018, 21:51:34) 
[GCC 7.3.0] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> from rediscluster import StrictRedisCluster
>>> startup_nodes = [{"host": "127.0.0.1", "port": "6379"}]
>>> rdb = StrictRedisCluster(startup_nodes=startup_nodes, decode_responses=True)
>>> print(rdb.get("foo"))
bar
>>> print(rdb.get("foo1"))
bar1
>>> print(rdb.get("foo2"))
bar2
>>> print(rdb.get("foo"))
bar
>>> print(rdb.get("foo3"))
bar33
>>> print(rdb.get("foo4"))
bar4
>>> print(rdb.get("foo5"))
bar5
```

- Great! Get a coffee!! 

