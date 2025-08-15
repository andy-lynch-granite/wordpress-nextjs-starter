/** @type {import('next').NextConfig} */
const nextConfig = {
  // Enable static export for zero runtime dependencies
  output: 'export',
  
  // Disable image optimization for static export (required)
  images: {
    unoptimized: true,
  },
  
  // Add trailing slash for consistent routing
  trailingSlash: true,
  
  // Environment variables for build-time access
  env: {
    WORDPRESS_GRAPHQL_URL: process.env.WORDPRESS_GRAPHQL_URL || 'http://localhost:8081/index.php?graphql',
    NEXT_PUBLIC_SITE_URL: process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000',
  },
  
  // Remove rewrites - not compatible with static export
};

module.exports = nextConfig;