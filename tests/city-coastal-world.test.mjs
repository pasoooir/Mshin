import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const coastal = await readFile(new URL("../src/city/city-coastal-world.js", import.meta.url), "utf8");
const renderer = await readFile(new URL("../src/city/city-three-renderer.js", import.meta.url), "utf8");
const atmosphere = await readFile(new URL("../src/city/city-atmosphere.js", import.meta.url), "utf8");
const worker = await readFile(new URL("../service-worker.js", import.meta.url), "utf8");
test("coastal world paints a multi-stop gradient ocean with layered waves and surf", () => {
  for (const token of ["animated-24bit-gradient-ocean", "uShallow", "uLagoon", "uCoastal", "uBlue", "uDeep", "multiscaleWaveFields", "shoreline-foam-", "natural-sandy-beach", "colorDepth:\"24-bit RGB\""]) assert.ok(coastal.includes(token), token);
  assert.match(coastal, /noise\(vWorld\.xz/);
  assert.match(coastal, /glint/);
  assert.match(coastal, /float n3=noise/);
  assert.match(coastal, /float n4=noise/);
  assert.match(coastal, /float pigment=/);
  assert.match(coastal, /createCityNaturalSoilTexture/);
  assert.match(coastal, /natural-earth-transition/);
  assert.ok(coastal.includes("beachUvs.push(i/segments*3.2, j*1.2)"));
  assert.match(coastal, /dispose\(\)/);
});
test("natural grass uses a full-color procedural texture in the live renderer", () => {
  assert.match(coastal, /createCityNaturalGrassTexture/);
  assert.match(renderer, /createCityNaturalGrassTexture/);
  assert.match(renderer, /naturalGrassTexture/);
  assert.match(renderer, /texture === grassGroundMap \? 16000 : 2048/);
  assert.match(coastal, /const size = 1536/);
  assert.match(coastal, /texture\.colorSpace = THREE\.SRGBColorSpace/);
  assert.match(coastal, /generateMipmaps = true/);
  assert.doesNotMatch(renderer, /\\\\n/);
});
test("sky uses continuous full-spectrum gradients and procedural atmosphere", () => {
  for (const token of ["uLower", "uMid", "skyNoise", "highCloudVeil", "cloudFieldLayers: 2", "continuousSkyGradient", "colorDepth: \"24-bit RGB\""]) assert.ok(atmosphere.includes(token), token);
  assert.match(renderer, /trueColorAtmosphere/);
  assert.match(atmosphere, /float cloudField=/);
  assert.match(atmosphere, /float cloudDetail=/);
  assert.match(atmosphere, /float cloudMask=/);
  assert.match(renderer, /renderer\.outputColorSpace = THREE\.SRGBColorSpace/);
  assert.match(renderer, /renderer\.toneMapping = THREE\.ACESFilmicToneMapping/);
  assert.match(renderer, /colorDepth: "24-bit RGB"/);
});
test("coastal world is mounted and cached offline", () => {
  assert.match(renderer, /createCityCoastalWorld/);
  assert.match(renderer, /scene\.add\(coastalWorld\.group\)/);
  assert.match(renderer, /coastalWorld\.update\(/);
  assert.match(worker, /city-coastal-world\.js/);
  assert.match(worker, /mshin-arcade-v83/);
});
