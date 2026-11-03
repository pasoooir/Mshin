import test from "node:test";
import assert from "node:assert/strict";
import { stepVehicleDynamics } from "../src/vehicle-dynamics.js";

const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
const frameAt=t=>({p:{x:Math.cos(t)*1000,y:Math.sin(t)*700},nx:-Math.cos(t),ny:-Math.sin(t),angle:t+Math.PI/2});
const tuning={dt:1/60,grip:1,mass:1250,acceleration:280,maxSpeed:390,worldUnitsPerSpeedUnit:1};
const makeCar=overrides=>({t:0,lateral:0,speed:0,lateralVelocity:0,yaw:0,yawRate:0,...overrides});

test("world-space dynamics accelerates and respects the speed cap",()=>{
 const car=makeCar();
 for(let i=0;i<120;i++)stepVehicleDynamics(car,{throttle:true,brake:false,steer:0},tuning,frameAt);
 assert.ok(car.speed>100);assert.ok(car.speed<=tuning.maxSpeed);assert.ok(car.t>0);
});

test("braking reduces speed and coasting applies rolling and aerodynamic drag",()=>{
 const coast=makeCar({speed:180}),brake=makeCar({speed:180});
 stepVehicleDynamics(coast,{throttle:false,brake:false,steer:0},tuning,frameAt);
 stepVehicleDynamics(brake,{throttle:false,brake:true,steer:0},tuning,frameAt);
 assert.ok(coast.speed<180);assert.ok(brake.speed<coast.speed);
});

test("steering changes world-space trajectory instead of locking to track tangent",()=>{
 const straight=t=>({p:{x:t*1000,y:0},nx:0,ny:1,angle:0});
 const car=makeCar({speed:180});
 for(let i=0;i<90;i++)stepVehicleDynamics(car,{throttle:true,brake:false,steer:.8},{...tuning,acceleration:0},straight);
 assert.ok(Math.abs(car.yaw)>.05,"chassis heading should change");
 assert.ok(Math.abs(car.lateral)>10,"world-space path should move away from the original line");
});

test("low grip reduces available tyre capacity",()=>{
 const dry=makeCar({speed:250}),wet=makeCar({speed:250});
 const a=stepVehicleDynamics(dry,{throttle:true,brake:false,steer:.8},{...tuning,grip:1.2},frameAt);
 const b=stepVehicleDynamics(wet,{throttle:true,brake:false,steer:.8},{...tuning,grip:.45},frameAt);
 assert.ok(b.tire.tireCapacity<a.tire.tireCapacity);
 assert.ok(Number.isFinite(wet.lateralVelocity)&&Math.abs(wet.yawRate)<=1.4);
});

test("fixed-step integration is deterministic for identical inputs",()=>{
 const a=makeCar(),b=makeCar();
 for(let i=0;i<120;i++)stepVehicleDynamics(a,{throttle:true,brake:false,steer:.3},tuning,frameAt);
 for(let i=0;i<120;i++)stepVehicleDynamics(b,{throttle:true,brake:false,steer:.3},tuning,frameAt);
 assert.deepEqual(a,b);
});

test("zero fixed step leaves vehicle state unchanged",()=>{
 const car=makeCar({t:.4,lateral:12,speed:90,lateralVelocity:3,yaw:.1,yawRate:.2});
 const before={...car};
 assert.equal(stepVehicleDynamics(car,{throttle:true,brake:false,steer:1},{...tuning,dt:0},frameAt),null);
 assert.deepEqual(car,before);
});

test("tenfold circuit scaling preserves lateral handling and calibrated race speed",()=>{
 const normal=makeCar({speed:180}),scaled=makeCar({speed:180});
 const controls={throttle:false,brake:false,steer:0};
 const a=stepVehicleDynamics(normal,controls,{...tuning,acceleration:0,trackDistanceScale:1},frameAt);
 const b=stepVehicleDynamics(scaled,controls,{...tuning,acceleration:0,trackDistanceScale:10},frameAt);
 assert.ok(scaled.t>normal.t*9.99,"the longer world must advance ten times as far along the circuit per simulation step");
 assert.equal(scaled.lateral,normal.lateral,"road-relative lane offset must not be multiplied");
 assert.equal(scaled.speed,normal.speed,"the calibrated speedometer value must remain unchanged");
 const f=frameAt(0);
 const tangent=(v)=>v.x*Math.cos(f.angle)+v.y*Math.sin(f.angle);
 const normalVelocity=(v)=>v.x*f.nx+v.y*f.ny;
 assert.ok(Math.abs(tangent(b.worldVelocity)-tangent(a.worldVelocity)*10)<1e-6);
 assert.ok(Math.abs(normalVelocity(b.worldVelocity)-normalVelocity(a.worldVelocity))<1e-6);
});
