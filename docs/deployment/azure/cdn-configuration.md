# CDN Configuration and Static Asset Delivery Guide

This guide covers Azure CDN setup, static asset optimization, and global content delivery for the headless WordPress + Next.js solution.

## Prerequisites

- Azure infrastructure setup completed ([Azure Setup Guide](./azure-setup-guide.md))
- WebApp deployment completed ([WebApp Deployment Guide](./webapp-deployment.md))
- Static Web App deployed and configured

## CDN Architecture Overview

```
┌────────────────────────────────────┐
│                Global Users               │
└────────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────┐
│           Azure Front Door              │
│         (Global Load Balancer)         │
│        Rules Engine + WAF             │
└────────────────────────────────────┘
                        │
           ┌────────────┴────────────┐
           │                             │
           ▼                             ▼
┌─────────────────┐         ┌─────────────────┐
│  Static Web App   │         │ Application     │
│  (Next.js SSG)    │         │ Gateway         │
│  - HTML/CSS/JS    │         │ (WordPress API) │
│  - Images/Assets  │         │ - /graphql      │
└─────────────────┘         │ - /wp-json      │
                              │ - /wp-content   │
                              └─────────────────┘
                                        │
                                        ▼
                              ┌─────────────────┐
                              │  WordPress      │
                              │  Container      │
                              │  + Media Files  │
                              └─────────────────┘
```

## Step 1: Azure Storage Account for Media

### 1.1 Create Storage Account for WordPress Media

```bash
# Source environment variables
source .env.azure

export STORAGE_ACCOUNT_NAME="st${PROJECT_NAME}${ENVIRONMENT}$(date +%s | tail -c 5)"
export MEDIA_CONTAINER_NAME="wordpress-media"
export STATIC_CONTAINER_NAME="static-assets"

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --access-tier Hot \
  --allow-blob-public-access true \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Get storage account key
export STORAGE_ACCOUNT_KEY=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP \
  --account-name $STORAGE_ACCOUNT_NAME \
  --query '[0].value' -o tsv)

# Create containers
az storage container create \
  --name $MEDIA_CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --account-key $STORAGE_ACCOUNT_KEY \
  --public-access blob

az storage container create \
  --name $STATIC_CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME \
  --account-key $STORAGE_ACCOUNT_KEY \
  --public-access blob

# Store credentials in Key Vault
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "storage-account-name" \
  --value $STORAGE_ACCOUNT_NAME

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "storage-account-key" \
  --value "$STORAGE_ACCOUNT_KEY"
```

### 1.2 Configure Storage Account Policies

```bash
# Enable static website hosting
az storage blob service-properties update \
  --account-name $STORAGE_ACCOUNT_NAME \
  --account-key $STORAGE_ACCOUNT_KEY \
  --static-website \
  --404-document 404.html \
  --index-document index.html

# Set CORS policy for cross-origin requests
az storage cors add \
  --account-name $STORAGE_ACCOUNT_NAME \
  --account-key $STORAGE_ACCOUNT_KEY \
  --services b \
  --methods GET POST PUT DELETE HEAD OPTIONS \
  --origins "*" \
  --allowed-headers "*" \
  --exposed-headers "*" \
  --max-age 3600

# Configure lifecycle management
cat > lifecycle-policy.json << 'EOF'
{
  "rules": [
    {
      "name": "DeleteOldMedia",
      "enabled": true,
      "type": "Lifecycle",
      "definition": {
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["wordpress-media/"]
        },
        "actions": {
          "baseBlob": {
            "delete": {
              "daysAfterModificationGreaterThan": 365
            },
            "tierToCool": {
              "daysAfterModificationGreaterThan": 30
            },
            "tierToArchive": {
              "daysAfterModificationGreaterThan": 90
            }
          }
        }
      }
    }
  ]
}
EOF

az storage account management-policy create \
  --account-name $STORAGE_ACCOUNT_NAME \
  --resource-group $RESOURCE_GROUP \
  --policy @lifecycle-policy.json
```

## Step 2: Azure CDN Profile and Endpoint

### 2.1 Create CDN Profile

```bash
export CDN_PROFILE_NAME="cdn-${PROJECT_NAME}-${ENVIRONMENT}"
export CDN_ENDPOINT_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cdn"

# Create CDN profile (Standard Microsoft)
az cdn profile create \
  --name $CDN_PROFILE_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --sku Standard_Microsoft \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Create CDN endpoint for static assets
az cdn endpoint create \
  --name $CDN_ENDPOINT_NAME \
  --profile-name $CDN_PROFILE_NAME \
  --resource-group $RESOURCE_GROUP \
  --origin ${STORAGE_ACCOUNT_NAME}.blob.core.windows.net \
  --origin-host-header ${STORAGE_ACCOUNT_NAME}.blob.core.windows.net \
  --origin-path "/" \
  --content-types-to-compress "text/css,text/javascript,application/javascript,text/html,text/xml,text/plain,application/json" \
  --is-compression-enabled true \
  --query-string-caching-behavior IgnoreQueryString

# Get CDN endpoint URL
export CDN_ENDPOINT_URL=$(az cdn endpoint show \
  --name $CDN_ENDPOINT_NAME \
  --profile-name $CDN_PROFILE_NAME \
  --resource-group $RESOURCE_GROUP \
  --query hostName -o tsv)

echo "CDN Endpoint URL: https://$CDN_ENDPOINT_URL"
```

### 2.2 Configure CDN Caching Rules

