import test from "node:test";
import assert from "node:assert/strict";
import { crossedFinishLine, finishLineFraction, finishTimestamp } from "../src/race-timing.js";

const lap = Math.PI * 2;

test("cars on the same start line do not count a lap before crossing it", () => {
  assert.equal(crossedFinishLine(0, 0.02, lap), false);
  assert.equal(crossedFinishLine(0, lap, lap), true);
});

test("finish crossing is detected across the wrap boundary", () => {
  assert.equal(crossedFinishLine(lap - 0.1, 0.12, lap), true);
  assert.equal(crossedFinishLine(lap - 0.1, 0.08, lap), false);
});

test("finish timestamp interpolates the exact crossing within a simulation step", () => {
  assert.equal(finishLineFraction(lap - 0.1, 0.2, lap), 0.5);
  assert.ok(Math.abs(finishTimestamp(12, 1 / 60, lap - 0.1, 0.2, lap) - (12 + 1 / 120)) < 1e-12);
});

test("invalid timing input cannot produce a false finish timestamp", () => {
  assert.equal(finishTimestamp(4, 0.016, 0.2, 0.1, lap), null);
  assert.equal(finishTimestamp(Number.NaN, 0.016, lap - 0.1, 0.2, lap), null);
});

test("independent race stopwatches advance separately and freeze at exact finish times", async () => {
  const { createRaceClock, startRaceClock, advanceRaceClock, finishRaceClock } = await import("../src/race-timing.js");
  const goAt = 1234;
  const player = startRaceClock(createRaceClock(), goAt);
  const rival = startRaceClock(createRaceClock(), goAt);
  advanceRaceClock(player, 0.25);
  advanceRaceClock(rival, 0.5);
  assert.equal(player.startedAt, goAt);
  assert.equal(rival.startedAt, goAt);
  assert.equal(player.elapsed, 0.25);
  assert.equal(rival.elapsed, 0.5);
  finishRaceClock(rival, 0.475);
  advanceRaceClock(rival, 1);
  assert.equal(rival.elapsed, 0.475);
  assert.equal(rival.finishTime, 0.475);
  assert.equal(rival.running, false);
});
