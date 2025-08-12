/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  images: {
    domains: ['localhost'],
    remotePatterns: [
      {
        protocol: 'http',
        hostname: 'localhost',
        port: '8081',
        pathname: '/wp-content/uploads/**',
      },
    ],
  },
  async rewrites() {
    return [
      {
        source: '/wp-content/:path*',
        destination: `${process.env.NEXT_PUBLIC_WORDPRESS_URL}/wp-content/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;