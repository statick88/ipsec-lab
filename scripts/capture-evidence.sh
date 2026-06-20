#!/bin/bash
# Captures real CLI evidence from the running IPsec lab
# Runs inside the container, saves outputs to evidence/cli/
set -euo pipefail

EVIDENCE_DIR="${1:-/evidence/cli}"
mkdir -p "$EVIDENCE_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "Capturing real CLI evidence..."

# 1. Topology - network namespaces
log "1/10 Topology..."
{
    echo "$ ip netns list"
    ip netns list 2>&1
    echo ""
    echo "$ ip netns exec ns-east ip addr show veth-east"
    ip netns exec ns-east ip addr show veth-east 2>&1
    echo ""
    echo "$ ip netns exec ns-west ip addr show veth-west"
    ip netns exec ns-west ip addr show veth-west 2>&1
    echo ""
    echo "$ ip netns exec ns-east ip addr show lo"
    ip netns exec ns-east ip addr show lo 2>&1
    echo ""
    echo "$ ip netns exec ns-west ip addr show lo"
    ip netns exec ns-west ip addr show lo 2>&1
} > "$EVIDENCE_DIR/01_topology.txt" 2>&1

# 2. Routes
log "2/10 Routes..."
{
    echo "$ ip netns exec ns-east ip route"
    ip netns exec ns-east ip route 2>&1
    echo ""
    echo "$ ip netns exec ns-west ip route"
    ip netns exec ns-west ip route 2>&1
} > "$EVIDENCE_DIR/02_routes.txt" 2>&1

# 3. Pre-shared key
log "3/10 PSK..."
{
    echo "$ cat /etc/ipsec.secrets"
    cat /etc/ipsec.secrets 2>&1
} > "$EVIDENCE_DIR/03_psk.txt" 2>&1

# 4. IKEv2 config (east)
log "4/10 IKEv2 config..."
{
    echo "$ cat /etc/ipsec.conf"
    cat /etc/ipsec.conf 2>&1
} > "$EVIDENCE_DIR/04_ipsec_conf.txt" 2>&1

# 5. IPsec status (run in ns-east where charon is initiator)
log "5/10 IPsec status..."
{
    echo "$ ip netns exec ns-east ipsec statusall"
    ip netns exec ns-east ipsec statusall 2>&1
    echo ""
    echo "$ ip netns exec ns-east ipsec status"
    ip netns exec ns-east ipsec status 2>&1
} > "$EVIDENCE_DIR/05_ipsec_status.txt" 2>&1

# 6. XFRM state (must run inside namespace)
log "6/10 XFRM state..."
{
    echo "$ ip netns exec ns-east ip xfrm state"
    ip netns exec ns-east ip xfrm state 2>&1
    echo ""
    echo "$ ip netns exec ns-east ip xfrm policy"
    ip netns exec ns-east ip xfrm policy 2>&1
    echo ""
    echo "$ ip netns exec ns-west ip xfrm state"
    ip netns exec ns-west ip xfrm state 2>&1
} > "$EVIDENCE_DIR/06_xfrm_state.txt" 2>&1

# 7. Ping through tunnel
log "7/10 Ping test..."
{
    echo "$ ip netns exec ns-east ping -c 5 10.20.0.1"
    ip netns exec ns-east ping -c 5 10.20.0.1 2>&1
} > "$EVIDENCE_DIR/07_ping_test.txt" 2>&1

# 8. IPsec status after traffic
log "8/10 Status after traffic..."
{
    echo "$ ip netns exec ns-east ipsec statusall"
    ip netns exec ns-east ipsec statusall 2>&1
} > "$EVIDENCE_DIR/08_status_after_traffic.txt" 2>&1

# 9. ESP SA keys (Wireshark format)
log "9/10 ESP SA keys..."
{
    echo "$ ip netns exec ns-east ip xfrm state"
    ip netns exec ns-east ip xfrm state 2>&1
    echo ""
    echo "=== esp_sa file (Wireshark CSV format) ==="
    cat /wireshark_keys/esp_sa 2>&1
} > "$EVIDENCE_DIR/09_esp_sa_keys.txt" 2>&1

# 10. Capture analysis
log "10/10 Capture analysis..."
{
    echo "$ tcpdump -r /wireshark_keys/capture.pcap -nn"
    tcpdump -r /wireshark_keys/capture.pcap -nn 2>&1
    echo ""
    echo "=== Packet count ==="
    echo "Total packets: $(tcpdump -r /wireshark_keys/capture.pcap -nn 2>&1 | wc -l)"
    echo "ESP packets: $(tcpdump -r /wireshark_keys/capture.pcap -nn 2>&1 | grep -c 'ESP')"
    echo "ICMP packets: $(tcpdump -r /wireshark_keys/capture.pcap -nn 2>&1 | grep -c 'ICMP')"
} > "$EVIDENCE_DIR/10_capture_analysis.txt" 2>&1

# 11. charon logs (if available)
log "11/11 charon startup logs..."
{
    echo "=== ns-west charon log ==="
    cat /tmp/charon-west.log 2>/dev/null || echo "(not captured)"
    echo ""
    echo "=== ns-east charon log ==="
    cat /tmp/charon-east.log 2>/dev/null || echo "(not captured)"
} > "$EVIDENCE_DIR/11_charon_logs.txt" 2>&1

log "Evidence saved to $EVIDENCE_DIR"
ls -la "$EVIDENCE_DIR"
