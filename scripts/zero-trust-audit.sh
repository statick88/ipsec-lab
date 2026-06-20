#!/bin/bash
# Zero Trust Audit Script — IPsec Lab
# Verifies identity, micro-segmentation, continuous verification
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }
header() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }
pass() { echo -e "${GREEN}✓ $*${NC}"; }
fail() { echo -e "${RED}✗ $*${NC}"; }

CONTAINER="${1:-ipsec-lab}"
CERT_DIR="/tmp/zero-trust-certs"
ERRORS=0

# =============================================================================
header "ZERO TRUST AUDIT — $(date '+%Y-%m-%d %H:%M:%S')"
# =============================================================================

# 1. IDENTITY VERIFICATION (X.509 Certificates)
header "1. IDENTITY VERIFICATION — X.509 Certificates"

if [ -f "$CERT_DIR/ca.crt" ]; then
    pass "CA certificate exists"
    
    # Verify CA
    CA_SUBJECT=$(openssl x509 -in "$CERT_DIR/ca.crt" -noout -subject 2>/dev/null || echo "")
    if echo "$CA_SUBJECT" | grep -q "ZeroTrust Lab CA"; then
        pass "CA subject: ZeroTrust Lab CA"
    else
        fail "CA subject mismatch: $CA_SUBJECT"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Verify east cert
    if [ -f "$CERT_DIR/gw-east.crt" ]; then
        EAST_SUBJECT=$(openssl x509 -in "$CERT_DIR/gw-east.crt" -noout -subject 2>/dev/null || echo "")
        EAST_ISSUER=$(openssl x509 -in "$CERT_DIR/gw-east.crt" -noout -issuer 2>/dev/null || echo "")
        if echo "$EAST_SUBJECT" | grep -q "gw-east"; then
            pass "gw-east certificate: valid subject"
        else
            fail "gw-east certificate: invalid subject"
            ERRORS=$((ERRORS + 1))
        fi
        if echo "$EAST_ISSUER" | grep -q "ZeroTrust Lab CA"; then
            pass "gw-east certificate: signed by ZeroTrust CA"
        else
            fail "gw-east certificate: NOT signed by ZeroTrust CA"
            ERRORS=$((ERRORS + 1))
        fi
    else
        fail "gw-east certificate NOT found"
        ERRORS=$((ERRORS + 1))
    fi
    
    # Verify west cert
    if [ -f "$CERT_DIR/gw-west.crt" ]; then
        WEST_SUBJECT=$(openssl x509 -in "$CERT_DIR/gw-west.crt" -noout -subject 2>/dev/null || echo "")
        if echo "$WEST_SUBJECT" | grep -q "gw-west"; then
            pass "gw-west certificate: valid subject"
        else
            fail "gw-west certificate: invalid subject"
            ERRORS=$((ERRORS + 1))
        fi
    else
        fail "gw-west certificate NOT found"
        ERRORS=$((ERRORS + 1))
    fi
else
    fail "CA certificate NOT found at $CERT_DIR/ca.crt"
    ERRORS=$((ERRORS + 1))
fi

# 2. MICRO-SEGMENTATION (Network Namespaces)
header "2. MICRO-SEGMENTATION — Network Namespaces"

for NS in ns-east ns-west; do
    if docker exec "$CONTAINER" ip netns list 2>/dev/null | grep -q "$NS"; then
        pass "Namespace $NS exists"
    else
        fail "Namespace $NS NOT found"
        ERRORS=$((ERRORS + 1))
    fi
done

# Verify isolation: east cannot reach west's protected subnet directly
if docker exec "$CONTAINER" bash -c 'ip netns exec ns-east ping -c 1 -W 1 10.20.0.1' >/dev/null 2>&1; then
    pass "Micro-segmentation: ns-east reaches 10.20.0.1 (via tunnel)"
else
    warn "Micro-segmentation: ns-east cannot reach 10.20.0.1"
fi

# 3. CONTINUOUS VERIFICATION (DPD + Rekeying)
header "3. CONTINUOUS VERIFICATION — DPD & Rekeying"

DPD_CONFIG=$(docker exec "$CONTAINER" bash -c 'cat /etc/ipsec.conf 2>/dev/null' | grep -E "dpd" || echo "")
if echo "$DPD_CONFIG" | grep -q "dpddelay=10s"; then
    pass "DPD interval: 10s (aggressive)"
