# Staging Environment Configuration Guide

This guide provides comprehensive configuration for the staging environment of the headless WordPress + Next.js solution, designed for testing, validation, and pre-production verification.

## Prerequisites

- Azure infrastructure setup completed ([Azure Setup Guide](../azure/azure-setup-guide.md))
- CI/CD pipeline configured ([GitHub Actions Setup](../cicd/github-actions-setup.md))
- Development environment tested locally

## Staging Environment Purpose

The staging environment serves as:
- **Pre-production testing** environment
- **Integration testing** platform
- **Performance validation** environment
- **User acceptance testing** (UAT) platform
- **Security testing** environment
- **CI/CD pipeline validation** stage

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Staging Environment                              │
│                 (Cost-optimized for testing)                        │
└─────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Azure Front Door                             │
│                   (Standard Tier - WAF)                           │
└─────────────────────────────────────────────────────────────────────┘
                                        │
              ┌─────────────────────────┴─────────────────────────┐
              │                                                        │
              ▼                                                        ▼
    ┌──────────────────────┐                        ┌──────────────────────┐
    │   Static Web App      │                        │   Container          │
    │   (Staging)           │                        │   Instances           │
    │                      │                        │   (Standard tier)     │
    │   Next.js Frontend    │                        │                     │
    │   - Testing branch    │                        │   WordPress Backend   │
    │   - Preview builds    │                        │   - Debug enabled     │
    └──────────────────────┘                        └──────────────────────┘
                                                                    │
                                                                    ▼
    ┌──────────────────────┐     ┌──────────────────────┐     ┌──────────────────────┐
    │   MySQL Flexible     │     │   Redis Basic       │     │   Azure Storage     │
    │   Server (Burstable) │     │   Cache             │     │   (Standard LRS)    │
    │                      │     │                   │     │                   │
    │   - B2s instance      │     │   - C0 (250MB)      │     │   - Test data       │
    │   - 7-day backup      │     │   - No persistence  │     │   - Temporary files │
    └──────────────────────┘     └──────────────────────┘     └──────────────────────┘
```

## Step 1: Staging Environment Setup

### 1.1 Create Staging Resource Group

```bash
# Source production environment variables
source .env.azure

# Create staging-specific variables
export ENVIRONMENT="staging"
export RESOURCE_GROUP_STAGING="rg-wordpress-nextjs-staging"
export LOCATION_STAGING="East US"  # Same region as production for simplicity

# Create staging resource group
az group create \
  --name $RESOURCE_GROUP_STAGING \
  --location "$LOCATION_STAGING" \
  --tags project=$PROJECT_NAME environment=staging

echo "Staging resource group created: $RESOURCE_GROUP_STAGING"
```

### 1.2 Staging Environment Variables

```bash
# Create staging environment configuration
cat > .env.staging << 'EOF'
# Staging Environment Configuration
ENVIRONMENT=staging
NODE_ENV=staging

# Azure Configuration
AZURE_REGION=eastus
RESOURCE_GROUP=rg-wordpress-nextjs-staging

# Performance Settings (Reduced for cost)
CACHE_TTL_STATIC=3600     # 1 hour (vs 1 year in prod)
CACHE_TTL_API=60          # 1 minute (vs 5 minutes in prod)
CACHE_TTL_HTML=300        # 5 minutes (vs 1 hour in prod)
MAX_CONCURRENT_REQUESTS=50 # Reduced from prod
CONNECTION_POOL_SIZE=5    # Reduced from prod
TIMEOUT_REQUEST=30
TIMEOUT_RESPONSE=60

# Security Settings (Basic protection)
ENABLE_WAF=true
ENABLE_DDOS_PROTECTION=false  # Cost optimization
ENABLE_SSL_ONLY=true
MIN_TLS_VERSION=1.2
ENABLE_HSTS=true
CSP_ENABLED=true

# Debug and Testing Settings
ENABLE_DEBUG_MODE=true
LOG_LEVEL=debug
ENABLE_DETAILED_ERRORS=true
ENABLE_QUERY_LOGGING=true
ENABLE_PERFORMANCE_PROFILING=true

# Monitoring Settings
ENABLE_APPLICATION_INSIGHTS=true
ENABLE_CUSTOM_METRICS=true
ALERT_EMAIL=staging@yourdomain.com

# Backup Settings (Minimal)
BACKUP_RETENTION_DAYS=7
BACKUP_FREQUENCY_HOURS=24
ENABLE_GEO_BACKUP=false

# Content Settings
MAX_UPLOAD_SIZE=10MB      # Reduced from prod
ALLOWED_FILE_TYPES=jpg,jpeg,png,gif,pdf
MEDIA_CDN_ENABLED=true
IMAGE_OPTIMIZATION=false  # Disabled for faster testing
ENABLE_WEBP=false

# WordPress Settings (Debug enabled)
WP_DEBUG=true
WP_DEBUG_LOG=true
WP_DEBUG_DISPLAY=true
WP_CACHE=true
WP_REDIS_ENABLED=true
WP_OBJECT_CACHE=true
AUTOSAVE_INTERVAL=60      # More frequent for testing
POST_REVISIONS=10         # More revisions for testing
EMPTY_TRASH_DAYS=7

# Testing Settings
ENABLE_TEST_DATA=true
ENABLE_SAMPLE_CONTENT=true
ENABLE_PREVIEW_MODE=true
ENABLE_DRAFT_MODE=true

# Rate Limiting (Relaxed)
RATE_LIMIT_REQUESTS_PER_MINUTE=120
RATE_LIMIT_BURST=20
RATE_LIMIT_API_REQUESTS_PER_MINUTE=200

