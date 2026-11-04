import test from "node:test";
import assert from "node:assert/strict";
import { getCityCloudLighting } from "../src/city/city-cloud-layer.js";
import { readFile } from "node:fs/promises";

test("procedural cloud shell is animated, weather-aware, and releases GPU resources", async () => {
  const source = await readFile(new URL("../src/city/city-cloud-layer.js", import.meta.url), "utf8");
  assert.match(source, /SphereGeometry\(875, 48, 32\)/);
  assert.match(source, /for \(int octave = 0; octave < 5; octave\+\+\)/);
  assert.match(source, /uTime/);
  assert.match(source, /weather === "rain"/);
  assert.match(source, /weather === "snow"/);
  assert.match(source, /geometry\.dispose\(\)/);
  assert.match(source, /material\.dispose\(\)/);
});

test("cloud layer is connected to the live renderer and offline app shell", async () => {
  const renderer = await readFile(new URL("../src/city/city-three-renderer.js", import.meta.url), "utf8");
  const worker = await readFile(new URL("../service-worker.js", import.meta.url), "utf8");
  assert.match(renderer, /createCityCloudLayer/);
  assert.match(renderer, /cloudLayer\.update\(city, atmosphere\.getStats\(\)\)/);
  assert.match(renderer, /cloudLayer\.dispose\(\)/);
  assert.match(worker, /\.\/src\/city\/city-cloud-layer\.js/);
});

test("cloud lighting preserves midnight and wraps the simulation clock", () => {
  const midnight = getCityCloudLighting({ minuteOfDay: 0 }, { weather: { weather: "clear", intensity: 0 } });
  const noon = getCityCloudLighting({ minuteOfDay: 720 }, { weather: { weather: "clear", intensity: 0 } });
  const wrapped = getCityCloudLighting({ minuteOfDay: 1440 }, { weather: { weather: "clear", intensity: 0 } });
  assert.equal(midnight.daylight, 0, "midnight must shade clouds as night, not default to noon");
  assert.equal(noon.daylight, 1, "noon must retain full cloud daylight");
  assert.equal(wrapped.daylight, 0, "24:00 must wrap to midnight");
  assert.equal(midnight.minute, 0);
  assert.equal(wrapped.minute, 0);
});
