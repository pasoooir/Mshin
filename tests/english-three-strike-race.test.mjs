import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const root=new URL("../",import.meta.url);
const [html,game,renderer,locale]=await Promise.all(["index.html","src/web-game.js","src/race-renderer-3d.js","src/english-locale.js"].map(p=>readFile(new URL(p,root),"utf8")));
test("game interface is English and left-to-right with Latin digits",()=>{
 assert.match(html,/<html lang="en" dir="ltr">/);
 assert.match(html,/english-locale\.js/);
 assert.match(locale,/document\.documentElement\.lang="en"/);
 assert.match(locale,/digitMap/);
 assert.match(locale,/"۰":"0"/);
});
test("the racing surface is substantially wider in both renderers and AI lanes fit it",()=>{
 assert.match(game,/ROAD_HALF_WIDTH=360/);
 assert.match(renderer,/half=360/);
 assert.match(game,/lanes=\[-270,-90,90,270/);
 assert.match(game,/-300,300/);
});
test("player gets two recoveries and loses on the third destruction",()=>{
 assert.match(game,/crashCount=\(vehicle\.crashCount\|\|0\)\+1/);
 assert.match(game,/vehicle\.crashCount>=3/);
 assert.match(game,/vehicle\.recoveryPending=true;vehicle\.recoveryTimer=1\.85/);
 assert.match(game,/vehicle\.destruction=createDestructionState\(\);vehicle\.damage=createDamageState\(\)/);
 assert.match(game,/race\.playerLost=true;race\.playerDNF=true/);
 assert.match(game,/"YOU LOST"/);
 assert.match(game,/"RETRY RACE"/);
});
test("vehicle-to-vehicle collisions apply full positional correction to prevent visible overlap",()=>{
 assert.match(game,/resolveRigidVehicleImpact\(a,b,\{positionPercent:1,slop:0\}\)/);
 assert.match(game,/resolveRigidVehicleImpact\(bodyA,bodyB,\{positionPercent:1,slop:0\}\)/);
 assert.match(game,/target\.strokeStyle="#f2f7ff"/);
});