# CI/CD Testing
ENABLE_BRANCH_DEPLOYS=true
ENABLE_PR_PREVIEWS=true
ENABLE_AUTO_TESTING=true
EOF
```

### 1.3 Next.js Staging Configuration

```bash
# Create Next.js staging configuration
cat > frontend/.env.staging << 'EOF'
# Next.js Staging Environment
NODE_ENV=staging
NEXT_TELEMETRY_DISABLED=0  # Enable for testing insights

# WordPress API Configuration
WORDPRESS_GRAPHQL_ENDPOINT=https://staging-api.yourdomain.com/graphql
NEXT_PUBLIC_WORDPRESS_URL=https://staging-api.yourdomain.com
WORDPRESS_API_URL=https://staging-api.yourdomain.com/wp-json/wp/v2

# Site Configuration
NEXT_PUBLIC_SITE_URL=https://staging.yourdomain.com
NEXT_PUBLIC_SITE_NAME="Staging - WordPress + Next.js Site"
NEXT_PUBLIC_SITE_DESCRIPTION="Staging environment for testing"

# CDN Configuration
NEXT_PUBLIC_CDN_URL=https://staging-cdn.yourdomain.com
NEXT_PUBLIC_MEDIA_URL=https://staging-media.yourdomain.com
IMAGE_DOMAINS=staging-cdn.yourdomain.com,staging-media.yourdomain.com

# Performance Settings (Faster rebuild for testing)
REVALIDATE_TIME=60        # 1 minute (vs 1 hour in prod)
REVALIDATE_ON_DEMAND=true
STATIC_GENERATION_TIMEOUT=30  # Reduced timeout
SERVERLESS_FUNCTION_TIMEOUT=15

# Debug Settings
DEBUG=true
NEXT_DEBUG=true
NEXT_PUBLIC_DEBUG=true

# Analytics and Monitoring (Staging versions)
NEXT_PUBLIC_GA_ID=G-STAGING-ID
NEXT_PUBLIC_GTM_ID=GTM-STAGING
APPLICATION_INSIGHTS_CONNECTION_STRING="InstrumentationKey=staging-key"
SENTRY_DSN=https://staging-sentry-dsn

# Testing Settings
ENABLE_PREVIEW_MODE=true
ENABLE_DRAFT_MODE=true
ENABLE_PWA=false          # Disabled for easier testing
ENABLE_SERVICE_WORKER=false

# Security Settings (Relaxed for testing)
NEXT_PUBLIC_CSP_NONCE=false
SECURE_HEADERS=false
HSTS_MAX_AGE=0

# Testing Features
NEXT_PUBLIC_ENABLE_TEST_FEATURES=true
NEXT_PUBLIC_SHOW_DEBUG_INFO=true
NEXT_PUBLIC_ENABLE_PERFORMANCE_METRICS=true
EOF
```

## Step 2: Staging Infrastructure Deployment

### 2.1 Database Setup (Cost-Optimized)

```bash
# Create staging MySQL server (Burstable tier)
export MYSQL_SERVER_STAGING="mysql-${PROJECT_NAME}-staging"
export MYSQL_DATABASE_STAGING="wordpress_staging"
export MYSQL_ADMIN_USER_STAGING="wpadmin"
export MYSQL_ADMIN_PASSWORD_STAGING=$(openssl rand -base64 32)

# Create MySQL Flexible Server (Burstable tier for cost optimization)
az mysql flexible-server create \
  --name $MYSQL_SERVER_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --location "$LOCATION_STAGING" \
  --admin-user $MYSQL_ADMIN_USER_STAGING \
  --admin-password "$MYSQL_ADMIN_PASSWORD_STAGING" \
  --sku-name Standard_B2s \
  --tier Burstable \
  --storage-size 32 \
  --storage-auto-grow Enabled \
  --backup-retention 7 \
  --geo-redundant-backup Disabled \
  --tags project=$PROJECT_NAME environment=staging

# Create WordPress database
az mysql flexible-server db create \
  --resource-group $RESOURCE_GROUP_STAGING \
  --server-name $MYSQL_SERVER_STAGING \
  --database-name $MYSQL_DATABASE_STAGING

# Configure for testing/development
az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP_STAGING \
  --server-name $MYSQL_SERVER_STAGING \
  --name slow_query_log \
  --value ON

az mysql flexible-server parameter set \
  --resource-group $RESOURCE_GROUP_STAGING \
  --server-name $MYSQL_SERVER_STAGING \
  --name long_query_time \
  --value 1.0  # Lower threshold for staging

echo "MySQL server created: $MYSQL_SERVER_STAGING"
```

### 2.2 Redis Cache Setup (Basic Tier)

```bash
# Create Redis cache (Basic tier for cost optimization)
export REDIS_CACHE_STAGING="redis-${PROJECT_NAME}-staging"

az redis create \
  --name $REDIS_CACHE_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --location "$LOCATION_STAGING" \
  --sku Basic \
  --vm-size c0 \
  --redis-version 6 \
  --minimum-tls-version 1.2 \
  --tags project=$PROJECT_NAME environment=staging

# Get Redis connection details
export REDIS_PRIMARY_KEY_STAGING=$(az redis list-keys \
  --name $REDIS_CACHE_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --query primaryKey -o tsv)

export REDIS_HOSTNAME_STAGING=$(az redis show \
  --name $REDIS_CACHE_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --query hostName -o tsv)

