import manifest from "./asset-manifest.json" with { type: "json" };

const imageCache = new Map();
const audioCache = new Map();
const timeout = (promise, ms, label) => new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error(`Asset timeout: ${label}`)), ms);
  Promise.resolve(promise).then(value => { clearTimeout(timer); resolve(value); }, error => { clearTimeout(timer); reject(error); });
});

async function fetchImage(asset) {
  let lastError;
  for (const source of [asset.cdn, asset.src].filter(Boolean)) {
    const controller = new AbortController();
    const remote = new URL(source, location.href).origin !== location.origin;
    const limit = remote ? (asset.group === "scene" ? 1800 : 1200) : 3000;
    const timer = setTimeout(() => controller.abort(), limit);
    try {
      const response = await timeout(fetch(source, { cache: "force-cache", credentials: "omit", signal: controller.signal }), limit, source);
      if (!response.ok) throw new Error(`Asset request failed (${response.status}): ${source}`);
      const blob = await timeout(response.blob(), limit, source);
      if (!blob.type.startsWith("image/")) throw new Error(`Unexpected image MIME type: ${blob.type}`);
      return blob;
    } catch (error) { lastError = error; }
    finally { clearTimeout(timer); }
  }
  throw lastError || new Error(`No image source available: ${asset.src}`);
}

async function loadVector(asset) {
  // Large photographic JPEGs are loaded directly. Fetch->Blob->objectURL->decode
  // creates unnecessary memory pressure on mobile and can stall WebKit/Chromium
  // emulation when several 0.2–0.7 MB scenes decode concurrently.
  if (asset.group === "scene" || /\\.(jpe?g|png|webp)(?:$|\\?)/i.test(asset.src || "")) {
    const image = new Image();
    await timeout(new Promise((resolve, reject) => {
      image.onload = () => resolve();
      image.onerror = () => reject(new Error("Image decode failed: " + asset.src));
      image.src = asset.src;
    }), 12000, asset.src);
    return image;
  }
  const blob = await fetchImage(asset);
  const image = new Image();
  const objectUrl = URL.createObjectURL(blob);
  try {
    image.src = objectUrl;
    if (image.decode) await timeout(image.decode(), 7000, asset.src);
    else await timeout(new Promise((resolve, reject) => { image.onload = resolve; image.onerror = reject; }), 10000, asset.src);
    return image;
  } finally { URL.revokeObjectURL(objectUrl); }
}

async function loadAudio(asset) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 5000);
  try {
    const response = await timeout(fetch(asset.src, { cache: "force-cache", mode: "cors", credentials: "omit", signal: controller.signal }), 7000, asset.src);
    if (!response.ok) throw new Error(`Audio request failed (${response.status}): ${asset.src}`);
    const type = response.headers.get("content-type") || "";
    if (!type.includes("audio/") && !/\.(mp3|ogg)(?:$|\?)/i.test(asset.src)) throw new Error(`Unexpected audio MIME type: ${type}`);
    const bytes = await timeout(response.arrayBuffer(), 7000, asset.src);
    // Cache writes are opportunistic only. They must never hold the boot barrier.
    if ("caches" in window) {
      caches.open("mshin-audio-assets-v1")
        .then(cache => cache.put(asset.src, new Response(bytes.slice(0), { headers: { "Content-Type": type || asset.type || "application/octet-stream", "Cache-Control": "public, max-age=31536000" } })))
        .catch(() => {});
    }
    return bytes;
  } finally { clearTimeout(timer); }
}

export async function preloadGameAssets(onProgress = () => {}) {
  const all = [...manifest.worlds, ...manifest.cars, ...(manifest.scenes || []), ...(manifest.icons || []), ...(manifest.sounds || [])];
  let loaded = 0, cursor = 0;
  const failures = [];
  const worker = async () => {
    while (cursor < all.length) {
      const asset = all[cursor++];
      try {
        const task = asset.group === "audio" ? loadAudio(asset) : loadVector(asset);
        const value = await timeout(task, asset.group === "scene" ? 15000 : 12000, asset.name || asset.src);
        if (asset.group === "audio") audioCache.set(asset.id, value);
        else imageCache.set(asset.id, value);
      } catch (error) {
        failures.push({ asset: asset.src || asset.cdn, error: error.message });
      }
      loaded++;
      onProgress({ loaded, total: all.length, percent: Math.round(loaded / all.length * 100), name: asset.name });
    }
  };
  const mobile = matchMedia("(pointer: coarse)").matches || Math.min(innerWidth, innerHeight) < 700;
  await Promise.all(Array.from({ length: mobile ? 3 : 6 }, worker));
  window.MshinAssets = {
    version: manifest.version,
    worlds: manifest.worlds.map(item => imageCache.get(item.id) || null),
    cars: Object.fromEntries(manifest.cars.map(item => [item.id, imageCache.get(item.id) || null])),
    scenes: Object.fromEntries((manifest.scenes || []).map(item => [item.id, imageCache.get(item.id) || null])),
    icons: Object.fromEntries((manifest.icons || []).map(item => [item.id, imageCache.get(item.id) || null])),
    audioData: Object.fromEntries((manifest.sounds || []).map(item => [item.id, audioCache.get(item.id) || null])),
    failures,
    ready: true
  };
  return window.MshinAssets;
}
