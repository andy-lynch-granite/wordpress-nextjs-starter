# Development Environment Setup Guide

This guide provides comprehensive instructions for setting up and configuring the development environment for the headless WordPress + Next.js application.

## Table of Contents

1. [Environment Overview](#environment-overview)
2. [Azure Resources Setup](#azure-resources-setup)
3. [Container Configuration](#container-configuration)
4. [Database Setup](#database-setup)
5. [Redis Cache Configuration](#redis-cache-configuration)
6. [Networking and Security](#networking-and-security)
7. [Monitoring and Logging](#monitoring-and-logging)
8. [Development Workflow](#development-workflow)
9. [Testing Configuration](#testing-configuration)
10. [Troubleshooting](#troubleshooting)

## Environment Overview

### Development Environment Characteristics

```yaml
Development_Environment:
  Purpose: "Feature development and testing"
  Auto_Deploy: true
  Branch: "develop"
  Approval_Required: false
  Scale: "Minimal for cost efficiency"
  
  Features:
    - Rapid deployment
    - Debug logging enabled
    - Development tools included
    - Relaxed security for ease of access
    - Hot reloading enabled
    - Mock services where appropriate
```

### Resource Naming Convention

```yaml
Naming_Pattern:
  Resource_Groups: "rg-{service}-dev"
  Storage: "sa{project}dev{random}"
  Key_Vault: "kv-{project}-dev-{suffix}"
  Databases: "{service}-{project}-dev"
  Container_Apps: "ca-{service}-dev"
  
Examples:
  - rg-app-dev
  - rg-db-dev
  - rg-cache-dev
  - sawordpressdev1234
  - kv-wordpress-dev-5678
  - mysql-wordpress-dev
  - ca-wordpress-dev
```

## Azure Resources Setup

### Resource Groups Creation

```bash
# Core resource groups for development environment
az group create --name rg-app-dev --location eastus
az group create --name rg-db-dev --location eastus
az group create --name rg-cache-dev --location eastus
az group create --name rg-storage-dev --location eastus
az group create --name rg-keyvault-dev --location eastus
az group create --name rg-monitoring-dev --location eastus

# Set default resource group for convenience
az configure --defaults group=rg-app-dev location=eastus
```

### Container Registry Setup

```bash
# Create Azure Container Registry for development
az acr create \
  --name acrwordpressdev$(date +%s | tail -c 4) \
  --resource-group rg-app-dev \
  --sku Basic \
  --admin-enabled true

# Get registry credentials
ACR_NAME="acrwordpressdev$(date +%s | tail -c 4)"
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)

echo "ACR Login Server: $ACR_LOGIN_SERVER"
echo "ACR Username: $ACR_USERNAME"
echo "ACR Password: $ACR_PASSWORD"
```

### Container Apps Environment

```bash
# Create Log Analytics workspace for Container Apps
az monitor log-analytics workspace create \
  --workspace-name law-wordpress-dev \
  --resource-group rg-monitoring-dev \
  --location eastus

LAW_WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --workspace-name law-wordpress-dev \
  --resource-group rg-monitoring-dev \
  --query customerId -o tsv)

LAW_WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --workspace-name law-wordpress-dev \
  --resource-group rg-monitoring-dev \
  --query primarySharedKey -o tsv)

# Create Container Apps Environment
az containerapp env create \
  --name cae-wordpress-dev \
  --resource-group rg-app-dev \
  --location eastus \
  --logs-destination log-analytics \
  --logs-workspace-id $LAW_WORKSPACE_ID \
  --logs-workspace-key $LAW_WORKSPACE_KEY
```

## Container Configuration

### WordPress Container App

```bash
# Create WordPress container app with development settings
az containerapp create \
  --name ca-wordpress-dev \
  --resource-group rg-app-dev \
  --environment cae-wordpress-dev \
  --image $ACR_LOGIN_SERVER/wordpress:dev-latest \
  --target-port 80 \
  --ingress external \
  --cpu 0.5 \
  --memory 1.0Gi \
  --min-replicas 1 \
  --max-replicas 2 \
  --registry-server $ACR_LOGIN_SERVER \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --env-vars \
    WORDPRESS_DEBUG=true \
    WORDPRESS_DEBUG_LOG=true \
    WP_ENVIRONMENT_TYPE=development \
    WORDPRESS_DB_HOST=mysql-wordpress-dev.mysql.database.azure.com \
    WORDPRESS_DB_NAME=wordpress \
    WORDPRESS_DB_USER=dbadmin \
    REDIS_HOST=redis-wordpress-dev.redis.cache.windows.net \
    REDIS_PORT=6380 \
    WP_REDIS_PREFIX=dev_ \
    WP_CACHE_KEY_SALT=dev-cache-salt
```

### Frontend Static Web App

```bash
# Create Static Web App for Next.js frontend
az staticwebapp create \
  --name swa-frontend-dev \
  --resource-group rg-app-dev \
  --location eastus2 \
  --source https://github.com/andy-lynch-granite/wordpress-nextjs-starter \
  --branch develop \
  --app-location "frontend" \
  --api-location "" \
  --output-location "out" \
  --sku Standard

# Get deployment token
SWA_DEPLOYMENT_TOKEN=$(az staticwebapp secrets list \
  --name swa-frontend-dev \
  --resource-group rg-app-dev \
  --query properties.apiKey -o tsv)

echo "Static Web App Deployment Token: $SWA_DEPLOYMENT_TOKEN"
```

## Database Setup

### MySQL Flexible Server

```bash
# Generate secure database password
DB_PASSWORD=$(openssl rand -base64 32)
echo "Database Password: $DB_PASSWORD"

# Create MySQL Flexible Server for development
az mysql flexible-server create \
  --name mysql-wordpress-dev \
  --resource-group rg-db-dev \
  --location eastus \
  --admin-user dbadmin \
  --admin-password "$DB_PASSWORD" \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 32 \
  --storage-auto-grow Disabled \
  --version 8.0 \
  --high-availability Disabled \
  --public-access 0.0.0.0

# Configure server parameters for development
az mysql flexible-server parameter set \
  --name mysql-wordpress-dev \
  --resource-group rg-db-dev \
  --parameter-name slow_query_log \
  --value ON

az mysql flexible-server parameter set \
  --name mysql-wordpress-dev \
  --resource-group rg-db-dev \
  --parameter-name long_query_time \
  --value 1.0

# Create WordPress database
az mysql flexible-server db create \
  --server-name mysql-wordpress-dev \
  --resource-group rg-db-dev \
  --database-name wordpress

# Allow Azure services access
az mysql flexible-server firewall-rule create \
  --name mysql-wordpress-dev \
  --resource-group rg-db-dev \
  --rule-name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Allow development machine access (replace with your IP)
az mysql flexible-server firewall-rule create \
  --name mysql-wordpress-dev \
  --resource-group rg-db-dev \
  --rule-name AllowDevelopmentAccess \
  --start-ip-address YOUR_DEV_IP \
  --end-ip-address YOUR_DEV_IP
```

### Database Initialization

```sql
-- Connect to MySQL and run initial setup
-- mysql -h mysql-wordpress-dev.mysql.database.azure.com -u dbadmin -p wordpress

-- Create additional users for development
CREATE USER 'dev_user'@'%' IDENTIFIED BY 'dev_password_123';
GRANT SELECT, INSERT, UPDATE, DELETE ON wordpress.* TO 'dev_user'@'%';

-- Create test database
CREATE DATABASE wordpress_test;
GRANT ALL PRIVILEGES ON wordpress_test.* TO 'dbadmin'@'%';
GRANT ALL PRIVILEGES ON wordpress_test.* TO 'dev_user'@'%';

-- Configure development-friendly settings
SET GLOBAL sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';
SET GLOBAL innodb_buffer_pool_size = 134217728;  -- 128MB for development

FLUSH PRIVILEGES;
```

## Redis Cache Configuration

### Azure Cache for Redis

```bash
# Create Redis cache for development
az redis create \
  --name redis-wordpress-dev \
  --resource-group rg-cache-dev \
  --location eastus \
  --sku Basic \
  --vm-size c0 \
  --enable-non-ssl-port false \
  --minimum-tls-version 1.2 \
  --redis-configuration '{"maxmemory-policy":"allkeys-lru"}'

# Get Redis connection details
REDIS_HOSTNAME=$(az redis show \
  --name redis-wordpress-dev \
  --resource-group rg-cache-dev \
  --query hostName -o tsv)

REDIS_PRIMARY_KEY=$(az redis list-keys \
  --name redis-wordpress-dev \
  --resource-group rg-cache-dev \
  --query primaryKey -o tsv)

REDIS_PORT=$(az redis show \
  --name redis-wordpress-dev \
  --resource-group rg-cache-dev \
  --query sslPort -o tsv)

echo "Redis Hostname: $REDIS_HOSTNAME"
echo "Redis Port: $REDIS_PORT"
echo "Redis Primary Key: $REDIS_PRIMARY_KEY"

# Test Redis connection
redis-cli -h $REDIS_HOSTNAME -p $REDIS_PORT -a $REDIS_PRIMARY_KEY --tls ping
```

### Redis Configuration for WordPress

```php
<?php
// wp-config-development.php additions for Redis

// Redis Object Cache Configuration
define('WP_REDIS_HOST', 'redis-wordpress-dev.redis.cache.windows.net');
define('WP_REDIS_PORT', 6380);
define('WP_REDIS_PASSWORD', 'REDIS_PRIMARY_KEY_HERE');
define('WP_REDIS_TIMEOUT', 1);
define('WP_REDIS_READ_TIMEOUT', 1);
define('WP_REDIS_DATABASE', 0);
define('WP_REDIS_PREFIX', 'dev:');
define('WP_REDIS_SELECTIVE_FLUSH', true);
define('WP_REDIS_MAXTTL', 86400); // 24 hours

// Enable Redis object cache
define('WP_CACHE', true);
?>
```

## Networking and Security

### Virtual Network (Optional for Development)

```bash
# Create VNet for development (optional, for testing network isolation)
az network vnet create \
  --name vnet-wordpress-dev \
  --resource-group rg-app-dev \
  --location eastus \
  --address-prefix 10.1.0.0/16 \
  --subnet-name subnet-apps \
  --subnet-prefix 10.1.1.0/24

# Create additional subnets
az network vnet subnet create \
  --vnet-name vnet-wordpress-dev \
  --resource-group rg-app-dev \
  --name subnet-data \
  --address-prefix 10.1.2.0/24

az network vnet subnet create \
  --vnet-name vnet-wordpress-dev \
  --resource-group rg-app-dev \
  --name subnet-cache \
  --address-prefix 10.1.3.0/24
```

### Network Security Groups

```bash
# Create NSG for development (relaxed rules)
az network nsg create \
  --name nsg-wordpress-dev \
  --resource-group rg-app-dev \
  --location eastus

# Allow HTTP/HTTPS traffic
az network nsg rule create \
  --nsg-name nsg-wordpress-dev \
  --resource-group rg-app-dev \
  --name AllowHTTP \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 80

az network nsg rule create \
  --nsg-name nsg-wordpress-dev \
  --resource-group rg-app-dev \
  --name AllowHTTPS \
  --priority 101 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes '*' \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 443

# Allow SSH for debugging
az network nsg rule create \
  --nsg-name nsg-wordpress-dev \
  --resource-group rg-app-dev \
  --name AllowSSH \
  --priority 200 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes 'YOUR_DEV_IP/32' \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 22
```

### Key Vault for Development Secrets

```bash
# Create Key Vault for development secrets
az keyvault create \
  --name kv-wordpress-dev-$(date +%s | tail -c 4) \
  --resource-group rg-keyvault-dev \
  --location eastus \
  --sku Standard \
  --enable-soft-delete true \
  --soft-delete-retention-days 7 \
  --enable-purge-protection false

KV_NAME="kv-wordpress-dev-$(date +%s | tail -c 4)"

# Set access policy for your user
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
az keyvault set-policy \
  --name $KV_NAME \
  --resource-group rg-keyvault-dev \
  --object-id $USER_OBJECT_ID \
  --secret-permissions all

# Store development secrets
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "database-password-dev" \
  --value "$DB_PASSWORD"

az keyvault secret set \
  --vault-name $KV_NAME \
  --name "redis-password-dev" \
  --value "$REDIS_PRIMARY_KEY"

# Generate and store WordPress keys
WP_AUTH_KEY=$(openssl rand -base64 64)
az keyvault secret set \
  --vault-name $KV_NAME \
  --name "wordpress-auth-key-dev" \
  --value "$WP_AUTH_KEY"
```

## Monitoring and Logging

### Application Insights

```bash
# Create Application Insights for development
az monitor app-insights component create \
  --app ai-wordpress-dev \
  --location eastus \
  --resource-group rg-monitoring-dev \
  --application-type web \
  --retention-time 30

# Get instrumentation key
AI_INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app ai-wordpress-dev \
  --resource-group rg-monitoring-dev \
  --query instrumentationKey -o tsv)

echo "Application Insights Instrumentation Key: $AI_INSTRUMENTATION_KEY"
```

### Log Analytics Workspace

```bash
# Configure log retention for development (shorter period)
az monitor log-analytics workspace update \
  --workspace-name law-wordpress-dev \
  --resource-group rg-monitoring-dev \
  --retention-time 30

# Create custom log queries for development
az monitor log-analytics query \
  --workspace $LAW_WORKSPACE_ID \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerName_s == 'ca-wordpress-dev' | limit 100"
```

## Development Workflow

### Environment Variables Configuration

```bash
# Create .env file for local development
cat > .env.development << EOF
# Database Configuration
WORDPRESS_DB_HOST=mysql-wordpress-dev.mysql.database.azure.com
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=dbadmin
WORDPRESS_DB_PASSWORD=$DB_PASSWORD

# Redis Configuration
REDIS_HOST=redis-wordpress-dev.redis.cache.windows.net
REDIS_PORT=6380
REDIS_PASSWORD=$REDIS_PRIMARY_KEY

# WordPress Configuration
WORDPRESS_DEBUG=true
WORDPRESS_DEBUG_LOG=true
WP_ENVIRONMENT_TYPE=development
WORDPRESS_AUTH_KEY=$WP_AUTH_KEY

# Application Insights
APPINSIGHTS_INSTRUMENTATIONKEY=$AI_INSTRUMENTATION_KEY

# Container Registry
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
ACR_USERNAME=$ACR_USERNAME
ACR_PASSWORD=$ACR_PASSWORD

# Key Vault
KEY_VAULT_NAME=$KV_NAME
EOF
```

### Docker Compose for Local Development

```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  wordpress-dev:
    build:
      context: .
      dockerfile: infrastructure/docker/wordpress/Dockerfile.dev
    ports:
      - "8080:80"
    environment:
      - WORDPRESS_DB_HOST=${WORDPRESS_DB_HOST}
      - WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME}
      - WORDPRESS_DB_USER=${WORDPRESS_DB_USER}
      - WORDPRESS_DB_PASSWORD=${WORDPRESS_DB_PASSWORD}
      - REDIS_HOST=${REDIS_HOST}
      - REDIS_PORT=${REDIS_PORT}
      - REDIS_PASSWORD=${REDIS_PASSWORD}
      - WORDPRESS_DEBUG=true
      - WP_DEBUG_LOG=true
    volumes:
      - ./wordpress:/var/www/html
      - ./logs/wordpress:/var/log/apache2
    depends_on:
      - mysql-local
      - redis-local

  frontend-dev:
    build:
      context: frontend
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_WORDPRESS_URL=http://localhost:8080
      - NODE_ENV=development
    volumes:
      - ./frontend:/app
      - /app/node_modules
      - ./logs/frontend:/app/.next

  mysql-local:
    image: mysql:8.0
    ports:
      - "3306:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=root
      - MYSQL_DATABASE=wordpress
      - MYSQL_USER=wp_user
      - MYSQL_PASSWORD=wp_pass
    volumes:
      - mysql_data:/var/lib/mysql
      - ./infrastructure/docker/mysql/conf.d:/etc/mysql/conf.d

  redis-local:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
      - ./infrastructure/docker/redis/redis.conf:/usr/local/etc/redis/redis.conf
    command: redis-server /usr/local/etc/redis/redis.conf

  mailhog:
    image: mailhog/mailhog:v1.0.1
    ports:
      - "1025:1025"
      - "8025:8025"

volumes:
  mysql_data:
  redis_data:
```

### Development Scripts

```bash
#!/bin/bash
# scripts/dev-setup.sh - Development environment setup script

set -e

echo "Setting up development environment..."

# Load environment variables
source .env.development

# Build and push development images
echo "Building WordPress development image..."
docker build -t $ACR_LOGIN_SERVER/wordpress:dev-latest \
  -f infrastructure/docker/wordpress/Dockerfile.dev .

echo "Building Frontend development image..."
docker build -t $ACR_LOGIN_SERVER/frontend:dev-latest \
  -f frontend/Dockerfile.dev frontend/

# Login to Azure Container Registry
echo $ACR_PASSWORD | docker login $ACR_LOGIN_SERVER -u $ACR_USERNAME --password-stdin

# Push images
echo "Pushing images to ACR..."
docker push $ACR_LOGIN_SERVER/wordpress:dev-latest
docker push $ACR_LOGIN_SERVER/frontend:dev-latest

# Update container apps
echo "Updating container apps..."
az containerapp update \
  --name ca-wordpress-dev \
  --resource-group rg-app-dev \
  --image $ACR_LOGIN_SERVER/wordpress:dev-latest

echo "Development environment setup complete!"
echo "WordPress: https://$(az containerapp show --name ca-wordpress-dev --resource-group rg-app-dev --query properties.configuration.ingress.fqdn -o tsv)"
echo "Frontend: https://$(az staticwebapp show --name swa-frontend-dev --resource-group rg-app-dev --query defaultHostname -o tsv)"
```

## Testing Configuration

### Test Database Setup

```bash
# Create dedicated test database
az mysql flexible-server db create \
  --server-name mysql-wordpress-dev \
  --resource-group rg-db-dev \
  --database-name wordpress_test

# Create test user
mysql -h mysql-wordpress-dev.mysql.database.azure.com -u dbadmin -p << EOF
CREATE USER 'test_user'@'%' IDENTIFIED BY 'test_password_123';
GRANT ALL PRIVILEGES ON wordpress_test.* TO 'test_user'@'%';
FLUSH PRIVILEGES;
EOF
```

### PHPUnit Configuration

```xml
<!-- wordpress/phpunit.xml -->
<?xml version="1.0"?>
<phpunit
    bootstrap="tests/bootstrap.php"
    backupGlobals="false"
    colors="true"
    convertErrorsToExceptions="true"
    convertNoticesToExceptions="true"
    convertWarningsToExceptions="true"
    >
    <testsuites>
        <testsuite name="WordPress Test Suite">
            <directory suffix=".php">./tests/</directory>
        </testsuite>
    </testsuites>
    <php>
        <const name="WP_TESTS_DB_HOST" value="mysql-wordpress-dev.mysql.database.azure.com" />
        <const name="WP_TESTS_DB_NAME" value="wordpress_test" />
        <const name="WP_TESTS_DB_USER" value="test_user" />
        <const name="WP_TESTS_DB_PASSWORD" value="test_password_123" />
        <const name="WP_TESTS_DOMAIN" value="wordpress-dev.example.com" />
        <const name="WP_TESTS_EMAIL" value="admin@wordpress-dev.example.com" />
        <const name="WP_DEBUG" value="true" />
    </php>
</phpunit>
```

### Jest Configuration for Frontend

```javascript
// frontend/jest.config.js
const nextJest = require('next/jest')

const createJestConfig = nextJest({
  // Provide the path to your Next.js app to load next.config.js and .env files
  dir: './'
})

// Add any custom config to be passed to Jest
const customJestConfig = {
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  moduleNameMapping: {
    // Handle module aliases (this will be automatically configured for you based on your tsconfig.json paths)
    '^@/components/(.*)$': '<rootDir>/components/$1',
    '^@/pages/(.*)$': '<rootDir>/pages/$1'
  },
  testEnvironment: 'jest-environment-jsdom',
  collectCoverageFrom: [
    'src/**/*.{js,jsx,ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/index.{js,ts}'
  ],
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70
    }
  }
}

// createJestConfig is exported this way to ensure that next/jest can load the Next.js config which is async
module.exports = createJestConfig(customJestConfig)
```

## Troubleshooting

### Common Development Issues

#### Container App Not Starting

```bash
# Check container app logs
az containerapp logs show \
  --name ca-wordpress-dev \
  --resource-group rg-app-dev \
  --follow

# Check container app status
az containerapp show \
  --name ca-wordpress-dev \
  --resource-group rg-app-dev \
  --query "properties.runningStatus"

# Restart container app
az containerapp revision restart \
  --name ca-wordpress-dev \
  --resource-group rg-app-dev
```

#### Database Connection Issues

```bash
# Test database connectivity
mysql -h mysql-wordpress-dev.mysql.database.azure.com -u dbadmin -p -e "SELECT 1;"

# Check firewall rules
az mysql flexible-server firewall-rule list \
  --name mysql-wordpress-dev \
  --resource-group rg-db-dev

# Check server status
az mysql flexible-server show \
  --name mysql-wordpress-dev \
  --resource-group rg-db-dev \
  --query "state"
```

#### Redis Connection Issues

```bash
# Test Redis connectivity
redis-cli -h redis-wordpress-dev.redis.cache.windows.net \
  -p 6380 \
  -a $REDIS_PRIMARY_KEY \
  --tls ping

# Check Redis status
az redis show \
  --name redis-wordpress-dev \
  --resource-group rg-cache-dev \
  --query "redisState"

# Get Redis logs
az redis export \
  --name redis-wordpress-dev \
  --resource-group rg-cache-dev \
  --file-format rdb \
  --file-name redis-export-$(date +%Y%m%d)
```

### Development Tools

#### Database Management

```bash
# Connect to development database
mysql -h mysql-wordpress-dev.mysql.database.azure.com -u dbadmin -p wordpress

# Export database for backup
mysqldump -h mysql-wordpress-dev.mysql.database.azure.com -u dbadmin -p \
  --single-transaction wordpress > wordpress-dev-backup-$(date +%Y%m%d).sql

# Import database from backup
mysql -h mysql-wordpress-dev.mysql.database.azure.com -u dbadmin -p wordpress < wordpress-dev-backup.sql
```

#### Log Analysis

```bash
# View container app logs in real-time
az containerapp logs show \
  --name ca-wordpress-dev \
  --resource-group rg-app-dev \
  --follow \
  --tail 50

# Query specific log entries
az monitor log-analytics query \
  --workspace $LAW_WORKSPACE_ID \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerName_s == 'ca-wordpress-dev' and Log_s contains 'error' | order by TimeGenerated desc"
```

### Performance Testing

```bash
#!/bin/bash
# scripts/dev-performance-test.sh

WORDPRESS_URL="https://$(az containerapp show --name ca-wordpress-dev --resource-group rg-app-dev --query properties.configuration.ingress.fqdn -o tsv)"
FRONTEND_URL="https://$(az staticwebapp show --name swa-frontend-dev --resource-group rg-app-dev --query defaultHostname -o tsv)"

echo "Performance testing development environment..."

# Test WordPress API response time
echo "Testing WordPress API..."
curl -w "@curl-format.txt" -o /dev/null -s "$WORDPRESS_URL/graphql" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ posts { nodes { title } } }"}'

# Test frontend response time
echo "Testing Frontend..."
curl -w "@curl-format.txt" -o /dev/null -s "$FRONTEND_URL"

# Load test with Apache Bench (install with: apt-get install apache2-utils)
echo "Running load test..."
ab -n 100 -c 10 "$FRONTEND_URL"
```

## Environment Cleanup

### Cleanup Script

```bash
#!/bin/bash
# scripts/dev-cleanup.sh

echo "Cleaning up development environment..."

# Stop container apps
echo "Stopping container apps..."
az containerapp update \
  --name ca-wordpress-dev \
  --resource-group rg-app-dev \
  --min-replicas 0 \
  --max-replicas 0

# Optional: Delete all development resources (use with caution)
read -p "Do you want to delete all development resources? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting development resource groups..."
    az group delete --name rg-app-dev --yes --no-wait
    az group delete --name rg-db-dev --yes --no-wait
    az group delete --name rg-cache-dev --yes --no-wait
    az group delete --name rg-storage-dev --yes --no-wait
    az group delete --name rg-keyvault-dev --yes --no-wait
    az group delete --name rg-monitoring-dev --yes --no-wait
    echo "Cleanup initiated. Resources will be deleted in the background."
else
    echo "Cleanup cancelled."
fi
```

## Development Best Practices

1. **Cost Management**: Use smaller SKUs and turn off resources when not needed
2. **Security**: Don't use production data in development
3. **Testing**: Always test changes in development before promoting
4. **Monitoring**: Keep logs and monitoring for debugging
5. **Documentation**: Document any custom configurations
6. **Backup**: Regular backups of development data
7. **Clean Code**: Follow coding standards and best practices
8. **Version Control**: All infrastructure changes should be version controlled

## Next Steps

1. Set up [staging environment](staging.md)
2. Configure [production environment](production.md)
3. Implement [automated testing](../cicd/automated-testing.md)
4. Set up [monitoring and alerting](../monitoring/azure-monitor-setup.md)
