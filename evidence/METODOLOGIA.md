# Metodología — Lab IPsec IKEv2/ESP con strongSwan

## 1. Objetivo

Demostrar el funcionamiento de un túnel IPsec IKEv2 con encapsulación ESP entre dos extremos (gateway east y gateway west), utilizando strongSwan sobre contenedores Docker con network namespaces aislados.

## 2. Arquitectura del Laboratorio

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTENEDOR DOCKER (privileged)                │
│                                                                  │
│  ┌──────────────────┐    veth pair    ┌──────────────────┐      │
│  │    ns-east        │◄──────────────►│    ns-west        │      │
│  │                   │  10.0.0.0/30   │                   │      │
│  │  ┌─────────────┐ │                │ ┌─────────────┐  │      │
│  │  │  charon     │ │   IKEv2/ESP    │ │  charon     │  │      │
│  │  │  (starter)  │◄├────────────────┤►│  (starter)  │  │      │
│  │  └─────────────┘ │                │ └─────────────┘  │      │
│  │                   │                │                   │      │
│  │  lo: 10.10.0.1/24│                │  lo: 10.20.0.1/24│      │
│  │  (subnet proteg.) │                │  (subnet proteg.) │      │
│  └──────────────────┘                └──────────────────┘      │
│                                                                  │
│  Configuración:                                                 │
│  - IKE: AES_CBC_256 / HMAC_SHA2_256_128 / PRF_HMAC_SHA2_256   │
│  - ESP: AES_CBC_256 / HMAC_SHA2_256_128                       │
│  - PSK: "StrongSwanLab2024!"                                    │
│  - Modo: tunnel                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 3. Metodología de Implementación

### 3.1 Fase de Diseño

| Elemento | Decisión | Justificación |
|----------|----------|---------------|
| Plataforma | Docker + Colima (VZ/VirtioFS) | Evitar VM pesada; Apple Silicon nativo |
| Aislamiento | Network namespaces | Simular dos gateways separados |
| Software | strongSwan 5.9.5 (apt) | Incluye plugins necesarios sin compilar |
| Configuración | ipsec.conf + ipsec.secrets (stroke) | Más simple que swanctl para lab |
| Autenticación | PSK | Demostración académica simplificada |

### 3.2 Fase de Configuración

1. **Network Namespaces**: Se crean `ns-east` y `ns-west` simulando dos routadores independientes
2. **Veth Pair**: `veth-east` ↔ `veth-west` conecta ambos namespaces (10.0.0.1/30 ↔ 10.0.0.2/30)
3. **Subnet Protegido**: Cada gateway tiene una red local (10.10.0.0/24 y 10.20.0.0/24)
4. **strongSwan**: Dos instancias de charon con PIDs y sockets separados
5. **XFRM Policies**: Tráfico entre subnets protegidos se encapsula en ESP

### 3.3 Fase de Ejecución

```
1. make build          → Construir imagen Docker
2. make run            → Iniciar namespaces + túnel
3. make status         → Verificar SA establecidos
4. make capture        → Capturar tráfico ESP
5. make evidence       → Generar evidencias académicas
```

### 3.4 Fase de Validación

| Verificación | Comando | Resultado Esperado |
|-------------|---------|-------------------|
| Namespaces | `ip netns list` | ns-east, ns-west |
| Conectividad | `ip netns exec ns-east ping 10.0.0.2` | 3/3 packets |
| IKE SA | `ipsec statusall` | ESTABLISHED |
| CHILD SA | `ipsec statusall` | INSTALLED |
| ESP Traffic | `ip xfrm state` | bytes > 0 |
| Wireshark | `tshark -r capture.pcap` | ESP + ICMP decodificado |

## 4. Herramientas Utilizadas

| Herramienta | Versión | Propósito |
|------------|---------|-----------|
| Docker | 29.6.0 | Contenedores |
| Colima | latest | VM backend (VZ) |
| strongSwan | 5.9.5 | IPsec IKEv2 |
| BATS | latest | Testing framework |
| ShellCheck | 0.10.0 | Linting bash |
| Hadolint | latest | Dockerfile linting |
| Trivy | latest | Vulnerability scanning |
| tcpdump | latest | Packet capture |
| tshark | latest | Protocol analysis |

## 5. Criterios de Aceptación

- [x] Túnel IKEv2 establecido entre ns-east y ns-west
- [x] Tráfico ESP visible entre subnets protegidos
- [x] Algoritmos: AES-CBC-256 + HMAC-SHA-256-128
- [x] Captura de paquetes ESP generada
- [x] Claves ESP exportadas para Wireshark
- [x] Evidencia académica completa (9 secciones)
- [x] Tests automatizados (unit + E2E + security)
- [x] CI/CD pipeline funcional
- [x] Imagen en Docker Hub

## 6. Referencias

1. RFC 7296 — Internet Key Exchange Version 2 (IKEv2)
- RFC 4303 — IP Encapsulating Security Payload (ESP)
- RFC 3602 — The AES-CBC Cipher Algorithm and Its Use with IPsec
- RFC 4868 — Using HMAC-SHA-256, HMAC-SHA-384, and HMAC-SHA-512 with IPsec
- strongSwan Documentation — https://docs.strongswan.org/
- Docker Network Namespaces — https://docs.docker.com/engine/network/
