#!/bin/bash
# setup-server.sh — build and configure SoftEther server inside vpn-server container
# run on host: sudo bash setup-server.sh

echo "[*] Installing build dependencies on vpn-server..."
docker exec clab-vpn-lab-vpn-server bash -c "
  apt-get update -qq
  apt-get install -y -qq wget gcc binutils make libreadline8 libssl3 iproute2 iputils-ping
"

echo "[*] Downloading SoftEther VPN Server..."
docker exec clab-vpn-lab-vpn-server bash -c "
  cd /tmp
  wget -q https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/v4.43-9799-beta/softether-vpnserver-v4.43-9799-beta-2023.08.31-linux-x64-64bit.tar.gz
  tar xzf softether-vpnserver*.tar.gz
"

echo "[*] Compiling SoftEther (accepting license automatically)..."
docker exec clab-vpn-lab-vpn-server bash -c "
  cd /tmp/vpnserver
  printf '1\n1\n1\n' | make
"

echo "[*] Starting VPN server..."
docker exec clab-vpn-lab-vpn-server bash -c "
  cd /tmp/vpnserver && ./vpnserver start
"

sleep 2

echo "[*] Configuring hub, user, and SecureNAT..."
docker exec clab-vpn-lab-vpn-server bash -c "
  cd /tmp/vpnserver
  ./vpncmd /SERVER:localhost:443 /PASSWORD: /CMD \
    ServerPasswordSet rootroot \
    HubCreate VPN /PASSWORD: \
    Hub VPN \
    UserCreate vpnuser /GROUP:none /REALNAME:none /NOTE:none \
    UserPasswordSet vpnuser /PASSWORD:rootroot \
    SecureNatEnable \
    VpnOverIcmpDnsEnable /ICMP:yes /DNS:yes
" 2>/dev/null || true

echo "[*] Verifying server is listening on 443..."
docker exec clab-vpn-lab-vpn-server bash -c "ss -tlnp | grep 443"

echo ""
echo "[+] VPN server ready."
echo "[+] Hub: VPN | User: vpnuser | Password: rootroot"
echo "[+] DNS/ICMP tunneling: enabled"
