#!/bin/bash
# start-lab.sh — full lab startup from scratch
# run on host: sudo bash start-lab.sh
# use after reboot or --reconfigure

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================"
echo "  vpn-lab startup script"
echo "================================================"

echo ""
echo "[1/5] Starting Docker..."
systemctl start docker
sleep 1

echo ""
echo "[2/5] Deploying containerlab topology..."
cd "$SCRIPT_DIR"
containerlab deploy --reconfigure -t topology.yml
sleep 2

echo ""
echo "[3/5] Configuring IPs on all containers..."
bash "$SCRIPT_DIR/setup-ips.sh"

echo ""
echo "[4/5] Setting up SoftEther server..."
bash "$SCRIPT_DIR/setup-server.sh"

echo ""
echo "[5/5] Setting up SoftEther client..."
bash "$SCRIPT_DIR/setup-client.sh"

echo ""
echo "================================================"
echo "  Lab is ready!"
echo "================================================"
echo ""
echo "  Containers:"
echo "    sudo docker exec -it clab-vpn-lab-vpn-client bash"
echo "    sudo docker exec -it clab-vpn-lab-firewall bash"
echo "    sudo docker exec -it clab-vpn-lab-vpn-server bash"
echo ""
echo "  Verify tunnel:"
echo "    sudo docker exec clab-vpn-lab-vpn-client ping -c 3 192.168.30.1"
echo ""
echo "  VPN status:"
echo "    sudo docker exec clab-vpn-lab-vpn-client /tmp/vpnclient/vpncmd /CLIENT:localhost /CMD AccountStatusGet lab"
echo "================================================"
