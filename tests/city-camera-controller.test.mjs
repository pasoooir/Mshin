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
      const event = { pointerType: "touch", button: 0, preventDefault() {}, ...values };
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
    h.send("pointermove", 1, 200, 100);
    h.send("pointermove", 2, 300, 100);
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
  assert.ok(h.camera.orbit > Math.PI * 2 - 0.2, "horizontal movement must orbit");
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
