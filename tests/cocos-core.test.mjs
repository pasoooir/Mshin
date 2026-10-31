import test from 'node:test';
import assert from 'node:assert/strict';
import { createRaceState, normalizeJoystick, resolveTrackCollision, stepCar, updateRace, createRigidBody2D, resolveRigidBody2D, resolveRigidVehiclePair, splitImpactEnergy, calculateRacingLineTarget, calculateAiTargetSpeed, worldVelocityToCar, surfaceCollisionFriction } from '../.test-build/src/cocos-core.js';

test('joystick clamps diagonal displacement to unit radius', () => {
 const v = normalizeJoystick(100, 100, 50); assert.ok(Math.hypot(v.x, v.y) <= 1.000001); assert.ok(v.x > 0 && v.y > 0);
});
test('invalid joystick radius or coordinates safely returns neutral input', () => {
 assert.deepEqual(normalizeJoystick(20, 20, 0), { x: 0, y: 0 });
 assert.deepEqual(normalizeJoystick(Number.NaN, 20, 50), { x: 0, y: 0 });
});
test('throttle accelerates and brake reduces speed', () => {
 const car = { x: 0, y: 0, heading: 0, speed: 0 }; stepCar(car, { steer: 0, throttle: true, brake: false }, 0.05);
 assert.ok(car.speed > 0); const before = car.speed; stepCar(car, { steer: 0, throttle: false, brake: true }, 0.05); assert.ok(car.speed < before);
});
test('frame spike is capped and steering remains bounded', () => {
 const car = { x: 0, y: 0, heading: 0, speed: 100 }; stepCar(car, { steer: 50, throttle: true, brake: false }, 2);
 assert.ok(Math.abs(car.heading) < 0.2); assert.ok(car.speed <= 360);
});
test('track collision corrects car back onto playable ring', () => {
 const car = { x: 900, y: 0, heading: 0, speed: 100 }; assert.equal(resolveTrackCollision(car), true);
 const r = Math.hypot(car.x / 420, car.y / 260); assert.ok(r <= 1.18 && r >= 0.82); assert.ok(car.speed < 0);
});
test('race increments lap on forward finish-line wrap and finishes at target', () => {
 const race = createRaceState(); race.previousProgress = 0.95;
 updateRace(race, 420 * Math.cos(0.1), 260 * Math.sin(0.1), 0.05, 1);
 assert.equal(race.lap, 1); assert.equal(race.finished, true); assert.equal(race.elapsedSeconds, 0.05);
});
test('idle and brake never push a stopped car into reverse',()=>{
 const idle={x:0,y:0,heading:0,speed:0};
 stepCar(idle,{steer:0,throttle:false,brake:false},0.05); assert.equal(idle.speed,0);
 stepCar(idle,{steer:0,throttle:false,brake:true},0.05); assert.equal(idle.speed,0);
});
test('low-grip world reduces steering response',()=>{
 const normal={x:0,y:0,heading:0,speed:180},ice={x:0,y:0,heading:0,speed:180};
 stepCar(normal,{steer:1,throttle:false,brake:false,grip:1},0.05);
 stepCar(ice,{steer:1,throttle:false,brake:false,grip:0.68},0.05);
 assert.ok(Math.abs(ice.heading)<Math.abs(normal.heading));
});
test('off-road driving has lower acceleration, speed ceiling and stronger coasting drag',()=>{
 const road={x:0,y:0,heading:0,speed:200},grass={x:0,y:0,heading:0,speed:200};
 stepCar(road,{steer:0,throttle:true,brake:false},0.05);
 stepCar(grass,{steer:0,throttle:true,brake:false,offRoad:true},0.05); assert.ok(grass.speed<road.speed);
 const fast={x:0,y:0,heading:0,speed:350}; stepCar(fast,{steer:0,throttle:true,brake:false,offRoad:true},0.05); assert.ok(fast.speed<=220);
 const coast={x:0,y:0,heading:0,speed:100}; stepCar(coast,{steer:0,throttle:false,brake:false,offRoad:true},0.05); assert.ok(coast.speed<100-95*0.05);
});
test('physics and race clock both cap long frame spikes to one simulation step',()=>{
 const car={x:0,y:0,heading:0,speed:0},race=createRaceState();
 stepCar(car,{steer:0,throttle:true,brake:false},3); updateRace(race,420,0,3,3);
 assert.ok(car.speed<=306*0.05+1e-9); assert.equal(race.elapsedSeconds,0.05);
});
test('invalid frame delta and steering input do not poison car or race state',()=>{
 const car={x:0,y:0,heading:0,speed:10},race=createRaceState();
 stepCar(car,{steer:Number.NaN,throttle:false,brake:false},Number.NaN); updateRace(race,Number.NaN,0,Number.NaN);
 assert.ok(Number.isFinite(car.x)&&Number.isFinite(car.y)&&Number.isFinite(car.heading)&&Number.isFinite(car.speed));
 assert.equal(race.elapsedSeconds,0);
});