```bash
# Create caching rules for different content types
az cdn endpoint rule add \
  --name $CDN_ENDPOINT_NAME \
  --profile-name $CDN_PROFILE_NAME \
  --resource-group $RESOURCE_GROUP \
  --rule-name "CacheImages" \
  --order 1 \
  --conditions UrlFileExtension operator=Equal parameters="jpg,jpeg,png,gif,webp,svg,ico" \
  --actions CacheExpiration cacheBehavior=SetIfMissing cacheType=All duration="365.00:00:00"

az cdn endpoint rule add \
  --name $CDN_ENDPOINT_NAME \
  --profile-name $CDN_PROFILE_NAME \
  --resource-group $RESOURCE_GROUP \
  --rule-name "CacheCSS" \
  --order 2 \
  --conditions UrlFileExtension operator=Equal parameters="css" \
  --actions CacheExpiration cacheBehavior=SetIfMissing cacheType=All duration="30.00:00:00"

az cdn endpoint rule add \
  --name $CDN_ENDPOINT_NAME \
  --profile-name $CDN_PROFILE_NAME \
  --resource-group $RESOURCE_GROUP \
  --rule-name "CacheJS" \
  --order 3 \
  --conditions UrlFileExtension operator=Equal parameters="js" \
  --actions CacheExpiration cacheBehavior=SetIfMissing cacheType=All duration="30.00:00:00"

az cdn endpoint rule add \
  --name $CDN_ENDPOINT_NAME \
  --profile-name $CDN_PROFILE_NAME \
  --resource-group $RESOURCE_GROUP \
  --rule-name "CacheHTML" \
  --order 4 \
  --conditions UrlFileExtension operator=Equal parameters="html,htm" \
  --actions CacheExpiration cacheBehavior=SetIfMissing cacheType=All duration="1.00:00:00"
```

## Step 3: Azure Front Door Setup (Premium CDN)

### 3.1 Create Front Door Profile

```bash
export FRONT_DOOR_NAME="fd-${PROJECT_NAME}-${ENVIRONMENT}"
export FRONT_DOOR_ENDPOINT_NAME="${PROJECT_NAME}-${ENVIRONMENT}"

# Create Front Door profile (Standard tier)
az afd profile create \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --sku Standard_AzureFrontDoor \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Create endpoint
az afd endpoint create \
  --endpoint-name $FRONT_DOOR_ENDPOINT_NAME \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --enabled-state Enabled

# Get Front Door endpoint hostname
export FRONT_DOOR_HOSTNAME=$(az afd endpoint show \
  --endpoint-name $FRONT_DOOR_ENDPOINT_NAME \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --query hostName -o tsv)

echo "Front Door Hostname: https://$FRONT_DOOR_HOSTNAME"
```

### 3.2 Configure Origins and Origin Groups

```bash
# Create origin group for Static Web App (frontend)
az afd origin-group create \
  --origin-group-name "static-web-app" \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --load-balancing-sample-size 4 \
  --load-balancing-successful-samples-required 3 \
  --probe-interval-in-seconds 120 \
  --probe-path "/" \
  --probe-protocol Https \
  --probe-request-type GET

# Add Static Web App as origin
az afd origin create \
  --origin-name "frontend-origin" \
  --origin-group-name "static-web-app" \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --host-name $STATIC_WEB_APP_URL \
  --origin-host-header $STATIC_WEB_APP_URL \
  --http-port 80 \
  --https-port 443 \
  --priority 1 \
  --weight 1000 \
  --enabled-state Enabled

# Create origin group for WordPress API (backend)
az afd origin-group create \
  --origin-group-name "wordpress-api" \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --load-balancing-sample-size 4 \
  --load-balancing-successful-samples-required 3 \
  --probe-interval-in-seconds 120 \
  --probe-path "/wp-json/wp/v2/" \
  --probe-protocol Http \
  --probe-request-type GET

# Add Application Gateway as origin for WordPress
az afd origin create \
  --origin-name "wordpress-origin" \
  --origin-group-name "wordpress-api" \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --host-name $AGW_PUBLIC_IP \
  --origin-host-header $AGW_PUBLIC_IP \
  --http-port 80 \
  --https-port 443 \
  --priority 1 \
  --weight 1000 \
  --enabled-state Enabled

# Create origin group for media assets
az afd origin-group create \
  --origin-group-name "media-assets" \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --load-balancing-sample-size 4 \
  --load-balancing-successful-samples-required 3 \
  --probe-interval-in-seconds 300 \
  --probe-path "/" \
  --probe-protocol Https \
  --probe-request-type GET

# Add Storage Account as origin for media
az afd origin create \
  --origin-name "media-origin" \
  --origin-group-name "media-assets" \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --host-name "${STORAGE_ACCOUNT_NAME}.blob.core.windows.net" \
  --origin-host-header "${STORAGE_ACCOUNT_NAME}.blob.core.windows.net" \
  --http-port 80 \
  --https-port 443 \
  --priority 1 \
  --weight 1000 \
  --enabled-state Enabled
```

### 3.3 Configure Routes

```bash
# Route for frontend (default route)
az afd route create \
  --route-name "frontend-route" \
  --endpoint-name $FRONT_DOOR_ENDPOINT_NAME \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --origin-group "static-web-app" \
  --supported-protocols Http Https \
  --patterns-to-match "/*" \
  --forwarding-protocol HttpsOnly \
  --https-redirect Enabled \
  --enabled-state Enabled

# Route for WordPress API
az afd route create \
  --route-name "api-route" \
  --endpoint-name $FRONT_DOOR_ENDPOINT_NAME \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --origin-group "wordpress-api" \
  --supported-protocols Http Https \
  --patterns-to-match "/api/*" "/graphql/*" "/wp-json/*" \
  --forwarding-protocol MatchRequest \
  --enabled-state Enabled

# Route for media assets
az afd route create \
  --route-name "media-route" \
  --endpoint-name $FRONT_DOOR_ENDPOINT_NAME \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --origin-group "media-assets" \
  --supported-protocols Http Https \
  --patterns-to-match "/wp-content/uploads/*" "/media/*" \
  --forwarding-protocol HttpsOnly \
  --enabled-state Enabled
```

## Step 4: WordPress Media Upload Configuration

### 4.1 WordPress Azure Storage Plugin Configuration

```bash
# Create WordPress plugin configuration for Azure Storage
cat > azure-storage-config.php << 'EOF'
<?php
// Azure Storage configuration for WordPress

// Azure Storage Account settings
define('AZURE_STORAGE_ACCOUNT', getenv('AZURE_STORAGE_ACCOUNT'));
define('AZURE_STORAGE_KEY', getenv('AZURE_STORAGE_KEY'));
define('AZURE_STORAGE_CONTAINER', getenv('AZURE_STORAGE_CONTAINER') ?: 'wordpress-media');

// CDN settings
define('AZURE_STORAGE_CDN_URL', getenv('AZURE_CDN_URL'));
define('AZURE_STORAGE_USE_CDN', true);

// Upload settings
define('AZURE_STORAGE_CNAME', getenv('AZURE_STORAGE_CNAME'));
define('AZURE_STORAGE_UPLOAD_CACHING', true);
define('AZURE_STORAGE_CACHE_CONTROL', 'max-age=31536000'); // 1 year

// Image processing
define('AZURE_STORAGE_WEBP_SUPPORT', true);
define('AZURE_STORAGE_IMAGE_COMPRESSION', 85);
define('AZURE_STORAGE_PROGRESSIVE_JPEG', true);

// Security settings
define('AZURE_STORAGE_PRIVATE_CONTAINER', false);
define('AZURE_STORAGE_DELETE_LOCAL_FILES', true);

// Performance settings
define('AZURE_STORAGE_CONCURRENT_UPLOADS', 3);
define('AZURE_STORAGE_CHUNK_SIZE', 4194304); // 4MB chunks

// Backup settings
define('AZURE_STORAGE_BACKUP_ENABLED', true);
define('AZURE_STORAGE_BACKUP_RETENTION', 30); // days
EOF
```

