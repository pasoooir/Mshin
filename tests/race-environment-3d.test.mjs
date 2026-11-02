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
  for (const budget of [
    "treeCount=mobile?18:48",
    "buildingCount=mobile?8:22",
    "shopCount=mobile?3:7",
    "spectatorCount=mobile?10:36",
    "petCount=mobile?3:9"
  ]) assert.ok(source.includes(budget), "missing mobile/desktop scene budget: " + budget);
  assert.ok(source.includes("sphere(skyTris,0,0,0,5600,3000,5600"));
  assert.ok(source.includes("box(trees,x,base+19,z,8,38,8)"));
});
