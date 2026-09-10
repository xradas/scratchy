import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Eye Sore — Isometric Arena',
  description: 'An original neon isometric arena shooter.',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