### 4.2 Update WordPress Container with Azure Storage

```bash
# Update container with Azure Storage environment variables
az container create \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --image ${ACR_NAME}.azurecr.io/wordpress-headless:latest \
  --registry-login-server ${ACR_NAME}.azurecr.io \
  --registry-username $ACR_USERNAME \
  --registry-password "$ACR_PASSWORD" \
  --dns-name-label $CONTAINER_DNS_NAME \
  --ports 80 443 \
  --cpu 2 \
  --memory 4 \
  --location "$LOCATION" \
  --restart-policy OnFailure \
  --environment-variables \
    WORDPRESS_DB_HOST="$MYSQL_HOST" \
    WORDPRESS_DB_NAME="$MYSQL_DATABASE" \
    WORDPRESS_DB_USER="$MYSQL_USERNAME" \
    WORDPRESS_DB_PASSWORD="$MYSQL_PASSWORD" \
    AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT_NAME" \
    AZURE_STORAGE_KEY="$STORAGE_ACCOUNT_KEY" \
    AZURE_STORAGE_CONTAINER="$MEDIA_CONTAINER_NAME" \
    AZURE_CDN_URL="https://$CDN_ENDPOINT_URL" \
    WP_REDIS_HOST="${REDIS_CACHE_NAME}.redis.cache.windows.net" \
    WP_REDIS_PORT="6380" \
    WP_REDIS_PASSWORD="$REDIS_PRIMARY_KEY" \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT
```

### 4.3 Install WordPress Azure Storage Plugin

```bash
# Install and configure Azure Storage plugin in WordPress
az container exec \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --exec-command "/bin/bash -c '
    # Install Windows Azure Storage plugin
    wp plugin install windows-azure-storage --activate --allow-root
    
    # Configure plugin options
    wp option update azure_storage_account_name '$STORAGE_ACCOUNT_NAME' --allow-root
    wp option update azure_storage_account_key '$STORAGE_ACCOUNT_KEY' --allow-root
    wp option update azure_storage_container '$MEDIA_CONTAINER_NAME' --allow-root
    wp option update azure_storage_cdn_url 'https://$CDN_ENDPOINT_URL' --allow-root
    wp option update azure_storage_use_cname 1 --allow-root
    
    # Enable Azure Storage for uploads
    wp option update upload_url_path 'https://$CDN_ENDPOINT_URL/$MEDIA_CONTAINER_NAME' --allow-root
    
    echo "Azure Storage plugin configured successfully"
    '"
```

## Step 5: Image Optimization and Processing

### 5.1 Azure Function for Image Processing

```bash
# Create Azure Function App for image processing
export FUNCTION_APP_NAME="func-${PROJECT_NAME}-${ENVIRONMENT}"
export FUNCTION_STORAGE_NAME="stfunc${PROJECT_NAME}${ENVIRONMENT}$(date +%s | tail -c 3)"

# Create storage account for function
az storage account create \
  --name $FUNCTION_STORAGE_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --sku Standard_LRS

# Create Function App
az functionapp create \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --storage-account $FUNCTION_STORAGE_NAME \
  --consumption-plan-location "$LOCATION" \
  --runtime node \
  --runtime-version 18 \
  --functions-version 4 \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Configure function app settings
az functionapp config appsettings set \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
    AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT_NAME" \
    AZURE_STORAGE_KEY="$STORAGE_ACCOUNT_KEY" \
    CDN_ENDPOINT_URL="https://$CDN_ENDPOINT_URL"
```

### 5.2 Image Processing Function Code

```bash
cat > image-optimizer-function.js << 'EOF'
const { BlobServiceClient } = require('@azure/storage-blob');
const sharp = require('sharp');

module.exports = async function (context, myBlob) {
    const blobName = context.bindingData.name;
    const containerName = context.bindingData.container;
    
    // Skip if already optimized
    if (blobName.includes('-optimized')) {
        return;
    }
    
    try {
        // Initialize Azure Storage client
        const blobServiceClient = BlobServiceClient.fromConnectionString(
            process.env.AzureWebJobsStorage
        );
        
        const containerClient = blobServiceClient.getContainerClient(containerName);
        
        // Create optimized versions
        const sizes = [
            { suffix: '-thumbnail', width: 150, height: 150 },
            { suffix: '-medium', width: 300, height: 300 },
            { suffix: '-large', width: 1024, height: 1024 },
            { suffix: '-webp', width: 1920, format: 'webp' }
        ];
        
        for (const size of sizes) {
            let processed = sharp(myBlob);
            
            if (size.format === 'webp') {
                processed = processed.webp({ quality: 85 });
            } else {
                processed = processed.jpeg({ quality: 85, progressive: true });
            }
            
            if (size.width && size.height) {
                processed = processed.resize(size.width, size.height, {
                    fit: 'inside',
                    withoutEnlargement: true
                });
            }
            
            const optimizedBuffer = await processed.toBuffer();
            
            // Upload optimized version
            const optimizedBlobName = blobName.replace(
                /\.(jpg|jpeg|png)$/i,
                `${size.suffix}.$1`
            );
            
            if (size.format === 'webp') {
                optimizedBlobName = blobName.replace(/\.(jpg|jpeg|png)$/i, '.webp');
            }
            
            const blockBlobClient = containerClient.getBlockBlobClient(optimizedBlobName);
            
            await blockBlobClient.upload(optimizedBuffer, optimizedBuffer.length, {
                blobHTTPHeaders: {
                    blobContentType: size.format === 'webp' ? 'image/webp' : 'image/jpeg',
                    blobCacheControl: 'max-age=31536000'
                }
            });
            
            context.log(`Created optimized image: ${optimizedBlobName}`);
        }
        
        // Purge CDN cache for the original image
        const cdnEndpoint = process.env.CDN_ENDPOINT_URL;
        if (cdnEndpoint) {
            // Add CDN purge logic here
            context.log(`Should purge CDN cache for: ${cdnEndpoint}/${containerName}/${blobName}`);
        }
        
    } catch (error) {
        context.log.error('Error processing image:', error);
    }
};
EOF

# Create function.json for blob trigger
cat > image-optimizer-function.json << 'EOF'
{
  "bindings": [
    {
      "name": "myBlob",
      "type": "blobTrigger",
      "direction": "in",
      "path": "wordpress-media/{name}",
      "connection": "AzureWebJobsStorage"
    }
  ],
  "scriptFile": "index.js"
}
EOF
```

