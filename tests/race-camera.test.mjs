import test from "node:test";
import assert from "node:assert/strict";
import { nextRaceCameraMode, projectRacePoint, RACE_CAMERA_MODES, RACE_CAMERA_LABELS } from "../src/race-camera.js";

test("race camera exposes side, top, south-east and south-west views", () => {
  assert.deepEqual(RACE_CAMERA_MODES, ["side", "top", "southeast", "southwest"]);
  assert.deepEqual(Object.values(RACE_CAMERA_LABELS), ["SIDE", "TOP", "SE", "SW"]);
  assert.equal(nextRaceCameraMode("side"), "top");
  assert.equal(nextRaceCameraMode("top"), "southeast");
  assert.equal(nextRaceCameraMode("southeast"), "southwest");
  assert.equal(nextRaceCameraMode("southwest"), "side");
  assert.equal(nextRaceCameraMode("unknown"), "side");
});

test("perspective projection keeps the horizon stable and scales distant road geometry down", () => {
  const viewport = { width: 1280, height: 720 };
  const camera = { x: 0, y: 0 };
  const near = projectRacePoint({ x: 0, y: 120 }, camera, Math.PI / 2, viewport);
  const far = projectRacePoint({ x: 0, y: 1100 }, camera, Math.PI / 2, viewport);
  assert.ok(near.y > far.y, "near road points should appear lower on screen");
  assert.ok(near.scale > far.scale, "near road geometry should be larger than distant geometry");
  assert.ok(Math.abs(near.x - viewport.width / 2) < 1, "centerline should project to the viewport center");
  assert.ok(far.y >= viewport.height * .31, "distant geometry must remain below the horizon");
});

test("camera projection responds to lateral position and camera yaw", () => {
  const viewport = { width: 1000, height: 600 };
  const camera = { x: 0, y: 0 };
  const center = projectRacePoint({ x: 0, y: 500 }, camera, Math.PI / 2, viewport);
  const right = projectRacePoint({ x: 120, y: 500 }, camera, Math.PI / 2, viewport);
  const yawed = projectRacePoint({ x: 0, y: 500 }, camera, Math.PI / 2, viewport, { yaw: .25 });
  assert.ok(right.x > center.x, "right-side road points should project to the right");
  assert.ok(yawed.x > center.x, "camera yaw should shift the projected view");
  assert.ok(Number.isFinite(center.y) && Number.isFinite(right.scale));
});
