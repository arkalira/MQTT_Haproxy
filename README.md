# eMQTT_Haproxy

For dev testing, not suitable for production environments. 

## Prerequisites

- 1 Debian 9 Server
- 1 Network interface
- 1 public IP

## Install docker and more basic software

 - Basic software
```
apt-get install -y vim mc uml-utilities ntp qemu-guest-agent \
htop sudo curl git git-core etckeeper zsh apt-transport-https ca-certificates \
bridge-utils gettext-base \
usermod root -s /bin/zsh \
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" \
sed -ri 's/ZSH_THEME="robbyrussell"/ZSH_THEME="pygmalion"/g' .zshrc \
sed -ri 's/plugins=\(git\)/plugins=\(debian apt systemd docker zsh-navigation-tools\)/g' .zshrc \
echo 'export VTYSH_PAGER=more' >> /etc/zsh/zshenv \
source .zshrc
```
 - Docker
 
 ```
 apt-get remove docker docker-engine docker.io && apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
apt-get update && apt-cache madison docker-ce
apt-get install -y docker-ce=17.03.2~ce-0~debian-stretch
 ```
## Create docker network 

```
docker network create --subnet "10.168.80.0/24" mqtt
```
## Generate image for HAProxyMQTT

- Using this configuration: https://github.com/rainisto/haproxy-emqtt we will generate the docker image.
- This image expose the following ports: 80 443 1883 and 18083. If you dont need any of them, comment it before generate the new image. 
- Change the balance for TCP port 1883 from balance to leastconn.

```
mkdir -p /opt/mqtt/haproxy \ 
cd /opt/mqtt/haproxy && git clone https://github.com/rainisto/haproxy-emqtt \
cd /opt/mqtt/haproxy/haproxy-emqtt && docker build -t haproxy-mqtt . \ 
``` 

### Image listing

```
=> docker image ls | grep haproxy-mqtt
haproxy-mqtt        latest              e348b9fd1d2d        12 minutes ago      69.3 MB
```
### Run your HAproxy

```
docker run --rm -it -d --net mqtt -p80:80 -p1883:1883 -p18083:18083 --name haproxy01 haproxy-mqtt:latest
```
- It will fail as we dont have our mqtt brokers active. 

## Generate image for eMQTT Server

- Using this configuration: https://github.com/emqtt/emq-docker we will generate the docker image.
- This image expose the following ports: 1883 8883 8083 8084 8080 18083 4369 6000-6999. If you dont need any of them, comment it before generate the new image. 

```
mkdir -p /opt/mqtt/emqtt
cd /opt/mqtt/emqtt
git clone -b master https://github.com/emqtt/emq_docker.git 
cd /opt/mqtt/emqtt/emq_docker && docker build -t emqtt-docker . 
``` 

### Image listing

```
⇒  docker image ls | grep emqtt-docker
emqtt-docker        latest              e2a06bebb484        8 minutes ago       78.9 MB
```

## Start your emqtt cluster

- We need three nodes: emqtt-master, emqtt-node1, emqtt-node2. These nodes are configured in the haproxy.cfg as backend servers for the network traffic received to ports 1883, 18083. Those ports will be accessed through haproxy so we dont need to map them when launching our emqtt-master.

- So we need to create our cluster now. Start the cluster by creating first the emqtt-master node. 

```
docker run --rm -ti -d --name emqtt-master --hostname emqtt-master --dns 10.200.1.1 --net mqtt \
-p 4369:4369 -p 6000-6100:6000-6100 \ 
-e EMQ_LOADED_PLUGINS="emq_recon,emq_modules,emq_retainer,emq_dashboard" \
-e EMQ_CLUSTER__AUTOHEAL="on" -e EMQ_CLUSTER__AUTOCLEAN="1m" \ 
-e EMQ_CLUSTER__ETCD__NODE_TTL="1m" \ 
-e EMQ_WAIT_TIME=30 \
-e EMQ_NAME="emqtt" \ 
-e EMQ_LISTENER__TCP__EXTERNAL=1883 \
emqtt-docker:latest
```

- See logs:

```
docker logs emqtt-master -f --tail 1m
```

- And then, add new nodes:

```
docker run -d --rm -ti --name emqtt-node1 --hostname emqtt-node1 --dns 10.200.1.1 --net mqtt \
-e EMQ_LOADED_PLUGINS="emq_recon,emq_modules,emq_retainer,emq_dashboard" \ 
-e EMQ_NAME="emqtt" -e EMQ_HOST="10.168.80.3" -e EMQ_LISTENER__TCP__EXTERNAL=1883 \
-e EMQ_JOIN_CLUSTER="emqtt@10.168.80.2" emqtt-docker:latest
```

