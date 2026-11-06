import test from "node:test";
import assert from "node:assert/strict";
import { createCityCameraController } from "../src/city/city-camera-controller.js";

function harness() {
  const listeners = new Map();
  const canvas = {
    style: {},
    addEventListener(type, fn) { if (!listeners.has(type)) listeners.set(type, new Set()); listeners.get(type).add(fn); },
    removeEventListener(type, fn) { listeners.get(type)?.delete(fn); },
    setPointerCapture() {}, hasPointerCapture() { return false; }, releasePointerCapture() {},
    dispatch(type, values) {
      const event = { type, pointerType: "touch", button: 0, timeStamp: 16, preventDefault() {}, ...values };
      for (const fn of listeners.get(type) || []) fn(event);
    }
  };
  const camera = { zoom: 0.8, orbit: Math.PI * 2 - 0.2, targetX: 0, targetZ: 0, x: 0, y: 0 };
  const renderer = {
    updateCamera() {},
    groundPointAt(x, y) { return { x: (x - 200) / camera.zoom + camera.targetX, z: (y - 200) / camera.zoom + camera.targetZ }; },
    tileAt(x, y) { return { x: Math.floor(x / 20), y: Math.floor(y / 20) }; }
  };
  const taps = [];
  const controller = createCityCameraController({ canvas, camera, getRenderer: () => renderer, onTap: (x, y) => taps.push([x, y]) });
  const send = (type, id, x, y) => canvas.dispatch(type, { pointerId: id, clientX: x, clientY: y });
  return { canvas, camera, controller, taps, send, renderer };
}

test("orbit remains continuous across the 2π boundary and supports repeated full turns", () => {
  const h = harness();
  const initial = h.camera.orbit;
  for (let i = 0; i < 9; i++) {
    h.send("pointerdown", 1, 100, 100);
    h.send("pointerdown", 2, 200, 100);
    // Rotate the finger line around a fixed first contact in 45-degree steps.
    for (let step = 1; step <= 8; step++) {
      const radians = step * Math.PI / 4;
      h.send("pointermove", 2, 100 + 100 * Math.cos(radians), 100 + 100 * Math.sin(radians));
    }
    h.send("pointerup", 1, 200, 100);
    h.send("pointerup", 2, 300, 100);
  }
  assert.ok(h.camera.orbit > initial + Math.PI * 2, "orbit must accumulate beyond one complete revolution");
  assert.ok(Number.isFinite(h.camera.orbit));
  assert.equal(h.controller.getState().pointers, 0);
  h.controller.destroy();
});

test("pinch zoom and horizontal orbit work together while retaining the ground anchor", () => {
  const h = harness();
  const anchorBefore = h.renderer.groundPointAt(150, 100);
  h.send("pointerdown", 1, 100, 100);
  h.send("pointerdown", 2, 200, 100);
  h.send("pointermove", 2, 300, 100);
  const anchorAfter = h.renderer.groundPointAt(200, 100);
  assert.ok(Math.abs(anchorBefore.x-anchorAfter.x)<1e-9&&Math.abs(anchorBefore.z-anchorAfter.z)<1e-9,"pinch must preserve the ground point under the gesture midpoint");
  assert.ok(h.camera.zoom > 0.8, "spreading fingers must zoom in");
  assert.equal(h.camera.orbit, Math.PI * 2 - 0.2, "parallel horizontal movement must pan, not orbit");
  const after = h.controller.getState();
  assert.equal(after.gesture, "pinch-orbit");
  assert.ok(after.zoom <= 1.5, "zoom must respect the upper bound");
  h.send("pointerup", 2, 300, 100);
  h.send("pointerup", 1, 100, 100);
  assert.equal(h.controller.getState().pointers, 0);
  h.controller.destroy();
});

test("pointer cancellation and finger-count transitions do not create phantom taps", () => {
  const h = harness();
  h.send("pointerdown", 1, 100, 100);
  h.send("pointerdown", 2, 200, 100);
  h.send("pointercancel", 2, 200, 100);
  h.send("pointermove", 1, 110, 100);
  h.send("pointerup", 1, 110, 100);
  assert.deepEqual(h.taps, []);
  assert.equal(h.controller.getState().pointers, 0);
  h.controller.destroy();
});

