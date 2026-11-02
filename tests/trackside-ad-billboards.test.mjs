import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const renderer = await readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8");

test("trackside sponsor boards are generated as visible 3D roadside structures", () => {
  assert.match(renderer, /Trackside advertising inventory/);
  assert.match(renderer, /const billboardCount=mobile\?8:20/);
  assert.match(renderer, /quad\(billboardFaces,a,b,c,d\)/);
  assert.match(renderer, /\[billboardPosts,"#303d4b"\]/, "billboard posts must use the bounded GPU upload queue");
  assert.match(renderer, /\[billboardFaces,"#17324b"\]/, "billboard faces must use the bounded GPU upload queue");
});

test("billboard locations expose stable world-scoped ad inventory metadata", () => {
  assert.match(renderer, /world-\$\{snapshot\.world\|\|0\}-trackside-/);
  assert.match(renderer, /format:"trackside-3d"/);
  assert.match(renderer, /available:true,creative:null/);
  assert.match(renderer, /state\.adSlots=billboardSlots/);
});

test("mobile billboard count stays bounded below desktop count", () => {
  assert.match(renderer, /const billboardCount=mobile\?8:20/);
});
