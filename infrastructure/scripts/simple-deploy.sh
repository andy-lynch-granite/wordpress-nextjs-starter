#!/bin/bash
# Simple Azure deployment script for WordPress + Next.js starter

set -e

# Configuration
PROJECT_NAME="wordpressnextjs"
ENVIRONMENT="${1:-dev}"
LOCATION="${2:-northeurope}"
RESOURCE_GROUP="${PROJECT_NAME}-${ENVIRONMENT}-rg"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log "Starting simple Azure deployment..."
log "Environment: $ENVIRONMENT"
log "Location: $LOCATION"
log "Resource Group: $RESOURCE_GROUP"

# Create resource group
log "Creating resource group..."
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags Environment="$ENVIRONMENT" Project="wordpress-nextjs" ManagedBy="SimpleScript"

# Create storage account for static hosting
STORAGE_ACCOUNT="${PROJECT_NAME}${ENVIRONMENT}static"
log "Creating storage account: $STORAGE_ACCOUNT"

az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --access-tier Hot \
    --tags Environment="$ENVIRONMENT" Project="wordpress-nextjs"

# Enable static website hosting
log "Enabling static website hosting..."
az storage blob service-properties update \
    --account-name "$STORAGE_ACCOUNT" \
    --static-website \
    --index-document index.html \
    --404-document 404.html

# Get static website URL
STATIC_URL=$(az storage account show \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --query "primaryEndpoints.web" \
    --output tsv)

success "Deployment completed successfully!"
echo ""
echo "================================="
echo "   DEPLOYMENT SUMMARY"
echo "================================="
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo ""
echo "STATIC HOSTING:"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo "  Static Website URL: $STATIC_URL"
echo ""
echo "NEXT STEPS:"
echo "1. Build your Next.js frontend: npm run build && npm run export"
echo "2. Deploy to storage: az storage blob upload-batch --source out --destination '\$web' --account-name $STORAGE_ACCOUNT"
echo "3. Access your site at: $STATIC_URL"
echo "================================="