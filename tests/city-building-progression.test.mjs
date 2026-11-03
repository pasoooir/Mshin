import test from "node:test";
import assert from "node:assert/strict";
import {
  advanceCityBuildingProgression,
  cityBuildingProgress,
  createCityBuildingProgression,
  startCityBuildingUpgrade
} from "../.test-build/src/city/core/building-progression.js";

test("new building starts with a bounded construction timer", () => {
  const building = createCityBuildingProgression({ constructionDuration: 20 });
  assert.equal(building.state, "constructing");
  assert.equal(building.secondsRemaining, 20);
  assert.equal(cityBuildingProgress(building), 0);
});

test("construction advances by frame delta and completes at progress one", () => {
  const started = createCityBuildingProgression({ constructionDuration: 10 });
  const halfway = advanceCityBuildingProgression(started, 5);
  assert.equal(halfway.secondsRemaining, 5);
  assert.equal(cityBuildingProgress(halfway), 0.5);
  const complete = advanceCityBuildingProgression(halfway, 5);
  assert.equal(complete.state, "complete");
  assert.equal(complete.secondsRemaining, 0);
  assert.equal(cityBuildingProgress(complete), 1);
});

test("negative and non-finite frame deltas cannot corrupt progression", () => {
  const started = createCityBuildingProgression({ constructionDuration: 8 });
  assert.equal(advanceCityBuildingProgression(started, -2).secondsRemaining, 8);
  assert.equal(advanceCityBuildingProgression(started, Number.NaN).secondsRemaining, 8);
  assert.equal(advanceCityBuildingProgression(started, Number.POSITIVE_INFINITY).secondsRemaining, 8);
});

test("upgrade is rejected before construction completes", () => {
  const started = createCityBuildingProgression({ constructionDuration: 8 });
  assert.equal(startCityBuildingUpgrade(started), null);
});

test("valid upgrade increments level and starts a separate bounded timer", () => {
  const complete = createCityBuildingProgression({ constructionDuration: 0, upgradeDuration: 6, maxLevel: 3 });
  const upgraded = startCityBuildingUpgrade(complete);
  assert.ok(upgraded);
  assert.equal(upgraded.level, 2);
  assert.equal(upgraded.state, "constructing");
  assert.equal(upgraded.secondsRemaining, 6);
  assert.equal(cityBuildingProgress(upgraded), 0);
});

test("upgrade is rejected at max level and does not mutate the source state", () => {
  const complete = createCityBuildingProgression({ constructionDuration: 0, maxLevel: 1 });
  assert.equal(startCityBuildingUpgrade(complete), null);
  assert.equal(complete.level, 1);
});

test("zero-duration construction and upgrades complete immediately", () => {
  const complete = createCityBuildingProgression({ constructionDuration: 0, upgradeDuration: 0, maxLevel: 2 });
  assert.equal(complete.state, "complete");
  const upgraded = startCityBuildingUpgrade(complete);
  assert.equal(upgraded?.level, 2);
  assert.equal(upgraded?.state, "complete");
  assert.equal(cityBuildingProgress(upgraded), 1);
});

test("invalid durations and max level are normalized safely", () => {
  const building = createCityBuildingProgression({
    constructionDuration: Number.NaN,
    upgradeDuration: -5,
    maxLevel: 0
  });
  assert.equal(building.constructionDuration, 30);
  assert.equal(building.upgradeDuration, 0);
  assert.equal(building.maxLevel, 1);
});
