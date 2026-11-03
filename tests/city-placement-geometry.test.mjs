import test from "node:test";
import assert from "node:assert/strict";
import {
  intersectCityPlacementGround,
  snapCityPlacementPoint
} from "../.test-build/src/city/core/placement-geometry.js";

test("ground projection intersects the forward ray at the configured height", () => {
  const point = intersectCityPlacementGround({
    origin: { x: 1, y: 10, z: 2 },
    direction: { x: 0.5, y: -1, z: 2 }
  }, 0, 30);
  assert.deepEqual(point, { x: 6, y: 0, z: 22 });
});

test("parallel, backwards and out-of-range rays are rejected", () => {
  const base = { origin: { x: 0, y: 5, z: 0 }, direction: { x: 0, y: -1, z: 0 } };
  assert.equal(intersectCityPlacementGround({ ...base, direction: { x: 1, y: 0, z: 0 } }, 0, 20), null);
  assert.equal(intersectCityPlacementGround({ ...base, direction: { x: 0, y: 1, z: 0 } }, 0, 20), null);
  assert.equal(intersectCityPlacementGround(base, 0, 4), null);
});

test("non-finite ray and placement configuration cannot create invalid coordinates", () => {
  const ray = { origin: { x: Number.NaN, y: 5, z: 0 }, direction: { x: 0, y: -1, z: 0 } };
  assert.equal(intersectCityPlacementGround(ray, 0, 20), null);
  assert.equal(intersectCityPlacementGround({ origin: { x: 0, y: 5, z: 0 }, direction: { x: 0, y: -1, z: 0 } }, Number.NaN, 20), null);
  assert.equal(intersectCityPlacementGround({ origin: { x: 0, y: 5, z: 0 }, direction: { x: 0, y: -1, z: 0 } }, 0, Number.NaN), null);
});

test("grid snapping is deterministic and preserves the ground plane", () => {
  assert.deepEqual(snapCityPlacementPoint({ x: 1.6, y: 2, z: -2.4 }, 1), { x: 2, y: 2, z: -2 });
  assert.deepEqual(snapCityPlacementPoint({ x: 1.6, y: 2, z: -2.4 }, 0), { x: 1.6, y: 2, z: -2.4 });
  assert.deepEqual(snapCityPlacementPoint({ x: 1.6, y: 2, z: -2.4 }, -1), { x: 1.6, y: 2, z: -2.4 });
});

test("invalid grid values and coordinates are rejected", () => {
  assert.equal(snapCityPlacementPoint({ x: 1, y: 2, z: 3 }, Number.NaN), null);
  assert.equal(snapCityPlacementPoint({ x: 1, y: Number.POSITIVE_INFINITY, z: 3 }, 1), null);
});
