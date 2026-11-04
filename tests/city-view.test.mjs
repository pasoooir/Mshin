import test from "node:test";
import assert from "node:assert/strict";
import {createInitialCity,stepCity,placeCityItem,isValidCitySave,normalizeCitySave,projectCityTile} from "../src/city/city-view.js";
test("new city starts as an empty, deterministic, fully gridded world",()=>{const a=createInitialCity(42),b=createInitialCity(42);assert.equal(a.name,"دره سبز");assert.equal(a.grid.length,32);assert.equal(a.grid[15][15],"road");assert.equal(a.buildings.length,0);assert.equal(a.population,0);assert.equal(a.trees.length,0);assert.equal(a.citizens.length,0);assert.equal(a.traffic.length,0);assert.equal(a.animals.length,0);assert.ok(a.grid.flat().filter(t=>t==="road").length>=300);assert.equal(a.population,b.population);assert.deepEqual(a.grid,b.grid);assert.equal(isValidCitySave(a),true)});
test("simulation ticks advance time, economy, citizens and traffic",()=>{const c=createInitialCity(7),money=c.treasury;stepCity(c,1);assert.equal(c.tick,1);assert.equal(c.minuteOfDay,505);assert.equal(c.traffic.length,0);assert.equal(c.animals.length,0);assert.equal(c.treasury,money);assert.equal(c.stats.income,0);assert.equal(c.stats.jobs,0)});
test("roads and buildings enforce budget and street access",()=>{const c=createInitialCity(99);assert.equal(placeCityItem(c,17,14,"road").ok,true);assert.equal(c.grid[14][17],"road");assert.equal(placeCityItem(c,17,13,"home").ok,true);assert.equal(c.grid[13][17],"building");assert.ok(c.population>=12);const blocked=placeCityItem(c,2,2,"shop");assert.equal(blocked.ok,false);assert.match(blocked.reason,/دسترسی/);assert.equal(placeCityItem(c,17,13,"shop").ok,false)});
test("save validation rejects malformed or incompatible snapshots",()=>{const c=createInitialCity(12);assert.equal(isValidCitySave(c),true);assert.equal(isValidCitySave({...c,schemaVersion:9}),false);assert.equal(isValidCitySave({...c,grid:[]}),false);assert.equal(isValidCitySave({...c,treasury:"unlimited"}),false)});
test("isometric projection preserves diagonal tile geometry",()=>{assert.deepEqual(projectCityTile(1,0),{x:16,y:8});assert.deepEqual(projectCityTile(0,1),{x:-16,y:8})});

test("city traffic spawns deterministically and remains on connected road tiles",()=>{
 const a=createInitialCity(731),b=createInitialCity(731);
 for(let i=0;i<32;i++){stepCity(a);stepCity(b)}
 assert.ok(a.traffic.length>=3,"traffic should enter the city as the simulation advances");
 assert.ok(a.traffic.length<=12,"traffic population must remain bounded");
 assert.deepEqual(a.traffic,b.traffic,"identical city seeds and ticks must produce identical traffic");
 for(const vehicle of a.traffic){
  const x=Math.round(vehicle.x),y=Math.round(vehicle.y);
  assert.equal(a.grid[y]?.[x],"road","every vehicle must occupy or traverse a road tile");
  assert.ok(Number.isFinite(vehicle.heading)&&Number.isFinite(vehicle.speed)&&vehicle.speed>0);
 }
});
test("city traffic moves continuously along road segments without jumping off the network",()=>{
 const city=createInitialCity(991);
 for(let i=0;i<8;i++)stepCity(city);
 assert.equal(city.traffic.length,1);
 const before={x:city.traffic[0].x,y:city.traffic[0].y};
 for(let i=0;i<5;i++)stepCity(city);
 const vehicle=city.traffic[0];
 assert.ok(Math.hypot(vehicle.x-before.x,vehicle.y-before.y)>0.1,"traffic must visibly advance");
 assert.equal(city.grid[Math.round(vehicle.y)]?.[Math.round(vehicle.x)],"road");
 assert.ok(Number.isInteger(vehicle.targetX)&&Number.isInteger(vehicle.targetY));
});
test("traffic remains bounded and does not spawn overlapping vehicles",()=>{
 const city=createInitialCity(2026);
 for(let i=0;i<400;i++)stepCity(city);
 assert.ok(city.traffic.length<=12);
 for(let i=0;i<city.traffic.length;i++)for(let j=i+1;j<city.traffic.length;j++){
  assert.ok(Math.hypot(city.traffic[i].x-city.traffic[j].x,city.traffic[i].y-city.traffic[j].y)>0.15,
   "traffic vehicles must not occupy the same point");
 }
});

