const DAYS_PER_SEASON = 7;
const TICKS_PER_DAY = 144;
const SEASONS = Object.freeze([
  Object.freeze({ id: "spring", label: "بهار", sky: "#a9d9e9", foliage: ["#4ba65d", "#65b96a", "#8acb70"] }),
  Object.freeze({ id: "summer", label: "تابستان", sky: "#82c6eb", foliage: ["#328c4d", "#4da653", "#70b85b"] }),
  Object.freeze({ id: "autumn", label: "پاییز", sky: "#d7b28f", foliage: ["#b66b3e", "#d18a45", "#e0aa58"] }),
  Object.freeze({ id: "winter", label: "زمستان", sky: "#b7c9dc", foliage: ["#718f83", "#8da99a", "#a9bcb0"] })
]);
function hashDay(seed, day) {
  let value = (Math.imul((seed >>> 0) || 1, 0x45d9f3b) ^ Math.imul(day + 1, 0x119de1f3)) >>> 0;
  value ^= value >>> 16; value = Math.imul(value, 0x7feb352d) >>> 0; value ^= value >>> 15;
  return value >>> 0;
}
/** Deterministic 28-day year; the same saved city always gets the same weather each day. */
export function getCitySeasonalWeather(city = {}) {
  const tick = Number.isSafeInteger(city.tick) && city.tick > 0 ? city.tick : 0;
  const day = Math.floor(tick / TICKS_PER_DAY);
  const seasonIndex = Math.floor(day / DAYS_PER_SEASON) % SEASONS.length;
  const season = SEASONS[seasonIndex];
  const roll = hashDay(Number.isFinite(city.seed) ? city.seed : 1, day) % 100;
  let weather = "clear";
  if (seasonIndex === 0) weather = roll < 34 ? "rain" : roll < 50 ? "wind" : "clear";
  else if (seasonIndex === 1) weather = roll < 22 ? "heat" : roll < 30 ? "rain" : "clear";
  else if (seasonIndex === 2) weather = roll < 40 ? "wind" : roll < 58 ? "rain" : "clear";
  else weather = roll < 48 ? "snow" : roll < 68 ? "frost" : "clear";
  const intensity = weather === "clear" ? 0 : 0.42 + hashDay(Number(city.seed) || 1, day + 97) % 59 / 100;
  return Object.freeze({
    day, dayOfSeason: day % DAYS_PER_SEASON, seasonIndex, season: season.id,
    seasonLabel: season.label, weather, intensity: Number(intensity.toFixed(2)),
    wind: weather === "wind" ? Number((0.45 + intensity * 0.8).toFixed(2))
      : weather === "rain" || weather === "snow" ? Number((0.2 + intensity * 0.35).toFixed(2)) : 0,
    sky: season.sky
  });
}
export const CITY_SEASONAL_CYCLE = Object.freeze({ daysPerSeason: DAYS_PER_SEASON, ticksPerDay: TICKS_PER_DAY, daysPerYear: 28, seasons: SEASONS });