echo "Redis cache created: $REDIS_CACHE_STAGING"
```

### 2.3 Storage Account for Staging

```bash
# Create staging storage account
export STORAGE_ACCOUNT_STAGING="st${PROJECT_NAME}staging$(date +%s | tail -c 5)"
export MEDIA_CONTAINER_STAGING="staging-media"

az storage account create \
  --name $STORAGE_ACCOUNT_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --location "$LOCATION_STAGING" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --access-tier Hot \
  --allow-blob-public-access true \
  --tags project=$PROJECT_NAME environment=staging

# Get storage account key
export STORAGE_ACCOUNT_KEY_STAGING=$(az storage account keys list \
  --resource-group $RESOURCE_GROUP_STAGING \
  --account-name $STORAGE_ACCOUNT_STAGING \
  --query '[0].value' -o tsv)

# Create media container
az storage container create \
  --name $MEDIA_CONTAINER_STAGING \
  --account-name $STORAGE_ACCOUNT_STAGING \
  --account-key $STORAGE_ACCOUNT_KEY_STAGING \
  --public-access blob

echo "Storage account created: $STORAGE_ACCOUNT_STAGING"
```

### 2.4 Key Vault for Staging Secrets

```bash
# Create Key Vault for staging
export KEY_VAULT_STAGING="kv-${PROJECT_NAME}-staging-$(date +%s | tail -c 5)"

az keyvault create \
  --name $KEY_VAULT_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --location "$LOCATION_STAGING" \
  --sku standard \
  --enable-rbac-authorization true \
  --tags project=$PROJECT_NAME environment=staging

# Store staging credentials
az keyvault secret set \
  --vault-name $KEY_VAULT_STAGING \
  --name "mysql-admin-username" \
  --value $MYSQL_ADMIN_USER_STAGING

az keyvault secret set \
  --vault-name $KEY_VAULT_STAGING \
  --name "mysql-admin-password" \
  --value "$MYSQL_ADMIN_PASSWORD_STAGING"

az keyvault secret set \
  --vault-name $KEY_VAULT_STAGING \
  --name "redis-connection-string" \
  --value "$REDIS_HOSTNAME_STAGING:6380,password=$REDIS_PRIMARY_KEY_STAGING,ssl=True,abortConnect=False"

az keyvault secret set \
  --vault-name $KEY_VAULT_STAGING \
  --name "storage-account-name" \
  --value $STORAGE_ACCOUNT_STAGING

az keyvault secret set \
  --vault-name $KEY_VAULT_STAGING \
  --name "storage-account-key" \
  --value "$STORAGE_ACCOUNT_KEY_STAGING"

echo "Key Vault created: $KEY_VAULT_STAGING"
```

## Step 3: Container and Application Setup

### 3.1 WordPress Container Deployment

```bash
# Create staging WordPress container
export CONTAINER_STAGING="ci-wordpress-staging"
export CONTAINER_DNS_STAGING="wordpress-${PROJECT_NAME}-staging"

# Generate WordPress secrets for staging
export WP_AUTH_KEY_STAGING=$(openssl rand -base64 48)
export WP_SECURE_AUTH_KEY_STAGING=$(openssl rand -base64 48)
export WP_LOGGED_IN_KEY_STAGING=$(openssl rand -base64 48)
export WP_NONCE_KEY_STAGING=$(openssl rand -base64 48)

# Create container with staging configuration
az container create \
  --resource-group $RESOURCE_GROUP_STAGING \
  --name $CONTAINER_STAGING \
  --image ${ACR_NAME}.azurecr.io/wordpress-headless:latest \
  --registry-login-server ${ACR_NAME}.azurecr.io \
  --registry-username $(az keyvault secret show --vault-name $KEY_VAULT_NAME --name "acr-username" --query value -o tsv) \
  --registry-password "$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name "acr-password" --query value -o tsv)" \
  --dns-name-label $CONTAINER_DNS_STAGING \
  --ports 80 \
  --cpu 1 \
  --memory 2 \
  --location "$LOCATION_STAGING" \
  --restart-policy OnFailure \
  --environment-variables \
    WORDPRESS_DB_HOST="${MYSQL_SERVER_STAGING}.mysql.database.azure.com" \
    WORDPRESS_DB_NAME="$MYSQL_DATABASE_STAGING" \
    WORDPRESS_DB_USER="$MYSQL_ADMIN_USER_STAGING" \
    WORDPRESS_DB_PASSWORD="$MYSQL_ADMIN_PASSWORD_STAGING" \
    WORDPRESS_ENV="staging" \
    WP_DEBUG="true" \
    WP_DEBUG_LOG="true" \
    WP_DEBUG_DISPLAY="true" \
    REDIS_CONNECTION_STRING="$REDIS_HOSTNAME_STAGING:6380,password=$REDIS_PRIMARY_KEY_STAGING,ssl=True" \
    WORDPRESS_AUTH_KEY="$WP_AUTH_KEY_STAGING" \
    WORDPRESS_SECURE_AUTH_KEY="$WP_SECURE_AUTH_KEY_STAGING" \
    WORDPRESS_LOGGED_IN_KEY="$WP_LOGGED_IN_KEY_STAGING" \
    WORDPRESS_NONCE_KEY="$WP_NONCE_KEY_STAGING" \
    AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT_STAGING" \
    AZURE_STORAGE_KEY="$STORAGE_ACCOUNT_KEY_STAGING" \
    AZURE_STORAGE_CONTAINER="$MEDIA_CONTAINER_STAGING" \
  --tags project=$PROJECT_NAME environment=staging

