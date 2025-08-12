# WebApp Deployment Guide

This guide covers the deployment of the WordPress backend using Azure Container Instances and configuration of the complete application stack.

## Prerequisites

- Azure infrastructure setup completed ([Azure Setup Guide](./azure-setup-guide.md))
- Docker image built and available
- Environment variables file (`.env.azure`) from previous setup

## Step 1: Container Image Preparation

### 1.1 Build WordPress Docker Image

```bash
# Source environment variables
source .env.azure

# Navigate to project root
cd /path/to/wordpress-nextjs-starter

# Build WordPress image
docker build -t wordpress-headless:latest -f infrastructure/docker/wordpress/Dockerfile .

# Tag for Azure Container Registry (if using ACR)
docker tag wordpress-headless:latest ${ACR_NAME}.azurecr.io/wordpress-headless:latest
```

### 1.2 Push to Container Registry

#### Option A: Azure Container Registry

```bash
# Login to ACR
az acr login --name $ACR_NAME

# Push image
docker push ${ACR_NAME}.azurecr.io/wordpress-headless:latest

# Verify image
az acr repository list --name $ACR_NAME --output table
```

#### Option B: Docker Hub (Alternative)

```bash
# Login to Docker Hub
docker login

# Tag and push
docker tag wordpress-headless:latest yourusername/wordpress-headless:latest
docker push yourusername/wordpress-headless:latest
```

## Step 2: WordPress Container Deployment

### 2.1 Get Database Connection Details

```bash
# Get MySQL connection details
export MYSQL_HOST="${MYSQL_SERVER_NAME}.mysql.database.azure.com"
export MYSQL_USERNAME=$(az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name "mysql-admin-username" \
  --query value -o tsv)
export MYSQL_PASSWORD=$(az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name "mysql-admin-password" \
  --query value -o tsv)

# Get Redis connection details
export REDIS_CONNECTION_STRING=$(az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name "redis-connection-string" \
  --query value -o tsv)
```

### 2.2 Create Container Instance

```bash
export CONTAINER_NAME="ci-wordpress-${ENVIRONMENT}"
export CONTAINER_DNS_NAME="wordpress-${PROJECT_NAME}-${ENVIRONMENT}"

# Generate WordPress secrets
export WP_AUTH_KEY=$(openssl rand -base64 48)
export WP_SECURE_AUTH_KEY=$(openssl rand -base64 48)
export WP_LOGGED_IN_KEY=$(openssl rand -base64 48)
export WP_NONCE_KEY=$(openssl rand -base64 48)
export WP_AUTH_SALT=$(openssl rand -base64 48)
export WP_SECURE_AUTH_SALT=$(openssl rand -base64 48)
export WP_LOGGED_IN_SALT=$(openssl rand -base64 48)
export WP_NONCE_SALT=$(openssl rand -base64 48)

# Store WordPress secrets in Key Vault
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "wp-auth-key" --value "$WP_AUTH_KEY"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "wp-secure-auth-key" --value "$WP_SECURE_AUTH_KEY"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "wp-logged-in-key" --value "$WP_LOGGED_IN_KEY"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "wp-nonce-key" --value "$WP_NONCE_KEY"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "wp-auth-salt" --value "$WP_AUTH_SALT"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "wp-secure-auth-salt" --value "$WP_SECURE_AUTH_SALT"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "wp-logged-in-salt" --value "$WP_LOGGED_IN_SALT"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "wp-nonce-salt" --value "$WP_NONCE_SALT"
```

### 2.3 Create Container with Environment Variables

```bash
# Create container instance
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
  --environment-variables \
    WORDPRESS_DB_HOST="$MYSQL_HOST" \
    WORDPRESS_DB_NAME="$MYSQL_DATABASE" \
    WORDPRESS_DB_USER="$MYSQL_USERNAME" \
    WORDPRESS_DB_PASSWORD="$MYSQL_PASSWORD" \
    WORDPRESS_CONFIG_EXTRA="define('WP_REDIS_HOST', '${REDIS_CACHE_NAME}.redis.cache.windows.net'); define('WP_REDIS_PORT', 6380); define('WP_REDIS_PASSWORD', '${REDIS_PRIMARY_KEY}'); define('WP_REDIS_SCHEME', 'tls'); define('WP_REDIS_DATABASE', 0);" \
    WORDPRESS_AUTH_KEY="$WP_AUTH_KEY" \
    WORDPRESS_SECURE_AUTH_KEY="$WP_SECURE_AUTH_KEY" \
    WORDPRESS_LOGGED_IN_KEY="$WP_LOGGED_IN_KEY" \
    WORDPRESS_NONCE_KEY="$WP_NONCE_KEY" \
    WORDPRESS_AUTH_SALT="$WP_AUTH_SALT" \
    WORDPRESS_SECURE_AUTH_SALT="$WP_SECURE_AUTH_SALT" \
    WORDPRESS_LOGGED_IN_SALT="$WP_LOGGED_IN_SALT" \
    WORDPRESS_NONCE_SALT="$WP_NONCE_SALT" \
    WP_DEBUG="false" \
    WORDPRESS_TABLE_PREFIX="wp_" \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT
```

