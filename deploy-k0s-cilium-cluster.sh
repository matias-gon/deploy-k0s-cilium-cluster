#!/bin/bash
# generating ssh key for the cluster nodes
ssh-keygen -q -t rsa -N '' -f ~/.ssh/cilium-k0s <<<y >/dev/null 2>&1
cp cloud-init-template.yaml cloud-init.yaml
cat ~/.ssh/cilium-k0s.pub | xargs -I{} echo "      - {}" >> cloud-init.yaml

# creating netowrk bridge for the cluster nodes
nmcli connection add type bridge con-name localbr ifname localbr ipv4.method manual ipv4.addresses 192.168.0.240/24

# waiting for multipass to be ready
sleep 10

# launching the cluster nodes with the cloud-init configuration
multipass launch -n cp01 -c 4 -m 2G -d 5G --network name=localbr,mode=manual --cloud-init ./cloud-init.yaml
multipass launch -n worker01 -c 6 -m 3G -d 10G --network name=localbr,mode=manual --cloud-init ./cloud-init.yaml
multipass launch -n worker02 -c 6 -m 3G -d 10G --network name=localbr,mode=manual --cloud-init ./cloud-init.yaml

# setting the static IP addresses for the cluster nodes
CP01_MAC=$(multipass exec -n cp01 -- ip a | awk '/link\/ether/ {print $2}' | sed -n '2p')
Worker01_MAC=$(multipass exec -n worker01 -- ip a | awk '/link\/ether/ {print $2}' | sed -n '2p')
Worker02_MAC=$(multipass exec -n worker02 -- ip a | awk '/link\/ether/ {print $2}' | sed -n '2p')
cp static-ip-address-template.yaml static-ip-address.yaml
sed -i "s/<MAC_ADDRESS>/${CP01_MAC}/g" static-ip-address.yaml
sed -i "s/<IP_ADDRESS>/192.168.0.241/g" static-ip-address.yaml
cat static-ip-address.yaml | multipass exec -n cp01 -- sudo bash -c 'cat > /etc/netplan/10-custom.yaml'
multipass exec -n cp01 -- sudo netplan apply
Worker01_MAC=$(multipass exec -n worker01 -- ip a | awk '/link\/ether/ {print $2}' | sed -n '2p')
cp static-ip-address-template.yaml static-ip-address.yaml
sed -i "s/<MAC_ADDRESS>/${Worker01_MAC}/g" static-ip-address.yaml
sed -i "s/<IP_ADDRESS>/192.168.0.242/g" static-ip-address.yaml
cat static-ip-address.yaml | multipass exec -n worker01 -- sudo bash -c 'cat > /etc/netplan/10-custom.yaml'
multipass exec -n worker01 -- sudo netplan apply
Worker02_MAC=$(multipass exec -n worker02 -- ip a | awk '/link\/ether/ {print $2}' | sed -n '2p')
cp static-ip-address-template.yaml static-ip-address.yaml
sed -i "s/<MAC_ADDRESS>/${Worker02_MAC}/g" static-ip-address.yaml
sed -i "s/<IP_ADDRESS>/192.168.0.243/g" static-ip-address.yaml
cat static-ip-address.yaml | multipass exec -n worker02 -- sudo bash -c 'cat > /etc/netplan/10-custom.yaml'
multipass exec -n worker02 -- sudo netplan apply

# waiting for the nodes to be up and running
sleep 30

# applying the cilium cluster configuration
cp cilium-cluster-template.yaml cilium-cluster.yaml
multipass info cp01 --format json | jq .info.cp01.ipv4[1] | xargs -I{} sed -i 's/<CP01Address>/{}/g' cilium-cluster.yaml
multipass info worker01 --format json | jq .info.worker01.ipv4[1] | xargs -I{} sed -i 's/<Worker01Address>/{}/g' cilium-cluster.yaml
multipass info worker02 --format json | jq .info.worker02.ipv4[1] | xargs -I{} sed -i 's/<Worker02Address>/{}/g' cilium-cluster.yaml
k0sctl apply --config cilium-cluster.yaml
