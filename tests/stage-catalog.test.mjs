import test from 'node:test';import assert from 'node:assert/strict';
import {STAGES,WORLD_THEMES,generateTrackPath,getStage,nearestTrackPoint} from '../.test-build/src/stage-catalog.js';
test('50 stages are grouped into 10 worlds with five stages each',()=>{assert.equal(WORLD_THEMES.length,10);assert.equal(STAGES.length,50);for(const w of WORLD_THEMES)assert.equal(STAGES.filter(s=>s.world.id===w.id).length,5);});
test('stages have unique ids and route seeds plus 10 different ground palettes',()=>{assert.equal(new Set(STAGES.map(s=>s.id)).size,50);assert.equal(new Set(STAGES.map(s=>s.seed)).size,50);assert.equal(new Set(WORLD_THEMES.map(w=>w.ground)).size,10);});
test('all routes are deterministic and stage variants differ',()=>{const a=generateTrackPath(getStage(1)),b=generateTrackPath(getStage(2));assert.equal(a.length,96);assert.deepEqual(a,generateTrackPath(getStage(1)));assert.notDeepEqual(a,b);assert.ok(a.every(p=>Number.isFinite(p.x)&&Number.isFinite(p.y)));});
test('nearest route projection finds closest point on closed polyline',()=>{const p=[{x:0,y:0},{x:10,y:0},{x:10,y:10},{x:0,y:10}];const hit=nearestTrackPoint({x:4,y:3},p);assert.deepEqual(hit.point,{x:4,y:0});assert.equal(hit.distance,3);});
test('unknown stage id is rejected',()=>assert.throws(()=>getStage(51),RangeError));

test('route style and world grip provide distinct handling and geometry data',()=>{
 const styles=new Set(STAGES.map(s=>s.routeStyle));assert.equal(styles.size,5);
 const grips=new Set(WORLD_THEMES.map(w=>w.grip));assert.ok(grips.size>=8);
});
