import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [game, renderer] = await Promise.all([
  readFile(new URL("../src/web-game.js", import.meta.url), "utf8"),
  readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8")
]);

test("the five race entrants are reset together on GO, not during the countdown", () => {
  assert.match(game, /race\.raceEntrants=rivals\.filter\(r=>r\.id<4\);rivals\.forEach\(r=>\{r\.clock=startRaceClock\(r\.clock,race\.startTimestamp\);r\.timerElapsed=0;r\.finishTime=null;r\.lapsCompleted=0;r\.totalProgress=0;r\.distance=0;r\.speed=0;r\.startTimestamp=race\.startTimestamp\}\)/);
  assert.match(game, /race\.startTimestamp=performance\.now\(\);race\.playerClock=startRaceClock\(race\.playerClock,race\.startTimestamp\);race\.elapsed=0/);
  assert.match(game, /window\.MshinRaceStart=\{timestamp:race\.startTimestamp,synchronized:/);
  assert.match(game, /window\.MshinRaceClocks=\{startTimestamp:race\.startTimestamp\?\?null,racers:rows\.map/);
  assert.match(game, /clock:createRaceClock\(\),timerElapsed:0,finishTime:null/);
  assert.match(game, /const spec=specs\[type\],mass=spec\.mass/);
  assert.match(game, /cruiseFactor=i<4\?1:spec\.cruise/);
  assert.match(game, /speed:i<4\?0:activeCar\(\)\.max\*cruiseFactor/, "race rivals start at zero while ambient traffic retains its own pace");
  assert.match(game, /speedLimit:aiMaxSpeed,acceleration:aiAcceleration/, "AI performance must use the selected player's shared engine limits");
  assert.match(game, /isRaceRival=r\.id<4/);
  assert.match(game, /laneChanges:!isRaceRival/, "only the four race rivals keep separate lanes for synchronized pacing");
  assert.match(game, /neighbors:isRaceRival\?\(race\.raceEntrants\|\|rivals\.filter\(other=>other\.id<4\)\):rivals/, "ambient traffic must not change the pace of the four race entrants");
  assert.match(game, /window\.MshinRacePace=\{speedLimit:aiMaxSpeed,acceleration:aiAcceleration,vehicles:/, "the shared performance profile must be observable in runtime tests");
  assert.match(game, /race\.playerClock=createRaceClock\(\);race\.raceEntrants=null/);
  assert.match(game, /audio\.ready\(\)\.then\(audioReady=>/, "mobile race startup must not be blocked when optional audio decoding is unavailable");
});

test("all four opponents occupy distinct road lanes beside the player on a shared countdown row", () => {
  assert.match(game, /const lanes=\[-165,-82\.5,82\.5,165,-165,82\.5,-82\.5,165\]/);
  assert.match(game, /lanes:\[-165,-82\.5,82\.5,165\]/);
  assert.match(game, /car\.t=0;car\.lateral=0;/);
  assert.match(game, /const scale=Math\.min\(1\.18,width\/480\),playerX=width\*\.5,playerY=height\*\.62/);
  assert.match(game, /gridX=\[\.16,\.33,\.67,.84\],x=width\*gridX\[i\],y=height\*\.62/);
  assert.match(game, /gridX=\[\.16,\.33,\.5,\.67,\.84\]/);
  assert.match(game, /race3d\.render\(\{state,stageId:stage\.id,world:stage\.world,frameAt,raceElapsed:race\.elapsed/);
  assert.match(renderer, /startingGrid=snapshot\.state==="countdown"\|\|\(Number\(snapshot\.raceElapsed\)\|\|0\)<2\.5,maxVisible=startingGrid\?4/);
});

test("AI and player finish times use interpolated finish-line crossing timestamps", () => {
  assert.match(game, /import \{ crossedFinishLine, finishTimestamp, createRaceClock, startRaceClock, advanceRaceClock, finishRaceClock \} from "\.\/race-timing\.js"/);
  assert.match(game, /wrapped=crossedFinishLine\(previousDistance,travel,Math\.PI\*2\)/);
  assert.match(game, /r\.finishTime=finishTimestamp\(race\.elapsed,dt,previousDistance,travel,Math\.PI\*2\)/);
  assert.match(game, /race\.playerFinishTime=finishTimestamp\(race\.elapsed,dt,race\.lastT,travel,Math\.PI\*2\)/);
  assert.match(game, /finishRaceClock\(r\.clock,r\.finishTime\)/);
  assert.match(game, /finishRaceClock\(race\.playerClock,race\.playerFinishTime\)/);
  assert.match(game, /\$\("time"\)\.textContent=formatRaceClock\(race\.playerClock\?\.elapsed\?\?race\.elapsed\)/);
  assert.match(game, /RANK · DRIVER/);
  assert.match(game, /formatRaceClock\(row\.finished\?row\.finishTime:row\.elapsed\)/, "the live table must show each vehicle's own running or final stopwatch");
  assert.match(game, /row\.dnf\?"DNF "\+formatRaceClock\(row\.elapsed\)/, "DNF cars must retain their frozen individual stopwatch");
});

test("AI circuit speed uses the same world-distance conversion as the player", () => {
  assert.match(game, /function trackDistanceScaleAt\(t\)/);
  assert.match(game, /distanceScale:trackDistanceScaleAt\(r\.distance\)/);
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
