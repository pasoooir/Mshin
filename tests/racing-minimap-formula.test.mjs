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
  assert.match(game, /const mapPoint=\(t,lateral=0\)=>/);
  assert.match(game, /worldX\/\(TRACK_RADIUS_X\*2\.3\)\*mw/);
  assert.match(game, /worldY\/\(TRACK_RADIUS_Y\*2\.3\)\*mh/);
  assert.match(game, /entrants\.forEach\(r=>\{const dnf=!!r\.destruction\?\.despawned,point=mapPoint\(r\.distance,r\.lateral\)/);
  assert.match(game, /markers,bounds:\{x,y,width:mw,height:mh\},updatedAt:now/);
  assert.match(game, /target\.fillText\(String\(r\.rank\|\|"-"\),px,py-7\)/, "each rival map marker should display its live rank");
  assert.match(game, /Math\.sin\(now\*\.009\)/, "player marker must blink");
  assert.match(game, /marker\(car\.t,car\.lateral,"#ffe34d",5,true\)/);
  assert.match(game, /target\.fillText\(String\(playerRank\)/, "the player marker should display the live rank");
  assert.match(game, /window\.MshinRaceMinimap=\{visible:true,anchor:"top-left",playerBlink:true,rivalCount:/);
});

test("all race entrants use the open-wheel formula profile with individual paint", () => {
  assert.match(renderer, /function vehicleShapeFor\(kind,id\)\{return kind==="player"\|\|kind==="car"\|\|kind==="formula"\?"ai-formula":AI_VEHICLE_SHAPES/);
  assert.match(renderer, /carParts\[i\]\.color=paint/);
  assert.match(vehicle, /"ai-formula":\{[^}]*style:"formula"/);
  assert.match(vehicle, /if\(p\.style==="formula"\)/);
});
