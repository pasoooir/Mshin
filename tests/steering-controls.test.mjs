import test from "node:test";
import assert from "node:assert/strict";
import { fuzzySteering, mapTiltToSteering, combineSteering } from "../src/steering-controls.js";

test("fuzzy steering responds immediately outside the dead zone and stays bounded",()=>{
 assert.equal(fuzzySteering(.04),0);
 assert.ok(fuzzySteering(.2)>0);
 assert.ok(fuzzySteering(-.2)<0);
 assert.ok(Math.abs(fuzzySteering(1,{speed:350}))<=1);
});
test("high speed gently reduces steering authority",()=>{
 assert.ok(fuzzySteering(.7,{speed:300})<fuzzySteering(.7,{speed:30}));
});
test("gyro tilt uses calibration, dead zone and configurable range",()=>{
 assert.equal(mapTiltToSteering(12,10,{deadZone:3,range:24}),0);
 assert.ok(mapTiltToSteering(20,10,{deadZone:3,range:24})>0);
 assert.ok(mapTiltToSteering(0,10,{deadZone:3,range:24})<0);
 assert.equal(mapTiltToSteering(40,10,{deadZone:3,range:24}),1);
});
test("steering modes select joystick, gyro or blended inputs",()=>{
 assert.equal(combineSteering({mode:"joystick",joystick:.6,gyro:-.5}),.6);
 assert.equal(combineSteering({mode:"gyro",joystick:.6,gyro:-.5}),-.5);
 assert.equal(combineSteering({mode:"hybrid",joystick:.4,gyro:.5}),.76);
 assert.equal(combineSteering({mode:"hybrid",joystick:1,gyro:1}),1);
});