## Step 6: Advanced CDN Configuration

### 6.1 Custom Domain and SSL Certificate

```bash
# Add custom domain to Front Door (requires domain validation)
export CUSTOM_DOMAIN="cdn.yourdomain.com"

# Create custom domain
az afd custom-domain create \
  --custom-domain-name "cdn-domain" \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --host-name $CUSTOM_DOMAIN \
  --minimum-tls-version TLS12

# Associate custom domain with route (after domain validation)
# az afd route update \
#   --route-name "frontend-route" \
#   --endpoint-name $FRONT_DOOR_ENDPOINT_NAME \
#   --profile-name $FRONT_DOOR_NAME \
#   --resource-group $RESOURCE_GROUP \
#   --custom-domains "cdn-domain"
```

### 6.2 WAF Security Policy

```bash
# Create WAF policy for Front Door
export WAF_POLICY_FD_NAME="waffd${PROJECT_NAME}${ENVIRONMENT}"

az network front-door waf-policy create \
  --name $WAF_POLICY_FD_NAME \
  --resource-group $RESOURCE_GROUP \
  --sku Standard_AzureFrontDoor \
  --mode Prevention \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Create rate limiting rule
az network front-door waf-policy rule create \
  --policy-name $WAF_POLICY_FD_NAME \
  --resource-group $RESOURCE_GROUP \
  --name "RateLimitRule" \
  --rule-type RateLimitRule \
  --action Block \
  --priority 100 \
  --rate-limit-duration 1 \
  --rate-limit-threshold 100

# Create bot protection rule
az network front-door waf-policy rule create \
  --policy-name $WAF_POLICY_FD_NAME \
  --resource-group $RESOURCE_GROUP \
  --name "BotProtectionRule" \
  --rule-type MatchRule \
  --action Block \
  --priority 200 \
  --match-conditions \
    '[{"matchVariable":"RequestHeader","selector":"User-Agent","operator":"Contains","matchValue":["bot","crawler","spider"],"negateCondition":false}]'

# Apply WAF policy to Front Door endpoint
az afd security-policy create \
  --security-policy-name "waf-security-policy" \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --domains $FRONT_DOOR_HOSTNAME \
  --waf-policy $WAF_POLICY_FD_NAME
```

### 6.3 Advanced Caching Rules

```bash
# Create rule set for advanced caching
az afd rule-set create \
  --rule-set-name "advanced-caching" \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP

# Rule for aggressive image caching
az afd rule create \
  --rule-name "cache-images-long" \
  --rule-set-name "advanced-caching" \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --order 1 \
  --conditions \
    '[{"name":"UrlFileExtension","parameters":{"operator":"Equal","matchValues":["jpg","jpeg","png","gif","webp","svg","ico","woff","woff2","ttf","eot"]}}]' \
  --actions \
    '[{"name":"CacheExpiration","parameters":{"cacheBehavior":"SetIfMissing","cacheType":"All","cacheDuration":"365.00:00:00"}}]'

# Rule for API response caching
az afd rule create \
  --rule-name "cache-api-responses" \
  --rule-set-name "advanced-caching" \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --order 2 \
  --conditions \
    '[{"name":"UrlPath","parameters":{"operator":"BeginsWith","matchValues":["/wp-json/","/graphql"]}}]' \
  --actions \
    '[{"name":"CacheExpiration","parameters":{"cacheBehavior":"SetIfMissing","cacheType":"All","cacheDuration":"0.00:05:00"}}]'

# Rule for HTML caching with query string bypass
az afd rule create \
  --rule-name "cache-html-bypass-query" \
  --rule-set-name "advanced-caching" \
  --profile-name $FRONT_DOOR_NAME \
  --resource-group $RESOURCE_GROUP \
  --order 3 \
  --conditions \
    '[{"name":"UrlFileExtension","parameters":{"operator":"Equal","matchValues":["html","htm"]}},{"name":"QueryString","parameters":{"operator":"Equal","matchValues":["v","ver","version"]}}]' \
  --actions \
    '[{"name":"CacheExpiration","parameters":{"cacheBehavior":"Override","cacheType":"All","cacheDuration":"0.00:01:00"}}]'
```

## Step 7: Performance Monitoring and Analytics

### 7.1 CDN Analytics Setup

```bash
# Enable analytics for CDN endpoint
az cdn endpoint update \
  --name $CDN_ENDPOINT_NAME \
  --profile-name $CDN_PROFILE_NAME \
  --resource-group $RESOURCE_GROUP \
  --enable-compression true

# Create Log Analytics workspace for CDN logs (if not exists)
if ! az monitor log-analytics workspace show --workspace-name $LOG_ANALYTICS_NAME --resource-group $RESOURCE_GROUP > /dev/null 2>&1; then
    az monitor log-analytics workspace create \
        --workspace-name $LOG_ANALYTICS_NAME \
        --resource-group $RESOURCE_GROUP \
        --location "$LOCATION"
fi

# Configure diagnostic settings for Front Door
az monitor diagnostic-settings create \
  --name "frontdoor-diagnostics" \
  --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Cdn/profiles/$FRONT_DOOR_NAME" \
  --workspace "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$LOG_ANALYTICS_NAME" \
  --logs \
    '[{"category":"FrontDoorAccessLog","enabled":true},{"category":"FrontDoorHealthProbeLog","enabled":true},{"category":"FrontDoorWebApplicationFirewallLog","enabled":true}]' \
  --metrics \
    '[{"category":"AllMetrics","enabled":true}]'
```

