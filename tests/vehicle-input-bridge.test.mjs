import test from "node:test";
import assert from "node:assert/strict";
import { mapInputSnapshotToVehicleControls } from "../src/vehicle-input-bridge.js";

test("one coherent snapshot maps steering, throttle, brake and turbo independently",()=>{
 const controls=mapInputSnapshotToVehicleControls({steering:.7,throttle:1,brake:1,turbo:true},.42);
 assert.deepEqual(controls,{steer:.42,throttle:1,brake:1,turbo:true});
});

test("analog pedal values are clamped independently",()=>{
 const controls=mapInputSnapshotToVehicleControls({steering:0,throttle:.35,brake:.8,turbo:false});
 assert.equal(controls.throttle,.35);assert.equal(controls.brake,.8);
});

test("legacy boolean pedals remain compatible and invalid values fail neutral",()=>{
 assert.deepEqual(mapInputSnapshotToVehicleControls({steering:2,throttle:true,brake:false,turbo:0}),{steer:1,throttle:1,brake:0,turbo:false});
 assert.deepEqual(mapInputSnapshotToVehicleControls({steering:NaN,throttle:NaN,brake:Infinity,turbo:null}),{steer:0,throttle:0,brake:0,turbo:false});
});