- See logs: 

```
docker logs emqtt-node1 -f --tail 1m
```

- Add new node: 

```
docker run -d --rm -ti --name emqtt-node2 --hostname emqtt-node2 --dns 10.200.1.1 --net mqtt \
-e EMQ_LOADED_PLUGINS="emq_recon,emq_modules,emq_retainer,emq_dashboard" \
-e EMQ_NAME="emqtt" -e EMQ_HOST="10.168.80.4" \
-e EMQ_LISTENER__TCP__EXTERNAL=1883 -e EMQ_JOIN_CLUSTER="emqtt@10.168.80.2" emqtt-docker:latest 
```

- See logs: 

```
docker logs emqtt-node2 -f --tail 1m
```

- If you want to review more info by yourself, check this: https://github.com/emqtt/emq-docker and this: https://github.com/emqtt/emqttd/wiki to see more detailed info. 

- If we look at logs: 

```
['2018-05-16T16:27:34Z']:emqttd try join emqtt@10.168.80.2
Join the cluster successfully.
Cluster status: [{running_nodes,['emqtt@10.168.80.2','emqtt@10.168.80.3']}]
```

### Start Haproxy

```
docker run --rm -it -d --net mqtt -p80:80 -p1883:1883 -p18083:18083 --name haproxy01 haproxy-mqtt:latest
```

- Success!

## Redis-Cluster

### Nodes: 3 masters and 3 slaves

- Minimum master nodes to start a redis-cluster: 3 
- Failover: 1 master - 1 slave so the slots in the failed master will be in the slave and this slave will be promoted automatically. 

### Create your cluster

- Based on: https://github.com/cpapidas/docker-compose-redis-cluster

### Create the cluster using your mqtt network

- We will create a cluster with 3 master using our mqtt network so our haproxy will be used as frontend for the cluster and will ask for the current master and detect failed redis nodes.

#### Compose it!

- After cloning this repo go to: "redis-cluster" folder and launch it with the following command: 

```
docker-compose up --build -d
```

- This will create the needed images and deploy the cluster. When its done, check logs of the redis_cluster_redis_cluster_1 container: 

```
docker logs $(docker ps -a | grep rediscluster_redis-cluster_1 | cut -d " " -f 1)
```

- And should give results like these lines: 

```
>>> Creating cluster
>>> Performing hash slots allocation on 6 nodes...
Using 3 masters:
10.168.80.101:7000
10.168.80.102:7001
10.168.80.103:7002
Adding replica 10.168.80.105:7004 to 10.168.80.101:7000
Adding replica 10.168.80.106:7005 to 10.168.80.102:7001
Adding replica 10.168.80.104:7003 to 10.168.80.103:7002
M: 73c5a1d20b75a692b723840acce320527b236d42 10.168.80.101:7000
   slots:0-5460 (5461 slots) master
M: 472363a3cf79a3c955d534e6e042f0c81349d2b5 10.168.80.102:7001
   slots:5461-10922 (5462 slots) master
M: bbeb14b902c9ec504ebad5940df9957b25d87092 10.168.80.103:7002
   slots:10923-16383 (5461 slots) master
S: 81d82b5c82aafae9842f282458c13fbaa38ea8e8 10.168.80.104:7003
   replicates bbeb14b902c9ec504ebad5940df9957b25d87092
S: b011850b7b258f60e2c0cac91373b859dd3adec6 10.168.80.105:7004
   replicates 73c5a1d20b75a692b723840acce320527b236d42
S: 9d045197be1d6a431c38f4369ce16a69d197842f 10.168.80.106:7005
   replicates 472363a3cf79a3c955d534e6e042f0c81349d2b5
Can I set the above configuration? (type 'yes' to accept): >>> Nodes configuration updated
>>> Assign a different config epoch to each node
>>> Sending CLUSTER MEET messages to join the cluster
Waiting for the cluster to join.....
>>> Performing Cluster Check (using node 10.168.80.101:7000)
M: 73c5a1d20b75a692b723840acce320527b236d42 10.168.80.101:7000
   slots:0-5460 (5461 slots) master
   1 additional replica(s)
M: 472363a3cf79a3c955d534e6e042f0c81349d2b5 10.168.80.102:7001
   slots:5461-10922 (5462 slots) master
   1 additional replica(s)
S: b011850b7b258f60e2c0cac91373b859dd3adec6 10.168.80.105:7004
   slots: (0 slots) slave
   replicates 73c5a1d20b75a692b723840acce320527b236d42
S: 81d82b5c82aafae9842f282458c13fbaa38ea8e8 10.168.80.104:7003
   slots: (0 slots) slave
   replicates bbeb14b902c9ec504ebad5940df9957b25d87092
M: bbeb14b902c9ec504ebad5940df9957b25d87092 10.168.80.103:7002
   slots:10923-16383 (5461 slots) master
   1 additional replica(s)
S: 9d045197be1d6a431c38f4369ce16a69d197842f 10.168.80.106:7005
   slots: (0 slots) slave
   replicates 472363a3cf79a3c955d534e6e042f0c81349d2b5
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
DONE
```

