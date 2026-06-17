// KnapScout service worker.
// Strategy: network-first for the app shell (so new deploys load when online,
// cached copy when offline); cache-first for pinned/immutable assets and map
// tiles (so the field works with zero signal). Bump CACHE_NAME on each deploy
// you want to force-evict — the version is just an arbitrary string.
const CACHE_NAME = 'knapscout-v1';        // <-- your ask #1 (single versioned constant)

// Same-origin shell files, precached at install. Kept to known-good local files
// only: addAll() is atomic, so one 404 (e.g. a cross-origin CDN hiccup) would
// fail the whole install. CDN assets and tiles are cached at runtime instead.
const SHELL = [
  './',
  './index.html',
  './manifest.json',
  './icons/knapscout-icon-180.png',
  './icons/knapscout-icon-192.png',
  './icons/knapscout-icon-512.png',
  './icons/knapscout-icon-1024.png',
  './art/knapscout-gate-kirk.png',
];

// Install: precache the shell, then take over without waiting for old tabs.
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL))
      .then(() => self.skipWaiting())
  );
});

// Activate: delete any cache whose name isn't the current CACHE_NAME, so a
// version bump evicts stale code cleanly. Then claim open clients.   <-- ask #2
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))
    )).then(() => self.clients.claim())
  );
});

// Fetch: network-first for navigations (HTML shell), cache-first for everything
// else (icons, art, fonts, Leaflet, tiles).                          <-- ask #3
self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const isNavigation =
    req.mode === 'navigate' ||
    (req.headers.get('accept') || '').includes('text/html');

  if (isNavigation) {
    // Network-first with a 4s timeout so flaky signal doesn't hang the app;
    // fall back to the cached shell (or index.html) when offline/slow.
    event.respondWith(
      Promise.race([
        fetch(req).then((res) => {
          const copy = res.clone();
          caches.open(CACHE_NAME).then((c) => c.put(req, copy));
          return res;
        }),
        new Promise((_, reject) => setTimeout(reject, 4000)),
      ]).catch(() =>
        caches.match(req).then((hit) => hit || caches.match('./index.html'))
      )
    );
    return;
  }

  // Cache-first for static/immutable assets and tiles.
  event.respondWith(
    caches.match(req).then((hit) => {
      if (hit) return hit;
      return fetch(req).then((res) => {
        // Cache successful basic/cors responses (skip opaque error tiles).
        if (res && (res.ok || res.type === 'opaque')) {
          const copy = res.clone();
          caches.open(CACHE_NAME).then((c) => c.put(req, copy));
        }
        return res;
      });
    })
  );
});
