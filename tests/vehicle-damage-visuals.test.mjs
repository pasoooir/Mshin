import test from "node:test";
import assert from "node:assert/strict";
import { getDamageVisuals } from "../src/vehicle-damage-visuals.js";

test("undamaged vehicle has no dents, cracks, or smoke",()=>{
 const visual=getDamageVisuals({total:0,front:0,rear:0,left:0,right:0});
 assert.ok(visual.panels.every(panel=>panel.dentCount===0&&panel.strength===0));
 assert.equal(visual.glassCracks,0);assert.equal(visual.smoke,0);assert.equal(visual.heavyDeformation,false);
});
test("damage remains localized to the struck side",()=>{
 const visual=getDamageVisuals({total:20,left:20,front:0,rear:0,right:0});
 const bySide=Object.fromEntries(visual.panels.map(panel=>[panel.side,panel]));
 assert.ok(bySide.left.dentCount>0);assert.equal(bySide.front.dentCount,0);assert.equal(bySide.rear.dentCount,0);assert.equal(bySide.right.dentCount,0);
});
test("severe frontal damage produces multiple dents and windshield cracks",()=>{
 const visual=getDamageVisuals({total:64,front:64,rear:0,left:0,right:0});
 assert.equal(visual.panels[0].dentCount,3);assert.ok(visual.glassCracks>0.9);assert.ok(visual.smoke>0);assert.equal(visual.heavyDeformation,true);
});
test("damage visualization clamps corrupt and out-of-range values",()=>{
 const visual=getDamageVisuals({total:150,front:Infinity,rear:-10,left:NaN,right:30});
 assert.ok(visual.panels.every(panel=>panel.strength>=0&&panel.strength<=1));
 assert.equal(visual.panels[0].points,0);assert.equal(visual.panels[1].points,0);assert.equal(visual.smoke,1);
});
test("critical damage is exposed as a disabled visual state",()=>{
 assert.equal(getDamageVisuals({total:100,disabled:true}).disabled,true);
});