# Get container URL
export WORDPRESS_URL_STAGING=$(az container show \
  --resource-group $RESOURCE_GROUP_STAGING \
  --name $CONTAINER_STAGING \
  --query ipAddress.fqdn -o tsv)

echo "WordPress container created: http://$WORDPRESS_URL_STAGING"
```

### 3.2 Static Web App for Frontend

```bash
# Create staging Static Web App
export STATICWEB_STAGING="stapp-${PROJECT_NAME}-staging"

az staticwebapp create \
  --name $STATICWEB_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --location "East US 2" \
  --source "https://github.com/andy-lynch-granite/wordpress-nextjs-starter" \
  --branch develop \
  --app-location "/frontend" \
  --api-location "" \
  --output-location "out" \
  --tags project=$PROJECT_NAME environment=staging

# Configure environment variables for staging
az staticwebapp appsettings set \
  --name $STATICWEB_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --setting-names \
    WORDPRESS_GRAPHQL_ENDPOINT="http://$WORDPRESS_URL_STAGING/graphql" \
    NEXT_PUBLIC_WORDPRESS_URL="http://$WORDPRESS_URL_STAGING" \
    NODE_ENV="staging" \
    NEXT_PUBLIC_ENVIRONMENT="staging" \
    REVALIDATE_TIME="60" \
    DEBUG="true"

# Get Static Web App URL
export STATIC_WEB_APP_URL_STAGING=$(az staticwebapp show \
  --name $STATICWEB_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --query defaultHostname -o tsv)

echo "Static Web App created: https://$STATIC_WEB_APP_URL_STAGING"
```

## Step 4: CDN and Performance Configuration

### 4.1 Front Door Setup (Standard Tier)

```bash
# Create Front Door profile for staging (Standard tier)
export FRONT_DOOR_STAGING="fd-${PROJECT_NAME}-staging"
export FRONT_DOOR_ENDPOINT_STAGING="${PROJECT_NAME}-staging"

az afd profile create \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --sku Standard_AzureFrontDoor \
  --tags project=$PROJECT_NAME environment=staging

# Create endpoint
az afd endpoint create \
  --endpoint-name $FRONT_DOOR_ENDPOINT_STAGING \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --enabled-state Enabled

# Get Front Door hostname
export FRONT_DOOR_HOSTNAME_STAGING=$(az afd endpoint show \
  --endpoint-name $FRONT_DOOR_ENDPOINT_STAGING \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --query hostName -o tsv)

echo "Front Door created: https://$FRONT_DOOR_HOSTNAME_STAGING"
```

### 4.2 Origin Configuration

```bash
# Create origin groups
az afd origin-group create \
  --origin-group-name "staging-frontend" \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --load-balancing-sample-size 4 \
  --load-balancing-successful-samples-required 2 \
  --probe-interval-in-seconds 60 \
  --probe-path "/" \
  --probe-protocol Https \
  --probe-request-type GET

az afd origin-group create \
  --origin-group-name "staging-backend" \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --load-balancing-sample-size 4 \
  --load-balancing-successful-samples-required 2 \
  --probe-interval-in-seconds 60 \
  --probe-path "/wp-json/wp/v2/" \
  --probe-protocol Http \
  --probe-request-type GET

# Add origins
az afd origin create \
  --origin-name "staging-frontend-origin" \
  --origin-group-name "staging-frontend" \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --host-name $STATIC_WEB_APP_URL_STAGING \
  --origin-host-header $STATIC_WEB_APP_URL_STAGING \
  --https-port 443 \
  --priority 1 \
  --weight 1000 \
  --enabled-state Enabled

az afd origin create \
  --origin-name "staging-backend-origin" \
  --origin-group-name "staging-backend" \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --host-name $WORDPRESS_URL_STAGING \
  --origin-host-header $WORDPRESS_URL_STAGING \
  --http-port 80 \
  --priority 1 \
  --weight 1000 \
  --enabled-state Enabled

# Create routes
az afd route create \
  --route-name "staging-frontend-route" \
  --endpoint-name $FRONT_DOOR_ENDPOINT_STAGING \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --origin-group "staging-frontend" \
  --supported-protocols Http Https \
  --patterns-to-match "/*" \
  --forwarding-protocol HttpsOnly \
  --https-redirect Enabled \
  --enabled-state Enabled

az afd route create \
  --route-name "staging-backend-route" \
  --endpoint-name $FRONT_DOOR_ENDPOINT_STAGING \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --origin-group "staging-backend" \
  --supported-protocols Http Https \
  --patterns-to-match "/api/*" "/graphql" "/wp-json/*" \
  --forwarding-protocol MatchRequest \
  --enabled-state Enabled
```

### 4.3 Staging-Specific Caching Rules

```bash
# Create staging caching rules (shorter cache times for testing)
az afd rule-set create \
  --rule-set-name "staging-cache-rules" \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING

# Short cache for images (1 hour vs 1 year in prod)
az afd rule create \
  --rule-name "cache-images-short" \
  --rule-set-name "staging-cache-rules" \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --order 1 \
  --conditions \
    '[{"name":"UrlFileExtension","parameters":{"operator":"Equal","matchValues":["jpg","jpeg","png","gif","webp","svg","ico"]}}]' \
  --actions \
    '[{"name":"CacheExpiration","parameters":{"cacheBehavior":"Override","cacheType":"All","cacheDuration":"1.00:00:00"}}]'

