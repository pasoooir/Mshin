import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8");

test("race terrain extends well beyond both track shoulders", () => {
  assert.match(source, /const terrainExtent=1500/);
  assert.match(source, /point\(fa,-terrainExtent,-\.18\)/);
  assert.match(source, /point\(fa,terrainExtent,-\.18\)/);
  assert.match(source, /quad\(groundTris,outerL,outerL1,outerR1,outerR\)/);
});

test("roadside foliage uses three overlapping ten-face canopy tiers", () => {
  assert.match(source, /for\(let tier=0;tier<3;tier\+\+\)/);
  assert.match(source, /tierRadius=rad\*\(1-tier\*\.2\)/);
  assert.match(source, /for\(let j=0;j<10;j\+\+\)/);
  assert.match(source, /trees\.push\(\.\.\.foliage\)/);
});

test("mobile and desktop retain existing progressive track segment budgets", () => {
  assert.match(source, /const segments=mobile\?84:240/);
  assert.match(source, /for\(let i=0;i<\(mobile\?18:48\);i\+\+\)/);
});
