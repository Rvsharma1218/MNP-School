/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: {
    ignoreBuildErrors: true,
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
      { source: '/scanner', destination: '/' },
      { source: '/qrscanner', destination: '/' },
      { source: '/notices', destination: '/' },
      { source: '/profile', destination: '/' },
      { source: '/settings', destination: '/' },
      { source: '/subscription', destination: '/' },
      { source: '/signin', destination: '/' },
      { source: '/signup', destination: '/' },
      { source: '/forgot-password', destination: '/' },
      { source: '/setup', destination: '/' },
      { source: '/users', destination: '/' },
    ];
  },
};

export default nextConfig;