# Very short cache for API responses (30 seconds)
az afd rule create \
  --rule-name "cache-api-minimal" \
  --rule-set-name "staging-cache-rules" \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --order 2 \
  --conditions \
    '[{"name":"UrlPath","parameters":{"operator":"BeginsWith","matchValues":["/wp-json/","/graphql"]}}]' \
  --actions \
    '[{"name":"CacheExpiration","parameters":{"cacheBehavior":"Override","cacheType":"All","cacheDuration":"0.00:00:30"}}]'

# No cache for HTML in staging
az afd rule create \
  --rule-name "no-cache-html" \
  --rule-set-name "staging-cache-rules" \
  --profile-name $FRONT_DOOR_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --order 3 \
  --conditions \
    '[{"name":"UrlFileExtension","parameters":{"operator":"Equal","matchValues":["html","htm"]}}]' \
  --actions \
    '[{"name":"CacheExpiration","parameters":{"cacheBehavior":"Override","cacheType":"All","cacheDuration":"0.00:00:00"}}]'
```

## Step 5: Monitoring and Application Insights

### 5.1 Application Insights for Staging

```bash
# Create Log Analytics workspace for staging
export LOG_ANALYTICS_STAGING="log-${PROJECT_NAME}-staging"

az monitor log-analytics workspace create \
  --workspace-name $LOG_ANALYTICS_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --location "$LOCATION_STAGING" \
  --sku PerGB2018 \
  --retention-time 30 \
  --tags project=$PROJECT_NAME environment=staging

# Create Application Insights for staging
export APP_INSIGHTS_STAGING="appi-${PROJECT_NAME}-staging"

az monitor app-insights component create \
  --app $APP_INSIGHTS_STAGING \
  --location "$LOCATION_STAGING" \
  --resource-group $RESOURCE_GROUP_STAGING \
  --workspace $LOG_ANALYTICS_STAGING \
  --tags project=$PROJECT_NAME environment=staging

# Get instrumentation key
export INSTRUMENTATION_KEY_STAGING=$(az monitor app-insights component show \
  --app $APP_INSIGHTS_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --query instrumentationKey -o tsv)

# Store in Key Vault
az keyvault secret set \
  --vault-name $KEY_VAULT_STAGING \
  --name "app-insights-key" \
  --value "$INSTRUMENTATION_KEY_STAGING"

echo "Application Insights created: $APP_INSIGHTS_STAGING"
```

### 5.2 Basic Alerts for Staging

```bash
# Create action group for staging alerts
export ACTION_GROUP_STAGING="ag-${PROJECT_NAME}-staging"

az monitor action-group create \
  --name $ACTION_GROUP_STAGING \
  --resource-group $RESOURCE_GROUP_STAGING \
  --short-name "StagingAlt" \
  --email-receivers name="StagingAdmin" email="staging@yourdomain.com" \
  --webhook-receivers name="Slack" service-uri="$SLACK_WEBHOOK_URL"

# Create basic error rate alert
az monitor metrics alert create \
  --name "Staging High Error Rate" \
  --resource-group $RESOURCE_GROUP_STAGING \
  --condition "avg exceptions/performanceCounters/exceptionsPerSecond > 5" \
  --window-size 10m \
  --evaluation-frequency 5m \
  --severity 3 \
  --description "High error rate detected in staging" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_STAGING/providers/Microsoft.Insights/components/$APP_INSIGHTS_STAGING" \
  --action $ACTION_GROUP_STAGING

echo "Staging monitoring configured"
```

## Step 6: Testing and Quality Assurance Features

### 6.1 Test Data Setup

```bash
# Create test data setup script
cat > setup-staging-data.sh << 'EOF'
#!/bin/bash

# Staging test data setup script
set -e

echo "Setting up staging test data..."

# Wait for WordPress to be ready
echo "Waiting for WordPress to be available..."
until curl -f http://$WORDPRESS_URL_STAGING/wp-json/wp/v2/ > /dev/null 2>&1; do
    sleep 10
    echo "Still waiting for WordPress..."
done

echo "WordPress is ready, installing test data..."

# Install and activate required plugins
az container exec \
  --resource-group $RESOURCE_GROUP_STAGING \
  --name $CONTAINER_STAGING \
  --exec-command "/bin/bash -c '
    # Install WP-GraphQL
    wp plugin install wp-graphql --activate --allow-root
    
    # Install Advanced Custom Fields
    wp plugin install advanced-custom-fields --activate --allow-root
    
    # Install WPGraphQL for ACF
    wp plugin install wp-graphql-acf --activate --allow-root
    
    # Install Redis Object Cache
    wp plugin install redis-cache --activate --allow-root
    wp redis enable --allow-root
    
    # Install WordPress Importer
    wp plugin install wordpress-importer --activate --allow-root
    
    # Create test users
    wp user create editor editor@staging.com --role=editor --user_pass=StagingPass123! --allow-root
    wp user create author author@staging.com --role=author --user_pass=StagingPass123! --allow-root
    wp user create subscriber subscriber@staging.com --role=subscriber --user_pass=StagingPass123! --allow-root
    
    # Import sample content
    wp post generate --count=50 --post_type=post --post_status=publish --allow-root
    wp post generate --count=10 --post_type=page --post_status=publish --allow-root
    
    # Create sample categories and tags
    wp term create category "Technology" --slug=technology --allow-root
    wp term create category "Business" --slug=business --allow-root
    wp term create category "Design" --slug=design --allow-root
    wp term create post_tag "staging" --slug=staging --allow-root
    wp term create post_tag "testing" --slug=testing --allow-root
    wp term create post_tag "development" --slug=development --allow-root
    
    # Set permalink structure
    wp rewrite structure "/%postname%/" --allow-root
    
    # Update site settings
    wp option update blogname "Staging - WordPress + Next.js" --allow-root
    wp option update blogdescription "Staging environment for testing and development" --allow-root
    wp option update admin_email "staging@yourdomain.com" --allow-root
    
    # Enable debugging
    wp config set WP_DEBUG true --raw --type=constant --allow-root
    wp config set WP_DEBUG_LOG true --raw --type=constant --allow-root
    wp config set WP_DEBUG_DISPLAY true --raw --type=constant --allow-root
    
    echo "Test data setup completed!"
    '"