test('Cocos rigid-body solver resolves oriented chassis contact against an immovable barrier',()=>{
 const car=createRigidBody2D({x:0,y:0,vx:90,vy:0,angle:0,mass:1300,length:54,width:30});
 const barrier=createRigidBody2D({x:42,y:0,angle:0,mass:1,length:34,width:28,static:true});
 const beforeX=barrier.x,impact=resolveRigidBody2D(car,barrier);
 assert.equal(impact.hit,true);assert.ok(impact.impulse>0);assert.ok(impact.energy>0);
 assert.ok(car.vx<90);assert.equal(barrier.x,beforeX);assert.ok(car.x<0);
});
test('Cocos vehicle pair solver transfers momentum according to mass',()=>{
 const heavy=createRigidBody2D({x:0,y:0,vx:120,vy:0,mass:1900,length:54,width:30});
 const light=createRigidBody2D({x:42,y:0,vx:0,vy:0,mass:800,length:54,width:30});
 const beforeHeavy=heavy.vx,impact=resolveRigidVehiclePair(heavy,light);
 assert.equal(impact.hit,true);assert.ok(light.vx>0);
 assert.ok(Math.abs(heavy.vx-beforeHeavy)<Math.abs(light.vx));
});
test('Cocos rigid-body solver produces angular response for an off-centre side contact',()=>{
 const a=createRigidBody2D({x:0,y:0,vx:80,vy:0,angle:0,mass:1200,length:54,width:30});
 const b=createRigidBody2D({x:35,y:18,vx:0,vy:0,angle:.12,mass:1100,length:54,width:30});
 const impact=resolveRigidBody2D(a,b);
 assert.equal(impact.hit,true);assert.ok(Number.isFinite(a.angularVelocity)&&Number.isFinite(b.angularVelocity));
});
test('Cocos collision chain transfers impulse to a third vehicle',()=>{
 const rear=createRigidBody2D({x:0,y:0,vx:160,vy:0,mass:1400,length:54,width:30});
 const middle=createRigidBody2D({x:42,y:0,vx:0,vy:0,mass:1100,length:54,width:30});
 const front=createRigidBody2D({x:84,y:0,vx:0,vy:0,mass:1000,length:54,width:30});
 const first=resolveRigidVehiclePair(rear,middle),second=resolveRigidVehiclePair(middle,front);
 assert.ok(first.hit&&second.hit);assert.ok(front.vx>0);
});

test('impact energy is assigned by inverse mass, with static barriers absorbing none',()=>{
 const equal=splitImpactEnergy(100,1/1000,1/1000);
 assert.equal(equal.a,50);assert.equal(equal.b,50);
 const heavyLight=splitImpactEnergy(100,1/2000,1/500);
 assert.ok(heavyLight.b>heavyLight.a);assert.equal(heavyLight.a+heavyLight.b,100);
 const wall=splitImpactEnergy(100,1/1200,0);
 assert.equal(wall.a,100);assert.equal(wall.b,0);
});


