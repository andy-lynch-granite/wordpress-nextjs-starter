<?php
/**
 * Footer template for headless WordPress theme
 */

// Prevent direct access
if (\!defined('ABSPATH')) {
    exit;
}
?>

<footer style="margin-top: 40px; padding: 20px; background: #333; color: white; text-align: center;">
    <p>&copy; <?php echo date('Y'); ?> <?php bloginfo('name'); ?> - Powered by Headless WordPress</p>
</footer>

<?php wp_footer(); ?>
</body>
</html>
EOF < /dev/null