echo "Staging environment is ready for testing!"
echo "WordPress Admin: http://$WORDPRESS_URL_STAGING/wp-admin"
echo "Frontend: https://$STATIC_WEB_APP_URL_STAGING"
echo "GraphQL: http://$WORDPRESS_URL_STAGING/graphql"
EOF

chmod +x setup-staging-data.sh
./setup-staging-data.sh
```

### 6.2 Automated Testing Configuration

```bash
# Create staging test configuration
cat > .github/workflows/staging-tests.yml << 'EOF'
name: Staging Environment Tests

on:
  schedule:
    - cron: '0 */4 * * *'  # Every 4 hours
  workflow_dispatch:
  deployment_status:

jobs:
  staging-smoke-tests:
    runs-on: ubuntu-latest
    if: github.event.deployment_status.state == 'success' && github.event.deployment_status.environment == 'staging'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'

      - name: Install dependencies
        working-directory: ./tests
        run: npm install

      - name: Run smoke tests
        working-directory: ./tests
        env:
          STAGING_FRONTEND_URL: ${{ secrets.STAGING_FRONTEND_URL }}
          STAGING_BACKEND_URL: ${{ secrets.STAGING_BACKEND_URL }}
        run: |
          npm run test:smoke:staging

      - name: Run API tests
        working-directory: ./tests
        env:
          STAGING_BACKEND_URL: ${{ secrets.STAGING_BACKEND_URL }}
        run: |
          npm run test:api:staging

      - name: Run accessibility tests
        working-directory: ./tests
        env:
          STAGING_FRONTEND_URL: ${{ secrets.STAGING_FRONTEND_URL }}
        run: |
          npm run test:a11y:staging

      - name: Performance audit
        uses: treosh/lighthouse-ci-action@v10
        with:
          urls: |
            ${{ secrets.STAGING_FRONTEND_URL }}
          configPath: .github/lighthouse/staging.json
          uploadArtifacts: true
          temporaryPublicStorage: true

      - name: Notify on failure
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: failure
          channel: '#staging'
          text: |
            Staging environment tests failed!
            Please investigate the staging environment.
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
EOF
```

## Step 7: CI/CD Integration

### 7.1 GitHub Secrets for Staging

Add the following secrets to your GitHub repository:

```bash
# Staging-specific secrets
echo "Add these secrets to GitHub repository:"
echo "STAGING_RESOURCE_GROUP=$RESOURCE_GROUP_STAGING"
echo "STAGING_CONTAINER_NAME=$CONTAINER_STAGING"
echo "STAGING_STATIC_WEB_APP_NAME=$STATICWEB_STAGING"
echo "STAGING_MYSQL_SERVER_NAME=$MYSQL_SERVER_STAGING"
echo "STAGING_REDIS_CACHE_NAME=$REDIS_CACHE_STAGING"
echo "STAGING_KEY_VAULT_NAME=$KEY_VAULT_STAGING"
echo "STAGING_FRONT_DOOR_NAME=$FRONT_DOOR_STAGING"
echo "STAGING_FRONTEND_URL=https://$STATIC_WEB_APP_URL_STAGING"
echo "STAGING_BACKEND_URL=http://$WORDPRESS_URL_STAGING"
```

### 7.2 Branch-based Deployment

```bash
# Update the main deployment workflow to handle staging
cat >> .github/workflows/deploy.yml << 'EOF'

  deploy-to-staging:
    runs-on: ubuntu-latest
    needs: [test-and-quality, build-images]
    if: github.ref == 'refs/heads/develop'
    environment: staging
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Deploy to staging
        run: |
          # Update staging container
          az container update \
            --resource-group ${{ secrets.STAGING_RESOURCE_GROUP }} \
            --name ${{ secrets.STAGING_CONTAINER_NAME }} \
            --image ${{ secrets.AZURE_ACR_NAME }}.azurecr.io/wordpress-headless:${{ github.sha }}

      - name: Wait for deployment
        run: |
          echo "Waiting for staging deployment to complete..."
          sleep 60

      - name: Run staging tests
        uses: ./.github/workflows/staging-tests.yml

      - name: Notify staging deployment
        uses: 8398a7/action-slack@v3
        with:
          status: success
          channel: '#staging'
          text: |
            Staging deployment completed!
            
            Branch: ${{ github.ref_name }}
            Commit: ${{ github.sha }}
            Frontend: https://${{ secrets.STAGING_FRONTEND_URL }}
            Backend: ${{ secrets.STAGING_BACKEND_URL }}
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
EOF
```

## Step 8: Cost Management and Optimization

### 8.1 Cost Monitoring

```bash
# Create cost alert for staging
az consumption budget create \
  --budget-name "staging-budget" \
  --amount 100 \
  --category Cost \
  --start-date "$(date +%Y-%m-01)" \
  --end-date "$(date -d '+1 year' +%Y-%m-01)" \
  --time-grain Monthly \
  --time-period-start "$(date +%Y-%m-01)" \
  --time-period-end "$(date -d '+1 year' +%Y-%m-01)" \
  --resource-groups $RESOURCE_GROUP_STAGING \
  --notifications \
    '[{"enabled":true,"operator":"GreaterThan","threshold":80,"contactEmails":["admin@yourdomain.com"],"contactRoles":["Owner"]}]'

