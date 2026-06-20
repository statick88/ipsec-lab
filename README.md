<![CDATA[<div align="center">

# 🔐 IPsec Tunnel Lab

### IKEv2/ESP Tunnel with strongSwan on Docker

[![CI/CD](https://github.com/statick88/ipsec-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/statick88/ipsec-lab/actions/workflows/ci.yml)
[![Docker Image](https://img.shields.io/docker/image-size/statick/ipsec-lab?sort=semver&label=docker)](https://hub.docker.com/r/statick/ipsec-lab)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![strongSwan](https://img.shields.io/badge/strongSwan-5.9.5-green.svg)](https://docs.strongswan.org)
[![Platform](https://img.shields.io/badge/platform-Docker%20%7C%20Linux-lightgrey.svg)]()

**Practical lab demonstrating IPsec IKEv2/ESP tunnel establishment, ESP traffic encryption,
and Wireshark packet decryption using strongSwan network namespaces.**

[Quick Start](#-quick-start) · [Architecture](#-architecture) · [Wireshark](#-wireshark-decryption) · [Docker Hub](https://hub.docker.com/r/statick/ipsec-lab) · [Report (PDF)](evidence/IPsec_Lab_Informe.pdf)

</div>

---

## Overview

This lab builds a **complete IPsec VPN** inside a single Docker container using Linux network namespaces to simulate two independent gateways connected by a veth pair. The tunnel encrypts all traffic between protected subnets using **AES-CBC-256** (cipher) and **HMAC-SHA-256-128** (integrity).

```
                    ┌─────────────────────────────────────────────┐
                    │           Docker Container (privileged)     │
                    │                                             │
                    │   ┌──────────────┐    ┌──────────────┐     │
  10.10.0.1/24 ────┤   │   ns-east     │    │   ns-west     │   ├──── 10.20.0.1/24
  (protected)      │   │   10.0.0.1    │────│   10.0.0.2    │   │      (protected)
                    │   │   charon      │ ESP│   charon      │   │
                    │   │   (initiator) │◄═══│   (responder) │   │
                    │   └──────────────┘    └──────────────┘     │
                    │         veth-east ◄──► veth-west           │
                    │              10.0.0.0/30                    │
                    └─────────────────────────────────────────────┘
```

### What You'll Learn

| Skill | Description |
|-------|-------------|
| **IKEv2 Configuration** | strongSwan ipsec.conf with PSK authentication |
| **ESP Encryption** | AES-CBC-256 tunnel mode between gateways |
| **XFRM State** | Linux kernel IPsec SA management |
| **Wireshark Decryption** | esp_sa CSV format for ESP packet decoding |
| **Network Namespaces** | Isolated network environments in Docker |

---

## Quick Start

### Prerequisites

- [Colima](https://github.com/abiosoft/colima) running (`colima status` → runtime: docker)
- Docker available (`docker ps`)
- Make (optional)

### One Command

```bash
make run-bg
```

This will:
1. Build the Docker image (Ubuntu 22.04 + strongSwan 5.9.5)
2. Create two network namespaces (ns-east, ns-west)
3. Establish IKEv2 tunnel automatically
4. Generate ESP traffic and capture packets
5. Export Wireshark decryption keys

### Verify

```bash
make status        # Check SA status
make validate      # Full validation (connectivity + tunnel + XFRM)
```

### Decrypt in Wireshark

```bash
wireshark wireshark_keys/capture.pcap
# Edit → Preferences → Protocols → ESP
# Load: wireshark_keys/esp_sa
```

### Stop

```bash
make stop
```

---

## Architecture

### Network Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Network Namespace: ns-east                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ lo: 10.10.0.1/24 (protected subnet)                        │   │
│  │ veth-east: 10.0.0.1/30 (transit link)                      │   │
│  │ charon: IKEv2 initiator, PSK "StrongSwanLab2024!"          │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│                         veth-east                                   │
│                              │                                      │
│                         veth-west                                   │
│                              │                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ lo: 10.20.0.1/24 (protected subnet)                        │   │
│  │ veth-west: 10.0.0.2/30 (transit link)                      │   │
│  │ charon: IKEv2 responder, PSK "StrongSwanLab2024!"          │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                    Network Namespace: ns-west                        │
└─────────────────────────────────────────────────────────────────────┘
```

### IPsec Parameters

| Phase | Parameter | Value | RFC |
|-------|-----------|-------|-----|
| **IKE (Phase 1)** | Cipher | AES_CBC_256 | [RFC 3602](https://tools.ietf.org/html/rfc3602) |
| | Integrity | HMAC_SHA2_256_128 | [RFC 4868](https://tools.ietf.org/html/rfc4868) |
| | PRF | PRF_HMAC_SHA2_256 | [RFC 7296](https://tools.ietf.org/html/rfc7296) |
| | DH Group | MODP_2048 (Group 14) | [RFC 3526](https://tools.ietf.org/html/rfc3526) |
| | Lifetime | 28800s | Default |
| **ESP (Phase 2)** | Protocol | ESP (IP Protocol 50) | [RFC 4303](https://tools.ietf.org/html/rfc4303) |
| | Cipher | AES_CBC_256 | RFC 3602 |
| | Integrity | HMAC_SHA2_256_128 | RFC 4868 |
| | Mode | Tunnel | RFC 4303 |
| **Auth** | Method | PSK | — |
| | Key | `StrongSwanLab2024!` | — |

---

## Evidence

All evidence is captured from **real CLI outputs** during lab execution:

| File | Content |
|------|---------|
| `evidence/cli/01_topology.txt` | `ip netns list` + interface IPs |
| `evidence/cli/05_ipsec_status.txt` | `ipsec statusall` (SA ESTABLISHED) |
| `evidence/cli/06_xfrm_state.txt` | `ip xfrm state` (ESP SAs with keys) |
| `evidence/cli/07_ping_test.txt` | Ping through encrypted tunnel |
| `evidence/cli/09_esp_sa_keys.txt` | XFRM state + Wireshark CSV |
| `evidence/cli/10_capture_analysis.txt` | `tcpdump` packet analysis |
| `evidence/IPsec_Lab_Informe.pdf` | Full 10-section academic report |

### Generate Evidence

```bash
make evidence          # Text evidence files
python3 scripts/generate-pdf-report.py  # PDF report
```

---

## Wireshark Decryption

### esp_sa Format (CSV)

```
"IPv4","src_ip","dst_ip","0xSPI","AES-CBC [RFC3602]","0xenc_key","HMAC-SHA-256-128 [RFC4868]","0xauth_key"
```

### Step-by-Step

1. Open `wireshark_keys/capture.pcap` in Wireshark
2. Go to **Edit → Preferences → Protocols → ESP**
3. Check **"Enable ESP decryption"**
4. Click **"Edit..."** next to esp_sa file
5. Load `wireshark_keys/esp_sa`
6. Apply filter: `icmp` to see decrypted ping traffic

### Verify with tshark

```bash
tshark -r wireshark_keys/capture.pcap -o "esp.enable_encryption_decode: TRUE"
```

---

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make build` | Build Docker image |
| `make run` | Run lab (interactive, waits) |
| `make run-bg` | Run lab in background |
| `make stop` | Stop lab container |
| `make status` | Check IKE/ESP SA status |
| `make validate` | Full validation suite |
| `make capture` | Capture ESP traffic to pcap |
| `make evidence` | Generate text evidence files |
| `make test-unit` | Unit tests (BATS) |
| `make test-e2e` | End-to-end tests (BATS) |
| `make test-security` | Security tests (Trivy, Hadolint) |
| `make test-all` | Run all tests |
| `make lint` | Lint Dockerfile + scripts |
| `make trivy` | Scan image for CVEs |
| `make push` | Push to Docker Hub |
| `make clean` | Remove containers + images |

---

## Docker Hub

```bash
# Pull
docker pull statick/ipsec-lab:latest

# Run
docker run --rm --privileged --network host statick/ipsec-lab:latest
```

> **Note:** Requires `--privileged` for network namespace operations.

---

## Project Structure

```
ipsec-lab/
├── Dockerfile                       # Ubuntu 22.04 + strongSwan 5.9.5
├── Makefile                         # 20+ automation targets
├── README.md                        # This file
├── .github/workflows/ci.yml        # CI/CD pipeline
├── configs/
│   ├── gw-east/
│   │   ├── ipsec.conf               # IKEv2 config (initiator)
│   │   └── ipsec.secrets.stroke     # PSK
│   ├── gw-west/
│   │   ├── ipsec.conf               # IKEv2 config (responder)
│   │   └── ipsec.secrets.stroke
│   ├── strongswan-east.conf         # charon daemon config
│   └── strongswan-west.conf
├── scripts/
│   ├── run-lab.sh                   # Main lab script
│   ├── capture-evidence.sh          # CLI evidence capture
│   ├── evidence.sh                  # Evidence generator
│   ├── generate-pdf-report.py       # PDF report (ReportLab)
│   └── generate-screenshots.sh      # HTML → PNG
├── tests/
│   ├── 01-unit.bats                 # Unit tests
│   ├── 02-e2e.bats                  # End-to-end tests
│   └── 03-security.bats             # Security tests
├── evidence/
│   ├── cli/                         # Real CLI outputs (11 files)
│   ├── screenshots/                 # HTML diagrams + PNG
│   ├── METODOLOGIA.md               # Methodology
│   ├── index.html                   # Evidence viewer
│   └── IPsec_Lab_Informe.pdf        # Academic report
└── wireshark_keys/                  # Output directory
    ├── capture.pcap                 # ESP + ICMP packets
    └── esp_sa                       # Wireshark decryption keys
```

---

## CI/CD Pipeline

```
Lint → Security → Build → Unit Tests → E2E Tests → Docker Scan → Push
 Hadolint    Trivy    Buildx     BATS        BATS     Dockle+Trivy   Hub
 ShellCheck                                          Advisory       (main)
```

| Stage | Tool | Purpose |
|-------|------|---------|
| Lint | Hadolint + ShellCheck | Static analysis |
| Security | Trivy (fs) | Vulnerability scan |
| Build | Docker Buildx | Image build + cache |
| Unit Tests | BATS | 13 integration tests |
| E2E Tests | BATS | 15 end-to-end tests |
| Scan | Dockle + Trivy | Best practices + CVEs |
| Push | Docker Hub | Auto-publish on main |

### Required Secrets

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |

---

## Troubleshooting

### "charon already running"

The script uses PID juggling to run two charon instances:
1. Start ns-west → creates `/var/run/charon.pid`
2. Copy PID to `/tmp/charon-west.pid`
3. Start ns-east → creates new PID file

### Ping works but no ESP traffic

Use protected subnet IPs (not gateway transit IPs):

```bash
docker exec ipsec-lab bash -c 'ip netns exec ns-east ping -c 3 10.20.0.1'
```

### Container won't start

Ensure Colima is running with correct settings:
```bash
colima status    # Should show: runtime: docker, mountType: virtiofs
colima start --cpu 4 --memory 8
```

---

## References

- [strongSwan Documentation](https://docs.strongswan.org/)
- [RFC 7296 — IKEv2](https://tools.ietf.org/html/rfc7296)
- [RFC 4303 — ESP](https://tools.ietf.org/html/rfc4303)
- [RFC 3602 — AES-CBC for IPsec](https://tools.ietf.org/html/rfc3602)
- [RFC 4868 — HMAC-SHA-256 for IPsec](https://tools.ietf.org/html/rfc4868)
- [Wireshark ESP Decryption](https://www.wireshark.org/docs/wsug_html_chunked/ChDecryptionSection.html)
- [Linux XFRM (IPsec Kernel)](https://www.kernel.org/doc/html/latest/networking/ipsec.html)

---

<div align="center">

**Developed as part of the Master in Cybersecurity — UCM (2024-2025)**

[![GitHub](https://img.shields.io/badge/GitHub-statick88-181717?logo=github)](https://github.com/statick88)
[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-statick-2496ED?logo=docker)](https://hub.docker.com/r/statick/ipsec-lab)

</div>
]]>