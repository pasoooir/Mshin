import test from "node:test";
import assert from "node:assert/strict";
import { createInitialCity, placeCityItem, stepCity, isValidCitySave, normalizeCitySave } from "../src/city/city-view.js";
import { CITY_MAX_CITIZEN_AGENTS, syncCityCitizens, stepCityCitizens } from "../src/city/city-population.js";
import { computeCityEmployment } from "../src/city/city-employment.js";
import { computeCityCommuting } from "../src/city/city-commuting.js";

test("residential occupancy creates a bounded pedestrian population on connected roads", () => {
  const city = createInitialCity(901);
  const placed = placeCityItem(city, 17, 14, "home");
  assert.equal(placed.ok, true);
  assert.equal(city.population, 12);
  assert.equal(city.citizens.length, 4);
  assert.ok(city.citizens.every(citizen => citizen.homeId === placed.item.id));
  assert.ok(city.citizens.every(citizen => city.grid[citizen.roadY]?.[citizen.roadX] === "road"));
  assert.ok(city.citizens.every(citizen => city.grid[Math.round(citizen.y)]?.[Math.round(citizen.x)] === "road"));
  assert.equal(new Set(city.citizens.map(citizen => citizen.id)).size, city.citizens.length);
  assert.equal(isValidCitySave(city), true);
});

test("pedestrians move deterministically along connected road routes", () => {
  const simulate = () => {
    const city = createInitialCity(902);
    placeCityItem(city, 17, 14, "home");
    for (let tick = 0; tick < 96; tick++) stepCity(city);
    return city;
  };
  const first = simulate();
  const second = simulate();
  assert.deepEqual(first.citizens, second.citizens);
  assert.ok(first.citizens.some(citizen => citizen.routeStep > 0), "citizens must progress beyond their starting road tile");
  assert.ok(first.citizens.every(citizen => first.grid[citizen.roadY]?.[citizen.roadX] === "road"));
  assert.ok(first.citizens.every(citizen => first.grid[Math.round(citizen.y)]?.[Math.round(citizen.x)] === "road"));
  assert.equal(isValidCitySave(first), true);
});

test("pedestrian agents remain capped and reconcile when residential population falls", () => {
  const city = createInitialCity(903);
  const homes = [[6,6],[9,6],[14,6],[17,6],[22,6],[25,6],[6,9],[9,9]];
  for (const [x, y] of homes) assert.equal(placeCityItem(city, x, y, "home").ok, true);
  city.population = 10000;
  syncCityCitizens(city);
  assert.equal(city.citizens.length, CITY_MAX_CITIZEN_AGENTS);
  const removedHome = city.buildings[0];
  city.buildings = city.buildings.filter(building => building.id !== removedHome.id);
  city.grid[removedHome.y][removedHome.x] = "grass";
  city.population -= removedHome.residents;
  syncCityCitizens(city);
  const remainingHomeIds = new Set(city.buildings.map(building => building.id));
  assert.ok(city.citizens.every(citizen => remainingHomeIds.has(citizen.homeId)), "citizens from a demolished home must be reassigned to a remaining residence");
  city.population = 0;
  syncCityCitizens(city);
  assert.equal(city.citizens.length, 0);
  assert.equal(isValidCitySave(city), true);
});

test("demolishing a home reassigns surviving pedestrians to an occupied home", () => {
  const city = createInitialCity(906);
  const first = placeCityItem(city, 17, 14, "home");
  const second = placeCityItem(city, 22, 14, "home");
  assert.equal(first.ok, true);
  assert.equal(second.ok, true);
  assert.ok(city.citizens.some(citizen => citizen.homeId === first.item.id));
  city.buildings = city.buildings.filter(building => building.id !== first.item.id);
  city.grid[first.item.y][first.item.x] = "grass";
  city.population -= first.item.residents;
  syncCityCitizens(city);
  assert.ok(city.citizens.every(citizen => citizen.homeId === second.item.id));
  assert.ok(city.citizens.every(citizen => city.grid[citizen.roadY]?.[citizen.roadX] === "road"));
  assert.equal(isValidCitySave(city), true);
});

