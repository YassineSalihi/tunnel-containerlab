#!/bin/bash
# setup-ips.sh — configure all container IPs for vpn-lab
# run on host: sudo bash setup-ips.sh

echo "[*] Installing iproute2 on all containers..."
docker exec clab-vpn-lab-vpn-client bash -c "apt-get update -qq && apt-get install -y -qq iproute2 iputils-ping curl wget" 2>/dev/null
docker exec clab-vpn-lab-firewall bash -c "apt-get update -qq && apt-get install -y -qq iproute2 iputils-ping iptables nftables" 2>/dev/null
docker exec clab-vpn-lab-vpn-server bash -c "apt-get update -qq && apt-get install -y -qq iproute2 iputils-ping" 2>/dev/null

echo "[*] Configuring vpn-client (eth1 -> 10.0.1.10)..."
docker exec clab-vpn-lab-vpn-client bash -c "
  ip addr add 10.0.1.10/24 dev eth1 2>/dev/null || true
  ip link set eth1 up
  ip route add 10.0.2.0/24 via 10.0.1.1 2>/dev/null || true
"

echo "[*] Configuring firewall (eth2 -> 10.0.1.1, eth3 -> 10.0.2.1)..."
docker exec clab-vpn-lab-firewall bash -c "
  ip addr add 10.0.1.1/24 dev eth2 2>/dev/null || true
  ip addr add 10.0.2.1/24 dev eth3 2>/dev/null || true
  ip link set eth2 up
  ip link set eth3 up
  echo 1 > /proc/sys/net/ipv4/ip_forward
"

echo "[*] Configuring vpn-server (eth4 -> 10.0.2.10)..."
docker exec clab-vpn-lab-vpn-server bash -c "
  ip addr add 10.0.2.10/24 dev eth4 2>/dev/null || true
  ip link set eth4 up
  ip route add 10.0.1.0/24 via 10.0.2.1 2>/dev/null || true
"

echo "[*] Testing connectivity..."
docker exec clab-vpn-lab-vpn-client ping -c 3 10.0.2.10
echo ""
echo "[+] Done. If ping shows 0% loss, topology is ready."
echo "[+] Next: start vpnserver inside vpn-server container."
