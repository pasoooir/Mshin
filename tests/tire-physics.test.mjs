import test from "node:test";
import assert from "node:assert/strict";
import { resolveTireForces } from "../src/tire-physics.js";

test("combined throttle and lateral demand never exceed tire capacity",()=>{
 const response=resolveTireForces({speed:240,lateralVelocity:0,steer:1,throttle:true,brake:false,grip:.65,deltaSeconds:1/60});
 assert.ok(Math.abs(response.lateralAcceleration)<=response.tireCapacity);
 assert.ok(response.lateralScale<1);
});

test("low grip reduces steering authority and preserves more lateral slip",()=>{
 const high=resolveTireForces({speed:220,lateralVelocity:0,steer:1,throttle:false,brake:false,grip:1,deltaSeconds:1/60});
 const low=resolveTireForces({speed:220,lateralVelocity:0,steer:1,throttle:false,brake:false,grip:.4,deltaSeconds:1/60});
 assert.ok(low.corneringScale<high.corneringScale);
 assert.ok(Math.abs(low.lateralAcceleration)<=Math.abs(high.lateralAcceleration));
});

test("sustained lateral velocity generates bounded progressive oversteer yaw",()=>{
 const response=resolveTireForces({speed:180,lateralVelocity:45,steer:0,throttle:false,brake:false,grip:.55,deltaSeconds:1/60});
 assert.ok(response.yawRateTarget>0);
 assert.ok(response.yawRateTarget<=.9);
 assert.ok(Number.isFinite(response.slipAngle));
});

test("braking consumes more tire budget than coasting during a turn",()=>{
 const coast=resolveTireForces({speed:180,lateralVelocity:0,steer:1,throttle:false,brake:false,grip:1,deltaSeconds:1/60});
 const braking=resolveTireForces({speed:180,lateralVelocity:0,steer:1,throttle:false,brake:true,grip:1,deltaSeconds:1/60});
 assert.ok(braking.corneringScale<coast.corneringScale);
});

test("zero-speed steering does not create a yaw impulse",()=>{
 const response=resolveTireForces({speed:0,lateralVelocity:0,steer:1,throttle:false,brake:false,grip:1,deltaSeconds:1/60});
 assert.equal(response.yawRateTarget,0);
 assert.equal(response.lateralAcceleration,0);
});

test("yaw rate always respects the available lateral tyre-force envelope",()=>{
 for(const speed of [40,120,240,420])for(const grip of [.35,.6,1,1.15])for(const brake of [false,true]){
  const response=resolveTireForces({speed,lateralVelocity:22,steer:.9,throttle:!brake,brake,grip,deltaSeconds:1/60});
  assert.ok(Math.abs(speed*response.yawRateTarget)<=response.availableLateral+1e-7);
  assert.ok(response.frictionUtilization<=1+1e-7);
 }
});

test("steering response is symmetric for left and right inputs",()=>{
 const left=resolveTireForces({speed:210,lateralVelocity:0,steer:-.7,throttle:true,brake:false,grip:.8,deltaSeconds:1/60});
 const right=resolveTireForces({speed:210,lateralVelocity:0,steer:.7,throttle:true,brake:false,grip:.8,deltaSeconds:1/60});
 assert.ok(Math.abs(left.lateralAcceleration+right.lateralAcceleration)<1e-9);
 assert.ok(Math.abs(left.yawRateTarget+right.yawRateTarget)<1e-9);
});

test("zero delta time remains finite and produces no force demand",()=>{
 const response=resolveTireForces({speed:300,lateralVelocity:0,steer:1,throttle:true,brake:false,grip:1,deltaSeconds:0});
 assert.ok(Number.isFinite(response.lateralAcceleration));
 assert.ok(Number.isFinite(response.yawRateTarget));
 assert.equal(response.lateralAcceleration,0);
});
