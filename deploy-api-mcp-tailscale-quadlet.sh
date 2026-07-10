#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ==============================================================================
# API MCP Server + Tailscale — Podman Quadlet Deployment
#
# Creates:
#   /etc/api-mcp-server/tailscale.env
#   /etc/api-mcp-server/api-mcp-server.env
#   /etc/containers/systemd/api-mcp-server.pod
#   /etc/containers/systemd/api-mcp-tailscale.container
#   /etc/containers/systemd/api-mcp-server.container
#
# Run:
#   sudo bash deploy-api-mcp-tailscale-quadlet.sh
#
# Optional overrides:
#   sudo API_MCP_IMAGE=localhost/api-mcp-server:latest \
#        API_MCP_PORT=3000 \
#        TAILSCALE_HOSTNAME=api-mcp-server \
#        TAILSCALE_TAGS=tag:mcp \
#        bash deploy-api-mcp-tailscale-quadlet.sh
# ==============================================================================

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Run this script as root or with sudo." >&2
    exit 1
fi

command -v podman >/dev/null 2>&1 || {
    echo "ERROR: Podman is not installed." >&2
    exit 1
}

command -v systemctl >/dev/null 2>&1 || {
    echo "ERROR: systemd is unavailable." >&2
    exit 1
}

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

TAILSCALE_AUTH_KEY='tskey-auth-kXAVZXL5ag11CNTRL-uimCJTwKnrJd6bmEryznrJ4wvHNoj5Hj2'

API_MCP_IMAGE="${API_MCP_IMAGE:-localhost/api-mcp-server:latest}"
API_MCP_PORT="${API_MCP_PORT:-3000}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-api-mcp-server}"
TAILSCALE_TAGS="${TAILSCALE_TAGS:-tag:mcp}"

QUADLET_DIR="/etc/containers/systemd"
CONFIG_DIR="/etc/api-mcp-server"
STATE_DIR="/var/lib/api-mcp-server"
TAILSCALE_STATE_DIR="${STATE_DIR}/tailscale"
BACKUP_DIR="${CONFIG_DIR}/backups"
TIMESTAMP="$(date +'%Y%m%d-%H%M%S')"

# ------------------------------------------------------------------------------
# Validate values
# ------------------------------------------------------------------------------

if [[ "${TAILSCALE_AUTH_KEY}" != tskey-auth-* ]]; then
    echo "ERROR: TAILSCALE_AUTH_KEY must begin with tskey-auth-." >&2
    exit 1
fi

if ! [[ "${API_MCP_PORT}" =~ ^[0-9]+$ ]] ||
   (( API_MCP_PORT < 1 || API_MCP_PORT > 65535 )); then
    echo "ERROR: API_MCP_PORT must be between 1 and 65535." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# Create directories
# ------------------------------------------------------------------------------

install -d -m 0755 -o root -g root "${QUADLET_DIR}"
install -d -m 0750 -o root -g root "${CONFIG_DIR}"
install -d -m 0700 -o root -g root "${BACKUP_DIR}"
install -d -m 0700 -o root -g root "${STATE_DIR}"
install -d -m 0700 -o root -g root "${TAILSCALE_STATE_DIR}"

# ------------------------------------------------------------------------------
# Back up existing configuration
# ------------------------------------------------------------------------------

for file in \
    "${CONFIG_DIR}/tailscale.env" \
    "${CONFIG_DIR}/api-mcp-server.env" \
    "${QUADLET_DIR}/api-mcp-server.pod" \
    "${QUADLET_DIR}/api-mcp-tailscale.container" \
    "${QUADLET_DIR}/api-mcp-server.container"
do
    if [[ -f "${file}" ]]; then
        cp --preserve=mode,ownership,timestamps \
            "${file}" \
            "${BACKUP_DIR}/$(basename "${file}").${TIMESTAMP}.bak"
    fi
done

# ------------------------------------------------------------------------------
# Protected Tailscale environment
# ------------------------------------------------------------------------------

cat > "${CONFIG_DIR}/tailscale.env" <<EOF
TS_AUTHKEY=${TAILSCALE_AUTH_KEY}
TS_HOSTNAME=${TAILSCALE_HOSTNAME}
TS_EXTRA_ARGS=--advertise-tags=${TAILSCALE_TAGS}
TS_STATE_DIR=/var/lib/tailscale
TS_USERSPACE=false
EOF

chown root:root "${CONFIG_DIR}/tailscale.env"
chmod 0600 "${CONFIG_DIR}/tailscale.env"

# ------------------------------------------------------------------------------
# API MCP application environment
#
# Add any additional application variables below.
# ------------------------------------------------------------------------------

cat > "${CONFIG_DIR}/api-mcp-server.env" <<EOF
NODE_ENV=production
HOST=0.0.0.0
PORT=${API_MCP_PORT}
EOF

chown root:root "${CONFIG_DIR}/api-mcp-server.env"
chmod 0600 "${CONFIG_DIR}/api-mcp-server.env"

# ------------------------------------------------------------------------------
# Shared Podman pod
# ------------------------------------------------------------------------------

