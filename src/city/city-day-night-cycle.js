/**
 * Mshin city day/night standard.
 * A complete cycle lasts 330 real seconds: 300 seconds of daylight and
 * 30 seconds of night. The visual sun path remains 06:00–18:00.
 */
export const CITY_DAY_NIGHT_CYCLE = Object.freeze({
  daylightSeconds: 300,
  nightSeconds: 30,
  daylightStartMinute: 360,
  nightStartMinute: 1080,
  daylightMinutes: 720,
  nightMinutes: 720,
  cycleSeconds: 330
});

export function advanceCityDayNightClock(city, elapsedSeconds) {
  if (!city || !Number.isFinite(city.minuteOfDay) ||
      !Number.isFinite(elapsedSeconds) || elapsedSeconds < 0) {
    throw new TypeError("A city clock and non-negative elapsed time are required");
  }
  let remaining = elapsedSeconds;
  let minute = ((city.minuteOfDay % 1440) + 1440) % 1440;
  const dayRate = CITY_DAY_NIGHT_CYCLE.daylightMinutes / CITY_DAY_NIGHT_CYCLE.daylightSeconds;
  const nightRate = CITY_DAY_NIGHT_CYCLE.nightMinutes / CITY_DAY_NIGHT_CYCLE.nightSeconds;

  while (remaining > 1e-9) {
    const isDay = minute >= CITY_DAY_NIGHT_CYCLE.daylightStartMinute &&
      minute < CITY_DAY_NIGHT_CYCLE.nightStartMinute;
    const boundary = isDay
      ? CITY_DAY_NIGHT_CYCLE.nightStartMinute
      : CITY_DAY_NIGHT_CYCLE.daylightStartMinute;
    const distance = isDay
      ? boundary - minute
      : (boundary - minute + 1440) % 1440 || 1440;
    const rate = isDay ? dayRate : nightRate;
    const secondsToBoundary = distance / rate;
    if (remaining + 1e-9 >= secondsToBoundary) {
      minute = boundary;
      remaining -= secondsToBoundary;
    } else {
      minute += remaining * rate;
      remaining = 0;
    }
  }

  city.minuteOfDay = Math.floor(minute * 1000 + 1e-7) / 1000;
  return city.minuteOfDay;
}
