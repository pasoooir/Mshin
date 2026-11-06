/**
 * Mshin city environment is locked to permanent midday until the city reaches
 * a stable release. Keep the public clock hook so existing callers remain compatible.
 */
export const CITY_DAY_NIGHT_CYCLE = Object.freeze({ enabled: false, fixedMinute: 720 });

export function advanceCityDayNightClock(city, elapsedSeconds) {
  if (!city || typeof city !== "object" || !Number.isFinite(elapsedSeconds) || elapsedSeconds < 0) {
    throw new TypeError("A city clock and non-negative elapsed time are required");
  }
  city.minuteOfDay = CITY_DAY_NIGHT_CYCLE.fixedMinute;
  return city.minuteOfDay;
}
