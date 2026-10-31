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
