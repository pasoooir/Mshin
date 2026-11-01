import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8");

test("procedural 3D scene stays within a bounded first-build geometry budget", () => {
  assert.match(source, /const segments=mobile\?84:240,half=180;/,
    "desktop track tessellation is capped at 240 segments");
  assert.match(source, /i<(mobile\?18:48);i\+\+/,
    "desktop tree instances are capped at 48");
  assert.match(source, /i\+=\(mobile\?18:6\)/,
    "trackside rail sampling is bounded on desktop");
  assert.match(source, /i<(mobile\?10:36);i\+\+/,
    "desktop crowd instances are capped at 36");
});

test("the scene keeps its full road width while reducing mesh density", () => {
  assert.match(source, /const segments=mobile\?84:240,half=180;/);
  assert.match(source, /const half=180|half=180/);
  assert.match(source, /quad\(roadTris,l0,l1,r1,r0\)/,
    "the asphalt remains a continuous closed road ribbon");
});
