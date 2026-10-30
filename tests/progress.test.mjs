import test from "node:test";
import assert from "node:assert/strict";
import { completeProgress, freshProgress, isStageSelectable, normalizeProgress } from "../.test-build/src/progress.js";

test("fresh progress starts at stage one with no records", () => {
  assert.deepEqual(freshProgress(), { unlockedStage: 1, completed: [], bestTimes: {} });
});
test("normalization removes invalid and duplicate completion ids", () => {
  const value = normalizeProgress({ unlockedStage: 99, completed: [1, 1, 0, 2, 51, "3", 4.5], bestTimes: { "1": 75, "2": -1, "3": "40", "51": 20, "4": Infinity } });
  assert.deepEqual(value, { unlockedStage: 50, completed: [1, 2], bestTimes: { "1": 75 } });
});
test("malformed or array-shaped save data safely resets", () => {
  assert.deepEqual(normalizeProgress(null), freshProgress());
  assert.deepEqual(normalizeProgress([]), freshProgress());
  assert.deepEqual(normalizeProgress("invalid"), freshProgress());
});
test("all 50 stage ids remain selectable while invalid ids are rejected", () => {
  for (let id = 1; id <= 50; id++) assert.equal(isStageSelectable(id), true);
  for (const id of [0, 51, -1, 1.5, NaN]) assert.equal(isStageSelectable(id), false);
});
test("completing a stage records completion and best time", () => {
  const progress = completeProgress(freshProgress(), 7, 62.4);
  assert.deepEqual(progress.completed, [7]);
  assert.equal(progress.unlockedStage, 8);
  assert.equal(progress.bestTimes["7"], 62.4);
});
test("completion is idempotent and only replaces a best time with a faster time", () => {
  const first = completeProgress(freshProgress(), 3, 80);
  const slower = completeProgress(first, 3, 90);
  assert.deepEqual(slower.completed, [3]);
  assert.equal(slower.bestTimes["3"], 80);
  assert.equal(completeProgress(slower, 3, 72).bestTimes["3"], 72);
});
test("invalid stage ids and elapsed times cannot corrupt saved records", () => {
  for (const id of [0, 51, 1.2]) assert.throws(() => completeProgress(freshProgress(), id, 10), RangeError);
  for (const time of [0, -1, NaN, Infinity]) assert.throws(() => completeProgress(freshProgress(), 1, time), RangeError);
});
test("completing the final stage keeps the unlock marker within the catalog", () => {
  const progress = completeProgress(freshProgress(), 50, 123.5);
  assert.equal(progress.unlockedStage, 50);
  assert.deepEqual(progress.completed, [50]);
});
