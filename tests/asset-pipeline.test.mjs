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
    assert.equal(asset.cdn, undefined, asset.src + " must not retain an external CDN fallback");
    assert.ok(asset.src.startsWith("./assets/vector/"), asset.src + " must resolve locally");
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
  const audio = await readFile(path.join(root, "src/audio.js"), "utf8");
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  const html = await readFile(path.join(root, "index.html"), "utf8");
  assert.ok(html.includes('src="./src/boot.js?v=2026.10.31.17"'));
  assert.match(html, /role="tablist"/);
  assert.match(html, /data-panel="race"/);
  assert.doesNotMatch(html, /مشاهده تغییرات نسخه|releaseBadge/);
  assert.match(game, /function activateMenuTab/);
  assert.match(game, /worldArt/);
  assert.match(game, /carArt/);
  assert.doesNotMatch(audio, /\\\\n/, "audio module must not contain escaped newlines that break browser module parsing");
  assert.match(audio, /decodeAudioData/);
  assert.match(audio, /engineGains/);
  assert.match(audio, /engineSources/);
  assert.match(audio, /RPM layers use equal-power crossfades/);
  assert.match(audio, /loopStart=edge/);
  assert.match(audio, /loopEnd=Math.max/);
  assert.match(audio, /gearForSpeed/);
  assert.match(audio, /setTargetAtTime/);
  assert.match(audio, /createBiquadFilter/);
  assert.match(game, /audio\.update\(car\.speed,state==="race"\|\|state==="countdown",input\.gas,input\.brake,boostTimer>0,selectedCar\)/);
  assert.match(loader, /manifest\.icons/);
  assert.match(loader, /manifest\.sounds/);
  assert.match(loader, /audioCache\.set/);
  assert.match(loader, /loadAudio/);
  assert.ok(loader.includes("audioData:"), "audio bytes must be retained before game startup");
  assert.ok(manifest.sounds.filter(sound => sound.id.startsWith("engine")).length === 6 && manifest.sounds.filter(sound => sound.id.startsWith("engine")).every(sound => sound.src.startsWith("./cdn/assets/audio/") && sound.license === "CC0"), "race engine audio must be bundled locally with CC0 provenance");
  assert.equal(manifest.icons.length, 3, "gas, brake and nitro icons must be bundled");
  assert.ok(manifest.icons.every(icon => icon.src.startsWith("./cdn/assets/icons/")), "all control icons must be local repository assets");
  const music = manifest.sounds.filter(sound => sound.id === "musicMenu" || sound.id === "musicRace");
  assert.equal(music.length, 2, "menu and race music must both be registered");
  assert.ok(music.every(track => track.license === "CC0-1.0" && track.src.startsWith("./cdn/assets/audio/") && track.source.startsWith("https://opengameart.org/")), "music tracks must be bundled locally with CC0 provenance");
  assert.ok(manifest.scenes.every(scene => scene.src.startsWith("./cdn/assets/scenes/")), "all photographic scenes must be local repository assets");
  assert.ok([...manifest.scenes, ...manifest.icons, ...manifest.sounds].every(asset => !/^https?:/i.test(asset.src)), "runtime asset paths must never point to external hosts");
});
test("service worker precaches every browser runtime dependency for offline gameplay", async () => {
  const sw = await readFile(path.join(root, "service-worker.js"), "utf8");
  for (const module of ["audio.js", "collision-physics.js", "rigid-body-physics.js", "tire-physics.js", "vehicle-damage-visuals.js", "traffic-ai.js", "vehicle-destruction.js"]) {
    assert.ok(sw.includes(`./src/${module}`), `${module} must be precached`);
  }
});
test("service worker precaches all vector art before offline races", async () => {
  const sw = await readFile(path.join(root, "service-worker.js"), "utf8");
  assert.match(sw, /mshin-arcade-v33/);
  assert.doesNotMatch(sw, /https?:\/\/|mshin-audio-assets-v1|opengameart\.org|sfxmint\.com|cdn\.jsdelivr\.net/, "service worker must not use third-party runtime endpoints");
  assert.doesNotMatch(sw, /https?:\/\/|mshin-audio-assets-v1|opengameart\.org|sfxmint\.com|cdn\.jsdelivr\.net/, "service worker must not use third-party runtime endpoints");
  assert.match(sw, /src\/tire-physics\.js/);
  for (const module of ["rigid-body-physics.js", "traffic-ai.js", "vehicle-destruction.js"]) assert.ok(sw.includes(`./src/${module}`), `${module} must be available offline`);
  for (const asset of [...manifest.worlds, ...manifest.cars, ...manifest.scenes, ...manifest.icons, ...manifest.sounds]) assert.ok(sw.includes(asset.src), asset.src + " must be precached");
});
test("photographic world scenes are repository-bundled before the race runtime", async () => {
  const loader = await readFile(path.join(root, "src/asset-loader.js"), "utf8");
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  const cocos = await readFile(path.join(root, "assets/scripts/MshinGame.ts"), "utf8");
  assert.match(loader, /scenes: Object\.fromEntries/);
  assert.match(game, /sceneArt/);
  assert.match(game, /\)\*\.96/);
  assert.match(game, /,-36,-54,72,108/);
  assert.ok(game.includes("ctx.rotate(-c.angle-Math.PI/2)"), "race camera should follow the road tangent and keep the player car facing forward");
  assert.match(cocos, /cameraNode\.angle=-this\.carNode\.angle/);
  assert.match(cocos, /hudCanvas\.angle=this\.carNode\.angle/);
  assert.match(cocos, /this\.carNode\.setScale\(1\.25,1\.25,1\)/);
});
test("race hot paths pool particles and use frame-driven collision cooldowns", async () => {
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  const sw = await readFile(path.join(root, "service-worker.js"), "utf8");
  assert.match(game, /particlePool/);
  assert.match(game, /resolveVehicleImpact/);
  const cocosCore = await readFile(path.join(root, "src/cocos-core.ts"), "utf8");
  const cocosVehicle = await readFile(path.join(root, "assets/scripts/VehicleController.ts"), "utf8");
  assert.match(cocosCore, /resolveVehicleImpulse/);
  assert.match(cocosCore, /resolveStaticBarrier/);
  assert.match(cocosVehicle, /addVehicleDamage/);
  assert.match(cocosVehicle, /resolveStaticBarrier/);
  const damageRenderer = await readFile(path.join(root, "assets/scripts/VehicleDamageRenderer.ts"), "utf8");
  const cocosGame = await readFile(path.join(root, "assets/scripts/MshinGame.ts"), "utf8");
  assert.match(cocosGame, /VehicleDamageRenderer/);
  assert.match(cocosGame, /"damage","بدنه/);
  assert.match(damageRenderer, /damage\.front/);
  assert.match(damageRenderer, /damage\.rear/);
  assert.match(damageRenderer, /damage\.left/);
  assert.match(damageRenderer, /damage\.right/);
  assert.match(damageRenderer, /damage\.engine/);
  assert.match(damageRenderer, /disabled/);
  assert.match(game, /resolveBarrierImpact/);
  assert.match(game, /applyVehicleDamage/);
  assert.match(game, /drawDamageOverlay/);
  assert.match(game, /getDamageVisuals/);
  assert.match(sw, /vehicle-damage-visuals\.js/);
  assert.match(game, /AI-to-AI contacts/);
  assert.match(game, /cameraShake/);
  assert.match(game, /collisionCooldown/);
  assert.match(game, /resolveTireForces/);
  assert.match(sw, /collision-physics\.js/);
  assert.match(game, /lane\(-90,"#ffffff70",3,\[22,30\]\)/);
  assert.match(game, /lane\(90,"#ffffff70",3,\[22,30\]\)/);
  assert.match(game, /Four lanes/);
  assert.match(game, /ROAD_HALF_WIDTH=180/);
  assert.match(game, /lanes:\[-135,-45,45,135\]/);
  assert.match(game, /countdownElapsed<3\.72/);
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
  assert.match(html, /نسخه ۰.۹.۲/);
  assert.match(html, /هوش ترافیک/);
  assert.match(html, /تخریب پویا/);
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
  const readme = await readFile(path.join(root, "README.md"), "utf8");
  assert.match(sw, /mshin-arcade-v32/);
  assert.ok(html.includes("boot"), "HTML should load the boot module");
  assert.equal(manifest.version, "2026.10.31.17");
  assert.equal(pkg.version, "0.9.3");
  assert.equal(pwa.version, "0.9.3");
  assert.equal(cocos.version, "2026.10.31.17");
  assert.ok(readme.includes("release candidate is **version 0.9.3**"), "README must identify 0.9.3 as the current release candidate");
});

test("vehicle-specific sound profiles include an EV motor whine", async () => {
  const audio = await readFile(path.join(root, "src/audio.js"), "utf8");
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  for (const id of ["rally", "comet", "lynx", "raptor", "thunder"]) assert.ok(audio.includes(id + ":{"), id + " sound profile is required");
  assert.ok(audio.includes("electric:true")); assert.ok(audio.includes("roughness:0"));
  assert.ok(audio.includes("evOscillators"));
  assert.ok(audio.includes('vehicleId="rally"'));
  assert.ok(game.includes("boostTimer>0,selectedCar"));
});

test("race intro, progressive traffic classes and impact coin rewards are wired into gameplay", async () => {
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  assert.ok(game.includes("function drawCountdownIntro()"));
  assert.ok(game.includes('state==="countdown"){drawCountdownIntro();return}'));
  for (const kind of ['types.push("pickup")','types.push("formula")','types.push("truck")','types.push("bus","motorcycle")']) assert.ok(game.includes(kind), kind + " must be introduced in later stages");
  assert.ok(game.includes("function drawTrafficBody(r)"));
  assert.ok(game.includes("function awardImpactReward(hit,forwardDot)"));
  assert.ok(game.includes("progress.credits+=reward;saveProgress()")); assert.ok(game.includes("race.impactPoints"));
  assert.ok(game.includes("تخریب حریف"));
});
