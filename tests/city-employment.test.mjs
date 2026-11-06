import test from "node:test";
import assert from "node:assert/strict";
import { createInitialCity, placeCityItem, stepCity } from "../src/city/city-view.js";
import { computeCityEmployment } from "../src/city/city-employment.js";

function seedCityRoadAccess(city){for(let x=10;x<=28;x++){placeCityItem(city,x,12,"road");placeCityItem(city,x,15,"road");placeCityItem(city,x,18,"road")}return city}

test("workplace capacity is counted by sector with deterministic workforce matching", () => {
  const city=seedCityRoadAccess(createInitialCity(2101));
  placeCityItem(city,17,14,"home"); placeCityItem(city,18,14,"shop");
  placeCityItem(city,19,14,"industrial"); placeCityItem(city,20,14,"administrative");
  const result=computeCityEmployment(city);
  assert.equal(result.jobs,39); assert.equal(result.laborForce,7);
  assert.equal(result.employed,7); assert.equal(result.unemployed,0);
  assert.equal(result.vacancies,32); assert.equal(result.bySector.industrial.employed,7);
  assert.equal(result.bySector.shop.employed,0);
});
test("labor surplus and shortage are separately reported", () => {
  const city=seedCityRoadAccess(seedCityRoadAccess(createInitialCity(2102)); placeCityItem(city,17,14,"home"); placeCityItem(city,18,14,"shop");
  city.population=60; const surplus=computeCityEmployment(city);
  assert.equal(surplus.laborForce,36); assert.equal(surplus.employed,9);
  assert.equal(surplus.unemployed,27); assert.equal(surplus.unemploymentRate,75);
  assert.equal(surplus.unmetLaborDemand,27);
  city.population=6; const shortage=computeCityEmployment(city);
  assert.equal(shortage.laborForce,3); assert.equal(shortage.employed,3);
  assert.equal(shortage.unemployed,0); assert.equal(shortage.laborShortage,6);
});
test("employment metrics are integrated into every simulation tick", () => {
  const city=seedCityRoadAccess(seedCityRoadAccess(createInitialCity(2103)); placeCityItem(city,17,14,"home"); placeCityItem(city,18,14,"shop");
  city.population=30; stepCity(city);
  assert.equal(city.stats.jobs,9); assert.equal(city.stats.laborForce,18);
  assert.equal(city.stats.employed,9); assert.equal(city.stats.unemployed,9);
  assert.equal(city.stats.unemploymentRate,50); assert.equal(city.stats.vacancies,0);
});
test("invalid population is rejected and empty cities have zero employment", () => {
  assert.throws(()=>computeCityEmployment({buildings:[],population:-1}),/valid city/);
  const result=computeCityEmployment(seedCityRoadAccess(createInitialCity(2104));
  assert.equal(result.jobs,0); assert.equal(result.employed,0); assert.equal(result.unemployed,0);
  assert.equal(result.vacancies,0); assert.ok(result.demandIndex>=0&&result.demandIndex<=100);
});
