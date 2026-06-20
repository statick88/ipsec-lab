#!/bin/bash
# Complete IPsec lab: namespaces, veth pair, and two strongSwan instances
# Uses ipsec start --nofork with PID file juggling to avoid collisions
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARN:${NC} $*"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $*"; }

[[ $EUID -ne 0 ]] && { error "Must run as root"; exit 1; }

WIRESHARK_DIR="${WIRESHARK_DIR:-/wireshark_keys}"

# Ensure wireshark directory exists
mkdir -p "$WIRESHARK_DIR" 2>/dev/null || true

# === CLEANUP TRAP ===
cleanup() {
    log "Cleaning up..."
    pkill -9 charon 2>/dev/null || true
    pkill -9 starter 2>/dev/null || true
    ip netns del ns-east 2>/dev/null || true
    ip netns del ns-west 2>/dev/null || true
    ip link del veth-east 2>/dev/null || true
    rm -f /var/run/ipsec-ns-east/charon.pid /var/run/ipsec-ns-east/starter.charon.pid 2>/dev/null || true
    rm -f /var/run/ipsec-ns-west/charon.pid /var/run/ipsec-ns-west/starter.charon.pid 2>/dev/null || true
    rm -f /tmp/charon-east.pid /tmp/charon-west.pid 2>/dev/null || true
    rm -f /tmp/starter-charon-east.pid /tmp/starter-charon-west.pid 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# === CLEANUP PREVIOUS ===
log "Cleaning up previous setup..."
pkill -9 charon 2>/dev/null || true
pkill -9 starter 2>/dev/null || true
ip netns del ns-east 2>/dev/null || true
ip netns del ns-west 2>/dev/null || true
ip link del veth-east 2>/dev/null || true
rm -f /var/run/ipsec-ns-east/charon.pid /var/run/ipsec-ns-east/starter.charon.pid 2>/dev/null || true
rm -f /var/run/ipsec-ns-west/charon.pid /var/run/ipsec-ns-west/starter.charon.pid 2>/dev/null || true

# === CREATE NAMESPACES ===
log "Creating network namespaces..."
ip netns add ns-east
ip netns add ns-west

log "Creating veth pair..."
ip link add veth-east type veth peer name veth-west
ip link set veth-east netns ns-east
ip link set veth-west netns ns-west

log "Configuring interfaces..."
ip netns exec ns-east ip link set lo up
ip netns exec ns-east ip link set veth-east up
ip netns exec ns-east ip addr add 10.0.0.1/30 dev veth-east

ip netns exec ns-west ip link set lo up
ip netns exec ns-west ip link set veth-west up
ip netns exec ns-west ip addr add 10.0.0.2/30 dev veth-west

log "Enabling IP forwarding..."
ip netns exec ns-east sysctl -w net.ipv4.ip_forward=1 2>/dev/null
ip netns exec ns-west sysctl -w net.ipv4.ip_forward=1 2>/dev/null

log "Adding routes for internal subnets..."
ip netns exec ns-east ip route add 10.20.0.0/24 via 10.0.0.2 dev veth-east 2>/dev/null || true
ip netns exec ns-west ip route add 10.10.0.0/24 via 10.0.0.1 dev veth-west 2>/dev/null || true

# Add protected subnet IPs for ESP traffic
ip netns exec ns-east ip addr add 10.10.0.1/24 dev lo 2>/dev/null || true
ip netns exec ns-west ip addr add 10.20.0.1/24 dev lo 2>/dev/null || true

# === ZERO TRUST: GENERATE X.509 CERTIFICATES ===
log "Generating X.509 CA and gateway certificates (Zero Trust)..."

CERT_DIR="/tmp/zero-trust-certs"
mkdir -p "$CERT_DIR"

# Generate CA key and certificate
pki --gen --type rsa --size 2048 --outform pem > "$CERT_DIR/ca.key" 2>/dev/null
pki --self --ca --lifetime 3650 --in "$CERT_DIR/ca.key" \
    --dn "CN=ZeroTrust Lab CA,O=IPsec Lab,C=ES" \
    --outform pem > "$CERT_DIR/ca.crt" 2>/dev/null

# Generate gw-east key and certificate
pki --gen --type rsa --size 2048 --outform pem > "$CERT_DIR/gw-east.key" 2>/dev/null
pki --issue --lifetime 3650 --ca "$CERT_DIR/ca.crt" --ca-key "$CERT_DIR/ca.key" \
    --in "$CERT_DIR/gw-east.key" \
    --dn "CN=gw-east,O=IPsec Lab,C=ES" \
    --san="10.0.0.1" --san="dns:gw-east" \
    --flag ikeIntermediate --outform pem > "$CERT_DIR/gw-east.crt" 2>/dev/null

# Generate gw-west key and certificate
pki --gen --type rsa --size 2048 --outform pem > "$CERT_DIR/gw-west.key" 2>/dev/null
pki --issue --lifetime 3650 --ca "$CERT_DIR/ca.crt" --ca-key "$CERT_DIR/ca.key" \
    --in "$CERT_DIR/gw-west.key" \
    --dn "CN=gw-west,O=IPsec Lab,C=ES" \
    --san="10.0.0.2" --san="dns:gw-west" \
    --flag ikeIntermediate --outform pem > "$CERT_DIR/gw-west.crt" 2>/dev/null

# Convert to DER for strongSwan
pki --pub --in "$CERT_DIR/gw-east.key" | \
    pki --issue --lifetime 3650 --ca "$CERT_DIR/ca.crt" --ca-key "$CERT_DIR/ca.key" \
    --dn "CN=gw-east,O=IPsec Lab,C=ES" \
    --san="10.0.0.1" --san="dns:gw-east" \
    --flag ikeIntermediate --outform pem > "$CERT_DIR/gw-east.crt" 2>/dev/null

pki --pub --in "$CERT_DIR/gw-west.key" | \
    pki --issue --lifetime 3650 --ca "$CERT_DIR/ca.crt" --ca-key "$CERT_DIR/ca.key" \
    --dn "CN=gw-west,O=IPsec Lab,C=ES" \
    --san="10.0.0.2" --san="dns:gw-west" \
    --flag ikeIntermediate --outform pem > "$CERT_DIR/gw-west.crt" 2>/dev/null

# Copy certs to Wireshark keys for evidence
cp "$CERT_DIR/ca.crt" "$CERT_DIR"/*.crt "$CERT_DIR"/*.key "$WIRESHARK_DIR/" 2>/dev/null || true

log "Zero Trust certificates generated:"
log "  CA:     $CERT_DIR/ca.crt"
log "  East:   $CERT_DIR/gw-east.crt"
log "  West:   $CERT_DIR/gw-west.crt"

# === TEST CONNECTIVITY ===
log "Testing connectivity..."
if ip netns exec ns-east ping -c 2 10.0.0.2 >/dev/null 2>&1; then
    log "Connectivity PASSED: ns-east -> ns-west"
else
    error "Connectivity FAILED"; exit 1
fi

# === START STRONGSWAN IN NS-WEST (responder) ===
log "Starting strongSwan in ns-west (responder)..."
mkdir -p /var/run/ipsec-ns-west 2>/dev/null || true
cp /etc/ipsec.d/gw-west/ipsec.conf /etc/ipsec.conf
cp /etc/ipsec.d/gw-west/ipsec.secrets.stroke /etc/ipsec.secrets
cp /etc/ipsec.d/strongswan-west.conf /etc/strongswan.conf
ip netns exec ns-west /usr/sbin/ipsec start --nofork &
WEST_PID=$!
sleep 3

cp /var/run/ipsec-ns-west/charon.pid /tmp/charon-west.pid 2>/dev/null || true
cp /var/run/ipsec-ns-west/starter.charon.pid /tmp/starter-charon-west.pid 2>/dev/null || true
rm -f /var/run/ipsec-ns-west/charon.pid /var/run/ipsec-ns-west/starter.charon.pid

# === START STRONGSWAN IN NS-EAST (initiator) ===
log "Starting strongSwan in ns-east (initiator)..."
mkdir -p /var/run/ipsec-ns-east 2>/dev/null || true
cp /etc/ipsec.d/gw-east/ipsec.conf /etc/ipsec.conf
cp /etc/ipsec.d/gw-east/ipsec.secrets.stroke /etc/ipsec.secrets
cp /etc/ipsec.d/strongswan-east.conf /etc/strongswan.conf
ip netns exec ns-east /usr/sbin/ipsec start --nofork &
EAST_PID=$!
sleep 5

# === CHECK STATUS ===
log "Checking IPsec status..."
echo ""

echo "=== ns-east status ==="
ip netns exec ns-east /usr/sbin/ipsec statusall 2>&1 || true

echo ""
echo "=== ns-west charon PID ==="
WEST_CHARON_PID=$(cat /tmp/charon-west.pid 2>/dev/null || echo "")
if [ -n "$WEST_CHARON_PID" ] && kill -0 "$WEST_CHARON_PID" 2>/dev/null; then
    echo "ns-west charon is running (PID $WEST_CHARON_PID)"
else
    echo "ns-west charon: PID check failed"
fi

# === GENERATE TRAFFIC TO TRIGGER TUNNEL ===
log "Generating traffic to trigger IKEv2 tunnel..."
ip netns exec ns-east ping -c 5 10.0.0.2 || true
sleep 3

echo ""
echo "=== ns-east status after traffic ==="
ip netns exec ns-east /usr/sbin/ipsec statusall 2>&1 || true

# === CAPTURE TRAFFIC ===
log "Starting packet capture (ESP on veth-east)..."
ip netns exec ns-east timeout 10 tcpdump -i veth-east -c 30 -w "${WIRESHARK_DIR}/capture.pcap" 'udp port 500 or udp port 4500 or esp or icmp' &
TCPDUMP_PID=$!
sleep 1

# Generate ESP traffic through protected subnets
log "Generating ESP traffic (10.10.0.1 -> 10.20.0.1)..."
ip netns exec ns-east ping -c 10 10.20.0.1 >/dev/null 2>&1 || true
sleep 2
kill $TCPDUMP_PID 2>/dev/null || true
wait $TCPDUMP_PID 2>/dev/null || true
log "Capture saved to ${WIRESHARK_DIR}/capture.pcap"

# === GENERATE WIRESHARK ESP SA KEYS ===
log "Generating Wireshark ESP SA keys..."

# Parse XFRM state and generate esp_sa file
generate_esp_sa() {
    local ns=$1
    local outfile=$2
    : > "$outfile"

    ip netns exec "$ns" ip xfrm state | awk '
    /^src .* dst / { src=$2; dst=$4 }
    /proto esp spi/ {
        gsub(/0x/, "", $4)
        spi=$4
    }
    /auth-trunc/ {
        algo=$2
        gsub(/\(/, "_", algo)
        gsub(/\)/, "", algo)
        # Map to Wireshark algorithm names
        if (algo == "hmac_sha256") algo = "HMAC-SHA-256-128 [RFC4868]"
        else if (algo == "hmac_sha256_128") algo = "HMAC-SHA-256-128 [RFC4868]"
        else if (algo == "hmac_sha1") algo = "HMAC-SHA-1-96 [RFC2404]"
        else if (algo == "hmac_md5") algo = "HMAC-MD5-96 [RFC2403]"
        key=$3
        gsub(/0x/, "", key)
        auth_algo=algo
        auth_key=key
    }
    /enc cbc/ {
        # cbc(aes) -> AES-CBC [RFC3602]
        n=split($2, a, "(")
        gsub(/\)/, "", a[n])
        enc_name = toupper(a[n]) "-CBC [RFC3602]"
        key=$3
        gsub(/0x/, "", key)
        enc_key=key
        # Wireshark CSV format: "IPv4","src","dst","0xSPI","enc_algo","0xenc_key","auth_algo","0xauth_key"
        printf "\"IPv4\",\"%s\",\"%s\",\"0x%s\",\"%s\",\"0x%s\",\"%s\",\"0x%s\"\n", src, dst, spi, enc_name, key, auth_algo, auth_key
    }' >> "$outfile"
}

generate_esp_sa ns-east "${WIRESHARK_DIR}/esp_sa"
generate_esp_sa ns-west "${WIRESHARK_DIR}/esp_sa-west"

# Merge both directions into one file (Wireshark needs both directions)
cat "${WIRESHARK_DIR}/esp_sa" "${WIRESHARK_DIR}/esp_sa-west" > "${WIRESHARK_DIR}/esp_sa.combined"
mv "${WIRESHARK_DIR}/esp_sa.combined" "${WIRESHARK_DIR}/esp_sa"

log "ESP SA keys saved to ${WIRESHARK_DIR}/esp_sa"

# Copy to Wireshark config directory for tshark decryption
WIRESHARK_CONFIG="${HOME}/.config/wireshark"
mkdir -p "$WIRESHARK_CONFIG" 2>/dev/null || true
cp "${WIRESHARK_DIR}/esp_sa" "${WIRESHARK_CONFIG}/esp_sa" 2>/dev/null && \
    log "Copied esp_sa to ${WIRESHARK_CONFIG}/esp_sa" || true

# === XFRM STATE ===
echo ""
echo "=== XFRM state ==="
echo "--- ns-east ---"
ip netns exec ns-east ip xfrm state 2>&1 || true
echo "--- ns-west ---"
ip netns exec ns-west ip xfrm state 2>&1 || true

# === ESP SA CONTENT ===
echo ""
echo "=== Wireshark ESP SA file ==="
cat "${WIRESHARK_DIR}/esp_sa" 2>/dev/null || echo "(empty)"

# === SUMMARY ===
echo ""
log "========================================="
log "  IPsec Lab is RUNNING"
log "========================================="
log ""
log "  Tunnel:  10.10.0.0/24 <-> 10.20.0.0/24"
log "  Gateway: 10.0.0.1 (east) <-> 10.0.0.2 (west)"
log "  Protected: 10.10.0.1 (east lo) <-> 10.20.0.1 (west lo)"
log "  IKE:     AES_CBC_256 / HMAC_SHA2_256_128 / MODP_2048"
log "  ESP:     AES_CBC_256 / HMAC_SHA2_256_128"
log ""
log "  Files:"
log "    ${WIRESHARK_DIR}/capture.pcap     — packet capture"
log "    ${WIRESHARK_DIR}/esp_sa           — ESP SA keys"
log ""
log "  Commands:"
log "    make status    — check tunnel"
log "    make capture   — capture traffic"
log "    make stop      — stop lab"
log ""

# Wait for both processes
wait $WEST_PID $EAST_PID 2>/dev/null || true
