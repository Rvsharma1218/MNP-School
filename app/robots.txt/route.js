export async function GET() {
  const robots = `User-agent: *
Allow: /

Sitemap: https://mnpschool.in/sitemap.xml
Sitemap: https://www.mnpschool.in/sitemap.xml
`;

  return new Response(robots, {
    status: 200,
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=3600, s-maxage=86400',
    },
  });
}
