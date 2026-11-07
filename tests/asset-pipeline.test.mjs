import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { CITY_ARCHITECTURAL_PALETTES } from "../src/city/city-building-high-gfx.js";
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
test("all gameplay control icons are bundled locally and decode as SVG sources", async () => {
  assert.equal(manifest.icons.length, 3);
  for (const asset of manifest.icons) {
    assert.equal(asset.cdn, undefined, asset.src + " must not depend on a remote CDN fallback");
    assert.ok(asset.src.startsWith("./cdn/assets/icons/"), asset.src + " must resolve to the bundled icon directory");
    const source = await readFile(path.join(root, asset.src.replace(/^\.\//, "")), "utf8");
    assert.match(source, /<svg[\s>]/, asset.src + " should be an SVG document");
    assert.match(source, /viewBox=/, asset.src + " should define scalable vector bounds");
  }
});

test("asset boot waits for bounded preload before starting the game module", async () => {
  const boot = await readFile(path.join(root, "src/boot.js"), "utf8");
  const loader = await readFile(path.join(root, "src/asset-loader.js"), "utf8");
  const audio = await readFile(path.join(root, "src/audio.js"), "utf8");
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  const html = await readFile(path.join(root, "index.html"), "utf8");
  assert.ok(html.includes('src="./src/boot.js?v=2026.11.06.01"'));
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
  for (const module of ["audio.js", "collision-physics.js", "vehicle-pbr.js", "rigid-body-physics.js", "tire-physics.js", "vehicle-dynamics.js", "pickup-collection.js", "vehicle-damage-visuals.js", "traffic-ai.js", "vehicle-destruction.js", "city/city-traffic.js"]) {
    assert.ok(sw.includes(`./src/${module}`), `${module} must be precached`);
  }
});
test("service worker precaches all vector art before offline races", async () => {
  const sw = await readFile(path.join(root, "service-worker.js"), "utf8");
  assert.match(sw, /mshin-arcade-v83/);
  assert.doesNotMatch(sw, /https?:\/\/|mshin-audio-assets-v1|opengameart\.org|sfxmint\.com|cdn\.jsdelivr\.net/, "service worker must not use third-party runtime endpoints");
  assert.doesNotMatch(sw, /https?:\/\/|mshin-audio-assets-v1|opengameart\.org|sfxmint\.com|cdn\.jsdelivr\.net/, "service worker must not use third-party runtime endpoints");
  assert.match(sw, /src\/tire-physics\.js/);
  for (const asset of ["./vendor/three/build/three.module.min.js", "./vendor/three/build/three.core.min.js", "./vendor/three/examples/jsm/controls/OrbitControls.js", "./vendor/three/examples/jsm/loaders/GLTFLoader.js", "./vendor/three/examples/jsm/utils/BufferGeometryUtils.js", "./vendor/three/LICENSE", "./assets/textures/asphalt_03_diff_1k.jpg", "./assets/textures/grass_ground_diff_1k.jpg", "./assets/textures/sand_01_diff_1k.jpg", "./assets/textures/snow_03_diff_1k.jpg", "./assets/textures/rocky_terrain_02_diff_1k.jpg", "./assets/textures/concrete_floor_02_diff_1k.jpg", "./assets/textures/bark_brown_02_diff_1k.jpg", "./assets/textures/leafy_grass_diff_1k.jpg"]) assert.ok(sw.includes(asset), `${asset} must be precached`);
  for (const module of ["vehicle-pbr.js", "rigid-body-physics.js", "traffic-ai.js", "vehicle-destruction.js"]) assert.ok(sw.includes(`./src/${module}`), `${module} must be available offline`);
  for (const asset of [...manifest.worlds, ...manifest.cars, ...manifest.scenes, ...manifest.icons, ...manifest.sounds]) assert.ok(sw.includes(asset.src), asset.src + " must be precached");
});
test("neighborhood preview and local architecture models are precached for offline use", async () => {
  const sw = await readFile(path.join(root, "service-worker.js"), "utf8");
  for (const asset of ["./city-neighborhood-preview.html", "./assets/city/models/manifest.json", "./assets/city/models/house.gltf", "./assets/city/models/apartment.gltf", "./assets/city/models/shop.gltf"]) {
    assert.ok(sw.includes(asset), asset + " must be available to the offline preview");
  }
});

test("Cocos runtime menus use the Mshin motorsport visual system", async () => {
  const cocos = await readFile(path.join(root, "assets/scripts/MshinGame.ts"), "utf8");
  assert.match(cocos, /drawMenuBackdrop\("MSHIN MOTORSPORT"/);
  for (const screen of ["WORLD SELECT", "STAGE SELECT", "RACE PAUSED", "RACE COMPLETE"]) assert.ok(cocos.includes(screen), screen + " should use the shared motorsport backdrop");
  assert.match(cocos, /#14253A/);
  assert.match(cocos, /#F33A52/);
  assert.match(cocos, /g\.moveTo\(-w\/2\+7,-h\/2\)/);
  assert.match(cocos, /g\.close\(\);g\.fill\(\)/);
  assert.match(cocos, /Node\.EventType\.TOUCH_END/);
  assert.match(cocos, /private menuRoot!:Node/);
  assert.match(cocos, /menuRoot\.setScale\(menuScale,menuScale,1\)/);
  assert.match(cocos, /Math\.min\(1,s\.width\/1280,s\.height\/720\)/);
  for (const entry of ["CONTINUE","RETRY","LEAVE EVENT","DRIVER DETAILS","MOST WANTED"]) assert.ok(cocos.includes(entry), `${entry} must appear in the responsive pause menu`);
  assert.match(cocos, /private addWantedRow\(/);
  assert.match(cocos, /this\.screen="paused";this\.cameraNode\.angle=0;this\.hudCanvas\.angle=0/);
  assert.match(cocos, /this\.cameraNode\.angle=-this\.carNode\.angle;this\.hudCanvas\.angle=this\.carNode\.angle/);
  assert.match(cocos, /private addPauseEntry\(/);
  const pauseHtml = await readFile(path.join(root, "index.html"), "utf8");
  assert.match(pauseHtml, /class="pauseScreen"/);
  assert.match(pauseHtml, /id="retryRace"/);
  assert.match(pauseHtml, /MOST WANTED/);
  assert.match(pauseHtml, /height:min\(690px,calc\(100dvh/);
  assert.match(pauseHtml, /@media\(max-aspect-ratio:1\/1\)/);
  const webGame = await readFile(path.join(root, "src/web-game.js"), "utf8");
  assert.match(webGame, /\$\("retryRace"\)\.onclick=\(\)=>\{audio\.unlock\(\);begin\(\)\}/);
  assert.doesNotMatch(cocos, /g\.fillColor=hex\("#F8C84E"\);g\.roundRect\(-w\/2/);
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
  assert.match(game, /stepVehicleDynamics/);
  assert.match(sw, /collision-physics\.js/);
  assert.match(game, /lane\(-90,"#ffffff70",3,\[22,30\]\)/);
  assert.match(game, /lane\(90,"#ffffff70",3,\[22,30\]\)/);
  assert.match(game, /Four lanes/);
  assert.match(game, /ROAD_HALF_WIDTH=220/);
  assert.match(game, /lanes:\[-165,-82.5,82.5,165\]/);
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
  assert.match(html, /نسخه ۰.۱۱.۰/);
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
  assert.match(sw, /mshin-arcade-v83/);
  assert.ok(html.includes("boot"), "HTML should load the boot module");
  assert.equal(manifest.version, "2026.11.06.01");
  assert.equal(pkg.version, "0.15.7");
  assert.equal(pwa.version, "0.15.7");
  assert.equal(cocos.version, "2026.11.06.01");
  assert.ok(readme.includes("Latest published release on main: 0.15.2") && readme.includes("Version 0.14.0 remains a separate draft and is not claimed as live"), "README must identify the verified live release without claiming the mobile fix is deployed");
  assert.ok(readme.includes("## Latest published release on main: 0.15.2") && readme.includes("Versions 0.11.0–0.11.6 were published on GitHub Pages; the in-race vehicle geometry was merged afterward in pull request #77"), "README must distinguish the published release from the mobile-fix PR branch");
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
  assert.ok(game.includes('state==="countdown"){drawCountdownIntro();const standings=getRaceStandings()'));
  for (const kind of ['types.push("pickup")','types.push("formula")','types.push("truck")','types.push("bus","motorcycle")']) assert.ok(game.includes(kind), kind + " must be introduced in later stages");
  assert.ok(game.includes("function drawTrafficBody(r)"));
  assert.ok(game.includes("function awardImpactReward(hit,forwardDot,impactScale=1)"));
  assert.ok(game.includes("progress.credits+=reward;saveProgress()")); assert.ok(game.includes("race.impactPoints"));
  assert.ok(game.includes("تخریب حریف"));
});


test("world-space player collision velocity preserves chassis heading", async () => {
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  const playerVelocity = /vehicleVelocity\(car\.t,car\.speed,car\.lateralVelocity,car\.yaw\)/g;
  assert.ok((game.match(playerVelocity) || []).length >= 3, "AI and obstacle collision responses must use the player's actual chassis heading");
  assert.match(game, /playerTrackT:car\.t,playerTrackAngle:playerFrame\.angle,playerTrackCurvature,playerLateral:car\.lateral,playerLateralVelocity:car\.lateralVelocity,playerYaw:car\.yaw,[^}]*playerSpeed:car\.speed/);
});

test("pickup collection uses swept vehicle motion and a physical capture radius", async () => {
  const source = await readFile(path.join(root, "src/pickup-collection.js"), "utf8");
  assert.match(source, /function sweptPickupContact/);
  assert.match(source, /pointSegmentDistanceSquared/);
  assert.match(source, /radius\*radius/);
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  assert.match(game, /sweptPickupContact\(previousPlayerPosition,pickupCurrentPosition/);
  assert.match(game, /const previousPlayerPosition=carPoint\(\)/);
});

test("opening nitro pickup is aligned with the player and protected from early traffic", async () => {
  const game = await readFile(path.join(root, "src/web-game.js"), "utf8");
  assert.match(game, /t:i===0\?\.075:/, "first pickup should be just ahead of the start line");
  assert.match(game, /lateral:i===0\?0:/, "first pickup should align with the starting lane");
  assert.match(game, /distance:0,totalProgress:0,lapsCompleted:0,clock:createRaceClock\(\),timerElapsed:0,finishTime:null/, "all race entrants should share the same starting line and reset clocks");
  assert.match(game, /const lanes=\[-165,-82.5,82.5,165,-165,82.5,-82.5,165\]/, "opponents should occupy separate grid lanes");
});


test("city architecture uses controlled natural sRGB material palettes", () => {
  const required = ["home","shop","industrial","administrative","service","power","water","sewage","waste","police","fire","health","education"];
  assert.deepEqual(Object.keys(CITY_ARCHITECTURAL_PALETTES).sort(), required.sort());
  for (const [category, palettes] of Object.entries(CITY_ARCHITECTURAL_PALETTES)) {
    assert.ok(palettes.length >= 2, category + " needs multiple deterministic facade variants");
    for (const palette of palettes) {
      for (const channel of ["wall","side","roof","trim","accent","door"]) {
        const value = palette[channel];
        assert.match(value, /^#[0-9a-f]{6}$/i, category + "." + channel + " must be a 24-bit sRGB color");
        const rgb = value.slice(1).match(/../g).map(hex => parseInt(hex, 16));
        const chroma = Math.max(...rgb) - Math.min(...rgb);
        assert.ok(chroma <= 120, category + "." + channel + " must avoid oversaturated neon material colors: " + value);
      }
    }
  }
});