test("a stationary single-pointer gesture focuses and selects the raycast tile", () => {
  const h = harness();
  h.send("pointerdown", 7, 260, 240);
  h.send("pointerup", 7, 260, 240);
  assert.deepEqual(h.taps, [[13, 12]]);
  assert.notEqual(h.camera.targetX, 0);
  assert.notEqual(h.camera.targetZ, 0);
  h.controller.destroy();
});

test("the 2D renderer fallback retains tile selection when Three.js is unavailable", () => {
  const listeners = new Map();
  const canvas = {
    style: {},
    addEventListener(type, fn) { if (!listeners.has(type)) listeners.set(type, new Set()); listeners.get(type).add(fn); },
    removeEventListener(type, fn) { listeners.get(type)?.delete(fn); },
    setPointerCapture() {}, hasPointerCapture() { return false; }, releasePointerCapture() {},
    dispatch(type, event) { for (const fn of listeners.get(type) || []) fn({ type, pointerType: "touch", button: 0, preventDefault() {}, ...event }); }
  };
  const taps = [];
  const controller = createCityCameraController({
    canvas, camera: { zoom: 1, orbit: 0 }, getRenderer: () => null,
    getTileAt: () => ({ x: 8, y: 9 }), onTap: (x, y) => taps.push([x, y])
  });
  canvas.dispatch("pointerdown", { pointerId: 1, clientX: 120, clientY: 130 });
  canvas.dispatch("pointerup", { pointerId: 1, clientX: 120, clientY: 130 });
  assert.deepEqual(taps, [[8, 9]]);
  controller.destroy();
});


test("pinch-to-pan transition rebases the remaining finger without a camera jump or stale fling", () => {
  const h = harness();
  h.send("pointerdown", 1, 100, 100);
  h.send("pointerdown", 2, 220, 100);
  h.send("pointermove", 2, 260, 100);
  const orbitAtTransition = h.camera.orbit;
  const zoomAtTransition = h.camera.zoom;
  h.send("pointerup", 2, 260, 100);
  assert.equal(h.controller.getState().gesture, "pan");
  assert.equal(h.controller.getState().pointers, 1);
  assert.equal(h.camera.orbit, orbitAtTransition);
  assert.equal(h.camera.zoom, zoomAtTransition);
  h.send("pointermove", 1, 104, 100);
  h.send("pointerup", 1, 104, 100);
  assert.equal(h.controller.getState().inertiaActive, false, "one-finger continuation must cancel the old two-finger fling");
  assert.deepEqual(h.taps, []);
  h.controller.destroy();
});

test("pointercancel and lost capture never become taps or start inertial motion", () => {
  const h = harness();
  h.send("pointerdown", 1, 100, 100);
  h.send("pointercancel", 1, 100, 100);
  h.send("lostpointercapture", 1, 100, 100);
  assert.deepEqual(h.taps, []);
  assert.equal(h.controller.getState().pointers, 0);
  assert.equal(h.controller.getState().inertiaActive, false);
  h.controller.destroy();
});

test("pinch zoom is multiplicative, bounded, and reversible across changing spans", () => {
  const h = harness();
  h.send("pointerdown", 1, 100, 100);
  h.send("pointerdown", 2, 200, 100);
  h.send("pointermove", 2, 260, 100);
  const zoomIn = h.camera.zoom;
  h.send("pointermove", 2, 220, 100);
  const zoomOut = h.camera.zoom;
  assert.ok(zoomIn > 0.8);
  assert.ok(zoomOut < zoomIn);
  h.send("pointermove", 2, 500, 100);
  assert.equal(h.camera.zoom, 1.5, "maximum zoom must be clamped");
  h.send("pointermove", 2, 101, 100);
  assert.equal(h.camera.zoom, 0.42, "minimum zoom must be clamped before the camera can expose the outside world");
  h.send("pointercancel", 2, 101, 100);
  h.send("pointercancel", 1, 100, 100);
  h.controller.destroy();
});


