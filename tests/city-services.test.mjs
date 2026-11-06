import test from "node:test";
import assert from "node:assert/strict";
import { createInitialCity, placeCityItem, stepCity } from "../src/city/city-view.js";
import { CITY_SERVICE_TYPES, computeCityServices, computeCityResidentServiceSatisfaction, cityServiceStatus } from "../src/city/city-services.js";

function seedCityRoadAccess(city){for(let x=10;x<=28;x++){placeCityItem(city,x,15,"road");placeCityItem(city,x,18,"road")}for(let y=10;y<=20;y++)placeCityItem(city,16,y,"road");return city}

test("the city defines all four utilities and four public service departments", () => {
  assert.deepEqual(Object.keys(CITY_SERVICE_TYPES), ["power","water","sewage","waste","police","fire","health","education"]);
  assert.equal(Object.values(CITY_SERVICE_TYPES).filter(v=>v.category==="utility").length,4);
  assert.equal(Object.values(CITY_SERVICE_TYPES).filter(v=>v.category==="public").length,4);
});

test("utility and civic buildings require road access and charge their construction cost", () => {
  const city=seedCityRoadAccess(createInitialCity(601))),money=city.treasury;
  const result=placeCityItem(city,17,14,"power");
  assert.equal(result.ok,true);
  assert.equal(city.grid[14][17],"building");
  assert.ok(city.treasury<money);
  assert.equal(city.buildings.find(b=>b.x===17&&b.y===14).type,"power");
  assert.equal(placeCityItem(city,2,2,"police").ok,false);
});

test("utility coverage reaches nearby buildings and remains bounded", () => {
  const city=seedCityRoadAccess(createInitialCity(602));
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
  const city=seedCityRoadAccess(createInitialCity(603));
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
  const a=seedCityRoadAccess(createInitialCity(604)),b=seedCityRoadAccess(createInitialCity(604));
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
  const underemployed=seedCityRoadAccess(createInitialCity(605)),employed=seedCityRoadAccess(createInitialCity(605));
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

 
test("resident service satisfaction weights each occupied home by its residents", () => {
  const city = { buildings: [
    { id: 1, type: "home", residents: 12, serviceSatisfaction: Object.fromEntries(Object.keys(CITY_SERVICE_TYPES).map(type => [type, 100])) },
    { id: 2, type: "home", residents: 12, serviceSatisfaction: Object.fromEntries(Object.keys(CITY_SERVICE_TYPES).map(type => [type, 100])) },
    { id: 3, type: "home", residents: 12, serviceSatisfaction: Object.fromEntries(Object.keys(CITY_SERVICE_TYPES).map(type => [type, 0])) },
    { id: 4, type: "shop", residents: 0, serviceSatisfaction: Object.fromEntries(Object.keys(CITY_SERVICE_TYPES).map(type => [type, 0])) }
  ] };
  assert.equal(computeCityResidentServiceSatisfaction(city), 67,
    "two fully served homes and one unserved home contribute equally when their resident counts match");
  city.buildings[2].residents = 0;
  assert.equal(computeCityResidentServiceSatisfaction(city), 100,
    "unoccupied homes must not reduce resident wellbeing");
  assert.equal(computeCityResidentServiceSatisfaction({ buildings: [] }), 0);
});

test("city happiness uses resident-weighted service satisfaction from finite allocations", () => {
  const city = seedCityRoadAccess(createInitialCity(606));
  assert.equal(placeCityItem(city, 17, 13, "home").ok, true);
  const initialHappiness = city.happiness;
  stepCity(city);
  assert.equal(city.stats.residentServiceSatisfaction, 0,
    "occupied homes without service capacity must report zero resident service satisfaction");
  assert.ok(city.happiness < initialHappiness,
    "unserved residents must reduce city happiness even when geographic station reach is absent");
});
