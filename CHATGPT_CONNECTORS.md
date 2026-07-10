# ChatGPT Connectors Integration Guide

This document explains how the **hostinger-api-mcp** server integrates with ChatGPT Custom Actions and the **sjl-mcp-filesystem** service for enabling ChatGPT to access and manipulate infrastructure files.

## Overview

The Hostinger API MCP server provides 118 API tools across 6 domains:
- **Billing** (7 tools)
- **DNS** (8 tools)
- **Domains** (18 tools)
- **Hosting** (13 tools)
- **Reach** (10 tools)
- **VPS** (62 tools)

When combined with the **sjl-mcp-filesystem** connector, ChatGPT gains the ability to:
1. Query infrastructure via Hostinger API
2. Read/write configuration files
3. Search infrastructure documentation
4. Create deployment scripts
5. Manage infrastructure state

## Architecture

```
┌─────────────────────┐
│     ChatGPT         │
└──────────┬──────────┘
           │
           ├─────────────────────────────────────┐
           │                                     │
    ┌──────▼──────────┐              ┌───────────▼─────────┐
    │ Hostinger API   │              │ SJL MCP Filesystem  │
    │   Connector     │              │     Connector       │
    │                 │              │                     │
    │ (API queries)   │              │ (File read/write)   │
    └──────┬──────────┘              └───────────┬─────────┘
           │                                     │
           ▼                                     ▼
    ┌──────────────────┐              ┌──────────────────┐
    │  Hostinger API   │              │ sjl-mcp-file     │
    │  (hostinger.com) │              │ (72.61.74.250)   │
    └──────────────────┘              └──────────────────┘
```

## Hostinger API Connector Setup

### Configuration

**Base URL:** `https://api.hostinger.com`  
**Authentication:** API Key (Bearer Token)  
**Available Binaries:**
```bash
hostinger-api-mcp           # All 118 tools
hostinger-billing-mcp       # 7 billing tools
hostinger-dns-mcp           # 8 DNS tools
hostinger-domains-mcp       # 18 domain tools
hostinger-hosting-mcp       # 13 hosting tools
hostinger-reach-mcp         # 10 reach tools
hostinger-vps-mcp           # 62 VPS tools
```

### ChatGPT Integration

To use Hostinger API tools in ChatGPT:

1. **Create Custom Action** in ChatGPT settings
2. **Set Base URL:** `https://api.hostinger.com`
3. **Set Authentication:** Bearer Token (Hostinger API key)
4. **Configure timeout:** 30 seconds
5. **Rate limiting:** Follow Hostinger API limits

### Environment Setup

```bash
# Set Hostinger API token
export HOSTINGER_API_TOKEN="Bearer YOUR-HOSTINGER-API-KEY"

# Or in .claude/settings.json
{
  "env": {
    "HOSTINGER_API_TOKEN": "Bearer YOUR-KEY"
  }
}
```

## Using Both Connectors Together

### Example: Deploy Infrastructure

ChatGPT can now:

1. **Query current infrastructure** (via Hostinger API)
   ```
   "Show me all VPS instances and their current status"
   ```

2. **Create deployment scripts** (via sjl-mcp-filesystem)
   ```
   "Create a deployment script that updates all VPS instances"
   ```

3. **Document infrastructure** (via sjl-mcp-filesystem)
   ```
   "Generate infrastructure documentation and save to /home/user/.github/infrastructure/docs.md"
   ```

### Example: DNS Management

1. **Check current DNS records** (via Hostinger API)
   ```
   "List all DNS records for example.com"
   ```

2. **Update configuration** (via sjl-mcp-filesystem)
   ```
   "Create a DNS batch update script and save to /home/user/.github/infrastructure/dns-update.sh"
   ```

### Example: Infrastructure Monitoring

1. **Query VPS metrics** (via Hostinger API)
   ```
   "Get CPU and memory usage for all VPS instances"
   ```

2. **Create monitoring configuration** (via sjl-mcp-filesystem)
   ```
   "Create a monitoring configuration file with these thresholds and save to /var/lib/para-codes/monitoring-config.json"
   ```

## Security Considerations

### Token Isolation

Keep API tokens separate:
```json
{
  "env": {
    "HOSTINGER_API_TOKEN": "Bearer HOSTINGER-KEY",
    "SJL_MCP_TOKEN": "Bearer SJL-FILESYSTEM-KEY"
  }
}
```

### API Rate Limits

**Hostinger API:**
- Check Hostinger documentation for rate limits
- Implement exponential backoff for rate limit errors

**SJL MCP Filesystem:**
- 1000 requests/hour per token
- 10 concurrent requests max
- 30 second timeout

### File Access Control

When writing files via filesystem connector:
- Only write to whitelisted paths
- Automatic backups created before modifications
- All operations logged server-side
- Require confirmation for write operations

## Available Hostinger Tools

### Billing (7 tools)
- Get account balance
- List invoices
- Get invoice details
- Download invoice
- Update payment method
- Check billing status
- List billing history

