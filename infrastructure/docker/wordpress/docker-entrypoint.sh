#!/bin/bash
set -euo pipefail

# Source the original WordPress entrypoint
source /usr/local/bin/docker-entrypoint.sh

# Function to wait for MySQL
wait_for_mysql() {
    echo "Waiting for MySQL to be ready..."
    until wp db check --allow-root 2>/dev/null; do
        echo "MySQL is unavailable - sleeping"
        sleep 2
    done
    echo "MySQL is ready!"
}

# Function to setup WordPress
setup_wordpress() {
    echo "Setting up WordPress..."
    
    # Wait for MySQL
    wait_for_mysql
    
    # Check if WordPress is already installed
    if ! wp core is-installed --allow-root 2>/dev/null; then
        echo "Installing WordPress..."
        
        # Download WordPress core if not present
        if [ ! -f wp-config.php ]; then
            wp core download --allow-root
        fi
        
        # Create wp-config.php
        wp config create \
            --dbhost="$WORDPRESS_DB_HOST" \
            --dbname="$WORDPRESS_DB_NAME" \
            --dbuser="$WORDPRESS_DB_USER" \
            --dbpass="$WORDPRESS_DB_PASSWORD" \
            --allow-root
        
        # Install WordPress
        wp core install \
            --url="http://localhost:8080" \
            --title="Headless WordPress" \
            --admin_user="admin" \
            --admin_password="admin_password" \
            --admin_email="admin@example.com" \
            --skip-email \
            --allow-root
    fi
    
    # Install and activate required plugins
    echo "Installing required plugins..."
    
    # WPGraphQL
    wp plugin install wp-graphql --activate --allow-root || true
    
    # Advanced Custom Fields
    wp plugin install advanced-custom-fields --activate --allow-root || true
    
    # WPGraphQL for ACF
    wp plugin install wp-graphql-acf --activate --allow-root || true
    
    # Redis Object Cache
    wp plugin install redis-cache --activate --allow-root || true
    
    # Enable Redis object cache
    wp redis enable --allow-root || true
    
    # Create sample content if it doesn't exist
    create_sample_content
    
    # Set proper permissions
    chown -R www-data:www-data /var/www/html
    
    echo "WordPress setup completed!"
}

# Function to create sample content
create_sample_content() {
    echo "Creating sample content..."
    
    # Check if sample post exists
    if ! wp post exists 'hello-world-from-wordpress' --allow-root 2>/dev/null; then
        # Create Hello World post
        wp post create \
            --post_title="Hello World from WordPress" \
            --post_content="<p>This is a sample post fetched via GraphQL API from our headless WordPress backend.</p><p>This demonstrates the basic connectivity between WordPress and Next.js.</p><h2>Features Demonstrated</h2><ul><li>GraphQL API integration</li><li>Custom post types</li><li>Featured images</li><li>Categories and tags</li><li>SEO optimization</li></ul>" \
            --post_status="publish" \
            --post_name="hello-world-from-wordpress" \
            --allow-root
    fi
    
    # Create sample page
    if ! wp post exists 'about-us' --allow-root 2>/dev/null; then
        wp post create \
            --post_type="page" \
            --post_title="About Us" \
            --post_content="<p>This is a sample page that demonstrates how WordPress pages are rendered in our Next.js frontend.</p><p>Our headless WordPress + Next.js solution provides:</p><ul><li>Lightning-fast performance with static site generation</li><li>SEO-friendly server-side rendering</li><li>Modern development experience</li><li>Scalable architecture</li></ul>" \
            --post_status="publish" \
            --post_name="about-us" \
            --allow-root
    fi
    
    # Create sample categories
    wp term create category "Technology" --slug="technology" --allow-root || true
    wp term create category "Development" --slug="development" --allow-root || true
    wp term create category "WordPress" --slug="wordpress" --allow-root || true
    
    # Create sample tags
    wp term create post_tag "headless" --slug="headless" --allow-root || true
    wp term create post_tag "nextjs" --slug="nextjs" --allow-root || true
    wp term create post_tag "graphql" --slug="graphql" --allow-root || true
    
    echo "Sample content created!"
}

# Function to configure GraphQL
configure_graphql() {
    echo "Configuring GraphQL..."
    
    # Enable GraphQL introspection in development
    wp option update graphql_general_settings '{
        "public_introspection_enabled": "on",
        "query_log_enabled": "on",
        "query_depth_enabled": "on",
        "query_depth_max": "10",
        "show_in_graphql": true
    }' --format=json --allow-root || true
    
    echo "GraphQL configured!"
}

# Main execution
if [[ "$1" == apache2* ]] || [ "$1" = 'php-fpm' ]; then
    # Setup WordPress on first run
    setup_wordpress
    configure_graphql
fi

# Execute the original entrypoint
exec "$@"
