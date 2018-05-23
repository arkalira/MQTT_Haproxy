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

- We need three nodes: emqtt-master, emqtt-node1, emqtt-node2. These nodes are configured in the haproxy.cfg as backend servers for the network traffic received to ports 1883, 18083. 

- So we need to create our cluster now. Start the cluster by creating first the emqtt-master node. 

```
docker run --rm -ti -d --name emqtt-master --hostname emqtt-master --dns 10.200.1.1 --net mqtt \
-p 18083:18083 -p 1883:1883 -p 4369:4369 -p 6000-6100:6000-6100 \ 
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
-e EMQ_LISTENER__TCP__EXTERNAL=1883 -e EMQ_JOIN_CLUSTER="emqtt@10.168.80.2" emqtt-docker:latest \

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

- Success!