### DNS (8 tools)
- List DNS records
- Create DNS record
- Update DNS record
- Delete DNS record
- Get DNS zone
- Export DNS records
- Import DNS records
- Check DNS propagation

### Domains (18 tools)
- List domains
- Get domain info
- Register domain
- Transfer domain
- Renew domain
- Update domain settings
- Enable/disable auto-renewal
- Get domain pricing
- Check domain availability
- And more...

### Hosting (13 tools)
- List hosting accounts
- Get account details
- Create hosting account
- Suspend/unsuspend account
- Update account settings
- Get disk usage
- List databases
- Create database
- And more...

### Reach (10 tools)
- Manage email accounts
- Get email statistics
- Configure forwarders
- Manage email settings
- Get email logs
- And more...

### VPS (62 tools)
- List VPS instances
- Get VPS details
- Create VPS
- Delete VPS
- Reboot VPS
- Get performance metrics
- Manage snapshots
- Manage backups
- Manage networking
- And many more...

## Usage Examples

### Example 1: Generate Deployment Report

```
User: "Generate a deployment report with:
1. Current VPS instance status from Hostinger
2. DNS records for all domains
3. Billing summary
4. Save as /home/user/.github/infrastructure/deployment-report.md"

ChatGPT will:
1. Call Hostinger API to get VPS status
2. Call Hostinger API to get DNS records
3. Call Hostinger API to get billing info
4. Call sjl-mcp-filesystem to write the report
```

### Example 2: Create DNS Update Script

```
User: "Create a bash script that updates DNS records:
- Change example.com A record from 192.168.1.1 to 10.0.0.1
- Update www CNAME
- Add new subdomain
Save to /home/user/.github/infrastructure/dns-update.sh"

ChatGPT will:
1. Query current DNS records via Hostinger API
2. Generate update script
3. Write script to filesystem via sjl-mcp-filesystem
4. Return confirmation with file path
```

### Example 3: VPS Management

```
User: "Get status of all VPS instances and create a monitoring script"

ChatGPT will:
1. List all VPS instances via Hostinger API
2. Get metrics for each instance
3. Generate monitoring script
4. Save to /var/lib/para-codes/vps-monitor.sh
5. Return summary and file paths
```

## Integration with CI/CD

The connectors enable GitOps-style infrastructure management:

1. **Query state** - Get current infrastructure via Hostinger API
2. **Generate configs** - Create deployment scripts
3. **Store configs** - Write to git-tracked directories via filesystem
4. **Trigger deployment** - Execute stored scripts manually or via CI/CD

## Performance Optimization

### Reduce API Calls

```
❌ Inefficient: Query VPS status 50 times
✅ Efficient: Query once, cache results in local file
```

### Batch Operations

```
❌ Inefficient: Create DNS records one by one
✅ Efficient: Create batch script, execute once
```

### Use Selective Tools

```
❌ Use hostinger-api-mcp (118 tools)
✅ Use hostinger-vps-mcp (62 tools) for VPS-only operations
```

## Troubleshooting

### "API Key Invalid" Error

**Solution:**
1. Verify Hostinger API key is correct
2. Check token starts with "Bearer "
3. Regenerate key if needed
4. Update in ChatGPT settings

### "Rate Limited" Error (Hostinger)

**Solution:**
1. Wait before retrying
2. Reduce request frequency
3. Use batch operations
4. Check Hostinger rate limits

### "Permission Denied" (Filesystem)

**Solution:**
1. Verify path is in write-enabled list
2. Check SJL_MCP_TOKEN is valid
3. Verify bearer token format

### "Connection Refused"

**Solution:**
1. Check if Hostinger API is accessible
2. Check if sjl-mcp-filesystem service is running
3. Verify network connectivity
4. Check firewall rules

## Best Practices

### DO

✅ Use selective binaries (hostinger-vps-mcp instead of hostinger-api-mcp)  
✅ Cache query results in local files  
✅ Generate scripts instead of executing directly  
✅ Require confirmation for infrastructure changes  
✅ Keep API keys secure  
✅ Log all operations  
✅ Review generated scripts before execution  

### DON'T

❌ Execute generated scripts automatically  
❌ Share API tokens  
❌ Write to system directories  
❌ Overwrite production configs without backup  
❌ Commit API keys to version control  
❌ Ignore rate limits  
❌ Skip verification steps  

## Documentation References

- **SJL MCP Filesystem:** See `.github/connectors/chatgpt/` directory
- **Hostinger API:** https://api.hostinger.com/docs
- **OpenAPI Schema:** See provided schema in this project
- **ChatGPT Setup:** See `.github/connectors/chatgpt/chatgpt-instructions.md`

## Support

For issues:
1. Verify both API tokens are correct
2. Check ChatGPT connector configuration
3. Review SJL MCP Filesystem documentation
4. Contact infrastructure team

---

**Last Updated:** July 10, 2026  
**Part of:** claude/chatgpt-connectors-write-access-agtyc7 branch
