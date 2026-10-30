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
  assert.match(html, /src="\.\/src\/boot\.js(?:\?v=[^"]+)?"/);
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
  assert.match(sw, /mshin-arcade-v14/);
  for (const asset of [...manifest.worlds, ...manifest.cars]) assert.ok(sw.includes(asset.src.replace(/^\.\//, "./")) || sw.includes(asset.src), asset.src + " must be precached");
});
test("photographic world scenes are CDN-preloaded before the race runtime", async () => {
  const loader = await readFile(path.join(root, "src/asset-loader.js"), "utf8");
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  const cocos = await readFile(path.join(root, "assets/scripts/MshinGame.ts"), "utf8");
  assert.match(loader, /scenes: Object\.fromEntries/);
  assert.match(game, /sceneArt/);
  assert.match(game, /\)\*1\.6/);
  assert.match(game, /,-36,-54,72,108/);
  assert.ok(game.includes("ctx.rotate(-c.angle-Math.PI/2)"), "race camera should follow the road tangent and keep the player car facing forward");
  assert.match(cocos, /cameraNode\.angle=-this\.carNode\.angle/);
  assert.match(cocos, /hudCanvas\.angle=this\.carNode\.angle/);
  assert.match(cocos, /this\.carNode\.setScale\(1\.25,1\.25,1\)/);
});
test("race hot paths pool particles and use frame-driven collision cooldowns", async () => {
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  const sw = await readFile(path.join(root, "service-worker.js"), "utf8");
  assert.match(game, /particlePool/);\n  assert.match(game, /resolveVehicleImpact/);\n  const cocosCore = await readFile(path.join(root, "src/cocos-core.ts"), "utf8");\n  const cocosVehicle = await readFile(path.join(root, "assets/scripts/VehicleController.ts"), "utf8");\n  assert.match(cocosCore, /resolveVehicleImpulse/);\n  assert.match(cocosCore, /resolveStaticBarrier/);\n  assert.match(cocosVehicle, /addVehicleDamage/);\n  assert.match(cocosVehicle, /resolveStaticBarrier/);\n  assert.match(game, /resolveBarrierImpact/);\n  assert.match(game, /applyVehicleDamage/);\n  assert.match(game, /drawDamageOverlay/);\n  assert.match(game, /AI-to-AI contacts/);\n  assert.match(game, /cameraShake/);\n  assert.match(game, /collisionCooldown/);\n  assert.match(sw, /collision-physics\\.js/);
  assert.match(game, /lane\(-40,"#ffffff70",3,\[22,30\]\)/);
  assert.match(game, /lane\(40,"#ffffff70",3,\[22,30\]\)/);
  assert.match(game, /Three readable lanes/);
  assert.match(game, /"دره سبز"/);
  assert.match(game, /"توفان کویر"/);
  assert.match(game, /وضعیت هوا/);
  assert.match(game, /مرحله/);
  assert.doesNotMatch(game, /setTimeout\(\(\)=>o\.hit=false/);
  assert.match(game, /hudClock>=\.1/);
});

test("boot experience uses a cinematic game splash and compact one-page mobile menu", async () => {
  const html = await readFile(path.join(root, "index.html"), "utf8");
  assert.match(html, /class="splash"/);
  assert.match(html, /lang="fa-IR" dir="rtl"/);
  assert.match(html, /Hamed Babaei/);
  assert.match(html, /https:\/\/ir\.linkedin\.com\/in\/gilasart/);
  assert.match(html, /انتخاب مسابقه/);
  assert.match(html, / aria-label="روشن یا خاموش کردن صدا"/);
  assert.match(html, /MSHIN STUDIOS/);
  assert.match(html, /نسخه ۰\.۴\.۷/);
  assert.match(html, /splashCarFront/);
  assert.match(html, /id="assetPercent"/);
  assert.match(html, /id="assetProgress"/);
  assert.match(html, /@keyframes splashDrive/);
  assert.match(html, /#select \.worlds\{grid-template-columns:repeat\(2,minmax\(0,1fr\)\)/);
  assert.match(html, /#select \.upgrades\{grid-template-columns:repeat\(3,minmax\(0,1fr\)\)/);
  assert.match(html, /#select \.actions\{position:sticky/);
  const boot = await readFile(path.join(root, "src/boot.js"), "utf8");
  assert.match(boot, /assetPercent/);
  assert.match(boot, /همه منابع آماده‌اند/);
});

test("all app cache and asset version markers are advanced together", async () => {
  const sw = await readFile(path.join(root, "service-worker.js"), "utf8");
  const html = await readFile(path.join(root, "index.html"), "utf8");
  const pkg = JSON.parse(await readFile(path.join(root, "package.json"), "utf8"));
  const pwa = JSON.parse(await readFile(path.join(root, "manifest.webmanifest"), "utf8"));
  const cocos = JSON.parse(await readFile(path.join(root, "assets/resources/vector-art.json"), "utf8"));
  assert.match(sw, /mshin-arcade-v14/);
  assert.match(html, /boot\.js\?v=2026.10.30.11/);
  assert.equal(manifest.version, "2026.10.30.11");
  assert.equal(pkg.version, "0.4.8");
  assert.equal(pwa.version, "0.4.8");
  assert.equal(cocos.version, "2026.10.30.8");
});
