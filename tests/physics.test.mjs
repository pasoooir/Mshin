import test from "node:test";
import assert from "node:assert/strict";
import { TRACK, trackRadius, stepCar, resolveTrackCollision, lapProgress, crossedFinish } from "../src/physics.js";

test("track radius identifies the road ring",()=>{assert.ok(trackRadius(TRACK.rx,0)>TRACK.inner&&trackRadius(TRACK.rx,0)<TRACK.outer);assert.ok(trackRadius(0,0)<TRACK.inner);});
test("accelerator increases forward speed and moves the car",()=>{const car={x:TRACK.rx,y:0,heading:Math.PI,speed:0};stepCar(car,{throttle:true,steer:0,brake:false},1/30);assert.ok(car.speed>0);assert.ok(car.y>0);});
test("brake reduces speed",()=>{const car={x:TRACK.rx,y:0,heading:Math.PI,speed:150};stepCar(car,{throttle:false,steer:0,brake:true},1/30);assert.ok(car.speed<150);});
test("steering changes heading",()=>{const car={x:TRACK.rx,y:0,heading:Math.PI,speed:120};stepCar(car,{throttle:false,steer:1,brake:false},1/30);assert.notEqual(car.heading,Math.PI);});
test("right joystick steers the car toward screen-right",()=>{const car={x:TRACK.rx,y:0,heading:Math.PI,speed:120};stepCar(car,{throttle:false,steer:1,brake:false},1/30);assert.ok(car.x>TRACK.rx);});
test("off-road collision returns car to track bounds",()=>{const car={x:0,y:0,heading:0,speed:100};assert.equal(resolveTrackCollision(car),true);const r=trackRadius(car.x,car.y);assert.ok(r>=TRACK.inner&&r<=TRACK.outer);assert.ok(Math.abs(car.speed)<100);});
test("finish line crossing is detected only at lap wrap",()=>{assert.equal(crossedFinish(.96,.03),true);assert.equal(crossedFinish(.4,.5),false);assert.ok(lapProgress(TRACK.rx,0)<.01);});

test("browser racing world is a large-scale circuit with a road wider than two cars",async()=>{const {readFile}=await import("node:fs/promises");const source=await readFile(new URL("../src/web-game.js",import.meta.url),"utf8");assert.match(source,/TRACK_RADIUS_X=1180,TRACK_RADIUS_Y=760,ROAD_HALF_WIDTH=120/);assert.match(source,/stroke\("#0007",330\);stroke\(w\[2\],306\);stroke\(w\[4\],270\);stroke\(w\[2\],238\)/);assert.match(source,/ctx\.rotate\(c\.angle\+Math\.PI\/2\)/);assert.match(source,/ctx\.rotate\(f\.angle\+Math\.PI\/2(?:\+\(r\.yaw\|\|0\))?\)/);assert.match(source,/ctx\.rotate\(-c\.angle-Math\.PI\/2\)/);});

test("large-world static track cache maps world coordinates back to the camera world",async()=>{const {readFile}=await import("node:fs/promises");const source=await readFile(new URL("../src/web-game.js",import.meta.url),"utf8");assert.ok(source.includes("ctx.setTransform(.5,0,0,.5,800,600)"));assert.ok(source.includes("ctx.drawImage(trackCache,-1600,-1200,3200,2400)"));});
