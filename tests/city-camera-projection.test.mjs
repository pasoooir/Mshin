import test from "node:test";
import assert from "node:assert/strict";
import { updateCityCameraTransform } from "../src/city/city-camera-projection.js";

function cameraHarness() {
  return {
    position: { set(x,y,z) { this.x=x; this.y=y; this.z=z; } },
    lookAt(x,y,z) { this.target={x,y,z}; },
    updateProjectionMatrix() {},
    updateMatrixWorld() {}
  };
}

test("camera transform uses one world target for orbit and pitch", () => {
  const camera=cameraHarness();
  const pose=updateCityCameraTransform(camera,{targetX:12,targetY:3,targetZ:-8,orbit:Math.PI/2,pitch:0.7,zoom:1},900);
  assert.equal(pose.targetX,12);assert.equal(pose.targetY,3);assert.equal(pose.targetZ,-8);
  assert.deepEqual(camera.target,{x:12,y:3,z:-8});
  assert.ok(camera.position.y>3);
  assert.ok(Math.abs(Math.hypot(camera.position.x-12,camera.position.z+8)-Math.hypot(48,48)*Math.cos(.7))<1e-9);
});

test("camera transform clamps elevation and preserves continuous orbit values", () => {
  const camera=cameraHarness();
  const pose=updateCityCameraTransform(camera,{orbit:Math.PI*4+0.2,pitch:9},800);
  assert.equal(pose.pitch,0.96);
  assert.ok(pose.orbit>Math.PI*2);
  const low=updateCityCameraTransform(camera,{orbit:pose.orbit,pitch:-5},800);
  assert.equal(low.pitch,0.24);
});

test("camera transform resolves the animated focus target before fallback pan offsets", () => {
  const camera=cameraHarness();
  const pose=updateCityCameraTransform(camera,{targetX:2,targetY:0,targetZ:4,currentTargetX:5,currentTargetY:2,currentTargetZ:7,x:100,y:100},1000);
  assert.deepEqual({x:pose.targetX,y:pose.targetY,z:pose.targetZ},{x:5,y:2,z:7});
});