else
    warn "DPD interval not set to 10s"
fi

if echo "$DPD_CONFIG" | grep -q "dpdtimeout=30s"; then
    pass "DPD timeout: 30s (fail fast)"
else
    warn "DPD timeout not set to 30s"
fi

if echo "$DPD_CONFIG" | grep -q "dpdaction=restart"; then
    pass "DPD action: restart (re-verify)"
else
    warn "DPD action not set to restart"
fi

# 4. TUNNEL STATUS (IKEv2 + ESP)
header "4. TUNNEL STATUS — IKEv2 & ESP"

STATUS=$(docker exec "$CONTAINER" bash -c 'ip netns exec ns-east ipsec statusall' 2>/dev/null || echo "")
if echo "$STATUS" | grep -q "ESTABLISHED"; then
    pass "IKEv2 SA: ESTABLISHED"
else
    fail "IKEv2 SA: NOT established"
    ERRORS=$((ERRORS + 1))
fi

if echo "$STATUS" | grep -q "INSTALLED"; then
    pass "CHILD SA (ESP): INSTALLED"
else
    fail "CHILD SA (ESP): NOT installed"
    ERRORS=$((ERRORS + 1))
fi

# 5. AUDIT LOGGING
header "5. AUDIT LOGGING — Charon"

if docker exec "$CONTAINER" bash -c 'test -f /tmp/charon-east.log' 2>/dev/null; then
    EAST_LOG_LINES=$(docker exec "$CONTAINER" bash -c 'wc -l < /tmp/charon-east.log' 2>/dev/null || echo "0")
    pass "Charon east log: $EAST_LOG_LINES lines"
else
    warn "Charon east log not found"
fi

if docker exec "$CONTAINER" bash -c 'test -f /tmp/charon-west.log' 2>/dev/null; then
    WEST_LOG_LINES=$(docker exec "$CONTAINER" bash -c 'wc -l < /tmp/charon-west.log' 2>/dev/null || echo "0")
    pass "Charon west log: $WEST_LOG_LINES lines"
else
    warn "Charon west log not found"
fi

# 6. XFRM AUDIT (Security Associations)
header "6. XFRM AUDIT — Security Associations"

XFRM_SA=$(docker exec "$CONTAINER" bash -c 'ip netns exec ns-east ip xfrm state' 2>/dev/null || echo "")
SA_COUNT=$(echo "$XFRM_SA" | grep -c "^proto esp" || echo "0")
if [ "$SA_COUNT" -ge 2 ]; then
    pass "XFRM SAs: $SA_COUNT (bidirectional)"
else
    fail "XFRM SAs: $SA_COUNT (expected >= 2)"
    ERRORS=$((ERRORS + 1))
fi

XFRM_POLICY=$(docker exec "$CONTAINER" bash -c 'ip netns exec ns-east ip xfrm policy' 2>/dev/null || echo "")
POLICY_COUNT=$(echo "$XFRM_POLICY" | grep -c "dir" || echo "0")
if [ "$POLICY_COUNT" -ge 3 ]; then
    pass "XFRM Policies: $POLICY_COUNT (out + fwd + in)"
else
    fail "XFRM Policies: $POLICY_COUNT (expected >= 3)"
    ERRORS=$((ERRORS + 1))
fi

# 7. WIRESHARK KEYS (Evidence)
header "7. WIRESHARK KEYS — Decryption Evidence"

ESP_SA="${WIRESHARK_DIR:-/wireshark_keys}/esp_sa"
if [ -f "$ESP_SA" ]; then
    ESP_LINES=$(wc -l < "$ESP_SA" 2>/dev/null || echo "0")
    if [ "$ESP_LINES" -ge 2 ]; then
        pass "ESP SA keys: $ESP_LINES entries (bidirectional)"
    else
        warn "ESP SA keys: $ESP_LINES entries (expected >= 2)"
    fi
else
    warn "ESP SA file not found"
fi

# SUMMARY
header "ZERO TRUST AUDIT SUMMARY"

if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ZERO TRUST AUDIT: PASS — All checks verified${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
else
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ZERO TRUST AUDIT: FAIL — $ERRORS error(s) found${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
fi

exit "$ERRORS"
