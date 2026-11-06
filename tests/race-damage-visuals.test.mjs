import test from "node:test";
import assert from "node:assert/strict";
import {buildVehicleDamageGeometry} from "../src/vehicle-showroom-3d.js";

test("all player and AI vehicle profiles provide two layered hood-scratch meshes",()=>{
 for(const id of ["rally","comet","lynx","thunder","raptor","ai-formula","ai-pickup","ai-rallycross","ai-touring","ai-prototype"]){
  const layers=buildVehicleDamageGeometry(id);
  assert.equal(layers.length,2,id+" must have light and dark scratch layers");
  assert.ok(layers.every(layer=>layer.vertices.length>=36),id+" scratch layers must contain visible geometry");
  assert.ok(layers.every(layer=>layer.paint.startsWith("#")),id+" scratch layers must have explicit paint");
 }
});

test("the live 3D renderer draws damage streaks and fades burnt wrecks",async()=>{
 const {readFile}=await import("node:fs/promises");
 const source=await readFile(new URL("../src/race-renderer-3d.js",import.meta.url),"utf8");
 assert.match(source,/getCarDamageParts\(profile\)/);
 assert.match(source,/damageValue>=8/);
 assert.match(source,/damageValue>=32/);
 assert.match(source,/destruction\?\.phase===\"burnt\"/);
 assert.match(source,/wreckScale/);
});

test("vehicle-to-vehicle impacts damage both cars and keep collision resolution active",async()=>{
 const {readFile}=await import("node:fs/promises");
 const game=await readFile(new URL("../src/web-game.js",import.meta.url),"utf8");
 assert.match(game,/applyDamageAndDestruction\(car,energyShare\.a,[^;]+;applyDamageAndDestruction\(r,energyShare\.b/);
 assert.match(game,/applyDamageAndDestruction\(a,energyShare\.a,[^;]+;applyDamageAndDestruction\(b,energyShare\.b/);
 assert.match(game,/resolveRigidVehicleImpact/);
 assert.match(game,/lanes:\[-270,-90,90,270\]/);
});
