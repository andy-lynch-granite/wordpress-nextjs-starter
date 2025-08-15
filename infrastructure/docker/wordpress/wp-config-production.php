<?php
/**
 * Production WordPress Configuration for Headless Static Operation
 * Optimizations for performance, security, and headless functionality
 */

// Security hardening
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', true);
define('AUTOMATIC_UPDATER_DISABLED', true);
define('WP_AUTO_UPDATE_CORE', false);
define('FORCE_SSL_ADMIN', true);

// Performance optimizations
define('WP_MEMORY_LIMIT', '512M');
define('WP_MAX_MEMORY_LIMIT', '512M');
define('WP_CACHE', true);
define('COMPRESS_CSS', true);
define('COMPRESS_SCRIPTS', true);
define('CONCATENATE_SCRIPTS', false);
define('ENFORCE_GZIP', true);

// Database optimizations
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);
define('SCRIPT_DEBUG', false);
define('SAVEQUERIES', false);

// GraphQL optimizations
define('GRAPHQL_DEBUG', false);
define('GRAPHQL_QUERY_ANALYZER', true);
define('GRAPHQL_TRACING_ENABLED', false);

// Disable unnecessary features for headless
define('WP_POST_REVISIONS', 5);
define('AUTOSAVE_INTERVAL', 300);
define('WP_CRON_LOCK_TIMEOUT', 60);
define('EMPTY_TRASH_DAYS', 30);

// Headless optimizations
define('WP_USE_THEMES', false);
define('XMLRPC_DISABLED', true);

// Object caching with Redis
define('WP_REDIS_HOST', getenv('WP_REDIS_HOST') ?: 'redis');
define('WP_REDIS_PORT', getenv('WP_REDIS_PORT') ?: 6379);
define('WP_REDIS_PASSWORD', getenv('WP_REDIS_PASSWORD') ?: '');
define('WP_REDIS_DATABASE', getenv('WP_REDIS_DATABASE') ?: 0);
define('WP_REDIS_TIMEOUT', 1);
define('WP_REDIS_READ_TIMEOUT', 1);

// Content delivery optimizations
add_action('init', function() {
    // Remove emoji support
    remove_action('wp_head', 'print_emoji_detection_script', 7);
    remove_action('wp_print_styles', 'print_emoji_styles');
    remove_action('admin_print_scripts', 'print_emoji_detection_script');
    remove_action('admin_print_styles', 'print_emoji_styles');
    remove_filter('the_content_feed', 'wp_staticize_emoji');
    remove_filter('comment_text_rss', 'wp_staticize_emoji');
    remove_filter('wp_mail', 'wp_staticize_emoji_for_email');
    
    // Remove other unnecessary features
    remove_action('wp_head', 'wp_generator');
    remove_action('wp_head', 'rsd_link');
    remove_action('wp_head', 'wlwmanifest_link');
    remove_action('wp_head', 'wp_shortlink_wp_head');
    remove_action('wp_head', 'adjacent_posts_rel_link_wp_head');
    remove_action('wp_head', 'feed_links_extra', 3);
    remove_action('wp_head', 'feed_links', 2);
    remove_action('wp_head', 'wp_oembed_add_discovery_links');
    remove_action('wp_head', 'wp_oembed_add_host_js');
    
    // Disable pingbacks
    add_filter('xmlrpc_enabled', '__return_false');
    add_filter('wp_headers', function($headers) {
        unset($headers['X-Pingback']);
        return $headers;
    });
});

// CORS headers for GraphQL API
add_action('wp_loaded', function() {
    if (isset($_GET['graphql']) || strpos($_SERVER['REQUEST_URI'], '/graphql') \!== false) {
        $origin = getenv('FRONTEND_URL') ?: '*';
        header("Access-Control-Allow-Origin: $origin");
        header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type, Authorization, X-WP-Nonce');
        header('Access-Control-Allow-Credentials: true');
        header('Access-Control-Max-Age: 86400');
        
        if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
            http_response_code(200);
            exit;
        }
    }
});

// Optimize database queries
add_action('init', function() {
    // Remove unnecessary queries
    remove_action('wp_head', 'wp_generator');
    remove_action('wp_head', 'wp_resource_hints', 2);
    
    // Optimize REST API
    add_filter('rest_authentication_errors', function($result) {
        if (\!empty($result)) {
            return $result;
        }
        
        if (\!is_user_logged_in()) {
            return new WP_Error('rest_not_logged_in', 'You are not currently logged in.', array('status' => 401));
        }
        
        return $result;
    });
});

// Image optimization for headless
add_filter('wp_image_editors', function($editors) {
    return array('WP_Image_Editor_Imagick', 'WP_Image_Editor_GD');
});

// Optimize media handling
add_filter('intermediate_image_sizes_advanced', function($sizes) {
    // Remove unnecessary image sizes for headless operation
    unset($sizes['medium_large']);
    unset($sizes['1536x1536']);
    unset($sizes['2048x2048']);
    return $sizes;
});

// Security headers
add_action('send_headers', function() {
    if (\!is_admin()) {
        header('X-Content-Type-Options: nosniff');
        header('X-Frame-Options: DENY');
        header('X-XSS-Protection: 1; mode=block');
        header('Referrer-Policy: strict-origin-when-cross-origin');
        header('Permissions-Policy: geolocation=(), microphone=(), camera=()');
    }
});

// Optimize GraphQL queries
add_filter('graphql_connection_max_query_amount', function($max, $source, $args, $context, $info) {
    return 100; // Limit large queries
}, 10, 5);

// Content optimization for static generation
add_action('save_post', function($post_id) {
    // Clear relevant caches when content is updated
    if (function_exists('wp_cache_flush')) {
        wp_cache_flush();
    }
    
    // Update build timestamp
    update_option('headless_last_build', current_time('mysql'));
    
    // Trigger static rebuild webhook
    do_action('headless_content_updated', $post_id);
});

// Optimize menu handling
add_filter('wp_get_nav_menu_items', function($items, $menu, $args) {
    if (empty($items)) {
        return $items;
    }
    
    // Cache menu items
    $cache_key = 'nav_menu_' . $menu->term_id;
    $cached_items = wp_cache_get($cache_key, 'nav_menu');
    
    if ($cached_items \!== false) {
        return $cached_items;
    }
    
    wp_cache_set($cache_key, $items, 'nav_menu', 3600);
    return $items;
}, 10, 3);

// Production logging
if (WP_DEBUG_LOG) {
    ini_set('log_errors', 1);
    ini_set('error_log', '/var/log/wordpress/php_errors.log');
}
EOF < /dev/null