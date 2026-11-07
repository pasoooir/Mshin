import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const coastal = await readFile(new URL("../src/city/city-coastal-world.js", import.meta.url), "utf8");
const renderer = await readFile(new URL("../src/city/city-three-renderer.js", import.meta.url), "utf8");
const worker = await readFile(new URL("../service-worker.js", import.meta.url), "utf8");
test("coastal world paints a multi-stop gradient ocean with layered waves and surf", () => {
  for (const token of ["animated-gradient-ocean", "uShallow", "uLagoon", "uCoastal", "uDeep", "multiscaleWaveFields", "shoreline-foam-", "natural-sandy-beach"]) assert.ok(coastal.includes(token), token);
  assert.match(coastal, /noise\(vWorld\.xz/);
  assert.match(coastal, /glint/);
  assert.match(coastal, /dispose\(\)/);
});
test("natural grass uses a full-color procedural texture in the live renderer", () => {
  assert.match(coastal, /createCityNaturalGrassTexture/);
  assert.match(renderer, /createCityNaturalGrassTexture/);
  assert.match(renderer, /naturalGrassTexture/);
  assert.match(renderer, /texture === grassGroundMap \? 16000 : 2048/);
  assert.doesNotMatch(renderer, /\\\\n/);
});
test("coastal world is mounted and cached offline", () => {
  assert.match(renderer, /createCityCoastalWorld/);
  assert.match(renderer, /scene\.add\(coastalWorld\.group\)/);
  assert.match(renderer, /coastalWorld\.update\(/);
  assert.match(worker, /city-coastal-world\.js/);
  assert.match(worker, /mshin-arcade-v82/);
});
