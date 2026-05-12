#!/bin/bash
# run on host to configure all container IPs at once
docker exec clab-vpn-lab-vpn-client bash -c "
  ip addr add 10.0.1.10/24 dev eth1
  ip link set eth1 up
  ip route add 10.0.2.0/24 via 10.0.1.1"

docker exec clab-vpn-lab-firewall bash -c "
  ip addr add 10.0.1.1/24 dev eth2
  ip addr add 10.0.2.1/24 dev eth3
  ip link set eth2 up
  ip link set eth3 up
  echo 1 > /proc/sys/net/ipv4/ip_forward"

docker exec clab-vpn-lab-vpn-server bash -c "
  ip addr add 10.0.2.10/24 dev eth4
  ip link set eth4 up
  ip route add 10.0.1.0/24 via 10.0.2.1"

echo "All IPs configured. Testing ping..."
docker exec clab-vpn-lab-vpn-client ping -c 3 10.0.2.10
