import test from "node:test";
import assert from "node:assert/strict";
import { advanceCityDayNightClock, CITY_DAY_NIGHT_CYCLE } from "../src/city/city-day-night-cycle.js";

test("daylight lasts five real minutes before the short night begins", () => {
  const city = { minuteOfDay: 360 };
  advanceCityDayNightClock(city, CITY_DAY_NIGHT_CYCLE.daylightSeconds - 0.01);
  assert.ok(city.minuteOfDay < 1080, "the city must remain in daylight for the full five minutes");
  advanceCityDayNightClock(city, 0.01);
  assert.equal(city.minuteOfDay, 1080, "night starts exactly after 300 seconds of daylight");
});

test("night lasts thirty seconds and returns to daylight", () => {
  const city = { minuteOfDay: 1080 };
  advanceCityDayNightClock(city, CITY_DAY_NIGHT_CYCLE.nightSeconds - 0.01);
  assert.ok(city.minuteOfDay > 1080, "night must remain active until its full duration elapses");
  advanceCityDayNightClock(city, 0.01);
  assert.equal(city.minuteOfDay, 360, "day starts exactly after 30 seconds of night");
});

test("large elapsed intervals preserve the 300:30 day-to-night ratio", () => {
  const city = { minuteOfDay: 360 };
  advanceCityDayNightClock(city, CITY_DAY_NIGHT_CYCLE.cycleSeconds);
  assert.equal(city.minuteOfDay, 360);
  advanceCityDayNightClock(city, CITY_DAY_NIGHT_CYCLE.cycleSeconds * 3);
  assert.equal(city.minuteOfDay, 360);
});

test("clock rejects invalid elapsed time without corrupting city time", () => {
  const city = { minuteOfDay: 720 };
  assert.throws(() => advanceCityDayNightClock(city, -1), /non-negative elapsed time/);
  assert.equal(city.minuteOfDay, 720);
});
