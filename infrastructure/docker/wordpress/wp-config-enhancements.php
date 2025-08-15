<?php
/**
 * WordPress Configuration Enhancements for Headless Static Operation
 */

// Enable GraphQL debugging
if (\!defined('GRAPHQL_DEBUG')) {
    define('GRAPHQL_DEBUG', true);
}

// Disable XML-RPC
if (\!defined('XMLRPC_DISABLED')) {
    define('XMLRPC_DISABLED', true);
}

// Optimize for headless operation
if (\!defined('WP_USE_THEMES')) {
    define('WP_USE_THEMES', false);
}

// Enable CORS for GraphQL
add_action('init', function() {
    // Add CORS headers for GraphQL
    add_action('wp_loaded', function() {
        if (isset($_GET['graphql']) || strpos($_SERVER['REQUEST_URI'], '/graphql') \!== false) {
            header('Access-Control-Allow-Origin: *');
            header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
            header('Access-Control-Allow-Headers: Content-Type, Authorization');
            
            if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
                exit(0);
            }
        }
    });
});

// Ensure pretty permalinks
add_action('init', function() {
    if (get_option('permalink_structure') == '') {
        update_option('permalink_structure', '/%postname%/');
        flush_rewrite_rules();
    }
});

// Auto-activate custom theme and plugins on initialization
add_action('wp_loaded', function() {
    // Switch to custom headless theme if not already active
    $current_theme = get_option('template');
    if ($current_theme \!== 'headless-static') {
        if (file_exists(WP_CONTENT_DIR . '/themes/custom/headless-static/style.css')) {
            switch_theme('headless-static');
        }
    }
    
    // Auto-activate custom plugin
    $plugin_file = 'custom/headless-static-enhancements/headless-static-enhancements.php';
    if (\!is_plugin_active($plugin_file)) {
        $plugin_path = WP_PLUGIN_DIR . '/' . $plugin_file;
        if (file_exists($plugin_path)) {
            activate_plugin($plugin_file);
        }
    }
});

// Set default content for headless operation
add_action('wp_loaded', function() {
    // Create sample navigation menu if none exists
    $menus = wp_get_nav_menus();
    if (empty($menus)) {
        $menu_id = wp_create_nav_menu('Main Navigation');
        
        if (\!is_wp_error($menu_id)) {
            // Add home page
            wp_update_nav_menu_item($menu_id, 0, [
                'menu-item-title' => 'Home',
                'menu-item-url' => home_url('/'),
                'menu-item-status' => 'publish'
            ]);
            
            // Add sample page if it exists
            $sample_page = get_page_by_title('Sample Page');
            if ($sample_page) {
                wp_update_nav_menu_item($menu_id, 0, [
                    'menu-item-title' => 'About',
                    'menu-item-object' => 'page',
                    'menu-item-object-id' => $sample_page->ID,
                    'menu-item-type' => 'post_type',
                    'menu-item-status' => 'publish'
                ]);
            }
            
            // Set as primary menu location
            $locations = get_theme_mod('nav_menu_locations');
            $locations['primary'] = $menu_id;
            set_theme_mod('nav_menu_locations', $locations);
        }
    }
});
EOF < /dev/null