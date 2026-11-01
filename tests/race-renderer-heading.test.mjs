import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const renderer = await readFile(new URL("src/race-renderer-3d.js", root), "utf8");
const controls = await readFile(new URL("src/vehicle-controls.js", root), "utf8");

test("3D race renderer preserves showroom geometry and PBR imports alongside shared vehicle heading", () => {
  assert.match(renderer, /from "\.\/vehicle-showroom-3d\.js"/);
  assert.match(renderer, /from "\.\/vehicle-pbr\.js"/);
  assert.match(renderer, /import \{ vehicleModelHeading \} from "\.\/vehicle-controls\.js"/);
  assert.match(renderer, /heading=vehicleModelHeading\(f\.angle,yaw\)/);
  assert.match(controls, /export function vehicleModelHeading\(trackAngle, yaw = 0\)/);
  assert.match(controls, /return angle \+ Math\.PI \/ 2 \+ slip/);
  assert.doesNotMatch(renderer, /heading=-\(f\.angle\+yaw\)/);
});
