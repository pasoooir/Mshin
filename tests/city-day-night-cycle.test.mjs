import test from "node:test";
import assert from "node:assert/strict";
import { advanceCityDayNightClock, CITY_DAY_NIGHT_CYCLE } from "../src/city/city-day-night-cycle.js";

test("city clock stays permanently at midday regardless of elapsed time", () => {
  assert.equal(CITY_DAY_NIGHT_CYCLE.enabled, false);
  assert.equal(CITY_DAY_NIGHT_CYCLE.fixedMinute, 720);
  for (const initialMinute of [0, 360, 1080, 1439, 815]) {
    const city = { minuteOfDay: initialMinute };
    assert.equal(advanceCityDayNightClock(city, 1), 720);
    assert.equal(city.minuteOfDay, 720, "saved night or twilight time must normalize to midday");
    assert.equal(advanceCityDayNightClock(city, 86400), 720, "long sessions must never enter night");
  }
});

test("fixed daytime clock rejects invalid elapsed time without changing the city", () => {
  const city = { minuteOfDay: 815 };
  assert.throws(() => advanceCityDayNightClock(city, -1), /non-negative elapsed time/);
  assert.equal(city.minuteOfDay, 815);
  assert.throws(() => advanceCityDayNightClock(null, 1), /city clock/);
});
