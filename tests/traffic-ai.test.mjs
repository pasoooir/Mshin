import test from "node:test";
import assert from "node:assert/strict";
import {stepTrafficVehicle,trafficFollowingGap} from "../src/traffic-ai.js";

const lanes=[-42,0,42];
test("traffic advances continuously with bounded speed and no lane teleport",()=>{
 const car={id:1,distance:20,speed:180,lateral:0,lateralVelocity:0,laneIndex:1,targetLane:1};
 const before=car.distance;
 stepTrafficVehicle(car,{trackLength:1000,lanes,dt:1/60,cruiseSpeed:220});
 assert.ok(car.distance>before);assert.ok(car.speed>=45&&car.speed<=237);
 assert.ok(Math.abs(car.lateral)<3);
});
test("blocked traffic chooses a clear adjacent lane and moves laterally over time",()=>{
 const car={id:2,distance:100,speed:210,lateral:0,lateralVelocity:0,laneIndex:1,targetLane:1,changeCooldown:0};
 const blocker={distance:150,speed:90,lateral:0};
 stepTrafficVehicle(car,{trackLength:2000,lanes,neighbors:[blocker],dt:1/60,cruiseSpeed:230});
 assert.notEqual(car.targetLane,1);
 const start=car.lateral;
 for(let i=0;i<60;i++)stepTrafficVehicle(car,{trackLength:2000,lanes,neighbors:[blocker],dt:1/60,cruiseSpeed:230});
 assert.notEqual(car.lateral,start);
 assert.ok(Math.abs(car.lateral)<=54);
});
test("player and other traffic are considered when evaluating safe gaps",()=>{
 const car={id:3,distance:200,speed:180,lateral:0,lateralVelocity:0,laneIndex:1,targetLane:1,changeCooldown:0};
 const player={distance:245,lateral:0,speed:100};
 stepTrafficVehicle(car,{trackLength:2000,lanes,player,dt:1/60});
 assert.notEqual(car.targetLane,1);
});
test("traffic wraps circuit progress and remains finite under invalid inputs",()=>{
 const car={id:4,distance:999,speed:160,lateral:0,lateralVelocity:0,laneIndex:1,targetLane:1};
 stepTrafficVehicle(car,{trackLength:1000,lanes,dt:1,curvature:NaN});
 assert.ok(car.distance>=0&&car.distance<1000);
 assert.ok(Number.isFinite(car.speed)&&Number.isFinite(car.lateral));
});
test("following gap is bounded",()=>{assert.ok(trafficFollowingGap(200)>=72);assert.ok(trafficFollowingGap(1000)<=190)});
