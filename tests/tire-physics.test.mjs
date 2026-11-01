import test from "node:test";
import assert from "node:assert/strict";
import { resolveTireForces, resolveLongitudinalAcceleration } from "../src/tire-physics.js";

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


test("available braking deceleration scales monotonically with surface grip",()=>{
 const dry=resolveTireForces({speed:180,lateralVelocity:0,steer:0,throttle:false,brake:true,grip:1,deltaSeconds:1/60});
 const wet=resolveTireForces({speed:180,lateralVelocity:0,steer:0,throttle:false,brake:true,grip:.86,deltaSeconds:1/60});
 const ice=resolveTireForces({speed:180,lateralVelocity:0,steer:0,throttle:false,brake:true,grip:.55,deltaSeconds:1/60});
 assert.equal(dry.brakingDeceleration,470);
 assert.ok(wet.brakingDeceleration<dry.brakingDeceleration);
 assert.ok(ice.brakingDeceleration<wet.brakingDeceleration);
 assert.equal(resolveTireForces({speed:180,lateralVelocity:0,steer:0,throttle:false,brake:false,grip:.55,deltaSeconds:1/60}).brakingDeceleration,0);
});

test("braking integrates with the fixed simulation step and never reverses the car",()=>{
 let speed=12;
 const dt=1/60;
 for(let frame=0;frame<120;frame++){
  const response=resolveTireForces({speed,lateralVelocity:0,steer:0,throttle:false,brake:true,grip:.35,deltaSeconds:dt});
  speed=Math.max(0,speed-response.brakingDeceleration*dt);
  assert.ok(speed>=0);
  if(speed===0)break;
 }
 assert.equal(speed,0);
});


test("cornering consumes braking capacity through the shared friction circle",()=>{
 const straight=resolveTireForces({speed:220,lateralVelocity:0,steer:0,throttle:false,brake:true,grip:1,deltaSeconds:1/60});
 const turning=resolveTireForces({speed:220,lateralVelocity:0,steer:1,throttle:false,brake:true,grip:1,deltaSeconds:1/60});
 assert.ok(turning.brakingDeceleration<straight.brakingDeceleration);
 assert.ok(turning.frictionUtilization<=1+1e-7);
});


test("drive acceleration scales with available road grip",()=>{
 const requestedAcceleration=260;
 const dry=resolveLongitudinalAcceleration({requestedAcceleration,grip:1});
 const wet=resolveLongitudinalAcceleration({requestedAcceleration,grip:.86});
 const snow=resolveLongitudinalAcceleration({requestedAcceleration,grip:.78});
 assert.equal(dry,requestedAcceleration);
 assert.ok(wet<dry);
 assert.ok(snow<wet);
 assert.equal(resolveLongitudinalAcceleration({requestedAcceleration:-10,grip:1}),0);
 assert.equal(resolveLongitudinalAcceleration({requestedAcceleration:260,grip:1.15}),299);
});

test("invalid traction inputs remain finite and safe",()=>{
 assert.equal(resolveLongitudinalAcceleration({requestedAcceleration:NaN,grip:NaN}),0);
 assert.equal(resolveLongitudinalAcceleration({requestedAcceleration:260,grip:.1}),91);
});


test("longitudinal traction stays bounded and monotonic across the supported grip range",()=>{
 const grips=[.35,.5,.68,.86,1,1.08,1.15];
 const accelerations=grips.map(grip=>resolveLongitudinalAcceleration({requestedAcceleration:300,grip}));
 for(let i=1;i<accelerations.length;i++)assert.ok(accelerations[i]>=accelerations[i-1]);
 assert.ok(accelerations.every(value=>Number.isFinite(value)&&value>=0&&value<=345));
});


test("braking transfers load forward and reduces rear-axle grip",()=>{
 const coast=resolveTireForces({speed:180,lateralVelocity:0,steer:0,throttle:false,brake:false,grip:1,deltaSeconds:1/60});
 const braking=resolveTireForces({speed:180,lateralVelocity:0,steer:0,throttle:false,brake:true,grip:1,deltaSeconds:1/60});
 assert.ok(braking.weightTransferFraction>0);
 assert.ok(braking.rearAxleLoadFraction<coast.rearAxleLoadFraction);
 assert.ok(braking.rearGripScale<coast.rearGripScale);
 assert.ok(braking.tireCapacity<coast.tireCapacity);
});

test("drive torque transfers load rearward and improves rear traction reserve",()=>{
 const coast=resolveTireForces({speed:180,lateralVelocity:0,steer:0,throttle:false,brake:false,grip:1,deltaSeconds:1/60});
 const throttle=resolveTireForces({speed:180,lateralVelocity:0,steer:0,throttle:true,brake:false,grip:1,deltaSeconds:1/60});
 assert.ok(throttle.weightTransferFraction<0);
 assert.ok(throttle.rearAxleLoadFraction>coast.rearAxleLoadFraction);
 assert.ok(throttle.rearGripScale>coast.rearGripScale);
});

test("braking load transfer increases rear slip response while keeping yaw bounded",()=>{
 const neutral=resolveTireForces({speed:100,lateralVelocity:38,steer:0,throttle:false,brake:false,grip:1,deltaSeconds:1/60});
 const braking=resolveTireForces({speed:200,lateralVelocity:38,steer:0,throttle:false,brake:true,grip:.8,deltaSeconds:1/60});
 assert.ok(braking.yawRateTarget>neutral.yawRateTarget);
 assert.ok(Math.abs(200*braking.yawRateTarget)<=braking.availableLateral+1e-7);
});

test("countersteer progressively reduces an established rear-slip yaw target",()=>{
 const neutral=resolveTireForces({speed:190,lateralVelocity:42,steer:0,throttle:false,brake:false,grip:.72,deltaSeconds:1/60});
 const countersteer=resolveTireForces({speed:190,lateralVelocity:42,steer:-.45,throttle:false,brake:false,grip:.72,deltaSeconds:1/60});
 assert.ok(countersteer.yawRateTarget<neutral.yawRateTarget);
 assert.ok(Number.isFinite(countersteer.lateralAcceleration));
});


test("high-grip vehicles retain distinct traction instead of being capped to the same value",()=>{
 const lynx=resolveLongitudinalAcceleration({requestedAcceleration:260,grip:1.22});
 const raptor=resolveLongitudinalAcceleration({requestedAcceleration:260,grip:1.32});
 assert.ok(lynx>260);
 assert.ok(raptor>lynx);
 assert.ok(raptor<260*1.32+1e-9);
});
