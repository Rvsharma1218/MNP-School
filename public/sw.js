// Service Worker for Offline Cache Memory & Push Notifications
const CACHE_NAME = 'mnp-school-cache-v2';
const STATIC_ASSETS = [
  '/',
  '/favicon.ico',
  '/logo.png',
  '/app_icon.png',
  '/school_campus_banner.jpg',
  '/campus_building.jpg',
  '/campus_playground.jpg',
  '/school_entrance.jpg',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS).catch(() => {});
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((key) => {
          if (key !== CACHE_NAME) {
            return caches.delete(key);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Cache-First / Stale-While-Revalidate for Static Assets & Images
self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);

  // Skip non-GET and chrome-extension / firestore / firebase requests
  if (request.method !== 'GET') return;
  if (url.origin !== self.location.origin) return;
  if (url.pathname.endsWith('.apk')) return; // Do not cache large APK files

  // Cache static images, fonts, and scripts
  if (
    url.pathname.startsWith('/_next/static/') ||
    url.pathname.match(/\.(png|jpg|jpeg|svg|webp|ico|woff|woff2|ttf|css|js)$/)
  ) {
    event.respondWith(
      caches.open(CACHE_NAME).then(async (cache) => {
        const cachedResponse = await cache.match(request);
        const fetchPromise = fetch(request).then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            cache.put(request, networkResponse.clone());
          }
          return networkResponse;
        }).catch(() => cachedResponse);

        return cachedResponse || fetchPromise;
      })
    );
  }
});

// Handle Background Push Event
self.addEventListener('push', (event) => {
  let data = { title: '📢 New School Notice', body: 'A new circular has been published by the Principal.' };
  if (event.data) {
    try {
      data = event.data.json();
    } catch (_) {
      data.body = event.data.text();
    }
  }

  const title = data.title || '📢 New School Notice';
  const options = {
    body: data.body || 'Click to view notice on school website.',
    icon: '/favicon.ico',
    badge: '/favicon.ico',
    tag: data.tag || 'notice-alert',
    data: {
      url: data.url || '/notices'
    },
    vibrate: [200, 100, 200],
    requireInteraction: true
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

// Handle Notification Click
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = event.notification.data?.url || '/notices';

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
    })
  );
});
