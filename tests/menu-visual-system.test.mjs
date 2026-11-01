import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const html = await readFile(new URL("index.html", root), "utf8");
const css = await readFile(new URL("src/menu-visual-system.css", root), "utf8");
const sw = await readFile(new URL("service-worker.js", root), "utf8");

test("home screen uses a cinematic car showcase instead of a plain modal card", () => {
  assert.match(html, /class="homeShowcase"/);
  assert.match(html, /assets\/vector\/car-rally\.svg/);
  assert.match(css, /#home \.homeShowcase/);
  assert.match(css, /@keyframes homeCarFloat/);
  assert.match(css, /prefers-reduced-motion:reduce/);
});

test("race hub uses a dedicated hero banner and a vertical desktop navigation rail", () => {
  assert.match(html, /class="menuHero"/);
  assert.match(html, /class="menuHeroCar"/);
  assert.match(html, /id="startRace"/);
  assert.match(css, /grid-template-areas:"header header" "nav body" "footer footer"/);
  assert.match(css, /#select \.menuTabs\s*\{[\s\S]*?flex-direction:column/);
  assert.match(css, /#select \.menuTab\.active/);
});

test("menu navigation retains a vertical side rail on narrow mobile screens", () => {
  assert.match(css, /@media\(max-width:820px\)/);
  assert.match(css, /grid-template-columns:72px minmax\(0,1fr\)/);\n  assert.match(css, /grid-template-areas:"header header" "nav body" "footer footer"/);
  assert.match(css, /#select \.menuTabs\s*\{[\s\S]*?flex-direction:row/);
  assert.match(css, /#select \.menuBody\{overflow-y:auto/);
});

test("offline app shell precaches the menu stylesheet and keeps the release cache aligned", () => {
  assert.match(html, /href="\.\/src\/menu-visual-system\.css"/);
  assert.match(sw, /mshin-arcade-v54/);
  assert.match(sw, /\.\/src\/menu-visual-system\.css/);
});

test("pause and results screens share the cinematic game-menu visual language", () => {
  assert.match(css, /#pausePanel \.pauseScreen/);
  assert.match(css, /#pausePanel \.pauseInactive\{display:none!important\}/);
  assert.match(css, /#finish \.panel\.narrow/);
  assert.match(css, /#select \.menuTab:focus-visible/);
});
