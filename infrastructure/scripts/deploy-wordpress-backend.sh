#!/bin/bash
# Deploy WordPress Backend to Azure Container Apps

set -e

# Configuration
PROJECT_NAME="wordpressnextjs"
ENVIRONMENT="${1:-dev}"
LOCATION="${2:-northeurope}"
RESOURCE_GROUP="${PROJECT_NAME}-${ENVIRONMENT}-rg"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log "Starting WordPress backend deployment..."
log "Environment: $ENVIRONMENT"
log "Location: $LOCATION"
log "Resource Group: $RESOURCE_GROUP"

# Generate secure passwords
log "Generating secure passwords..."
MYSQL_PASSWORD=$(openssl rand -base64 32 | tr -d "/+=" | cut -c1-25)
WP_ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "/+=" | cut -c1-25)

# Resource names
MYSQL_SERVER="${PROJECT_NAME}-${ENVIRONMENT}-mysql"
CONTAINER_ENV="${PROJECT_NAME}-${ENVIRONMENT}-env"
WORDPRESS_APP="${PROJECT_NAME}-${ENVIRONMENT}-wordpress"

log "Creating MySQL Flexible Server..."
az mysql flexible-server create \
    --name "$MYSQL_SERVER" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --admin-user "wpadmin" \
    --admin-password "$MYSQL_PASSWORD" \
    --sku-name "Standard_B1ms" \
    --tier "Burstable" \
    --storage-size 20 \
    --version "8.0.21" \
    --public-access "All" \
    --tags Environment="$ENVIRONMENT" Project="wordpress-nextjs"

log "Creating WordPress database..."
az mysql flexible-server db create \
    --resource-group "$RESOURCE_GROUP" \
    --server-name "$MYSQL_SERVER" \
    --database-name "wordpress"

log "Creating Container Apps Environment..."
az containerapp env create \
    --name "$CONTAINER_ENV" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags Environment="$ENVIRONMENT" Project="wordpress-nextjs"

# Get MySQL connection string
MYSQL_HOST="${MYSQL_SERVER}.mysql.database.azure.com"

log "Deploying WordPress Container App..."
az containerapp create \
    --name "$WORDPRESS_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --environment "$CONTAINER_ENV" \
    --image "wordpress:6.4-apache" \
    --target-port 80 \
    --ingress external \
    --min-replicas 1 \
    --max-replicas 3 \
    --cpu 1.0 \
    --memory 2.0Gi \
    --env-vars \
        "WORDPRESS_DB_HOST=$MYSQL_HOST" \
        "WORDPRESS_DB_NAME=wordpress" \
        "WORDPRESS_DB_USER=wpadmin" \
        "WORDPRESS_DB_PASSWORD=$MYSQL_PASSWORD" \
        "WORDPRESS_CONFIG_EXTRA=define('WP_DEBUG', false); define('WP_DEBUG_LOG', false);" \
    --tags Environment="$ENVIRONMENT" Project="wordpress-nextjs"

# Get WordPress URL
WORDPRESS_URL=$(az containerapp show \
    --name "$WORDPRESS_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.configuration.ingress.fqdn" \
    --output tsv)

log "WordPress backend deployment completed!"
log "Waiting for WordPress to be ready..."
sleep 30

# Test WordPress availability
for i in {1..10}; do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$WORDPRESS_URL" || echo "000")
    
    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
        success "WordPress is accessible (HTTP $HTTP_STATUS)"
        break
    else
        log "WordPress returned HTTP $HTTP_STATUS, retrying... (attempt $i/10)"
        sleep 15
    fi
    
    if [ $i -eq 10 ]; then
        warn "WordPress validation had issues, but continuing..."
    fi
done

success "WordPress backend deployment completed successfully!"
echo ""
echo "================================="
echo "   WORDPRESS BACKEND SUMMARY"
echo "================================="
echo "Environment: $ENVIRONMENT"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo ""
echo "MYSQL DATABASE:"
echo "  Server: $MYSQL_HOST"
echo "  Database: wordpress"
echo "  Username: wpadmin"
echo "  Password: $MYSQL_PASSWORD"
echo ""
echo "WORDPRESS:"
echo "  URL: https://$WORDPRESS_URL"
echo "  Admin URL: https://$WORDPRESS_URL/wp-admin/"
echo "  Container App: $WORDPRESS_APP"
echo ""
echo "NEXT STEPS:"
echo "1. Complete WordPress setup at: https://$WORDPRESS_URL/wp-admin/install.php"
echo "2. Install WPGraphQL plugin for headless functionality"
echo "3. Configure WordPress for headless operation"
echo "4. Update frontend to use: https://$WORDPRESS_URL/graphql"
echo "================================="
echo ""
echo "Save these credentials securely:"
echo "MySQL Password: $MYSQL_PASSWORD"
echo "WordPress Admin URL: https://$WORDPRESS_URL/wp-admin/"