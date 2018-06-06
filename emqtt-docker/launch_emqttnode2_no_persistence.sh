docker run -d --rm -ti --name emqtt-node2 --hostname emqtt-node2 --dns 10.80.254.2 --net mqtt -e EMQ_LOADED_PLUGINS="emq_recon,emq_modules,emq_retainer,emq_dashboard" -e EMQ_NAME="emqtt" -e EMQ_HOST="10.168.80.4" -e EMQ_LISTENER__TCP__EXTERNAL=1883 -e EMQ_JOIN_CLUSTER="emqtt@10.168.80.2" emqtt-docker:latest 
docker logs emqtt-node2 -f --tail 1m
