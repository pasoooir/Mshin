import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [game, renderer, vehicle] = await Promise.all([
  readFile(new URL("../src/web-game.js", import.meta.url), "utf8"),
  readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8"),
  readFile(new URL("../src/vehicle-showroom-3d.js", import.meta.url), "utf8")
]);

test("3D race minimap is anchored at the upper-left and updates live", () => {
  assert.match(game, /function drawMinimap\(target=ctx\)/);
  assert.match(game, /const mw=Math\.min\(164,width\*\.34\),mh=mw\*\.68,x=14,y=88/);
  assert.match(game, /drawMinimap\(racePositionCtx\)/);
  assert.match(game, /rivals\.forEach\(r=>\{if\(!r\.despawned&&!r\.destruction\?\.despawned\)marker\(r\.distance,r\.lateral,r\.color/);
  assert.match(game, /Math\.sin\(now\*\.009\)/, "player marker must blink");
  assert.match(game, /marker\(car\.t,car\.lateral,"#ffe34d",5,true\)/);
  assert.match(game, /window\.MshinRaceMinimap=\{visible:true,anchor:"top-left",playerBlink:true,rivalCount:/);
});

test("all race entrants use the open-wheel formula profile with individual paint", () => {
  assert.match(renderer, /function vehicleShapeFor\(kind,id\)\{return kind==="player"\|\|kind==="car"\|\|kind==="formula"\?"ai-formula":AI_VEHICLE_SHAPES/);
  assert.match(renderer, /carParts\[i\]\.color=paint/);
  assert.match(vehicle, /"ai-formula":\{[^}]*style:"formula"/);
  assert.match(vehicle, /if\(p\.style==="formula"\)/);
});
