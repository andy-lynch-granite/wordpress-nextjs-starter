# Environment Variables Reference Guide

This comprehensive guide documents all environment variables used across the headless WordPress + Next.js application for development, staging, and production environments.

## Table of Contents

1. [Variable Categories](#variable-categories)
2. [WordPress Configuration](#wordpress-configuration)
3. [Database Configuration](#database-configuration)
4. [Redis Cache Configuration](#redis-cache-configuration)
5. [Next.js Frontend Configuration](#nextjs-frontend-configuration)
6. [Azure Services Configuration](#azure-services-configuration)
7. [Security and Authentication](#security-and-authentication)
8. [Monitoring and Logging](#monitoring-and-logging)
9. [Environment-Specific Values](#environment-specific-values)
10. [Secret Management](#secret-management)

## Variable Categories

### Variable Types and Sources

```yaml
Variable_Sources:
  Azure_Key_Vault:
    - Database passwords
    - Redis authentication keys
    - WordPress authentication keys
    - SSL certificate passwords
    - API keys and tokens
    
  GitHub_Secrets:
    - Azure service principal credentials
    - Container registry credentials
    - Deployment tokens
    
  Container_App_Environment:
    - Application runtime configuration
    - Service endpoints
    - Feature flags
    - Debug settings
    
  Static_Configuration:
    - Service names
    - Resource identifiers
    - Public endpoints
```

### Naming Conventions

```yaml
Naming_Patterns:
  General: "SERVICE_PURPOSE_MODIFIER"
  Examples:
    - WORDPRESS_DB_HOST
    - REDIS_CONNECTION_STRING
    - NEXT_PUBLIC_API_URL
    - AZURE_STORAGE_ACCOUNT_NAME
    
  Environment_Suffixes:
    - No suffix for current environment
    - _DEV, _STAGING, _PROD for cross-environment references
    
  Secret_References:
    - Prefix with KV_ for Key Vault references
    - Format: KV_SECRET_NAME for direct references
    - Format: @Microsoft.KeyVault(VaultName=...;SecretName=...) for Azure references
```

## WordPress Configuration

### Core WordPress Variables

```bash
# Database Connection
WORDPRESS_DB_HOST="mysql-wordpress-{env}.mysql.database.azure.com"
WORDPRESS_DB_NAME="wordpress"
WORDPRESS_DB_USER="dbadmin"
WORDPRESS_DB_PASSWORD="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=database-password)"
WORDPRESS_DB_CHARSET="utf8mb4"
WORDPRESS_DB_COLLATE="utf8mb4_unicode_ci"
WORDPRESS_TABLE_PREFIX="wp_"

# WordPress URLs
WORDPRESS_HOME="https://api.{domain}.com"
WORDPRESS_SITEURL="https://api.{domain}.com"
WORDPRESS_URL="https://api.{domain}.com"

# WordPress Debug and Development
WORDPRESS_DEBUG="{true|false}"
WORDPRESS_DEBUG_LOG="{true|false}"
WORDPRESS_DEBUG_DISPLAY="{true|false}"
SCRIPT_DEBUG="{true|false}"
WP_DEBUG_LOG="{true|false}"
WP_ENVIRONMENT_TYPE="{development|staging|production}"

# WordPress Configuration
WP_POST_REVISIONS="5"
AUTOSAVE_INTERVAL="300"
WP_MEMORY_LIMIT="256M"
WP_MAX_MEMORY_LIMIT="512M"
EMPTY_TRASH_DAYS="30"

# WordPress Security
DISALLOW_FILE_EDIT="true"
DISALLOW_FILE_MODS="true"
FORCE_SSL_ADMIN="true"
WP_AUTO_UPDATE_CORE="minor"
```

### WordPress Authentication Keys

```bash
# WordPress Authentication Keys (stored in Key Vault)
WORDPRESS_AUTH_KEY="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=wordpress-auth-key)"
WORDPRESS_SECURE_AUTH_KEY="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=wordpress-secure-auth-key)"
WORDPRESS_LOGGED_IN_KEY="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=wordpress-logged-in-key)"
WORDPRESS_NONCE_KEY="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=wordpress-nonce-key)"
WORDPRESS_AUTH_SALT="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=wordpress-auth-salt)"
WORDPRESS_SECURE_AUTH_SALT="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=wordpress-secure-auth-salt)"
WORDPRESS_LOGGED_IN_SALT="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=wordpress-logged-in-salt)"
WORDPRESS_NONCE_SALT="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=wordpress-nonce-salt)"
```

### WordPress Plugin Configuration

```bash
# GraphQL Configuration
GRAPHQL_DEBUG="{true|false}"
GRAPHQL_QUERY_COMPLEXITY_MAX="1000"
GRAPHQL_QUERY_DEPTH_MAX="15"
GRAPHQL_DISABLE_INTROSPECTION="{true|false}"
GRAPHQL_ENABLE_CORS="true"

# SEO and Performance
YOAST_SEO_ENVIRONMENT="{development|staging|production}"
WP_ROCKET_CACHE="{true|false}"
WP_ROCKET_MINIFY_CSS="{true|false}"
WP_ROCKET_MINIFY_JS="{true|false}"

# Email Configuration
WP_MAIL_SMTP_HOST="smtp.sendgrid.net"
WP_MAIL_SMTP_PORT="587"
WP_MAIL_SMTP_AUTH="true"
WP_MAIL_SMTP_SECURE="tls"
WP_MAIL_SMTP_USERNAME="apikey"
WP_MAIL_SMTP_PASSWORD="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=sendgrid-api-key)"
```

## Database Configuration

### MySQL Connection Variables

```bash
# Primary Database Connection
DB_HOST="mysql-wordpress-{env}.mysql.database.azure.com"
DB_PORT="3306"
DB_NAME="wordpress"
DB_USER="dbadmin"
DB_PASSWORD="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=database-password)"
DB_CHARSET="utf8mb4"
DB_COLLATE="utf8mb4_unicode_ci"

# Connection Pool Settings
DB_CONNECTION_TIMEOUT="30"
DB_MAX_CONNECTIONS="100"
DB_IDLE_TIMEOUT="300"
DB_POOL_SIZE="20"

# SSL Configuration
DB_SSL_MODE="REQUIRED"
DB_SSL_CERT_PATH="/var/ssl/mysql-client-cert.pem"
DB_SSL_KEY_PATH="/var/ssl/mysql-client-key.pem"
DB_SSL_CA_PATH="/var/ssl/mysql-ca-cert.pem"

# Read Replica Configuration (Production)
DB_READ_HOST="mysql-wordpress-{env}-read.mysql.database.azure.com"
DB_READ_USER="dbadmin"
DB_READ_PASSWORD="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=database-password)"
```

### Database Connection Strings

```bash
# Full Connection String
DATABASE_URL="mysql://dbadmin:${DB_PASSWORD}@mysql-wordpress-{env}.mysql.database.azure.com:3306/wordpress?sslmode=require"

# Application-specific Connection Strings
WP_DATABASE_URL="mysql://dbadmin:${DB_PASSWORD}@mysql-wordpress-{env}.mysql.database.azure.com:3306/wordpress?charset=utf8mb4&collation=utf8mb4_unicode_ci&sslmode=require"

# Test Database
TEST_DATABASE_URL="mysql://test_user:${TEST_DB_PASSWORD}@mysql-wordpress-{env}.mysql.database.azure.com:3306/wordpress_test?sslmode=require"
```

## Redis Cache Configuration

### Redis Connection Variables

```bash
# Redis Connection
REDIS_HOST="redis-wordpress-{env}.redis.cache.windows.net"
REDIS_PORT="6380"
REDIS_PASSWORD="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=redis-password)"
REDIS_DATABASE="0"
REDIS_TIMEOUT="1"
REDIS_READ_TIMEOUT="1"
REDIS_SSL="true"
REDIS_TLS_INSECURE="false"

# Redis Configuration
REDIS_PREFIX="{env}:"
REDIS_MAXTTL="86400"
REDIS_SELECTIVE_FLUSH="true"
REDIS_GLOBAL_GROUPS="blog-details,blog-id-cache,blog-lookup,global-posts,networks,rss,sites,site-details,site-lookup,site-options,site-transient,users,usermeta"
REDIS_IGNORED_GROUPS="comment,counts,plugins"

# Redis Connection String
REDIS_URL="rediss://:${REDIS_PASSWORD}@redis-wordpress-{env}.redis.cache.windows.net:6380"
REDIS_CONNECTION_STRING="redis-wordpress-{env}.redis.cache.windows.net:6380,password=${REDIS_PASSWORD},ssl=True,abortConnect=False"
```

### WordPress Redis Configuration

```bash
# WordPress Redis Object Cache
WP_REDIS_HOST="${REDIS_HOST}"
WP_REDIS_PORT="${REDIS_PORT}"
WP_REDIS_PASSWORD="${REDIS_PASSWORD}"
WP_REDIS_TIMEOUT="${REDIS_TIMEOUT}"
WP_REDIS_READ_TIMEOUT="${REDIS_READ_TIMEOUT}"
WP_REDIS_DATABASE="${REDIS_DATABASE}"
WP_REDIS_PREFIX="${REDIS_PREFIX}"
WP_REDIS_SELECTIVE_FLUSH="${REDIS_SELECTIVE_FLUSH}"
WP_REDIS_MAXTTL="${REDIS_MAXTTL}"
WP_CACHE="true"
```

## Next.js Frontend Configuration

### Next.js Runtime Variables

```bash
# Application Environment
NODE_ENV="{development|production}"
NEXT_TELEMETRY_DISABLED="1"
NEXT_PUBLIC_ENVIRONMENT="{development|staging|production}"

# API Configuration
NEXT_PUBLIC_WORDPRESS_URL="https://api.{domain}.com"
NEXT_PUBLIC_GRAPHQL_ENDPOINT="https://api.{domain}.com/graphql"
NEXT_PUBLIC_REST_API_ENDPOINT="https://api.{domain}.com/wp-json/wp/v2"

# CDN and Assets
NEXT_PUBLIC_CDN_URL="https://cdn.{domain}.com"
NEXT_PUBLIC_ASSETS_URL="https://cdn.{domain}.com/assets"
NEXT_PUBLIC_IMAGES_DOMAIN="{domain}.com"

# Frontend Features
NEXT_PUBLIC_ENABLE_ANALYTICS="{true|false}"
NEXT_PUBLIC_ENABLE_COMMENTS="{true|false}"
NEXT_PUBLIC_ENABLE_SEARCH="{true|false}"
NEXT_PUBLIC_PREVIEW_MODE="{true|false}"

# Performance Configuration
NEXT_PUBLIC_REVALIDATE_TIME="3600"
NEXT_PUBLIC_CACHE_MAX_AGE="86400"
NEXT_PUBLIC_IMAGE_OPTIMIZATION="{true|false}"
```

### Build-time Configuration

```bash
# Build Configuration
NEXT_BUILD_TARGET="standalone"
NEXT_OUTPUT="export"
NEXT_TRAILINGSLASH="false"
NEXT_COMPRESS="true"

# Image Optimization
NEXT_IMAGES_DOMAINS="api.{domain}.com,cdn.{domain}.com"
NEXT_IMAGES_LOADER="custom"
NEXT_IMAGES_PATH="/_next/image"

# Bundle Analysis
NEXT_BUNDLE_ANALYZE="{true|false}"
NEXT_SOURCE_MAPS="{true|false}"
```

### Third-party Service Integration

```bash
# Analytics
NEXT_PUBLIC_GA_TRACKING_ID="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=google-analytics-id)"
NEXT_PUBLIC_GTM_CONTAINER_ID="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=google-tag-manager-id)"

# Social Media
NEXT_PUBLIC_FACEBOOK_APP_ID="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=facebook-app-id)"
NEXT_PUBLIC_TWITTER_HANDLE="@company"

# Error Tracking
NEXT_PUBLIC_SENTRY_DSN="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=sentry-dsn)"
SENTRY_ORG="your-organization"
SENTRY_PROJECT="wordpress-nextjs"
SENTRY_AUTH_TOKEN="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=sentry-auth-token)"
```

## Azure Services Configuration

### Container Apps Configuration

```bash
# Container Configuration
CONTAINER_APP_NAME="ca-wordpress-{env}"
CONTAINER_APP_ENVIRONMENT="cae-wordpress-{env}"
CONTAINER_IMAGE="${ACR_LOGIN_SERVER}/wordpress:${IMAGE_TAG}"
CONTAINER_CPU="1.0"
CONTAINER_MEMORY="2.0Gi"
CONTAINER_MIN_REPLICAS="2"
CONTAINER_MAX_REPLICAS="10"
CONTAINER_TARGET_PORT="80"

# Container Registry
ACR_LOGIN_SERVER="acrwordpress{env}.azurecr.io"
ACR_USERNAME="acrwordpress{env}"
ACR_PASSWORD="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=acr-password)"

# Scaling Configuration
SCALE_TRIGGER_TYPE="http"
SCALE_CONCURRENT_REQUESTS="50"
SCALE_CPU_THRESHOLD="70"
SCALE_MEMORY_THRESHOLD="80"
```

### Static Web Apps Configuration

```bash
# Static Web App
STATIC_WEB_APP_NAME="swa-frontend-{env}"
STATIC_WEB_APP_TOKEN="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=swa-deployment-token)"

# Build Configuration
APP_LOCATION="frontend"
API_LOCATION=""
OUTPUT_LOCATION="out"
SKIP_APP_BUILD="false"
SKIP_API_BUILD="true"

# Custom Domain
CUSTOM_DOMAIN="{domain}.com"
CUSTOM_DOMAIN_VALIDATION_METHOD="dns-txt-token"
```

### Azure Storage Configuration

```bash
# Storage Account
AZURE_STORAGE_ACCOUNT_NAME="sawordpress{env}"
AZURE_STORAGE_ACCOUNT_KEY="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=storage-account-key)"
AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;AccountName=sawordpress{env};AccountKey=${AZURE_STORAGE_ACCOUNT_KEY};EndpointSuffix=core.windows.net"

# Blob Storage Containers
WP_UPLOADS_CONTAINER="uploads"
WP_BACKUPS_CONTAINER="backups"
WP_LOGS_CONTAINER="logs"
CDN_ASSETS_CONTAINER="assets"

# CDN Configuration
CDN_PROFILE_NAME="cdnprofile-wordpress-{env}"
CDN_ENDPOINT_NAME="cdn-wordpress-{env}"
CDN_CUSTOM_DOMAIN="cdn.{domain}.com"
```

## Security and Authentication

### Azure Authentication

```bash
# Service Principal for CI/CD
AZURE_CLIENT_ID="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=service-principal-client-id)"
AZURE_CLIENT_SECRET="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=service-principal-client-secret)"
AZURE_TENANT_ID="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=azure-tenant-id)"
AZURE_SUBSCRIPTION_ID="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=azure-subscription-id)"

# Key Vault Configuration
KEY_VAULT_NAME="kv-wordpress-{env}"
KEY_VAULT_URI="https://kv-wordpress-{env}.vault.azure.net/"
KEY_VAULT_CLIENT_ID="${AZURE_CLIENT_ID}"
KEY_VAULT_CLIENT_SECRET="${AZURE_CLIENT_SECRET}"

# Managed Identity (Alternative to Service Principal)
AZURE_USE_MANAGED_IDENTITY="{true|false}"
AZURE_MANAGED_IDENTITY_CLIENT_ID="system-assigned"
```

### SSL and Security Configuration

```bash
# SSL Certificate
SSL_CERTIFICATE_NAME="ssl-cert-{env}"
SSL_CERTIFICATE_PASSWORD="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=ssl-cert-password)"
SSL_CERTIFICATE_THUMBPRINT="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=ssl-cert-thumbprint)"

# Security Headers
HSTS_MAX_AGE="31536000"
CSP_POLICY="default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'"
X_FRAME_OPTIONS="SAMEORIGIN"
X_CONTENT_TYPE_OPTIONS="nosniff"
REFERRER_POLICY="strict-origin-when-cross-origin"

# CORS Configuration
CORS_ALLOWED_ORIGINS="https://{domain}.com,https://www.{domain}.com"
CORS_ALLOWED_METHODS="GET,POST,PUT,DELETE,OPTIONS"
CORS_ALLOWED_HEADERS="Content-Type,Authorization,X-Requested-With"
CORS_MAX_AGE="86400"
```

## Monitoring and Logging

### Application Insights

```bash
# Application Insights
APPINSIGHTS_INSTRUMENTATIONKEY="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=appinsights-instrumentation-key)"
APPINSIGHTS_CONNECTION_STRING="InstrumentationKey=${APPINSIGHTS_INSTRUMENTATIONKEY};IngestionEndpoint=https://eastus-8.in.applicationinsights.azure.com/"
APPLICATIONINSIGHTS_ROLE_NAME="wordpress-{env}"
APPLICATIONINSIGHTS_ROLE_INSTANCE="${HOSTNAME}"

# Sampling Configuration
APPINSIGHTS_SAMPLING_PERCENTAGE="10"
APPINSIGHTS_ENABLE_LIVE_METRICS="{true|false}"
APPINSIGHTS_ENABLE_ADAPTIVE_SAMPLING="{true|false}"
```

### Log Analytics

```bash
# Log Analytics Workspace
LAW_WORKSPACE_ID="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=law-workspace-id)"
LAW_WORKSPACE_KEY="@Microsoft.KeyVault(VaultName=kv-wordpress-{env};SecretName=law-workspace-key)"
LAW_WORKSPACE_NAME="law-wordpress-{env}"

# Logging Configuration
LOG_LEVEL="{debug|info|warning|error}"
LOG_FORMAT="json"
LOG_DESTINATION="stdout"
ENABLE_CONSOLE_LOGGING="{true|false}"
ENABLE_FILE_LOGGING="{true|false}"
LOG_FILE_PATH="/var/log/wordpress/application.log"
LOG_ROTATION_SIZE="100MB"
LOG_RETENTION_DAYS="30"
```

### Performance Monitoring

```bash
# Performance Metrics
ENABLE_PERFORMANCE_MONITORING="{true|false}"
PERFORMANCE_SAMPLE_RATE="0.1"
SLOW_QUERY_THRESHOLD="2.0"
ENABLE_QUERY_LOGGING="{true|false}"

# Health Check Configuration
HEALTH_CHECK_ENDPOINT="/health"
HEALTH_CHECK_INTERVAL="30"
HEALTH_CHECK_TIMEOUT="10"
HEALTH_CHECK_RETRIES="3"
HEALTH_CHECK_GRACE_PERIOD="60"
```

## Environment-Specific Values

### Development Environment

```bash
# Development-specific variables
WORDPRESS_DEBUG="true"
WORDPRESS_DEBUG_LOG="true"
WORDPRESS_DEBUG_DISPLAY="true"
SCRIPT_DEBUG="true"
WP_ENVIRONMENT_TYPE="development"
NODE_ENV="development"
NEXT_PUBLIC_ENVIRONMENT="development"
LOG_LEVEL="debug"
REDIS_PREFIX="dev:"
CONTAINER_MIN_REPLICAS="1"
CONTAINER_MAX_REPLICAS="2"
ENABLE_CONSOLE_LOGGING="true"
HEALTH_CHECK_INTERVAL="60"

# Development URLs
WORDPRESS_HOME="https://api-dev.{domain}.com"
NEXT_PUBLIC_WORDPRESS_URL="https://api-dev.{domain}.com"
CUSTOM_DOMAIN="dev.{domain}.com"
```

### Staging Environment

```bash
# Staging-specific variables
WORDPRESS_DEBUG="false"
WORDPRESS_DEBUG_LOG="true"
WORDPRESS_DEBUG_DISPLAY="false"
SCRIPT_DEBUG="false"
WP_ENVIRONMENT_TYPE="staging"
NODE_ENV="production"
NEXT_PUBLIC_ENVIRONMENT="staging"
LOG_LEVEL="info"
REDIS_PREFIX="staging:"
CONTAINER_MIN_REPLICAS="2"
CONTAINER_MAX_REPLICAS="5"
ENABLE_CONSOLE_LOGGING="true"
HEALTH_CHECK_INTERVAL="30"

# Staging URLs
WORDPRESS_HOME="https://api-staging.{domain}.com"
NEXT_PUBLIC_WORDPRESS_URL="https://api-staging.{domain}.com"
CUSTOM_DOMAIN="staging.{domain}.com"
```

### Production Environment

```bash
# Production-specific variables
WORDPRESS_DEBUG="false"
WORDPRESS_DEBUG_LOG="false"
WORDPRESS_DEBUG_DISPLAY="false"
SCRIPT_DEBUG="false"
WP_ENVIRONMENT_TYPE="production"
NODE_ENV="production"
NEXT_PUBLIC_ENVIRONMENT="production"
LOG_LEVEL="warning"
REDIS_PREFIX="prod:"
CONTAINER_MIN_REPLICAS="3"
CONTAINER_MAX_REPLICAS="20"
ENABLE_CONSOLE_LOGGING="false"
HEALTH_CHECK_INTERVAL="15"

# Production URLs
WORDPRESS_HOME="https://api.{domain}.com"
NEXT_PUBLIC_WORDPRESS_URL="https://api.{domain}.com"
CUSTOM_DOMAIN="{domain}.com"

# Production Security
FORCE_SSL_ADMIN="true"
DISALLOW_FILE_EDIT="true"
DISALLOW_FILE_MODS="true"
WP_AUTO_UPDATE_CORE="minor"
```

## Secret Management

### Key Vault Secret References

```yaml
# Azure Key Vault secret reference format
Azure_KeyVault_Reference:
  Format: "@Microsoft.KeyVault(VaultName={vault-name};SecretName={secret-name})"
  Examples:
    Database: "@Microsoft.KeyVault(VaultName=kv-wordpress-prod;SecretName=database-password)"
    Redis: "@Microsoft.KeyVault(VaultName=kv-wordpress-prod;SecretName=redis-password)"
    API_Keys: "@Microsoft.KeyVault(VaultName=kv-wordpress-prod;SecretName=sendgrid-api-key)"
```

### Environment Variable Validation

```bash
#!/bin/bash
# validate-env-vars.sh - Environment variable validation script

set -e

# Required variables for all environments
REQUIRED_VARS=(
    "WORDPRESS_DB_HOST"
    "WORDPRESS_DB_NAME"
    "WORDPRESS_DB_USER"
    "WORDPRESS_DB_PASSWORD"
    "REDIS_HOST"
    "REDIS_PASSWORD"
    "WORDPRESS_AUTH_KEY"
    "ACR_LOGIN_SERVER"
    "AZURE_CLIENT_ID"
    "KEY_VAULT_NAME"
)

# Environment-specific required variables
if [ "$WP_ENVIRONMENT_TYPE" = "production" ]; then
    REQUIRED_VARS+=(
        "SSL_CERTIFICATE_THUMBPRINT"
        "APPINSIGHTS_INSTRUMENTATIONKEY"
        "CDN_ENDPOINT_NAME"
    )
fi

echo "Validating environment variables for $WP_ENVIRONMENT_TYPE environment..."

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "ERROR: Required environment variable $var is not set"
        exit 1
    else
        echo "✓ $var is set"
    fi
done

echo "All required environment variables are set!"
```

### Container App Environment Configuration

```yaml
# container-app-env-vars.yaml
properties:
  template:
    containers:
    - name: wordpress
      image: ${ACR_LOGIN_SERVER}/wordpress:${IMAGE_TAG}
      env:
      # Database Configuration
      - name: WORDPRESS_DB_HOST
        value: mysql-wordpress-prod.mysql.database.azure.com
      - name: WORDPRESS_DB_NAME
        value: wordpress
      - name: WORDPRESS_DB_USER
        value: dbadmin
      - name: WORDPRESS_DB_PASSWORD
        secretRef: database-password
      
      # Redis Configuration
      - name: REDIS_HOST
        value: redis-wordpress-prod.redis.cache.windows.net
      - name: REDIS_PORT
        value: "6380"
      - name: REDIS_PASSWORD
        secretRef: redis-password
      
      # WordPress Configuration
      - name: WORDPRESS_DEBUG
        value: "false"
      - name: WP_ENVIRONMENT_TYPE
        value: production
      - name: WORDPRESS_AUTH_KEY
        secretRef: wordpress-auth-key
      
      # Application Insights
      - name: APPINSIGHTS_INSTRUMENTATIONKEY
        secretRef: appinsights-instrumentation-key
      
  secrets:
  - name: database-password
    keyVaultUrl: https://kv-wordpress-prod.vault.azure.net/secrets/database-password
    identity: system
  - name: redis-password
    keyVaultUrl: https://kv-wordpress-prod.vault.azure.net/secrets/redis-password
    identity: system
  - name: wordpress-auth-key
    keyVaultUrl: https://kv-wordpress-prod.vault.azure.net/secrets/wordpress-auth-key
    identity: system
  - name: appinsights-instrumentation-key
    keyVaultUrl: https://kv-wordpress-prod.vault.azure.net/secrets/appinsights-instrumentation-key
    identity: system
```

### GitHub Actions Environment Variables

```yaml
# GitHub workflow environment variables
name: Deploy Application

env:
  # Global environment variables
  AZURE_RESOURCE_GROUP: rg-app-${{ github.event.inputs.environment }}
  CONTAINER_APP_NAME: ca-wordpress-${{ github.event.inputs.environment }}
  STATIC_WEB_APP_NAME: swa-frontend-${{ github.event.inputs.environment }}
  
  # Container configuration
  CONTAINER_CPU: ${{ github.event.inputs.environment == 'production' && '2.0' || '1.0' }}
  CONTAINER_MEMORY: ${{ github.event.inputs.environment == 'production' && '4.0Gi' || '2.0Gi' }}
  MIN_REPLICAS: ${{ github.event.inputs.environment == 'production' && '3' || '1' }}
  MAX_REPLICAS: ${{ github.event.inputs.environment == 'production' && '20' || '5' }}
  
jobs:
  deploy:
    environment: ${{ github.event.inputs.environment }}
    steps:
    - name: Set environment-specific variables
      run: |
        if [ "${{ github.event.inputs.environment }}" = "production" ]; then
          echo "WORDPRESS_DEBUG=false" >> $GITHUB_ENV
          echo "LOG_LEVEL=warning" >> $GITHUB_ENV
          echo "ENABLE_CONSOLE_LOGGING=false" >> $GITHUB_ENV
        elif [ "${{ github.event.inputs.environment }}" = "staging" ]; then
          echo "WORDPRESS_DEBUG=false" >> $GITHUB_ENV
          echo "LOG_LEVEL=info" >> $GITHUB_ENV
          echo "ENABLE_CONSOLE_LOGGING=true" >> $GITHUB_ENV
        else
          echo "WORDPRESS_DEBUG=true" >> $GITHUB_ENV
          echo "LOG_LEVEL=debug" >> $GITHUB_ENV
          echo "ENABLE_CONSOLE_LOGGING=true" >> $GITHUB_ENV
        fi
```

## Configuration Management Best Practices

1. **Never hardcode secrets** in environment variables
2. **Use Key Vault references** for all sensitive data
3. **Validate required variables** before deployment
4. **Use environment-specific naming** for resources
5. **Document all variables** with purpose and format
6. **Regular rotation** of secrets and keys
7. **Audit access** to sensitive configuration
8. **Version control** configuration templates

## Next Steps

1. Set up [configuration management](configuration-management.md) processes
2. Implement [secret rotation](../cicd/secret-management.md#secret-rotation) procedures
3. Configure [monitoring and alerting](../monitoring/azure-monitor-setup.md) for configuration changes
4. Review [security best practices](../infrastructure/security-hardening.md) for environment variables
