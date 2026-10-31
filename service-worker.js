const CACHE_NAME = "mshin-arcade-v32";
const APP_SHELL = [
  "./", "./index.html", "./manifest.webmanifest", "./icons/mshin.svg",
  "./src/web-game.js", "./src/environment-renderer.js", "./src/tire-physics.js", "./src/rigid-body-physics.js", "./src/traffic-ai.js", "./src/vehicle-destruction.js", "./src/vehicle-damage-visuals.js", "./src/audio.js", "./src/collision-physics.js", "./src/boot.js", "./src/asset-loader.js", "./src/asset-manifest.json",
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
  "./assets/vector/car-thunder.svg", "./assets/vector/car-raptor.svg"
];
const REMOTE_AUDIO = [
  "https://sfxmint.com/dl/race-car-07.mp3",
  "https://sfxmint.com/dl/race-car-10.mp3",
  "https://cdn.jsdelivr.net/gh/Billioncodes001/agent-empire@17621885f718517d926729266ea3a00c317e6723/src/client/public/audio/engine-idle.wav",
  "https://cdn.jsdelivr.net/gh/Billioncodes001/agent-empire@17621885f718517d926729266ea3a00c317e6723/src/client/public/audio/engine-load.wav",
  "https://cdn.jsdelivr.net/gh/Billioncodes001/agent-empire@17621885f718517d926729266ea3a00c317e6723/src/client/public/audio/road-roll.wav",
  "https://cdn.jsdelivr.net/gh/Billioncodes001/agent-empire@17621885f718517d926729266ea3a00c317e6723/src/client/public/audio/engine-start.wav",
  "https://cdn.jsdelivr.net/gh/Billioncodes001/agent-empire@17621885f718517d926729266ea3a00c317e6723/src/client/public/audio/engine-stop.wav",
  "https://cdn.jsdelivr.net/gh/tininsteelian/tininsteelian.github.io@66c5f2415978cec667ab166daf22fb3889f1760b/games/3dfoggydrive/media/151624__qubodup__clank-car-crash-collision.ogg",
  "https://cdn.jsdelivr.net/gh/JerryMerweather/Checkpoint-Chaser@e280012e423cf2c800bd54e4fe361edaa9cae167/sky_blue_street_bpm165.ogg",
  "https://cdn.jsdelivr.net/gh/JerryMerweather/Checkpoint-Chaser@e280012e423cf2c800bd54e4fe361edaa9cae167/pure_raceway_bpm160.ogg"
];

self.addEventListener("install", event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll(APP_SHELL);
    await self.skipWaiting();
  })());
});

self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith("mshin-arcade-") && key !== CACHE_NAME).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});

self.addEventListener("fetch", event => {
  const request = event.request;
  const url = new URL(request.url);
  const localRequest = url.origin === self.location.origin;
  const approvedRemoteAudio = REMOTE_AUDIO.includes(request.url);
  if (request.method !== "GET" || (!localRequest && !approvedRemoteAudio)) return;
  event.respondWith(caches.match(request, { ignoreSearch: true }).then(cached => {
    if (cached) return cached;
    return fetch(request).then(response => {
      if (response.ok && (response.type === "basic" || approvedRemoteAudio && response.type === "cors")) {
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
