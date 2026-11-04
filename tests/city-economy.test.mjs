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


test("commute congestion reduces only business productivity with a strict 15% cap", () => {
  const city = createInitialCity(1106);
  city.population = 12;
  assert.equal(placeCityItem(city, 17, 14, "home").ok, true);
  assert.equal(placeCityItem(city, 18, 14, "shop").ok, true);
  assert.equal(placeCityItem(city, 19, 14, "industrial").ok, true);
  assert.equal(placeCityItem(city, 18, 17, "administrative").ok, true);
  const clear = computeCityEconomy(city, {}, { averageCongestionDelay: 0 });
  const delayed = computeCityEconomy(city, {}, { averageCongestionDelay: 100 });
  const severe = computeCityEconomy(city, {}, { averageCongestionDelay: 150 });
  assert.equal(clear.commuteProductivityPercent, 100);
  assert.equal(clear.commuteEconomicLoss, 0);
  assert.equal(delayed.commuteProductivityPercent, 90);
  assert.ok(delayed.commuteEconomicLoss > 0);
  assert.equal(delayed.residentialTax, clear.residentialTax);
  assert.equal(delayed.publicFunding, clear.publicFunding);
  assert.ok(delayed.commercialTax < clear.commercialTax);
  assert.ok(delayed.industrialTax < clear.industrialTax);
  assert.equal(severe.commuteProductivityPercent, 85);
  assert.ok(severe.commuteEconomicLoss >= delayed.commuteEconomicLoss);
  const invalidHigh = computeCityEconomy(city, {}, { averageCongestionDelay: 999 });
  const invalidLow = computeCityEconomy(city, {}, { averageCongestionDelay: -10 });
  assert.equal(invalidHigh.commuteProductivityPercent, 85);
  assert.equal(invalidLow.commuteProductivityPercent, 100);
});

test("city simulation applies the cached commute productivity metric to its budget and save", () => {
  const city = createInitialCity(1107);
  const home = placeCityItem(city, 17, 14, "home");
  const shop = placeCityItem(city, 18, 14, "shop");
  const factory = placeCityItem(city, 19, 14, "industrial");
  assert.equal(home.ok, true);
  assert.equal(shop.ok, true);
  assert.equal(factory.ok, true);
  city.population = 24;
  city.traffic = [{ id: 1, x: 16, y: 15, speed: 0.4, heading: 0, headingX: 1, headingY: 0,
    routeStep: 0, color: "#fff", targetX: null, targetY: null, previousX: null, previousY: null }];
  stepCity(city);
  assert.ok(city.stats.averageCongestionDelay > 0);
  assert.ok(city.stats.commuteProductivityPercent < 100);
  assert.ok(city.stats.commuteEconomicLoss > 0);
  // Keep this assertion focused on the persisted economic metrics, not transient vehicle coordinates.
  city.traffic = [];
  assert.equal(isValidCitySave(city), true);
  const invalid = structuredClone(city);
  invalid.stats.commuteProductivityPercent = 84;
  assert.equal(isValidCitySave(invalid), false);
});

test("rain and snow weather reduce business output while leaving resident and public income unchanged", () => {
  const city = createInitialCity(20261104);
  placeCityItem(city, 17, 14, "home");
  placeCityItem(city, 18, 14, "shop");
  placeCityItem(city, 19, 14, "industrial");
  placeCityItem(city, 18, 17, "administrative");
  city.population = 24;
  city.tick = 4 * 144;
  const rainy = computeCityEconomy(city, {}, { averageCongestionDelay: 0 });
  assert.equal(rainy.weather, "rain");
  assert.ok(rainy.weatherEconomicLoss > 0);
  assert.ok(rainy.weatherProductivityPercent < 100);
  city.tick = 23 * 144;
  const snowy = computeCityEconomy(city, {}, { averageCongestionDelay: 0 });
  assert.equal(snowy.weather, "snow");
  assert.ok(snowy.weatherEconomicLoss > rainy.weatherEconomicLoss);
  assert.equal(snowy.residentialTax, rainy.residentialTax);
  assert.equal(snowy.publicFunding, rainy.publicFunding);
});
