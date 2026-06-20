#!/usr/bin/env bats

# =============================================================================
# IPsec Lab - E2E Tests (Full Integration)
# =============================================================================

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  CONTAINER_NAME="ipsec-lab-e2e-$$"
  IMAGE_NAME="ipsec-lab:e2e"
}

teardown() {
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}

# =============================================================================
# STRONGSWAN TESTS
# =============================================================================

@test "strongSwan charon starts in ns-east" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 25
  
  run docker exec "$CONTAINER_NAME" pgrep -f "charon"
  [ "$status" -eq 0 ]
}

@test "strongSwan charon starts in ns-west" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 25
  
  run docker exec "$CONTAINER_NAME" cat /tmp/charon-west.pid
  [ "$status" -eq 0 ]
  
  run docker exec "$CONTAINER_NAME" kill -0 $output
  [ "$status" -eq 0 ]
}

# =============================================================================
# IKEv2 TUNNEL TESTS
# =============================================================================

@test "IKEv2 SA is ESTABLISHED" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 30
  
  run docker exec "$CONTAINER_NAME" ipsec statusall
  [ "$status" -eq 0 ]
  [[ "$output" == *"ESTABLISHED"* ]]
}

@test "CHILD_SA is INSTALLED" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 30
  
  run docker exec "$CONTAINER_NAME" ipsec statusall
  [ "$status" -eq 0 ]
  [[ "$output" == *"INSTALLED"* ]]
}

@test "IKE proposal uses AES_CBC_256" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 30
  
  run docker exec "$CONTAINER_NAME" ipsec statusall
  [ "$status" -eq 0 ]
  [[ "$output" == *"AES_CBC_256"* ]]
}

@test "ESP proposal uses AES_CBC_256" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 30
  
  run docker exec "$CONTAINER_NAME" ipsec statusall
  [ "$status" -eq 0 ]
  [[ "$output" == *"AES_CBC_256"* ]]
}

# =============================================================================
# ESP TRAFFIC TESTS
# =============================================================================

@test "ESP traffic flows between protected subnets" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 30
  
  run docker exec "$CONTAINER_NAME" ip netns exec ns-east ping -c 3 10.20.0.1
  [ "$status" -eq 0 ]
  
  run docker exec "$CONTAINER_NAME" ip netns exec ns-east ip -s xfrm state
  [ "$status" -eq 0 ]
  [[ "$output" == *"bytes"* ]]
}

@test "XFRM state shows tunnel mode" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 30
  
  docker exec "$CONTAINER_NAME" ip netns exec ns-east ping -c 1 10.20.0.1 2>/dev/null
  
  run docker exec "$CONTAINER_NAME" ip netns exec ns-east ip xfrm state
  [ "$status" -eq 0 ]
  [[ "$output" == *"mode tunnel"* ]]
}

@test "XFRM policies are configured" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 30
  
  run docker exec "$CONTAINER_NAME" ip netns exec ns-east ip xfrm policy
  [ "$status" -eq 0 ]
  [[ "$output" == *"10.10.0.0/24"* ]]
  [[ "$output" == *"10.20.0.0/24"* ]]
}

# =============================================================================
# WIRESHARK KEYS TESTS
# =============================================================================

@test "esp_sa file is generated" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    -v "$(pwd)/wireshark_keys:/wireshark_keys" \
    "$IMAGE_NAME"
  sleep 35
  
  [ -f wireshark_keys/esp_sa ]
}

@test "esp_sa has correct Wireshark CSV format" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    -v "$(pwd)/wireshark_keys:/wireshark_keys" \
    "$IMAGE_NAME"
  sleep 35
  
  run head -1 wireshark_keys/esp_sa
  [ "$status" -eq 0 ]
  [[ "$output" == *'"IPv4"'* ]]
  [[ "$output" == *'"AES-CBC [RFC3602]"'* ]]
  [[ "$output" == *'"HMAC-SHA-256-128 [RFC4868]"'* ]]
}

@test "esp_sa contains both directions" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    -v "$(pwd)/wireshark_keys:/wireshark_keys" \
    "$IMAGE_NAME"
  sleep 35
  
  run grep -c "IPv4" wireshark_keys/esp_sa
  [ "$status" -eq 0 ]
  [ "$output" -ge 2 ]
}

# =============================================================================
# CAPTURE TESTS
# =============================================================================

@test "capture.pcap is generated" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    -v "$(pwd)/wireshark_keys:/wireshark_keys" \
    "$IMAGE_NAME"
  sleep 30
  
  docker exec -d "$CONTAINER_NAME" bash -c 'ip netns exec ns-east timeout 5 tcpdump -i veth-east -w /wireshark_keys/capture.pcap "esp"' 2>/dev/null || true
  sleep 1
  docker exec "$CONTAINER_NAME" ip netns exec ns-east ping -c 3 10.20.0.1 2>/dev/null || true
  sleep 5
  
  [ -f wireshark_keys/capture.pcap ]
}

@test "capture.pcap contains ESP packets" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    -v "$(pwd)/wireshark_keys:/wireshark_keys" \
    "$IMAGE_NAME"
  sleep 30
  
  docker exec -d "$CONTAINER_NAME" bash -c 'ip netns exec ns-east timeout 5 tcpdump -i veth-east -w /wireshark_keys/capture.pcap "esp"' 2>/dev/null || true
  sleep 1
  docker exec "$CONTAINER_NAME" ip netns exec ns-east ping -c 3 10.20.0.1 2>/dev/null || true
  sleep 5
  
  run tcpdump -r wireshark_keys/capture.pcap -nn 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"ESP"* ]]
}
