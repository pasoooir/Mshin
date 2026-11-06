import test from "node:test";
import assert from "node:assert/strict";
import { createInitialCity, placeCityItem, stepCity, isValidCitySave } from "../src/city/city-view.js";
import { CITY_ZONES, isCityZoneCell } from "../src/city/city-zoning.js";

function seedCityRoadAccess(city){for(let x=10;x<=28;x++){placeCityItem(city,x,12,"road");placeCityItem(city,x,15,"road")}return city}

test("all five zoning classes are explicit and map to playable building types", () => {
  assert.deepEqual(Object.keys(CITY_ZONES), ["residential","commercial","industrial","administrative","recreational"]);
  assert.deepEqual(Object.values(CITY_ZONES).map(zone => zone.buildingType), ["home","shop","industrial","administrative","park"]);
});

test("zoning requires an empty tile connected to a street and sufficient funds", () => {
  const city = seedCityRoadAccess(createInitialCity(501));
  const result = placeCityItem(city,17,14,"zone-residential");
  assert.equal(result.ok,true);
  assert.equal(city.grid[14][17],"zone-residential");
  assert.equal(city.zones.length,1);
  assert.equal(isCityZoneCell(city.grid[14][17]),true);
  assert.equal(placeCityItem(city,2,2,"zone-commercial").ok,false);
  assert.equal(placeCityItem(city,17,14,"zone-industrial").ok,false);
});

test("residential zoning grows into housing and increases population", () => {
  const city = seedCityRoadAccess(createInitialCity(502));
  const before = city.population;
  assert.equal(placeCityItem(city,17,14,"zone-residential").ok,true);
  for(let i=0;i<12;i++) stepCity(city);
  assert.equal(city.grid[14][17],"building");
  assert.ok(city.buildings.some(building=>building.x===17&&building.y===14&&building.type==="home"));
  assert.ok(city.population>=before+12);
  assert.equal(city.zones.length,0);
});

test("commercial, industrial, administrative and recreational zones develop when demand exists", () => {
  const city = seedCityRoadAccess(createInitialCity(503));
  const zones = [
    [13,14,"residential"],
    [18,14,"residential"],
    [14,13,"residential"],
    [17,18,"residential"],
    [14,14,"commercial"],
    [17,14,"industrial"],
    [14,17,"administrative"],
    [17,17,"recreational"]
  ];
  for(const [x,y,type] of zones) assert.equal(placeCityItem(city,x,y,"zone-"+type).ok,true);
  for(let i=0;i<96;i++) stepCity(city);
  for(const [x,y,type] of zones){
    const expected=CITY_ZONES[type].buildingType;
    assert.ok(city.buildings.some(building=>building.x===x&&building.y===y&&building.type===expected),type+" zone should develop into "+expected);
  }
  assert.ok(city.stats.jobs>0,"industrial and administrative development should expand employment");
});

test("version-two saves accept zoning tiles and legacy saves without a zones array", () => {
  const city=seedCityRoadAccess(createInitialCity(504));
  city.grid[14][17]="zone-residential";
  city.zones=[{x:17,y:14,type:"residential",createdAt:0}];
  assert.equal(isValidCitySave(city),true);
  const legacy={...city,zones:undefined};
  assert.equal(isValidCitySave(legacy),true);
  assert.equal(isValidCitySave({...city,grid:Array.from({length:32},()=>Array(32).fill("zone-unknown"))}),false);
});

 
test("job-producing zones wait for enough residents before expanding labor demand", () => {
  const city=seedCityRoadAccess(createInitialCity(505));
  assert.equal(placeCityItem(city,14,14,"zone-commercial").ok,true);
  assert.equal(placeCityItem(city,17,14,"zone-industrial").ok,true);
  for(let i=0;i<24;i++)stepCity(city);
  assert.ok(city.buildings.some(building=>building.type==="shop"));
  assert.equal(city.buildings.some(building=>building.type==="industrial"),false,"industrial growth must wait while projected vacancies exceed the allowance");
  assert.equal(city.grid[14][17],"zone-industrial");
  assert.equal(placeCityItem(city,13,14,"zone-residential").ok,true);
  assert.equal(placeCityItem(city,18,14,"zone-residential").ok,true);
  for(let i=0;i<36;i++)stepCity(city);
  assert.ok(city.population>=24,"residential growth should expand the available workforce");
  assert.ok(city.buildings.some(building=>building.type==="industrial"),"industrial zoning should develop once workforce capacity is adequate");
});
