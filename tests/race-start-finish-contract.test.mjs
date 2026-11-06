import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const game = await readFile(new URL("../src/web-game.js", import.meta.url), "utf8");

test("the five race entrants are reset together on GO, not during the countdown", () => {
  assert.match(game, /race\.raceEntrants=rivals\.filter\(r=>r\.id<4\);rivals\.forEach\(r=>\{r\.timerElapsed=0;r\.finishTime=null;r\.lapsCompleted=0;r\.totalProgress=0;r\.distance=0;r\.speed=0\}\)/);
  assert.match(game, /race\.startTimestamp=performance\.now\(\);race\.elapsed=0/);
  assert.match(game, /distance:0,totalProgress:0,lapsCompleted:0,timerElapsed:0,finishTime:null/);
});

test("all four opponents occupy distinct road lanes beside the player", () => {
  assert.match(game, /const lanes=\[-165,-55,55,165,-165,55,-55,165\]/);
  assert.match(game, /car\.t=0;car\.lateral=0;/);
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

test("live map keeps all four original opponents visible with their current ranks", () => {
  assert.match(game, /\(race\.raceEntrants\|\|rivals\)\.forEach\(r=>\{if\(!r\.despawned\)/);
  assert.match(game, /dnf\?"#ff665f":r\.color/);
  assert.match(game, /target\.fillText\(String\(r\.rank\|\|"-"\),px,py-7\)/);
});
