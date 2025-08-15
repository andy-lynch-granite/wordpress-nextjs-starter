# Azure Infrastructure Deployment Guide

This guide provides step-by-step instructions for deploying the complete WordPress + Next.js infrastructure to Azure.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Detailed Deployment Steps](#detailed-deployment-steps)
4. [Environment Configuration](#environment-configuration)
5. [DNS Configuration](#dns-configuration)
6. [Validation and Testing](#validation-and-testing)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance](#maintenance)

## Prerequisites

### Required Tools

- **Azure CLI** (latest version)
- **Node.js** 18+ (for frontend builds)
- **Docker** (for backend container builds)
- **Git** (for repository management)
- **jq** (for JSON processing)
- **curl** (for API testing)

### Azure Requirements

- Azure subscription with Contributor access
- Sufficient quota for:
  - Storage accounts
  - Container Apps
  - MySQL Flexible Server
  - Redis Cache
  - Front Door profiles
  - Virtual networks

### Domain Requirements

- Custom domain name (optional but recommended)
- Access to DNS management for domain configuration

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/your-org/wordpress-nextjs-starter.git
cd wordpress-nextjs-starter
```

### 2. Login to Azure

```bash
az login
az account set --subscription "Your Subscription Name"
```

### 3. Deploy Infrastructure

```bash
cd infrastructure/scripts
chmod +x *.sh

# Deploy to development environment
./deploy-infrastructure.sh dev eastus your-domain.com

# Deploy to staging environment
./deploy-infrastructure.sh staging eastus your-domain.com

# Deploy to production environment
./deploy-infrastructure.sh prod eastus your-domain.com
```

### 4. Configure Environments

```bash
# Set up all environments and GitHub integration
./setup-environments.sh your-domain.com your-org/wordpress-nextjs-starter
```

### 5. Configure DNS

```bash
# Configure DNS for production
./configure-dns.sh your-domain.com prod

# Configure DNS for staging
./configure-dns.sh your-domain.com staging
```

### 6. Validate Deployment

```bash
# Validate production deployment
./validate-deployment.sh prod your-domain.com

# Validate staging deployment
./validate-deployment.sh staging your-domain.com
```

## Detailed Deployment Steps

### Step 1: Environment Preparation

#### 1.1 Verify Prerequisites

```bash
# Check Azure CLI
az version

# Check subscription access
az account show

# Check resource provider registrations
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Cdn
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.DBforMySQL
az provider register --namespace Microsoft.Cache
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Insights
```

#### 1.2 Choose Deployment Parameters

| Parameter | Development | Staging | Production |
|-----------|-------------|---------|------------|
| Environment | `dev` | `staging` | `prod` |
| Location | `eastus` | `eastus` | `eastus` |
| Backend | `true` | `true` | `true` |
| Monitoring | `false` | `true` | `true` |
| Domain | `dev.yourdomain.com` | `staging.yourdomain.com` | `yourdomain.com` |

### Step 2: Infrastructure Deployment

#### 2.1 Deploy Core Infrastructure

```bash
# Navigate to scripts directory
cd infrastructure/scripts

# Make scripts executable
chmod +x *.sh

# Deploy infrastructure (replace parameters as needed)
ENVIRONMENT="prod"          # dev, staging, prod
LOCATION="eastus"           # Azure region
DOMAIN="yourdomain.com"     # Your domain name
BACKEND="true"              # Deploy WordPress backend
MONITORING="true"           # Enable monitoring

./deploy-infrastructure.sh $ENVIRONMENT $LOCATION $DOMAIN $BACKEND $MONITORING
```

#### 2.2 Monitor Deployment Progress

The deployment script will:
1. Create resource group
2. Generate secure passwords
3. Deploy Bicep templates
4. Configure services
5. Output deployment summary

**Expected deployment time**: 15-25 minutes

#### 2.3 Verify Deployment Outputs

After successful deployment, you'll see:

```
========================================
       DEPLOYMENT SUMMARY
========================================
Environment: prod
Resource Group: wordpress-nextjs-prod-rg
Location: eastus

STATIC HOSTING:
  Storage Account: wordpressnextjsprodstatic
  Static Website URL: https://wordpressnextjsprodstatic.z13.web.core.windows.net/
  Front Door CDN URL: https://wordpress-nextjs-prod-fd-endpoint-xxx.azurefd.net/

WORDPRESS BACKEND:
  WordPress URL: https://wordpress-nextjs-prod-wordpress.xxx.eastus.azurecontainerapps.io/
  MySQL Server: wordpress-nextjs-prod-mysql.mysql.database.azure.com
  Redis Host: wordpress-nextjs-prod-redis.redis.cache.windows.net

SECURITY:
  Key Vault: wordpress-nextjs-prod-kv
========================================
```

### Step 3: Environment Configuration

#### 3.1 Set Up GitHub Integration

```bash
# Configure environments and create service principal
./setup-environments.sh yourdomain.com your-org/wordpress-nextjs-starter
```

This script will:
1. Create Azure service principal for GitHub Actions
2. Configure static website hosting
3. Generate GitHub environment configurations
4. Create environment variables file
5. Generate DNS configuration guide

#### 3.2 Configure GitHub Secrets

Add the following secrets to your GitHub repository:

**Azure Credentials**:
```
AZURE_CREDENTIALS={"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}
```

**Environment-specific secrets** (for each environment):
```
# Production
PROD_RESOURCE_GROUP=wordpress-nextjs-prod-rg
PROD_STORAGE_ACCOUNT=wordpressnextjsprodstatic
PROD_FRONT_DOOR_PROFILE=wordpress-nextjs-prod-fd
PROD_FRONT_DOOR_ENDPOINT=wordpress-nextjs-prod-fd-endpoint
PROD_WORDPRESS_URL=https://wordpress-nextjs-prod-wordpress.xxx.azurecontainerapps.io
PROD_DOMAIN_NAME=yourdomain.com

# Staging
STAGING_RESOURCE_GROUP=wordpress-nextjs-staging-rg
STAGING_STORAGE_ACCOUNT=wordpressnextjsstagingstatic
# ... etc

# Development
DEV_RESOURCE_GROUP=wordpress-nextjs-dev-rg
DEV_STORAGE_ACCOUNT=wordpressnextjsdevstatic
# ... etc
```

**Common secrets**:
```
DOMAIN_NAME=yourdomain.com
```

### Step 4: DNS Configuration

#### 4.1 Configure DNS Records

```bash
# Configure DNS for each environment
./configure-dns.sh yourdomain.com prod
./configure-dns.sh yourdomain.com staging
./configure-dns.sh yourdomain.com dev
```

#### 4.2 Manual DNS Configuration

If automatic DNS configuration fails, manually add these records:

**Production**:
```
yourdomain.com          CNAME   wordpress-nextjs-prod-fd-endpoint-xxx.azurefd.net
www.yourdomain.com      CNAME   wordpress-nextjs-prod-fd-endpoint-xxx.azurefd.net
```

**Staging**:
```
staging.yourdomain.com  CNAME   wordpress-nextjs-staging-fd-endpoint-xxx.azurefd.net
```

**Development**:
```
dev.yourdomain.com      CNAME   wordpress-nextjs-dev-fd-endpoint-xxx.azurefd.net
```

#### 4.3 Wait for DNS Propagation

DNS propagation can take up to 48 hours. Check status:

```bash
# Check DNS propagation
nslookup yourdomain.com
dig yourdomain.com

# Online tools
# https://www.whatsmydns.net/
# https://dnschecker.org/
```

### Step 5: Application Deployment

#### 5.1 Deploy Frontend (Automatic via GitHub Actions)

Once GitHub is configured, frontend deploys automatically on:
- Push to `main` branch (staging environment)
- Manual workflow dispatch (any environment)

#### 5.2 Deploy Backend (Automatic via GitHub Actions)

WordPress backend deploys automatically on:
- Push to `main` branch with backend changes
- Manual workflow dispatch

#### 5.3 Manual Frontend Deployment

If needed, deploy frontend manually:

```bash
cd frontend

# Install dependencies
npm ci

# Build for production
NEXT_PUBLIC_WORDPRESS_API_URL="https://your-wordpress-url/graphql" \
NEXT_PUBLIC_SITE_URL="https://yourdomain.com" \
npm run build && npm run export

# Deploy to Azure Storage
az storage blob upload-batch \
  --account-name "your-storage-account" \
  --destination '$web' \
  --source out \
  --overwrite

# Purge CDN cache
az cdn afd endpoint purge \
  --resource-group "your-resource-group" \
  --profile-name "your-front-door-profile" \
  --endpoint-name "your-front-door-endpoint" \
  --content-paths "/*"
```

## Environment Configuration

### Development Environment

**Purpose**: Feature development and testing

**Configuration**:
- Minimal resources (cost optimization)
- No monitoring (basic logs only)
- Development domain (`dev.yourdomain.com`)
- Relaxed security policies

**Resource Sizes**:
- MySQL: `Standard_B1ms` (Burstable)
- Redis: `Basic C0`
- Container Apps: 0.5 CPU, 1GB RAM

### Staging Environment

**Purpose**: Pre-production testing and QA

**Configuration**:
- Production-like resources
- Full monitoring enabled
- Staging domain (`staging.yourdomain.com`)
- Production security policies

**Resource Sizes**:
- MySQL: `Standard_B2s` (Burstable)
- Redis: `Standard C1`
- Container Apps: 1 CPU, 2GB RAM

### Production Environment

**Purpose**: Live production workloads

**Configuration**:
- High availability and performance
- Comprehensive monitoring and alerting
- Primary domain (`yourdomain.com`)
- Strict security policies
- Auto-scaling enabled

**Resource Sizes**:
- MySQL: `Standard_D2ds_v4` (General Purpose)
- Redis: `Premium P1`
- Container Apps: 2 CPU, 4GB RAM (auto-scale to 20)

## Validation and Testing

### Step 1: Infrastructure Validation

```bash
# Run comprehensive validation
./validate-deployment.sh prod yourdomain.com
```

This validates:
- ✅ Resource group and resources exist
- ✅ Static website hosting enabled
- ✅ Front Door CDN accessible
- ✅ WordPress backend running
- ✅ Database connectivity
- ✅ Redis cache accessible
- ✅ SSL certificates valid
- ✅ Security configurations
- ✅ Performance metrics

### Step 2: Application Testing

#### Frontend Testing

```bash
# Test static site
curl -I https://yourdomain.com

# Test key pages
curl -I https://yourdomain.com/robots.txt
curl -I https://yourdomain.com/sitemap.xml

# Test performance
curl -w "Time: %{time_total}s\n" -o /dev/null -s https://yourdomain.com
```

#### Backend Testing

```bash
# Test WordPress installation
curl -I https://your-wordpress-url/wp-admin/install.php

# Test GraphQL endpoint
curl -I https://your-wordpress-url/graphql

# Test REST API
curl -I https://your-wordpress-url/wp-json/wp/v2
```

### Step 3: Performance Testing

#### Core Web Vitals

```bash
# Use Lighthouse CLI
npm install -g lighthouse
lighthouse https://yourdomain.com --output html --output-path ./lighthouse-report.html

# Or use online tools:
# https://pagespeed.web.dev/
# https://gtmetrix.com/
```

#### Load Testing

```bash
# Simple load test with curl
for i in {1..100}; do
  curl -s -o /dev/null -w "Response: %{http_code}, Time: %{time_total}s\n" https://yourdomain.com &
done
wait
```

## Troubleshooting

### Common Issues

#### 1. Deployment Fails

**Symptoms**: Bicep template deployment errors

**Solutions**:
```bash
# Check Azure CLI version
az version

# Update if needed
az upgrade

# Check subscription limits
az vm list-usage --location eastus

# Verify resource provider registrations
az provider show --namespace Microsoft.Storage --query registrationState
```

#### 2. DNS Issues

**Symptoms**: Domain not resolving or SSL certificate errors

**Solutions**:
```bash
# Check DNS propagation
nslookup yourdomain.com

# Verify CNAME records
dig yourdomain.com CNAME

# Check Azure Front Door custom domain status
az cdn afd custom-domain show \
  --resource-group "your-rg" \
  --profile-name "your-profile" \
  --custom-domain-name "your-domain"
```

#### 3. WordPress Backend Issues

**Symptoms**: WordPress not accessible or database connection errors

**Solutions**:
```bash
# Check Container App status
az containerapp show \
  --name "your-container-app" \
  --resource-group "your-rg" \
  --query properties.runningStatus

# Check Container App logs
az containerapp logs show \
  --name "your-container-app" \
  --resource-group "your-rg" \
  --follow

# Check MySQL server status
az mysql flexible-server show \
  --name "your-mysql-server" \
  --resource-group "your-rg" \
  --query state
```

#### 4. Frontend Deployment Issues

**Symptoms**: Static files not updating or 404 errors

**Solutions**:
```bash
# Check storage account static website settings
az storage blob service-properties show \
  --account-name "your-storage-account"

# Manually purge CDN cache
az cdn afd endpoint purge \
  --resource-group "your-rg" \
  --profile-name "your-profile" \
  --endpoint-name "your-endpoint" \
  --content-paths "/*"

# Check file upload status
az storage blob list \
  --account-name "your-storage-account" \
  --container-name '$web' \
  --output table
```

### Getting Help

1. **Check Azure Activity Log**: Review deployment operations in Azure Portal
2. **Enable Debug Logging**: Add `--debug` flag to Azure CLI commands
3. **Review GitHub Actions**: Check workflow run logs for CI/CD issues
4. **Azure Support**: Open support ticket for Azure-specific issues

## Maintenance

### Regular Tasks

#### 1. Monitor Costs

```bash
# Check current costs
az consumption usage list \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --query "[?contains(instanceName, 'wordpress-nextjs')]"

# Set up budget alerts in Azure Portal
```

#### 2. Update Dependencies

```bash
# Update Bicep CLI
az bicep upgrade

# Update Azure CLI
az upgrade

# Update Node.js dependencies
cd frontend && npm update
```

#### 3. Security Updates

```bash
# Rotate Key Vault secrets (quarterly)
# Update WordPress core and plugins
# Review Azure Security Center recommendations
# Update container images
```

#### 4. Performance Monitoring

```bash
# Check Application Insights metrics
az monitor metrics list \
  --resource "your-app-insights-resource" \
  --metric requests/count

# Review Front Door analytics
# Monitor WordPress backend performance
```

#### 5. Backup Verification

```bash
# Verify MySQL backups
az mysql flexible-server backup list \
  --resource-group "your-rg" \
  --server-name "your-mysql-server"

# Test backup restoration (in dev environment)
```

### Scaling Operations

#### Scale Up/Down Resources

```bash
# Scale MySQL server
az mysql flexible-server update \
  --resource-group "your-rg" \
  --name "your-mysql-server" \
  --sku-name Standard_D4ds_v4

# Scale Redis cache
az redis update \
  --resource-group "your-rg" \
  --name "your-redis" \
  --sku Standard \
  --vm-size C2

# Update Container App scaling rules
az containerapp update \
  --name "your-container-app" \
  --resource-group "your-rg" \
  --min-replicas 2 \
  --max-replicas 50
```

### Disaster Recovery

#### 1. Backup Strategy

- **Database**: Automated daily backups (7-day retention)
- **Files**: Static files stored in geo-redundant storage
- **Configuration**: Infrastructure as Code in Git
- **Secrets**: Key Vault with soft delete enabled

#### 2. Recovery Procedures

```bash
# Restore from backup
az mysql flexible-server restore \
  --resource-group "your-rg" \
  --name "your-mysql-server-restored" \
  --source-server "your-mysql-server" \
  --restore-time "2024-01-15T10:00:00Z"

# Redeploy infrastructure
./deploy-infrastructure.sh prod eastus yourdomain.com

# Redeploy applications
# Trigger GitHub Actions workflows
```

## Next Steps

After successful deployment:

1. **Configure WordPress**: Access WordPress admin and complete setup
2. **Install Plugins**: Add required WordPress plugins for headless operation
3. **Content Migration**: Import existing content if migrating from another site
4. **SEO Configuration**: Set up meta tags, sitemaps, and analytics
5. **Performance Optimization**: Configure caching and CDN settings
6. **Security Hardening**: Implement additional security measures
7. **Monitoring Setup**: Configure alerts and notifications
8. **Documentation**: Document your specific configuration and customizations

---

**Need Help?** 

- 📧 Email: support@yourorganization.com
- 📚 Documentation: https://github.com/your-org/wordpress-nextjs-starter/wiki
- 🐛 Issues: https://github.com/your-org/wordpress-nextjs-starter/issues
