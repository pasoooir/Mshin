import test from 'node:test';
import assert from 'node:assert/strict';
import { createRaceState, normalizeJoystick, resolveTrackCollision, stepCar, updateRace } from '../.test-build/src/cocos-core.js';

test('joystick clamps diagonal displacement to unit radius', () => {
 const v = normalizeJoystick(100, 100, 50); assert.ok(Math.hypot(v.x, v.y) <= 1.000001); assert.ok(v.x > 0 && v.y > 0);
});
test('invalid joystick radius safely returns neutral input', () => assert.deepEqual(normalizeJoystick(20, 20, 0), { x: 0, y: 0 }));
test('throttle accelerates and brake reduces speed', () => {
 const car = { x: 0, y: 0, heading: 0, speed: 0 }; stepCar(car, { steer: 0, throttle: true, brake: false }, 0.05);
 assert.ok(car.speed > 0); const before = car.speed; stepCar(car, { steer: 0, throttle: false, brake: true }, 0.05); assert.ok(car.speed < before);
});
test('frame spike is capped and steering remains bounded', () => {
 const car = { x: 0, y: 0, heading: 0, speed: 100 }; stepCar(car, { steer: 50, throttle: true, brake: false }, 2);
 assert.ok(Math.abs(car.heading) < 0.2); assert.ok(car.speed <= 360);
});
test('track collision corrects car back onto playable ring', () => {
 const car = { x: 900, y: 0, heading: 0, speed: 100 }; assert.equal(resolveTrackCollision(car), true);
 const r = Math.hypot(car.x / 420, car.y / 260); assert.ok(r <= 1.18 && r >= 0.82); assert.ok(car.speed < 0);
});
test('race increments lap on finish-line wrap and finishes at target', () => {
 const race = createRaceState(); race.previousProgress = 0.95;
 updateRace(race, 420 * Math.cos(0.1), 260 * Math.sin(0.1), 1, 1);
 assert.equal(race.lap, 1); assert.equal(race.finished, true); assert.equal(race.elapsedSeconds, 1);
});
