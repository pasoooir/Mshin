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
    const timer = setTimeout(() => controller.abort(), remote ? (asset.group === "scene" ? 1800 : 1200) : 3000);
    try {
      const response = await fetch(source, { cache: "force-cache", credentials: "omit", signal: controller.signal });
      if (!response.ok) throw new Error(`Asset request failed (${response.status}): ${source}`);
      const blob = await response.blob();
      if (!blob.type.startsWith("image/")) throw new Error(`Unexpected image MIME type: ${blob.type}`);
      return blob;
    } catch (error) { lastError = error; }
    finally { clearTimeout(timer); }
  }
  throw lastError || new Error(`No image source available: ${asset.src}`);
}

async function loadVector(asset) {
  const blob = await fetchImage(asset);
  const image = new Image();
  const objectUrl = URL.createObjectURL(blob);
  try {
    image.src = objectUrl;
    if (image.decode) await timeout(image.decode(), 10000, asset.src);
    else await timeout(new Promise((resolve, reject) => { image.onload = resolve; image.onerror = reject; }), 10000, asset.src);
    return image;
  } finally { URL.revokeObjectURL(objectUrl); }
}

async function loadAudio(asset) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 5000);
  try {
    const response = await timeout(fetch(asset.src, { cache: "force-cache", mode: "cors", credentials: "omit", signal: controller.signal }), 5000, asset.src);
    if (!response.ok) throw new Error(`Audio request failed (${response.status}): ${asset.src}`);
    const type = response.headers.get("content-type") || "";
    if (!type.includes("audio/") && !asset.src.endsWith(".mp3")) throw new Error(`Unexpected audio MIME type: ${type}`);
    return await timeout(response.arrayBuffer(), 5000, asset.src);
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
        if (asset.group === "audio") audioCache.set(asset.id, await loadAudio(asset));
        else imageCache.set(asset.id, await loadVector(asset));
      } catch (error) { failures.push({ asset: asset.src || asset.cdn, error: error.message }); }
      loaded++;
      onProgress({ loaded, total: all.length, percent: Math.round(loaded / all.length * 100), name: asset.name });
    }
  };
  await Promise.all(Array.from({ length: 6 }, worker));
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
