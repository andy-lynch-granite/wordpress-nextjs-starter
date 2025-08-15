<?php
/**
 * Headless Static WordPress Theme Functions
 * Optimized for static site generation with GraphQL API
 */

// Prevent direct access
if (\!defined('ABSPATH')) {
    exit;
}

/**
 * Theme Setup
 */
function headless_static_setup() {
    // Add theme support for various features
    add_theme_support('post-thumbnails');
    add_theme_support('title-tag');
    add_theme_support('html5', array(
        'search-form',
        'comment-form',
        'comment-list',
        'gallery',
        'caption',
    ));
    
    // Disable theme editor
    if (\!defined('DISALLOW_FILE_EDIT')) {
        define('DISALLOW_FILE_EDIT', true);
    }
    
    // Remove unnecessary WordPress features for headless operation
    remove_action('wp_head', 'wp_generator');
    remove_action('wp_head', 'rsd_link');
    remove_action('wp_head', 'wlwmanifest_link');
    remove_action('wp_head', 'wp_shortlink_wp_head');
    remove_action('wp_head', 'adjacent_posts_rel_link_wp_head');
    
    // Clean up admin for headless operation
    add_action('admin_init', 'headless_static_admin_cleanup');
}
add_action('after_setup_theme', 'headless_static_setup');

/**
 * Clean up admin interface for headless operation
 */
function headless_static_admin_cleanup() {
    // Remove unnecessary admin menu items
    remove_menu_page('themes.php');
    remove_submenu_page('themes.php', 'themes.php');
    remove_submenu_page('themes.php', 'widgets.php');
    remove_submenu_page('themes.php', 'customize.php');
    
    // Remove theme customizer
    global $wp_customize;
    if (isset($wp_customize)) {
        $wp_customize = null;
    }
}

/**
 * Enqueue scripts and styles (minimal for headless)
 */
function headless_static_scripts() {
    // Only load styles in admin or when previewing
    if (is_admin() || is_preview()) {
        wp_enqueue_style('headless-static-style', get_stylesheet_uri());
    }
}
add_action('wp_enqueue_scripts', 'headless_static_scripts');

/**
 * Disable unnecessary features for static generation
 */
function headless_static_disable_features() {
    // Disable feeds
    remove_action('wp_head', 'feed_links_extra', 3);
    remove_action('wp_head', 'feed_links', 2);
    
    // Disable emojis
    remove_action('wp_head', 'print_emoji_detection_script', 7);
    remove_action('wp_print_styles', 'print_emoji_styles');
    remove_action('admin_print_scripts', 'print_emoji_detection_script');
    remove_action('admin_print_styles', 'print_emoji_styles');
    remove_filter('the_content_feed', 'wp_staticize_emoji');
    remove_filter('comment_text_rss', 'wp_staticize_emoji');
    remove_filter('wp_mail', 'wp_staticize_emoji_for_email');
    
    // Disable embeds
    remove_action('wp_head', 'wp_oembed_add_discovery_links');
    remove_action('wp_head', 'wp_oembed_add_host_js');
}
add_action('init', 'headless_static_disable_features');

/**
 * Custom GraphQL enhancements for static generation
 */
function headless_static_graphql_enhancements() {
    // Add build metadata to GraphQL
    add_action('graphql_register_types', function() {
        register_graphql_field('RootQuery', 'buildMetadata', [
            'type' => 'String',
            'description' => 'Build metadata for static generation',
            'resolve' => function() {
                return json_encode([
                    'lastBuild' => get_option('headless_last_build', ''),
                    'version' => get_option('headless_build_version', '1.0.0'),
                    'contentHash' => wp_hash(serialize(get_posts(['numberposts' => -1]))),
                    'timestamp' => current_time('timestamp')
                ]);
            }
        ]);
    });
    
    // Add navigation menu to GraphQL
    add_action('graphql_register_types', function() {
        register_graphql_field('RootQuery', 'navigationMenus', [
            'type' => ['list_of' => 'String'],
            'description' => 'Available navigation menus',
            'resolve' => function() {
                $menus = wp_get_nav_menus();
                return array_map(function($menu) {
                    return $menu->name;
                }, $menus);
            }
        ]);
    });
}
add_action('init', 'headless_static_graphql_enhancements');

/**
 * Webhook system for content-triggered builds
 */
class HeadlessStaticWebhooks {
    private $webhook_url;
    private $webhook_secret;
    
    public function __construct() {
        $this->webhook_url = get_option('headless_webhook_url', '');
        $this->webhook_secret = get_option('headless_webhook_secret', '');
        
        $this->init_hooks();
    }
    
