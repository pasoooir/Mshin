import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/audio.js", import.meta.url), "utf8");

test("all vehicle audio profiles define a tire-squeal character", () => {
  for (const profile of ["rally", "comet", "lynx", "raptor", "thunder"]) {
    assert.match(source, new RegExp(profile + ":\\{[^}]*squeal:"));
  }
});

test("hard-braking squeal cadence is deterministic rather than random", () => {
  assert.match(source, /lastBrakeSquealAt=-Infinity/);
  assert.match(source, /now-lastBrakeSquealAt>=\.38/);
  assert.match(source, /const intensity=Math\.min\(1,\(velocity-95\)\/190\)/);
  assert.match(source, /\.9\+intensity\*\.22/);
  assert.doesNotMatch(source, /Math\.random\(\)/);
});

test("tire squeal is gated by braking and resets when braking ends", () => {
  assert.match(source, /if\(!brake\)lastBrakeSquealAt=-Infinity;else if\(velocity>95/);
  assert.match(source, /oneShot\("brakeSqueal"/);
});
