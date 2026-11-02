import test from "node:test";
import assert from "node:assert/strict";
import { createInitialCity, placeCityItem, stepCity } from "../src/city/city-view.js";
import { CITY_SERVICE_TYPES, computeCityServices, cityServiceStatus } from "../src/city/city-services.js";

test("the city defines all four utilities and four public service departments", () => {
  assert.deepEqual(Object.keys(CITY_SERVICE_TYPES), ["power","water","sewage","waste","police","fire","health","education"]);
  assert.equal(Object.values(CITY_SERVICE_TYPES).filter(v=>v.category==="utility").length,4);
  assert.equal(Object.values(CITY_SERVICE_TYPES).filter(v=>v.category==="public").length,4);
});

test("utility and civic buildings require road access and charge their construction cost", () => {
  const city=createInitialCity(601),money=city.treasury;
  const result=placeCityItem(city,16,14,"power");
  assert.equal(result.ok,true);
  assert.equal(city.grid[14][16],"building");
  assert.ok(city.treasury<money);
  assert.equal(city.buildings.find(b=>b.x===16&&b.y===14).type,"power");
  assert.equal(placeCityItem(city,2,2,"police").ok,false);
});

test("utility coverage reaches nearby buildings and remains bounded", () => {
  const city=createInitialCity(602);
  const before=computeCityServices(city);
  assert.equal(before.utilityCoverage,0);
  assert.equal(placeCityItem(city,16,14,"power").ok,true);
  assert.equal(placeCityItem(city,14,14,"water").ok,true);
  const result=computeCityServices(city);
  assert.ok(result.coverage.power>0);
  assert.ok(result.coverage.water>0);
  assert.ok(result.utilityCoverage>0&&result.utilityCoverage<=100);
  assert.ok(city.buildings.some(b=>b.serviceCoverage?.power===true));
});

test("public safety, health and education coverage contributes to the city service score", () => {
  const city=createInitialCity(603);
  for(const [x,y,type] of [[16,14,"power"],[14,14,"water"],[16,16,"police"],[14,16,"health"],[16,18,"fire"],[14,18,"education"]]){
    assert.equal(placeCityItem(city,x,y,type).ok,true,type+" should be constructible");
  }
  stepCity(city);
  assert.ok(city.stats.utilityCoverage>0);
  assert.ok(city.stats.publicServiceCoverage>0);
  assert.ok(city.stats.overallCoverage>0);
  assert.ok(city.stats.expenses>0,"service upkeep must be included in city expenses");
  assert.ok(cityServiceStatus(city).coverage.police>0);
});

test("service coverage is deterministic and city simulation exposes infrastructure metrics", () => {
  const a=createInitialCity(604),b=createInitialCity(604);
  for(const city of [a,b]){
    placeCityItem(city,16,14,"power");
    placeCityItem(city,14,14,"water");
    stepCity(city);
  }
  assert.deepEqual(cityServiceStatus(a),cityServiceStatus(b));
  assert.equal(a.stats.overallCoverage,b.stats.overallCoverage);
});
