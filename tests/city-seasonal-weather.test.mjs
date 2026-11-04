import test from "node:test";
import assert from "node:assert/strict";
import { CITY_SEASONAL_CYCLE, getCitySeasonalWeather } from "../src/city/city-seasonal-weather.js";

test("city advances through spring, summer, autumn and winter on a deterministic 28-day cycle", () => {
  const expected = ["spring", "summer", "autumn", "winter", "spring"];
  for (let index = 0; index < expected.length; index++) {
    assert.equal(getCitySeasonalWeather({ seed: 20261104, tick: index * 7 * 144 }).season, expected[index]);
  }
  assert.equal(CITY_SEASONAL_CYCLE.daysPerYear, 28);
});
test("weather is deterministic for a saved city and changes only at day boundaries", () => {
  const a = getCitySeasonalWeather({ seed: 77, tick: 144 * 9 + 143 });
  const b = getCitySeasonalWeather({ seed: 77, tick: 144 * 9 + 2 });
  const next = getCitySeasonalWeather({ seed: 77, tick: 144 * 10 });
  assert.deepEqual(a, b); assert.equal(next.day, a.day + 1); assert.equal(next.season, a.season);
});
test("all generated weather states have bounded intensity and wind", () => {
  for (let seed = 1; seed <= 250; seed++) for (let day = 0; day < 28; day++) {
    const state = getCitySeasonalWeather({ seed, tick: day * 144 });
    assert.ok(state.intensity >= 0 && state.intensity <= 1);
    assert.ok(state.wind >= 0 && state.wind <= 1.5);
    assert.ok(["clear", "rain", "wind", "heat", "snow", "frost"].includes(state.weather));
  }
});
test("missing or invalid clock data falls back safely to spring", () => {
  const state = getCitySeasonalWeather({ seed: NaN, tick: -1 });
  assert.equal(state.day, 0); assert.equal(state.season, "spring");
});
