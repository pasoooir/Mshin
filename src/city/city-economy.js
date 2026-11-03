export const CITY_DEFAULT_TAX_RATES = Object.freeze({
  residential: 8,
  commercial: 10,
  industrial: 12
});
export const CITY_TAX_RATE_LIMIT = 20;

const clampRate = value => Math.max(0, Math.min(CITY_TAX_RATE_LIMIT, Math.round(value)));

export function normalizeCityTaxRates(value) {
  const rates = {};
  for (const sector of Object.keys(CITY_DEFAULT_TAX_RATES)) {
    const candidate = value?.[sector];
    rates[sector] = Number.isFinite(candidate)
      ? clampRate(candidate)
      : CITY_DEFAULT_TAX_RATES[sector];
  }
  return rates;
}

/** Change one sector's tax rate without allowing invalid or unbounded save data. */
export function setCityTaxRate(city, sector, value) {
  if (!city || typeof city !== "object" || !Object.hasOwn(CITY_DEFAULT_TAX_RATES, sector)
    || !Number.isFinite(value) || value < 0 || value > CITY_TAX_RATE_LIMIT) {
    return { ok: false, reason: "نرخ مالیات معتبر نیست" };
  }
  city.taxRates = normalizeCityTaxRates(city.taxRates);
  city.taxRates[sector] = clampRate(value);
  return { ok: true, sector, rate: city.taxRates[sector] };
}

/**
 * Calculate a deterministic per-tick city budget. Tax income scales from the
 * original balanced rates; public funding and upkeep remain explicit line items.
 */
export function computeCityEconomy(city, infrastructure = {}) {
  if (!city || !Array.isArray(city.buildings) || !Number.isFinite(city.population)
    || city.population < 0) {
    throw new TypeError("A valid city economy state is required");
  }
  const rates = normalizeCityTaxRates(city.taxRates);
  const buildings = city.buildings;
  const count = type => buildings.filter(building => building.type === type).length;
  const homes = count("home");
  const shops = count("shop");
  const industrial = count("industrial");
  const administrative = count("administrative");
  const services = count("service");
  const parks = count("park");

  const residentialTax = Math.round(city.population * (13 / 12) * rates.residential / CITY_DEFAULT_TAX_RATES.residential);
  const commercialTax = Math.round(shops * 46 * rates.commercial / CITY_DEFAULT_TAX_RATES.commercial);
  const industrialTax = Math.round(industrial * 72 * rates.industrial / CITY_DEFAULT_TAX_RATES.industrial);
  const publicFunding = administrative * 28;
  const serviceFees = services * 8;
  const taxRevenue = residentialTax + commercialTax + industrialTax;
  const income = taxRevenue + publicFunding + serviceFees;
  const maintenance = parks * 7 + industrial * 24 + administrative * 12 + buildings.length * 2;
  const serviceUpkeep = services * 31 + (Number.isFinite(infrastructure.upkeep) ? infrastructure.upkeep : 0);
  const expenses = maintenance + serviceUpkeep;

  return {
    income,
    expenses,
    net: income - expenses,
    taxRevenue,
    residentialTax,
    commercialTax,
    industrialTax,
    publicFunding,
    serviceFees,
    maintenance,
    serviceUpkeep,
    rates,
    taxableResidents: city.population,
    taxableShops: shops,
    taxableFactories: industrial,
    residentialBuildings: homes
  };
}

export function cityTaxPressure(value) {
  const rates = normalizeCityTaxRates(value);
  return (Math.max(0, rates.residential - CITY_DEFAULT_TAX_RATES.residential) * 0.015)
    + (Math.max(0, rates.commercial - CITY_DEFAULT_TAX_RATES.commercial) * 0.015)
    + (Math.max(0, rates.industrial - CITY_DEFAULT_TAX_RATES.industrial) * 0.015);
}