### 7.2 Custom Performance Monitoring

```bash
cat > cdn-performance-monitor.sh << 'EOF'
#!/bin/bash

# CDN Performance monitoring script
set -e

LOG_FILE="cdn-performance-$(date +%Y%m%d).log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

echo "=== CDN Performance Check - $TIMESTAMP ===" >> $LOG_FILE

# Test endpoints
ENDPOINTS=(
    "https://$FRONT_DOOR_HOSTNAME/"
    "https://$CDN_ENDPOINT_URL/wordpress-media/test-image.jpg"
    "https://$STATIC_WEB_APP_URL/"
)

# Test each endpoint
for endpoint in "${ENDPOINTS[@]}"; do
    echo "Testing: $endpoint" >> $LOG_FILE
    
    # Test response time and status
    RESPONSE=$(curl -w "HTTP_CODE:%{http_code}|DNS:%{time_namelookup}|CONNECT:%{time_connect}|TTFB:%{time_starttransfer}|TOTAL:%{time_total}|SIZE:%{size_download}" \
                   -s -o /dev/null "$endpoint" || echo "FAILED")
    
    if [[ $RESPONSE == *"FAILED"* ]]; then
        echo "  FAILED to connect" >> $LOG_FILE
    else
        echo "  $RESPONSE" >> $LOG_FILE
        
        # Extract values for alerting
        HTTP_CODE=$(echo $RESPONSE | grep -o 'HTTP_CODE:[0-9]*' | cut -d: -f2)
        TOTAL_TIME=$(echo $RESPONSE | grep -o 'TOTAL:[0-9.]*' | cut -d: -f2)
        
        # Alert on slow responses (>3 seconds)
        if (( $(echo "$TOTAL_TIME > 3" | bc -l) )); then
            echo "  WARNING: Slow response ($TOTAL_TIME seconds)" >> $LOG_FILE
        fi
        
        # Alert on error status codes
        if [[ $HTTP_CODE -ge 400 ]]; then
            echo "  ERROR: HTTP $HTTP_CODE" >> $LOG_FILE
        fi
    fi
    
    echo "" >> $LOG_FILE
done

# Test CDN cache hit ratio (requires Azure CLI and Log Analytics)
echo "Checking CDN cache metrics..." >> $LOG_FILE

# Get cache hit ratio from Azure Monitor (last 24 hours)
CACHE_METRICS=$(az monitor metrics list \
    --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Cdn/profiles/$FRONT_DOOR_NAME" \
    --metric "Percentage4XX,Percentage5XX,RequestCount" \
    --interval PT1H \
    --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --aggregation Average 2>/dev/null || echo "No metrics available")

if [[ $CACHE_METRICS != "No metrics available" ]]; then
    echo "Cache metrics retrieved successfully" >> $LOG_FILE
else
    echo "Unable to retrieve cache metrics" >> $LOG_FILE
fi

echo "=== Performance Check Complete ===" >> $LOG_FILE
echo "" >> $LOG_FILE
EOF

chmod +x cdn-performance-monitor.sh

# Schedule performance monitoring (every 15 minutes)
echo "*/15 * * * * /path/to/cdn-performance-monitor.sh" | crontab -
```

## Step 8: CDN Purge and Cache Management

### 8.1 Automated Cache Purge Scripts

```bash
cat > purge-cdn-cache.sh << 'EOF'
#!/bin/bash

# CDN Cache purge script
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <path-pattern> [content-type]"
    echo "Examples:"
    echo "  $0 '/*' # Purge everything"
    echo "  $0 '/wp-content/uploads/*' # Purge all uploads"
    echo "  $0 '/specific-file.jpg' # Purge specific file"
    exit 1
fi

PATH_PATTERN=$1
CONTENT_TYPE=${2:-"all"}

echo "Purging CDN cache for pattern: $PATH_PATTERN"

# Purge Azure CDN (Standard Microsoft)
echo "Purging Standard CDN..."
az cdn endpoint purge \
    --name $CDN_ENDPOINT_NAME \
    --profile-name $CDN_PROFILE_NAME \
    --resource-group $RESOURCE_GROUP \
    --content-paths "$PATH_PATTERN"

# Purge Front Door CDN
echo "Purging Front Door CDN..."
az afd endpoint purge \
    --endpoint-name $FRONT_DOOR_ENDPOINT_NAME \
    --profile-name $FRONT_DOOR_NAME \
    --resource-group $RESOURCE_GROUP \
    --content-paths "$PATH_PATTERN" \
    --domains $FRONT_DOOR_HOSTNAME

echo "Cache purge initiated for: $PATH_PATTERN"
echo "Note: Purge may take 5-10 minutes to complete globally"
EOF

chmod +x purge-cdn-cache.sh
```

### 8.2 WordPress Integration for Automatic Purging

