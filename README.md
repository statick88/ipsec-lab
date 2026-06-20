# IPsec Tunnel Lab — strongSwan/Docker

[![CI/CD](https://github.com/statick/ipsec-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/statick/ipsec-lab/actions/workflows/ci.yml)
[![Docker](https://img.shields.io/badge/docker-statick%2Fipsec--lab-blue)](https://hub.docker.com/r/statick/ipsec-lab)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Laboratorio práctico de configuración de túneles IPsec IKEv2/ESP con strongSwan en Docker usando Network Namespaces.

## Objetivos

Al finalizar este laboratorio, serás capaz de:

- Configurar strongSwan como implementación IPsec en Linux
- Crear dos extremos de comunicación usando Network Namespaces
- Establecer un túnel IPsec IKEv2 con autenticación PSK
- Capturar y analizar tráfico ESP cifrado con Wireshark

## Prerrequisitos

- **Colima** ejecutándose (VZ/VirtioFS en Apple Silicon)
- **Docker** (vía Colima)
- **make** (opcional)

```bash
colima status
# Debe mostrar: runtime: docker, mountType: virtiofs
```

## Inicio Rápido

```bash
# Ejecutar lab completo
make run-bg

# Verificar túnel
make status

# Validar todo
make validate

# Generar evidencias
make evidence

# Detener
make stop
```

## Comandos Make

| Comando | Descripción |
|---------|-------------|
| `make help` | Mostrar ayuda |
| `make build` | Construir imagen Docker |
| `make run` | Ejecutar lab (interactivo) |
| `make run-bg` | Ejecutar lab en background |
| `make stop` | Detener lab |
| `make status` | Ver estado del túnel |
| `make capture` | Capturar tráfico ESP |
| `make validate` | Validar: conectividad + túnel + XFRM |
| `make evidence` | Generar documentos de evidencia |
| `make test` | Ejecutar tests unitarios |
| `make test-e2e` | Ejecutar tests E2E |
| `make test-security` | Ejecutar tests de seguridad |
| `make test-all` | Ejecutar todos los tests |
| `make lint` | Lintear Dockerfile + scripts |
| `make trivy` | Escaneo de vulnerabilidades |
| `make push` | Subir a Docker Hub |
| `make clean` | Limpiar contenedores |

## Arquitectura

```
┌──────────────────────────────────────────────────────────────────┐
│  Docker Container (privileged, --network host)                   │
│  ├── Namespace ns-east (10.0.0.1/30)                            │
│  │   ├── veth-east ←→ veth-west                                 │
│  │   ├── strongSwan charon (initiator, IKEv2)                   │
│  │   └── IP: 10.10.0.1/24 (lo) ← subred protegida             │
│  │                                                                │
│  └── Namespace ns-west (10.0.0.2/30)                            │
│      ├── veth-west ←→ veth-east                                 │
│      ├── strongSwan charon (responder, IKEv2)                   │
│      └── IP: 10.20.0.1/24 (lo) ← subred protegida             │
│                                                                   │
│  wireshark_keys/                                                 │
│  ├── capture.pcap    — paquetes ESP capturados                  │
│  └── esp_sa          — claves ESP para Wireshark                │
└──────────────────────────────────────────────────────────────────┘
```

### Configuración IPsec

| Parámetro | Valor |
|-----------|-------|
| Protocolo | IKEv2 (UDP 500/4500) |
| Cifrado IKE | AES_CBC_256 |
| HMAC IKE | HMAC_SHA2_256_128 |
| DH Group | MODP_2048 (Group 14) |
| Cifrado ESP | AES_CBC_256 |
| HMAC ESP | HMAC_SHA2_256_128 |
| Autenticación | PSK: `StrongSwanLab2024!` |
| Túnel | 10.10.0.0/24 ↔ 10.20.0.0/24 |

## Tests

### Unit/Integration Tests

```bash
make test-unit
```

Verifica:
- Docker image build
- Namespace creation
- veth pair connectivity
- IP configuration

### E2E Tests

```bash
make test-e2e
```

Verifica:
- strongSwan charon startup
- IKEv2 SA establishment
- CHILD SA installation
- ESP traffic flow
- XFRM state
- Wireshark keys generation
- Packet capture

### Security Tests

```bash
make test-security
```

Verifica:
- Docker image vulnerabilities (Trivy)
- Dockerfile best practices
- Shell script security
- Configuration security
- Network isolation

### Run All Tests

```bash
make test-all
```

## Análisis Wireshark

```bash
# Abrir captura
wireshark wireshark_keys/capture.pcap

# Descifrar ESP: Edit → Preferences → Protocols → ESP
# Cargar wireshark_keys/esp_sa
```

### Formato esp_sa

```
"IPv4","src_ip","dst_ip","0xSPI","AES-CBC [RFC3602]","0xenc_key","HMAC-SHA-256-128 [RFC4868]","0xauth_key"
```

## Estructura de Archivos

```
lab/
├── Dockerfile                  # Ubuntu 22.04 + strongSwan 5.9.5
├── Makefile                    # Comandos de automatización
├── README.md                   # Documentación
├── .github/workflows/ci.yml   # CI/CD pipeline
├── configs/
│   ├── gw-east/
│   │   ├── ipsec.conf          # IKEv2 config
│   │   └── ipsec.secrets.stroke # PSK
│   ├── gw-west/
│   │   ├── ipsec.conf
│   │   └── ipsec.secrets.stroke
│   ├── strongswan-east.conf    # charon config
│   └── strongswan-west.conf
├── scripts/
│   ├── run-lab.sh              # Script principal
│   └── evidence.sh             # Generador de evidencias
├── tests/
│   ├── 01-unit.bats            # Tests unitarios
│   ├── 02-e2e.bats             # Tests E2E
│   └── 03-security.bats        # Tests de seguridad
└── wireshark_keys/             # Output: capture.pcap + esp_sa
```

## CI/CD Pipeline

El pipeline incluye:

1. **Lint**: Hadolint (Dockerfile) + ShellCheck (scripts)
2. **Security**: Gitleaks (secret scanning) + Trivy (vulnerabilities)
3. **Build**: Docker image build + cache
4. **Test**: Unit + E2E tests
5. **Scan**: Trivy image scan
6. **Push**: Docker Hub (solo main branch)

### Secrets requeridos

- `DOCKERHUB_USERNAME`: Usuario de Docker Hub
- `DOCKERHUB_TOKEN`: Token de Docker Hub

## Docker Hub

```bash
# Login
docker login

# Pull
docker pull statick/ipsec-lab:latest

# Ejecutar
docker run --rm --privileged --network host statick/ipsec-lab:latest
```

## Solución de Problemas

### "charon already running"

El script hace PID juggling:
1. Inicia ns-west → crea `/var/run/charon.pid`
2. Copia PID a `/tmp/charon-west.pid`
3. Inicia ns-east → crea nuevo PID

### Ping funciona pero sin tráfico ESP

Usar IPs de subred protegida:
```bash
docker exec ipsec-lab bash -c 'ip netns exec ns-east ping -c 3 10.20.0.1'
```

## Referencias

- [strongSwan Documentation](https://docs.strongswan.org)
- [strongSwan Network Namespaces](https://docs.strongswan.org/docs/latest/howtos/nameSpaces.html)
- [Wireshark ESP Decryption](https://www.wireshark.org/docs/wsug_html_chunked/ChDecryptionSection.html)
- [IPsec RFC 4303](https://tools.ietf.org/html/rfc4303)

## Autor

Desarrollado como parte del Máster en Ciberseguridad — UCM (2024-2025)

## Licencia

MIT
