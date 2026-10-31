import manifest from "./asset-manifest.json" with { type: "json" };

const imageCache = new Map();
const audioCache = new Map();
const timeout = (promise, ms, label) => new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(new Error(`Asset timeout: ${label}`)), ms);
  Promise.resolve(promise).then(value => { clearTimeout(timer); resolve(value); }, error => { clearTimeout(timer); reject(error); });
});

async function fetchAsset(asset) {
  let lastError;
  // Use the immutable jsDelivr URL first. If it is unavailable (or the player is offline),
  // fall back immediately to the same-origin copy that the Service Worker precaches.
  for (const source of [asset.cdn, asset.src].filter(Boolean)) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), source === asset.cdn ? (asset.group === "scene" ? 4200 : 2200) : 10000);
    try {
      const response = await fetch(source, {
        cache: "force-cache",
        credentials: source === asset.cdn ? "omit" : "same-origin",
        signal: controller.signal
      });
      if (!response.ok) throw new Error(`Asset request failed (${response.status}): ${source}`);
      const blob = await response.blob();
      if (!blob.type.startsWith("image/")) throw new Error(`Unexpected image MIME type: ${blob.type}`);
      return blob;
    } catch (error) { lastError = error; }
    finally { clearTimeout(timer); }
  }
  throw lastError || new Error(`No asset source available: ${asset.src}`);
}

async function loadVector(asset) {
  const blob = await fetchAsset(asset);
  const image = new Image();
  const objectUrl = URL.createObjectURL(blob);
  try {
    image.src = objectUrl;
    if (image.decode) await timeout(image.decode(), 10000, asset.src);
    else await timeout(new Promise((resolve, reject) => { image.onload = resolve; image.onerror = reject; }), 10000, asset.src);
    return image;
  } finally { URL.revokeObjectURL(objectUrl); }
}

export async function preloadGameAssets(onProgress = () => {}) {
  const all = [...manifest.worlds, ...manifest.cars, ...(manifest.scenes || [])];
  let loaded = 0;
  const failures = [];
  let cursor = 0;
  const worker = async () => {
    while (cursor < all.length) {
      const asset = all[cursor++];
      try { imageCache.set(asset.id, await loadVector(asset)); }
      catch (error) { failures.push({ asset: asset.src, error: error.message }); }
      loaded++;
      onProgress({ loaded, total: all.length, percent: Math.round(loaded / all.length * 100), name: asset.name });
    }
  };
  await Promise.all(Array.from({ length: 4 }, worker));
  window.MshinAssets = {
    version: manifest.version,
    worlds: manifest.worlds.map(item => imageCache.get(item.id) || null),
    cars: Object.fromEntries(manifest.cars.map(item => [item.id, imageCache.get(item.id) || null])),
    scenes: Object.fromEntries((manifest.scenes || []).map(item => [item.id, imageCache.get(item.id) || null])),
    failures,
    ready: true
  };
  return window.MshinAssets;
}
