export async function GET() {
  return new Response('google-site-verification: google4149f6e4a3de7cbd.html', {
    status: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
    },
  });
}
