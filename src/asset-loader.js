import manifest from "./asset-manifest.json" with { type: "json" };

const imageCache = new Map();
const timeout = (promise, ms, label) => Promise.race([promise, new Promise((_, reject) => setTimeout(() => reject(new Error(`Asset timeout: ${label}`)), ms))]);

async function loadVector(asset) {
  const response = await timeout(fetch(asset.src, { cache: "force-cache", credentials: "same-origin" }), 12000, asset.src);
  if (!response.ok) throw new Error(`Asset request failed (${response.status}): ${asset.src}`);
  const blob = await response.blob();
  if (!blob.type.includes("svg")) throw new Error(`Unexpected vector MIME type: ${blob.type}`);
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
  const all = [...manifest.worlds, ...manifest.cars];
  let loaded = 0;
  const failures = [];
  // Bounded concurrency avoids a burst of simultaneous decodes on mobile devices.
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
  await Promise.all(Array.from({ length: 3 }, worker));
  // Art is non-blocking: if a CDN/cache miss or unsupported SVG decoder occurs, Canvas fallback art remains available.
  window.MshinAssets = {
    version: manifest.version,
    worlds: manifest.worlds.map(item => imageCache.get(item.id) || null),
    cars: Object.fromEntries(manifest.cars.map(item => [item.id, imageCache.get(item.id) || null])),
    failures,
    ready: true
  };
  return window.MshinAssets;
}
