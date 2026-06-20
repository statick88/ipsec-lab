<div align="center">

# IPsec Tunnel Lab

### IKEv2/ESP with strongSwan — Docker + Network Namespaces

[![CI/CD](https://github.com/statick88/ipsec-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/statick88/ipsec-lab/actions/workflows/ci.yml)
[![Docker](https://img.shields.io/docker/image-size/statick/ipsec-lab?sort=semver&label=image%20size)](https://hub.docker.com/r/statick/ipsec-lab)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![strongSwan](https://img.shields.io/badge/strongSwan-5.9.5-green.svg)](https://docs.strongswan.org)

**Un contenedor Docker. Dos namespaces. Un túnel IPsec real. Cero atajos.**

[Quick Start](#-quick-start) · [Architecture](#-architecture) · [Metrics](#-metrics) · [Wireshark](#-wireshark) · [Docker Hub](https://hub.docker.com/r/statick/ipsec-lab)

</div>

---

## What Is This?

Un laboratorio completo de IPsec IKEv2/ESP que ejecuta **dos gateways VPN** dentro de un único contenedor Docker, usando Linux network namespaces para simular entidades de red aisladas.

No es un tutorial. No es un ejemplo simplificado. Es un **entorno funcional** que genera evidencia real: paquetes ESP capturados, claves de descifrado para Wireshark, y un informe PDF con salidas de CLI auténticas.

```
┌─────────────────────────────────────────────────────────────┐
│                  Docker (privileged)                         │
│                                                              │
│   ┌──────────────┐         ┌──────────────┐                │
│   │   ns-east     │◄══ ESP ══►│   ns-west     │                │
│   │  10.0.0.1     │  tunnel  │  10.0.0.2     │                │
│   │  charon (I)   │         │  charon (R)   │                │
│   │  10.10.0.1/24 │         │  10.20.0.1/24 │                │
│   └──────────────┘         └──────────────┘                │
│        lo (protected)          lo (protected)                │
└─────────────────────────────────────────────────────────────┘
```

---

## Quick Start

**Prerrequisitos:** Colima corriendo (`colima status` → runtime: docker)

```bash
# Arrancar el lab completo
make run-bg

# Verificar que el túnel está establecido
make status

# Validar conectividad + túnel + XFRM
make validate

# Generar evidencia
make evidence

# Parar
make stop
```

Un solo comando. Sin configuración manual. Sin scripts externos.

---

## Architecture

### Topología de Red

```
                    ┌─────────────────────────────────────┐
                    │         Container Docker             │
                    │                                      │
  10.10.0.1/24 ────┤   ns-east          ns-west   ├──── 10.20.0.1/24
  (subred           │   ╔═══════════╗   ╔═══════════╗   │  (subred
   protegida)       │   ║ 10.0.0.1  ║───║ 10.0.0.2  ║   │   protegida)
                    │   ║ veth-east ║   ║ veth-west ║   │
                    │   ║ charon(I) ║   ║ charon(R) ║   │
                    │   ╚═══════════╝   ╚═══════════╝   │
                    │          10.0.0.0/30 (tránsito)     │
                    └─────────────────────────────────────┘
```

### Stack Tecnológico

| Componente | Versión | Fuente |
|------------|---------|--------|
| OS Base | Ubuntu 22.04 LTS | Docker Hub |
| strongSwan | 5.9.5 | apt (official) |
| Docker | Colima VZ/VirtioFS | Apple Silicon |
| CI/CD | GitHub Actions | 6 stages |
| Tests | BATS | 42 tests |
| Linting | ShellCheck + Hadolint | Static analysis |
| Security | Trivy + Dockle | CVE + best practices |

### Configuración IPsec

| Fase | Parámetro | Valor | RFC |
|------|-----------|-------|-----|
| **IKE** | Cipher | AES_CBC_256 | [RFC 3602](https://tools.ietf.org/html/rfc3602) |
| | Integrity | HMAC_SHA2_256_128 | [RFC 4868](https://tools.ietf.org/html/rfc4868) |
| | PRF | PRF_HMAC_SHA2_256 | [RFC 7296](https://tools.ietf.org/html/rfc7296) |
| | DH Group | MODP_2048 (Group 14) | [RFC 3526](https://tools.ietf.org/html/rfc3526) |
| **ESP** | Protocol | ESP (IP Protocol 50) | [RFC 4303](https://tools.ietf.org/html/rfc4303) |
| | Cipher | AES_CBC_256 | RFC 3602 |
| | Integrity | HMAC_SHA2_256_128 | RFC 4868 |
| | Mode | Tunnel | RFC 4303 |
| **Auth** | Method | PSK | — |

---

## Metrics

Datos reales capturados durante la ejecución del laboratorio:

### Recursos del Sistema

| Métrica | Valor |
|---------|-------|
| **Imagen Docker** | 132 MB |
| **Memoria** | 8.1 MiB / 7.7 GiB (0.10%) |
| **CPU** | 0.82% |
| **Block I/O** | 410 kB read / 32.8 kB write |
| **Procesos charon** | 2 (east: PID 43, west: PID 70) |

### Estado del Túnel

| Métrica | Valor |
|---------|-------|
| **IKE SA** | ESTABLISHED |
| **CHILD SA (ESP)** | INSTALLED, TUNNEL |
| **SPI east→west** | `0xcfbe7479` |
| **SPI west→east** | `0xcf5294b7` |
| **Uptime** | 42 segundos (al momento de captura) |
| **XFRM SAs** | 4 (2 por namespace) |
| **XFRM Policies** | 3 por namespace (out, fwd, in) |

### Tráfico Cifrado

| Métrica | Valor |
|---------|-------|
| **Paquetes capturados** | 27 |
| **ESP packets** | 16 (8 por dirección) |
| **ICMP decodificado** | 11 (ping replies) |
| **RTT ping cifrado** | 0.082 / 0.168 / 0.224 ms (min/avg/max) |
| **Throughput** | ~3 packets/second (ping interval) |

### Claves ESP (Generadas en Runtime)

| Dirección | SPI | Cipher Key (256-bit) | Auth Key (256-bit) |
|-----------|-----|---------------------|-------------------|
| east → west | `0xcfbe7479` | `0x23fad991...114c5a5f` | `0x117cc654...621ea7` |
| west → east | `0xcf5294b7` | `0x22fdf231...f3638ae5` | `0x86c92d20...1104d96` |

> Las claves se generan dinámicamente en cada ejecución. No hay claves hardcodeadas.

---

## Wireshark

### Descifrado de Paquetes ESP

```bash
# Abrir captura
wireshark wireshark_keys/capture.pcap

# Cargar claves ESP
# Edit → Preferences → Protocols → ESP
# ✓ Enable ESP decryption
# File: wireshark_keys/esp_sa
```

### Formato esp_sa (CSV)

```
"IPv4","10.0.0.1","10.0.0.2","0xcfbe7479","AES-CBC [RFC3602]","0x23fad9...","HMAC-SHA-256-128 [RFC4868]","0x117cc6..."
```

### Verificación con tshark

```bash
tshark -r wireshark_keys/capture.pcap -o "esp.enable_encryption_decode: TRUE"
```

Resultado: paquetes ESP se decodifican mostrando ICMP echo request/reply dentro del túnel.

---

## Evidencia

### Archivos Generados

| Archivo | Contenido |
|---------|-----------|
| `evidence/cli/01_topology.txt` | `ip netns list` + interfaces |
| `evidence/cli/05_ipsec_status.txt` | `ipsec statusall` (SA ESTABLISHED) |
| `evidence/cli/06_xfrm_state.txt` | `ip xfrm state` (SAs con claves) |
| `evidence/cli/07_ping_test.txt` | Ping cifrado: 10.10.0.1 → 10.20.0.1 |
| `evidence/cli/09_esp_sa_keys.txt` | XFRM + CSV Wireshark |
| `evidence/cli/10_capture_analysis.txt` | `tcpdump` análisis de paquetes |
| `evidence/IPsec_Lab_Informe.pdf` | Informe académico (10 secciones) |

### Generar Evidencia

```bash
make evidence                                    # Archivos de texto
python3 scripts/generate-pdf-report.py           # PDF con outputs reales
```

---

## Zero Trust Architecture

Este lab implementa los principios de **Zero Trust** (NIST SP 800-207) en un entorno IPsec:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ZERO TRUST PRINCIPLES                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. VERIFY EXPLICITLY     2. LEAST PRIVILEGE                        │
│     ├─ X.509 CA            ├─ Namespaces aislados                   │
│     ├─ Certificados        ├─ Subredes protegidas por SA            │
│     └─ PSK + Cert hybrid   └─ Acceso mínimo necesario               │
│                                                                     │
│  3. ASSUME BREACH         4. CONTINUOUS VERIFICATION                │
│     ├─ Charon audit log    ├─ DPD cada 10s                         │
│     ├─ XFRM state monitor  ├─ Rekeying cada 1h                     │
│     └─ Wireshark decrypt   └─ Monitoreo continuo                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Identity Verification (X.509)

```bash
# Generar certificados (se ejecuta automáticamente con make run)
pki --gen --type rsa --size 2048 > ca.key
pki --self --ca --in ca.key --dn "CN=ZeroTrust Lab CA" > ca.crt
pki --issue --ca ca.crt --ca-key ca.key --dn "CN=gw-east" --san="10.0.0.1" > gw-east.crt
pki --issue --ca ca.crt --ca-key ca.key --dn "CN=gw-west" --san="10.0.0.2" > gw-west.crt
```

### Continuous Verification (DPD)

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `dpddelay` | 10s | Verificar peer cada 10 segundos |
| `dpdtimeout` | 30s | Timeout rápido — fallar rápido |
| `dpdaction` | restart | Re-verificar si peer no responde |
| `lifetime` | 3600s | Rekeying cada 1h (perfect forward secrecy) |

### Audit Trail (Charon Logging)

```bash
# Logs configurados en strongswan.conf
charondebug="ike 2, knl 2, cfg 2, net 2"
filelog {
    /tmp/charon-east.log { ... }
    /tmp/charon-west.log { ... }
}
```

### Zero Trust Audit

```bash
# Ejecutar auditoría completa
make zero-trust-audit

# O directamente
bash scripts/zero-trust-audit.sh
```

Audit verifica:
- **Identity**: CA + certificados X.509 válidos
- **Micro-segmentation**: Namespaces aislados
- **Continuous verification**: DPD configurado agresivamente
- **Tunnel status**: IKEv2 + ESP establecidos
- **Audit logging**: Charon logs activos
- **XFRM**: Security Associations bidireccionales

---

## Makefile

| Comando | Qué hace |
|---------|----------|
| `make build` | Construye la imagen Docker |
| `make run` | Ejecuta el lab (interactivo) |
| `make run-bg` | Ejecuta en background |
| `make stop` | Detiene el contenedor |
| `make status` | Muestra estado de SA |
| `make validate` | Validación completa |
| `make capture` | Captura tráfico ESP a pcap |
| `make evidence` | Genera evidencia textual |
| `make test-unit` | Tests unitarios (BATS) |
| `make test-e2e` | Tests end-to-end (BATS) |
| `make test-security` | Tests de seguridad |
| `make test-all` | Todos los tests |
| `make lint` | ShellCheck + Hadolint |
| `make trivy` | Escaneo CVEs |
| `make push` | Push a Docker Hub |
| `make clean` | Limpia contenedores |

---

## Docker Hub

```bash
docker pull statick/ipsec-lab:latest

docker run --rm --privileged --network host statick/ipsec-lab:latest
```

Requiere `--privileged` para operaciones de network namespace.

---

## CI/CD

```
Lint ──► Security ──► Build ──► Unit Tests ──► E2E Tests ──► Scan ──► Push
 │          │          │           │              │           │        │
 │          │          │           │              │           │        └─ Docker Hub
 │          │          │           │              │           └─ Dockle + Trivy
 │          │          │           │              └─ BATS (14 tests)
 │          │          │           └─ BATS (13 tests)
 │          │          └─ Docker Buildx + cache
 │          └─ Trivy filesystem
 └─ Hadolint + ShellCheck
```

**6/7 jobs passing** (Push requiere Docker Hub secrets configurados).

### Secrets

| Secret | Descripción |
|--------|-------------|
| `DOCKERHUB_USERNAME` | Usuario Docker Hub |
| `DOCKERHUB_TOKEN` | Token de acceso |

---

## Estructura

```
ipsec-lab/
├── Dockerfile                    # Ubuntu 22.04 + strongSwan 5.9.5
├── Makefile                      # 20+ targets
├── .github/workflows/ci.yml     # CI/CD pipeline
├── configs/
│   ├── gw-east/                  # Config initiator
│   │   ├── ipsec.conf
│   │   └── ipsec.secrets.stroke
│   ├── gw-west/                  # Config responder
│   │   ├── ipsec.conf
│   │   └── ipsec.secrets.stroke
│   ├── strongswan-east.conf
│   └── strongswan-west.conf
├── scripts/
│   ├── run-lab.sh                # Script principal
│   ├── capture-evidence.sh       # Captura de evidencia CLI
│   ├── generate-pdf-report.py    # Generador PDF
│   └── generate-screenshots.sh   # HTML → PNG
├── tests/
│   ├── 01-unit.bats
│   ├── 02-e2e.bats
│   └── 03-security.bats
├── evidence/
│   ├── cli/                      # 11 archivos de evidencia real
│   ├── screenshots/              # Diagramas HTML + PNG
│   ├── IPsec_Lab_Informe.pdf     # Informe académico
│   └── METODOLOGIA.md
└── wireshark_keys/
    ├── capture.pcap              # 27 paquetes ESP + ICMP
    └── esp_sa                    # Claves descifrado Wireshark
```

---

## Troubleshooting

### "charon already running"

El script hace **PID juggling**: inicia ns-west, copia el PID a `/tmp`, borra el original, luego inicia ns-east. Cada charon tiene su propio archivo PID.

### Ping funciona pero no veo ESP

Usar IPs de **subred protegida**, no de tránsito:
```bash
docker exec ipsec-lab bash -c 'ip netns exec ns-east ping -c 3 10.20.0.1'
```

### Contenedor no arranca

```bash
colima status    # Verificar: runtime: docker, mountType: virtiofs
colima start --cpu 4 --memory 8
```

---

## Referencias

- [strongSwan Documentation](https://docs.strongswan.org/)
- [RFC 7296 — IKEv2](https://tools.ietf.org/html/rfc7296)
- [RFC 4303 — ESP](https://tools.ietf.org/html/rfc4303)
- [RFC 3602 — AES-CBC for IPsec](https://tools.ietf.org/html/rfc3602)
- [RFC 4868 — HMAC-SHA-256 for IPsec](https://tools.ietf.org/html/rfc4868)
- [Wireshark ESP Decryption](https://www.wireshark.org/docs/wsug_html_chunked/ChDecryptionSection.html)
- [Linux XFRM](https://www.kernel.org/doc/html/latest/networking/ipsec.html)

---

<div align="center">

**Desarrollado por Diego Saavedra — Máster en Ciberseguridad UCM (2024-2025)**

[![GitHub](https://img.shields.io/badge/GitHub-statick88-181717?logo=github)](https://github.com/statick88)
[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-statick-2496ED?logo=docker)](https://hub.docker.com/r/statick/ipsec-lab)

*"El código no miente. Los logs no mienten. La evidencia CLI no miente."*

</div>
