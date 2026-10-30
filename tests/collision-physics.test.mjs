import test from "node:test";
import assert from "node:assert/strict";
import { createDamageState, damageLevel, applyVehicleDamage, resolveVehicleImpact, resolveBarrierImpact, damageSideFromLocalNormal } from "../src/collision-physics.js";
const car=(x,y,vx,vy,mass=1100)=>({x,y,vx,vy,mass,radius:32});
test("gentle rear impact transfers a small forward impulse without lateral kick",()=>{
 const a=car(0,0,120,0),b=car(64,0,100,0),r=resolveVehicleImpact(a,b);
 assert.equal(r.hit,true);assert.ok(b.vx>100);assert.ok(Math.abs(b.vy)<1);assert.ok(r.energy>0);
});
test("high-speed rear impact transfers momentum and preserves impact axis",()=>{
 const a=car(0,0,360,0),b=car(64,0,80,0),r=resolveVehicleImpact(a,b);
 assert.ok(b.vx>80);assert.ok(Math.abs(b.vy)<1);assert.ok(r.energy>100000);
});
test("head-on impact reverses relative longitudinal motion",()=>{
 const a=car(0,0,240,0),b=car(64,0,-240,0);resolveVehicleImpact(a,b);
 assert.ok(a.vx<240);assert.ok(b.vx>-240);assert.ok(a.vx-b.vx<480);
});
test("left-side impact changes lateral velocity",()=>{
 const a=car(0,0,0,180),b=car(0,64,0,0);const r=resolveVehicleImpact(a,b);
 assert.ok(r.impulse>0);assert.ok(Math.abs(a.vy)<180);
});
test("right-side impact is symmetric",()=>{
 const a=car(0,0,0,-180),b=car(0,-64,0,0);const r=resolveVehicleImpact(a,b);
 assert.ok(r.hit);assert.ok(Math.abs(a.vy)<180);
});
test("oblique impact resolves both velocity axes",()=>{
 const a=car(0,0,230,35),b=car(58,42,-20,-10);resolveVehicleImpact(a,b);
 assert.ok(Number.isFinite(a.vx)&&Number.isFinite(a.vy));assert.ok(Math.abs(a.vy-35)>0.01);
});
test("static barrier reflects only inward normal velocity",()=>{
 const v=car(0,0,200,40),r=resolveBarrierImpact(v,-1,0);
 assert.ok(r.hit);assert.ok(v.vx<0);assert.ok(Math.abs(v.vy)<40);
});
test("non-closing separated cars do not receive artificial energy",()=>{
 const a=car(0,0,-50,0),b=car(64,0,50,0),r=resolveVehicleImpact(a,b);
 assert.equal(r.hit,false);assert.equal(r.energy,0);
});
test("overlap is corrected to prevent persistent interpenetration",()=>{
 const a=car(0,0,0,0),b=car(30,0,0,0),r=resolveVehicleImpact(a,b);
 assert.ok(r.overlap>0);assert.ok(b.x-a.x>30);
});
test("mass changes impulse response: heavier vehicle moves less",()=>{
 const light=car(0,0,220,0,700),heavy=car(64,0,0,0,2200);
 const before=heavy.vx;resolveVehicleImpact(light,heavy);
 assert.ok(heavy.vx>before);assert.ok(Math.abs(light.vx-220)>Math.abs(heavy.vx));
});
test("damage accumulates gradually and maps to five damage levels",()=>{
 const d=createDamageState();assert.equal(damageLevel(d),0);
 applyVehicleDamage(d,1500000,"front");assert.equal(damageLevel(d),1);
 applyVehicleDamage(d,2600000,"rear");assert.ok(d.total>8);assert.ok(d.front>0&&d.rear>0);
 applyVehicleDamage(d,12000000,"left");assert.ok(damageLevel(d)>=2);
});
test("damage remains localized to the struck body panel",()=>{
 const d=createDamageState();applyVehicleDamage(d,1800000,"left");
 assert.ok(d.left>0);assert.equal(d.right,0);assert.equal(d.rear,0);
});
test("critical cumulative damage can disable a vehicle",()=>{
 const d=createDamageState();for(let i=0;i<8;i++)applyVehicleDamage(d,12000000,"front");
 assert.ok(d.total>=82);assert.equal(damageLevel(d),4);
});
test("collision normal maps to the corresponding local body zone",()=>{
 assert.equal(damageSideFromLocalNormal(1,.1),"front");
 assert.equal(damageSideFromLocalNormal(-1,.1),"rear");
 assert.equal(damageSideFromLocalNormal(.1,-1),"left");
 assert.equal(damageSideFromLocalNormal(.1,1),"right");
});
test("barrier impact ignores outward-moving vehicles",()=>{
 const v=car(0,0,-120,0);const r=resolveBarrierImpact(v,-1,0);
 assert.equal(r.hit,false);
});

import { createVehicleDamage, addVehicleDamage, vehicleDamageLevel, resolveVehicleImpulse, resolveStaticBarrier } from "../.test-build/src/cocos-core.js";
test("Cocos shared core resolves a frontal vehicle impulse with mass weighting",()=>{
 const a={x:0,y:0,vx:260,vy:0,mass:1300,radius:18},b={x:36,y:0,vx:30,vy:0,mass:900,radius:18};
 const hit=resolveVehicleImpulse(a,b);assert.ok(hit.hit);assert.ok(b.vx>30);assert.ok(hit.energy>0);
});
test("Cocos shared core reflects static barrier impacts and ignores separating motion",()=>{
 const inward={x:0,y:0,vx:160,vy:20,mass:1200,radius:18},outward={x:0,y:0,vx:-160,vy:20,mass:1200,radius:18};
 assert.equal(resolveStaticBarrier(inward,-1,0).hit,true);assert.ok(inward.vx<0);
 assert.equal(resolveStaticBarrier(outward,-1,0).hit,false);
});
test("Cocos damage state accumulates by local panel and reduces to five levels",()=>{
 const d=createVehicleDamage();assert.equal(vehicleDamageLevel(d),0);
 addVehicleDamage(d,5_000_000,"rear");assert.ok(d.rear>0);assert.equal(d.front,0);
 for(let i=0;i<3;i++)addVehicleDamage(d,5_000_000,"left");
 assert.ok(vehicleDamageLevel(d)>=1);assert.ok(d.left>d.right);
});
