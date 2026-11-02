import test from "node:test";
import assert from "node:assert/strict";
import { createCityState, advanceCityTick } from "../.test-build/src/city/core/city-state.js";
import { createSeededRandom } from "../.test-build/src/city/core/seeded-random.js";
import { SimulationClock } from "../.test-build/src/city/core/simulation-clock.js";

test("city state is validated, immutable and advances by discrete ticks", () => {
  const city = createCityState({ cityId: "city-001", name: "Green Valley", seed: 42 });
  assert.equal(city.schemaVersion, 1);
  assert.equal(city.simulationTick, 0);
  const next = advanceCityTick(city);
  assert.equal(next.simulationTick, 1);
  assert.equal(city.simulationTick, 0, "advancing a city must not mutate the previous snapshot");
  assert.ok(Object.isFrozen(city));
  assert.ok(Object.isFrozen(next));
  assert.throws(() => createCityState({ cityId: " ", name: "City", seed: 1 }), /cityId/);
  assert.throws(() => createCityState({ cityId: "id", name: " ", seed: 1 }), /name/);
  assert.throws(() => createCityState({ cityId: "id", name: "City", seed: 1.2 }), /seed/);
});

test("seeded random streams reproduce exactly and stay in the unit interval", () => {
  const a = createSeededRandom(123456);
  const b = createSeededRandom(123456);
  const first = Array.from({ length: 32 }, () => a.next());
  const second = Array.from({ length: 32 }, () => b.next());
  assert.deepEqual(first, second);
  assert.ok(first.every(value => value >= 0 && value < 1));
  assert.throws(() => createSeededRandom(Number.NaN), /seed/);
});

test("fixed simulation ticks are independent of render-frame chunking", () => {
  const oneFrame = new SimulationClock({ tickSeconds: 0.5, maxTicksPerAdvance: 100 });
  const manyFrames = new SimulationClock({ tickSeconds: 0.5, maxTicksPerAdvance: 100 });
  const a = [], b = [];
  oneFrame.advance(5, tick => a.push(tick));
  for (let i = 0; i < 50; i += 1) manyFrames.advance(0.1, tick => b.push(tick));
  assert.deepEqual(a, b);
  assert.equal(oneFrame.tick, 10);
  assert.equal(manyFrames.tick, 10);
});

test("clock retains backlog and limits work per frame without dropping simulation time", () => {
  const clock = new SimulationClock({ tickSeconds: 1, maxTicksPerAdvance: 3 });
  const seen = [];
  const first = clock.advance(10, tick => seen.push(tick));
  assert.equal(first.ticksRun, 3);
  assert.equal(first.pendingTicks, 7);
  assert.equal(first.lastTick, 3);
  clock.advance(0, tick => seen.push(tick));
  clock.advance(0, tick => seen.push(tick));
  clock.advance(0, tick => seen.push(tick));
  assert.deepEqual(seen, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  assert.equal(clock.pendingTicks, 0);
});

test("pause and speed controls do not corrupt the fixed-step accumulator", () => {
  const clock = new SimulationClock({ tickSeconds: 1 });
  const seen = [];
  clock.advance(0.5, tick => seen.push(tick));
  clock.setSpeed(0);
  clock.advance(20, tick => seen.push(tick));
  assert.equal(clock.tick, 0);
  assert.equal(clock.interpolationAlpha, 0.5);
  clock.setSpeed(2);
  clock.advance(0.25, tick => seen.push(tick));
  assert.deepEqual(seen, [1]);
  assert.equal(clock.tick, 1);
  clock.setSpeed(4);
  clock.advance(0.5, tick => seen.push(tick));
  assert.equal(clock.tick, 3);
  assert.throws(() => clock.setSpeed(3), /speed/);
});

test("invalid deltas and callback failures are explicit and do not consume a failed tick", () => {
  const clock = new SimulationClock();
  assert.throws(() => clock.advance(-1, () => {}), /realDeltaSeconds/);
  assert.throws(() => clock.advance(Number.POSITIVE_INFINITY, () => {}), /realDeltaSeconds/);
  assert.throws(() => clock.advance(1, null), /callback/);
  assert.throws(() => clock.advance(1, () => { throw new Error("tick failure"); }), /tick failure/);
  assert.equal(clock.tick, 0);
  assert.equal(clock.pendingTicks, 1);
  clock.advance(0, () => {});
  assert.equal(clock.tick, 1);
});
