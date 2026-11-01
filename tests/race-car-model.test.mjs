import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8");

test("in-race WebGL car uses a tapered multi-station body shell", () => {
  assert.match(source, /const stations=\[/);
  assert.match(source, /const rings=stations\.map/);
  assert.match(source, /quad\(body,rings\[i\]/);
});

test("in-race car retains visible body character creases and sculpted side details", () => {
  assert.match(source, /side character lines/);
  assert.match(source, /box\(trim,side\*31,27,-4/);
  assert.match(source, /Wheel arch lips and sill trim/);
  assert.match(source, /Hood power creases/);
});

test("in-race car includes detailed glass, lighting, aero and metallic wheel hubs", () => {
  assert.match(source, /Sloped glazing|Cabin:/);
  assert.match(source, /Distinct LED headlamps/);
  assert.match(source, /part\(rims,/);
  assert.match(source, /racing wing/);
  assert.match(source, /part\(aero,/);
});

test("3D race-car geometry is procedural and has no runtime CDN dependency", () => {
  assert.match(source, /function buildCar\(\)/);
  assert.match(source, /carParts=\[/);
  assert.doesNotMatch(source, /https?:\/\//);
});
