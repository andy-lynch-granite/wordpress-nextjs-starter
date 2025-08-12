# Azure Setup Guide

This guide provides step-by-step instructions for setting up the complete Azure infrastructure for the headless WordPress + Next.js solution.

## Prerequisites

### Required Tools
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) v2.40+
- [Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps) (optional)
- [Terraform](https://terraform.io/downloads.html) v1.3+ (if using Terraform)
- [Git](https://git-scm.com/downloads)

### Azure Account Requirements
- Active Azure subscription with sufficient quotas
- Contributor or Owner role on the subscription
- Resource group creation permissions

## Architecture Overview

The solution deploys the following Azure services:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Azure CDN     │───▶│  Static Web Apps │───▶│   Next.js App   │
│   (Frontend)    │    │   (Frontend)     │    │   (Frontend)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Application    │───▶│  Container       │───▶│   WordPress     │
│  Gateway + WAF  │    │  Instances       │    │   Backend       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Azure Cache   │    │   MySQL          │    │   Azure Key     │
│   for Redis     │    │   Flexible       │    │   Vault         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Step 1: Initial Azure Setup

### 1.1 Login and Set Subscription

```bash
# Login to Azure
az login

# List available subscriptions
az account list --output table

# Set the subscription
az account set --subscription "<your-subscription-id>"

# Verify current subscription
az account show
```

### 1.2 Create Resource Group

```bash
# Set variables
export RESOURCE_GROUP="rg-wordpress-nextjs-prod"
export LOCATION="East US"
export PROJECT_NAME="wordpress-nextjs"
export ENVIRONMENT="prod"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location "$LOCATION" \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT
```

### 1.3 Register Required Resource Providers

```bash
# Register required providers
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.ContainerInstance
az provider register --namespace Microsoft.DBforMySQL
az provider register --namespace Microsoft.Cache
az provider register --namespace Microsoft.Cdn
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.Network

# Verify registration status
az provider list --query "[?namespace=='Microsoft.Web'].registrationState" -o table
```

## Step 2: Core Infrastructure Services

### 2.1 Azure Key Vault

```bash
export KEY_VAULT_NAME="kv-${PROJECT_NAME}-${ENVIRONMENT}-$(date +%s | tail -c 5)"

# Create Key Vault
az keyvault create \
  --name $KEY_VAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --sku standard \
  --enable-rbac-authorization true \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Store Key Vault name for later use
echo "KEY_VAULT_NAME=$KEY_VAULT_NAME" >> .env.azure
```

### 2.2 Virtual Network

```bash
export VNET_NAME="vnet-${PROJECT_NAME}-${ENVIRONMENT}"
export SUBNET_WP_NAME="subnet-wordpress"
export SUBNET_DB_NAME="subnet-database"
export SUBNET_REDIS_NAME="subnet-redis"

# Create Virtual Network
az network vnet create \
  --name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --address-prefix 10.0.0.0/16 \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Create WordPress subnet
az network vnet subnet create \
  --name $SUBNET_WP_NAME \
  --vnet-name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --address-prefix 10.0.1.0/24

# Create database subnet (with delegation)
az network vnet subnet create \
  --name $SUBNET_DB_NAME \
  --vnet-name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --address-prefix 10.0.2.0/24 \
  --delegations Microsoft.DBforMySQL/flexibleServers

# Create Redis subnet
az network vnet subnet create \
  --name $SUBNET_REDIS_NAME \
  --vnet-name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --address-prefix 10.0.3.0/24
```

### 2.3 Network Security Groups

```bash
export NSG_WP_NAME="nsg-wordpress-${ENVIRONMENT}"
export NSG_DB_NAME="nsg-database-${ENVIRONMENT}"

# Create WordPress NSG
az network nsg create \
  --name $NSG_WP_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# WordPress NSG rules
az network nsg rule create \
  --nsg-name $NSG_WP_NAME \
  --resource-group $RESOURCE_GROUP \
  --name AllowHTTP \
  --priority 100 \
  --protocol Tcp \
  --destination-port-ranges 80 \
  --access Allow

az network nsg rule create \
  --nsg-name $NSG_WP_NAME \
  --resource-group $RESOURCE_GROUP \
  --name AllowHTTPS \
  --priority 110 \
  --protocol Tcp \
  --destination-port-ranges 443 \
  --access Allow

# Create Database NSG
az network nsg create \
  --name $NSG_DB_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Database NSG rule (only allow from WordPress subnet)
az network nsg rule create \
  --nsg-name $NSG_DB_NAME \
  --resource-group $RESOURCE_GROUP \
  --name AllowMySQL \
  --priority 100 \
  --protocol Tcp \
  --source-address-prefixes 10.0.1.0/24 \
  --destination-port-ranges 3306 \
  --access Allow

# Associate NSGs with subnets
az network vnet subnet update \
  --name $SUBNET_WP_NAME \
  --vnet-name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --network-security-group $NSG_WP_NAME

az network vnet subnet update \
  --name $SUBNET_DB_NAME \
  --vnet-name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --network-security-group $NSG_DB_NAME
```

## Step 3: Database Setup

### 3.1 MySQL Flexible Server

```bash
export MYSQL_SERVER_NAME="mysql-${PROJECT_NAME}-${ENVIRONMENT}"
export MYSQL_ADMIN_USER="wpadmin"
export MYSQL_ADMIN_PASSWORD=$(openssl rand -base64 32)
export MYSQL_DATABASE="wordpress"

# Store credentials in Key Vault
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "mysql-admin-username" \
  --value $MYSQL_ADMIN_USER

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "mysql-admin-password" \
  --value "$MYSQL_ADMIN_PASSWORD"

# Create MySQL Flexible Server
az mysql flexible-server create \
  --name $MYSQL_SERVER_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --admin-user $MYSQL_ADMIN_USER \
  --admin-password "$MYSQL_ADMIN_PASSWORD" \
  --sku-name Standard_B2s \
  --tier Burstable \
  --storage-size 20 \
  --storage-auto-grow Enabled \
  --backup-retention 7 \
  --geo-redundant-backup Disabled \
  --vnet $VNET_NAME \
  --subnet $SUBNET_DB_NAME \
  --private-dns-zone ${MYSQL_SERVER_NAME}.private.mysql.database.azure.com \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Create WordPress database
az mysql flexible-server db create \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --database-name $MYSQL_DATABASE

# Configure server parameters for WordPress
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name innodb_buffer_pool_size \
  --value 134217728

az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name $MYSQL_SERVER_NAME \
  --name max_allowed_packet \
  --value 67108864
```

### 3.2 Redis Cache

```bash
export REDIS_CACHE_NAME="redis-${PROJECT_NAME}-${ENVIRONMENT}"

# Create Redis Cache
az redis create \
  --name $REDIS_CACHE_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --sku Basic \
  --vm-size c0 \
  --redis-version 6 \
  --minimum-tls-version 1.2 \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Get Redis connection string and store in Key Vault
export REDIS_PRIMARY_KEY=$(az redis list-keys \
  --name $REDIS_CACHE_NAME \
  --resource-group $RESOURCE_GROUP \
  --query primaryKey -o tsv)

export REDIS_HOSTNAME=$(az redis show \
  --name $REDIS_CACHE_NAME \
  --resource-group $RESOURCE_GROUP \
  --query hostName -o tsv)

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "redis-connection-string" \
  --value "$REDIS_HOSTNAME:6380,password=$REDIS_PRIMARY_KEY,ssl=True,abortConnect=False"
```

## Step 4: Container Infrastructure

### 4.1 Container Registry (Optional)

```bash
export ACR_NAME="acr${PROJECT_NAME}${ENVIRONMENT}$(date +%s | tail -c 5)"

# Create Azure Container Registry
az acr create \
  --name $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --sku Basic \
  --admin-enabled true \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Get ACR credentials
export ACR_USERNAME=$(az acr credential show \
  --name $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --query username -o tsv)

export ACR_PASSWORD=$(az acr credential show \
  --name $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --query passwords[0].value -o tsv)

# Store ACR credentials in Key Vault
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "acr-username" \
  --value $ACR_USERNAME

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "acr-password" \
  --value "$ACR_PASSWORD"
```

## Step 5: Static Web App (Frontend)

### 5.1 Create Static Web App

```bash
export STATICWEB_NAME="stapp-${PROJECT_NAME}-${ENVIRONMENT}"
export GITHUB_REPO="https://github.com/andy-lynch-granite/wordpress-nextjs-starter"

# Create Static Web App (requires GitHub token)
az staticwebapp create \
  --name $STATICWEB_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "East US 2" \
  --source $GITHUB_REPO \
  --branch main \
  --app-location "/frontend" \
  --api-location "" \
  --output-location "out" \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT
```

## Step 6: Application Insights & Monitoring

### 6.1 Log Analytics Workspace

```bash
export LOG_ANALYTICS_NAME="log-${PROJECT_NAME}-${ENVIRONMENT}"

# Create Log Analytics Workspace
az monitor log-analytics workspace create \
  --workspace-name $LOG_ANALYTICS_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --sku PerGB2018 \
  --retention-time 30 \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Get workspace ID and key
export WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --workspace-name $LOG_ANALYTICS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query customerId -o tsv)

export WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --workspace-name $LOG_ANALYTICS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query primarySharedKey -o tsv)
```

### 6.2 Application Insights

```bash
export APP_INSIGHTS_NAME="appi-${PROJECT_NAME}-${ENVIRONMENT}"

# Create Application Insights
az monitor app-insights component create \
  --app $APP_INSIGHTS_NAME \
  --location "$LOCATION" \
  --resource-group $RESOURCE_GROUP \
  --workspace $LOG_ANALYTICS_NAME \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Get instrumentation key
export INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query instrumentationKey -o tsv)

# Store in Key Vault
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "app-insights-key" \
  --value "$INSTRUMENTATION_KEY"
```

## Step 7: Environment Variables Summary

Create a complete environment variables file:

```bash
cat > .env.azure << EOF
# Azure Configuration
RESOURCE_GROUP=$RESOURCE_GROUP
LOCATION="$LOCATION"
PROJECT_NAME=$PROJECT_NAME
ENVIRONMENT=$ENVIRONMENT

# Key Vault
KEY_VAULT_NAME=$KEY_VAULT_NAME

# Network
VNET_NAME=$VNET_NAME
SUBNET_WP_NAME=$SUBNET_WP_NAME
SUBNET_DB_NAME=$SUBNET_DB_NAME
SUBNET_REDIS_NAME=$SUBNET_REDIS_NAME

# Database
MYSQL_SERVER_NAME=$MYSQL_SERVER_NAME
MYSQL_DATABASE=$MYSQL_DATABASE

# Redis
REDIS_CACHE_NAME=$REDIS_CACHE_NAME

# Container Registry
ACR_NAME=$ACR_NAME

# Static Web App
STATICWEB_NAME=$STATICWEB_NAME

# Monitoring
LOG_ANALYTICS_NAME=$LOG_ANALYTICS_NAME
APP_INSIGHTS_NAME=$APP_INSIGHTS_NAME
EOF

echo "Azure setup completed successfully!"
echo "Configuration saved to .env.azure"
echo "Next steps: Proceed with webapp-deployment.md"
```

## Security Checklist

- [ ] Key Vault created with RBAC authorization
- [ ] Network Security Groups configured
- [ ] Database in private subnet with delegation
- [ ] Redis cache with TLS 1.2 minimum
- [ ] All secrets stored in Key Vault
- [ ] Resource tagging applied consistently
- [ ] Backup retention configured for database

## Cost Optimization Notes

1. **Database**: Start with Burstable tier, scale up as needed
2. **Redis**: Use Basic tier for development, Standard for production
3. **Container Registry**: Basic tier sufficient for small teams
4. **Static Web App**: Free tier available for small projects
5. **Application Insights**: Monitor data ingestion to control costs

## Troubleshooting

### Common Issues

1. **Resource Provider Not Registered**
   ```bash
   az provider register --namespace Microsoft.Web
   ```

2. **Insufficient Permissions**
   - Verify Contributor role on subscription
   - Check resource group permissions

3. **Naming Conflicts**
   - Add unique suffix to resource names
   - Check name availability before creation

4. **Quota Limits**
   ```bash
   az vm list-usage --location "East US" -o table
   ```

### Validation Commands

```bash
# Verify all resources created
az resource list --resource-group $RESOURCE_GROUP --output table

# Check Key Vault secrets
az keyvault secret list --vault-name $KEY_VAULT_NAME --output table

# Test database connectivity
az mysql flexible-server show --name $MYSQL_SERVER_NAME --resource-group $RESOURCE_GROUP

# Verify Redis cache
az redis show --name $REDIS_CACHE_NAME --resource-group $RESOURCE_GROUP
```

## Next Steps

1. Continue with [WebApp Deployment Guide](./webapp-deployment.md)
2. Set up [Database Configuration](./database-setup.md)
3. Configure [CDN and Static Assets](./cdn-configuration.md)
4. Implement [DNS and SSL Setup](./dns-ssl-setup.md)
5. Configure [Auto-scaling](./scaling-configuration.md)
