import test from "node:test";
import assert from "node:assert/strict";
import { createInitialCity, placeCityItem, stepCity, isValidCitySave } from "../src/city/city-view.js";
import { CITY_ZONES, isCityZoneCell } from "../src/city/city-zoning.js";

test("all five zoning classes are explicit and map to playable building types", () => {
  assert.deepEqual(Object.keys(CITY_ZONES), ["residential","commercial","industrial","administrative","recreational"]);
  assert.deepEqual(Object.values(CITY_ZONES).map(zone => zone.buildingType), ["home","shop","industrial","administrative","park"]);
});

test("zoning requires an empty tile connected to a street and sufficient funds", () => {
  const city = createInitialCity(501);
  const result = placeCityItem(city,17,14,"zone-residential");
  assert.equal(result.ok,true);
  assert.equal(city.grid[14][17],"zone-residential");
  assert.equal(city.zones.length,1);
  assert.equal(isCityZoneCell(city.grid[14][17]),true);
  assert.equal(placeCityItem(city,2,2,"zone-commercial").ok,false);
  assert.equal(placeCityItem(city,17,14,"zone-industrial").ok,false);
});

test("residential zoning grows into housing and increases population", () => {
  const city = createInitialCity(502);
  const before = city.population;
  assert.equal(placeCityItem(city,17,14,"zone-residential").ok,true);
  for(let i=0;i<12;i++) stepCity(city);
  assert.equal(city.grid[14][17],"building");
  assert.ok(city.buildings.some(building=>building.x===16&&building.y===14&&building.type==="home"));
  assert.ok(city.population>=before+12);
  assert.equal(city.zones.length,0);
});

test("commercial, industrial, administrative and recreational zones develop when demand exists", () => {
  const city = createInitialCity(503);
  const zones = [
    [14,14,"commercial"],
    [17,14,"industrial"],
    [14,16,"administrative"],
    [16,16,"recreational"]
  ];
  for(const [x,y,type] of zones) assert.equal(placeCityItem(city,x,y,"zone-"+type).ok,true);
  for(let i=0;i<48;i++) stepCity(city);
  for(const [x,y,type] of zones){
    const expected=CITY_ZONES[type].buildingType;
    assert.ok(city.buildings.some(building=>building.x===x&&building.y===y&&building.type===expected),type+" zone should develop into "+expected);
  }
  assert.ok(city.stats.jobs>0,"industrial and administrative development should expand employment");
});

test("version-two saves accept zoning tiles and legacy saves without a zones array", () => {
  const city=createInitialCity(504);
  city.grid[14][17]="zone-residential";
  city.zones=[{x:17,y:14,type:"residential",createdAt:0}];
  assert.equal(isValidCitySave(city),true);
  const legacy={...city,zones:undefined};
  assert.equal(isValidCitySave(legacy),true);
  assert.equal(isValidCitySave({...city,grid:Array.from({length:32},()=>Array(32).fill("zone-unknown"))}),false);
});
