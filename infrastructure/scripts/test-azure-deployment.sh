#!/bin/bash

# Azure Static Website Deployment Test Script
# This script helps debug and test Azure Storage static website deployment

set -e

# Configuration
STORAGE_ACCOUNT="wordpressnextjsdevstatic"
RESOURCE_GROUP="wordpressnextjs-dev-rg"
DOMAIN_NAME="wordpressnextjsdevstatic.z16.web.core.windows.net"
SOURCE_DIR="../frontend/out"

echo "=== Azure Static Website Deployment Test ==="
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Resource Group: $RESOURCE_GROUP"
echo "Domain: $DOMAIN_NAME"
echo "Source Directory: $SOURCE_DIR"
echo ""

# Check if Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first."
    exit 1
fi

echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "❌ Not logged into Azure. Please run 'az login' first."
    exit 1
fi

echo "✅ Azure CLI is ready"
echo ""

# Check if storage account exists and get details
echo "Checking storage account configuration..."

if ! az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo "❌ Storage account '$STORAGE_ACCOUNT' not found in resource group '$RESOURCE_GROUP'"
    exit 1
fi

echo "✅ Storage account exists"

# Check if static website hosting is enabled
echo "Checking static website hosting configuration..."

STATIC_WEB_CONFIG=$(az storage blob service-properties show \
    --account-name "$STORAGE_ACCOUNT" \
    --auth-mode login \
    --query 'staticWebsite' \
    --output json 2>/dev/null || echo "null")

if [ "$STATIC_WEB_CONFIG" = "null" ] || [ "$(echo $STATIC_WEB_CONFIG | jq -r '.enabled')" != "true" ]; then
    echo "❌ Static website hosting is not enabled"
    echo "Enabling static website hosting..."
    
    az storage blob service-properties update \
        --account-name "$STORAGE_ACCOUNT" \
        --static-website \
        --index-document "index.html" \
        --404-document "404.html" \
        --auth-mode login
    
    echo "✅ Static website hosting enabled"
else
    echo "✅ Static website hosting is already enabled"
    echo "Index document: $(echo $STATIC_WEB_CONFIG | jq -r '.indexDocument')"
    echo "404 document: $(echo $STATIC_WEB_CONFIG | jq -r '.errorDocument404Path')"
fi
echo ""

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ Source directory '$SOURCE_DIR' not found"
    echo "Please build the Next.js application first:"
    echo "  cd ../frontend && npm run build"
    exit 1
fi

echo "✅ Source directory exists"
echo "Files to deploy:"
find "$SOURCE_DIR" -type f | head -10
echo ""

# Deploy files
echo "Deploying files to Azure Storage..."

az storage blob upload-batch \
    --account-name "$STORAGE_ACCOUNT" \
    --destination '$web' \
    --source "$SOURCE_DIR" \
    --overwrite \
    --auth-mode login

echo "✅ Files deployed successfully"
echo ""

# Test the deployment
echo "Testing deployment..."
SITE_URL="https://$DOMAIN_NAME"

echo "Waiting for propagation (30 seconds)..."
sleep 30

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$SITE_URL" || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Site is accessible at $SITE_URL (HTTP $HTTP_STATUS)"
    
    # Check content
    CONTENT=$(curl -s "$SITE_URL" | head -1)
    if echo "$CONTENT" | grep -q "<!DOCTYPE html>"; then
        echo "✅ Valid HTML content detected"
        echo "🎉 Deployment successful!"
    else
        echo "⚠️ Unexpected content format"
        echo "First line: $CONTENT"
    fi
else
    echo "❌ Site returned HTTP $HTTP_STATUS"
    echo "URL: $SITE_URL"
    
    # Additional debugging
    echo ""
    echo "Debugging information:"
    echo "Checking if \$web container exists..."
    
    az storage container list \
        --account-name "$STORAGE_ACCOUNT" \
        --auth-mode login \
        --query "[?name=='$web']" \
        --output table
    
    echo ""
    echo "Checking files in $web container..."
    az storage blob list \
        --account-name "$STORAGE_ACCOUNT" \
        --container-name '$web' \
        --auth-mode login \
        --output table | head -10
fi

echo ""
echo "=== Test Complete ==="
echo "Site URL: $SITE_URL"
echo "Azure Portal: https://portal.azure.com/#@/resource/subscriptions//resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT/staticwebsite"