    private function init_hooks() {
        // Post/page save hooks
        add_action('save_post', [$this, 'trigger_build_webhook'], 10, 3);
        add_action('delete_post', [$this, 'trigger_build_webhook']);
        
        // Menu update hooks
        add_action('wp_update_nav_menu', [$this, 'trigger_build_webhook']);
        
        // Category/tag hooks
        add_action('created_term', [$this, 'trigger_build_webhook']);
        add_action('edited_term', [$this, 'trigger_build_webhook']);
        add_action('delete_term', [$this, 'trigger_build_webhook']);
        
        // Theme/plugin activation (if allowed)
        add_action('after_switch_theme', [$this, 'trigger_build_webhook']);
        
        // Add admin menu for webhook configuration
        add_action('admin_menu', [$this, 'add_admin_menu']);
        add_action('admin_init', [$this, 'register_settings']);
    }
    
    public function trigger_build_webhook($post_id = null, $post = null, $update = null) {
        // Skip auto-saves and revisions
        if (wp_is_post_autosave($post_id) || wp_is_post_revision($post_id)) {
            return;
        }
        
        // Skip if no webhook URL configured
        if (empty($this->webhook_url)) {
            return;
        }
        
        // Prepare webhook payload
        $payload = [
            'event' => current_action(),
            'timestamp' => current_time('timestamp'),
            'post_id' => $post_id,
            'site_url' => home_url(),
            'signature' => $this->generate_signature()
        ];
        
        // Send webhook asynchronously
        wp_schedule_single_event(time(), 'headless_static_send_webhook', [$payload]);
    }
    
    private function generate_signature() {
        if (empty($this->webhook_secret)) {
            return '';
        }
        
        $data = $this->webhook_url . current_time('timestamp');
        return hash_hmac('sha256', $data, $this->webhook_secret);
    }
    
    public function send_webhook($payload) {
        $response = wp_remote_post($this->webhook_url, [
            'method' => 'POST',
            'timeout' => 30,
            'headers' => [
                'Content-Type' => 'application/json',
                'X-Webhook-Signature' => $payload['signature'],
                'User-Agent' => 'WordPress-Headless-Static/1.0'
            ],
            'body' => json_encode($payload)
        ]);
        
        // Log webhook result
        if (is_wp_error($response)) {
            error_log('Headless webhook error: ' . $response->get_error_message());
        } else {
            error_log('Headless webhook sent successfully to: ' . $this->webhook_url);
        }
    }
    
    public function add_admin_menu() {
        add_options_page(
            'Headless Static Settings',
            'Headless Static',
            'manage_options',
            'headless-static-settings',
            [$this, 'admin_page']
        );
    }
    
    public function register_settings() {
        register_setting('headless_static_settings', 'headless_webhook_url');
        register_setting('headless_static_settings', 'headless_webhook_secret');
        register_setting('headless_static_settings', 'headless_github_token');
        register_setting('headless_static_settings', 'headless_github_repo');
        register_setting('headless_static_settings', 'headless_github_workflow');
    }
    
    public function admin_page() {
        ?>
        <div class="wrap">
            <h1>Headless Static Settings</h1>
            <form method="post" action="options.php">
                <?php
                settings_fields('headless_static_settings');
                do_settings_sections('headless_static_settings');
                ?>
                <table class="form-table">
                    <tr>
                        <th scope="row">Webhook URL</th>
                        <td>
                            <input type="url" name="headless_webhook_url" value="<?php echo esc_attr(get_option('headless_webhook_url')); ?>" class="regular-text" />
                            <p class="description">GitHub Actions webhook URL for triggering builds</p>
                        </td>
                    </tr>
                    <tr>
                        <th scope="row">Webhook Secret</th>
                        <td>
                            <input type="password" name="headless_webhook_secret" value="<?php echo esc_attr(get_option('headless_webhook_secret')); ?>" class="regular-text" />
                            <p class="description">Secret key for webhook authentication</p>
                        </td>
                    </tr>
                    <tr>
                        <th scope="row">GitHub Token</th>
                        <td>
                            <input type="password" name="headless_github_token" value="<?php echo esc_attr(get_option('headless_github_token')); ?>" class="regular-text" />
                            <p class="description">GitHub Personal Access Token for repository access</p>
                        </td>
                    </tr>
                    <tr>
                        <th scope="row">GitHub Repository</th>
                        <td>
                            <input type="text" name="headless_github_repo" value="<?php echo esc_attr(get_option('headless_github_repo')); ?>" class="regular-text" />
                            <p class="description">GitHub repository (e.g., username/repository-name)</p>
                        </td>
                    </tr>
                    <tr>
                        <th scope="row">GitHub Workflow</th>
                        <td>
                            <input type="text" name="headless_github_workflow" value="<?php echo esc_attr(get_option('headless_github_workflow', 'build-deploy.yml')); ?>" class="regular-text" />
                            <p class="description">GitHub Actions workflow filename</p>
                        </td>
                    </tr>
                </table>
                <?php submit_button(); ?>
            </form>
            
            <h2>Test Webhook</h2>
            <p>
                <button type="button" id="test-webhook" class="button">Test Webhook</button>
                <span id="webhook-result"></span>
            </p>
            
            <script>
            document.getElementById('test-webhook').addEventListener('click', function() {
                const result = document.getElementById('webhook-result');
                result.textContent = 'Testing...';
                
                fetch(ajaxurl, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                    },
                    body: 'action=test_headless_webhook&_wpnonce=' + '<?php echo wp_create_nonce("test_webhook"); ?>'
                })
                .then(response => response.json())
                .then(data => {
                    result.textContent = data.success ? 'Webhook test successful\!' : 'Webhook test failed: ' + data.data;
                })
                .catch(error => {
                    result.textContent = 'Error: ' + error.message;
                });
            });
            </script>
        </div>
        <?php
    }
}

