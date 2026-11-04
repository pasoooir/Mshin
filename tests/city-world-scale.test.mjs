import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import {
  CITY_TILE_METERS, CITY_GRID_SIZE, CITY_WORLD_EXTENT_METERS,
  WORLD_UNIT_METERS, cityTileToWorld, worldToCityTile, getBuildingVisualScale
} from "../src/city/city-world-scale.js";

test("city world uses metres and eight-metre road/parcel cells", () => {
  assert.equal(WORLD_UNIT_METERS, 1);
  assert.equal(CITY_TILE_METERS, 8);
  assert.equal(CITY_GRID_SIZE, 32);
  assert.equal(CITY_WORLD_EXTENT_METERS, 256);
});

test("tile/world transforms preserve every cell centre including grid edges", () => {
  for (let tile = 0; tile < CITY_GRID_SIZE; tile++) assert.equal(worldToCityTile(cityTileToWorld(tile)), tile);
  assert.equal(cityTileToWorld(0), -124);
  assert.equal(cityTileToWorld(31), 124);
});

test("procedural buildings fill parcel scale while doors and windows retain human dimensions", async () => {
  const scale = getBuildingVisualScale("home");
  assert.deepEqual(scale, { x: 4.8, y: 2.2, z: 4.8 });
  const source = await readFile(new URL("../src/city/city-building-high-gfx.js", import.meta.url), "utf8");
  assert.match(source, /BoxGeometry\(0\.17, 0\.96, 0\.05\)/);
  assert.match(source, /BoxGeometry\(0\.20, 0\.55, 0\.04\)/);
});

test("renderer scales the district, vehicles, pedestrians and zoom range from the shared contract", async () => {
  const source = await readFile(new URL("../src/city/city-three-renderer.js", import.meta.url), "utf8");
  assert.match(source, /cityTileToWorld\(x - 16\)/);
  assert.match(source, /worldToCityTile\(point\.x\)/);
  assert.match(source, /Math\.max\(0\.0625, Math\.min\(1\.875/);
  assert.match(source, /trafficDummy\.scale\.set\(1\.76, 1\.5, 2\.53\)/);
  assert.match(source, /pedestrianDummy\.scale\.set\(1\.8, 2\.8, 1\.8\)/);
  assert.ok(source.length < 35_000, "renderer must stay under its 35 KB architecture budget");
});