- Sooo, we have our new cluster with 6 containers. Lets see if redis-cli tell us the same information: 

- In your server do the following install: 

```
apt install redis-tools python-pip -y 
pip install redis-py-cluster
```

#### Check cluster status using redis-cli: 

- Enter this:
```
redis-cli -h 10.168.80.101 -p 7000
```
- And this in the redis cli: 

10.168.80.101:7000> 

```
cluster nodes
```

 - That should give us the following output: 
 
 ```
 10.168.80.101:7000> cluster nodes
472363a3cf79a3c955d534e6e042f0c81349d2b5 10.168.80.102:7001@17001 master - 0 1528275082000 2 connected 5461-10922
b011850b7b258f60e2c0cac91373b859dd3adec6 10.168.80.105:7004@17004 slave 73c5a1d20b75a692b723840acce320527b236d42 0 1528275083413 5 connected
73c5a1d20b75a692b723840acce320527b236d42 10.168.80.101:7000@17000 myself,master - 0 1528275082000 1 connected 0-5460
81d82b5c82aafae9842f282458c13fbaa38ea8e8 10.168.80.104:7003@17003 slave bbeb14b902c9ec504ebad5940df9957b25d87092 0 1528275082410 4 connected
bbeb14b902c9ec504ebad5940df9957b25d87092 10.168.80.103:7002@17002 master - 0 1528275081408 3 connected 10923-16383
9d045197be1d6a431c38f4369ce16a69d197842f 10.168.80.106:7005@17005 slave 472363a3cf79a3c955d534e6e042f0c81349d2b5 0 1528275083000 6 connected
10.168.80.101:7000> 
 ```
### HAProxy as redis-cluster proxy

- Lets put our HAProxy in front of the redis cluster listening on 127.0.0.1:6379 si the cluster will be transparent for our clients and HAProxy will check the master status using 'option' checks. 

### Modifiy haproxy.cfg

- Go to haproxy-mqtt folder, edit **haproxy.cfg** and add this to the end of file: 

```
listen redis-cluster
    bind *:6379
    mode tcp
    timeout connect  4s
    timeout server  30s
    timeout client  30s
    #option clitcpka
    option tcplog
    option tcp-check
    tcp-check send PING\r\n
    tcp-check expect string +PONG
    tcp-check send info\ replication\r\n
    tcp-check expect string role:master
    tcp-check send QUIT\r\n
    tcp-check expect string +OK
    #balance leastconn
    server redis_master1 10.168.80.101:7000 maxconn 2048 check inter 1s
    server redis_master2 10.168.80.102:7001 maxconn 2048 check inter 1s
    server redis_master3 10.168.80.103:7002 maxconn 2048 check inter 1s
    server redis_slave1 10.168.80.104:7003 maxconn 2048 check inter 1s
    server redis_slave2 10.168.80.105:7004 maxconn 2048 check inter 1s
    server redis_slave3 10.168.80.106:7005 maxconn 2048 check inter 1s
```

- Then save it and edit the Dockerfile to EXPOSE the Redis port. The EXPOSE section of your Dockerfile should look like this.

```
. . . 

# Expose ports.
EXPOSE 80
EXPOSE 443
EXPOSE 1883
EXPOSE 6379
EXPOSE 18083
. . . 
```

- Build new haproxy image: 

```
docker build -t haproxy-mqtt:1.7-rediscl .
```

- And then stop current HAProxy and deploy new version: 

```
docker stop haproxy01
docker rm haproxy01
docker run -it -d --net mqtt -p80:80 -p1883:1883 -p18083:18083 -p6379:6379 --name haproxy01 haproxy-mqtt:1.7-rediscl
```

- Now we will be able to see the new backend and its state in the haproxy stats. Go to your website http://IP_OFYOR_VM and check the state of the redis-cluster backend. 

- You should see, 3 redis-master in green and 3 redis-slaves in red. Thats normal dont panic. 

- In our haproxy we specified that HAProxy must talk only to backends with the role:master string so the red ones are OK, they are replicas. All works as expected. 

- If you want to test and have some fun with your redis-cluster, check this link:

https://github.com/arkalira/MQTT_Haproxy/blob/master/redis-cluster/README.md

- Now everything is working fine. 
- Start your mqtt devices and send your publications!




