# Project 8 — NAT and Filtering-Tolerant VPN
**Author:** Salihi Yassine && Zouine Razane  
**Date:** May 2026  

---

## Table of Contents
1. [Objectives](#objectives)
2. [Tools and Environment](#tools-and-environment)
3. [Topology](#topology)
4. [Network Addressing](#network-addressing)
5. [VPN Configuration](#vpn-configuration)
6. [Filtering Rules](#filtering-rules)
7. [Test Results](#test-results)
8. [Technical Analysis](#technical-analysis)
9. [Conditions of Success and Failure](#conditions-of-success-and-failure)
10. [Conclusion](#conclusion)

---

## Objectives

- Design a VPN solution capable of operating in a filtered network environment
- Use a transport mode and port compatible with restrictive firewall policies
- Simulate a filtering firewall between client and server
- Verify that the tunnel can establish despite imposed restrictions
- Document success conditions and failure cases

---

## Tools and Environment

| Tool | Version | Role |
|------|---------|------|
| Arch Linux (host) | rolling | Host machine |
| containerlab | 0.75.0 | Network topology emulation (GNS3 alternative) |
| Docker / debian:bookworm-slim | 24.x | Container runtime for all nodes |
| SoftEther VPN | v4.43 build 9799 | VPN server and client |
| nftables | kernel 6.x | Packet filtering (Scenario A) |
| iptables-nft | 1.8.9 | Packet filtering (Scenarios B and C) |
| tcpdump / Wireshark | latest | Traffic capture and analysis |

### Why containerlab instead of GNS3

GNS3 on Arch Linux suffers from dependency conflicts (Qt version mismatches,
outdated AUR packages) and requires managing QEMU VMs which are slow to boot
and reset. containerlab replaces GNS3 by using Docker containers as network
nodes connected via virtual ethernet pairs. The result is identical in terms
of network isolation and routing behavior, but topology deployment takes under
5 seconds instead of several minutes. Each container gets its own network
namespace, making it a proper isolated node.

---

## Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                    containerlab: vpn-lab                        │
│                                                                  │
│  ┌─────────────┐    net-client      ┌──────────────┐            │
│  │  vpn-client │    10.0.1.0/24     │   firewall   │            │
│  │ 10.0.1.10   │◄──────────────────►│ 10.0.1.1     │            │
│  │             │    eth1 ↔ eth2     │              │            │
│  └─────────────┘                    │ 10.0.2.1     │            │
│                                     │              │            │
│                    net-server       └──────┬───────┘            │
│                    10.0.2.0/24            │                     │
│                                    eth3 ↔ eth4                  │
│                                           │                     │
│                                    ┌──────▼───────┐            │
│                                    │  vpn-server  │            │
│                                    │  10.0.2.10   │            │
│                                    └──────────────┘            │
│                                                                  │
│  ╔══════════════════════════════════════════════════════╗       │
│  ║  SoftEther VPN tunnel (port 443/TCP or DNS/UDP)      ║       │
│  ║  vpn-client ════════════════════════════ vpn-server  ║       │
│  ╚══════════════════════════════════════════════════════╝       │
└─────────────────────────────────────────────────────────────────┘
```

The firewall node has two network interfaces — one in each segment — making
it the mandatory transit point for all traffic between client and server.
All filtering rules are applied on the firewall's FORWARD chain, which
processes packets passing through rather than destined for the firewall itself.

### topology.yml (containerlab definition)

```yaml
name: vpn-lab

topology:
  nodes:
    vpn-client:
      kind: linux
      image: debian:bookworm-slim

    firewall:
      kind: linux
      image: debian:bookworm-slim

    vpn-server:
      kind: linux
      image: debian:bookworm-slim

  links:
    - endpoints: ["vpn-client:eth1", "firewall:eth2"]
    - endpoints: ["firewall:eth3", "vpn-server:eth4"]
```

---

## Network Addressing

| Node | Interface | IP Address | Role |
|------|-----------|------------|------|
| vpn-client | eth1 | 10.0.1.10/24 | Client LAN interface |
| firewall | eth2 | 10.0.1.1/24 | Gateway for client segment |
| firewall | eth3 | 10.0.2.1/24 | Gateway for server segment |
| vpn-server | eth4 | 10.0.2.10/24 | Server LAN interface |
| vpn-client | vpn_vpn0 | 192.168.30.10/24 | Virtual NIC (SoftEther tunnel) |
| vpn-server | SecureNAT | 192.168.30.1/24 | Virtual gateway (SecureNAT) |

Routing was configured manually on each container:
- vpn-client default route via 10.0.1.1 (firewall)
- vpn-server default route via 10.0.2.1 (firewall)
- ip_forward enabled on firewall: `echo 1 > /proc/sys/net/ipv4/ip_forward`

---

## VPN Configuration

### Server setup (vpn-server container)

SoftEther was compiled from source on debian:bookworm-slim:

```bash
apt install -y wget gcc binutils libreadline8 libssl3 make
cd /tmp && wget <softether-vpnserver-v4.43-linux-x64.tar.gz>
tar xzf softether-vpnserver*.tar.gz && cd vpnserver && make
./vpnserver start
```

Configuration via vpncmd:

```
ServerPasswordSet          # admin password: rootroot
HubCreate VPN              # virtual hub named VPN
Hub VPN
UserCreate vpnuser         # VPN user
UserPasswordSet vpnuser    # password: rootroot
SecureNatEnable            # enable virtual NAT + DHCP (192.168.30.0/24)
VpnOverIcmpDnsEnable /ICMP:yes /DNS:yes   # enable fallback protocols
```

SoftEther listeners active:
- TCP port 443 (primary — HTTPS-compatible)
- ICMP (fallback when TCP blocked)
- DNS/UDP port 53 (fallback when TCP and ICMP blocked)

### Client setup (vpn-client container)

```bash
apt install -y wget gcc binutils libreadline8 libssl3 make
cd /tmp && wget <softether-vpnclient-v4.43-linux-x64.tar.gz>
tar xzf softether-vpnclient*.tar.gz && cd vpnclient && make
./vpnclient start
```

Configuration via vpncmd:

```
NicCreate vpn0
AccountCreate lab /SERVER:10.0.2.10:443 /HUB:VPN /USERNAME:vpnuser /NICNAME:vpn0
AccountPasswordSet lab /PASSWORD:rootroot /TYPE:standard
AccountConnect lab
```

DHCP lease on virtual NIC:
```bash
dhclient vpn_vpn0
# Result: 192.168.30.10/24 assigned by SecureNAT
```

---

## Filtering Rules

### Scenario A — Port whitelist (nftables)

```nft
table inet filter {
    chain forward {
        type filter hook forward priority filter; policy drop;
        ct state established,related accept
        tcp dport { 80, 443 } accept
        tcp sport { 80, 443 } accept
    }
}
```

Applied via:
```bash
nft add table inet filter
nft add chain inet filter forward { type filter hook forward priority 0 \; policy drop \; }
nft add rule inet filter forward ct state established,related accept
nft add rule inet filter forward tcp dport { 80, 443 } accept
nft add rule inet filter forward tcp sport { 80, 443 } accept
```

### Scenario B — DPI string matching (iptables) + TCP/443 block

```bash
# Phase 1: string matching to simulate DPI
iptables -I FORWARD -i eth2 -m string --string "VPN" --algo bm -j DROP
iptables -I FORWARD -i eth2 -m string --string "SoftEther" --algo bm -j DROP

# Phase 2: hard TCP/443 block to test DNS fallback
iptables -I FORWARD -p tcp --dport 443 -j DROP
iptables -I FORWARD -p tcp --sport 443 -j DROP
```

### Scenario C — Full block (iptables)

```bash
iptables -I FORWARD -p tcp --dport 443 -j DROP
iptables -I FORWARD -p tcp --sport 443 -j DROP
iptables -I FORWARD -p udp -j DROP
iptables -I FORWARD -p icmp -j DROP
```

---

## Test Results

### Baseline (no filtering)

| Metric | Value |
|--------|-------|
| Raw ping client→server | 0% loss, ~0.1ms |
| VPN tunnel ping (192.168.30.1) | 0% loss, ~0.96ms |
| Protocol | TCP port 443 |
| Encryption | TLS_AES_256_GCM_SHA384 |
| Sessions established | 1 |
| Physical underlay | Standard TCP/IP (IPv4) |

> Screenshot slot: AccountStatusGet showing "Connection Completed (Session Established)"

---

### Scenario A — Port whitelist

| Metric | Value |
|--------|-------|
| Rules | allow TCP 80/443, drop all else |
| Tunnel status | **Connected** |
| Ping through tunnel | 0% loss, ~1ms |
| Sessions established | 1 |
| Protocol change | None — already on 443 |

**Result: PASS** — Tunnel survives port-based filtering.

> Screenshot slot: ping output showing 0% loss with nftables rules active

---

### Scenario B — DPI simulation and bypass

**Phase 1 — String matching blocks tunnel:**

| Metric | Value |
|--------|-------|
| Rules | DROP packets containing "VPN" or "SoftEther" strings |
| Tunnel status | **Retrying** |
| Sessions established | 0 |
| Error | Handshake never completes |

**Result: BLOCKED** — DPI string matching defeats SoftEther on port 443.

> Screenshot slot: AccountStatusGet showing "Retrying"

**Phase 2 — DNS tunneling bypass:**

| Metric | Value |
|--------|-------|
| Rules | DROP tcp/443 both directions |
| Bypass method | VpnOverIcmpDnsEnable (DNS/UDP fallback) |
| Tunnel status | **Connected** |
| Sessions established | 1 |
| Physical underlay | **VPN over DNS (IPv4)RUDP/DNS** |
| Encryption | TLS_AES_256_GCM_SHA384 (maintained) |

**Result: BYPASS SUCCESS** — SoftEther automatically fell back to DNS
tunneling when TCP/443 was blocked.

> Screenshot slot: AccountStatusGet showing "VPN over DNS (IPv4)RUDP/DNS"

---

### Scenario C — Full block

| Metric | Value |
|--------|-------|
| Rules | DROP tcp/443, DROP udp, DROP icmp |
| Tunnel status | **Retrying / Connection to VPN Server Started** |
| Sessions established | 0 |
| Protocols attempted | TCP/443 → DNS/UDP → ICMP → all blocked |

**Result: FAIL (expected)** — No protocol available, tunnel cannot establish.

> Screenshot slot: AccountStatusGet cycling between Retrying and "Connection to VPN Server Started"

---

## Technical Analysis

### Why SoftEther is resistant to filtering

SoftEther was designed from the ground up to be tolerant of restrictive
network environments. Its resilience comes from three architectural decisions:

**1. Port 443 as primary transport**

Port 443 is the standard HTTPS port. Any network that blocks 443 also breaks
all encrypted web browsing, which makes it impractical for most organizations
to block. SoftEther wraps its protocol in a TLS handshake that is
indistinguishable from normal HTTPS at the port level. This is why Scenario A
(port whitelist) had no impact — the tunnel was already using the only
allowed port.

**2. Protocol fallback chain**

When the primary TCP/443 path is blocked, SoftEther automatically tries
alternative transport protocols in sequence:

```
TCP/443 → failed
    ↓
ICMP tunnel → try encapsulating in ping packets
    ↓
DNS/UDP tunnel → encapsulate in DNS query/response packets
    ↓
All failed → give up (Scenario C)
```

In Scenario B we observed SoftEther successfully falling back to DNS tunneling
(Physical Underlay: `VPN over DNS (IPv4)RUDP/DNS`). DNS traffic on UDP/53 is
allowed by almost every network because blocking it breaks domain name
resolution entirely, making it an effective covert channel.

**3. TLS encryption of payload**

In all successful scenarios, encryption remained TLS_AES_256_GCM_SHA384
regardless of the transport protocol. The VPN payload is always encrypted,
making deep content inspection ineffective even when the transport is DNS.

### Why DPI string matching worked (and its limits)

The iptables string module (`-m string`) performs simple Boyer-Moore pattern
matching on packet payloads. SoftEther embeds its protocol name and version
strings in the initial handshake, which made it detectable. However this
approach has significant limitations in practice:

- It only works on unencrypted portions of the handshake (the TLS ClientHello
  and early negotiation bytes)
- It requires the firewall to inspect every packet payload, which is CPU
  intensive at scale
- It is trivially bypassed by obfuscation, custom builds that remove the
  strings, or switching to a different transport (as demonstrated)
- Real DPI appliances use statistical traffic analysis and protocol fingerprinting
  rather than simple string matching

### Why the full block (Scenario C) succeeded

Scenario C works because it closes every protocol SoftEther can use:

| Protocol | Blocked by | SoftEther use |
|----------|------------|---------------|
| TCP/443 | iptables dport/sport 443 | Primary transport |
| UDP (all) | iptables -p udp | DNS tunneling fallback |
| ICMP | iptables -p icmp | ICMP tunneling fallback |

With all three blocked, SoftEther has no transport mechanism available.
This represents a whitelist-only egress policy — only explicitly permitted
traffic is allowed — which is the most effective but also most restrictive
approach. In practice this breaks most legitimate network functionality
(no DNS resolution, no ICMP/ping diagnostics) and requires careful
management of the whitelist.

### Comparison of filtering approaches

| Approach | Blocks SoftEther | Collateral damage | Real-world feasibility |
|----------|-----------------|-------------------|----------------------|
| Port blacklist (non-443) | No | Low | High |
| Port whitelist (443 only) | No | Medium | Medium |
| DPI string matching | Partially | Low | Medium |
| Block TCP/443 | No (DNS fallback) | High | Low |
| Block TCP + UDP + ICMP | Yes | Very high | Very low |

### NAT tolerance

SoftEther is NAT-tolerant by design. The containerlab topology did not use
NAT, but SoftEther's use of TCP/443 and UDP makes it traverse NAT devices
naturally since both protocols support NAT traversal. The RUDP (Reliable UDP)
implementation includes hole-punching for NAT traversal, visible in the
status output: `IPv4 UDPAccel_Ver=2 ChachaPoly_OpenSSL UDPAccel_MSS=1309`.

---

## Conditions of Success and Failure

### Success conditions

| Condition | Result |
|-----------|--------|
| Network allows TCP/443 | Tunnel establishes natively |
| TCP/443 blocked, UDP/53 allowed | Tunnel establishes via DNS |
| TCP/443 blocked, ICMP allowed | Tunnel establishes via ICMP |
| NAT present (no filtering) | Tunnel establishes (NAT-tolerant) |
| DPI string matching only | Tunnel blocked then bypassed via DNS |

### Failure conditions

| Condition | Result |
|-----------|--------|
| TCP/443 + UDP + ICMP all blocked | Tunnel cannot establish |
| Whitelist-only egress (no DNS/ICMP) | Tunnel cannot establish |
| SoftEther v4.43 vs advanced DPI | No built-in obfuscation available |

### Recommended countermeasures (for network defenders)

To reliably block SoftEther and similar resilient VPNs:
1. Implement strict egress whitelist — only permit traffic to known destinations
2. Use stateful DPI appliances (not simple string matching) for protocol fingerprinting
3. Block or proxy DNS to prevent DNS tunneling
4. Consider SSL/TLS inspection for traffic on port 443

### Recommended improvements (for VPN resilience)

For even greater resistance to filtering:
1. Upgrade to SoftEther v5 which includes obfuscation support
2. Wrap the tunnel in obfs4proxy or Shadowsocks for additional obfuscation
3. Use a domain fronting technique to hide the server destination
4. Run the server on a cloud provider with a CDN IP (harder to block without
   collateral damage)

---

## Conclusion

This project demonstrated that SoftEther VPN is highly tolerant of network
filtering when configured correctly. Port-based filtering is completely
ineffective because SoftEther operates on port 443 by default. Simple DPI
string matching can block the initial handshake but is bypassed automatically
by the DNS tunneling fallback. Only a comprehensive block of all usable
protocols (TCP/443, UDP, ICMP) successfully prevents tunnel establishment,
at the cost of severely disrupting legitimate network functionality.

The project also validated containerlab as a practical GNS3 alternative for
network security labs on Linux. The 3-node topology deployed in under 5 seconds
and provided full network isolation, routing, and packet-level filtering
capabilities equivalent to a hardware lab environment.

| Deliverable | Status |
|-------------|--------|
| Topology with filtering zone | Complete |
| Filtering rules used | Complete |
| VPN configuration | Complete |
| Test results (3 scenarios) | Complete |
| Technical analysis | Complete |

---

*Lab environment: Arch Linux host, containerlab 0.75.0, SoftEther v4.43 build 9799*