echo "Cost monitoring configured for staging"
```

### 8.2 Automated Shutdown (Cost Optimization)

```bash
# Create auto-shutdown script for staging (run during off-hours)
cat > staging-shutdown.sh << 'EOF'
#!/bin/bash

# Auto-shutdown script for staging environment (cost optimization)
set -e

echo "Shutting down staging environment for cost optimization..."

# Stop container instance
az container stop \
  --resource-group $RESOURCE_GROUP_STAGING \
  --name $CONTAINER_STAGING

# Stop MySQL server (if supported)
# Note: Flexible server doesn't support stop/start, only delete/recreate

echo "Staging environment shut down completed"
EOF

chmod +x staging-shutdown.sh

# Create startup script
cat > staging-startup.sh << 'EOF'
#!/bin/bash

# Auto-startup script for staging environment
set -e

echo "Starting up staging environment..."

# Start container instance
az container start \
  --resource-group $RESOURCE_GROUP_STAGING \
  --name $CONTAINER_STAGING

echo "Staging environment startup completed"
EOF

chmod +x staging-startup.sh

# Schedule shutdown/startup (example: shutdown at 8 PM, startup at 8 AM)
# echo "0 20 * * 1-5 /path/to/staging-shutdown.sh" | crontab -
# echo "0 8 * * 1-5 /path/to/staging-startup.sh" | crontab -
```

## Step 9: Documentation and Team Access

### 9.1 Staging Environment Documentation

```bash
cat > staging-environment-guide.md << 'EOF'
# Staging Environment Guide

## Access Information

### URLs
- **Frontend**: https://STATIC_WEB_APP_URL_STAGING
- **Backend Admin**: http://WORDPRESS_URL_STAGING/wp-admin
- **GraphQL Playground**: http://WORDPRESS_URL_STAGING/graphql
- **API Endpoint**: http://WORDPRESS_URL_STAGING/wp-json/wp/v2/

### Test Accounts
- **Admin**: admin / (generated password in Key Vault)
- **Editor**: editor@staging.com / StagingPass123!
- **Author**: author@staging.com / StagingPass123!
- **Subscriber**: subscriber@staging.com / StagingPass123!

## Purpose and Usage

### What is Staging For?
1. **Pre-production Testing**: Test features before production deployment
2. **Integration Testing**: Validate API integrations and third-party services
3. **Performance Testing**: Load testing and performance validation
4. **User Acceptance Testing**: Client and stakeholder testing
5. **Security Testing**: Vulnerability and security assessments
6. **Content Testing**: Test content workflows and publishing

### What Staging is NOT for
1. **Development Work**: Use local development environment
2. **Experimentation**: Use feature branches and local testing
3. **Production Data**: Never use real user data in staging
4. **Long-term Storage**: Data may be reset regularly

## Testing Guidelines

### Automated Testing
- Smoke tests run every 4 hours
- API tests validate all endpoints
- Accessibility tests ensure WCAG compliance
- Performance tests monitor Core Web Vitals

### Manual Testing Checklist
- [ ] User registration and login flows
- [ ] Content creation and editing
- [ ] Media upload and management
- [ ] Search functionality
- [ ] Mobile responsiveness
- [ ] Cross-browser compatibility
- [ ] Performance on slow connections
- [ ] Accessibility with screen readers

## Environment Differences from Production

| Feature | Staging | Production |
|---------|---------|------------|
| Database Tier | Burstable B2s | General Purpose D4s |
| Redis Tier | Basic C0 | Premium P2 |
| CDN Caching | Short (1 hour) | Long (1 year) |
| SSL Certificate | Let's Encrypt | Azure Managed |
| Backup Retention | 7 days | 35 days |
| Debug Mode | Enabled | Disabled |
| Error Display | Visible | Hidden |
| Auto-scaling | Disabled | Enabled |
| DDoS Protection | Basic | Premium |
| WAF Rules | Basic | Advanced |

## Deployment Process

### Automatic Deployment
- **Trigger**: Push to `develop` branch
- **Process**: Build → Test → Deploy → Validate
- **Notifications**: Slack #staging channel

### Manual Deployment
- Use GitHub Actions workflow_dispatch
- Requires approval for production promotion
- Full testing required before promotion

## Troubleshooting

### Common Issues

1. **Container Not Starting**
   ```bash
   # Check container logs
   az container logs --resource-group $RESOURCE_GROUP_STAGING --name $CONTAINER_STAGING
   
   # Restart container
   az container restart --resource-group $RESOURCE_GROUP_STAGING --name $CONTAINER_STAGING
   ```

2. **Database Connection Issues**
   ```bash
   # Check database status
   az mysql flexible-server show --resource-group $RESOURCE_GROUP_STAGING --name $MYSQL_SERVER_STAGING
   
   # Test connection
   mysql --host=${MYSQL_SERVER_STAGING}.mysql.database.azure.com --user=$MYSQL_ADMIN_USER_STAGING --password --ssl-mode=REQUIRED
   ```

3. **Static Web App Build Failures**
   - Check GitHub Actions logs
   - Verify environment variables
   - Test build locally

4. **Performance Issues**
   - Check Application Insights
   - Review slow query log
   - Monitor resource utilization