test('AI racing line offsets cars consistently and wraps at the path boundary',()=>{
 const path=[{x:0,y:0},{x:10,y:0},{x:20,y:0},{x:30,y:0}];
 const left=calculateRacingLineTarget(path,0,4),right=calculateRacingLineTarget(path,0,-4);
 assert.equal(left.x,0);assert.equal(right.x,0);assert.equal(left.y,-4);assert.equal(right.y,4);
 assert.deepEqual(calculateRacingLineTarget(path,4,4),left);
});
test('AI target speed decreases for sharper turns and remains bounded for invalid input',()=>{
 assert.equal(calculateAiTargetSpeed(0),310);
 assert.ok(calculateAiTargetSpeed(1.2)<calculateAiTargetSpeed(.2));
 assert.ok(calculateAiTargetSpeed(Math.PI)>=165);
 assert.equal(calculateAiTargetSpeed(Number.NaN),165);
});

test('AI racing-line planner safely handles invalid indices and lane offsets',()=>{
 const path=[{x:3,y:7},{x:13,y:7},{x:23,y:7}];
 assert.deepEqual(calculateRacingLineTarget(path,Number.NaN,Number.NaN),{x:3,y:7});
 assert.deepEqual(calculateRacingLineTarget([],0,10),{x:0,y:0});
});


test('rear-end impact transfers forward momentum to the leading car and slows the striking car',()=>{
 const rear=createRigidBody2D({x:0,y:0,vx:0,vy:240,angle:Math.PI/2,mass:1250,length:92,width:44,restitution:.12,friction:.72});
 const lead=createRigidBody2D({x:0,y:91,vx:0,vy:120,angle:Math.PI/2,mass:1250,length:92,width:44,restitution:.12,friction:.72});
 const momentumBefore=rear.mass*rear.vy+lead.mass*lead.vy;
 const impact=resolveRigidBody2D(rear,lead);
 assert.equal(impact.hit,true);assert.ok(impact.closingSpeed>0);
 assert.ok(lead.vy>120,'leading car must receive forward impulse');
 assert.ok(rear.vy<240,'striking car must lose forward speed');
 assert.ok(Math.abs((rear.mass*rear.vy+lead.mass*lead.vy)-momentumBefore)<1e-6,'linear momentum must be conserved');
 assert.ok(Math.abs(rear.angularVelocity)<1e-8&&Math.abs(lead.angularVelocity)<1e-8,'centred rear-end impact must not invent yaw');
});
test('off-centre rear impact creates yaw and persistent lateral velocity instead of discarding the impulse',()=>{
 const rear=createRigidBody2D({x:0,y:0,vx:18,vy:230,angle:Math.PI/2,mass:1250,length:92,width:44});
 const lead=createRigidBody2D({x:12,y:91,vx:0,vy:100,angle:Math.PI/2,mass:1250,length:92,width:44});
 const impact=resolveRigidBody2D(rear,lead);
 assert.equal(impact.hit,true);
 assert.ok(Math.abs(rear.angularVelocity)+Math.abs(lead.angularVelocity)>1e-7);
 const projected=worldVelocityToCar(lead.vx,lead.vy,Math.PI);
 assert.ok(Math.abs(projected.lateralSpeed)>0.01,'lateral component must survive collision projection');
});
test('aerodynamic drag scales quadratically with speed and tire grip damps lateral slip',()=>{
 const slow={x:0,y:0,heading:0,speed:100,lateralSpeed:20},fast={x:0,y:0,heading:0,speed:300,lateralSpeed:20};
 stepCar(slow,{steer:0,throttle:false,brake:false},.05);
 stepCar(fast,{steer:0,throttle:false,brake:false},.05);
 const slowLoss=100-95*.05-slow.speed,fastLoss=300-95*.05-fast.speed;
 assert.ok(fastLoss>slowLoss*7,'quadratic aero drag should be substantially stronger at 3x speed');
 assert.ok(Math.abs(slow.lateralSpeed)<20,'tire forces should damp lateral slip');
});


test('surface collision friction follows asphalt, dirt and wet grip without invalid coefficients',()=>{
 assert.ok(surfaceCollisionFriction(1)>surfaceCollisionFriction(.55));
 assert.ok(surfaceCollisionFriction(.55)>surfaceCollisionFriction(.35));
 assert.ok(surfaceCollisionFriction(1.15)<=.82);
 assert.ok(surfaceCollisionFriction(Number.NaN)>0);
});
