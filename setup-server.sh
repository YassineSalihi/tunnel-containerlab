#!/bin/bash
# run inside vpn-server container
apt update && apt install -y wget libreadline8 libssl3 make curl
cd /tmp
wget -q https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/v4.43-9799-beta/softether-vpnserver-v4.43-9799-beta-2023.08.31-linux-x64-64bit.tar.gz
tar xzf softether-vpnserver*.tar.gz
cd vpnserver && make