```bash
cat > wordpress-cdn-purge.php << 'EOF'
<?php
/**
 * WordPress CDN Cache Purge Integration
 * Add this to WordPress theme functions.php or as a plugin
 */

// Hook into post save/update to purge cache
add_action('save_post', 'purge_cdn_on_post_update', 10, 3);
add_action('wp_trash_post', 'purge_cdn_on_post_delete');
add_action('untrash_post', 'purge_cdn_on_post_update');

function purge_cdn_on_post_update($post_id, $post, $update) {
    // Only purge for published posts
    if ($post->post_status !== 'publish') {
        return;
    }
    
    // Get post permalink
    $post_url = get_permalink($post_id);
    $post_path = parse_url($post_url, PHP_URL_PATH);
    
    // Purge specific post
    purge_cdn_paths([$post_path]);
    
    // Also purge home page and category pages if needed
    if ($update) {
        purge_cdn_paths(['/', '/blog/']);
    }
}

function purge_cdn_on_post_delete($post_id) {
    $post_url = get_permalink($post_id);
    $post_path = parse_url($post_url, PHP_URL_PATH);
    purge_cdn_paths([$post_path, '/', '/blog/']);
}

function purge_cdn_paths($paths) {
    $cdn_endpoints = [
        getenv('CDN_ENDPOINT_URL'),
        getenv('FRONT_DOOR_HOSTNAME')
    ];
    
    foreach ($cdn_endpoints as $endpoint) {
        if (!$endpoint) continue;
        
        // Use Azure REST API to purge cache
        $subscription_id = getenv('AZURE_SUBSCRIPTION_ID');
        $resource_group = getenv('AZURE_RESOURCE_GROUP');
        $profile_name = getenv('AZURE_CDN_PROFILE_NAME');
        
        if (!$subscription_id || !$resource_group || !$profile_name) {
            error_log('CDN purge failed: Missing Azure configuration');
            continue;
        }
        
        // This would require proper Azure authentication
        // For production, use Azure SDK or REST API calls
        error_log('CDN purge requested for paths: ' . implode(', ', $paths));
        
        // Alternative: Use webhook to trigger purge script
        $webhook_url = getenv('CDN_PURGE_WEBHOOK_URL');
        if ($webhook_url) {
            wp_remote_post($webhook_url, [
                'body' => json_encode(['paths' => $paths]),
                'headers' => ['Content-Type' => 'application/json']
            ]);
        }
    }
}

// Manual purge function for admin
add_action('wp_ajax_purge_cdn_cache', 'handle_manual_cdn_purge');
function handle_manual_cdn_purge() {
    if (!current_user_can('manage_options')) {
        wp_die('Unauthorized');
    }
    
    $paths = isset($_POST['paths']) ? $_POST['paths'] : ['/*'];
    purge_cdn_paths($paths);
    
    wp_send_json_success('CDN cache purge initiated');
}

// Add admin menu item
add_action('admin_menu', 'add_cdn_purge_menu');
function add_cdn_purge_menu() {
    add_management_page(
        'CDN Cache Purge',
        'CDN Cache',
        'manage_options',
        'cdn-cache-purge',
        'cdn_purge_admin_page'
    );
}

function cdn_purge_admin_page() {
    ?>
    <div class="wrap">
        <h1>CDN Cache Management</h1>
        <form method="post" action="">
            <?php wp_nonce_field('purge_cdn_nonce'); ?>
            <table class="form-table">
                <tr>
                    <th scope="row">Purge Paths</th>
                    <td>
                        <textarea name="paths" rows="5" cols="50" placeholder="/path1/\n/path2/\n/*">/*</textarea>
                        <p class="description">One path per line. Use /* to purge everything.</p>
                    </td>
                </tr>
            </table>
            <p class="submit">
                <input type="submit" name="submit" class="button-primary" value="Purge CDN Cache">
            </p>
        </form>
    </div>
    <?php
    
    if (isset($_POST['submit'])) {
        check_admin_referer('purge_cdn_nonce');
        $paths = array_filter(array_map('trim', explode("\n", $_POST['paths'])));
        purge_cdn_paths($paths);
        echo '<div class="notice notice-success"><p>CDN cache purge initiated for ' . count($paths) . ' paths.</p></div>';
    }
}
EOF
```

## Step 9: Performance Optimization and Testing

### 9.1 Load Testing Script

```bash
cat > cdn-load-test.sh << 'EOF'
#!/bin/bash

# CDN Load testing script
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <concurrent-users> [duration-seconds]"
    echo "Example: $0 50 300  # 50 concurrent users for 5 minutes"
    exit 1
fi

CONCURRENT_USERS=$1
DURATION=${2:-60}
TEST_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="load-test-results-$TEST_TIMESTAMP"

mkdir -p $RESULTS_DIR

echo "Starting load test with $CONCURRENT_USERS concurrent users for $DURATION seconds"
echo "Results will be saved to: $RESULTS_DIR"

# Test URLs
TEST_URLS=(
    "https://$FRONT_DOOR_HOSTNAME/"
    "https://$FRONT_DOOR_HOSTNAME/api/wp-json/wp/v2/posts"
    "https://$FRONT_DOOR_HOSTNAME/graphql"
    "https://$CDN_ENDPOINT_URL/wordpress-media/sample-image.jpg"
)

# Create URLs file
printf '%s\n' "${TEST_URLS[@]}" > $RESULTS_DIR/test-urls.txt

# Run load test using Apache Bench (ab)
for url in "${TEST_URLS[@]}"; do
    echo "Testing: $url"
    SAFE_NAME=$(echo $url | sed 's|https://||g' | sed 's|/|_|g')
    
    ab -n $((CONCURRENT_USERS * 10)) \
       -c $CONCURRENT_USERS \
       -t $DURATION \
       -g "$RESULTS_DIR/${SAFE_NAME}_gnuplot.dat" \
       -e "$RESULTS_DIR/${SAFE_NAME}_percentiles.csv" \
       "$url" > "$RESULTS_DIR/${SAFE_NAME}_results.txt" 2>&1 &
done

echo "Load tests running in background..."
echo "Waiting for completion..."
wait

# Generate summary report
cat > $RESULTS_DIR/summary.txt << EOL
Load Test Summary - $(date)
=========================

Test Configuration:
- Concurrent Users: $CONCURRENT_USERS
- Duration: $DURATION seconds
- URLs Tested: ${#TEST_URLS[@]}

Results Files:
- *_results.txt: Detailed Apache Bench output
- *_percentiles.csv: Response time percentiles
- *_gnuplot.dat: Time series data for plotting

Key Metrics to Review:
- Requests per second
- Average response time
- 95th percentile response time
- Failed requests (should be 0)
- Transfer rate

EOL

# Extract key metrics
echo "\nKey Metrics Summary:" >> $RESULTS_DIR/summary.txt
echo "==================" >> $RESULTS_DIR/summary.txt

for result_file in $RESULTS_DIR/*_results.txt; do
    if [ -f "$result_file" ]; then
        echo "\n$(basename $result_file .txt):" >> $RESULTS_DIR/summary.txt
        grep -E "(Requests per second|Time per request|Transfer rate|Failed requests)" "$result_file" >> $RESULTS_DIR/summary.txt
    fi
done

echo "Load test completed. Results saved to: $RESULTS_DIR"
cat $RESULTS_DIR/summary.txt
EOF

chmod +x cdn-load-test.sh
```

### 9.2 CDN Health Check and Monitoring

