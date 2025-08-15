<?php
// WordPress setup script for headless operation
define('WP_USE_THEMES', false);
require_once '/var/www/html/wp-config.php';
require_once '/var/www/html/wp-load.php';

echo "Setting up Headless WordPress...\n";

// 1. Configure permalinks
echo "1. Setting up permalinks...\n";
if (get_option('permalink_structure') == '') {
    update_option('permalink_structure', '/%postname%/');
    flush_rewrite_rules();
    echo "   Pretty permalinks enabled\n";
} else {
    echo "   Permalinks already configured\n";
}

// 2. Set default options
echo "2. Configuring options...\n";
update_option('headless_build_version', '1.0.0');
update_option('headless_last_build', current_time('mysql'));
echo "   Default options set\n";

// 3. Test GraphQL
echo "3. Testing GraphQL...\n";
if (class_exists('WPGraphQL')) {
    echo "   WPGraphQL is active\n";
} else {
    echo "   WPGraphQL plugin not found\n";
}

// 4. Check content
echo "4. Checking content...\n";
$posts_count = wp_count_posts()->publish;
$pages_count = wp_count_posts('page')->publish;
echo "   Posts: $posts_count, Pages: $pages_count\n";

echo "\nHeadless WordPress setup completed!\n";
echo "\nEndpoints:\n";
echo "- GraphQL: " . home_url('/graphql') . "\n";
echo "- REST API: " . home_url('/wp-json/') . "\n";
echo "- Admin: " . admin_url() . "\n";
