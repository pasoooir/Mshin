import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const html = await readFile(new URL("../index.html", import.meta.url), "utf8");
const game = await readFile(new URL("../src/web-game.js", import.meta.url), "utf8");
const manifest = JSON.parse(await readFile(new URL("../manifest.webmanifest", import.meta.url), "utf8"));
const pkg = JSON.parse(await readFile(new URL("../package.json", import.meta.url), "utf8"));
const sw = await readFile(new URL("../service-worker.js", import.meta.url), "utf8");

test("portrait devices receive a rotated landscape game surface without a rotate-device gate", () => {
  assert.match(html, /width:100dvh!important;height:100dvw!important/);
  assert.match(html, /transform:rotate\(90deg\) translateY\(-100%\)!important/);
  assert.doesNotMatch(html, /برای اجرای بازی، دستگاه را افقی نگه دارید|گوشی را به حالت افقی بچرخانید|content:\\"↻\\"/);
  assert.doesNotMatch(html, /stopImmediatePropagation\(\)/);
  assert.equal(manifest.orientation, "landscape");
  assert.match(html, /id="cameraMode"/, "race HUD must expose a camera angle selector");
  assert.match(game, /cameraMode:\["side","top","southeast","southwest"\]/, "camera view preference must persist across sessions");
  assert.match(game, /drawPerspectiveRace\(ctx/, "race renderer must support the new perspective camera");
});

test("canvas backing store uses landscape logical dimensions in portrait mode", () => {
  assert.match(game, /portrait\?Math\.max\(innerWidth,innerHeight\):innerWidth/);
  assert.match(game, /portrait\?Math\.min\(innerWidth,innerHeight\):innerHeight/);
  assert.match(game, /softwareLandscape:portrait/);
});

test("pause menu exposes ten actions and a data-driven five-row leaderboard", () => {
  assert.match(html, /id="driverDetails"/);
  assert.match(html, /id="pauseSettings"/);
  assert.match(html, /id="mostWantedList"/);
  assert.match(html, /MULTIPLAYER · UNAVAILABLE/);
  assert.match(game, /function renderPauseLeaderboard\(\)/);
  assert.match(game, /rival\.distance/);
  assert.match(game, /list\.replaceChildren/);
});

test("settings and pause actions preserve game state semantics", () => {
  assert.match(game, /state="paused"/);
  assert.match(game, /state="race";audio\.unlock\(\);show\("race"\)/);
  assert.match(game, /\$\("pauseSettings"\)\.onclick/);
  assert.match(game, /\$\("retryRace"\)\.onclick=\(\)=>\{audio\.unlock\(\);begin\(\)\}/);
});

test("PWA and offline cache markers advance together", () => {
  assert.equal(manifest.version, pkg.version, "PWA manifest version must match package.json");
  assert.match(sw, /mshin-arcade-v39/);
});

test("menu and garage use repository-local procedural WebGL 3D scenes", async () => {
  const scene = await readFile(new URL("../src/menu-3d-scene.js", import.meta.url), "utf8");
  assert.match(game, /createMenu3DScene/);
  assert.match(scene, /getContext\("webgl"/);
  assert.match(scene, /function perspective/);
  assert.match(scene, /function lookAt/);
  assert.match(scene, /function ring\(/);
  assert.match(scene, /function car\(/);
  assert.match(scene, /mshinMenu3DCanvas/);
  assert.match(scene, /mshinGarage3DCanvas/);
  assert.match(scene, /Mshin3DGarage/);
  assert.doesNotMatch(scene, /https?:\/\//, "3D runtime must not depend on a CDN or external model host");
  assert.ok(sw.includes("./src/menu-3d-scene.js"), "3D scene module must be precached for offline use");
  assert.match(html, /#mshinGarage3DCanvas/);
  assert.match(html, /#hud,\.overlay,#mshinMenu3DCanvas/);
});