test("same-direction asynchronous finger updates do not create a false pinch zoom", () => {
  const h = harness();
  const initialZoom = h.camera.zoom;
  h.send("pointerdown", 31, 100, 100);
  h.send("pointerdown", 32, 200, 100);
  // Pointer Events are delivered per contact. The first finger can report its
  // full movement before the second contact's next event is dispatched.
  h.send("pointermove", 31, 200, 100);
  h.send("pointermove", 32, 300, 100);
  assert.ok(Math.abs(h.camera.zoom - initialZoom) < 1e-9,
    "equal translation of both fingers must not be mistaken for a pinch, even when pointer events arrive sequentially");
  assert.equal(h.controller.getState().gesture, "pinch-orbit");
  h.send("pointerup", 31, 200, 100);
  h.send("pointerup", 32, 300, 100);
  h.controller.destroy();
});

test("rotating the two-finger line changes orbit without changing pinch scale", () => {
  const h = harness();
  const initialZoom = h.camera.zoom;
  const initialOrbit = h.camera.orbit;
  h.send("pointerdown", 41, 150, 100);
  h.send("pointerdown", 42, 250, 100);
  // Rotate the pair around its midpoint while preserving the 100px span.
  h.send("pointermove", 41, 200, 50);
  h.send("pointermove", 42, 200, 150);
  assert.ok(Math.abs(h.camera.orbit - initialOrbit) > 0.1,
    "rotating the two-finger line must rotate the camera");
  assert.ok(Math.abs(h.camera.zoom - initialZoom) < 1e-9,
    "pure two-finger rotation must not zoom");
  h.send("pointercancel", 41, 200, 50);
  h.send("pointercancel", 42, 200, 150);
  h.controller.destroy();
});


test("orbit inertia is speed-capped and always settles within its maximum lifetime", async () => {
  const h = harness();
  h.send("pointerdown", 51, 100, 100);
  h.send("pointerdown", 52, 200, 100);
  h.send("pointermove", 51, 1100, 100);
  h.send("pointermove", 52, 1200, 100);
  h.send("pointerup", 51, 1100, 100);
  h.send("pointerup", 52, 1200, 100);
  await new Promise(resolve => setTimeout(resolve, 30));
  assert.ok(Math.abs(h.controller.getState().lastInertiaVelocity) <= 0.18,
    "a fast flick must not create an unbounded angular velocity");
  await new Promise(resolve => setTimeout(resolve, 1000));
  assert.equal(h.controller.getState().inertiaActive, false,
    "inertia must terminate within its bounded lifetime");
  h.controller.destroy();
});


test("parallel two-finger movement pans without changing zoom, pitch or orbit", () => {
  const h = harness();
  h.camera.pitch = 0.51;
  const before = { x: h.camera.targetX, z: h.camera.targetZ };
  h.send("pointerdown", 71, 100, 100);
  h.send("pointerdown", 72, 200, 100);
  h.send("pointermove", 71, 120, 140);
  h.send("pointermove", 72, 220, 140);
  assert.equal(h.camera.zoom, 0.8, "parallel movement must not zoom");
  assert.equal(h.camera.orbit, Math.PI * 2 - 0.2, "parallel movement must not rotate the camera");
  assert.equal(h.camera.pitch, 0.51, "parallel movement must not tilt the camera");
  assert.ok(h.camera.targetX !== before.x || h.camera.targetZ !== before.z,
    "two-finger midpoint translation must pan the camera target");
  assert.equal(h.controller.getState().gesture, "pinch-orbit");
  h.send("pointercancel", 71, 120, 140);
  h.send("pointercancel", 72, 220, 140);
  h.controller.destroy();
});

test("pure two-finger line rotation orbits without panning or changing zoom", () => {
  const h = harness();
  const zoom = h.camera.zoom;
  const target = { x: h.camera.targetX, z: h.camera.targetZ };
  const orbit = h.camera.orbit;
  h.send("pointerdown", 81, 150, 100);
  h.send("pointerdown", 82, 250, 100);
  h.send("pointermove", 81, 200, 50);
  h.send("pointermove", 82, 200, 150);
  assert.ok(Math.abs(h.camera.orbit - orbit) > 0.1, "rotating the finger line must orbit");
  assert.equal(h.camera.zoom, zoom, "pure rotation must not zoom");
  assert.equal(h.camera.targetX, target.x, "pure rotation around a fixed midpoint must not pan X");
  assert.equal(h.camera.targetZ, target.z, "pure rotation around a fixed midpoint must not pan Z");
  h.send("pointercancel", 81, 200, 50);
  h.send("pointercancel", 82, 200, 150);
  h.controller.destroy();
});
