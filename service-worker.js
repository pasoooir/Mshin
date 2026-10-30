const CACHE_NAME = "mshin-arcade-v4";
const APP_SHELL = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icons/mshin.svg",
  "./src/web-game.js",
  "./src/audio.js"
];

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith("mshin-arcade-") && key !== CACHE_NAME).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});

self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET" || new URL(request.url).origin !== self.location.origin) return;
  event.respondWith(caches.match(request, { ignoreSearch: true }).then(cached => {
    if (cached) return cached;
    return fetch(request).then(response => {
      if (response.ok && response.type === "basic") {
        const copy = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(request, copy));
      }
      return response;
    }).catch(() => {
      if (request.mode === "navigate") return caches.match("./index.html");
      return new Response("Offline: this game resource is not cached yet.", { status: 503, headers: { "Content-Type": "text/plain; charset=utf-8" } });
    });
  }));
});
