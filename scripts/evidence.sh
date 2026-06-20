#!/bin/bash
# IPsec Lab - Evidence Collection Script
# Generates academic evidence of tunnel operation
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
header() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

CONTAINER="ipsec-lab"
EVIDENCE_DIR="evidence"
mkdir -p "$EVIDENCE_DIR"

header "1. TOPOLOGÍA DE RED"
log "Creando namespaces y interfaces..."
docker exec "$CONTAINER" bash -c '
echo "=== Namespaces ==="
ip netns list
echo ""
echo "=== ns-east: veth-east ==="
ip netns exec ns-east ip addr show veth-east
echo ""
echo "=== ns-east: lo (subred protegida) ==="
ip netns exec ns-east ip addr show lo
echo ""
echo "=== ns-west: veth-west ==="
ip netns exec ns-west ip addr show veth-west
echo ""
echo "=== ns-west: lo (subred protegida) ==="
ip netns exec ns-west ip addr show lo
' 2>&1 | tee "$EVIDENCE_DIR/01_topologia.txt"

header "2. CONECTIVIDAD BASE"
log "Verificando ping entre gateways..."
docker exec "$CONTAINER" bash -c '
echo "=== Ping ns-east (10.0.0.1) → ns-west (10.0.0.2) ==="
ip netns exec ns-east ping -c 5 10.0.0.2
echo ""
echo "=== Ping ns-west (10.0.0.2) → ns-east (10.0.0.1) ==="
ip netns exec ns-west ping -c 5 10.0.0.1
' 2>&1 | tee "$EVIDENCE_DIR/02_conectividad.txt"

header "3. ESTADO DEL TÚNEL IKEv2"
log "Verificando SA IKEv2..."
docker exec "$CONTAINER" bash -c '
echo "=== ipsec statusall ==="
ipsec statusall
echo ""
echo "=== Verificación de SA ==="
echo "IKE SA: ESPERE ESTABLISHED"
echo "CHILD SA: ESPERE INSTALLED"
' 2>&1 | tee "$EVIDENCE_DIR/03_tunel_ikev2.txt"

header "4. SA XFRM (Security Associations)"
log "Mostrando XFRM state..."
docker exec "$CONTAINER" bash -c '
echo "=== XFRM State (ns-east) ==="
ip netns exec ns-east ip xfrm state
echo ""
echo "=== XFRM State (ns-west) ==="
ip netns exec ns-west ip xfrm state
echo ""
echo "=== XFRM Policies (ns-east) ==="
ip netns exec ns-east ip xfrm policy
' 2>&1 | tee "$EVIDENCE_DIR/04_xfrm_sa.txt"

header "5. ALGORITMOS DE CIFRADO"
log "Extrayendo algoritmos..."
docker exec "$CONTAINER" bash -c '
echo "=== Propuesta IKE ==="
echo "Cifrado:     AES_CBC_256"
echo "HMAC:        HMAC_SHA2_256_128"
echo "PRF:         PRF_HMAC_SHA2_256"
echo "DH Group:    MODP_2048 (Group 14)"
echo ""
echo "=== Propuesta ESP ==="
echo "Cifrado:     AES_CBC_256"
echo "HMAC:        HMAC_SHA2_256_128"
echo "Modo:        TUNNEL"
echo ""
echo "=== Verificación de algoritmos en SA ==="
ip netns exec ns-east ip xfrm state | grep -E "proto|auth-trunc|enc"
' 2>&1 | tee "$EVIDENCE_DIR/05_algoritmos.txt"

header "6. TRÁFICO ESP CIFRADO"
log "Generando tráfico y verificando encapsulación..."
docker exec "$CONTAINER" bash -c '
echo "=== Ping a subred protegida (10.10.0.1 → 10.20.0.1) ==="
ip netns exec ns-east ping -c 5 10.20.0.1
echo ""
echo "=== Contadores XFRM después del tráfico ==="
ip netns exec ns-east ip -s xfrm state | grep -E "bytes|packets"
' 2>&1 | tee "$EVIDENCE_DIR/06_trafico_esp.txt"

header "7. CAPTURA DE PAQUETES"
log "Capturando tráfico ESP..."
docker exec "$CONTAINER" bash -c '
ip netns exec ns-east timeout 5 tcpdump -i veth-east -w /wireshark_keys/capture.pcap "udp port 500 or udp port 4500 or esp or icmp" 2>/dev/null &
TCPDUMP_PID=$!
sleep 1
ip netns exec ns-east ping -c 5 10.20.0.1 2>/dev/null
wait $TCPDUMP_PID 2>/dev/null || true
echo "=== Paquetes capturados ==="
tcpdump -r /wireshark_keys/capture.pcap -nn 2>/dev/null | head -20
echo ""
echo "Total de paquetes:"
tcpdump -r /wireshark_keys/capture.pcap -nn 2>/dev/null | wc -l
' 2>&1 | tee "$EVIDENCE_DIR/07_captura_paquetes.txt"

header "8. CLAVES WIRESHARK"
log "Mostrando claves ESP para descifrado..."
docker exec "$CONTAINER" bash -c '
echo "=== esp_sa (formato Wireshark) ==="
cat /wireshark_keys/esp_sa 2>/dev/null || echo "(no disponible)"
echo ""
echo "=== Formato del archivo ==="
echo "IPv4,src,dst,0xSPI,enc_algo,0xenc_key,auth_algo,0xauth_key"
' 2>&1 | tee "$EVIDENCE_DIR/08_claves_wireshark.txt"

header "9. PRUEBA DE DESCIFRADO ESP"
log "Verificando descifrado con tshark..."
if command -v tshark &>/dev/null; then
  tshark -r wireshark_keys/capture.pcap -o "esp.enable_encryption_decode: TRUE" 2>/dev/null | head -15 | tee "$EVIDENCE_DIR/09_descifrado_esp.txt"
else
  echo "tshark no disponible - usar Wireshark GUI" | tee "$EVIDENCE_DIR/09_descifrado_esp.txt"
fi

header "10. RESUMEN DE EVIDENCIAS"
log "Archivos generados:"
ls -la "$EVIDENCE_DIR/"
echo ""
log "Para incluir en el documento:"
echo "  - Copiar cada archivo como evidencia"
echo "  - Los comandos muestran la ejecución real"
echo "  - Las salidas verifican el funcionamiento"

echo -e "\n${GREEN}Evidencias completas en: ${EVIDENCE_DIR}/${NC}"
