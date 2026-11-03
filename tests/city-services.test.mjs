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
  const result=placeCityItem(city,17,14,"power");
  assert.equal(result.ok,true);
  assert.equal(city.grid[14][17],"building");
  assert.ok(city.treasury<money);
  assert.equal(city.buildings.find(b=>b.x===17&&b.y===14).type,"power");
  assert.equal(placeCityItem(city,2,2,"police").ok,false);
});

test("utility coverage reaches nearby buildings and remains bounded", () => {
  const city=createInitialCity(602);
  assert.equal(placeCityItem(city,17,13,"home").ok,true);
  const before=computeCityServices(city);
  assert.equal(before.utilityCoverage,0);
  assert.equal(placeCityItem(city,17,14,"power").ok,true);
  assert.equal(placeCityItem(city,14,17,"water").ok,true);
  const result=computeCityServices(city);
  assert.ok(result.coverage.power>0);
  assert.ok(result.coverage.water>0);
  assert.ok(result.utilityCoverage>0&&result.utilityCoverage<=100);
  assert.ok(city.buildings.some(b=>b.serviceCoverage?.power===true));
});

test("public safety, health and education coverage contributes to the city service score", () => {
  const city=createInitialCity(603);
  assert.equal(placeCityItem(city,17,13,"home").ok,true);
  for(const [x,y,type] of [[17,14,"power"],[14,17,"water"],[18,14,"police"],[13,17,"health"],[18,17,"fire"],[13,14,"education"]]){
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
    placeCityItem(city,17,13,"home");
    placeCityItem(city,17,14,"power");
    placeCityItem(city,14,14,"water");
    stepCity(city);
  }
  assert.deepEqual(cityServiceStatus(a),cityServiceStatus(b));
  assert.equal(a.stats.overallCoverage,b.stats.overallCoverage);
});

test("service demand is limited by station capacity even when buildings are in range", () => {
  const city = { buildings: [
    ...Array.from({ length: 8 }, (_, index) => ({ id: index + 1, type: "home", x: index + 1, y: 1, residents: 12 })),
    { id: 20, type: "power", x: 0, y: 1 },
    { id: 21, type: "health", x: 0, y: 1 }
  ] };
  const result = computeCityServices(city);
  assert.equal(result.coverage.power, 100);
  assert.equal(result.demandCoverage.power, 100);
  assert.equal(result.coverage.health, 100);
  assert.equal(result.demandCoverage.health, 83);
  assert.equal(result.capacityUsage.power, 96);
  assert.equal(result.capacityUsage.health, 80);
  assert.ok(result.utilityCoverage < 100);
});

test("empty homes consume no finite service capacity", () => {
  const emptyHome={id:1,type:"home",x:1,y:1,residents:0};
  const city={buildings:[emptyHome,{id:2,type:"power",x:0,y:1}]};
  const result=computeCityServices(city);
  assert.equal(result.coverage.power,100,"geographic reach remains separate from demand");
  assert.equal(result.demandCoverage.power,0,"an empty city block contributes no resident demand");
  assert.equal(result.capacityUsage.power,0,"empty homes must not consume utility capacity");
  assert.equal(emptyHome.serviceSatisfaction.power,100,"zero-demand buildings are fully satisfied by definition");
});

test("multiple service stations pool capacity without exceeding their limits", () => {
  const city = { buildings: [
    ...Array.from({ length: 16 }, (_, index) => ({ id: index + 1, type: "home", x: index % 8 + 1, y: Math.floor(index / 8) + 1, residents: 12 })),
    { id: 30, type: "power", x: 0, y: 1 },
    { id: 31, type: "power", x: 9, y: 1 }
  ] };
  const result = computeCityServices(city);
  assert.equal(result.demandCoverage.power, 100);
  assert.equal(result.capacityUsage.power, 192);
  assert.ok(result.capacityUsage.power <= 240);
});

test("service status exposes demand coverage and capacity usage as bounded metrics", () => {
  const city = { buildings: [{ id: 1, type: "home", x: 1, y: 1, residents: 12 }, { id: 2, type: "water", x: 1, y: 2 }] };
  const status = cityServiceStatus(city);
  assert.equal(status.demandCoverage.water, 100);
  assert.equal(status.capacityUsage.water, 12);
  assert.ok(Object.values(status.demandCoverage).every(value => value >= 0 && value <= 100));
});


test("resident wellbeing reflects finite service demand and workforce unemployment", () => {
  const underemployed=createInitialCity(605),employed=createInitialCity(605);
  for(const city of [underemployed,employed]){
    assert.equal(placeCityItem(city,17,13,"home").ok,true);
    assert.equal(placeCityItem(city,17,12,"home").ok,true);
  }
  assert.equal(placeCityItem(employed,17,14,"industrial").ok,true);
  underemployed.happiness=70;
  employed.happiness=70;
  stepCity(underemployed);
  stepCity(employed);
  assert.equal(underemployed.stats.unemploymentRate,100);
  assert.equal(employed.stats.unemploymentRate,0);
  assert.ok(underemployed.happiness<employed.happiness,"unemployment should reduce resident wellbeing");
  assert.deepEqual(Object.keys(employed.stats.serviceDemandCoverage).sort(),["education","fire","health","police","power","sewage","waste","water"]);
  assert.deepEqual(Object.keys(employed.stats.serviceCapacityUsage).sort(),["education","fire","health","police","power","sewage","waste","water"]);
});
