#!/bin/bash
ssh-keygen -q -t rsa -N '' -f ~/.ssh/cilium-k0s <<<y >/dev/null 2>&1
cp cloud-init-template.yaml cloud-init.yaml
cat ~/.ssh/cilium-k0s.pub | xargs -I{} echo "      - {}" >> cloud-init.yaml
multipass launch -n cp01 -c 1 -m 1G -d 5G --network enp0s31f6 --cloud-init /home/matias/Documents/lab/k0s-cluster/cloud-init.yaml
multipass launch -n worker01 -c 4 -m 3G -d 10G --network enp0s31f6 --cloud-init /home/matias/Documents/lab/k0s-cluster/cloud-init.yaml
multipass launch -n worker02 -c 4 -m 3G -d 10G --network enp0s31f6 --cloud-init /home/matias/Documents/lab/k0s-cluster/cloud-init.yaml
cp cilium-cluster-template.yaml cilium-cluster-01.yaml
multipass info cp01 --format json | jq .info.cp01.ipv4[1] | xargs -I{} sed -i 's/<CP01Address>/{}/g' cilium-cluster-01.yaml
multipass info worker01 --format json | jq .info.worker01.ipv4[1] | xargs -I{} sed -i 's/<Worker01Address>/{}/g' cilium-cluster-01.yaml
multipass info worker02 --format json | jq .info.worker02.ipv4[1] | xargs -I{} sed -i 's/<Worker02Address>/{}/g' cilium-cluster-01.yaml
kosctl apply --config cilium-cluster-01.yaml
