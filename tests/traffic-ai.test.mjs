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

test("AI circuit progress uses the same world-distance scale as the player",()=>{
 const car={id:8,distance:0,speed:200,lateral:0,lateralVelocity:0,laneIndex:1,targetLane:1};
 const distanceScale=10/10000,dt=1/60;
 stepTrafficVehicle(car,{trackLength:Math.PI*2,lanes,dt,cruiseSpeed:200,distanceScale});
 assert.ok(Math.abs(car.distance-200*dt*distanceScale)<1e-12,
  "AI distance per second must match player world speed projected onto the same track radius");
});


test("all AI rivals use identical acceleration and top speed from a shared start",()=>{
 const raceLanes=[-165,-82.5,82.5,165];
 const cars=Array.from({length:4},(_,id)=>({id,distance:0,speed:0,lateral:raceLanes[id],lateralVelocity:0,laneIndex:id,targetLane:id}));
 const options={trackLength:Math.PI*2,lanes:raceLanes,neighbors:cars,dt:1/60,cruiseSpeed:402.6,maxSpeed:402.6,acceleration:318.5,laneChanges:false,distanceScale:10/10000};
 for(let frame=0;frame<60;frame++)for(const car of cars)stepTrafficVehicle(car,options);
 assert.ok(cars.every(car=>Math.abs(car.speed-cars[0].speed)<1e-9),"identical AI cars must accelerate at the same rate");
 assert.ok(cars.every(car=>Math.abs(car.distance-cars[0].distance)<1e-9),"identical AI cars must cover the same distance from the shared GO");
 assert.ok(cars.every(car=>car.speed<=options.maxSpeed),"no rival may exceed the shared vehicle speed limit");
});
