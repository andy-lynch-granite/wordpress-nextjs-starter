#!/bin/bash
# Azure Infrastructure Deployment Script
# Deploys complete WordPress + Next.js infrastructure to Azure

set -e

# Configuration
PROJECT_NAME="wordpress-nextjs"
ENVIRONMENT="${1:-dev}"  # dev, staging, prod
RESOURCE_GROUP="${PROJECT_NAME}-${ENVIRONMENT}-rg"
LOCATION="${2:-eastus}"
DOMAIN_NAME="${3:-example.com}"
DEPLOY_BACKEND="${4:-true}"
ENABLE_MONITORING="${5:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Validate inputs
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    error "Environment must be one of: dev, staging, prod"
fi

if [[ ! "$LOCATION" =~ ^[a-z0-9]+$ ]]; then
    error "Invalid Azure location: $LOCATION"
fi

log "Starting Azure infrastructure deployment..."
log "Project: $PROJECT_NAME"
log "Environment: $ENVIRONMENT"
log "Resource Group: $RESOURCE_GROUP"
log "Location: $LOCATION"
log "Domain: $DOMAIN_NAME"
log "Deploy Backend: $DEPLOY_BACKEND"
log "Enable Monitoring: $ENABLE_MONITORING"

# Check Azure CLI
if ! command -v az &> /dev/null; then
    error "Azure CLI is not installed. Please install it first."
fi

# Check if logged in
if ! az account show &> /dev/null; then
    error "Not logged in to Azure. Run 'az login' first."
fi

log "Checking Azure subscription..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
log "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Create resource group
log "Creating resource group: $RESOURCE_GROUP"
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags Environment="$ENVIRONMENT" Project="$PROJECT_NAME" ManagedBy="Script"

success "Resource group created successfully"

# Generate secure passwords
log "Generating secure passwords..."
MYSQL_PASSWORD=$(openssl rand -base64 32 | tr -d "/+=" | cut -c1-25)
WORDPRESS_DB_PASSWORD=$(openssl rand -base64 32 | tr -d "/+=" | cut -c1-25)

# Deploy infrastructure
log "Deploying infrastructure using Bicep templates..."

DEPLOYMENT_NAME="${PROJECT_NAME}-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "../bicep/main.bicep" \
    --name "$DEPLOYMENT_NAME" \
    --parameters \
        environment="$ENVIRONMENT" \
        projectName="$PROJECT_NAME" \
        location="$LOCATION" \
        domainName="$DOMAIN_NAME" \
        deployWordPressBackend="$DEPLOY_BACKEND" \
        enableMonitoring="$ENABLE_MONITORING" \
        mysqlAdminPassword="$MYSQL_PASSWORD" \
        wordpressDbPassword="$WORDPRESS_DB_PASSWORD" \
    --output table

if [ $? -eq 0 ]; then
    success "Infrastructure deployment completed successfully"
else
    error "Infrastructure deployment failed"
fi

# Get deployment outputs
log "Retrieving deployment outputs..."

STATIC_URL=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.staticWebsiteUrl.value -o tsv)

FRONT_DOOR_URL=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.frontDoorEndpoint.value -o tsv)

STORAGE_ACCOUNT=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.storageAccountName.value -o tsv)

KEY_VAULT=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.keyVaultName.value -o tsv)

if [ "$DEPLOY_BACKEND" = "true" ]; then
    WORDPRESS_URL=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.wordpressBackendUrl.value -o tsv)
    
    MYSQL_SERVER=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.mysqlServerName.value -o tsv)
    
    REDIS_HOST=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.redisHostname.value -o tsv)
fi

if [ "$ENABLE_MONITORING" = "true" ]; then
    APP_INSIGHTS_KEY=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$DEPLOYMENT_NAME" \
        --query properties.outputs.applicationInsightsInstrumentationKey.value -o tsv)
fi

# Output summary
echo ""
echo "========================================"
echo "       DEPLOYMENT SUMMARY"
echo "========================================"
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo ""
echo "STATIC HOSTING:"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo "  Static Website URL: $STATIC_URL"
echo "  Front Door CDN URL: $FRONT_DOOR_URL"
echo ""
if [ "$DEPLOY_BACKEND" = "true" ]; then
    echo "WORDPRESS BACKEND:"
    echo "  WordPress URL: $WORDPRESS_URL"
    echo "  MySQL Server: $MYSQL_SERVER"
    echo "  Redis Host: $REDIS_HOST"
    echo ""
fi
if [ "$ENABLE_MONITORING" = "true" ]; then
    echo "MONITORING:"
    echo "  Application Insights Key: $APP_INSIGHTS_KEY"
    echo ""
fi
echo "SECURITY:"
echo "  Key Vault: $KEY_VAULT"
echo ""
echo "NEXT STEPS:"
echo "1. Configure DNS records for your domain"
echo "2. Upload your static files to: $STORAGE_ACCOUNT"
echo "3. Set up GitHub Actions with the service principal"
if [ "$DEPLOY_BACKEND" = "true" ]; then
    echo "4. Configure WordPress at: $WORDPRESS_URL"
fi
echo "========================================"

success "Deployment completed successfully!"

# Save deployment info to file
DEPLOYMENT_INFO_FILE="deployment-info-${ENVIRONMENT}.json"
cat > "$DEPLOYMENT_INFO_FILE" << EOF
{
  "environment": "$ENVIRONMENT",
  "resourceGroup": "$RESOURCE_GROUP",
  "location": "$LOCATION",
  "deploymentName": "$DEPLOYMENT_NAME",
  "storageAccount": "$STORAGE_ACCOUNT",
  "staticWebsiteUrl": "$STATIC_URL",
  "frontDoorUrl": "$FRONT_DOOR_URL",
  "keyVault": "$KEY_VAULT",
  "wordpressUrl": "${WORDPRESS_URL:-}",
  "mysqlServer": "${MYSQL_SERVER:-}",
  "redisHost": "${REDIS_HOST:-}",
  "applicationInsightsKey": "${APP_INSIGHTS_KEY:-}",
  "deployedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

log "Deployment information saved to: $DEPLOYMENT_INFO_FILE"
