<?php
/**
 * Plugin Name: Headless Static Enhancements
 * Description: GraphQL and webhook enhancements for static site generation
 * Version: 1.0.0
 * Author: Headless Development Team
 * Text Domain: headless-static-enhancements
 */

// Prevent direct access
if (\!defined('ABSPATH')) {
    exit;
}

class HeadlessStaticEnhancements {
    
    public function __construct() {
        add_action('init', [$this, 'init']);
        add_action('graphql_register_types', [$this, 'register_graphql_types']);
        register_activation_hook(__FILE__, [$this, 'activate']);
        register_deactivation_hook(__FILE__, [$this, 'deactivate']);
    }
    
    public function init() {
        // Add REST API endpoints for build status
        add_action('rest_api_init', [$this, 'register_rest_routes']);
        
        // Add admin notices for headless configuration
        add_action('admin_notices', [$this, 'admin_notices']);
    }
    
    public function register_rest_routes() {
        register_rest_route('headless-static/v1', '/build-status', [
            'methods' => 'GET',
            'callback' => [$this, 'get_build_status'],
            'permission_callback' => '__return_true'
        ]);
        
        register_rest_route('headless-static/v1', '/trigger-build', [
            'methods' => 'POST',
            'callback' => [$this, 'trigger_build'],
            'permission_callback' => function() {
                return current_user_can('manage_options');
            }
        ]);
        
        register_rest_route('headless-static/v1', '/content-hash', [
            'methods' => 'GET',
            'callback' => [$this, 'get_content_hash'],
            'permission_callback' => '__return_true'
        ]);
    }
    
    public function get_build_status() {
        return rest_ensure_response([
            'last_build' => get_option('headless_last_build', ''),
            'build_version' => get_option('headless_build_version', '1.0.0'),
            'content_hash' => $this->get_content_hash_value(),
            'timestamp' => current_time('mysql'),
            'posts_count' => wp_count_posts()->publish,
            'pages_count' => wp_count_posts('page')->publish
        ]);
    }
    
    public function trigger_build() {
        $webhook_url = get_option('headless_webhook_url');
        
        if (empty($webhook_url)) {
            return new WP_Error('no_webhook', 'No webhook URL configured', ['status' => 400]);
        }
        
        // Update build timestamp
        update_option('headless_last_build', current_time('mysql'));
        
        // Trigger webhook
        $payload = [
            'event' => 'manual_trigger',
            'timestamp' => current_time('timestamp'),
            'site_url' => home_url(),
            'user' => wp_get_current_user()->user_login
        ];
        
        $response = wp_remote_post($webhook_url, [
            'method' => 'POST',
            'timeout' => 30,
            'headers' => [
                'Content-Type' => 'application/json',
                'User-Agent' => 'WordPress-Headless-Static/1.0'
            ],
            'body' => json_encode($payload)
        ]);
        
        if (is_wp_error($response)) {
            return new WP_Error('webhook_failed', $response->get_error_message(), ['status' => 500]);
        }
        
        return rest_ensure_response(['success' => true, 'message' => 'Build triggered successfully']);
    }
    
    public function get_content_hash() {
        return rest_ensure_response([
            'hash' => $this->get_content_hash_value(),
            'timestamp' => current_time('mysql')
        ]);
    }
    
    private function get_content_hash_value() {
        // Get all published posts and pages
        $posts = get_posts([
            'numberposts' => -1,
            'post_status' => 'publish',
            'post_type' => ['post', 'page']
        ]);
        
        // Create hash based on content
        $content_data = array_map(function($post) {
            return [
                'id' => $post->ID,
                'modified' => $post->post_modified,
                'title' => $post->post_title,
                'content' => md5($post->post_content)
            ];
        }, $posts);
        
        return md5(serialize($content_data));
    }
    
