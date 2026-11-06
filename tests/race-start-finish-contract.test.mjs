import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const game = await readFile(new URL("../src/web-game.js", import.meta.url), "utf8");

test("the five race entrants are reset together on GO, not during the countdown", () => {
  assert.match(game, /race\.raceEntrants=rivals\.filter\(r=>r\.id<4\);rivals\.forEach\(r=>\{r\.timerElapsed=0;r\.finishTime=null;r\.lapsCompleted=0;r\.totalProgress=0;r\.distance=0;r\.speed=0;r\.startTimestamp=race\.startTimestamp\}\)/);
  assert.match(game, /race\.startTimestamp=performance\.now\(\);race\.elapsed=0/);
  assert.match(game, /window\.MshinRaceStart=\{timestamp:race\.startTimestamp,synchronized:/);
  assert.match(game, /distance:0,totalProgress:0,lapsCompleted:0,timerElapsed:0,finishTime:null/);
});

test("all four opponents occupy distinct road lanes beside the player", () => {
  assert.match(game, /const lanes=\[-165,-55,55,165,-165,55,-55,165\]/);
  assert.match(game, /car\.t=0;car\.lateral=0;/);
  assert.match(game, /distanceScale:trackDistanceScaleAt\(r\.distance\)/);
  assert.match(game, /function trackDistanceScaleAt\(t\)\{const before=center\(t-\.002\),after=center\(t\+\.002\),tangentScale=Math\.hypot\(after\.x-before\.x,after\.y-before\.y\)\/\.004;return TRACK_LENGTH_SCALE\/Math\.max\(1,tangentScale\)\}/);
});

test("AI and player finish times use interpolated finish-line crossing timestamps", () => {
  assert.match(game, /import \{ crossedFinishLine, finishTimestamp \} from "\.\/race-timing\.js"/);
  assert.match(game, /wrapped=crossedFinishLine\(previousDistance,travel,Math\.PI\*2\)/);
  assert.match(game, /r\.finishTime=finishTimestamp\(race\.elapsed,dt,previousDistance,travel,Math\.PI\*2\)/);
  assert.match(game, /race\.playerFinishTime=finishTimestamp\(race\.elapsed,dt,race\.lastT,travel,Math\.PI\*2\)/);
});

test("the event waits for all original AI entrants, retaining destroyed cars as DNFs", () => {
  assert.match(game, /race\.raceEntrants\|\|rivals/);
  assert.match(game, /const rivalDNF=!!rival\.destruction\?\.despawned/);
  assert.match(game, /every\(r=>r\.finishTime!==null\|\|r\.destruction\?\.despawned\)/);
  assert.match(game, /if\(a\.dnf!==b\.dnf\)return a\.dnf\?1:-1/);
});

test("live map places all entrants using normalized track coordinates and publishes moving markers", () => {
  assert.match(game, /worldX\/\(TRACK_RADIUS_X\*2\.3\)\*mw/);
  assert.match(game, /worldY\/\(TRACK_RADIUS_Y\*2\.3\)\*mh/);
  assert.match(game, /window\.MshinRaceMinimap=\{visible:true,anchor:"top-left",playerBlink:true,rivalCount:entrants\.length,player:/);
  assert.match(game, /markers,bounds:\{x,y,width:mw,height:mh\},updatedAt:now/);
  assert.match(game, /dnf\?"#ff665f":r\.color/);
});
