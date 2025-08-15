<?php
/**
 * Header template for headless WordPress theme
 */

// Prevent direct access
if (\!defined('ABSPATH')) {
    exit;
}
?>
<\!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
    <meta charset="<?php bloginfo('charset'); ?>">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?php bloginfo('name'); ?> - Headless WordPress</title>
    <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
<?php wp_body_open(); ?>
EOF < /dev/null