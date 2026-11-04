import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = process.cwd();

test("city reference HUD stylesheet is linked and precached", async () => {
  const html = await readFile(resolve(root, "city.html"), "utf8");
  const sw = await readFile(resolve(root, "service-worker.js"), "utf8");
  const css = await readFile(resolve(root, "src/city/city-reference-hud.css"), "utf8");
  assert.match(html, /city-reference-hud\.css/);
  assert.match(sw, /\.\/src\/city\/city-reference-hud\.css/);
  assert.match(css, /\.cityTool:focus-visible/);
  assert.match(css, /min-height:48px|min-height: 48px/);
});

test("grass PBR material contains deterministic meadow variation and rough surface", async () => {
  const pbr = await readFile(resolve(root, "src/city/city-pbr-textures.js"), "utf8");
  assert.match(pbr, /kind === "grass"/);
  assert.match(pbr, /bezierCurveTo/);
  assert.match(pbr, /7800/);
  assert.match(pbr, /seed >>> 0/);
  assert.match(pbr, /roughnessMap/);
});
