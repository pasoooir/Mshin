import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/web-game.js", import.meta.url), "utf8");

test("browser race connects every vehicle impact to progressive destruction", () => {
  assert.match(source, /import \{ createDestructionState, applyDestructionImpact, stepDestruction, destructionVisuals \} from "\.\/vehicle-destruction\.js"/);
  assert.match(source, /function applyDamageAndDestruction\(vehicle,energy,side="front"\)/);
  assert.match(source, /applyDestructionImpact\(vehicle\.destruction/);
  assert.match(source, /applyDamageAndDestruction\(car,energyShare\.a,side\)/);
  assert.match(source, /applyDamageAndDestruction\(r,energyShare\.b/);
  assert.match(source, /applyDamageAndDestruction\(a,energyShare\.a,"front"\)/);
  assert.match(source, /applyDamageAndDestruction\(b,energyShare\.b,"front"\)/);
});

test("browser renderer exposes panel soot, fire, smoke and one-shot explosion feedback", () => {
  assert.match(source, /function drawDestructionOverlay\(target,state\)/);
  assert.match(source, /visual\.soot/);
  assert.match(source, /visual\.fire/);
  assert.match(source, /visual\.explosion/);
  assert.match(source, /vehicle\.destructionEffectPlayed/);
  assert.match(source, /emitParticle\(x\+Math\.cos\(h\)\*34/);
});

test("burnt rivals leave traffic, collision, minimap and ranking participation", () => {
  assert.match(source, /rivals=rivals\.filter\(r=>!r\.destruction\?\.despawned\)/);
  assert.match(source, /if\(a\.destruction\?\.despawned\|\|b\.destruction\?\.despawned\)/);
  assert.match(source, /!r\.destruction\?\.despawned&&r\.distance>/);
  assert.match(source, /if\(!r\.destruction\?\.despawned\)dot\(r\.distance/);
});

test("player destruction ends the race explicitly rather than silently removing the car", () => {
  assert.match(source, /if\(car\.destruction\?\.despawned&&!race\.finished\)/);
  assert.match(source, /خودروی شما پس از انفجار و سوختن از کار افتاد/);
});
