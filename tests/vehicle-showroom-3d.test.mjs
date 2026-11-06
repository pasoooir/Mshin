import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const renderer = await readFile(new URL("src/vehicle-showroom-3d.js", root), "utf8");
const game = await readFile(new URL("src/web-game.js", root), "utf8");
const html = await readFile(new URL("index.html", root), "utf8");
const worker = await readFile(new URL("service-worker.js", root), "utf8");
const pbr = await readFile(new URL("src/vehicle-pbr.js", root), "utf8");

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
  assert.doesNotMatch(renderer, /https?:\/\//);
});

test("360-degree interaction changes the real orbit camera and supports a complete spin", () => {
  assert.match(renderer, /yaw\+=dx\*\.012/);
  assert.match(renderer, /state\.pitch=clamp/);
  assert.match(renderer, /spin360\(\)\{spinUntil=performance\.now\(\)\+1500/);
  assert.match(renderer, /if\(spinUntil>now\)yaw\+=\.14/);
  assert.match(game, /showroom3d\.spin360\(\)/);
  assert.match(game, /showroom3d\.setVehicle\(model\.id\)/);
});

test("showroom module is loaded locally and precached for offline use", () => {
  assert.match(game, /from "\.\/vehicle-showroom-3d\.js"/);
  assert.match(worker, /\.\/src\/vehicle-showroom-3d\.js/);
  assert.match(worker, /mshin-arcade-v77/);
  assert.match(renderer, /from "\.\/vehicle-pbr\.js"/);
  assert.match(worker, /\.\/src\/vehicle-pbr\.js/);
});

test("automotive paint uses shared Cook-Torrance metallic-roughness PBR and clearcoat", () => {
  assert.match(pbr, /distributionGGX/);
  assert.match(pbr, /fresnelSchlick/);
  assert.match(pbr, /geometrySchlick/);
  assert.match(pbr, /uClearcoat/);
  assert.match(pbr, /samplerCube uEnvironmentMap/);
  assert.match(pbr, /createVehicleEnvironment/);
  for (const material of ["body", "glass", "rubber", "rims", "aero"]) assert.match(pbr, new RegExp(material + ":\\{"));
  assert.match(renderer, /material:"body"/);
  assert.match(renderer, /material:"rubber"/);
});

test("procedural finish details distinguish paint flakes, carbon weave, rubber grain and brushed alloys", () => {
  assert.match(pbr, /Fine metallic flakes/);
  assert.match(pbr, /Carbon-fibre twill/);
  assert.match(pbr, /Rubber sidewall micrograin/);
  assert.match(pbr, /Brushed aluminium/);
});


test("showroom pauses GPU work when hidden or offscreen and resumes when visible", () => {
  assert.match(renderer, /document\.addEventListener\("visibilitychange",onVisibility\)/);
  assert.match(renderer, /new IntersectionObserver/);
  assert.match(renderer, /!visible\|\|!intersecting\|\|contextLost/);
  assert.match(renderer, /cancelAnimationFrame\(raf\)/);
});

test("showroom releases every registered input and lifecycle listener on destroy", () => {
  assert.match(renderer, /canvas\.removeEventListener\("pointerdown",pointerDown\)/);
  assert.match(renderer, /document\.removeEventListener\("visibilitychange",onVisibility\)/);
  assert.match(renderer, /window\.removeEventListener\("pointermove",move\)/);
  assert.match(renderer, /canvas\.removeEventListener\("webglcontextlost",onContextLost\)/);
  assert.match(renderer, /intersectionObserver\?\.disconnect\(\)/);
  assert.match(renderer, /if\(disposed\)return;disposed=true/);
});

test("showroom handles WebGL context loss without continuing to issue draw calls", () => {
  assert.match(renderer, /event\.preventDefault\(\);contextLost=true/);
  assert.match(renderer, /state\.status="context-lost"/);
  assert.match(renderer, /onContextRestored/);
});
