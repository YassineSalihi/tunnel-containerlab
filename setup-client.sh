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
  if [ ! -f softether-vpnclient-v4.43-9799-beta-2023.08.31-linux-x64-64bit.tar.gz ]; then
    wget -q https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/v4.43-9799-beta/softether-vpnclient-v4.43-9799-beta-2023.08.31-linux-x64-64bit.tar.gz
  fi
  if [ ! -d vpnclient ]; then
    tar xzf softether-vpnclient*.tar.gz
  fi
"

echo "[*] Compiling SoftEther client..."
docker exec clab-vpn-lab-vpn-client bash -c "
  cd /tmp/vpnclient
  if [ ! -f vpnclient ]; then
    printf '1\n1\n1\n' | make
  else
    echo 'Already compiled, skipping.'
  fi
"

echo "[*] Starting VPN client..."
docker exec clab-vpn-lab-vpn-client bash -c "
  cd /tmp/vpnclient
  ./vpnclient stop 2>/dev/null || true
  sleep 1
  ./vpnclient start
"
sleep 3

echo "[*] Creating NIC and connection profile..."
docker exec clab-vpn-lab-vpn-client bash -c "
  cd /tmp/vpnclient
  cat > /tmp/client_cmds.txt << 'EOF'
NicCreate vpn0
AccountCreate lab /SERVER:10.0.2.10:443 /HUB:VPN /USERNAME:vpnuser /NICNAME:vpn0
AccountPasswordSet lab /PASSWORD:rootroot /TYPE:standard
AccountConnect lab
exit
EOF
  ./vpncmd localhost /CLIENT /IN:/tmp/client_cmds.txt 2>/dev/null || true
"

echo "[*] Waiting 8 seconds for tunnel to establish..."
sleep 8

echo "[*] Checking tunnel status..."
docker exec clab-vpn-lab-vpn-client bash -c "
  cd /tmp/vpnclient
  printf 'AccountStatusGet lab\nexit\n' | ./vpncmd localhost /CLIENT 2>/dev/null | grep -E 'Session Status|Protocol|Encryption|Sessions'
"

echo "[*] Requesting DHCP on tunnel NIC..."
docker exec clab-vpn-lab-vpn-client bash -c "
  sleep 2
  dhclient vpn_vpn0 2>/dev/null || true
  ip addr show vpn_vpn0 2>/dev/null || echo 'vpn_vpn0 not yet available — run dhclient vpn_vpn0 manually inside the container'
"

echo ""
echo "[+] VPN client setup complete."
echo "[+] If tunnel shows Retrying, the server config may need manual setup."
echo "[+] To check manually:"
echo "    sudo docker exec -it clab-vpn-lab-vpn-client bash"
echo "    cd /tmp/vpnclient && ./vpncmd"
echo "    Select 2 -> Enter -> Enter -> AccountStatusGet lab"
