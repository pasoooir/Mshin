import test from 'node:test';
import assert from 'node:assert/strict';
import { createRaceState, normalizeJoystick, resolveTrackCollision, stepCar, updateRace } from '../.test-build/src/cocos-core.js';

test('joystick clamps diagonal displacement to unit radius', () => {
 const v = normalizeJoystick(100, 100, 50); assert.ok(Math.hypot(v.x, v.y) <= 1.000001); assert.ok(v.x > 0 && v.y > 0);
});
test('invalid joystick radius or coordinates safely returns neutral input', () => {
 assert.deepEqual(normalizeJoystick(20, 20, 0), { x: 0, y: 0 });
 assert.deepEqual(normalizeJoystick(Number.NaN, 20, 50), { x: 0, y: 0 });
});
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
test('race increments lap on forward finish-line wrap and finishes at target', () => {
 const race = createRaceState(); race.previousProgress = 0.95;
 updateRace(race, 420 * Math.cos(0.1), 260 * Math.sin(0.1), 0.05, 1);
 assert.equal(race.lap, 1); assert.equal(race.finished, true); assert.equal(race.elapsedSeconds, 0.05);
});
test('idle and brake never push a stopped car into reverse',()=>{
 const idle={x:0,y:0,heading:0,speed:0};
 stepCar(idle,{steer:0,throttle:false,brake:false},0.05); assert.equal(idle.speed,0);
 stepCar(idle,{steer:0,throttle:false,brake:true},0.05); assert.equal(idle.speed,0);
});
test('low-grip world reduces steering response',()=>{
 const normal={x:0,y:0,heading:0,speed:180},ice={x:0,y:0,heading:0,speed:180};
 stepCar(normal,{steer:1,throttle:false,brake:false,grip:1},0.05);
 stepCar(ice,{steer:1,throttle:false,brake:false,grip:0.68},0.05);
 assert.ok(Math.abs(ice.heading)<Math.abs(normal.heading));
});
test('off-road driving has lower acceleration, speed ceiling and stronger coasting drag',()=>{
 const road={x:0,y:0,heading:0,speed:200},grass={x:0,y:0,heading:0,speed:200};
 stepCar(road,{steer:0,throttle:true,brake:false},0.05);
 stepCar(grass,{steer:0,throttle:true,brake:false,offRoad:true},0.05); assert.ok(grass.speed<road.speed);
 const fast={x:0,y:0,heading:0,speed:350}; stepCar(fast,{steer:0,throttle:true,brake:false,offRoad:true},0.05); assert.ok(fast.speed<=220);
 const coast={x:0,y:0,heading:0,speed:100}; stepCar(coast,{steer:0,throttle:false,brake:false,offRoad:true},0.05); assert.ok(coast.speed<100-95*0.05);
});
test('physics and race clock both cap long frame spikes to one simulation step',()=>{
 const car={x:0,y:0,heading:0,speed:0},race=createRaceState();
 stepCar(car,{steer:0,throttle:true,brake:false},3); updateRace(race,420,0,3,3);
 assert.ok(car.speed<=306*0.05+1e-9); assert.equal(race.elapsedSeconds,0.05);
});
test('invalid frame delta and steering input do not poison car or race state',()=>{
 const car={x:0,y:0,heading:0,speed:10},race=createRaceState();
 stepCar(car,{steer:Number.NaN,throttle:false,brake:false},Number.NaN); updateRace(race,Number.NaN,0,Number.NaN);
 assert.ok(Number.isFinite(car.x)&&Number.isFinite(car.y)&&Number.isFinite(car.heading)&&Number.isFinite(car.speed));
 assert.equal(race.elapsedSeconds,0);
});