// Initialize webhook system
new HeadlessStaticWebhooks();

// AJAX handler for webhook testing
add_action('wp_ajax_test_headless_webhook', function() {
    check_ajax_referer('test_webhook');
    
    if (\!current_user_can('manage_options')) {
        wp_die('Unauthorized');
    }
    
    $webhook_url = get_option('headless_webhook_url');
    if (empty($webhook_url)) {
        wp_send_json_error('No webhook URL configured');
    }
    
    $payload = [
        'event' => 'test',
        'timestamp' => current_time('timestamp'),
        'site_url' => home_url(),
        'test' => true
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
        wp_send_json_error($response->get_error_message());
    } else {
        wp_send_json_success('Webhook sent successfully');
    }
});

// Schedule webhook sending
add_action('headless_static_send_webhook', function($payload) {
    $webhooks = new HeadlessStaticWebhooks();
    $webhooks->send_webhook($payload);
});

/**
 * Optimize permalink structure for static hosting
 */
function headless_static_optimize_permalinks() {
    // Ensure pretty permalinks are enabled
    if (get_option('permalink_structure') == '') {
        update_option('permalink_structure', '/%postname%/');
        flush_rewrite_rules();
    }
}
add_action('admin_init', 'headless_static_optimize_permalinks');

/**
 * Add custom fields for SEO and static generation
 */
function headless_static_add_meta_boxes() {
    add_meta_box(
        'headless_static_seo',
        'Headless Static SEO',
        'headless_static_seo_meta_box',
        ['post', 'page'],
        'normal',
        'high'
    );
}
add_action('add_meta_boxes', 'headless_static_add_meta_boxes');

function headless_static_seo_meta_box($post) {
    wp_nonce_field('headless_static_seo_nonce', 'headless_static_seo_nonce');
    
    $seo_title = get_post_meta($post->ID, '_headless_seo_title', true);
    $seo_description = get_post_meta($post->ID, '_headless_seo_description', true);
    $static_priority = get_post_meta($post->ID, '_headless_static_priority', true);
    
    ?>
    <table class="form-table">
        <tr>
            <th><label for="headless_seo_title">SEO Title</label></th>
            <td><input type="text" id="headless_seo_title" name="headless_seo_title" value="<?php echo esc_attr($seo_title); ?>" class="large-text" /></td>
        </tr>
        <tr>
            <th><label for="headless_seo_description">SEO Description</label></th>
            <td><textarea id="headless_seo_description" name="headless_seo_description" class="large-text" rows="3"><?php echo esc_textarea($seo_description); ?></textarea></td>
        </tr>
        <tr>
            <th><label for="headless_static_priority">Static Priority</label></th>
            <td>
                <select id="headless_static_priority" name="headless_static_priority">
                    <option value="high" <?php selected($static_priority, 'high'); ?>>High</option>
                    <option value="normal" <?php selected($static_priority, 'normal'); ?>>Normal</option>
                    <option value="low" <?php selected($static_priority, 'low'); ?>>Low</option>
                </select>
                <p class="description">Priority for static site generation</p>
            </td>
        </tr>
    </table>
    <?php
}

// Save custom meta fields
add_action('save_post', function($post_id) {
    if (\!isset($_POST['headless_static_seo_nonce']) || 
        \!wp_verify_nonce($_POST['headless_static_seo_nonce'], 'headless_static_seo_nonce')) {
        return;
    }
    
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
        return;
    }
    
    if (\!current_user_can('edit_post', $post_id)) {
        return;
    }
    
    update_post_meta($post_id, '_headless_seo_title', sanitize_text_field($_POST['headless_seo_title']));
    update_post_meta($post_id, '_headless_seo_description', sanitize_textarea_field($_POST['headless_seo_description']));
    update_post_meta($post_id, '_headless_static_priority', sanitize_text_field($_POST['headless_static_priority']));
});

/**
 * Add theme update timestamp on content changes
 */
function headless_static_update_build_timestamp() {
    update_option('headless_last_build', current_time('mysql'));
}
add_action('save_post', 'headless_static_update_build_timestamp');
add_action('delete_post', 'headless_static_update_build_timestamp');
add_action('wp_update_nav_menu', 'headless_static_update_build_timestamp');
EOF < /dev/null