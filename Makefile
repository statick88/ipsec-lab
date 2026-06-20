# =============================================================================
# IPsec Lab - Makefile
# =============================================================================

# Configuration
DOCKER_IMAGE ?= ipsec-lab
DOCKER_TAG ?= latest
DOCKER_USER ?= statick
DOCKER_FULL_IMAGE = $(DOCKER_USER)/$(DOCKER_IMAGE):$(DOCKER_TAG)
CONTAINER_NAME = ipsec-lab

# Colors
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
CYAN = \033[0;36m
NC = \033[0m

.PHONY: help build run run-bg stop status capture validate evidence \
        test test-unit test-e2e test-security test-all \
        lint lint-docker lint-shell lint-all \
        security-scan scan trivy \
        push push-multiarch clean

help: ## Show this help message
	@echo "$(GREEN)IPsec Lab — Docker + strongSwan$(NC)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

# =============================================================================
# DOCKER
# =============================================================================

build: ## Build Docker image
	@echo "$(GREEN)Building Docker image...$(NC)"
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .
	docker tag $(DOCKER_IMAGE):$(DOCKER_TAG) $(DOCKER_FULL_IMAGE)

run: build ## Build and run IPsec lab (interactive)
	@echo "$(GREEN)Starting IPsec lab...$(NC)"
	docker run --rm --privileged --network host \
		-v "$(CURDIR)/wireshark_keys:/wireshark_keys" \
		$(DOCKER_IMAGE):$(DOCKER_TAG)

run-bg: build ## Build and run IPsec lab (background)
	@echo "$(GREEN)Starting IPsec lab in background...$(NC)"
	@-docker rm -f $(CONTAINER_NAME) 2>/dev/null
	docker run -d --privileged --network host \
		--name $(CONTAINER_NAME) \
		-v "$(CURDIR)/wireshark_keys:/wireshark_keys" \
		$(DOCKER_IMAGE):$(DOCKER_TAG)
	@sleep 15
	@echo "$(GREEN)Lab running. Use 'make status' to check.$(NC)"

stop: ## Stop running lab container
	@echo "$(YELLOW)Stopping lab...$(NC)"
	docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
	@echo "$(GREEN)Stopped$(NC)"

status: ## Show IPsec tunnel status
	@echo "$(GREEN)=== IPsec Lab Status ===$(NC)"
	@echo ""
	@echo "$(YELLOW)--- ns-east (initiator) ---$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c 'ip netns exec ns-east ipsec statusall' 2>/dev/null || echo "ns-east not running"
	@echo ""
	@echo "$(YELLOW)--- ns-west charon PID ---$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c 'cat /tmp/charon-west.pid 2>/dev/null && kill -0 $$(cat /tmp/charon-west.pid) 2>/dev/null && echo " running" || echo " not running"' 2>/dev/null || echo "ns-west not running"
	@echo ""
	@echo "$(YELLOW)--- XFRM State (ns-east) ---$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c 'ip netns exec ns-east ip xfrm state' 2>/dev/null || echo "XFRM not available"

capture: ## Capture encrypted traffic to pcap (with ping)
	@echo "$(GREEN)Capturing ESP traffic on veth-east (10s)...$(NC)"
	@docker exec -d $(CONTAINER_NAME) bash -c 'ip netns exec ns-east timeout 10 tcpdump -i veth-east -w /wireshark_keys/capture.pcap "udp port 500 or udp port 4500 or esp or icmp"' 2>/dev/null || true
	@sleep 1
	@docker exec $(CONTAINER_NAME) bash -c 'ip netns exec ns-east ping -c 10 -i 1 10.20.0.1' 2>/dev/null || true
	@sleep 2
	@echo "$(GREEN)Capture saved to wireshark_keys/capture.pcap$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c 'cp /root/.config/wireshark/esp_sa /wireshark_keys/esp_sa 2>/dev/null || true' 2>/dev/null || true

validate: ## Validate lab: connectivity + tunnel + XFRM
	@echo "$(GREEN)=== Validating IPsec Lab ===$(NC)"
	@echo ""
	@echo "$(YELLOW)1. Connectivity...$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c 'ip netns exec ns-east ping -c 3 10.0.0.2' || echo "FAIL"
	@echo ""
	@echo "$(YELLOW)2. Tunnel status...$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c 'ip netns exec ns-east ipsec statusall' || echo "FAIL"
	@echo ""
	@echo "$(YELLOW)3. XFRM SAs...$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c 'ip netns exec ns-east ip xfrm state' || echo "FAIL"
	@echo ""
	@echo "$(YELLOW)4. Encrypted traffic (via tunnel)...$(NC)"
	@docker exec $(CONTAINER_NAME) bash -c 'ip netns exec ns-east ping -c 3 10.20.0.1 && echo "" && echo "XFRM counters:" && ip netns exec ns-east ip -s xfrm state | grep -E "bytes|packets" | head -4' || echo "FAIL"
	@echo ""
	@echo "$(GREEN)Validation complete$(NC)"

evidence: ## Generate academic evidence documents
	@echo "$(GREEN)Generating evidence documents...$(NC)"
	@bash scripts/evidence.sh
	@echo "$(GREEN)Evidence saved to evidence/$(NC)"

screenshots: ## Generate PNG screenshots from HTML evidence
	@echo "$(GREEN)Generating screenshots...$(NC)"
	@bash scripts/generate-screenshots.sh
	@echo "$(GREEN)Open evidence/index.html to view$(NC)"

# =============================================================================
# TESTS
# =============================================================================

test: test-unit ## Run unit tests

test-unit: ## Run unit/integration tests
	@echo "$(GREEN)Running unit tests...$(NC)"
	bats tests/01-unit.bats

test-e2e: ## Run end-to-end tests
	@echo "$(GREEN)Running E2E tests...$(NC)"
	bats tests/02-e2e.bats

test-security: ## Run security tests
	@echo "$(GREEN)Running security tests...$(NC)"
	bats tests/03-security.bats

test-all: ## Run all tests
	@echo "$(GREEN)Running all tests...$(NC)"
	bats tests/*.bats

# =============================================================================
# LINT
# =============================================================================

lint: lint-docker lint-shell ## Run all linters

lint-docker: ## Lint Dockerfile
	@echo "$(GREEN)Linting Dockerfile...$(NC)"
	docker run --rm -i hadolint/hadolint < Dockerfile

lint-shell: ## Lint shell scripts
	@echo "$(GREEN)Linting shell scripts...$(NC)"
	shellcheck scripts/*.sh

# =============================================================================
# SECURITY
# =============================================================================

security-scan: trivy ## Run security scans

scan: trivy ## Alias for trivy

trivy: ## Run Trivy vulnerability scanner
	@echo "$(GREEN)Running Trivy scan...$(NC)"
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		aquasec/trivy:latest image \
		--severity CRITICAL,HIGH \
		$(DOCKER_IMAGE):$(DOCKER_TAG)

# =============================================================================
# DOCKER HUB
# =============================================================================

push: build ## Build and push image to Docker Hub
	@echo "$(GREEN)Pushing to Docker Hub: $(DOCKER_FULL_IMAGE)$(NC)"
	docker push $(DOCKER_FULL_IMAGE)
	@echo "$(GREEN)Pushed$(NC)"

push-multiarch: ## Build and push multi-arch image (requires buildx)
	@echo "$(GREEN)Building multi-arch image...$(NC)"
	docker buildx create --use --name ipsec-lab-builder 2>/dev/null || true
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		-t $(DOCKER_FULL_IMAGE) \
		--push .

# =============================================================================
# CLEAN
# =============================================================================

clean: ## Clean containers and images
	@echo "$(YELLOW)Cleaning...$(NC)"
	@-docker rm -f $(CONTAINER_NAME) 2>/dev/null
	@-docker rm -f ipsec-lab-* 2>/dev/null
	docker rmi $(DOCKER_IMAGE):$(DOCKER_TAG) 2>/dev/null || true
	docker rmi $(DOCKER_FULL_IMAGE) 2>/dev/null || true
	@echo "$(GREEN)Clean$(NC)"
