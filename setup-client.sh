#!/bin/bash
# setup-client.sh — build and configure SoftEther client inside vpn-client container
# run on host: sudo bash setup-client.sh

echo "[*] Installing build dependencies on vpn-client..."
docker exec clab-vpn-lab-vpn-client bash -c "
  apt-get update -qq
  apt-get install -y -qq wget gcc binutils make libreadline8 libssl3 iproute2 iputils-ping isc-dhcp-client
"

echo "[*] Downloading SoftEther VPN Client..."
docker exec clab-vpn-lab-vpn-client bash -c "
  cd /tmp
  wget -q https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/v4.43-9799-beta/softether-vpnclient-v4.43-9799-beta-2023.08.31-linux-x64-64bit.tar.gz
  tar xzf softether-vpnclient*.tar.gz
"

echo "[*] Compiling SoftEther client (accepting license automatically)..."
docker exec clab-vpn-lab-vpn-client bash -c "
  cd /tmp/vpnclient
  printf '1\n1\n1\n' | make
"

echo "[*] Starting VPN client..."
docker exec clab-vpn-lab-vpn-client bash -c "
  cd /tmp/vpnclient && ./vpnclient start
"

sleep 2

echo "[*] Creating VPN connection profile..."
docker exec clab-vpn-lab-vpn-client bash -c "
  cd /tmp/vpnclient
  ./vpncmd /CLIENT:localhost /CMD \
    NicCreate vpn0 \
    AccountCreate lab /SERVER:10.0.2.10:443 /HUB:VPN /USERNAME:vpnuser /NICNAME:vpn0 \
    AccountPasswordSet lab /PASSWORD:rootroot /TYPE:standard \
    AccountConnect lab
"

echo "[*] Waiting for tunnel to establish..."
sleep 5

echo "[*] Checking tunnel status..."
docker exec clab-vpn-lab-vpn-client bash -c "
  cd /tmp/vpnclient
  ./vpncmd /CLIENT:localhost /CMD AccountStatusGet lab
"

echo "[*] Requesting DHCP on tunnel NIC..."
docker exec clab-vpn-lab-vpn-client bash -c "dhclient vpn_vpn0 2>/dev/null; ip addr show vpn_vpn0"

echo ""
echo "[+] VPN client ready."
echo "[+] Tunnel NIC: vpn_vpn0 should have 192.168.30.x address"
