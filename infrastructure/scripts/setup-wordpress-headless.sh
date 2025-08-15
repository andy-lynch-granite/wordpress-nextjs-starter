#!/bin/bash
# Setup WordPress for Headless Operation

set -e

# Configuration
WORDPRESS_URL="https://wordpressnextjs-dev-wordpress.ashyrock-47f94abe.northeurope.azurecontainerapps.io"
CONTAINER_APP="wordpressnextjs-dev-wordpress"
RESOURCE_GROUP="wordpressnextjs-dev-rg"

# WordPress admin credentials
WP_TITLE="${1:-WordPress NextJS Headless}"
WP_ADMIN_USER="${2:-admin}"
WP_ADMIN_PASSWORD="${3:-$(openssl rand -base64 20)}"
WP_ADMIN_EMAIL="${4:-admin@example.com}"

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

log "Setting up WordPress for headless operation..."
log "WordPress URL: $WORDPRESS_URL"
log "Admin User: $WP_ADMIN_USER"
log "Admin Email: $WP_ADMIN_EMAIL"

# First, let's complete the WordPress installation
log "Completing WordPress installation..."

# Use Azure Container Apps exec to run WP-CLI commands inside the container
log "Installing WordPress core..."
az containerapp exec \
    --name "$CONTAINER_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --command "wp core install \
        --url='$WORDPRESS_URL' \
        --title='$WP_TITLE' \
        --admin_user='$WP_ADMIN_USER' \
        --admin_password='$WP_ADMIN_PASSWORD' \
        --admin_email='$WP_ADMIN_EMAIL' \
        --skip-email \
        --allow-root"

success "WordPress core installation completed!"

log "Installing and configuring WPGraphQL plugin..."
az containerapp exec \
    --name "$CONTAINER_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --command "wp plugin install wp-graphql --activate --allow-root"

log "Installing additional headless plugins..."
az containerapp exec \
    --name "$CONTAINER_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --command "wp plugin install wp-graphql-cors --activate --allow-root"

# Configure WordPress for headless operation
log "Configuring WordPress settings for headless mode..."

# Set permalink structure for better SEO
az containerapp exec \
    --name "$CONTAINER_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --command "wp rewrite structure '/%postname%/' --allow-root"

# Enable GraphQL for public queries
az containerapp exec \
    --name "$CONTAINER_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --command "wp option update graphql_general_settings '{\"public_introspection_enabled\":\"on\",\"query_logs_enabled\":\"on\"}' --format=json --allow-root"

# Configure CORS for frontend
az containerapp exec \
    --name "$CONTAINER_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --command "wp option update graphql_cors_settings '{\"enabled\":true,\"origins\":[\"https://wordpressnextjsdevstatic.z16.web.core.windows.net\",\"http://localhost:3000\"]}' --format=json --allow-root"

# Create some sample content
log "Creating sample content for testing..."

# Create a sample post
az containerapp exec \
    --name "$CONTAINER_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --command "wp post create \
        --post_title='Welcome to Headless WordPress' \
        --post_content='<p>This is a sample post created via WP-CLI for testing the headless WordPress setup with Next.js.</p><p>The WordPress backend is running on Azure Container Apps and serving content via GraphQL to the Next.js frontend.</p>' \
        --post_status=publish \
        --post_author=1 \
        --allow-root"

# Create another sample post
az containerapp exec \
    --name "$CONTAINER_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --command "wp post create \
        --post_title='Azure Deployment Success' \
        --post_content='<p>This headless WordPress + Next.js setup has been successfully deployed to Microsoft Azure!</p><h2>Architecture</h2><ul><li>Frontend: Next.js on Azure Static Web Apps</li><li>Backend: WordPress on Azure Container Apps</li><li>Database: MySQL Flexible Server</li><li>CI/CD: GitHub Actions</li></ul>' \
        --post_status=publish \
        --post_author=1 \
        --allow-root"

# Create a sample page
az containerapp exec \
    --name "$CONTAINER_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --command "wp post create \
        --post_title='About Us' \
        --post_content='<p>This is a sample About page demonstrating how pages work in the headless WordPress setup.</p>' \
        --post_status=publish \
        --post_type=page \
        --post_author=1 \
        --allow-root"

success "WordPress headless setup completed successfully!"

log "Testing GraphQL endpoint..."
GRAPHQL_TEST=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"query":"query { posts { nodes { title slug content excerpt } } }"}' \
    "$WORDPRESS_URL/graphql" | jq -r '.data.posts.nodes | length')

if [ "$GRAPHQL_TEST" -gt 0 ]; then
    success "GraphQL endpoint is working! Found $GRAPHQL_TEST posts."
else
    warn "GraphQL endpoint might need additional configuration."
fi

echo ""
echo "================================="
echo "   WORDPRESS HEADLESS SETUP"
echo "================================="
echo "WordPress URL: $WORDPRESS_URL"
echo "Admin URL: $WORDPRESS_URL/wp-admin/"
echo "GraphQL Endpoint: $WORDPRESS_URL/graphql"
echo ""
echo "ADMIN CREDENTIALS:"
echo "Username: $WP_ADMIN_USER"
echo "Password: $WP_ADMIN_PASSWORD"
echo "Email: $WP_ADMIN_EMAIL"
echo ""
echo "NEXT STEPS:"
echo "1. Update frontend environment variables:"
echo "   NEXT_PUBLIC_WORDPRESS_API_URL=$WORDPRESS_URL/graphql"
echo "2. Test GraphQL endpoint:"
echo "   curl -X POST -H 'Content-Type: application/json' \\"
echo "   -d '{\"query\":\"{ posts { nodes { title slug } } }\"}' \\"
echo "   $WORDPRESS_URL/graphql"
echo "3. Deploy updated frontend"
echo "================================="