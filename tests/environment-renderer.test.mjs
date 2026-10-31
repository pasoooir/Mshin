import test from "node:test";
import assert from "node:assert/strict";
import { drawWorldEnvironment, drawHelicopterShadow } from "../src/environment-renderer.js";

function mockContext() {
  const calls = [];
  const ctx = new Proxy({ calls, createLinearGradient(){ return { addColorStop(){} }; } }, {
    get(target, key) {
      if (key in target) return target[key];
      if (typeof key === "string") return (...args) => { calls.push([key, ...args]); };
    },
    set(target, key, value) { target[key] = value; return true; }
  });
  return ctx;
}
function frameAt(t) {
  return { p: { x: Math.cos(t) * 1000, y: Math.sin(t) * 700 }, nx: -Math.sin(t), ny: Math.cos(t), angle: t + Math.PI / 2 };
}

test("all ten world themes render volumetric props, shadows and spectator clusters", () => {
  for (let world = 0; world < 10; world++) {
    const ctx = mockContext();
    drawWorldEnvironment(ctx, world, frameAt);
    const names = ctx.calls.map(call => call[0]);
    assert.ok(names.includes("ellipse"), `world ${world} must draw contact shadows and rounded volumes`);
    assert.ok(names.includes("lineTo"), `world ${world} must draw extruded faces`);
    assert.ok(names.includes("fillRect"), `world ${world} must draw facade/structural details`);
    assert.ok(names.includes("arc"), `world ${world} must include identifiable spectator heads`);
  }
});

test("helicopter shadow is world-anchored and its rotor silhouette animates", () => {
  const a = mockContext(), b = mockContext();
  drawHelicopterShadow(a, frameAt, 1000);
  drawHelicopterShadow(b, frameAt, 5000);
  const aTransforms = a.calls.filter(call => call[0] === "translate");
  const bTransforms = b.calls.filter(call => call[0] === "translate");
  assert.notDeepEqual(aTransforms[0], bTransforms[0], "shadow must move in world coordinates");
  assert.ok(a.calls.filter(call => call[0] === "fillRect").length >= 5, "shadow must include fuselage, skids and rotor blades");
  assert.ok(b.calls.some(call => call[0] === "rotate"), "rotor and helicopter heading must be transformed");
});
