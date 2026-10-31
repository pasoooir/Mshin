import test from "node:test";
import assert from "node:assert/strict";
import { getHelicopterShadowPose, renderAerialScenery, drawHelicopterShadow } from "../src/aerial-environment.js";

test("helicopter shadow remains attached to a world-space pose, not the viewport",()=>{
 const center={x:120,y:-45}, tangent={x:1,y:0,nx:0,ny:1};
 const pose=getHelicopterShadowPose(1200,7,center,tangent);
 assert.ok(Number.isFinite(pose.x)&&Number.isFinite(pose.y));
 assert.ok(pose.scale>.8&&pose.scale<1.1);
 assert.ok(Number.isFinite(pose.rotation)&&Number.isFinite(pose.rotor));
 assert.notDeepEqual(pose,{x:0,y:0});
});
test("helicopter shadow follows the world camera anchor as it advances",()=>{
 const tangent={x:1,y:0,nx:0,ny:1};
 const a=getHelicopterShadowPose(3000,2,{x:0,y:0},tangent);
 const b=getHelicopterShadowPose(3000,2,{x:500,y:250},tangent);
 assert.ok(Math.abs((b.x-a.x)-500)<1e-9);
 assert.ok(Math.abs((b.y-a.y)-250)<1e-9);
});


function recordingContext() {
 const calls = {};
 const context = new Proxy({}, { get(target, key) {
   if (key in target) return target[key];
   if (typeof key === "string") return (...args) => { calls[key] = (calls[key] || 0) + 1; for (const value of args) if (typeof value === "number") assert.ok(Number.isFinite(value), key + " received a non-finite coordinate"); };
 }, set(target,key,value) { target[key]=value; return true; } });
 return { context, calls };
}
test("all ten worlds render volumetric scenery, crowd silhouettes and raised barriers deterministically",()=>{
 const world=["World","#9ac","#789","#eee","#f5c","#eee",1,""];
 for(let kind=0;kind<10;kind++){
  const {context,calls}=recordingContext();
  const stage={id:kind*5+1,world:kind,seed:kind*97+31};
  const frameAt=t=>({p:{x:Math.cos(t)*420,y:Math.sin(t)*320},nx:Math.cos(t),ny:Math.sin(t),angle:t});
  renderAerialScenery(context,stage,frameAt,world);
  assert.ok(calls.ellipse>=30, "world "+kind+" should include grounded contact shadows");
  assert.ok(calls.fillRect>=60, "world "+kind+" should include facade/barrier detail");
  assert.ok(calls.fill>=40, "world "+kind+" should include layered solid geometry");
  assert.ok(calls.stroke>=18, "world "+kind+" should include dimensional figure details");
 }
});
test("aerial crowd clusters are rendered as bodies, heads, limbs and ground shadows",()=>{
 const {context,calls}=recordingContext();
 const frameAt=t=>({p:{x:Math.cos(t)*400,y:Math.sin(t)*300},nx:Math.cos(t),ny:Math.sin(t),angle:t});
 renderAerialScenery(context,{id:4,world:4,seed:419},frameAt,["x","x","x","x","#ff44cc"]);
 assert.ok(calls.arc>=18,"crowd heads must be drawn individually");
 assert.ok(calls.stroke>=18,"crowd limbs must be drawn individually");
});
test("helicopter shadow draws a blurred fuselage and a separately faded rotor disk",()=>{
 const {context,calls}=recordingContext();
 drawHelicopterShadow(context,{x:20,y:30,rotation:.2,scale:1,rotor:1.5});
 assert.ok(calls.ellipse>=2);
 assert.equal(calls.rotate,2);
 assert.equal(calls.fillRect,3);
});
