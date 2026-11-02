import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [html,game,renderer,traffic] = await Promise.all([
 readFile(new URL("../index.html",import.meta.url),"utf8"),
 readFile(new URL("../src/web-game.js",import.meta.url),"utf8"),
 readFile(new URL("../src/race-renderer-3d.js",import.meta.url),"utf8"),
 readFile(new URL("../src/traffic-ai.js",import.meta.url),"utf8")
]);

test("portrait phones rotate the active WebGL canvas with the landscape game",()=>{
 assert.match(html,/#game,#game3d,#assetLoader,#countdownOverlay,#hud,\.overlay/);
 assert.match(html,/#game,#game3d\{display:block!important\}/);
 assert.match(html,/transform:rotate\(90deg\) translateY\(-100%\)!important/);
});
test("mobile WebGL uses a bounded landscape drawing buffer and lower GPU cost",()=>{
 assert.ok(renderer.includes('const mobile=matchMedia("(pointer:coarse)")'));
 assert.ok(renderer.includes("antialias:!mobile"));
 assert.ok(renderer.includes("mobile?.68:1.5"));
 assert.ok(renderer.includes("portrait?innerHeight:innerWidth"));
 assert.ok(renderer.includes("mobile?280:760"));
 assert.ok(renderer.includes("mobile?54:144"));
 assert.ok(renderer.includes("mobile?10:36"));
 assert.ok(renderer.includes("mobile?3:7"));
 assert.ok(renderer.includes("qualityScale=clamp(scale,.58,1)"));
});
test("race simulation advances in stable fixed 60 Hz steps",()=>{
 assert.ok(game.includes("const FIXED_STEP=1/60,RENDER_STEP=1/60"));
 assert.ok(game.includes("steps<(mobileDevice?5:8)"));
 assert.ok(game.includes("simulationAccumulator=Math.min(simulationAccumulator+frameDelta,mobileDevice?.08:.1)"));
});
test("mobile rendering targets 60fps without dropping alternate high-refresh callbacks",()=>{
 assert.ok(game.includes("renderAccumulator+=frameDelta"));
 assert.ok(game.includes("renderAccumulator>=RENDER_STEP"));
 assert.ok(!game.includes("ts-last<16.5"));
});
test("mobile renderer adapts drawing resolution to measured render cost",()=>{
 assert.ok(game.includes("renderCostEMA>18"));
 assert.ok(game.includes("renderCostEMA<13"));
 assert.ok(game.includes("race3d.setQuality?.(adaptiveQuality)"));
 assert.ok(renderer.includes("setQuality(scale){qualityScale=clamp(scale,.58,1)"));
});
test("driving acceleration, top speed and displayed speed are increased",()=>{
 assert.ok(game.includes("maxSpeed=model.max*1.22*performanceFactor"));
 assert.ok(game.includes("accel=model.accel*1.3*performanceFactor"));
 assert.ok(game.includes("cruiseSpeed:activeCar().max*1.2"));
 assert.ok(game.includes('$("speed").textContent=Math.round(car.speed*.55)'));
});
test("AI-to-AI collision work uses a conservative angular broad phase",()=>{
 const broad=game.indexOf("angularGap>.20"),geometry=game.indexOf("const fa=frameAt(a.distance%(Math.PI*2)),fb=frameAt(b.distance%(Math.PI*2))",broad);
 assert.ok(broad>=0&&geometry>broad);
});
test("traffic lane evaluation avoids per-tick array mapping, filtering and sorting",()=>{
 assert.ok(traffic.includes("const aheadInLane=laneIndex=>"));
 assert.ok(!traffic.includes(".map("));
 assert.ok(!traffic.includes(".filter("));
 assert.ok(!traffic.includes(".sort("));
});

test("3D rival selection reuses scratch arrays, avoids sorting, and draws rivals at track distance",()=>{
 assert.ok(renderer.includes("const visibleRivals=[],visibleDistances=[]"));
 assert.ok(renderer.includes("visibleRivals.length=0;visibleDistances.length=0"));
 assert.ok(renderer.includes("visibleRivals.splice(slot,0,r);visibleDistances.splice(slot,0,distance)"));
 assert.ok(!renderer.includes("visibleRivals.sort("));
 assert.ok(renderer.includes("drawVehicle(r.distance,r.lateral,r.yaw||0"));
 assert.ok(renderer.includes("rawDelta=Math.abs(r.distance-playerT),delta=rawDelta%(Math.PI*2),distance=Math.min(delta,Math.PI*2-delta)"));
});
