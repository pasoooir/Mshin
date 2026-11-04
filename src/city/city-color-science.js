/**
 * Mshin 24-bit true-colour and atmospheric colour science.
 *
 * Authored colours are sRGB display values. Interpolation is performed in
 * linear-light RGB to avoid dark/dirty gradients, then encoded back to sRGB.
 * Every output is a full 8-bit-per-channel RGB value (16,777,216 possible).
 */
const SKY_STOPS = Object.freeze([
  [0,    "#071426", "#18283f", "#17243a"],
  [240,  "#152847", "#35435e", "#26334c"],
  [300,  "#554c70", "#a06c79", "#d08b83"],
  [345,  "#a66e79", "#d49a91", "#f1b58e"],
  [390,  "#c7a6a0", "#e5c7ae", "#ffe0b5"],
  [480,  "#80b8dc", "#b9d9e8", "#fff0d5"],
  [600,  "#5fa9dc", "#a6d2e8", "#fff3dc"],
  [720,  "#398fce", "#91c5e4", "#fff5df"],
  [900,  "#5b9dcc", "#a9c9dc", "#ffedcf"],
  [990,  "#d49a78", "#e8b89a", "#ffd19a"],
  [1050, "#b97978", "#d59b91", "#ffc18c"],
  [1110, "#594c70", "#9a7180", "#df9b86"],
  [1170, "#263451", "#50536e", "#b57f78"],
  [1260, "#101d35", "#26344e", "#5c586f"],
  [1440, "#071426", "#18283f", "#17243a"]
]);

const SEASON_TINT = Object.freeze({
  spring: "#e1eee9",
  summer: "#e2efff",
  autumn: "#f2d7c0",
  winter: "#dce7f4"
});

const WEATHER_TINT = Object.freeze({
  clear: "#ffffff",
  wind: "#e7edf0",
  rain: "#aebdca",
  heat: "#f2d5b2",
  snow: "#e3edf6",
  frost: "#d9e8f4"
});

function clamp01(value) {
  return Math.max(0, Math.min(1, value));
}

function hexToLinear(hex) {
  const value = hex.replace("#", "");
  const channels = [0, 2, 4].map(index => parseInt(value.slice(index, index + 2), 16) / 255);
  return channels.map(channel => channel <= 0.04045
    ? channel / 12.92
    : Math.pow((channel + 0.055) / 1.055, 2.4));
}

function linearToSrgb(channel) {
  const value = clamp01(channel);
  return value <= 0.0031308
    ? value * 12.92
    : 1.055 * Math.pow(value, 1 / 2.4) - 0.055;
}

function mixLinear(a, b, amount) {
  return a.map((value, index) => value + (b[index] - value) * amount);
}

function linearToHex(rgb) {
  return "#" + rgb.map(channel => Math.round(linearToSrgb(channel) * 255)
    .toString(16).padStart(2, "0")).join("");
}

function mixHexLinear(a, b, amount) {
  return linearToHex(mixLinear(hexToLinear(a), hexToLinear(b), clamp01(amount)));
}

function sampleStops(minute) {
  const time = ((Number(minute) || 0) % 1440 + 1440) % 1440;
  for (let index = 0; index < SKY_STOPS.length - 1; index++) {
    const left = SKY_STOPS[index];
    const right = SKY_STOPS[index + 1];
    if (time < left[0] || time > right[0]) continue;
    const amount = (time - left[0]) / (right[0] - left[0]);
    return [1, 2, 3].map(channel => mixHexLinear(left[channel], right[channel], amount));
  }
  return SKY_STOPS[0].slice(1);
}

/**
 * Returns continuously interpolated 24-bit sky colours for the current
 * minute, season and weather. zenith/horizon are used by the sky shader;
 * sunlight is the directional-light colour.
 */
export function getCityAtmosphericColors(minuteOfDay, season = "spring", weather = "clear") {
  const [zenith, horizon, sunlight] = sampleStops(minuteOfDay);
  const seasonTint = SEASON_TINT[season] || SEASON_TINT.spring;
  const weatherTint = WEATHER_TINT[weather] || WEATHER_TINT.clear;
  const seasonalAmount = season === "summer" ? 0.055 : season === "winter" ? 0.11 : 0.075;
  const weatherAmount = weather === "clear" ? 0 : weather === "rain" ? 0.30
    : weather === "snow" || weather === "frost" ? 0.16 : weather === "wind" ? 0.08 : 0.05;
  const sky = mixHexLinear(zenith, seasonTint, seasonalAmount);
  const horizonSeasonal = mixHexLinear(horizon, seasonTint, seasonalAmount * 0.72);
  const weatherSky = mixHexLinear(sky, weatherTint, weatherAmount);
  const weatherHorizon = mixHexLinear(horizonSeasonal, weatherTint, weatherAmount * 0.82);
  const sunWeather = mixHexLinear(sunlight, weatherTint, weatherAmount * 0.36);
  return Object.freeze({
    zenith: weatherSky,
    horizon: weatherHorizon,
    sunlight: sunWeather
  });
}

/** True-colour metadata for diagnostics and visual acceptance tests. */
export const CITY_COLOR_PIPELINE = Object.freeze({
  format: "RGB",
  bitsPerChannel: 8,
  bitDepth: 24,
  possibleColors: 16777216,
  authoringSpace: "sRGB",
  interpolationSpace: "linear-sRGB",
  outputSpace: "sRGB"
});
