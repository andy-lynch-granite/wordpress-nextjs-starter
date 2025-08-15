# Azure Resource Naming Convention Standard

## Overview

This document defines the comprehensive naming convention for all Azure resources in the WordPress + Next.js headless CMS project. The naming convention ensures consistency, clarity, and compliance with Azure limitations while supporting multi-environment deployments.

## Core Naming Strategy

### Base Pattern
```
[resource-type]-[project]-[component]-[environment]-[region]-[instance]
```

### Components
- **resource-type**: Azure resource type abbreviation
- **project**: Project identifier (wp-nextjs)
- **component**: Functional component (web, api, data, cdn, etc.)
- **environment**: Environment identifier (prod, staging, dev, preview)
- **region**: Azure region abbreviation (optional for global resources)
- **instance**: Instance number or identifier (optional)

## Resource Type Abbreviations

### Compute & Hosting
| Resource Type | Abbreviation | Example |
|--------------|-------------|----------|
| Resource Group | `rg` | `rg-wp-nextjs-web-prod-eus` |
| Storage Account | `st` | `stwpnextjswebprodeus01` |
| Container Apps Environment | `cae` | `cae-wp-nextjs-api-prod-eus` |
| Container App | `ca` | `ca-wp-nextjs-wordpress-prod-eus` |
| Static Web App | `stapp` | `stapp-wp-nextjs-preview-prod-eus` |
| App Service Plan | `asp` | `asp-wp-nextjs-api-prod-eus` |

### Networking
| Resource Type | Abbreviation | Example |
|--------------|-------------|----------|
| Virtual Network | `vnet` | `vnet-wp-nextjs-prod-eus` |
| Subnet | `snet` | `snet-wp-nextjs-containers-prod-eus` |
| Network Security Group | `nsg` | `nsg-wp-nextjs-containers-prod-eus` |
| Private Endpoint | `pe` | `pe-wp-nextjs-mysql-prod-eus` |
| Private DNS Zone | `pdz` | `pdz-wp-nextjs-mysql-prod-eus` |

### Data & Storage
| Resource Type | Abbreviation | Example |
|--------------|-------------|----------|
| MySQL Flexible Server | `mysql` | `mysql-wp-nextjs-prod-eus` |
| Redis Cache | `redis` | `redis-wp-nextjs-prod-eus` |
| Storage Account (Data) | `stdata` | `stdatawpnextjsprodeus01` |
| Blob Container | `blob` | `web`, `uploads`, `backups` |

### Security & Monitoring
| Resource Type | Abbreviation | Example |
|--------------|-------------|----------|
| Key Vault | `kv` | `kv-wp-nextjs-prod-eus` |
| Application Insights | `ai` | `ai-wp-nextjs-prod-eus` |
| Log Analytics Workspace | `law` | `law-wp-nextjs-prod-eus` |
| WAF Policy | `waf` | `waf-wp-nextjs-prod-eus` |

### CDN & Front Door
| Resource Type | Abbreviation | Example |
|--------------|-------------|----------|
| Front Door Profile | `fd` | `fd-wp-nextjs-prod` |
| Front Door Endpoint | `fde` | `fde-wp-nextjs-prod` |
| CDN Profile | `cdn` | `cdn-wp-nextjs-prod` |
| CDN Endpoint | `cdne` | `cdne-wp-nextjs-prod` |

## Environment-Specific Naming

### Production Environment
```yaml
Environment: prod
Resource Group: rg-wp-nextjs-web-prod-eus
Storage Account: stwpnextjswebprodeus01
Front Door: fd-wp-nextjs-prod
WordPress App: ca-wp-nextjs-wordpress-prod-eus
MySQL Server: mysql-wp-nextjs-prod-eus
```

### Staging Environment
```yaml
Environment: staging
Resource Group: rg-wp-nextjs-web-staging-eus
Storage Account: stwpnextjswebstagingeus01
Front Door: fd-wp-nextjs-staging
WordPress App: ca-wp-nextjs-wordpress-staging-eus
MySQL Server: mysql-wp-nextjs-staging-eus
```

### Development Environment
```yaml
Environment: dev
Resource Group: rg-wp-nextjs-web-dev-eus
Storage Account: stwpnextjswebdeveus01
Static Web App: stapp-wp-nextjs-dev-eus
WordPress App: ca-wp-nextjs-wordpress-dev-eus
```

### Preview Environment
```yaml
Environment: preview
Resource Group: rg-wp-nextjs-web-preview-eus
Static Web App: stapp-wp-nextjs-preview-eus
# Note: Preview uses shared staging backend
```