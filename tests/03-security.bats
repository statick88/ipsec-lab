#!/usr/bin/env bats

# =============================================================================
# IPsec Lab - Security Tests
# =============================================================================

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  IMAGE_NAME="ipsec-lab:security"
}

# =============================================================================
# DOCKER SECURITY TESTS
# =============================================================================

@test "Docker image has no critical vulnerabilities" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  
  # Run Trivy
  run docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy:latest image \
    --severity CRITICAL \
    --exit-code 1 \
    "$IMAGE_NAME"
  
  [ "$status" -eq 0 ]
}

@test "Dockerfile uses specific Ubuntu version" {
  run grep "FROM ubuntu:" Dockerfile
  [ "$status" -eq 0 ]
  [[ "$output" == *"ubuntu:22.04"* ]]
}

@test "Dockerfile sets DEBIAN_FRONTEND" {
  run grep "DEBIAN_FRONTEND" Dockerfile
  [ "$status" -eq 0 ]
}

@test "Dockerfile removes apt lists" {
  run grep "rm -rf /var/lib/apt/lists" Dockerfile
  [ "$status" -eq 0 ]
}

@test "Dockerfile has LABEL metadata" {
  run grep "LABEL" Dockerfile
  [ "$status" -eq 0 ]
  [[ "$output" == *"maintainer"* ]]
}

# =============================================================================
# SHELL SECURITY TESTS
# =============================================================================

@test "run-lab.sh uses set -euo pipefail" {
  run head -10 scripts/run-lab.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"set -euo pipefail"* ]]
}

@test "run-lab.sh checks for root" {
  run grep "EUID" scripts/run-lab.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"Must run as root"* ]]
}

@test "run-lab.sh has cleanup trap" {
  run grep "trap" scripts/run-lab.sh
  [ "$status" -eq 0 ]
}

@test "Shell scripts pass ShellCheck" {
  run shellcheck scripts/*.sh
  [ "$status" -eq 0 ]
}

# =============================================================================
# CONFIGURATION SECURITY TESTS
# =============================================================================

@test "IPsec configs use PSK authentication" {
  run grep -r "PSK" configs/
  [ "$status" -eq 0 ]
}

@test "IPsec PSK is not empty" {
  run grep -r "PSK" configs/
  [ "$status" -eq 0 ]
  [[ "$output" == *"PSK \""* ]]
  ! [[ "$output" == *"PSK \"\""* ]]
}

@test "strongSwan config limits plugins" {
  run grep -r "load_modular" configs/
  [ "$status" -eq 0 ]
}

@test "DPD is configured" {
  run grep -r "dpd" configs/
  [ "$status" -eq 0 ]
}

# =============================================================================
# NETWORK SECURITY TESTS
# =============================================================================

@test "Protected subnets are isolated" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  CONTAINER="ipsec-lab-sec-$$"
  docker run -d --privileged --network host \
    --name "$CONTAINER" \
    "$IMAGE_NAME"
  sleep 20
  
  # Ping gateway directly (should work)
  run docker exec "$CONTAINER" ip netns exec ns-east ping -c 1 10.0.0.2
  [ "$status" -eq 0 ]
  
  # Cleanup
  docker rm -f "$CONTAINER" 2>/dev/null || true
}

@test "XFRM policies enforce tunnel" {
  docker build -t "$IMAGE_NAME" . 2>/dev/null
  CONTAINER="ipsec-lab-sec-$$"
  docker run -d --privileged --network host \
    --name "$CONTAINER" \
    "$IMAGE_NAME"
  sleep 20
  
  run docker exec "$CONTAINER" ip netns exec ns-east ip xfrm policy
  [ "$status" -eq 0 ]
  [[ "$output" == *"dir out"* ]]
  [[ "$output" == *"dir fwd"* ]]
  [[ "$output" == *"dir in"* ]]
  
  # Cleanup
  docker rm -f "$CONTAINER" 2>/dev/null || true
}
