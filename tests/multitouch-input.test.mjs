import test from "node:test";
import assert from "node:assert/strict";
import { createMultiTouchPointerSet } from "../src/multitouch-input.js";

test("independent fingers can hold the same driving action",()=>{
  const gas=createMultiTouchPointerSet();
  assert.equal(gas.press(11),true);
  assert.equal(gas.press(12),true);
  assert.equal(gas.size,2);
  assert.equal(gas.pressed,true);
  assert.equal(gas.release(11),true);
  assert.equal(gas.pressed,true,"releasing one finger must not cancel the other");
  assert.equal(gas.release(12),true);
  assert.equal(gas.pressed,false);
});

test("pointer release is idempotent and one finger cannot release another",()=>{
  const brake=createMultiTouchPointerSet();
  brake.press(21);
  assert.equal(brake.release(22),false);
  assert.equal(brake.pressed,true);
  assert.equal(brake.release(21),true);
  assert.equal(brake.release(21),false);
});

test("all held pointers can be safely cleared after interruption",()=>{
  const gas=createMultiTouchPointerSet();
  gas.press(31);gas.press(32);
  assert.equal(gas.clear(),true);
  assert.equal(gas.clear(),false);
  assert.equal(gas.size,0);
  assert.equal(gas.pressed,false);
});