test("save validation rejects malformed entities and grid/entity mismatches",()=>{
 const city=createInitialCity(414);
 const badBuilding=structuredClone(city);
 badBuilding.buildings.push({id:1,type:"home",x:17,y:13,level:1,age:0,residents:12});
 assert.equal(isValidCitySave(badBuilding),false,"a building record cannot exist on a grass tile");
 const validBuilding=structuredClone(city);
 validBuilding.grid[13][17]="building";
 validBuilding.buildings.push({id:1,type:"home",x:17,y:13,level:1,age:0,residents:12});
 validBuilding.nextBuildingId=2;
 assert.equal(isValidCitySave(validBuilding),true);
 const brokenGrid=structuredClone(validBuilding);
 brokenGrid.grid[13]=[];
 assert.equal(isValidCitySave(brokenGrid),false);
 const brokenStats=structuredClone(city);
 brokenStats.stats.income=Number.NaN;
 assert.equal(isValidCitySave(brokenStats),false);
});
test("save validation checks zone and traffic route consistency",()=>{
 const zoneCity=createInitialCity(515);
 zoneCity.grid[13][17]="zone-residential";
 zoneCity.zones=[{x:17,y:13,type:"residential",createdAt:0}];
 assert.equal(isValidCitySave(zoneCity),true);
 const trafficCity=createInitialCity(616);
 trafficCity.traffic=[{id:1,x:7,y:7,previousX:null,previousY:null,targetX:8,targetY:7,headingX:1,headingY:0,heading:0,routeStep:0,speed:.4,color:"#f2bd4d"}];
 trafficCity.nextTrafficId=2;
 assert.equal(isValidCitySave(trafficCity),true);
 const offRoad=structuredClone(trafficCity);
 offRoad.traffic[0].targetX=10;
 offRoad.traffic[0].targetY=10;
 assert.equal(isValidCitySave(offRoad),false,"traffic targets must remain on the road network");
 const missingZone=structuredClone(zoneCity);
 missingZone.zones=[];
 assert.equal(isValidCitySave(missingZone),false,"zoned grid cells must have matching zone records");
});
test("legacy version-two saves normalize optional fields without losing valid city data",()=>{
 const legacy=createInitialCity(717);
 legacy.grid[13][17]="building";
 legacy.buildings=[{id:1,type:"home",x:17,y:13,residents:12}];
 delete legacy.zones;
 delete legacy.animals;
 delete legacy.nextTrafficId;
 delete legacy.nextBuildingId;
 delete legacy.stats;
 delete legacy.minuteOfDay;
 delete legacy.happiness;
 assert.equal(isValidCitySave(legacy),true);
 const normalized=normalizeCitySave(legacy);
 assert.equal(normalized.buildings[0].level,1);
 assert.equal(normalized.buildings[0].age,0);
 assert.equal(normalized.nextBuildingId,2);
 assert.equal(normalized.nextTrafficId,1);
 assert.deepEqual(normalized.zones,[]);
 assert.deepEqual(normalized.animals,[]);
 assert.equal(normalized.minuteOfDay,495);
 assert.equal(normalized.happiness,100);
 assert.deepEqual(normalized.stats,{income:0,expenses:0,jobs:0,traffic:0});
 const legacyZone=createInitialCity(919);legacyZone.grid[13][17]="zone-residential";delete legacyZone.zones;
 assert.equal(isValidCitySave(legacyZone),true,"legacy v2 saves without zone records must preserve zoning tiles");
 assert.deepEqual(normalizeCitySave(legacyZone).zones,[{x:17,y:13,type:"residential",createdAt:0}]);
});

test("road demolition retires stranded traffic before the next save",()=>{
 const city=createInitialCity(818);
 for(let i=0;i<8;i++)stepCity(city);
 assert.equal(city.traffic.length,1);
 const stranded=city.traffic[0],x=Math.round(stranded.x),y=Math.round(stranded.y);
 city.grid[y][x]="grass";
 stepCity(city);
 assert.equal(city.traffic.some(vehicle=>vehicle.id===stranded.id),false);
 assert.equal(isValidCitySave(city),true);
});

test("unfinished home, shop and factory buildings stay inactive until their timer completes",()=>{for(const [type,x,y] of [["home",17,13],["shop",18,13],["industrial",19,13]]){const c=createInitialCity(2026);c.grid[12][x]="road";const result=placeCityItem(c,x,13,type,45);assert.equal(result.ok,true);assert.equal(result.item.construction.remaining,45);const before=type==="home"?c.population:c.stats.jobs;stepCity(c,44);assert.ok(c.buildings[0].construction,"building remains a construction site before the final second");assert.equal(type==="home"?c.population:c.stats.jobs,before);stepCity(c,1);assert.equal(c.buildings[0].construction,undefined,"finished building replaces the construction site");if(type==="home")assert.equal(c.population,12);}});


test("unfinished construction timers survive save normalization and reject invalid countdowns",()=>{
 const city=createInitialCity(414);
 city.grid[12][17]="road";
 const result=placeCityItem(city,17,13,"home",45);
 assert.equal(result.ok,true);
 assert.equal(isValidCitySave(city),true);
 const normalized=normalizeCitySave(city);
 assert.deepEqual(normalized.buildings[0].construction,{duration:45,remaining:45});
 const invalid={...city,buildings:city.buildings.map(building=>({...building,construction:{duration:45,remaining:46}}))};
 assert.equal(isValidCitySave(invalid),false,"a countdown must never exceed its construction duration");
});


test("traffic epsilon transitions keep previous road coordinates integer-safe for saves",()=>{
 const city=createInitialCity(7731);
 for(let i=0;i<144;i++)stepCity(city);
 assert.ok(city.traffic.length>0);
 assert.ok(city.traffic.every(vehicle=>vehicle.previousX===null||Number.isInteger(vehicle.previousX)));
 assert.ok(city.traffic.every(vehicle=>vehicle.previousY===null||Number.isInteger(vehicle.previousY)));
 assert.equal(isValidCitySave(city),true,"traffic rounding near a road node must not invalidate a long-running city save");
});
