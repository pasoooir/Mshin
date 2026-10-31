import test from "node:test";
import assert from "node:assert/strict";
import { createRigidVehicle, vehicleContact, resolveRigidVehicleImpact, sweptVehicleContact, applyRigidImpactDamage } from "../src/rigid-body-physics.js";

const body=(x,y,vx,vy,mass=1200,angle=0)=>createRigidVehicle({x,y,vx,vy,mass,angle,length:90,width:42});

test("oriented body geometry rejects diagonal corner cases missed by center-radius checks",()=>{
 const a=body(0,0,0,0,1200,0),b=body(0,75,0,0,1200,0);
 assert.equal(vehicleContact(a,b).hit,false);
});
test("low-speed rear contact resolves overlap and conserves near-total linear momentum",()=>{
 const a=body(0,0,18,0),b=body(82,0,8,0),px=a.mass*a.vx+b.mass*b.vx;
 const r=resolveRigidVehicleImpact(a,b);
 assert.equal(r.hit,true);assert.ok(r.overlap>0);assert.ok(b.vx>8);
 assert.ok(Math.abs(a.mass*a.vx+b.mass*b.vx-px)<1e-5);
 assert.ok(b.x-a.x>=Math.min(a.length,b.length)*.75);
});
test("heavy high-speed vehicle produces a smaller velocity change than the light vehicle",()=>{
 const heavy=body(0,0,150,0,2200),light=body(82,0,0,0,750);
 const beforeHeavy=heavy.vx,beforeLight=light.vx;
 const r=resolveRigidVehicleImpact(heavy,light);
 assert.ok(r.hit&&r.energy>0);assert.ok(Math.abs(heavy.vx-beforeHeavy)<Math.abs(light.vx-beforeLight));
});
test("oblique impact creates physically coupled translation and yaw",()=>{
 const a=body(0,0,120,22,1300,.12),b=body(68,36,-12,-4,1050,-.25);
 const r=resolveRigidVehicleImpact(a,b);
 assert.ok(r.hit);assert.ok(Number.isFinite(a.angularVelocity)&&Number.isFinite(b.angularVelocity));
 assert.ok(Math.abs(a.vy-22)>0.01||Math.abs(b.vy+4)>0.01);
});
test("side impact resolves with a non-longitudinal contact normal",()=>{
 const a=body(0,0,0,80),b=body(0,38,0,0);
 const c=vehicleContact(a,b);assert.ok(c.hit);assert.ok(Math.abs(c.ny)>.9);
 const r=resolveRigidVehicleImpact(a,b);assert.ok(r.impulse>0);
});
test("continuous swept contact detects fast vehicles crossing within one frame",()=>{
 const a0=body(-180,0,0,0),a1=body(180,0,0,0);
 const b0=body(0,0,0,0),b1=body(0,0,0,0);
 const r=sweptVehicleContact(a0,a1,b0,b1);
 assert.ok(r.hit);assert.ok(r.timeOfImpact<.5);assert.ok(r.steps>1);
});
test("three-car chain transfers momentum through sequential impacts",()=>{
 const rear=body(0,0,190,0),middle=body(82,0,0,0),front=body(164,0,0,0);
 const one=resolveRigidVehicleImpact(rear,middle);
 assert.ok(one.hit&&middle.vx>0);
 const two=resolveRigidVehicleImpact(middle,front);
 assert.ok(two.hit&&front.vx>0);
});
test("impact damage is deterministic, localized and cumulative",()=>{
 const d={total:0,front:0,rear:0,left:0,right:0,engine:0,disabled:false};
 const impact={energy:2_000_000};
 const r=applyRigidImpactDamage(d,impact,"left");
 assert.equal(r.zone,"left");assert.ok(d.left>0);assert.equal(d.right,0);
 const before=d.total;applyRigidImpactDamage(d,impact,"left");
 assert.ok(d.total>before);assert.equal(d.front,0);
});
test("separating overlapping vehicles receive correction but no false energy",()=>{
 const a=body(0,0,-40,0),b=body(80,0,40,0);
 const r=resolveRigidVehicleImpact(a,b);
 assert.ok(r.hit);assert.equal(r.energy,0);assert.equal(r.impulse,0);
});
