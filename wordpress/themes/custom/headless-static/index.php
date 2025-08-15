<?php
/**
 * Headless Static WordPress Theme - Main Template
 * This theme is designed for headless operation and should not be used for frontend display
 */

// Prevent direct access
if (\!defined('ABSPATH')) {
    exit;
}

get_header(); ?>

<div class="headless-notice">
    <h1>Headless WordPress</h1>
    <p>This WordPress installation is running in headless mode. The frontend is served by a separate application.</p>
    <p>
        <strong>GraphQL Endpoint:</strong> 
        <a href="<?php echo home_url('/graphql'); ?>" target="_blank"><?php echo home_url('/graphql'); ?></a>
    </p>
    <p>
        <strong>Admin Dashboard:</strong> 
        <a href="<?php echo admin_url(); ?>">Access WordPress Admin</a>
    </p>
</div>

<?php get_footer(); ?>
EOF < /dev/null