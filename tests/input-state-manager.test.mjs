import test from "node:test";
import assert from "node:assert/strict";
import { createInputStateManager } from "../src/input-state-manager.js";

test("three independent pointers can steer, accelerate and turbo simultaneously", () => {
  const input = createInputStateManager();
  input.set("steering", 11, -0.72);
  input.set("throttle", 22, true);
  input.set("turbo", 33, true);

  const state = input.snapshot();
  assert.equal(state.steering, -0.72);
  assert.equal(state.throttle, 1);
  assert.equal(state.brake, 0);
  assert.equal(state.turbo, true);
  assert.equal(input.pointerCount(), 3);
  assert.deepEqual(state.activePointers, { steering: 1, throttle: 1, brake: 0, turbo: 1 });
});

test("releasing one pointer never cancels another control", () => {
  const input = createInputStateManager();
  input.set("steering", 1, 0.8);
  input.set("throttle", 2, true);
  input.set("turbo", 3, true);

  input.releasePointer(1);
  assert.deepEqual(input.snapshot(), {
    steering: 0, throttle: 1, brake: 0, turbo: true,
    activePointers: { steering: 0, throttle: 1, brake: 0, turbo: 1 }
  });
});

test("gas and brake remain independent, including simultaneous activation", () => {
  const input = createInputStateManager();
  input.set("throttle", 10, true);
  input.set("brake", 20, true);
  assert.equal(input.snapshot().throttle, 1);
  assert.equal(input.snapshot().brake, 1);
  input.release("brake", 20);
  assert.equal(input.snapshot().throttle, 1);
  assert.equal(input.snapshot().brake, 0);
});

test("multiple pointers on one pedal keep it active until the last pointer leaves", () => {
  const input = createInputStateManager();
  input.set("throttle", 1, true);
  input.set("throttle", 2, true);
  input.release("throttle", 1);
  assert.equal(input.snapshot().throttle, 1);
  input.release("throttle", 2);
  assert.equal(input.snapshot().throttle, 0);
});

test("steering is clamped and returns to neutral after its pointer is cancelled", () => {
  const input = createInputStateManager();
  input.set("steering", 5, -4);
  assert.equal(input.snapshot().steering, -1);
  input.releasePointer(5);
  assert.equal(input.snapshot().steering, 0);
});

test("releaseAll safely clears every active pointer", () => {
  const input = createInputStateManager();
  input.set("steering", 1, 0.4);
  input.set("throttle", 2, true);
  input.set("brake", 3, true);
  input.set("turbo", 4, true);
  input.releaseAll();
  assert.equal(input.pointerCount(), 0);
  assert.deepEqual(input.snapshot().activePointers, { steering: 0, throttle: 0, brake: 0, turbo: 0 });
});

test("neutral steering does not retain a phantom pointer owner", () => {
  const input = createInputStateManager();
  input.set("steering", -1, 0);
  assert.equal(input.snapshot().steering, 0);
  assert.equal(input.snapshot().activePointers.steering, 0);
  assert.equal(input.pointerCount(), 0);
});
