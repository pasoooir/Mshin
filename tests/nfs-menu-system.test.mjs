import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const html = await readFile(new URL("../index.html", import.meta.url), "utf8");
const game = await readFile(new URL("../src/web-game.js", import.meta.url), "utf8");
const manifest = JSON.parse(await readFile(new URL("../manifest.webmanifest", import.meta.url), "utf8"));
const sw = await readFile(new URL("../service-worker.js", import.meta.url), "utf8");

test("portrait devices receive a rotated landscape game surface without a rotate-device gate", () => {
  assert.match(html, /width:100dvh!important;height:100dvw!important/);
  assert.match(html, /transform:rotate\(90deg\) translateY\(-100%\)!important/);
  assert.doesNotMatch(html, /برای اجرای بازی، دستگاه را افقی نگه دارید|گوشی را به حالت افقی بچرخانید|content:\\"↻\\"/);
  assert.doesNotMatch(html, /stopImmediatePropagation\(\)/);
  assert.equal(manifest.orientation, "landscape");
});

test("canvas backing store follows VisualViewport while preserving landscape logical dimensions", () => {
  assert.ok(game.includes("const viewport=window.visualViewport;"));
  assert.ok(game.includes("viewport?.width||innerWidth"));
  assert.ok(game.includes("viewport?.height||innerHeight"));
  assert.ok(game.includes("width=portrait?Math.max(viewportWidth,viewportHeight):viewportWidth;"));
  assert.ok(game.includes("height=portrait?Math.min(viewportWidth,viewportHeight):viewportHeight;"));
  assert.ok(game.includes('window.visualViewport?.addEventListener("resize",scheduleViewportResize,{passive:true});'));
  assert.ok(game.includes("softwareLandscape:portrait"));
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
  assert.equal(manifest.version, "0.15.4");
  assert.match(sw, /mshin-arcade-v68/);
});

test("race countdown advances on a monotonic wall clock without depending on animation frames", () => {
  assert.match(game, /countdownStartedAt=performance\.now\(\)/);
  assert.match(game, /performance\.now\(\)-countdownStartedAt/);
  assert.match(game, /setTimeout\(scheduleCountdownTick/);
  assert.doesNotMatch(game, /countdownElapsed\+=dt/);
});
