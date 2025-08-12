#!/bin/bash
set -euo pipefail

# Custom Docker entrypoint for headless WordPress setup
echo "🚀 Starting WordPress container with headless configuration..."

# Source the original WordPress entrypoint
source /usr/local/bin/docker-entrypoint.sh

# Function to wait for database
wait_for_db() {
    echo "⏳ Waiting for database connection..."
    while ! mysqladmin ping -h"$WORDPRESS_DB_HOST" --silent; do
        sleep 1
    done
    echo "✅ Database is ready!"
}

# Custom initialization
headless_init() {
    echo "🔧 Initializing headless WordPress setup..."
    
    # Wait for database if needed
    if [ -n "${WORDPRESS_DB_HOST:-}" ]; then
        wait_for_db
    fi
    
    # Run our WordPress setup script
    if [ -f "/usr/local/bin/wp-setup.sh" ]; then
        echo "📦 Running WordPress headless setup..."
        bash /usr/local/bin/wp-setup.sh
    fi
    
    echo "✅ Headless WordPress initialization complete!"
}

# Override the main function to add our custom initialization
exec_main() {
    # Run original WordPress setup
    docker_entrypoint_main "$@"
    
    # Run our headless setup if this is the first time
    if [ "$1" = 'apache2-foreground' ]; then
        headless_init
    fi
}

# Execute with our custom main function
exec_main "$@"