```bash
cat > cdn-health-check.sh << 'EOF'
#!/bin/bash

# Comprehensive CDN health check
set -e

HEALTH_LOG="cdn-health-$(date +%Y%m%d_%H%M%S).log"
ERROR_COUNT=0

echo "=== CDN Health Check - $(date) ===" | tee $HEALTH_LOG

# Function to test endpoint
test_endpoint() {
    local url=$1
    local expected_status=$2
    local max_time=$3
    local description=$4
    
    echo "Testing: $description" | tee -a $HEALTH_LOG
    echo "URL: $url" | tee -a $HEALTH_LOG
    
    local response=$(curl -w "status:%{http_code}|time:%{time_total}|size:%{size_download}" \
                          -s -o /dev/null \
                          --max-time $max_time \
                          "$url" 2>/dev/null || echo "status:000|time:999|size:0")
    
    local status=$(echo $response | grep -o 'status:[0-9]*' | cut -d: -f2)
    local time=$(echo $response | grep -o 'time:[0-9.]*' | cut -d: -f2)
    local size=$(echo $response | grep -o 'size:[0-9]*' | cut -d: -f2)
    
    echo "  Status: $status (expected: $expected_status)" | tee -a $HEALTH_LOG
    echo "  Response Time: ${time}s (max: ${max_time}s)" | tee -a $HEALTH_LOG
    echo "  Content Size: ${size} bytes" | tee -a $HEALTH_LOG
    
    # Check status code
    if [ "$status" != "$expected_status" ]; then
        echo "  ❌ FAIL: Wrong status code" | tee -a $HEALTH_LOG
        ((ERROR_COUNT++))
    else
        echo "  ✅ PASS: Status code OK" | tee -a $HEALTH_LOG
    fi
    
    # Check response time
    if (( $(echo "$time > $max_time" | bc -l) )); then
        echo "  ❌ FAIL: Response too slow" | tee -a $HEALTH_LOG
        ((ERROR_COUNT++))
    else
        echo "  ✅ PASS: Response time OK" | tee -a $HEALTH_LOG
    fi
    
    # Check content size (should be > 0 for successful responses)
    if [ "$status" = "200" ] && [ "$size" = "0" ]; then
        echo "  ⚠️  WARN: Empty content" | tee -a $HEALTH_LOG
    fi
    
    echo "" | tee -a $HEALTH_LOG
}

# Test endpoints
test_endpoint "https://$FRONT_DOOR_HOSTNAME/" "200" "5" "Front Door - Homepage"
test_endpoint "https://$FRONT_DOOR_HOSTNAME/graphql" "400" "10" "Front Door - GraphQL Endpoint"
test_endpoint "https://$STATIC_WEB_APP_URL/" "200" "5" "Static Web App - Direct"
test_endpoint "https://$CDN_ENDPOINT_URL/wordpress-media/test.txt" "404" "5" "CDN - Media Endpoint"

# Test CDN headers
echo "Testing CDN Headers:" | tee -a $HEALTH_LOG
echo "=====================" | tee -a $HEALTH_LOG

HEADERS=$(curl -s -I "https://$FRONT_DOOR_HOSTNAME/" || echo "Failed to fetch headers")

if echo "$HEADERS" | grep -qi "cache-control"; then
    echo "✅ Cache-Control header present" | tee -a $HEALTH_LOG
else
    echo "❌ Cache-Control header missing" | tee -a $HEALTH_LOG
    ((ERROR_COUNT++))
fi

if echo "$HEADERS" | grep -qi "x-azure-ref"; then
    echo "✅ Azure CDN headers present" | tee -a $HEALTH_LOG
else
    echo "⚠️  Azure CDN headers not detected" | tee -a $HEALTH_LOG
fi

if echo "$HEADERS" | grep -qi "x-cache"; then
    echo "✅ Cache status header present" | tee -a $HEALTH_LOG
    echo "   $(echo "$HEADERS" | grep -i "x-cache")" | tee -a $HEALTH_LOG
else
    echo "⚠️  Cache status header not found" | tee -a $HEALTH_LOG
fi

echo "" | tee -a $HEALTH_LOG

# Test SSL certificates
echo "Testing SSL Certificates:" | tee -a $HEALTH_LOG
echo "=========================" | tee -a $HEALTH_LOG

SSL_DOMAINS=("$FRONT_DOOR_HOSTNAME" "$STATIC_WEB_APP_URL")

for domain in "${SSL_DOMAINS[@]}"; do
    # Remove https:// if present
    clean_domain=$(echo $domain | sed 's|https://||g')
    
    echo "Checking SSL for: $clean_domain" | tee -a $HEALTH_LOG
    
    SSL_INFO=$(openssl s_client -connect "${clean_domain}:443" -servername "$clean_domain" < /dev/null 2>/dev/null | \
               openssl x509 -noout -dates 2>/dev/null || echo "SSL check failed")
    
    if [ "$SSL_INFO" != "SSL check failed" ]; then
        echo "  ✅ SSL certificate valid" | tee -a $HEALTH_LOG
        echo "  $SSL_INFO" | tee -a $HEALTH_LOG
    else
        echo "  ❌ SSL certificate check failed" | tee -a $HEALTH_LOG
        ((ERROR_COUNT++))
    fi
    
    echo "" | tee -a $HEALTH_LOG
done

# Final summary
echo "=== Health Check Summary ===" | tee -a $HEALTH_LOG
echo "Total Errors: $ERROR_COUNT" | tee -a $HEALTH_LOG

if [ $ERROR_COUNT -eq 0 ]; then
    echo "🎉 All checks passed!" | tee -a $HEALTH_LOG
    exit 0
else
    echo "⚠️  $ERROR_COUNT checks failed" | tee -a $HEALTH_LOG
    exit 1
fi
EOF

chmod +x cdn-health-check.sh

# Schedule health checks (every hour)
echo "0 * * * * /path/to/cdn-health-check.sh" | crontab -
```

## Step 10: Final Configuration and Testing

### 10.1 Update Environment Variables

