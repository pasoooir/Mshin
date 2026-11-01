import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/vehicle-showroom-3d.js", import.meta.url), "utf8");
const raceRenderer = await readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8");
const pbr = await readFile(new URL("../src/vehicle-pbr.js", import.meta.url), "utf8");

test("3D race-car body shells use tapered multi-station geometry", () => {
  assert.match(source, /const stations=\[/);
  assert.match(source, /const rings=stations\.map/);
  assert.match(source, /quad\(body,rings\[i\]/);
});

test("race-car flanks retain body creases, wheel-arch lips and side sills", () => {
  assert.match(source, /Deep wheel arches, flared fenders/);
  assert.match(source, /box\(trim,side\*35\*w,25\*h,-2\*L/);
  assert.match(source, /box\(trim,side\*39\*w,13\*h,0/);
});

test("race cars include scaled cabins, glazing, aero, lamps and metallic wheel hubs", () => {
  assert.match(source, /const base=32\*p\.cabin,roof=base\+20\*p\.cabin/);
  assert.match(source, /quad\(glass,\[-low\+2,base\+2,fz-2\]/);
  assert.match(source, /if\(p\.style!=="electric"\)/);
  assert.match(source, /quad\(body,\[low,base,rz\]/);
  assert.match(source, /box\(lights,side\*21\*w,24\*h/);
  assert.match(source, /vertices:rims,paint:"#dce6ed"/);
});

test("ten vehicle profiles are generated locally without a runtime model CDN", () => {
  assert.match(source, /function buildVehicleGeometry\(id\)/);
  assert.match(raceRenderer, /buildVehicleGeometry\(id\)\.map/);
  assert.match(source, /const PROFILES=\{/);
  assert.match(source, /"ai-formula"/);
  assert.match(source, /"ai-pickup"/);
  assert.match(source, /"ai-rallycross"/);
  assert.match(source, /"ai-touring"/);
  assert.match(source, /"ai-prototype"/);
  assert.doesNotMatch(source, /https?:\/\//);
});

test("race and showroom share PBR materials, environment reflections and automotive clearcoat", () => {
  assert.match(raceRenderer, /PBR_FRAGMENT/);
  assert.match(raceRenderer, /createVehicleEnvironment/);
  assert.match(raceRenderer, /uniforms\.roughness/);
  assert.match(raceRenderer, /item\.material/);
  assert.match(pbr, /distributionGGX/);
  assert.match(pbr, /textureCube\(uEnvironmentMap,R\)/);
  assert.match(pbr, /clearcoat/);
});
