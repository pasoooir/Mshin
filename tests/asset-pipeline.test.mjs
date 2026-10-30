import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(await readFile(path.join(root, "src/asset-manifest.json"), "utf8"));
test("all 10 world illustrations and five car sprites are bundled SVG vectors", async () => {
  assert.equal(manifest.worlds.length, 10);
  assert.equal(manifest.cars.length, 5);
  assert.equal(manifest.scenes.length, 10);
  const assets = [...manifest.worlds, ...manifest.cars];
  assert.equal(new Set(assets.map(asset => asset.src)).size, 15);
  for (const asset of assets) {
    assert.ok(asset.cdn.startsWith("https://cdn.jsdelivr.net/gh/pasoooir/Mshin@"), asset.src + " should use jsDelivr");
    assert.match(asset.cdn.split("@")[1].split("/")[0], /^[a-f0-9]{40}$/, asset.src + " should pin an immutable commit");
  }
  for (const asset of assets) {
    const source = await readFile(path.join(root, asset.src.replace(/^\.\//, "")), "utf8");
    assert.match(source, /<svg[\s>]/, asset.src + " should be an SVG vector");
    assert.match(source, /viewBox=/, asset.src + " should define scalable vector bounds");
    assert.ok(source.length < 12000, asset.src + " should remain lightweight");
  }
});
test("asset boot waits for bounded preload before starting the game module", async () => {
  const boot = await readFile(path.join(root, "src/boot.js"), "utf8");
  const loader = await readFile(path.join(root, "src/asset-loader.js"), "utf8");
  const html = await readFile(path.join(root, "index.html"), "utf8");
  assert.match(html, /src="\.\/src\/boot\.js"/);
  assert.match(boot, /await preloadGameAssets/);
  assert.match(boot, /await import\("\.\/web-game\.js"\)/);
  assert.match(loader, /length: 4/);
  assert.match(loader, /manifest\.scenes/);
  assert.match(loader, /Unexpected image MIME type/);
  assert.match(loader, /image\.decode/);
  assert.ok(loader.includes("asset.cdn"), "loader should try the manifest CDN URL");
  assert.ok(loader.includes('source === asset.cdn ? (asset.group === "scene" ? 4200 : 2200) : 10000'), "CDN should have a bounded timeout before local fallback");
  assert.ok(loader.includes("[asset.cdn, asset.src]"), "local bundled art must remain the fallback");
});
test("service worker precaches all vector art before offline races", async () => {
  const sw = await readFile(path.join(root, "service-worker.js"), "utf8");
  assert.match(sw, /mshin-arcade-v6/);
  for (const asset of [...manifest.worlds, ...manifest.cars]) assert.ok(sw.includes(asset.src.replace(/^\.\//, "./")) || sw.includes(asset.src), asset.src + " must be precached");
});
test("photographic world scenes are CDN-preloaded before the race runtime", async () => {
  const loader = await readFile(path.join(root, "src/asset-loader.js"), "utf8");
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  assert.match(loader, /scenes: Object\.fromEntries/);
  assert.match(game, /sceneArt/);
  assert.match(game, /\)\*1\.6/);
  assert.match(game, /,-29,-45,58,90/);
});
test("race hot paths pool particles and use frame-driven collision cooldowns", async () => {
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  assert.match(game, /particlePool/);
  assert.doesNotMatch(game, /setTimeout\(\(\)=>o\.hit=false/);
  assert.match(game, /hudClock>=\.1/);
});
