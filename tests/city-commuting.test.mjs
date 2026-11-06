import test from "node:test";
import assert from "node:assert/strict";
import { createInitialCity, placeCityItem, stepCity, isValidCitySave } from "../src/city/city-view.js";
import { computeCityEmployment } from "../src/city/city-employment.js";
import { computeCityCommuting } from "../src/city/city-commuting.js";

function seedCityRoadAccess(city){for(let x=10;x<=28;x++){placeCityItem(city,x,12,"road");placeCityItem(city,x,15,"road")}return city}

function connectedWorkCity(seed = 3101) {
  const city = seedCityRoadAccess(createInitialCity(seed));
  const home = placeCityItem(city,17,14,"home");
  const shop = placeCityItem(city,18,14,"shop");
  const industrial = placeCityItem(city,19,14,"industrial");
  assert.equal(home.ok,true);
  assert.equal(shop.ok,true);
  assert.equal(industrial.ok,true);
  return { city, home: home.item, shop: shop.item, industrial: industrial.item };
}

test("residents are assigned to reachable workplaces through shortest road routes", () => {
  const { city, home, shop, industrial } = connectedWorkCity();
  const employment = computeCityEmployment(city);
  const result = computeCityCommuting(city,employment);
  assert.equal(result.assignedWorkers,employment.employed);
  assert.equal(result.unreachableWorkers,0);
  assert.equal(result.commuteCoverage,100);
  assert.ok(result.assignments.length > 0);
  assert.ok(result.assignments.every(flow => flow.homeId === home.id));
  assert.ok(result.assignments.every(flow => [shop.id,industrial.id].includes(flow.workplaceId)));
  assert.ok(result.assignments.every(flow => flow.route.length === flow.distance + 1));
  assert.ok(result.assignments.every(flow => flow.route.every(point => city.grid[point.y][point.x] === "road")));
  assert.ok(result.averageCommuteDistance >= 0);
});

test("disconnected road islands do not create impossible commutes", () => {
  const { city } = connectedWorkCity(3102);
  for (const row of city.grid) row.fill("grass");
  city.grid[14][16] = "road"; // home access
  city.grid[15][18] = "road"; // workplace access, isolated from home
  const employment = computeCityEmployment(city);
  const result = computeCityCommuting(city,employment);
  assert.equal(result.assignedWorkers,0);
  assert.equal(result.unreachableWorkers,employment.employed);
  assert.equal(result.commuteCoverage,0);
  assert.equal(result.assignments.length,0);
});

test("commute assignment respects sector employment and workplace capacity", () => {
  const { city } = connectedWorkCity(3103);
  const secondHome = placeCityItem(city,22,14,"home");
  const secondShop = placeCityItem(city,25,14,"shop");
  assert.equal(secondHome.ok,true);
  assert.equal(secondShop.ok,true);
  city.population = 72;
  const employment = computeCityEmployment(city);
  const result = computeCityCommuting(city,employment);
  const byWorkplace = new Map();
  for (const flow of result.assignments) {
    byWorkplace.set(flow.workplaceId,(byWorkplace.get(flow.workplaceId)||0)+flow.workers);
  }
  assert.ok(result.assignedWorkers <= employment.employed);
  for (const [id,workers] of byWorkplace) {
    const workplace = city.buildings.find(building => building.id === id);
    assert.ok(workers <= ({shop:9,industrial:18,administrative:12,service:6}[workplace.type]));
  }
  assert.equal(result.assignedWorkers + result.unreachableWorkers,employment.employed);
});

test("commute assignments are deterministic and integrated into city simulation stats", () => {
  const simulate = () => {
    const { city } = connectedWorkCity(3104);
    city.population = 24;
    stepCity(city);
    return city;
  };
  const first = simulate(), second = simulate();
  assert.deepEqual(first.stats.commuteAssignments,undefined,
    "route details remain outside persisted city stats to keep mobile saves compact");
  assert.equal(first.stats.commutingWorkers,first.stats.employed);
  assert.equal(first.stats.commuteCoverage,100);
  assert.ok(first.stats.averageCommuteDistance >= 0);
  assert.equal(first.stats.unreachableWorkers,0);
  const a = computeCityCommuting(first,computeCityEmployment(first));
  const b = computeCityCommuting(second,computeCityEmployment(second));
  assert.deepEqual(a,b);
});

test("commute telemetry is bounded and validated in city saves", () => {
  const { city } = connectedWorkCity(3105);
  city.population = 24;
  stepCity(city);
  assert.equal(isValidCitySave(city),true);
  const invalidCoverage = structuredClone(city);
  invalidCoverage.stats.commuteCoverage = 101;
  assert.equal(isValidCitySave(invalidCoverage),false);
  const invalidWorkers = structuredClone(city);
  invalidWorkers.stats.commutingWorkers = -1;
  assert.equal(isValidCitySave(invalidWorkers),false);
  const invalidDistance = structuredClone(city);
  invalidDistance.stats.averageCommuteDistance = -0.1;
  assert.equal(isValidCitySave(invalidDistance),false);
});


test("commute traffic delay is zero on clear roads and bounded under congestion", () => {
  const { city } = connectedWorkCity(3106);
  city.population = 24;
  const clear = computeCityCommuting(city, computeCityEmployment(city));
  assert.equal(clear.averageCongestionDelay, 0);
  const routePoint = clear.assignments[0].route[Math.floor(clear.assignments[0].route.length / 2)];
  city.traffic = Array.from({ length: 8 }, (_, index) => ({
    id: index + 1, x: routePoint.x, y: routePoint.y
  }));
  const congested = computeCityCommuting(city, computeCityEmployment(city));
  assert.ok(congested.averageCongestionDelay > 0);
  assert.ok(congested.averageCongestionDelay <= 150);
  assert.equal(congested.assignedWorkers, clear.assignedWorkers,
    "traffic changes commute burden, not the underlying job assignment");
});

test("congestion delay is persisted safely and feeds a bounded resident wellbeing penalty", () => {
  const { city } = connectedWorkCity(3107);
  city.population = 24;
  city.happiness = 70; // Keep the comparison below the happiness ceiling so the marginal penalty is observable.
  const baseline = structuredClone(city);
  const route = computeCityCommuting(city, computeCityEmployment(city)).assignments[0].route;
  const point = route[Math.floor(route.length / 2)];
  const congested = structuredClone(city);
  congested.traffic = [{
    id: 1, x: point.x, y: point.y, speed: 0.4, heading: 0,
    headingX: 1, headingY: 0, routeStep: 0, color: "#fff",
    targetX: null, targetY: null, previousX: null, previousY: null
  }];
  stepCity(baseline);
  stepCity(congested);
  assert.ok(congested.stats.averageCongestionDelay > 0);
  assert.ok(congested.happiness < baseline.happiness,
    "residents should experience a small wellbeing cost when their commutes are congested");
  assert.ok(congested.happiness >= 25);
  // Validate the persisted telemetry independently of transient vehicle positions.
  congested.traffic = [];
  assert.equal(isValidCitySave(congested), true);
  const invalid = structuredClone(congested);
  invalid.stats.averageCongestionDelay = 151;
  assert.equal(isValidCitySave(invalid), false);
});