### 2.4 Verify Container Deployment

```bash
# Check container status
az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --query "{Name:name,State:containers[0].instanceView.currentState.state,FQDN:ipAddress.fqdn}" --output table

# Get container logs
az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME

# Get container FQDN
export WORDPRESS_URL=$(az container show \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --query ipAddress.fqdn -o tsv)

echo "WordPress URL: http://$WORDPRESS_URL"
```

## Step 3: WordPress Initial Configuration

### 3.1 WordPress Setup

```bash
# Wait for WordPress to be ready
echo "Waiting for WordPress to start..."
until curl -f http://$WORDPRESS_URL/wp-admin/install.php; do
  sleep 10
  echo "Still waiting..."
done

# WordPress CLI setup (if included in container)
echo "WordPress is ready at: http://$WORDPRESS_URL"
echo "Admin URL: http://$WORDPRESS_URL/wp-admin"
```

### 3.2 Install Required Plugins

Create a plugin installation script:

```bash
cat > install-wp-plugins.sh << 'EOF'
#!/bin/bash

# WordPress CLI commands to run inside container
az container exec \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_NAME \
  --exec-command "/bin/bash -c '
    # Install WP-GraphQL
    wp plugin install wp-graphql --activate --allow-root
    
    # Install Redis Object Cache
    wp plugin install redis-cache --activate --allow-root
    
    # Enable Redis cache
    wp redis enable --allow-root
    
    # Install Advanced Custom Fields
    wp plugin install advanced-custom-fields --activate --allow-root
    
    # Install WPGraphQL for Advanced Custom Fields
    wp plugin install wp-graphql-acf --activate --allow-root
    
    # Set permalink structure
    wp rewrite structure '/%postname%/' --allow-root
    
    # Update site URL for headless setup
    wp option update home 'http://$WORDPRESS_URL' --allow-root
    wp option update siteurl 'http://$WORDPRESS_URL' --allow-root
    
    echo "WordPress plugins installed successfully"
    '"
EOF

chmod +x install-wp-plugins.sh
./install-wp-plugins.sh
```

## Step 4: Application Gateway Setup (Load Balancer + WAF)

### 4.1 Create Application Gateway

```bash
export APP_GATEWAY_NAME="agw-${PROJECT_NAME}-${ENVIRONMENT}"
export PUBLIC_IP_NAME="pip-agw-${PROJECT_NAME}-${ENVIRONMENT}"
export APP_GATEWAY_SUBNET="subnet-appgateway"

# Create subnet for Application Gateway
az network vnet subnet create \
  --name $APP_GATEWAY_SUBNET \
  --vnet-name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --address-prefix 10.0.4.0/24

# Create public IP for Application Gateway
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $PUBLIC_IP_NAME \
  --location "$LOCATION" \
  --sku Standard \
  --allocation-method Static \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Create Application Gateway
az network application-gateway create \
  --name $APP_GATEWAY_NAME \
  --location "$LOCATION" \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --subnet $APP_GATEWAY_SUBNET \
  --capacity 2 \
  --sku Standard_v2 \
  --http-settings-cookie-based-affinity Disabled \
  --frontend-port 80 \
  --http-settings-port 80 \
  --http-settings-protocol Http \
  --public-ip-address $PUBLIC_IP_NAME \
  --servers $WORDPRESS_URL \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT
```

### 4.2 Configure WAF Policy

```bash
export WAF_POLICY_NAME="waf-${PROJECT_NAME}-${ENVIRONMENT}"

# Create WAF policy
az network application-gateway waf-policy create \
  --name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --location "$LOCATION" \
  --type OWASP \
  --version 3.2 \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT

# Associate WAF policy with Application Gateway
az network application-gateway waf-policy policy-setting update \
  --policy-name $WAF_POLICY_NAME \
  --resource-group $RESOURCE_GROUP \
  --state Enabled \
  --mode Prevention \
  --request-body-check true \
  --max-request-body-size 128

# Apply WAF policy to Application Gateway
az network application-gateway update \
  --name $APP_GATEWAY_NAME \
  --resource-group $RESOURCE_GROUP \
  --waf-policy $WAF_POLICY_NAME
```

## Step 5: Frontend Static Web App Configuration

### 5.1 Configure Static Web App Environment