test("legacy citizen saves are normalized into road-agent state without breaking compatibility", () => {
  const city = createInitialCity(904);
  placeCityItem(city, 17, 14, "home");
  city.citizens = [{ id: 1, x: 17, y: 7, phase: 0, pace: 0.1 }];
  delete city.nextCitizenId;
  const normalized = normalizeCitySave(city);
  assert.equal(normalized.nextCitizenId, 2);
  assert.equal(normalized.citizens[0].homeId, 1);
  assert.equal(normalized.citizens[0].roadX, 17);
  assert.equal(normalized.citizens[0].roadY, 7);
  assert.equal(isValidCitySave(normalized), true);
  stepCityCitizens(normalized, 5);
  assert.ok(normalized.citizens[0].routeStep >= 0);
});

test("invalid citizen route coordinates are rejected by city save validation", () => {
  const city = createInitialCity(905);
  placeCityItem(city, 17, 14, "home");
  city.citizens[0].targetX = 32;
  city.citizens[0].targetY = 7;
  assert.equal(isValidCitySave(city), false);
  city.citizens[0].targetX = null;
  city.citizens[0].targetY = 7;
  assert.equal(isValidCitySave(city), false, "partially null route pairs must be rejected");
});


test("demolished homes remove their pedestrian agents and invalid home references are rejected", () => {
  const city = createInitialCity(906);
  const firstHome = placeCityItem(city, 17, 14, "home").item;
  const secondHome = placeCityItem(city, 17, 13, "home").item;
  assert.equal(city.citizens.length, 8);
  city.buildings = city.buildings.filter(building => building.id !== firstHome.id);
  city.grid[firstHome.y][firstHome.x] = "grass";
  city.population -= firstHome.residents;
  syncCityCitizens(city);
  assert.equal(city.citizens.length, 4);
  assert.ok(city.citizens.every(citizen => citizen.homeId === secondHome.id));
  assert.equal(isValidCitySave(city), true);
  const invalid = structuredClone(city);
  invalid.citizens[0].homeId = firstHome.id;
  assert.equal(isValidCitySave(invalid), false);
});


test("assigned pedestrian workers travel to workplaces and return home on the same connected route", () => {
  const city = createInitialCity(907);
  const home = placeCityItem(city,17,14,"home").item;
  const shop = placeCityItem(city,18,14,"shop").item;
  city.population = 12;
  const assignment = computeCityCommuting(city,computeCityEmployment(city));
  assert.ok(assignment.assignments.some(flow => flow.homeId === home.id && flow.workplaceId === shop.id));
  for (let tick=0;tick<1200;tick++) stepCityCitizens(city,1,assignment.assignments);
  const workers = city.citizens.filter(citizen => citizen.commuteWorkplaceId === shop.id);
  assert.ok(workers.length > 0,"at least one visible citizen must be assigned to the shop");
  assert.ok(workers.some(citizen => citizen.commutePhase === "returning" || citizen.commuteRouteStep > 0),
    "assigned citizens must progress along their commute route");
  assert.ok(workers.every(citizen => city.grid[citizen.roadY]?.[citizen.roadX] === "road"));
  assert.equal(isValidCitySave(city),true);
});

test("commute agents remain deterministic and recover when their road route is removed", async () => {
  const create = () => {
    const city = createInitialCity(908);
    placeCityItem(city,17,14,"home");
    placeCityItem(city,18,14,"shop");
    city.population = 12;
    return {city, assignments:computeCityCommuting(city,computeCityEmployment(city)).assignments};
  };
  const a=create(),b=create();
  for(let tick=0;tick<180;tick++){stepCityCitizens(a.city,1,a.assignments);stepCityCitizens(b.city,1,b.assignments);}
  assert.deepEqual(a.city.citizens,b.city.citizens);
  const assigned=a.city.citizens.find(citizen=>citizen.commuteWorkplaceId);
  assert.ok(assigned);
  assert.equal(isValidCitySave(a.city),true);
});
