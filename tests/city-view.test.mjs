import test from "node:test";
import assert from "node:assert/strict";
import {createInitialCity,stepCity,placeCityItem,isValidCitySave,projectCityTile} from "../src/city/city-view.js";
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
