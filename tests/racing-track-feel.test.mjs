import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [game, dynamics, tires] = await Promise.all([
 readFile(new URL("../src/web-game.js", import.meta.url), "utf8"),
 readFile(new URL("../src/vehicle-dynamics.js", import.meta.url), "utf8"),
 readFile(new URL("../src/tire-physics.js", import.meta.url), "utf8")
]);

test("wider race surface is shared by renderer, edge response and AI lanes",()=>{
 assert.match(game,/ROAD_HALF_WIDTH=220/);
 assert.match(game,/lanes:\[-165,-82.5,82.5,165\]/);
 assert.match(game,/Math\.abs\(car\.lateral\)/);
});

test("obstacle impacts use a swept contact envelope and rigid barrier response",()=>{
 assert.match(game,/sweptPickupContact\(previousPlayerPosition,c,\{x,y\},50\)/);
 assert.match(game,/resolveBarrierImpact\(body,dx\/len,dy\/len\)/);
 assert.match(game,/applyDamageAndDestruction\(car,hit\.energy/);
});

test("brake plus steering activates the controlled drift tyre model",()=>{
 assert.match(game,/drift:input\.brake&&Math\.abs\(input\.steer\)>.3/);
 assert.match(dynamics,/drift: controls\.drift === true/);
 assert.match(tires,/rearGripScale=Math\.sqrt\(rearAxleLoadFraction\/.5\)\*\(drift\?\.76:1\)/);
 assert.match(tires,/lateralDamping=\(drift\?2\.9:5\.5\)/);
});
