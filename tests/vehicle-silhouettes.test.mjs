import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const renderer = await readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8");
const models = await readFile(new URL("../src/vehicle-showroom-3d.js", import.meta.url), "utf8");
const game = await readFile(new URL("../src/web-game.js", import.meta.url), "utf8");

test("the 3D renderer defines ten distinct player and AI vehicle silhouettes", () => {
  const profiles = ["rally", "comet", "lynx", "thunder", "raptor", "ai-formula", "ai-pickup", "ai-rallycross", "ai-touring", "ai-prototype"];
  for (const id of profiles) assert.match(renderer, new RegExp('(?:^|[,{\\s])"?'+id+'"?:'));
  assert.match(renderer, /const AI_VEHICLE_SHAPES=\[/);
  assert.match(renderer, /function vehicleShapeFor\(/);
});

test("garage cars have distinct proportions, wheel sizes and body styles", () => {
  assert.match(renderer, /comet:\{width:1\.03,length:1\.14,bodyY:\.84/);
  assert.match(renderer, /lynx:\{width:1\.13,length:1,bodyY:1\.22/);
  assert.match(renderer, /thunder:\{width:1\.08,length:1\.06,bodyY:\.86/);
  assert.match(renderer, /raptor:\{width:1\.17,length:1\.04,bodyY:1\.12/);
  assert.match(models, /style:"pickup"/);
  assert.match(models, /style:"formula"/);
});

test("vehicle meshes are cached per silhouette and released on renderer teardown", () => {
  assert.match(renderer, /carPartSets=new Map\(\)/);
  assert.match(renderer, /function getCarParts\(id\)/);
  assert.match(renderer, /\[\.\.\.carPartSets\.values\(\)\]\.flat\(\)/);
});

test("the selected garage vehicle identity reaches the 3D player renderer", () => {
  assert.match(game, /modelId:activeCar\(\)\.id/);
  assert.match(renderer, /snapshot\.player\.modelId/);
});

test("additional AI meshes are queued and uploaded progressively", () => {
  assert.match(renderer, /carBuildQueue=\[\]/);
  assert.match(renderer, /carBuildQueued=new Set\(\)/);
  assert.match(renderer, /if\(carBuildQueue\.length\)/);
  assert.match(renderer, /return carPartSets\.values\(\)\.next\(\)\.value/);
});

test("race and showroom renderers consume the same sculpted race-car body meshes", () => {
  assert.match(renderer, /buildVehicleGeometry\(id\)\.map/);
  assert.match(models, /Deep wheel arches, flared fenders/);
  assert.match(models, /quad\(trim,point\(p\.wheel\+8/);
  assert.match(models, /Hood creases, front grille, intakes and LED signatures/);
  assert.match(models, /multi-spoke alloys/);
});
