import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Headless WordPress + Next.js',
  description: 'A modern headless WordPress starter kit with Next.js',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}