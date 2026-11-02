import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

test("race environment builds a complete local 3D roadside scene", async () => {
  const source = await readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8");
  for (const feature of [
    "skyTris", "cloudTris", "sunTris", "landscape",
    "treeShadows", "buildingShadows", "houses", "shops",
    "windows", "crowdBodies", "petBodies", "petHeads", "petLegs",
    "state.environmentCounts"
  ]) assert.ok(source.includes(feature), "missing environment feature: " + feature);
  assert.match(source, /const treeCount=mobile\?18:52/);
  assert.match(source, /const buildingCount=mobile\?8:22/);
  assert.match(source, /const shopCount=mobile\?3:7/);
  assert.match(source, /const spectatorCount=mobile\?12:44/);
  assert.match(source, /const petCount=mobile\?3:9/);
  assert.match(source, /sphere\(skyTris,0,0,0,5600,3000,5600/);
  assert.match(source, /box\(trees,x,base\+19,z,8,38,8\)/);
});