    public function register_graphql_types() {
        // Register build status type
        register_graphql_object_type('BuildStatus', [
            'description' => 'Build status information',
            'fields' => [
                'lastBuild' => [
                    'type' => 'String',
                    'description' => 'Timestamp of last build'
                ],
                'buildVersion' => [
                    'type' => 'String',
                    'description' => 'Current build version'
                ],
                'contentHash' => [
                    'type' => 'String',
                    'description' => 'Hash of all content for change detection'
                ],
                'postsCount' => [
                    'type' => 'Int',
                    'description' => 'Number of published posts'
                ],
                'pagesCount' => [
                    'type' => 'Int',
                    'description' => 'Number of published pages'
                ]
            ]
        ]);
        
        // Add build status field to root query
        register_graphql_field('RootQuery', 'buildStatus', [
            'type' => 'BuildStatus',
            'description' => 'Get build status information',
            'resolve' => function() {
                return [
                    'lastBuild' => get_option('headless_last_build', ''),
                    'buildVersion' => get_option('headless_build_version', '1.0.0'),
                    'contentHash' => $this->get_content_hash_value(),
                    'postsCount' => wp_count_posts()->publish,
                    'pagesCount' => wp_count_posts('page')->publish
                ];
            }
        ]);
        
        // Enhanced post/page fields for static generation
        register_graphql_field('Post', 'seoTitle', [
            'type' => 'String',
            'description' => 'Custom SEO title',
            'resolve' => function($post) {
                return get_post_meta($post->ID, '_headless_seo_title', true);
            }
        ]);
        
        register_graphql_field('Post', 'seoDescription', [
            'type' => 'String',
            'description' => 'Custom SEO description',
            'resolve' => function($post) {
                return get_post_meta($post->ID, '_headless_seo_description', true);
            }
        ]);
        
        register_graphql_field('Post', 'staticPriority', [
            'type' => 'String',
            'description' => 'Static generation priority',
            'resolve' => function($post) {
                return get_post_meta($post->ID, '_headless_static_priority', true) ?: 'normal';
            }
        ]);
        
        // Add the same fields to pages
        register_graphql_field('Page', 'seoTitle', [
            'type' => 'String',
            'description' => 'Custom SEO title',
            'resolve' => function($post) {
                return get_post_meta($post->ID, '_headless_seo_title', true);
            }
        ]);
        
        register_graphql_field('Page', 'seoDescription', [
            'type' => 'String',
            'description' => 'Custom SEO description',
            'resolve' => function($post) {
                return get_post_meta($post->ID, '_headless_seo_description', true);
            }
        ]);
        
        register_graphql_field('Page', 'staticPriority', [
            'type' => 'String',
            'description' => 'Static generation priority',
            'resolve' => function($post) {
                return get_post_meta($post->ID, '_headless_static_priority', true) ?: 'normal';
            }
        ]);
        
        // Add navigation menu items with enhanced data
        register_graphql_field('RootQuery', 'navigationMenu', [
            'type' => ['list_of' => 'MenuItem'],
            'description' => 'Get navigation menu items',
            'args' => [
                'location' => [
                    'type' => 'String',
                    'description' => 'Menu location'
                ]
            ],
            'resolve' => function($root, $args) {
                $locations = get_nav_menu_locations();
                $menu_id = null;
                
                if (isset($args['location']) && isset($locations[$args['location']])) {
                    $menu_id = $locations[$args['location']];
                } else {
                    // Get first available menu
                    $menus = wp_get_nav_menus();
                    if (\!empty($menus)) {
                        $menu_id = $menus[0]->term_id;
                    }
                }
                
                if (\!$menu_id) {
                    return [];
                }
                
                $menu_items = wp_get_nav_menu_items($menu_id);
                
                return array_map(function($item) {
                    return [
                        'id' => $item->ID,
                        'title' => $item->title,
                        'url' => $item->url,
                        'target' => $item->target,
                        'description' => $item->description,
                        'classes' => implode(' ', $item->classes),
                        'parent' => $item->menu_item_parent,
                        'order' => $item->menu_order
                    ];
                }, $menu_items ?: []);
            }
        ]);
        
        // Register MenuItem type
        register_graphql_object_type('MenuItem', [
            'description' => 'Navigation menu item',
            'fields' => [
                'id' => ['type' => 'ID'],
                'title' => ['type' => 'String'],
                'url' => ['type' => 'String'],
                'target' => ['type' => 'String'],
                'description' => ['type' => 'String'],
                'classes' => ['type' => 'String'],
                'parent' => ['type' => 'String'],
                'order' => ['type' => 'Int']
            ]
        ]);
    }
    
    public function admin_notices() {
        $screen = get_current_screen();
        
        if ($screen->id \!== 'dashboard') {
            return;
        }
        
        $webhook_url = get_option('headless_webhook_url');
        
        if (empty($webhook_url)) {
            ?>
            <div class="notice notice-warning is-dismissible">
                <p>
                    <strong>Headless Static:</strong> 
                    Webhook URL not configured. 
                    <a href="<?php echo admin_url('options-general.php?page=headless-static-settings'); ?>">Configure now</a>
                </p>
            </div>
            <?php
        }
    }
    
    public function activate() {
        // Set default options
        add_option('headless_build_version', '1.0.0');
        add_option('headless_last_build', current_time('mysql'));
        
        // Flush rewrite rules
        flush_rewrite_rules();
    }
    
    public function deactivate() {
        // Clean up if needed
        flush_rewrite_rules();
    }
}

// Initialize the plugin
new HeadlessStaticEnhancements();

/**
 * GitHub Actions webhook trigger
 */
class GitHubActionsWebhook {
    
    public function __construct() {
        add_action('init', [$this, 'init']);
    }
    
    public function init() {
        add_action('headless_static_send_webhook', [$this, 'send_github_webhook']);
    }
    
    public function send_github_webhook($payload) {
        $github_token = get_option('headless_github_token');
        $github_repo = get_option('headless_github_repo');
        $github_workflow = get_option('headless_github_workflow', 'build-deploy.yml');
        
        if (empty($github_token) || empty($github_repo)) {
            error_log('GitHub configuration incomplete for webhook');
            return;
        }
        
        // GitHub API endpoint for triggering workflow
        $github_url = "https://api.github.com/repos/{$github_repo}/actions/workflows/{$github_workflow}/dispatches";
        
        $github_payload = [
            'ref' => 'main',
            'inputs' => [
                'wordpress_event' => $payload['event'],
                'post_id' => $payload['post_id'] ?? '',
                'timestamp' => $payload['timestamp']
            ]
        ];
        
        $response = wp_remote_post($github_url, [
            'method' => 'POST',
            'timeout' => 30,
            'headers' => [
                'Authorization' => 'token ' . $github_token,
                'Accept' => 'application/vnd.github.v3+json',
                'Content-Type' => 'application/json',
                'User-Agent' => 'WordPress-Headless-Static/1.0'
            ],
            'body' => json_encode($github_payload)
        ]);
        
        if (is_wp_error($response)) {
            error_log('GitHub webhook error: ' . $response->get_error_message());
        } else {
            error_log('GitHub workflow triggered successfully for: ' . $github_repo);
        }
    }
}

// Initialize GitHub webhook handler
new GitHubActionsWebhook();
EOF < /dev/null