import test from "node:test";
import assert from "node:assert/strict";
import { calculateRaceCameraPose } from "../src/race-renderer-3d.js";

function curvedFrameAt(t) {
  const p = { x: 11800 * Math.cos(t), y: 7600 * Math.sin(t) + 420 * Math.sin(t * 4) };
  const before = { x: 11800 * Math.cos(t - 0.001), y: 7600 * Math.sin(t - 0.001) + 420 * Math.sin((t - 0.001) * 4) };
  const after = { x: 11800 * Math.cos(t + 0.001), y: 7600 * Math.sin(t + 0.001) + 420 * Math.sin((t + 0.001) * 4) };
  const dx = after.x - before.x, dy = after.y - before.y, length = Math.hypot(dx, dy) || 1;
  return { p, nx: -dy / length, ny: dx / length, height: 12 * Math.sin(t * 2) };
}

test("race chase camera samples the real circuit behind and ahead of the player", () => {
  const t = 1.17, lateral = 42, pose = calculateRaceCameraPose(curvedFrameAt, t, lateral, false);
  const behind = curvedFrameAt(t - pose.behindT), ahead = curvedFrameAt(t + pose.lookAheadT);
  assert.deepEqual(pose.eye, [behind.p.x + behind.nx * lateral, behind.height + 235, -(behind.p.y + behind.ny * lateral)]);
  assert.deepEqual(pose.target, [ahead.p.x + ahead.nx * lateral, ahead.height + 28, -(ahead.p.y + ahead.ny * lateral)]);
  assert.ok(pose.behindT > 0 && pose.lookAheadT > pose.behindT);
});

test("mobile chase camera keeps a slightly higher, tighter curve-following frame", () => {
  const pose = calculateRaceCameraPose(curvedFrameAt, 2.2, -35, true);
  const behind = curvedFrameAt(2.2 - pose.behindT), ahead = curvedFrameAt(2.2 + pose.lookAheadT);
  assert.equal(pose.eye[1], behind.height + 255);
  assert.equal(pose.target[1], ahead.height + 28);
  assert.ok(pose.behindT < 0.03);
  assert.ok(pose.lookAheadT > 0.03);
});
