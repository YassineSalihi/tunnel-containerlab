#!/bin/bash
# setup-server.sh — build and configure SoftEther server inside vpn-server container
# run on host: sudo bash setup-server.sh

echo "[*] Installing build dependencies on vpn-server..."
docker exec clab-vpn-lab-vpn-server bash -c "
  apt-get update -qq
  apt-get install -y -qq wget gcc binutils make libreadline8 libssl3 iproute2 iputils-ping net-tools
"

echo "[*] Downloading SoftEther VPN Server..."
docker exec clab-vpn-lab-vpn-server bash -c "
  cd /tmp
  if [ ! -f softether-vpnserver-v4.43-9799-beta-2023.08.31-linux-x64-64bit.tar.gz ]; then
    wget -q https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/v4.43-9799-beta/softether-vpnserver-v4.43-9799-beta-2023.08.31-linux-x64-64bit.tar.gz
  fi
  if [ ! -d vpnserver ]; then
    tar xzf softether-vpnserver*.tar.gz
  fi
"

echo "[*] Compiling SoftEther..."
docker exec clab-vpn-lab-vpn-server bash -c "
  cd /tmp/vpnserver
  if [ ! -f vpnserver ]; then
    printf '1\n1\n1\n' | make
  else
    echo 'Already compiled, skipping.'
  fi
"

echo "[*] Starting VPN server..."
docker exec clab-vpn-lab-vpn-server bash -c "
  cd /tmp/vpnserver
  ./vpnserver stop 2>/dev/null || true
  sleep 1
  ./vpnserver start
"
sleep 3

echo "[*] Configuring hub, user, SecureNAT and fallback protocols..."
docker exec clab-vpn-lab-vpn-server bash -c "
  cd /tmp/vpnserver
  cat > /tmp/server_cmds.txt << 'EOF'
ServerPasswordSet
rootroot
rootroot
HubCreate VPN
/PASSWORD:
Hub VPN
UserCreate vpnuser /GROUP:none /REALNAME:none /NOTE:none
UserPasswordSet vpnuser
rootroot
rootroot
SecureNatEnable
VpnOverIcmpDnsEnable /ICMP:yes /DNS:yes
exit
EOF
  ./vpncmd localhost:443 /SERVER /IN:/tmp/server_cmds.txt 2>/dev/null || true
"

sleep 2

echo "[*] Verifying hub and user..."
docker exec clab-vpn-lab-vpn-server bash -c "
  cd /tmp/vpnserver
  printf 'HubList\nexit\n' | ./vpncmd localhost:443 /SERVER /PASSWORD:rootroot 2>/dev/null | grep -E 'VPN|Hub Name' || echo 'Check manually with vpncmd'
"

echo "[*] Verifying server is listening on 443..."
docker exec clab-vpn-lab-vpn-server bash -c "ss -tlnp | grep 443"

echo ""
echo "[+] VPN server setup complete."
echo "[+] Hub: VPN | User: vpnuser | Password: rootroot"
echo "[+] If hub/user creation failed, run manually:"
echo "    sudo docker exec -it clab-vpn-lab-vpn-server bash"
echo "    cd /tmp/vpnserver && ./vpncmd"