cat > "${QUADLET_DIR}/api-mcp-server.pod" <<EOF
[Unit]
Description=API MCP Server Pod
Documentation=https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
Wants=network-online.target
After=network-online.target

[Pod]
PodName=api-mcp-server-pod

# Localhost exposure for a reverse proxy running on this host.
PublishPort=127.0.0.1:${API_MCP_PORT}:${API_MCP_PORT}

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 "${QUADLET_DIR}/api-mcp-server.pod"

# ------------------------------------------------------------------------------
# Tailscale sidecar
# ------------------------------------------------------------------------------

cat > "${QUADLET_DIR}/api-mcp-tailscale.container" <<EOF
[Unit]
Description=Tailscale Sidecar for API MCP Server
Documentation=https://tailscale.com/kb/1282/docker
Requires=api-mcp-server-pod.service
After=api-mcp-server-pod.service network-online.target
Wants=network-online.target

[Container]
Image=docker.io/tailscale/tailscale:stable
ContainerName=api-mcp-tailscale
Pod=api-mcp-server.pod

EnvironmentFile=${CONFIG_DIR}/tailscale.env

AddCapability=NET_ADMIN
AddCapability=NET_RAW
AddDevice=/dev/net/tun:/dev/net/tun

Volume=${TAILSCALE_STATE_DIR}:/var/lib/tailscale:Z

Pull=newer
NoNewPrivileges=false

[Service]
Restart=always
RestartSec=10
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 "${QUADLET_DIR}/api-mcp-tailscale.container"

# ------------------------------------------------------------------------------
# API MCP application container
# ------------------------------------------------------------------------------

cat > "${QUADLET_DIR}/api-mcp-server.container" <<EOF
[Unit]
Description=API MCP Server
Requires=api-mcp-server-pod.service
Requires=api-mcp-tailscale.service
After=api-mcp-server-pod.service api-mcp-tailscale.service

[Container]
Image=${API_MCP_IMAGE}
ContainerName=api-mcp-server
Pod=api-mcp-server.pod

EnvironmentFile=${CONFIG_DIR}/api-mcp-server.env

Exec=npm start
Pull=newer
NoNewPrivileges=true

[Service]
Restart=always
RestartSec=10
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 "${QUADLET_DIR}/api-mcp-server.container"

# ------------------------------------------------------------------------------
# Check application image
# ------------------------------------------------------------------------------

if ! podman image exists "${API_MCP_IMAGE}"; then
    echo
    echo "WARNING: Application image does not currently exist locally:"
    echo "  ${API_MCP_IMAGE}"
    echo
    echo "Attempting to pull it..."
    if ! podman pull "${API_MCP_IMAGE}"; then
        echo
        echo "ERROR: The application image could not be pulled."
        echo
        echo "Build it before restarting the service, for example:"
        echo "  podman build -t '${API_MCP_IMAGE}' ./api-mcp-server"
        echo
        echo "The Quadlet files and protected environment files were still installed."
        systemctl daemon-reload
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# Generate and activate services
# ------------------------------------------------------------------------------

systemctl daemon-reload

SERVICES=(
    api-mcp-server-pod.service
    api-mcp-tailscale.service
    api-mcp-server.service
)

for service in "${SERVICES[@]}"; do
    if ! systemctl cat "${service}" >/dev/null 2>&1; then
        echo "ERROR: Quadlet did not generate ${service}." >&2
        echo "Inspect the generator output with:" >&2
        echo "  /usr/lib/systemd/system-generators/podman-system-generator --dryrun" >&2
        exit 1
    fi
done

systemctl enable \
    api-mcp-server-pod.service \
    api-mcp-tailscale.service \
    api-mcp-server.service

systemctl restart api-mcp-server-pod.service
systemctl restart api-mcp-tailscale.service
systemctl restart api-mcp-server.service

# ------------------------------------------------------------------------------
# Verification
# ------------------------------------------------------------------------------

echo
echo "Waiting briefly for Tailscale initialization..."
sleep 5

echo
echo "======================================================================"
echo "Deployment completed"
echo "======================================================================"
echo "Application image:   ${API_MCP_IMAGE}"
echo "Application port:    127.0.0.1:${API_MCP_PORT}"
echo "Tailscale hostname:  ${TAILSCALE_HOSTNAME}"
echo "Tailscale tags:      ${TAILSCALE_TAGS}"
echo

echo "Service state:"
systemctl --no-pager --full status \
    api-mcp-tailscale.service \
    api-mcp-server.service || true

echo
echo "Tailscale status:"
podman exec api-mcp-tailscale tailscale status || true

echo
echo "Tailscale IPv4 address:"
podman exec api-mcp-tailscale tailscale ip -4 || true

echo
echo "Useful commands:"
echo "  systemctl status api-mcp-tailscale api-mcp-server"
echo "  journalctl -u api-mcp-tailscale -u api-mcp-server -f"
echo "  podman exec api-mcp-tailscale tailscale status"
echo "  curl http://127.0.0.1:${API_MCP_PORT}/"
