# =============================================================================
# IPsec Lab - Dockerfile
# strongSwan 5.9.5 on Ubuntu 22.04 (apt)
# =============================================================================

FROM ubuntu:22.04

LABEL maintainer="Diego Saavedra <statick88@users.noreply.github.com>"
LABEL description="IPsec Lab - IKEv2/ESP with strongSwan"
LABEL version="1.0.0"

# Security: Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    strongswan \
    strongswan-pki \
    strongswan-swanctl \
    libcharon-extra-plugins \
    libcharon-extauth-plugins \
    iproute2 \
    iptables \
    tcpdump \
    iputils-ping \
    grep \
    gawk \
    && rm -rf /var/lib/apt/lists/*

# Security: Create non-root user (but we need root for namespaces)
# We'll run as root but limit capabilities

# Copy configuration files
COPY configs/ /etc/ipsec.d/
COPY scripts/run-lab.sh /usr/local/bin/run-lab.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/run-lab.sh

# Security: Remove setuid/setgid binaries
RUN find / -perm /6000 -type f -exec chmod a-s {} \; 2>/dev/null || true

# Security: Make /etc/ipsec.d read-only
RUN chmod -R 555 /etc/ipsec.d/

# Working directory
WORKDIR /lab

# Expose nothing - this is a lab container
# Use --privileged for namespace operations

# Default command
CMD ["/usr/local/bin/run-lab.sh"]
