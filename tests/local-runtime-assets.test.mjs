import test from "node:test";
import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifest = JSON.parse(await readFile(path.join(root, "src/asset-manifest.json"), "utf8"));
const stageCatalog = JSON.parse(await readFile(path.join(root, "data/stages.json"), "utf8"));

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
  assert.match(sw, /mshin-arcade-v\d+/);
  assert.match(sw, /\.\/src\/multitouch-input\.js/);
  assert.match(sw, /\.\/src\/vehicle-pbr\.js/);
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

test("all required racing textures are repository-local and precached", async () => {
  const sw = await readFile(path.join(root, "service-worker.js"), "utf8");
  const files = [
    "assets/textures/asphalt_03_diff_1k.jpg",
    "assets/textures/grass_ground_diff_1k.jpg",
    "assets/textures/sand_01_diff_1k.jpg",
    "assets/textures/snow_03_diff_1k.jpg",
    "assets/textures/rocky_terrain_02_diff_1k.jpg",
    "assets/textures/concrete_floor_02_diff_1k.jpg",
    "assets/textures/bark_brown_02_diff_1k.jpg",
    "assets/textures/leafy_grass_diff_1k.jpg"
  ];
  for (const relative of files) {
    const info = await stat(path.join(root, relative));
    assert.ok(info.isFile() && info.size > 0, relative + " must be committed");
    assert.ok(sw.includes("./" + relative), relative + " must be precached");
  }
  const raceRenderer = await readFile(path.join(root, "src/race-renderer-3d.js"), "utf8");
  assert.doesNotMatch(raceRenderer, /https?:\/\/dl\.polyhaven\.org|source\.fallback/);
});
test("all stage previews use project-relative GitHub Pages paths and are cached offline", async () => {
  const sw = await readFile(path.join(root, "service-worker.js"), "utf8");
  assert.equal(stageCatalog.stages.length, 50);
  for (const stage of stageCatalog.stages) {
    assert.ok(stage.preview.startsWith("./cdn/previews/"), stage.slug + " must use a project-relative path");
    assert.ok(!("cdnUrl" in stage), stage.slug + " must not contain an external CDN URL");
    const info = await stat(path.join(root, stage.preview));
    assert.ok(info.isFile() && info.size > 0, stage.preview + " must exist locally");
    assert.ok(sw.includes('"' + stage.preview + '"'), stage.preview + " must be cached offline");
  }
  assert.ok(sw.includes('"./data/stages.json"'));
  assert.ok(sw.includes('"./data/worlds.json"'));
});
test("Three.js and all city addons are local and precached", async () => {
  const files = [
    "vendor/three/build/three.module.min.js",
    "vendor/three/build/three.core.min.js",
    "vendor/three/examples/jsm/controls/OrbitControls.js",
    "vendor/three/examples/jsm/loaders/GLTFLoader.js",
    "vendor/three/examples/jsm/utils/BufferGeometryUtils.js",
    "vendor/three/LICENSE"
  ];
  const sw = await readFile(path.join(root, "service-worker.js"), "utf8");
  const threeModule = await readFile(path.join(root, "vendor/three/build/three.module.min.js"), "utf8");
  const threeCore = await readFile(path.join(root, "vendor/three/build/three.core.min.js"), "utf8");
  const cityRenderer = await readFile(path.join(root, "src/city/city-three-renderer.js"), "utf8");
  const preview = await readFile(path.join(root, "city-neighborhood-preview.html"), "utf8");
  for (const relative of files) {
    const info = await stat(path.join(root, relative));
    assert.ok(info.isFile() && info.size > 0, relative + " must be non-empty");
    assert.ok(sw.includes("./" + relative), relative + " must be precached");
  }
  assert.match(threeModule, /from"\.\/three\.core\.min\.js"/);
  assert.match(threeCore, /const t="180"/);
  assert.match(cityRenderer, /import\("\.\.\/\.\.\/vendor\/three\/build\/three\.module\.min\.js"\)/);
  assert.doesNotMatch(cityRenderer, /cdn\.jsdelivr\.net|unpkg\.com/);
  assert.match(preview, /"three":"\.\/vendor\/three\/build\/three\.module\.min\.js"/);
  assert.match(preview, /"three\/addons\/":"\.\/vendor\/three\/examples\/jsm\//);
  assert.doesNotMatch(preview, /cdn\.jsdelivr\.net|unpkg\.com/);
});
