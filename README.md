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

