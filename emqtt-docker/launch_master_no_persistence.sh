docker run --rm -ti -d --name emqtt-master --hostname emqtt-master --dns 10.80.254.2 --net mqtt \
-p 4369:4369 -p 6000-6100:6000-6100 -e EMQ_LOADED_PLUGINS="emq_recon,emq_modules,emq_retainer,emq_dashboard" -e EMQ_CLUSTER__AUTOHEAL="on" -e EMQ_CLUSTER__AUTOCLEAN="1m" -e EMQ_CLUSTER__ETCD__NODE_TTL="1m" -e EMQ_WAIT_TIME=30 -e EMQ_NAME="emqtt" -e EMQ_LISTENER__TCP__EXTERNAL=1883 emqtt-docker:latest
docker logs emqtt-master -f --tail 1m
