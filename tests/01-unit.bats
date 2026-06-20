#!/usr/bin/env bats

# =============================================================================
# IPsec Lab - TDD Tests (Unit/Integration)
# =============================================================================

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  CONTAINER_NAME="ipsec-lab-tdd-$$"
  IMAGE_NAME="ipsec-lab:tdd"
}

teardown() {
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}

# =============================================================================
# BUILD TESTS
# =============================================================================

@test "Docker image builds successfully" {
  run docker build -t "$IMAGE_NAME" .
  [ "$status" -eq 0 ]
}

@test "Docker image has correct labels" {
  run docker build -t "$IMAGE_NAME" .
  [ "$status" -eq 0 ]
  
  run docker inspect "$IMAGE_NAME" --format '{{index .Config.Labels "description"}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"IPsec Lab"* ]]
}

@test "Docker image uses Ubuntu 22.04" {
  run docker build -t "$IMAGE_NAME" .
  [ "$status" -eq 0 ]
  
  run docker inspect "$IMAGE_NAME" --format '{{.Config.Image}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ubuntu:22.04"* ]]
}

# =============================================================================
# NETWORK TESTS
# =============================================================================

@test "Container creates ns-east namespace" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 20
  
  run docker exec "$CONTAINER_NAME" ip netns list
  [ "$status" -eq 0 ]
  [[ "$output" == *"ns-east"* ]]
}

@test "Container creates ns-west namespace" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 20
  
  run docker exec "$CONTAINER_NAME" ip netns list
  [ "$status" -eq 0 ]
  [[ "$output" == *"ns-west"* ]]
}

@test "veth pair is connected" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 20
  
  run docker exec "$CONTAINER_NAME" ip netns exec ns-east ip link show veth-east
  [ "$status" -eq 0 ]
  
  run docker exec "$CONTAINER_NAME" ip netns exec ns-west ip link show veth-west
  [ "$status" -eq 0 ]
}

# =============================================================================
# IP CONFIGURATION TESTS
# =============================================================================

@test "ns-east has IP 10.0.0.1/30 on veth-east" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 20
  
  run docker exec "$CONTAINER_NAME" ip netns exec ns-east ip addr show veth-east
  [ "$status" -eq 0 ]
  [[ "$output" == *"10.0.0.1/30"* ]]
}

@test "ns-west has IP 10.0.0.2/30 on veth-west" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 20
  
  run docker exec "$CONTAINER_NAME" ip netns exec ns-west ip addr show veth-west
  [ "$status" -eq 0 ]
  [[ "$output" == *"10.0.0.2/30"* ]]
}

@test "ns-east has IP 10.10.0.1/24 on lo (protected subnet)" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 20
  
  run docker exec "$CONTAINER_NAME" ip netns exec ns-east ip addr show lo
  [ "$status" -eq 0 ]
  [[ "$output" == *"10.10.0.1/24"* ]]
}

@test "ns-west has IP 10.20.0.1/24 on lo (protected subnet)" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 20
  
  run docker exec "$CONTAINER_NAME" ip netns exec ns-west ip addr show lo
  [ "$status" -eq 0 ]
  [[ "$output" == *"10.20.0.1/24"* ]]
}

# =============================================================================
# CONNECTIVITY TESTS
# =============================================================================

@test "ns-east can ping ns-west gateway" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 20
  
  run docker exec "$CONTAINER_NAME" ip netns exec ns-east ping -c 3 10.0.0.2
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 packets transmitted"* ]]
  [[ "$output" == *"3 received"* ]]
}

@test "ns-west can ping ns-east gateway" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  docker run -d --privileged --network host \
    --name "$CONTAINER_NAME" \
    "$IMAGE_NAME"
  sleep 20
  
  run docker exec "$CONTAINER_NAME" ip netns exec ns-west ping -c 3 10.0.0.1
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 packets transmitted"* ]]
  [[ "$output" == *"3 received"* ]]
}
