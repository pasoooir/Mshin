import { readFile, writeFile, mkdir, stat } from "node:fs/promises";
import path from "node:path";

const root = process.cwd();
const manifestPath = path.join(root, "src/asset-manifest.json");
const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
const entries = [
  ...(manifest.scenes || []),
  ...(manifest.icons || []),
  ...(manifest.sounds || [])
];
let totalBytes = 0;
const maxFileBytes = 30 * 1024 * 1024;

for (const asset of entries) {
  const source = asset.cdn || asset.src;
  if (!source || !/^https:\/\//i.test(source)) {
    if (asset.src && !/^https:\/\//i.test(asset.src)) continue;
    throw new Error(`Missing remote source for ${asset.id}`);
  }
  const extension = asset.type === "audio/wav" ? "wav"
    : asset.type === "audio/ogg" ? "ogg"
    : asset.type === "audio/mpeg" ? "mp3"
    : asset.type === "image/svg+xml" ? "svg"
    : asset.type === "image/png" ? "png" : "jpg";
  const folder = asset.group === "audio" ? "audio" : asset.group === "icon" ? "icons" : "scenes";
  const relative = `cdn/assets/${folder}/${asset.id}.${extension}`;
  const destination = path.join(root, relative);
  await mkdir(path.dirname(destination), { recursive: true });
  let response;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      response = await fetch(source, { headers: { "User-Agent": "Mshin-Asset-Vendor/0.9.3" }, signal: AbortSignal.timeout(45000) });
      if (response.ok) break;
      throw new Error(`HTTP ${response.status}`);
    } catch (error) {
      if (attempt === 3) throw new Error(`Unable to vendor ${asset.id} from ${source}: ${error.message}`);
      await new Promise(resolve => setTimeout(resolve, attempt * 1500));
    }
  }
  const bytes = Buffer.from(await response.arrayBuffer());
  if (!bytes.length || bytes.length > maxFileBytes) throw new Error(`Invalid size for ${asset.id}: ${bytes.length}`);
  totalBytes += bytes.length;
  if (totalBytes > 100 * 1024 * 1024) throw new Error("Vendored assets exceed the 100 MiB release budget");
  await writeFile(destination, bytes);
  asset.src = `./${relative}`;
  delete asset.cdn;
  asset.bytes = bytes.length;
  console.log(`Vendored ${asset.id}: ${relative} (${bytes.length} bytes)`);
}

for (const collection of [manifest.worlds, manifest.cars]) {
  for (const asset of collection || []) delete asset.cdn;
}
manifest.version = "2026.10.31.17";
await writeFile(manifestPath, JSON.stringify(manifest, null, 2) + "\n");

const packagePath = path.join(root, "package.json");
const pkg = JSON.parse(await readFile(packagePath, "utf8"));
pkg.version = "0.9.3";
await writeFile(packagePath, JSON.stringify(pkg, null, 2) + "\n");
const pwaPath = path.join(root, "manifest.webmanifest");
const pwa = JSON.parse(await readFile(pwaPath, "utf8"));
pwa.version = "0.9.3";
await writeFile(pwaPath, JSON.stringify(pwa, null, 2) + "\n");

const vectorPath = path.join(root, "assets/resources/vector-art.json");
const vector = JSON.parse(await readFile(vectorPath, "utf8"));
vector.version = "2026.10.31.17";
await writeFile(vectorPath, JSON.stringify(vector, null, 2) + "\n");

const htmlPath = path.join(root, "index.html");
let html = await readFile(htmlPath, "utf8");
html = html.replace(/src="\.\/src\/boot\.js\?v=[^"]+"/, 'src="./src/boot.js?v=2026.10.31.17"');
await writeFile(htmlPath, html);

const swPath = path.join(root, "service-worker.js");
let sw = await readFile(swPath, "utf8");
sw = sw.replace(/const CACHE_NAME = "[^"]+";/, 'const CACHE_NAME = "mshin-arcade-v33";');
const localAssets = entries.map(asset => asset.src).filter(Boolean);
const appShellEnd = '  "./assets/vector/car-thunder.svg", "./assets/vector/car-raptor.svg"';
if (!sw.includes(appShellEnd)) throw new Error("Could not locate service-worker app shell insertion point");
sw = sw.replace(appShellEnd, appShellEnd + ",\n" + localAssets.map(src => `  "${src}"`).join(",\n"));
const crossOriginStart = '  if (requestUrl.origin !== self.location.origin) {';
const crossOriginEnd = '  event.respondWith(caches.match(request, { ignoreSearch: true }).then(cached => {';
const start = sw.indexOf(crossOriginStart);
const end = sw.indexOf(crossOriginEnd);
if (start < 0 || end < 0 || end <= start) throw new Error("Could not locate cross-origin service-worker handler");
sw = sw.slice(0, start) + '  if (requestUrl.origin !== self.location.origin) return;\n' + sw.slice(end);
await writeFile(swPath, sw);

const audit = [
  "# Vendored runtime assets — Mshin 0.9.3",
  "",
  "All runtime images, icons, and audio files are stored in this repository under `cdn/assets/` and served from the same GitHub Pages origin.",
  "",
  "| Asset | Local file | Original source | License / attribution |",
  "|---|---|---|---|",
  ...entries.map(asset => `| ${asset.id} | ${asset.src} | ${asset.source || asset.cdn || "original URL recorded in git history"} | ${asset.license || "See upstream source terms; verify before redistribution"} |`),
  "",
  `Total downloaded payload: ${totalBytes} bytes.`,
  "",
  "Runtime policy: no external CDN fallback; the service worker precaches every vendored file. The original source URL and license metadata are retained here for provenance.",
  ""
].join("\n");
await mkdir(path.join(root, "docs"), { recursive: true });
await writeFile(path.join(root, "docs/VENDORED_ASSETS.md"), audit);
console.log(`Vendored ${entries.length} assets; ${totalBytes} bytes total.`);