```bash
# Get Application Gateway public IP
export AGW_PUBLIC_IP=$(az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name $PUBLIC_IP_NAME \
  --query ipAddress -o tsv)

# Set environment variables for Static Web App
az staticwebapp appsettings set \
  --name $STATICWEB_NAME \
  --resource-group $RESOURCE_GROUP \
  --setting-names \
    WORDPRESS_GRAPHQL_ENDPOINT="http://$AGW_PUBLIC_IP/graphql" \
    NEXT_PUBLIC_WORDPRESS_URL="http://$AGW_PUBLIC_IP" \
    NODE_ENV="production"
```

### 5.2 Configure Build Settings

Create build configuration for Static Web App:

```bash
cat > staticwebapp.config.json << 'EOF'
{
  "routes": [
    {
      "route": "/api/*",
      "allowedRoles": ["anonymous"]
    },
    {
      "route": "/*",
      "serve": "/index.html",
      "statusCode": 200
    }
  ],
  "navigationFallback": {
    "rewrite": "/index.html",
    "exclude": ["/images/*.{png,jpg,gif}", "/css/*"]
  },
  "responseOverrides": {
    "401": {
      "redirect": "/login",
      "statusCode": 302
    },
    "403": {
      "redirect": "/",
      "statusCode": 302
    },
    "404": {
      "redirect": "/404",
      "statusCode": 404
    }
  },
  "globalHeaders": {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "X-XSS-Protection": "1; mode=block"
  },
  "mimeTypes": {
    ".json": "application/json"
  }
}
EOF
```

## Step 6: Health Checks and Monitoring

### 6.1 Container Health Probe

```bash
# Update container with health probe
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
  --environment-variables "${ENV_VARS[@]}" \
  --command-line "/bin/bash -c 'apache2-foreground'" \
  --tags project=$PROJECT_NAME environment=$ENVIRONMENT
```

### 6.2 Application Insights Integration

```bash
# Get Application Insights key
export APP_INSIGHTS_KEY=$(az keyvault secret show \
  --vault-name $KEY_VAULT_NAME \
  --name "app-insights-key" \
  --query value -o tsv)

# Add Application Insights to Static Web App
az staticwebapp appsettings set \
  --name $STATICWEB_NAME \
  --resource-group $RESOURCE_GROUP \
  --setting-names \
    APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=$APP_INSIGHTS_KEY"
```

## Step 7: SSL Certificate Setup

### 7.1 Let's Encrypt Certificate (Free)

```bash
# Install certbot in a temporary container
az container create \
  --resource-group $RESOURCE_GROUP \
  --name "certbot-temp" \
  --image certbot/certbot \
  --restart-policy Never \
  --command-line "certbot certonly --webroot -w /var/www/certbot -d yourdomain.com --email your-email@domain.com --agree-tos --non-interactive"

# Note: This is a simplified example. For production, use Azure Key Vault certificates
# or configure automatic certificate management
```

### 7.2 Azure Managed Certificate (Recommended)

```bash
# This will be configured in the DNS and SSL setup guide
echo "SSL configuration will be completed in dns-ssl-setup.md"
```

## Step 8: Deployment Verification

### 8.1 Test WordPress Backend

```bash
# Test WordPress health
echo "Testing WordPress endpoints..."
curl -I http://$AGW_PUBLIC_IP/wp-json/wp/v2/
curl -I http://$AGW_PUBLIC_IP/graphql

# Test database connectivity
echo "Testing database connection..."
curl -X POST http://$AGW_PUBLIC_IP/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "query { posts { nodes { id title } } }"}'
```

### 8.2 Test Frontend Static App

```bash
# Get Static Web App URL
export STATIC_APP_URL=$(az staticwebapp show \
  --name $STATICWEB_NAME \
  --resource-group $RESOURCE_GROUP \
  --query defaultHostname -o tsv)

echo "Static Web App URL: https://$STATIC_APP_URL"

# Test frontend
curl -I https://$STATIC_APP_URL
```

### 8.3 End-to-End Test

