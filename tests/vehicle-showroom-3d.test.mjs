import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const renderer = await readFile(new URL("src/vehicle-showroom-3d.js", root), "utf8");
const game = await readFile(new URL("src/web-game.js", root), "utf8");
const html = await readFile(new URL("index.html", root), "utf8");
const worker = await readFile(new URL("service-worker.js", root), "utf8");

test("garage uses a real WebGL canvas rather than a perspective-transformed flat SVG", () => {
  assert.match(html, /<canvas class="showroomVehicle" id="showroomVehicle"/);
  assert.doesNotMatch(html, /showroomCarImage/);
  assert.match(renderer, /canvas\.getContext\("webgl"/);
  assert.match(renderer, /function buildVehicle\(gl,id\)/);
});

test("showroom builds five distinct locally generated 3D race-car profiles", () => {
  for (const id of ["rally", "comet", "lynx", "thunder", "raptor"]) {
    assert.match(renderer, new RegExp(id + ":\\{paint:"));
  }
  assert.match(renderer, /cylinderX\(rubber/);
  assert.match(renderer, /wheel arches, flared fenders/);
  assert.match(renderer, /multi-spoke alloys/);
  assert.doesNotMatch(renderer, /https?:\\/\\//);
});

test("360-degree interaction changes the real orbit camera and supports a complete spin", () => {
  assert.match(renderer, /yaw\+=dx\*\.012/);
  assert.match(renderer, /state\.pitch=clamp/);
  assert.match(renderer, /spin360\(\)\{spinUntil=performance\.now\(\)\+1500/);
  assert.match(game, /showroom3d\.spin360\(\)/);
  assert.match(game, /showroom3d\.setVehicle\(model\.id\)/);
});

test("showroom module is loaded locally and precached for offline use", () => {
  assert.match(game, /from "\.\/vehicle-showroom-3d\.js"/);
  assert.match(worker, /\.\/src\/vehicle-showroom-3d\.js/);
  assert.match(worker, /mshin-arcade-v47/);
});
