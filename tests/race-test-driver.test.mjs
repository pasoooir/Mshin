import test from "node:test";
import assert from "node:assert/strict";
import { calculateRaceSteering, chooseRaceTargetLateral } from "./race-test-driver.mjs";

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
  assert.equal(calculateRaceSteering({ lateral: 1e9 }), -0.85);
  assert.equal(calculateRaceSteering({ lateral: -1e9 }), 0.85);
  assert.equal(calculateRaceSteering({ lateral: NaN, yaw: Infinity, lateralVelocity: undefined }), 0);
});

test("race test driver can hold a deliberate pickup lane target", () => {
  assert.equal(calculateRaceSteering({ lateral: 30, targetLateral: 30 }), 0);
  assert.ok(calculateRaceSteering({ lateral: 140, targetLateral: 30 }) < 0);
  assert.ok(calculateRaceSteering({ lateral: -100, targetLateral: 30 }) > 0);
});

test("race test driver adds steering feed-forward for positive and negative track curvature", () => {
  assert.ok(calculateRaceSteering({ trackCurvature: 0.001 }) > 0);
  assert.ok(calculateRaceSteering({ trackCurvature: -0.001 }) < 0);
});

test("race test driver keeps its lane when traffic is not nearby", () => {
  assert.equal(chooseRaceTargetLateral({ trackT: 0, currentTarget: 0, traffic: [{ distance: 2, lateral: 0 }] }), 0);
});

test("race test driver moves away from a nearby vehicle", () => {
  const target = chooseRaceTargetLateral({ trackT: 0, currentTarget: 0, traffic: [{ distance: 0.02, lateral: 0 }] });
  assert.ok(Math.abs(target) >= 90);
});

test("race test driver ignores invalid traffic telemetry", () => {
  assert.equal(chooseRaceTargetLateral({ trackT: 0, currentTarget: 0, traffic: [{ distance: NaN, lateral: 0 }] }), 0);
});
