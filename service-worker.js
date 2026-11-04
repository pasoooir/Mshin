const CACHE_NAME = "mshin-arcade-v69";
const APP_SHELL = [
  "./", "./index.html", "./city.html", "./city-neighborhood-preview.html", "./assets/city/models/manifest.json", "./assets/city/models/house.gltf", "./assets/city/models/apartment.gltf", "./assets/city/models/shop.gltf", "./src/city/city-view.js", "./src/city/city-three-renderer.js", "./src/city/city-camera-controller.js", "./src/city/city-camera-projection.js", "./src/city/city-construction-renderer.js", "./src/city/city-surface-texture.js", "./src/city/city-view.css", "./src/city/city-mobile-layout.css", "./src/city/city-zoning.js", "./src/city/city-services.js", "./src/city/city-traffic.js", "./src/city/city-population.js", "./src/city/city-economy.js","./src/city/city-employment.js", "./src/city/city-save.js", "./manifest.webmanifest", "./icons/mshin.svg",
  "./src/web-game.js", "./src/multitouch-input.js", "./src/vehicle-pbr.js", "./src/vehicle-showroom-3d.js", "./src/race-renderer-3d.js", "./src/aerial-environment.js", "./src/tire-physics.js", "./src/vehicle-dynamics.js", "./src/pickup-collection.js", "./src/rigid-body-physics.js", "./src/traffic-ai.js", "./src/vehicle-destruction.js", "./src/vehicle-damage-visuals.js", "./src/audio.js", "./src/collision-physics.js", "./src/boot.js", "./src/asset-loader.js", "./src/asset-manifest.json",
  "./assets/vector/world-01.svg",
  "./assets/vector/world-02.svg",
  "./assets/vector/world-03.svg",
  "./assets/vector/world-04.svg",
  "./assets/vector/world-05.svg",
  "./assets/vector/world-06.svg",
  "./assets/vector/world-07.svg",
  "./assets/vector/world-08.svg",
  "./assets/vector/world-09.svg",
  "./assets/vector/world-10.svg",
  "./assets/vector/car-rally.svg", "./assets/vector/car-comet.svg", "./assets/vector/car-lynx.svg",
  "./assets/vector/car-thunder.svg", "./assets/vector/car-raptor.svg",
  "./cdn/assets/scenes/scene-01.jpg",
  "./cdn/assets/scenes/scene-02.jpg",
  "./cdn/assets/scenes/scene-03.jpg",
  "./cdn/assets/scenes/scene-04.jpg",
  "./cdn/assets/scenes/scene-05.jpg",
  "./cdn/assets/scenes/scene-06.jpg",
  "./cdn/assets/scenes/scene-07.jpg",
  "./cdn/assets/scenes/scene-08.jpg",
  "./cdn/assets/scenes/scene-09.jpg",
  "./cdn/assets/scenes/scene-10.jpg",
  "./cdn/assets/icons/accelerate.svg",
  "./cdn/assets/icons/brake.svg",
  "./cdn/assets/icons/nitro.svg",
  "./cdn/assets/audio/engine0.wav",
  "./cdn/assets/audio/engine1.wav",
  "./cdn/assets/audio/engine2.wav",
  "./cdn/assets/audio/engine3.wav",
  "./cdn/assets/audio/engine4.wav",
  "./cdn/assets/audio/engine5.wav",
  "./cdn/assets/audio/brakeSqueal.mp3",
  "./cdn/assets/audio/gearDown.mp3",
  "./cdn/assets/audio/musicMenu.ogg",
  "./cdn/assets/audio/musicRace.ogg"
];

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith("mshin-arcade-") && key !== CACHE_NAME).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});

self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET") return;
  const requestUrl = new URL(request.url);
  if (requestUrl.origin !== self.location.origin) return;
  event.respondWith(caches.match(request, { ignoreSearch: true }).then(cached => {
    if (cached) return cached;
    return fetch(request).then(response => {
      if (response.ok && response.type === "basic") {
        const copy = response.clone();
        event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.put(request, copy)));
      }
      return response;
    }).catch(() => {
      if (request.mode === "navigate") return caches.match("./index.html");
      return new Response("Offline: this game resource is not cached yet.", { status: 503, headers: { "Content-Type": "text/plain; charset=utf-8" } });
    });
  }));
});
