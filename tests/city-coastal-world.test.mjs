import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const coastal = await readFile(new URL("../src/city/city-coastal-world.js", import.meta.url), "utf8");
const renderer = await readFile(new URL("../src/city/city-three-renderer.js", import.meta.url), "utf8");
const worker = await readFile(new URL("../service-worker.js", import.meta.url), "utf8");

test("coastal world provides a procedural beach and animated real 3D ocean", () => {
  assert.match(coastal, /natural-sandy-beach/);
  assert.match(coastal, /animated-turquoise-ocean/);
  assert.match(coastal, /ShaderMaterial/);
  assert.match(coastal, /uTime/);
  assert.match(coastal, /shoreline-surf/);
  assert.match(coastal, /dispose\(\)/);
});

test("coastal world is mounted in the live city renderer and cached offline", () => {
  assert.match(renderer, /createCityCoastalWorld/);
  assert.match(renderer, /scene\.add\(coastalWorld\.group\)/);
  assert.match(renderer, /coastalWorld\.update\(/);
  assert.match(renderer, /\.\.\.coastalWorld\.getStats\(\)/);
  assert.match(worker, /city-coastal-world\.js/);
  assert.match(worker, /mshin-arcade-v82/);
});
