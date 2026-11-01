import test from "node:test";
import assert from "node:assert/strict";
import { stepVehicleDynamics } from "../src/vehicle-dynamics.js";

const frameAt = t => ({
  p: { x: Math.cos(t) * 1000, y: Math.sin(t) * 700 },
  nx: -Math.cos(t),
  ny: -Math.sin(t),
  angle: t + Math.PI / 2
});
const tuning = { dt: 1 / 60, grip: 1, mass: 1250, acceleration: 280, maxSpeed: 390 };

function vehicle(overrides = {}) {
  return { t: 0, lateral: 0, speed: 0, lateralVelocity: 0, yaw: 0, yawRate: 0, ...overrides };
}

test("vehicle remains stationary without throttle or residual velocity", () => {
  const car = vehicle();
  for (let i = 0; i < 120; i++) stepVehicleDynamics(car, { throttle: false, brake: false, steer: 0 }, tuning, frameAt);
  assert.equal(car.speed, 0);
  assert.equal(car.t, 0);
  assert.equal(car.lateral, 0);
});

test("throttle accelerates progressively and respects the speed cap", () => {
  const car = vehicle();
  for (let i = 0; i < 60; i++) stepVehicleDynamics(car, { throttle: true, brake: false, steer: 0 }, tuning, frameAt);
  assert.ok(car.speed > 100);
  assert.ok(car.speed <= tuning.maxSpeed);
  assert.ok(car.t > 0);
});

test("coasting and braking reduce longitudinal speed", () => {
  const coasting = vehicle({ speed: 180 });
  stepVehicleDynamics(coasting, { throttle: false, brake: false, steer: 0 }, tuning, frameAt);
  assert.ok(coasting.speed < 180);
  const braking = vehicle({ speed: 180 });
  stepVehicleDynamics(braking, { throttle: false, brake: true, steer: 0 }, tuning, frameAt);
  assert.ok(braking.speed < coasting.speed);
});

test("steering changes the world-space trajectory instead of locking progress to the track tangent", () => {
  const straightFrame = t => ({
    p: { x: t * 1000, y: 0 }, nx: 0, ny: 1, angle: 0
  });
  const car = vehicle({ speed: 180 });
  for (let i = 0; i < 60; i++) stepVehicleDynamics(car, { throttle: true, brake: false, steer: 1 }, tuning, straightFrame);
  assert.ok(car.lateral > 10, "steering should move the car away from the track centreline");
  assert.ok(Math.abs(car.yaw) > 0.05, "steering should rotate the vehicle body");
  assert.ok(car.t > 0, "the car should retain forward progress while cornering");
});

test("reduced grip limits cornering force and increases slip", () => {
  const dry = vehicle({ speed: 260 });
  const wet = vehicle({ speed: 260 });
  let dryResult, wetResult;
  for (let i = 0; i < 30; i++) {
    dryResult = stepVehicleDynamics(dry, { throttle: true, brake: false, steer: 1 }, { ...tuning, grip: 1.25 }, frameAt);
    wetResult = stepVehicleDynamics(wet, { throttle: true, brake: false, steer: 1 }, { ...tuning, grip: 0.45 }, frameAt);
  }
  assert.ok(wetResult.tire.tireCapacity < dryResult.tire.tireCapacity);
  assert.ok(Math.abs(wet.yawRate) <= 1.4);
  assert.ok(Number.isFinite(wet.lateralVelocity));
});

test("fixed-step integration is deterministic for equal simulation time", () => {
  const a = vehicle(), b = vehicle();
  for (let i = 0; i < 120; i++) stepVehicleDynamics(a, { throttle: true, brake: false, steer: 0.35 }, tuning, frameAt);
  for (let i = 0; i < 60; i++) {
    stepVehicleDynamics(b, { throttle: true, brake: false, steer: 0.35 }, { ...tuning, dt: 1 / 30 }, frameAt);
  }
  assert.ok(Math.abs(a.speed - b.speed) < 0.01);
  assert.ok(Math.abs(a.lateral - b.lateral) < 2.5);
});
