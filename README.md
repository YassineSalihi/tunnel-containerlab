# Project 8 — NAT/filtering-tolerant VPN

## Topology
- 3 nodes: vpn-client, firewall, vpn-server
- 2 segments: net-client (10.0.1.0/24), net-server (10.0.2.0/24)
- Tool: containerlab + Docker (debian:bookworm-slim)

## Network addressing
| Node       | Interface | IP          |
|------------|-----------|-------------|
| vpn-client | eth1      | 10.0.1.10   |
| firewall   | eth2      | 10.0.1.1    |
| firewall   | eth3      | 10.0.2.1    |
| vpn-server | eth4      | 10.0.2.10   |

## Filtering rules
(fill in Day 3)

## VPN configuration
(fill in Day 2)

## Test results
### Scenario A — port whitelist
### Scenario B — DPI simulation  
### Scenario C — full block

## Analysis
(fill in Day 4)

## Setup log

### Day 1 — topology deployed
- containerlab 0.75.0, debian:bookworm-slim
- All 3 containers running
- IP addressing configured manually on eth1-eth4
- Verified: vpn-client -> vpn-server ping 0% loss, ~0.1ms


### Day 2 — VPN tunnel established
- SoftEther v4.43 build 9799
- Protocol: TLS_AES_256_GCM_SHA384 over TCP port 443
- Hub: VPN, User: vpnuser
- Status: Session Established, 1 session, full duplex
- SecureNAT enabled on server


### Day 2 — Tunnel verification
- vpn_vpn0 NIC created on client, IP: 192.168.30.10/24 (SecureNAT DHCP)
- SecureNAT gateway: 192.168.30.1 (server-side virtual gateway)
- Ping through tunnel: 0% loss, ~0.96ms avg, TTL=128
- Encryption confirmed: TLS_AES_256_GCM_SHA384
- Baseline established: tunnel works with no filtering rules in place

## Baseline traffic summary
| Test | Result |
|------|--------|
| client -> server (raw) | 0% loss, ~0.1ms |
| client -> tunnel gateway | 0% loss, ~0.96ms |
| VPN protocol | SoftEther over TCP/443 |
| Encryption | TLS_AES_256_GCM_SHA384 |


## Day 3 — Filtering and bypass

### What is nftables
nftables is the Linux kernel's packet filtering framework. It replaces iptables.
Rules are applied on the firewall container which sits between client and server.
All traffic must pass through it, so rules here affect the VPN tunnel directly.

### Filtering logic
Traffic flows: vpn-client -> firewall (eth2) -> firewall (eth3) -> vpn-server
The FORWARD chain handles packets passing through (not destined for the firewall itself).

---

### Scenario A — port whitelist
**Rule:** allow only TCP ports 80 and 443, drop everything else
**Hypothesis:** tunnel survives because SoftEther uses port 443 natively
**Result:** (fill after test)
**Pcap:** (attach screenshot)

---

### Scenario B — DPI simulation
**Rule:** block packets containing SoftEther protocol signatures
**Hypothesis:** tunnel breaks, obfuscation mode bypasses the block
**Result:** (fill after test)
**Pcap:** (attach screenshot)

---

### Scenario C — full block
**Rule:** drop all forwarded traffic
**Hypothesis:** tunnel fails, no bypass possible
**Result:** (fill after test)
**Pcap:** (attach screenshot)

