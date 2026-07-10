/**
 * Tailscale Configuration for API MCP Server
 *
 * This module provides Tailscale network configuration for secure remote access
 * to the API MCP server through the Tailscale mesh network.
 */

import { createServer } from 'http';
import { resolve } from 'path';

const TAILSCALE_ENABLED = process.env.TAILSCALE_ENABLED === 'true';
const TAILSCALE_HOSTNAME = process.env.TAILSCALE_HOSTNAME || 'api-mcp-server';
const BIND_ADDRESS = process.env.BIND_ADDRESS || 'localhost';
const BIND_PORT = process.env.BIND_PORT || 3000;

/**
 * Tailscale network configuration object
 * @type {Object}
 */
export const tailscaleConfig = {
  enabled: TAILSCALE_ENABLED,
  hostname: TAILSCALE_HOSTNAME,
  bindAddress: BIND_ADDRESS,
  bindPort: parseInt(BIND_PORT, 10),

  // Security settings
  security: {
    trustProxy: TAILSCALE_ENABLED, // Trust X-Forwarded-For headers from Tailscale
    requireHttps: false, // Set to true in production with proper certificates
  },

  // Tailscale-specific features
  features: {
    funnel: process.env.TAILSCALE_FUNNEL === 'true', // Enable Tailscale Funnel for public access
    tlsCert: process.env.TAILSCALE_TLS_CERT_DIR || '/var/lib/tailscale', // TLS certificate directory
  },

  // Health check configuration
  health: {
    enabled: true,
    path: '/health',
    interval: 30000, // 30 seconds
  },

  // Metrics and monitoring
  metrics: {
    enabled: process.env.METRICS_ENABLED === 'true',
    port: process.env.METRICS_PORT || 9090,
  },
};

/**
 * Get server configuration for Tailscale integration
 * @returns {Object} Server configuration
 */
export function getTailscaleServerConfig() {
  return {
    host: BIND_ADDRESS,
    port: BIND_PORT,
    backlog: 511,
    maxConnections: 100,
  };
}

/**
 * Middleware to detect Tailscale connection
 * @param {Object} req - Express request object
 * @returns {boolean} True if request is from Tailscale network
 */
export function isTailscaleConnection(req) {
  if (!TAILSCALE_ENABLED) return false;

  const tailscaleHeader = req.get('X-Tailscale-Auth') ||
                         req.get('X-Forwarded-For') ||
                         '';

  return tailscaleHeader.length > 0;
}

/**
 * Middleware for Tailscale health checks
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware
 */
export function tailscaleHealthCheck(req, res, next) {
  if (!tailscaleConfig.health.enabled) {
    return next();
  }

  if (req.path === tailscaleConfig.health.path) {
    res.json({
      status: 'healthy',
      service: 'api-mcp-server',
      tailscale: {
        enabled: TAILSCALE_ENABLED,
        hostname: TAILSCALE_HOSTNAME,
      },
      timestamp: new Date().toISOString(),
    });
    return;
  }

  next();
}

/**
 * Setup Tailscale server
 * @param {Object} app - Express app instance
 */
export function setupTailscaleServer(app) {
  if (!TAILSCALE_ENABLED) {
    console.log('Tailscale integration disabled');
    return;
  }

  console.log('Tailscale Integration Enabled');
  console.log(`  Hostname: ${TAILSCALE_HOSTNAME}`);
  console.log(`  Bind Address: ${BIND_ADDRESS}:${BIND_PORT}`);
  console.log(`  Funnel: ${tailscaleConfig.features.funnel ? 'enabled' : 'disabled'}`);

  // Add health check middleware
  app.use(tailscaleHealthCheck);

  // Add request logging for Tailscale connections
  app.use((req, res, next) => {
    if (isTailscaleConnection(req)) {
      console.log(`[Tailscale] ${req.method} ${req.path}`);
    }
    next();
  });
}

export default tailscaleConfig;
