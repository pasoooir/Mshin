import test from "node:test";
import assert from "node:assert/strict";
import { vehicleModelHeading, screenRelativeTilt, tiltToSteer, invertSteerDirection } from "../src/vehicle-controls.js";

test("model local forward axis follows the track tangent", () => {
  assert.ok(Math.abs(vehicleModelHeading(0) - Math.PI / 2) < 1e-9);
  assert.ok(Math.abs(vehicleModelHeading(Math.PI / 2) - Math.PI) < 1e-9);
  assert.ok(Math.abs(vehicleModelHeading(0, .2) - (Math.PI / 2 + .2)) < 1e-9);
});

test("gyro tilt is mapped to the screen horizontal axis in every orientation", () => {
  assert.equal(screenRelativeTilt({ beta: 12, gamma: 7 }, 0), 7);
  assert.equal(screenRelativeTilt({ beta: 12, gamma: 7 }, 90), 12);
  assert.equal(screenRelativeTilt({ beta: 12, gamma: 7 }, 180), -7);
  assert.equal(screenRelativeTilt({ beta: 12, gamma: 7 }, 270), -12);
  assert.equal(screenRelativeTilt({ beta: null, gamma: 7 }, 0), null);
});

test("gyro steering has a dead zone and saturates smoothly", () => {
  assert.equal(tiltToSteer(1), 0);
  assert.equal(tiltToSteer(-1), 0);
  assert.ok(tiltToSteer(10) > 0);
  assert.ok(tiltToSteer(-10) < 0);
  assert.equal(tiltToSteer(90), 1);
  assert.equal(tiltToSteer(-90), -1);
});


test("gyro steering remains bounded and responds strongly to small calibrated tilts", () => {
  assert.ok(tiltToSteer(6, 1.45) > tiltToSteer(6, 1));
  assert.ok(tiltToSteer(-6, 1.45) < tiltToSteer(-6, 1));
  assert.equal(tiltToSteer(90, 1.45), 1);
  assert.equal(tiltToSteer(-90, 1.45), -1);
});


test("screen-left and screen-right steering are mapped to the corrected vehicle direction", () => {
  assert.equal(invertSteerDirection(-1), 1);
  assert.equal(invertSteerDirection(1), -1);
  assert.equal(invertSteerDirection(0), 0);
  assert.equal(invertSteerDirection(4), -1);
  assert.equal(invertSteerDirection(-4), 1);
  assert.equal(invertSteerDirection(Number.NaN), 0);
});
