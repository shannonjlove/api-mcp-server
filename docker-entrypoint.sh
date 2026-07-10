#!/bin/sh
#
# Docker entrypoint script for API MCP Server with Tailscale support
#
# This script handles:
# 1. Starting Tailscale daemon (if enabled)
# 2. Authenticating with Tailscale (if auth key provided)
# 3. Starting the MCP server

set -e

# Configuration
TAILSCALE_ENABLED="${TAILSCALE_ENABLED:-true}"
TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY:-}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-api-mcp-server}"

# Colors for output
log_info() {
  echo "[INFO] $*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

# Start Tailscale daemon if enabled
if [ "$TAILSCALE_ENABLED" = "true" ]; then
  log_info "Starting Tailscale daemon..."

  # Start tailscaled in the background
  tailscaled --tun=userspace-networking &
  TAILSCALED_PID=$!

  # Give tailscaled time to start
  sleep 2

  # Authenticate if auth key is provided
  if [ -n "$TAILSCALE_AUTH_KEY" ]; then
    log_info "Authenticating with Tailscale using auth key..."
    tailscale login --authkey="$TAILSCALE_AUTH_KEY" --hostname="$TAILSCALE_HOSTNAME" || {
      log_error "Failed to authenticate with Tailscale"
      kill $TAILSCALED_PID 2>/dev/null || true
      exit 1
    }
  else
    log_info "Tailscale enabled but no auth key provided"
    log_info "To enable Tailscale authentication, set TAILSCALE_AUTH_KEY environment variable"
  fi

  log_info "Tailscale is ready"
  log_info "Tailscale status:"
  tailscale status || true
fi

# Execute the main command
log_info "Starting API MCP Server..."
exec "$@"
