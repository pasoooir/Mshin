import { chromium } from "playwright";
import assert from "node:assert/strict";
import fs from "node:fs";
import { getCitySeasonalWeather } from "../src/city/city-seasonal-weather.js";

const browser = await chromium.launch({ headless: true, args: ["--no-sandbox", "--disable-dev-shm-usage", "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
const context = await browser.newContext({ viewport: { width: 844, height: 390 }, screen: { width: 844, height: 390 }, isMobile: true, hasTouch: true, serviceWorkers: "block" });
const page = await context.newPage();
const errors = [];
page.on("pageerror", error => errors.push(error.stack || String(error)));
try {
  fs.mkdirSync("artifacts", { recursive: true });
  await page.goto("http://127.0.0.1:4173/city.html", { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.MshinCity3DReady === true, { timeout: 25000 });
  const seed = 20261104;
  const seasons = [
    { day: 0, season: "spring", file: "city-season-spring.png" },
    { day: 7, season: "summer", file: "city-season-summer.png" },
    { day: 14, season: "autumn", file: "city-season-autumn.png" },
    { day: 21, season: "winter", file: "city-season-winter.png" }
  ];
  for (const item of seasons) {
    const result = await page.evaluate(({ day, seed }) => {
      const city = window.MshinCityDebug.city;
      city.seed = seed; city.tick = day * 144; city.minuteOfDay = 720;
      window.MshinCityDebug.draw();
      return window.MshinCity3DStats.weather;
    }, { day: item.day, seed });
    assert.equal(result.season, item.season, "the 3D renderer must expose the expected season");
    assert.equal(result.seasonLabel.length > 0, true);
    assert.ok(result.intensity >= 0 && result.intensity <= 1);
    await page.screenshot({ path: "artifacts/" + item.file });
  }
  const springRainDay = Array.from({ length: 7 }, (_, day) => day).find(day => getCitySeasonalWeather({ seed, tick: day * 144 }).weather === "rain");
  const winterSnowDay = Array.from({ length: 7 }, (_, day) => day + 21).find(day => getCitySeasonalWeather({ seed, tick: day * 144 }).weather === "snow");
  assert.notEqual(springRainDay, undefined, "fixture seed must include spring rain");
  assert.notEqual(winterSnowDay, undefined, "fixture seed must include winter snow");
  const rain = await page.evaluate(day => {
    const city = window.MshinCityDebug.city; city.tick = day * 144; city.minuteOfDay = 720;
    window.MshinCityDebug.draw(); return window.MshinCity3DStats.weather;
  }, springRainDay);
  assert.equal(rain.weather, "rain"); assert.equal(rain.rainVisible, true);
  await page.screenshot({ path: "artifacts/city-weather-rain.png" });
  const snow = await page.evaluate(day => {
    const city = window.MshinCityDebug.city; city.tick = day * 144; city.minuteOfDay = 720;
    window.MshinCityDebug.draw(); return window.MshinCity3DStats.weather;
  }, winterSnowDay);
  assert.equal(snow.weather, "snow"); assert.equal(snow.snowVisible, true);
  await page.screenshot({ path: "artifacts/city-weather-snow.png" });
  assert.deepEqual(errors, [], "seasonal city renderer must not emit browser runtime errors");
  console.log("Four seasons, spring rain and winter snow rendered successfully.");
} finally {
  await context.close();
  await browser.close();
}
