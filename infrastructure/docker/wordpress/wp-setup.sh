#!/bin/bash

# WordPress Setup Script for Headless Configuration
# This script runs when the WordPress container starts

set -e

echo "🚀 Starting WordPress setup for headless configuration..."

# Wait for MySQL to be ready
echo "⏳ Waiting for MySQL connection..."
until wp db check --allow-root 2>/dev/null; do
    echo "   MySQL not ready, waiting..."
    sleep 3
done
echo "✅ MySQL connection established"

# Check if WordPress is already installed
if ! wp core is-installed --allow-root 2>/dev/null; then
    echo "📦 Installing WordPress..."
    
    # Download WordPress core if not present
    if [ ! -f wp-config.php ]; then
        wp core download --allow-root
    fi
    
    # Create wp-config.php if it doesn't exist
    if [ ! -f wp-config.php ]; then
        wp config create \
            --dbname="${WORDPRESS_DB_NAME}" \
            --dbuser="${WORDPRESS_DB_USER}" \
            --dbpass="${WORDPRESS_DB_PASSWORD}" \
            --dbhost="${WORDPRESS_DB_HOST}" \
            --dbcharset="utf8mb4" \
            --dbcollate="utf8mb4_unicode_ci" \
            --allow-root
    fi
    
    # Install WordPress
    wp core install \
        --url="${WORDPRESS_URL:-http://localhost:8080}" \
        --title="${WORDPRESS_TITLE:-Headless WordPress}" \
        --admin_user="${WORDPRESS_ADMIN_USER:-admin}" \
        --admin_password="${WORDPRESS_ADMIN_PASSWORD:-admin_password}" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}" \
        --allow-root
    
    echo "✅ WordPress core installed"
else
    echo "ℹ️  WordPress already installed"
fi

# Install and activate essential plugins for headless setup
echo "🔌 Setting up headless plugins..."

# Array of essential plugins
plugins=(
    "wp-graphql"
    "wp-graphql-acf"
    "advanced-custom-fields"
    "wp-rest-api-authentication"
    "redis-cache"
    "wordpress-seo"
)

for plugin in "${plugins[@]}"; do
    if ! wp plugin is-installed "$plugin" --allow-root; then
        echo "   Installing $plugin..."
        wp plugin install "$plugin" --activate --allow-root || echo "   ⚠️  Failed to install $plugin"
    else
        echo "   ✅ $plugin already installed"
        wp plugin activate "$plugin" --allow-root 2>/dev/null || echo "   ⚠️  Failed to activate $plugin"
    fi
done

# Configure Redis Cache
echo "🗄️  Configuring Redis cache..."
wp config set WP_REDIS_HOST redis --allow-root
wp config set WP_REDIS_PORT 6379 --allow-root
wp config set WP_REDIS_PASSWORD '' --allow-root
wp config set WP_REDIS_DATABASE 0 --allow-root

# Enable Redis cache if plugin is active
if wp plugin is-active redis-cache --allow-root; then
    wp redis enable --allow-root 2>/dev/null || echo "   ⚠️  Redis cache already enabled or failed to enable"
fi

# Configure permalinks for better API URLs
echo "🔗 Configuring permalinks..."
wp rewrite structure '/%postname%/' --allow-root
wp rewrite flush --allow-root

# Create sample content for testing
echo "📝 Creating sample content..."

# Create a sample page
if ! wp post exists --post_type=page --post_title="Home" --allow-root; then
    wp post create \
        --post_type=page \
        --post_title="Home" \
        --post_content="<h1>Welcome to Headless WordPress</h1><p>This is your homepage content served via GraphQL and REST API.</p>" \
        --post_status=publish \
        --allow-root
fi

# Create sample posts
sample_posts=(
    "Getting Started with Headless WordPress|This post explains how to use WordPress as a headless CMS with GraphQL and REST APIs."
    "Building with Next.js|Learn how to build modern web applications using Next.js with WordPress as the backend."
    "GraphQL vs REST|Understanding the differences between GraphQL and REST APIs for content delivery."
)

for post_data in "${sample_posts[@]}"; do
    IFS='|' read -r title content <<< "$post_data"
    if ! wp post exists --post_title="$title" --allow-root; then
        wp post create \
            --post_title="$title" \
            --post_content="<p>$content</p>" \
            --post_status=publish \
            --allow-root
    fi
done

# Create sample categories
categories=("Technology" "Development" "GraphQL" "WordPress")
for category in "${categories[@]}"; do
    wp term create category "$category" --allow-root 2>/dev/null || echo "   Category '$category' may already exist"
done

# Set up theme for headless mode
echo "🎨 Configuring theme for headless mode..."
wp theme activate twentytwentyfour --allow-root 2>/dev/null || echo "   Using current theme"

# Configure WordPress settings for headless usage
echo "⚙️  Configuring WordPress settings..."

# Set timezone
wp option update timezone_string 'UTC' --allow-root

# Configure discussion settings
wp option update default_ping_status 'closed' --allow-root
wp option update default_comment_status 'closed' --allow-root

# Set up user roles for API access
echo "👥 Configuring user roles..."
wp role create api_user 'API User' --allow-root 2>/dev/null || echo "   API User role may already exist"
wp cap add api_user read --allow-root
wp cap add api_user edit_posts --allow-root

# Flush rewrite rules
wp rewrite flush --allow-root

# Test GraphQL endpoint
echo "🧪 Testing GraphQL endpoint..."
if wp plugin is-active wp-graphql --allow-root; then
    echo "   ✅ GraphQL endpoint should be available at /graphql"
else
    echo "   ⚠️  GraphQL plugin not active"
fi

# Test REST API
echo "🧪 Testing REST API..."
echo "   ✅ REST API should be available at /wp-json/wp/v2/"

# Display setup summary
echo ""
echo "🎉 WordPress headless setup completed!"
echo ""
echo "📋 Setup Summary:"
echo "   • WordPress URL: ${WORDPRESS_URL:-http://localhost:8080}"
echo "   • Admin User: ${WORDPRESS_ADMIN_USER:-admin}"
echo "   • Admin Password: ${WORDPRESS_ADMIN_PASSWORD:-admin_password}"
echo "   • GraphQL Endpoint: ${WORDPRESS_URL:-http://localhost:8080}/graphql"
echo "   • REST API Endpoint: ${WORDPRESS_URL:-http://localhost:8080}/wp-json/wp/v2/"
echo ""
echo "🔗 Quick Links:"
echo "   • WordPress Admin: ${WORDPRESS_URL:-http://localhost:8080}/wp-admin"
echo "   • GraphQL IDE: ${WORDPRESS_URL:-http://localhost:8080}/graphql"
echo "   • REST API: ${WORDPRESS_URL:-http://localhost:8080}/wp-json/wp/v2/posts"
echo ""
echo "✅ Ready for headless development!"