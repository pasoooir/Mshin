import test from "node:test";
import assert from "node:assert/strict";
import { vehicleModelHeading, screenRelativeTilt, tiltToSteer, joystickDeltaToSteer, screenTiltToSteer } from "../src/vehicle-controls.js";

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

test("joystick right and left map to the matching world-space turn direction", () => {
  assert.ok(joystickDeltaToSteer(40, 50) < 0, "dragging right must turn right in world space");
  assert.ok(joystickDeltaToSteer(-40, 50) > 0, "dragging left must turn left in world space");
  assert.equal(joystickDeltaToSteer(2, 50), 0, "small joystick noise must remain inside the dead zone");
  assert.equal(joystickDeltaToSteer(40, 0), 0, "invalid joystick travel must not create steering");
});

test("rightward gyro tilt maps to the same direction as rightward joystick input", () => {
  assert.ok(screenTiltToSteer(10) < 0);
  assert.ok(screenTiltToSteer(-10) > 0);
  assert.equal(screenTiltToSteer(0), 0);
});
