import test from "node:test";
import assert from "node:assert/strict";
import { calculateRaceSteering } from "./race-test-driver.mjs";

test("race test driver counter-steers positive lateral displacement", () => {
  assert.ok(calculateRaceSteering({ lateral: 120 }) < 0);
});

test("race test driver steers back from negative lateral displacement", () => {
  assert.ok(calculateRaceSteering({ lateral: -120 }) > 0);
});

test("race test driver counters positive and negative heading error symmetrically", () => {
  assert.ok(calculateRaceSteering({ yaw: 0.3 }) < 0);
  assert.ok(calculateRaceSteering({ yaw: -0.3 }) > 0);
});

test("race test driver damps lateral velocity before the car leaves the track", () => {
  assert.ok(calculateRaceSteering({ lateralVelocity: 40 }) < 0);
  assert.ok(calculateRaceSteering({ lateralVelocity: -40 }) > 0);
});

test("race test driver output is bounded and ignores invalid telemetry", () => {
  assert.equal(calculateRaceSteering({ lateral: 1e9 }), -0.9);
  assert.equal(calculateRaceSteering({ lateral: -1e9 }), 0.9);
  assert.equal(calculateRaceSteering({ lateral: NaN, yaw: Infinity, lateralVelocity: undefined }), 0);
});
