import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
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

test("race runtime lowers GPU fill cost and increases vehicle response", async () => {
  const game = await readFile(new URL("../src/web-game.js", import.meta.url), "utf8");
  assert.match(game, /touchDevice\?1\.3:1\.55/, "mobile and desktop backing-store resolution must be capped");
  assert.match(game, /adaptiveScale=Math\.max\(\.72,adaptiveScale-\.08\)/, "sustained slow frames must reduce render resolution");
  assert.match(game, /adaptiveScale=Math\.min\(1,adaptiveScale\+\.05\)/, "headroom should restore quality gradually");
  assert.match(game, /base\.max\*1\.15/, "vehicle top speed should be raised for a faster race feel");
  assert.match(game, /base\.accel\*1\.18/, "vehicle acceleration should be raised for a stronger launch");
  assert.match(game, /ctx\.shadowBlur=0/, "particle rendering must avoid expensive per-particle blur filters");
});
