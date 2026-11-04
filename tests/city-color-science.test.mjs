import test from "node:test";
import assert from "node:assert/strict";
import { CITY_COLOR_PIPELINE, getCityAtmosphericColors } from "../src/city/city-color-science.js";

test("city output pipeline explicitly supports 24-bit RGB true colour", () => {
  assert.deepEqual(CITY_COLOR_PIPELINE, {
    format: "RGB", bitsPerChannel: 8, bitDepth: 24,
    possibleColors: 16777216, authoringSpace: "sRGB",
    interpolationSpace: "linear-sRGB", outputSpace: "sRGB"
  });
});

test("sky and horizon use full six-digit 24-bit sRGB colours", () => {
  for (const minute of [0, 300, 390, 720, 990, 1110, 1439]) {
    const colors = getCityAtmosphericColors(minute, "summer", "clear");
    for (const key of ["zenith", "horizon", "sunlight"]) {
      assert.match(colors[key], /^#[0-9a-f]{6}$/i, key + " must be 24-bit sRGB");
    }
  }
});

test("sky transitions are continuous and produce a broad range of true-colour values", () => {
  const samples = new Set();
  for (let minute = 0; minute < 1440; minute += 2) {
    samples.add(getCityAtmosphericColors(minute, "spring", "clear").zenith);
  }
  assert.ok(samples.size > 300, "continuous daily sky curve must not collapse to a small fixed palette");
  for (let minute = 1; minute < 1440; minute++) {
    const before = getCityAtmosphericColors(minute - 1).zenith;
    const after = getCityAtmosphericColors(minute).zenith;
    const delta = before.slice(1).match(/../g).map((v, i) =>
      Math.abs(parseInt(v, 16) - parseInt(after.slice(1).match(/../g)[i], 16)));
    assert.ok(Math.max(...delta) < 18, "one-minute sky transitions must not visibly jump");
  }
});

test("seasons and weather influence colour without reducing colour depth", () => {
  const clear = getCityAtmosphericColors(720, "summer", "clear");
  const rain = getCityAtmosphericColors(720, "summer", "rain");
  const winter = getCityAtmosphericColors(720, "winter", "snow");
  assert.notEqual(clear.zenith, rain.zenith);
  assert.notEqual(clear.horizon, winter.horizon);
  assert.match(rain.sunlight, /^#[0-9a-f]{6}$/i);
});
