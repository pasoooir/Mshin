import test from "node:test";
import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(await readFile(path.join(root, "src/asset-manifest.json"), "utf8"));

test("every runtime asset is stored inside this repository", async () => {
  const assets = [...manifest.worlds, ...manifest.cars, ...manifest.scenes, ...manifest.icons, ...manifest.sounds];
  assert.equal(manifest.scenes.length, 10);
  assert.equal(manifest.icons.length, 3);
  assert.equal(manifest.sounds.length, 10);
  assert.equal(assets.length, 38);
  for (const asset of assets) {
    assert.ok(asset.src.startsWith("./"), `${asset.id} must use a relative same-origin path`);
    assert.doesNotMatch(asset.src, /^https?:/i, `${asset.id} must not reference an external host`);
    const file = path.join(root, asset.src.replace(/^\.\//, ""));
    const info = await stat(file);
    assert.ok(info.isFile() && info.size > 0, `${asset.id} must exist as a non-empty repository file`);
    if (asset.bytes) assert.equal(info.size, asset.bytes, `${asset.id} byte inventory must match the committed file`);
  }
});

test("service worker precaches all runtime assets and rejects cross-origin requests", async () => {
  const sw = await readFile(path.join(root, "service-worker.js"), "utf8");
  assert.match(sw, /mshin-arcade-v36/);
  assert.match(sw, /requestUrl\.origin !== self\.location\.origin\) return/);
  assert.doesNotMatch(sw, /opengameart\.org|sfxmint\.com|cdn\.jsdelivr\.net|images\.unsplash\.com/);
  for (const asset of [...manifest.scenes, ...manifest.icons, ...manifest.sounds]) {
    assert.ok(sw.includes(asset.src), `${asset.id} must be in the offline app shell`);
  }
});

test("runtime asset loader consumes manifest paths without external CDN fallback", async () => {
  const loader = await readFile(path.join(root, "src/asset-loader.js"), "utf8");
  assert.match(loader, /fetchImage/);
  assert.match(loader, /fetch\(source/);
  assert.doesNotMatch(loader, /cdn\.jsdelivr\.net|images\.unsplash\.com|sfxmint\.com|opengameart\.org/);
  assert.match(loader, /manifest\.scenes/);
  assert.match(loader, /manifest\.sounds/);
});
