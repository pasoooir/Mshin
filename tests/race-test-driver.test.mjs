import test from "node:test";
import assert from "node:assert/strict";
import { calculateRaceSteering } from "./race-test-driver.mjs";
test("closed-loop smoke steering counter-steers lateral displacement and yaw", () => {
  assert.ok(calculateRaceSteering({ lateral: 120 }) < 0);
  assert.ok(calculateRaceSteering({ lateral: -120 }) > 0);
  assert.ok(calculateRaceSteering({ yaw: .3 }) < 0);
  assert.ok(calculateRaceSteering({ yaw: -.3 }) > 0);
});
test("closed-loop smoke steering damps lateral slip and follows track curvature", () => {
  assert.ok(calculateRaceSteering({ lateralVelocity: 40 }) < 0);
  assert.ok(calculateRaceSteering({ lateralVelocity: -40 }) > 0);
  assert.ok(calculateRaceSteering({ trackCurvature: .001 }) > 0);
  assert.ok(calculateRaceSteering({ trackCurvature: -.001 }) < 0);
});
test("closed-loop smoke steering is bounded and tolerates invalid telemetry", () => {
  assert.equal(calculateRaceSteering({ lateral: 1e9 }), -.52);
  assert.equal(calculateRaceSteering({ lateral: -1e9 }), .52);
  assert.equal(calculateRaceSteering({ lateral: NaN, yaw: Infinity }), 0);
});
