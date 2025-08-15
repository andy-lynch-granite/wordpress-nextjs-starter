<?php
/**
 * Comprehensive Headless WordPress API Test
 */

require_once '/var/www/html/wp-config.php';
require_once '/var/www/html/wp-load.php';

echo "=== Headless WordPress API Test ===\n\n";

// Test 1: GraphQL Basic Functionality
echo "1. Testing GraphQL Basic Queries...\n";
if (class_exists('WPGraphQL')) {
    echo "   ✓ WPGraphQL is active\n";
    
    // Test basic site info query
    $query = 'query { generalSettings { title description url } }';
    try {
        $result = graphql(['query' => $query]);
        if (\!empty($result['data']['generalSettings'])) {
            echo "   ✓ Site info query successful\n";
            echo "     Site: " . $result['data']['generalSettings']['title'] . "\n";
            echo "     URL: " . $result['data']['generalSettings']['url'] . "\n";
        } else {
            echo "   ✗ Site info query failed\n";
        }
    } catch (Exception $e) {
        echo "   ✗ GraphQL error: " . $e->getMessage() . "\n";
    }
} else {
    echo "   ✗ WPGraphQL not found\n";
}

// Test 2: Content Queries
echo "\n2. Testing Content Queries...\n";
$posts_query = 'query { posts(first: 3) { nodes { id title slug date content excerpt } } }';
try {
    $result = graphql(['query' => $posts_query]);
    if (\!empty($result['data']['posts']['nodes'])) {
        $posts_count = count($result['data']['posts']['nodes']);
        echo "   ✓ Posts query successful ($posts_count posts)\n";
        foreach ($result['data']['posts']['nodes'] as $post) {
            echo "     - " . $post['title'] . " (" . $post['slug'] . ")\n";
        }
    } else {
        echo "   ✗ No posts found\n";
    }
} catch (Exception $e) {
    echo "   ✗ Posts query error: " . $e->getMessage() . "\n";
}

// Test 3: Pages Query
echo "\n3. Testing Pages Queries...\n";
$pages_query = 'query { pages(first: 5) { nodes { id title slug content } } }';
try {
    $result = graphql(['query' => $pages_query]);
    if (\!empty($result['data']['pages']['nodes'])) {
        $pages_count = count($result['data']['pages']['nodes']);
        echo "   ✓ Pages query successful ($pages_count pages)\n";
        foreach ($result['data']['pages']['nodes'] as $page) {
            echo "     - " . $page['title'] . " (" . $page['slug'] . ")\n";
        }
    } else {
        echo "   ✗ No pages found\n";
    }
} catch (Exception $e) {
    echo "   ✗ Pages query error: " . $e->getMessage() . "\n";
}

// Test 4: Menu Queries
echo "\n4. Testing Menu Queries...\n";
$menus_query = 'query { menus { nodes { id name slug } } }';
try {
    $result = graphql(['query' => $menus_query]);
    if (\!empty($result['data']['menus']['nodes'])) {
        $menus_count = count($result['data']['menus']['nodes']);
        echo "   ✓ Menus query successful ($menus_count menus)\n";
        foreach ($result['data']['menus']['nodes'] as $menu) {
            echo "     - " . $menu['name'] . " (" . $menu['slug'] . ")\n";
        }
    } else {
        echo "   ℹ No menus configured\n";
    }
} catch (Exception $e) {
    echo "   ✗ Menus query error: " . $e->getMessage() . "\n";
}

// Test 5: Configuration Check
echo "\n5. Testing Configuration...\n";
$permalink_structure = get_option('permalink_structure');
if (\!empty($permalink_structure)) {
    echo "   ✓ Pretty permalinks enabled: $permalink_structure\n";
} else {
    echo "   ✗ Pretty permalinks not enabled\n";
}

$redis_enabled = class_exists('Redis') || function_exists('redis_connect');
echo "   " . ($redis_enabled ? "✓" : "ℹ") . " Redis support: " . ($redis_enabled ? "Available" : "Not detected") . "\n";

// Test 6: Webhook Configuration
echo "\n6. Testing Webhook Configuration...\n";
$webhook_url = get_option('headless_webhook_url');
if (\!empty($webhook_url)) {
    echo "   ✓ Webhook URL configured: $webhook_url\n";
} else {
    echo "   ℹ Webhook URL not configured\n";
}

$github_repo = get_option('headless_github_repo');
if (\!empty($github_repo)) {
    echo "   ✓ GitHub repository configured: $github_repo\n";
} else {
    echo "   ℹ GitHub repository not configured\n";
}

// Test 7: Performance Settings
echo "\n7. Testing Performance Settings...\n";
$memory_limit = ini_get('memory_limit');
echo "   Memory limit: $memory_limit\n";

$max_execution_time = ini_get('max_execution_time');
echo "   Max execution time: {$max_execution_time}s\n";

// Test 8: Build Information
echo "\n8. Build Information...\n";
$last_build = get_option('headless_last_build');
$build_version = get_option('headless_build_version', '1.0.0');
echo "   Last build: " . ($last_build ?: 'Never') . "\n";
echo "   Build version: $build_version\n";

// Test 9: Content Statistics
echo "\n9. Content Statistics...\n";
$posts_count = wp_count_posts()->publish;
$pages_count = wp_count_posts('page')->publish;
$categories_count = wp_count_terms('category');
$tags_count = wp_count_terms('post_tag');

echo "   Published posts: $posts_count\n";
echo "   Published pages: $pages_count\n";
echo "   Categories: $categories_count\n";
echo "   Tags: $tags_count\n";

// Test 10: Security Check
echo "\n10. Security Configuration...\n";
$file_edit_disabled = defined('DISALLOW_FILE_EDIT') && DISALLOW_FILE_EDIT;
echo "   " . ($file_edit_disabled ? "✓" : "⚠") . " File editing: " . ($file_edit_disabled ? "Disabled" : "Enabled") . "\n";

$auto_update_disabled = defined('AUTOMATIC_UPDATER_DISABLED') && AUTOMATIC_UPDATER_DISABLED;
echo "   " . ($auto_update_disabled ? "✓" : "ℹ") . " Auto updates: " . ($auto_update_disabled ? "Disabled" : "Enabled") . "\n";

echo "\n=== API Endpoints ===\n";
echo "GraphQL: " . home_url('/index.php?graphql') . "\n";
echo "REST API: " . home_url('/wp-json/') . "\n";
echo "Admin: " . admin_url() . "\n";

echo "\n=== Test Completed ===\n";
EOF < /dev/null