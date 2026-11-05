/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: {
    ignoreBuildErrors: true,
  },
  async headers() {
    return [
      {
        source: '/:path*.apk',
        headers: [
          { key: 'Content-Type', value: 'application/vnd.android.package-archive' },
          { key: 'Content-Disposition', value: 'attachment' },
          { key: 'Accept-Ranges', value: 'bytes' },
          { key: 'Cache-Control', value: 'public, max-age=3600, s-maxage=31536000, stale-while-revalidate' },
        ],
      },
    ];
  },
  async rewrites() {
    return [
      { source: '/dashboard', destination: '/' },
      { source: '/students', destination: '/' },
      { source: '/fees', destination: '/' },
      { source: '/attendance', destination: '/' },
      { source: '/results', destination: '/' },
      { source: '/idcards', destination: '/' },
      { source: '/admitcards', destination: '/' },
      { source: '/timetable', destination: '/' },
      { source: '/classes', destination: '/' },
      { source: '/teachers', destination: '/' },
      { source: '/reports', destination: '/' },
      { source: '/documents', destination: '/' },
      { source: '/import-export', destination: '/' },
      { source: '/scanner', destination: '/' },
      { source: '/qrscanner', destination: '/' },
      { source: '/notices', destination: '/' },
      { source: '/profile', destination: '/' },
      { source: '/settings', destination: '/' },
      { source: '/settings/:path*', destination: '/' },
      { source: '/subscription', destination: '/' },
      { source: '/signin', destination: '/' },
      { source: '/signup', destination: '/' },
      { source: '/forgot-password', destination: '/' },
      { source: '/setup', destination: '/' },
      { source: '/users', destination: '/' },
      { source: '/complaints', destination: '/' },
      { source: '/access-denied', destination: '/' },
      { source: '/teacher-access', destination: '/' },
    ];
  },
};

export default nextConfig;