### Getting Help
- **Slack**: #staging channel
- **Email**: staging@yourdomain.com
- **Documentation**: Link to full documentation
- **Incident Response**: Follow incident response procedures

## Data Management

### Test Data Reset
- Staging database is reset weekly
- Media files are cleaned up monthly
- Cache is cleared daily

### Data Privacy
- No production data in staging
- All test data is synthetic
- Personal information is anonymized

### Backup and Recovery
- 7-day retention for database backups
- Point-in-time recovery available
- Media files backed up to separate storage account
EOF
```

## Step 10: Final Configuration

### 10.1 Environment Variables Summary

```bash
# Update staging environment configuration
cat >> .env.staging << EOF

# Azure Resources
RESOURCE_GROUP_STAGING=$RESOURCE_GROUP_STAGING
LOCATION_STAGING="$LOCATION_STAGING"
MYSQL_SERVER_STAGING=$MYSQL_SERVER_STAGING
REDIS_CACHE_STAGING=$REDIS_CACHE_STAGING
STORAGE_ACCOUNT_STAGING=$STORAGE_ACCOUNT_STAGING
KEY_VAULT_STAGING=$KEY_VAULT_STAGING
CONTAINER_STAGING=$CONTAINER_STAGING
STATICWEB_STAGING=$STATICWEB_STAGING
FRONT_DOOR_STAGING=$FRONT_DOOR_STAGING
APP_INSIGHTS_STAGING=$APP_INSIGHTS_STAGING

# URLs
WORDPRESS_URL_STAGING=http://$WORDPRESS_URL_STAGING
STATIC_WEB_APP_URL_STAGING=https://$STATIC_WEB_APP_URL_STAGING
FRONT_DOOR_HOSTNAME_STAGING=https://$FRONT_DOOR_HOSTNAME_STAGING

# Configuration
COST_BUDGET_LIMIT=100
AUTO_SHUTDOWN_ENABLED=true
TEST_DATA_ENABLED=true
DEBUG_MODE=true
PERFORMANCE_PROFILING=true

# Testing
SMOKE_TESTS_ENABLED=true
API_TESTS_ENABLED=true
PERFORMANCE_TESTS_ENABLED=true
ACCESSIBILITY_TESTS_ENABLED=true

# Monitoring
ALERT_THRESHOLD_ERRORS=5
ALERT_THRESHOLD_RESPONSE_TIME=5000
LOG_RETENTION_DAYS=30
METRICS_RETENTION_DAYS=30
EOF

echo "Staging environment configuration completed!"
echo "Configuration saved to .env.staging"
```

### 10.2 Staging Readiness Checklist

```bash
cat > staging-readiness-checklist.md << 'EOF'
# Staging Environment Readiness Checklist

## Infrastructure
- [ ] Resource group created
- [ ] MySQL Flexible Server deployed (Burstable tier)
- [ ] Redis Cache deployed (Basic tier)
- [ ] Storage Account configured
- [ ] Key Vault with secrets configured
- [ ] Virtual Network and security groups configured

## Applications
- [ ] WordPress container deployed and running
- [ ] Static Web App deployed and accessible
- [ ] Front Door configured with origins and routes
- [ ] CDN caching rules configured (staging-appropriate)

## Testing
- [ ] Test data and users created
- [ ] Required plugins installed and activated
- [ ] Sample content generated
- [ ] GraphQL endpoint accessible
- [ ] REST API endpoints accessible

## Monitoring
- [ ] Application Insights configured
- [ ] Log Analytics workspace setup
- [ ] Basic alerts configured
- [ ] Cost monitoring enabled
- [ ] Performance monitoring active

## CI/CD Integration
- [ ] GitHub secrets configured
- [ ] Staging deployment workflow tested
- [ ] Branch protection rules configured
- [ ] Automated tests running
- [ ] Notifications configured

## Security
- [ ] SSL certificates configured
- [ ] WAF basic rules enabled
- [ ] Network security groups configured
- [ ] Access controls validated
- [ ] Secrets management validated

## Documentation
- [ ] Environment access documentation created
- [ ] Testing guidelines documented
- [ ] Troubleshooting guide created
- [ ] Team access configured
- [ ] Incident response procedures documented

## Cost Management
- [ ] Budget alerts configured
- [ ] Auto-shutdown scripts created (optional)
- [ ] Resource utilization monitoring enabled
- [ ] Cost optimization measures implemented

## Quality Assurance
- [ ] Smoke tests passing
- [ ] API tests passing
- [ ] Performance tests configured
- [ ] Accessibility tests configured
- [ ] Load testing capability validated
EOF
```

## Summary

The staging environment provides:

- **Cost-optimized infrastructure** suitable for testing
- **Debug-enabled configuration** for troubleshooting
- **Automated testing integration** with CI/CD pipeline
- **Realistic production simulation** with appropriate trade-offs
- **Team collaboration features** for testing and validation
- **Cost management controls** to prevent budget overruns
- **Comprehensive monitoring** for issue detection
- **Easy reset and refresh** capabilities for clean testing

## Next Steps

1. Continue with [Development Environment](./development.md)
2. Set up [Infrastructure as Code](../infrastructure/bicep-templates.md)
3. Configure [Monitoring and Observability](../monitoring/azure-monitor-setup.md)
4. Implement [Disaster Recovery Testing](../backup-dr/testing-procedures.md)
5. Review [Environment Variables Reference](./environment-variables.md)

The staging environment is now ready to support your development workflow and provide confidence before production deployments.
