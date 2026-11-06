import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/web-game.js", import.meta.url), "utf8");

test("browser race connects every vehicle impact to progressive destruction", () => {
  assert.match(source, /import \{ createDestructionState, applyDestructionImpact, stepDestruction, destructionVisuals \} from "\.\/vehicle-destruction\.js"/);
  assert.match(source, /function applyDamageAndDestruction\(vehicle,energy,side="front",impactScale=1\)/);
  assert.match(source, /applyDestructionImpact\(vehicle\.destruction/);
  assert.match(source, /applyDamageAndDestruction\(car,energyShare\.a,side,playerImpactScale\)/);
  assert.match(source, /applyDamageAndDestruction\(r,energyShare\.b/);
  assert.match(source, /applyDamageAndDestruction\(a,energyShare\.a,"front",impactScaleA\)/);
  assert.match(source, /applyDamageAndDestruction\(b,energyShare\.b,"front",impactScaleB\)/);
});

test("browser renderer exposes panel soot, fire, smoke and one-shot explosion feedback", () => {
  assert.match(source, /function drawDestructionOverlay\(target,state\)/);
  assert.match(source, /visual\.soot/);
  assert.match(source, /visual\.fire/);
  assert.match(source, /visual\.explosion/);
  assert.match(source, /vehicle\.destructionEffectPlayed/);
  assert.match(source, /emitParticle\(x\+Math\.cos\(h\)\*34/);
  assert.match(source, /"source-over"\)/);
});

test("burnt rivals leave active traffic but remain visible and ranked as DNFs", () => {
  assert.match(source, /rivals=rivals\.filter\(r=>!r\.destruction\?\.despawned\)/);
  assert.match(source, /if\(a\.destruction\?\.despawned\|\|b\.destruction\?\.despawned\|\|a\.finishTime!==null\|\|b\.finishTime!==null\|\|a\.collisionCooldown/);
  assert.match(source, /if\(rival\.id>=4\)continue/);
  assert.match(source, /const rivalDNF=!!rival\.destruction\?\.despawned/);
  assert.match(source, /entrants\.forEach\(r=>\{const dnf=!!r\.destruction\?\.despawned/);
  assert.match(source, /dnf\?"#ff665f":r\.color/);
});

test("player destruction ends the race explicitly rather than silently removing the car", () => {
  assert.match(source, /if\(car\.destruction\?\.despawned&&!race\.finished&&race\.playerFinishTime===null\)/);
  assert.match(source, /race\.playerDNF=true/);
  assert.match(source, /YOU LOST! Your car was destroyed 3 times. Race over\./);
});
