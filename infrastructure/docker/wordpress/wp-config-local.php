<?php
/**
 * Local WordPress configuration file
 * 
 * This file contains local environment specific configurations
 * and is included by the main wp-config.php file.
 */

// Redis Configuration
define('WP_REDIS_HOST', getenv('WP_REDIS_HOST') ?: 'redis');
define('WP_REDIS_PORT', getenv('WP_REDIS_PORT') ?: 6379);
define('WP_REDIS_PASSWORD', getenv('WP_REDIS_PASSWORD') ?: '');
define('WP_REDIS_DATABASE', getenv('WP_REDIS_DATABASE') ?: 0);
define('WP_REDIS_TIMEOUT', 1);
define('WP_REDIS_READ_TIMEOUT', 1);

// GraphQL Configuration
define('GRAPHQL_DEBUG', getenv('GRAPHQL_DEBUG') === '1');
define('GRAPHQL_QUERY_ANALYZER_ENABLED', true);
define('GRAPHQL_QUERY_ANALYZER_MAX_QUERY_DEPTH', 15);
define('GRAPHQL_QUERY_ANALYZER_MAX_QUERY_COMPLEXITY', 1000);

// JWT Authentication
define('JWT_AUTH_SECRET_KEY', getenv('JWT_AUTH_SECRET_KEY') ?: 'your-secret-key-here-change-in-production');
define('JWT_AUTH_CORS_ENABLE', true);

// CORS Settings for development
define('HEADLESS_MODE_CLIENT_URL', getenv('HEADLESS_MODE_CLIENT_URL') ?: 'http://localhost:3000');

// Performance optimizations
define('WP_CACHE', true);
define('COMPRESS_CSS', true);
define('COMPRESS_SCRIPTS', true);
define('CONCATENATE_SCRIPTS', false);
define('ENFORCE_GZIP', true);

// Security headers
define('FORCE_SSL_ADMIN', false); // Set to true in production with HTTPS
define('COOKIE_DOMAIN', '');

// File permissions
define('FS_METHOD', 'direct');

// Additional WordPress settings
define('WP_POST_REVISIONS', 5);
define('AUTOSAVE_INTERVAL', 300);
define('WP_AUTO_UPDATE_CORE', false);
define('DISALLOW_FILE_EDIT', false); // Set to true in production

// Development specific settings
if (getenv('WP_DEBUG') === '1') {
    define('WP_DEBUG_LOG', true);
    define('WP_DEBUG_DISPLAY', false);
    define('SCRIPT_DEBUG', true);
    define('SAVEQUERIES', true);
}

// Memory limit
ini_set('memory_limit', '512M');

// Upload size limits
ini_set('upload_max_filesize', '64M');
ini_set('post_max_size', '64M');
ini_set('max_execution_time', 300);
?>