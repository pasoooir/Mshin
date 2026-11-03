import test from "node:test";
import assert from "node:assert/strict";
import { createInitialCity, placeCityItem, stepCity, isValidCitySave, normalizeCitySave } from "../src/city/city-view.js";
import { CITY_DEFAULT_TAX_RATES, computeCityEconomy, setCityTaxRate, cityTaxPressure } from "../src/city/city-economy.js";

test("default sector tax rates preserve the established residential income baseline", () => {
  const city = createInitialCity(1101);
  placeCityItem(city, 17, 14, "home");
  const economy = computeCityEconomy(city);
  assert.deepEqual(city.taxRates, CITY_DEFAULT_TAX_RATES);
  assert.equal(economy.residentialTax, 13);
  assert.equal(economy.taxRevenue, 13);
  assert.equal(economy.income, 13);
  assert.equal(economy.expenses, 2);
  assert.equal(economy.net, 11);
});

test("sector tax changes deterministically scale the matching revenue stream", () => {
  const city = createInitialCity(1102);
  placeCityItem(city, 17, 14, "home");
  placeCityItem(city, 18, 14, "shop");
  placeCityItem(city, 19, 14, "industrial");
  const baseline = computeCityEconomy(city);
  assert.equal(setCityTaxRate(city, "residential", 16).ok, true);
  assert.equal(setCityTaxRate(city, "commercial", 15).ok, true);
  assert.equal(setCityTaxRate(city, "industrial", 6).ok, true);
  const adjusted = computeCityEconomy(city);
  assert.equal(adjusted.residentialTax, baseline.residentialTax * 2);
  assert.equal(adjusted.commercialTax, Math.round(baseline.commercialTax * 1.5));
  assert.equal(adjusted.industrialTax, Math.round(baseline.industrialTax * .5));
  assert.ok(cityTaxPressure(city.taxRates) > 0);
  assert.equal(cityTaxPressure(CITY_DEFAULT_TAX_RATES), 0);
});

test("invalid sector names and out-of-range rates are rejected without changing tax policy", () => {
  const city = createInitialCity(1103);
  const before = structuredClone(city.taxRates);
  for (const [sector, rate] of [["unknown", 10], ["residential", -1], ["commercial", 21], ["industrial", NaN]]) {
    assert.equal(setCityTaxRate(city, sector, rate).ok, false);
  }
  assert.deepEqual(city.taxRates, before);
});

test("tax policy persists and legacy saves receive safe defaults", () => {
  const city = createInitialCity(1104);
  placeCityItem(city, 17, 14, "home");
  setCityTaxRate(city, "residential", 14);
  stepCity(city);
  assert.equal(isValidCitySave(city), true);
  const restored = normalizeCitySave(JSON.parse(JSON.stringify(city)));
  assert.deepEqual(restored.taxRates, city.taxRates);
  const legacy = structuredClone(city);
  delete legacy.taxRates;
  const migrated = normalizeCitySave(legacy);
  assert.deepEqual(migrated.taxRates, CITY_DEFAULT_TAX_RATES);
  assert.equal(isValidCitySave(migrated), true);
});

test("economy output and treasury changes remain deterministic", () => {
  const simulate = () => {
    const city = createInitialCity(1105);
    placeCityItem(city, 17, 14, "home");
    placeCityItem(city, 18, 14, "shop");
    for (let i = 0; i < 24; i++) stepCity(city);
    return { treasury: city.treasury, stats: city.stats, population: city.population };
  };
  assert.deepEqual(simulate(), simulate());
});