```bash
# Update .env.azure with CDN configuration
cat >> .env.azure << EOF

# CDN Configuration
STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT_NAME
MEDIA_CONTAINER_NAME=$MEDIA_CONTAINER_NAME
STATIC_CONTAINER_NAME=$STATIC_CONTAINER_NAME
CDN_PROFILE_NAME=$CDN_PROFILE_NAME
CDN_ENDPOINT_NAME=$CDN_ENDPOINT_NAME
CDN_ENDPOINT_URL=https://$CDN_ENDPOINT_URL
FRONT_DOOR_NAME=$FRONT_DOOR_NAME
FRONT_DOOR_ENDPOINT_NAME=$FRONT_DOOR_ENDPOINT_NAME
FRONT_DOOR_HOSTNAME=https://$FRONT_DOOR_HOSTNAME
FUNCTION_APP_NAME=$FUNCTION_APP_NAME
WAF_POLICY_FD_NAME=$WAF_POLICY_FD_NAME

# CDN Settings
CDN_CACHE_DURATION_IMAGES=365
CDN_CACHE_DURATION_STATIC=30
CDN_CACHE_DURATION_API=5
CDN_COMPRESSION_ENABLED=true
CDN_QUERY_STRING_CACHING=IgnoreQueryString

# Performance Settings
IMAGE_OPTIMIZATION_ENABLED=true
WEBP_SUPPORT_ENABLED=true
IMAGE_COMPRESSION_QUALITY=85
PROGRESSIVE_JPEG_ENABLED=true
EOF

echo "CDN configuration completed successfully!"
echo "Configuration saved to .env.azure"
```

### 10.2 Comprehensive Test Suite

```bash
cat > test-cdn-deployment.sh << 'EOF'
#!/bin/bash

# Comprehensive CDN deployment test
set -e

echo "=== CDN Deployment Test Suite ==="
echo "Start Time: $(date)"
echo ""

# Test 1: Basic connectivity
echo "1. Testing basic connectivity..."
./cdn-health-check.sh
echo ""

# Test 2: Performance test (light load)
echo "2. Running performance test..."
./cdn-load-test.sh 10 60
echo ""

# Test 3: Cache functionality
echo "3. Testing cache functionality..."

# First request (should be cache miss)
echo "  First request (cache miss expected):"
RESPONSE1=$(curl -w "time:%{time_total}" -s -o /dev/null "https://$FRONT_DOOR_HOSTNAME/")
echo "  $RESPONSE1"

sleep 2

# Second request (should be cache hit)
echo "  Second request (cache hit expected):"
RESPONSE2=$(curl -w "time:%{time_total}" -s -o /dev/null "https://$FRONT_DOOR_HOSTNAME/")
echo "  $RESPONSE2"

echo ""

# Test 4: Image optimization
echo "4. Testing image optimization..."
if command -v identify &> /dev/null; then
    # Test original vs optimized images (if available)
    echo "  ImageMagick available for testing"
else
    echo "  ImageMagick not available, skipping image tests"
fi
echo ""

# Test 5: CDN purge functionality
echo "5. Testing CDN purge..."
./purge-cdn-cache.sh "/test/*"
echo ""

# Test 6: Security headers
echo "6. Testing security headers..."
HEADERS=$(curl -s -I "https://$FRONT_DOOR_HOSTNAME/")

SECURITY_HEADERS=("X-Content-Type-Options" "X-Frame-Options" "X-XSS-Protection")
for header in "${SECURITY_HEADERS[@]}"; do
    if echo "$HEADERS" | grep -qi "$header"; then
        echo "  ✅ $header present"
    else
        echo "  ❌ $header missing"
    fi
done
echo ""

# Test 7: Compression
echo "7. Testing compression..."
COMPRESSED=$(curl -s -H "Accept-Encoding: gzip" -I "https://$FRONT_DOOR_HOSTNAME/" | grep -i "content-encoding")
if [[ $COMPRESSED ]]; then
    echo "  ✅ Compression enabled: $COMPRESSED"
else
    echo "  ❌ Compression not detected"
fi
echo ""

echo "=== Test Suite Complete ==="
echo "End Time: $(date)"
EOF

chmod +x test-cdn-deployment.sh

# Run the comprehensive test
./test-cdn-deployment.sh
```

## Summary and Next Steps

### Configuration Checklist

- [ ] Azure Storage Account created for media files
- [ ] CDN Profile and Endpoint configured
- [ ] Front Door setup with origins and routes
- [ ] WAF policy applied for security
- [ ] Caching rules configured for different content types
- [ ] Image optimization function deployed
- [ ] WordPress Azure Storage plugin configured
- [ ] Custom domain and SSL certificates (if applicable)
- [ ] Performance monitoring and alerting setup
- [ ] Cache purge automation implemented
- [ ] Load testing and health checks configured

### Performance Optimization Summary

1. **Global Distribution**: Front Door provides global edge locations
2. **Intelligent Caching**: Different TTLs for various content types
3. **Image Optimization**: Automated resizing and WebP conversion
4. **Compression**: Gzip/Brotli compression for text assets
5. **Security**: WAF protection and security headers
6. **Monitoring**: Comprehensive health checks and performance metrics

### Troubleshooting Guide

#### Common Issues:

1. **Cache Not Working**
   - Check cache-control headers from origin
   - Verify CDN rules are applied correctly
   - Use browser dev tools to inspect headers

2. **Slow Performance**
   - Run load tests to identify bottlenecks
   - Check origin server performance
   - Review CDN cache hit ratios

3. **SSL Certificate Issues**
   - Verify domain ownership for custom domains
   - Check certificate expiration dates
   - Ensure proper DNS configuration

4. **Image Optimization Not Working**
   - Check Azure Function logs
   - Verify storage account permissions
   - Test function trigger manually

### Cost Optimization Tips

1. **CDN Tier Selection**: Start with Standard, upgrade to Premium if needed
2. **Storage Tiers**: Use appropriate tiers (Hot/Cool/Archive) for different content
3. **Cache Duration**: Longer cache TTLs reduce origin requests
4. **Compression**: Reduces bandwidth costs
5. **Image Optimization**: Smaller file sizes reduce transfer costs

### Next Steps

1. Continue with [DNS and SSL Setup](./dns-ssl-setup.md)
2. Configure [Auto-scaling](./scaling-configuration.md)
3. Set up [Monitoring and Alerting](../monitoring/azure-monitor-setup.md)
4. Implement [CI/CD Pipeline](../cicd/github-actions-setup.md)
5. Review [Security Hardening](../infrastructure/bicep-templates.md)

## Production Readiness Checklist

- [ ] All tests passing
- [ ] Performance benchmarks established
- [ ] Monitoring and alerting configured
- [ ] Cache purge automation working
- [ ] SSL certificates valid and auto-renewing
- [ ] WAF rules tuned and tested
- [ ] Cost monitoring in place
- [ ] Documentation updated
- [ ] Team trained on CDN management
- [ ] Disaster recovery procedures tested