```bash
cat > test-deployment.sh << 'EOF'
#!/bin/bash

echo "=== Deployment Verification Test ==="

# Test WordPress backend
echo "1. Testing WordPress backend..."
WP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$AGW_PUBLIC_IP/wp-json/wp/v2/)
if [ "$WP_STATUS" = "200" ]; then
  echo "✓ WordPress REST API is working"
else
  echo "✗ WordPress REST API failed (Status: $WP_STATUS)"
fi

# Test GraphQL endpoint
echo "2. Testing GraphQL endpoint..."
GQL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$AGW_PUBLIC_IP/graphql)
if [ "$GQL_STATUS" = "200" ] || [ "$GQL_STATUS" = "400" ]; then
  echo "✓ GraphQL endpoint is accessible"
else
  echo "✗ GraphQL endpoint failed (Status: $GQL_STATUS)"
fi

# Test frontend
echo "3. Testing frontend..."
FE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://$STATIC_APP_URL)
if [ "$FE_STATUS" = "200" ]; then
  echo "✓ Frontend is accessible"
else
  echo "✗ Frontend failed (Status: $FE_STATUS)"
fi

# Test database connection
echo "4. Testing database connectivity..."
DB_TEST=$(az mysql flexible-server show --name $MYSQL_SERVER_NAME --resource-group $RESOURCE_GROUP --query state -o tsv)
if [ "$DB_TEST" = "Ready" ]; then
  echo "✓ Database is ready"
else
  echo "✗ Database not ready (State: $DB_TEST)"
fi

# Test Redis cache
echo "5. Testing Redis cache..."
REDIS_TEST=$(az redis show --name $REDIS_CACHE_NAME --resource-group $RESOURCE_GROUP --query redisVersion -o tsv)
if [ ! -z "$REDIS_TEST" ]; then
  echo "✓ Redis cache is running (Version: $REDIS_TEST)"
else
  echo "✗ Redis cache not accessible"
fi

echo "=== Deployment verification complete ==="
EOF

chmod +x test-deployment.sh
./test-deployment.sh
```

## Step 9: Update Environment Configuration

```bash
# Update .env.azure with deployment URLs
cat >> .env.azure << EOF

# Deployment URLs
WORDPRESS_URL=http://$WORDPRESS_URL
APP_GATEWAY_IP=$AGW_PUBLIC_IP
STATIC_WEB_APP_URL=https://$STATIC_APP_URL
GRAPHQL_ENDPOINT=http://$AGW_PUBLIC_IP/graphql

# Container Details
CONTAINER_NAME=$CONTAINER_NAME
APP_GATEWAY_NAME=$APP_GATEWAY_NAME
WAF_POLICY_NAME=$WAF_POLICY_NAME
EOF

echo "Deployment completed successfully!"
echo "Configuration updated in .env.azure"
```

## Troubleshooting

### Common Issues

1. **Container Won't Start**
   ```bash
   # Check container logs
   az container logs --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --follow
   
   # Check container events
   az container show --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME
   ```

2. **Database Connection Failed**
   ```bash
   # Test database connectivity
   az mysql flexible-server connect --name $MYSQL_SERVER_NAME --admin-user $MYSQL_USERNAME
   
   # Check firewall rules
   az mysql flexible-server firewall-rule list --name $MYSQL_SERVER_NAME --resource-group $RESOURCE_GROUP
   ```

3. **GraphQL Not Working**
   ```bash
   # Check WordPress plugins
   az container exec --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME --exec-command "wp plugin list --allow-root"
   ```

4. **Static Web App Build Failed**
   - Check GitHub Actions logs in repository
   - Verify build configuration in `staticwebapp.config.json`
   - Check environment variables in Static Web App settings

### Useful Commands

```bash
# Container management
az container restart --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME
az container stop --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME
az container start --resource-group $RESOURCE_GROUP --name $CONTAINER_NAME

# Application Gateway management
az network application-gateway stop --name $APP_GATEWAY_NAME --resource-group $RESOURCE_GROUP
az network application-gateway start --name $APP_GATEWAY_NAME --resource-group $RESOURCE_GROUP

# Static Web App management
az staticwebapp show --name $STATICWEB_NAME --resource-group $RESOURCE_GROUP
az staticwebapp appsettings list --name $STATICWEB_NAME --resource-group $RESOURCE_GROUP
```

## Performance Optimization

1. **Container Resources**
   - Monitor CPU and memory usage
   - Scale container resources based on load
   
2. **Application Gateway**
   - Enable HTTP/2
   - Configure compression
   - Optimize backend pool health probes

3. **Database**
   - Monitor connection pool usage
   - Optimize query performance
   - Consider read replicas for high traffic

4. **Redis Cache**
   - Monitor cache hit ratio
   - Configure appropriate eviction policies
   - Scale Redis tier based on memory usage

## Security Hardening

1. **Network Security**
   - Use private endpoints where possible
   - Configure NSG rules strictly
   - Enable DDoS protection

2. **Container Security**
   - Use minimal base images
   - Keep containers updated
   - Run containers as non-root user

3. **Database Security**
   - Use SSL connections
   - Regularly rotate passwords
   - Enable audit logging

4. **Application Gateway**
   - Enable WAF in Prevention mode
   - Configure custom WAF rules
   - Enable access logging

## Next Steps

1. Configure [Database Optimization](./database-setup.md)
2. Set up [CDN Configuration](./cdn-configuration.md) 
3. Implement [DNS and SSL Setup](./dns-ssl-setup.md)
4. Configure [Auto-scaling](./scaling-configuration.md)
5. Set up [Monitoring and Alerting](../monitoring/azure-monitor-setup.md)
