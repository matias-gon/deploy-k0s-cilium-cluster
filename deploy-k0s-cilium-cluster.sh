#!/bin/bash
# generating ssh key for the cluster nodes
ssh-keygen -q -t rsa -N '' -f ~/.ssh/cilium-k0s <<<y >/dev/null 2>&1
cp cloud-init-template.yaml cloud-init.yaml
cat ~/.ssh/cilium-k0s.pub | xargs -I{} echo "      - {}" >> cloud-init.yaml

# creating the cluster nodes with multipass
export NETWORK=$(multipass networks | grep ethernet | awk '{print $1}')
multipass launch -n cp01 -c 1 -m 1G -d 5G --network $NETWORK --cloud-init ./cloud-init.yaml
multipass launch -n worker01 -c 6 -m 2G -d 10G --network $NETWORK --cloud-init ./cloud-init.yaml
multipass launch -n worker02 -c 6 -m 2G -d 10G --network $NETWORK --cloud-init ./cloud-init.yaml

# waiting for the nodes to be up and running
wait 30

# applying the cilium cluster configuration
cp cilium-cluster-template.yaml cilium-cluster.yaml
multipass info cp01 --format json | jq .info.cp01.ipv4[1] | xargs -I{} sed -i 's/<CP01Address>/{}/g' cilium-cluster.yaml
multipass info worker01 --format json | jq .info.worker01.ipv4[1] | xargs -I{} sed -i 's/<Worker01Address>/{}/g' cilium-cluster.yaml
multipass info worker02 --format json | jq .info.worker02.ipv4[1] | xargs -I{} sed -i 's/<Worker02Address>/{}/g' cilium-cluster.yaml
k0sctl apply --config cilium-cluster.yaml
