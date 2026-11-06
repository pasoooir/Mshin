import fs from "node:fs";
import test from "node:test";
import assert from "node:assert/strict";
import { createInitialCity, placeCityItem, stepCity, isValidCitySave, migrateCitySave, createCitySaveBackup } from "../src/city/city-view.js";
import { CITY_DEFAULT_TAX_RATES, setCityTaxRate } from "../src/city/city-economy.js";

function seedCityRoadAccess(city){for(let x=10;x<=28;x++){placeCityItem(city,x,15,"road");placeCityItem(city,x,18,"road")}for(let y=10;y<=20;y++)placeCityItem(city,16,y,"road");return city}

function createLegacyV1City() {
  const grid = Array.from({length:32},()=>Array(32).fill("grass"));
  for (let y=0;y<32;y++) for (let x=0;x<32;x++) {
    if ([7,15,23].includes(x) || [7,15,23].includes(y)) grid[y][x]="road";
  }
  for (let y=0;y<5;y++) for (let x=26;x<31;x++) grid[y][x]="water";
  grid[14][17]="building";
  return {
    schemaVersion:1,cityId:"legacy-city-01",name:"شهر قدیمی",seed:20261102,tick:42,
    minuteOfDay:815,treasury:12345,population:12,happiness:76,grid,
    buildings:[{id:1,type:"home",x:17,y:14,level:1,age:4,residents:12}],
    trees:[{x:10,y:10,size:1.2}],
    citizens:[{id:1,x:11.5,y:12.2,phase:1.4,pace:.16}],
    traffic:[{id:1,x:15,y:15,speed:1.2,color:"#f5bd58"}],
    nextBuildingId:2,stats:{income:13,expenses:2,jobs:8,traffic:3}
  };
}

test("version-one local city saves migrate without losing the built city or treasury", () => {
  const legacy=createLegacyV1City();
  const migrated=migrateCitySave(legacy);
  assert.ok(migrated);
  assert.equal(migrated.schemaVersion,2);
  assert.equal(migrated.cityId,legacy.cityId);
  assert.equal(migrated.name,legacy.name);
  assert.equal(migrated.seed,legacy.seed);
  assert.equal(migrated.tick,legacy.tick);
  assert.equal(migrated.treasury,legacy.treasury);
  assert.equal(migrated.population,legacy.population);
  assert.deepEqual(migrated.grid,legacy.grid);
  assert.deepEqual(migrated.buildings,legacy.buildings.map(building=>({...building,level:1,age:4,residents:12})));
  assert.deepEqual(migrated.trees,legacy.trees);
  assert.deepEqual(migrated.taxRates,CITY_DEFAULT_TAX_RATES);
  assert.equal(migrated.traffic.length,0,"legacy rail-based traffic is rebuilt by the current road simulation");
  assert.equal(migrated.citizens.length,4,"legacy free-moving citizens are rebuilt as road-following pedestrian agents");
  assert.ok(migrated.citizens.every(citizen=>citizen.homeId===1));
  assert.equal(isValidCitySave(migrated),true);
  assert.equal(legacy.schemaVersion,1,"migration must not mutate the original save");
  assert.equal(legacy.citizens.length,1);
});

test("exported JSON backup envelopes round-trip through the same migration boundary", () => {
  const city=seedCityRoadAccess(createInitialCity(1201));
  placeCityItem(city,17,14,"home");
  setCityTaxRate(city,"residential",14);
  for(let i=0;i<3;i++)stepCity(city);
  const backup=createCitySaveBackup(city,"2026-11-03T09:00:00.000Z");
  assert.equal(backup.format,"mshin-city-save");
  assert.equal(backup.version,2);
  assert.equal(backup.exportedAt,"2026-11-03T09:00:00.000Z");
  const restored=migrateCitySave(backup);
  assert.ok(restored);
  assert.equal(isValidCitySave(restored),true);
  assert.equal(restored.treasury,city.treasury);
  assert.deepEqual(restored.taxRates,city.taxRates);
  assert.deepEqual(restored.buildings,city.buildings);
  assert.deepEqual(restored.citizens,city.citizens);
});

test("malformed version-one saves are rejected rather than partially imported", () => {
  const legacy=createLegacyV1City();
  legacy.grid[4]=[];
  assert.equal(migrateCitySave(legacy),null);
  assert.equal(migrateCitySave({format:"mshin-city-save",version:2,city:{schemaVersion:9}}),null);
});

test("backup envelopes reject unsupported versions and invalid timestamps", () => {
  const city=seedCityRoadAccess(createInitialCity(1203));
  const backup=createCitySaveBackup(city,"2026-11-03T09:00:00.000Z");
  assert.equal(migrateCitySave({...backup,version:3}),null);
  assert.equal(migrateCitySave({...backup,exportedAt:"not-a-date"}),null);
  assert.throws(()=>createCitySaveBackup(city,"not-a-date"),/valid city snapshot/);
});

test("current version-two saves normalize optional fields without changing core progress", () => {
  const city=seedCityRoadAccess(createInitialCity(1202));
  placeCityItem(city,17,14,"home");
  stepCity(city);
  const restored=migrateCitySave(JSON.parse(JSON.stringify(city)));
  assert.ok(restored);
  assert.equal(restored.treasury,city.treasury);
  assert.equal(restored.population,city.population);
  assert.deepEqual(restored.taxRates,city.taxRates);
  assert.equal(isValidCitySave(restored),true);
});

test("backup export refuses invalid in-memory state", () => {
  assert.throws(()=>createCitySaveBackup({schemaVersion:99}),/valid city snapshot/);
});


test("offline app shell precaches every city simulation and persistence module", () => {
  const serviceWorker=fs.readFileSync(new URL("../service-worker.js",import.meta.url),"utf8");
  for(const modulePath of ["city-view.js","city-day-night-cycle.js","city-three-renderer.js","city-world-scale.js","city-camera-controller.js","city-camera-projection.js","city-zoning.js","city-services.js","city-traffic.js","city-population.js","city-economy.js","city-employment.js","city-save.js"]){
    assert.ok(serviceWorker.includes("./src/city/"+modulePath),"offline app shell is missing "+modulePath);
  }
  assert.match(serviceWorker,/mshin-arcade-v80/,"city persistence release must advance the offline cache version");
});

test("fractional city clock minutes remain valid and survive save migration", () => {
  const city = seedCityRoadAccess(createInitialCity(1204));
  city.minuteOfDay = 720.8;
  assert.equal(isValidCitySave(city), true, "continuous lighting clock values must be persistable");
  const restored = migrateCitySave(JSON.parse(JSON.stringify(city)));
  assert.equal(restored.minuteOfDay, 720.8, "save migration must preserve sub-minute daylight progress");
  assert.equal(isValidCitySave(restored), true);
});
