import test from "node:test";
import assert from "node:assert/strict";
import { getHelicopterShadowPose } from "../src/aerial-environment.js";

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
