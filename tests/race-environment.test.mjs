import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const renderer = await readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8");

test("race environment builds continuous ground beyond both road shoulders", () => {
  assert.match(renderer, /Continuous terrain extends well beyond the shoulders/);
  assert.match(renderer, /point\(fa,-1500,-\.18\)/);
  assert.match(renderer, /point\(fa,1500,-\.18\)/);
  assert.match(renderer, /quad\(groundTris,terrainL0,terrainL1,terrainR1,terrainR0\)/);
});

test("roadside trees use layered foliage rather than a single flat cone", () => {
  assert.match(renderer, /Three overlapping foliage tiers/);
  assert.match(renderer, /for\(let tier=0;tier<3;tier\+\+\)/);
  assert.match(renderer, /tierRadius=rad\*\(1-tier\*\.2\)/);
});
