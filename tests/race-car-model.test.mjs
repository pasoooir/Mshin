import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8");

test("3D race-car body shells use tapered multi-station geometry", () => {
  assert.match(source, /const stations=\[/);
  assert.match(source, /const rings=stations\.map/);
  assert.match(source, /quad\(body,rings\[i\]/);
});

test("race-car flanks retain body creases, wheel-arch lips and side sills", () => {
  assert.match(source, /box\(trim,side\*31\*w,27\*h,-4\*l/);
  assert.match(source, /p\.wheelRadius\*1\.9/);
  assert.match(source, /box\(trim,side\*29\*w,13\*h,0/);
  assert.match(source, /for\(const side of \[-1,1\]\)box\(trim,side\*10\*w/);
});

test("race cars include scaled cabins, glazing, aero, lamps and metallic wheel hubs", () => {
  assert.match(source, /const baseY=30\*p\.cabinY,roofY=baseY\+17\*p\.cabinHeight/);
  assert.match(source, /quad\(glass,\[-lowerW\+3,baseY\+2,frontZ-1\]/);
  assert.match(source, /if\(p\.wing>\.2\)/);\n  assert.match(source, /quad\(body,\[-lowerW,baseY,rearZ\]/);
  assert.match(source, /box\(lights,-17\*w,25\*h/);
  assert.match(source, /part\(rims,/);
});

test("ten vehicle profiles are generated locally without a runtime model CDN", () => {
  assert.match(source, /function buildCar\(id="rally"\)/);
  assert.match(source, /const VEHICLE_SHAPES=\{/);
  assert.match(source, /"ai-formula"/);
  assert.match(source, /"ai-pickup"/);
  assert.match(source, /"ai-rallycross"/);
  assert.match(source, /"ai-touring"/);
  assert.match(source, /"ai-prototype"/);
  assert.doesNotMatch(source, /https?:\/\//);
});
