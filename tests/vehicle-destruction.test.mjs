import test from "node:test";
import assert from "node:assert/strict";
import {createDestructionState,applyDestructionImpact,stepDestruction,destructionVisuals} from "../src/vehicle-destruction.js";

test("each impact progressively darkens only the struck panel",()=>{
 const s=createDestructionState();
 applyDestructionImpact(s,{damage:12,panel:"front"});
 applyDestructionImpact(s,{damage:9,panel:"front"});
 applyDestructionImpact(s,{damage:8,panel:"left"});
 assert.equal(s.panels.front,18.9);assert.equal(s.panels.left,7.2);assert.equal(s.panels.rear,0);
 assert.ok(s.damage<100);
});
test("smoke and fire escalate at cumulative damage thresholds",()=>{
 const s=createDestructionState();
 applyDestructionImpact(s,{damage:30});assert.ok(s.smoke>0);
 applyDestructionImpact(s,{damage:30});assert.equal(s.phase,"smoking");
 applyDestructionImpact(s,{damage:20});assert.equal(s.phase,"burning");
});
test("critical damage triggers exactly one explosion",()=>{
 const s=createDestructionState();
 applyDestructionImpact(s,{damage:35});applyDestructionImpact(s,{damage:35});applyDestructionImpact(s,{damage:35});
 const a=applyDestructionImpact(s,{damage:20});
 assert.equal(a.explosion,true);assert.equal(s.explosionTriggered,true);
 applyDestructionImpact(s,{damage:10});assert.equal(s.explosionTriggered,true);
});
test("wreck burns, then smoke fades and despawn is terminal",()=>{
 const s=createDestructionState();
 applyDestructionImpact(s,{damage:35});applyDestructionImpact(s,{damage:35});applyDestructionImpact(s,{damage:35});
 stepDestruction(s,.016);assert.equal(s.phase,"burning");
 for(let i=0;i<51;i++)stepDestruction(s,.1);
 assert.equal(s.phase,"burnt");assert.equal(s.despawned,false);
 for(let i=0;i<40;i++)stepDestruction(s,.1);
 assert.equal(s.phase,"despawned");assert.equal(s.despawned,true);
 stepDestruction(s,.1);assert.equal(s.despawned,true);
});
test("invalid damage and frame steps stay bounded",()=>{
 const s=createDestructionState();
 applyDestructionImpact(s,{damage:Infinity,panel:"invalid"});
 stepDestruction(s,NaN);
 const v=destructionVisuals(s);
 assert.equal(s.damage,0);assert.equal(v.phase,"intact");assert.ok(v.smoke>=0&&v.smoke<=1);
});
