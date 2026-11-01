import test from "node:test";
import assert from "node:assert/strict";
import { calculateRaceSteering } from "./race-test-driver.mjs";

test("race test driver counter-steers positive and negative lateral displacement", () => {
  assert.ok(calculateRaceSteering({ lateral: 120 }) < 0);
  assert.ok(calculateRaceSteering({ lateral: -120 }) > 0);
});

test("race test driver counters heading error and lateral slip symmetrically", () => {
  assert.ok(calculateRaceSteering({ yaw: .3 }) < 0);
  assert.ok(calculateRaceSteering({ yaw: -.3 }) > 0);
  assert.ok(calculateRaceSteering({ lateralVelocity: 40 }) < 0);
  assert.ok(calculateRaceSteering({ lateralVelocity: -40 }) > 0);
});

test("race test driver is bounded and ignores invalid telemetry", () => {
  assert.equal(calculateRaceSteering({ lateral: 1e9 }), -.52);
  assert.equal(calculateRaceSteering({ lateral: -1e9 }), .52);
  assert.equal(calculateRaceSteering({ lateral: NaN, yaw: Infinity }), 0);
});

test("race test driver adds feed-forward for both track curvature directions", () => {
  assert.ok(calculateRaceSteering({ trackCurvature: .001 }) > 0);
  assert.ok(calculateRaceSteering({ trackCurvature: -.001 }) < 0);
});
