import test from "node:test";
import { readFile } from "node:fs/promises";
import assert from "node:assert/strict";
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
  for (let tile = 0; tile < CITY_GRID_SIZE; tile++) {
    assert.equal(worldToCityTile(cityTileToWorld(tile)), tile);
  }
  assert.equal(cityTileToWorld(0), -124);
  assert.equal(cityTileToWorld(31), 124);
});

test("architectural visual scale expands procedural buildings into metre-sized assets", () => {
  for (const type of ["home", "shop", "industrial", "administrative", "service"]) {
    const scale = getBuildingVisualScale(type);
    assert.equal(scale.x, 4.8);
    assert.equal(scale.z, 4.8);
    assert.equal(scale.y, 2.2);
  }
});

test("renderer and architecture consume the shared metre scale without legacy 2 m placement", async () => {
  const renderer = await readFile(new URL("../src/city/city-three-renderer.js", import.meta.url), "utf8");
  const buildings = await readFile(new URL("../src/city/city-building-high-gfx.js", import.meta.url), "utf8");
  assert.match(renderer, /cityTileToWorld\(x - 16\)/);
  assert.match(renderer, /worldToCityTile\(point\.x\)/);
  assert.match(renderer, /Math\.max\(0\.0625, Math\.min\(1\.875/);
  assert.match(renderer, /BoxGeometry\(CITY_TILE_METERS - 0\.06/);
  assert.match(renderer, /trafficDummy\.scale\.set\(1\.76, 1\.5, 2\.53\)/);
  assert.match(renderer, /pedestrianDummy\.scale\.set\(1\.8, 2\.8, 1\.8\)/);
  assert.match(renderer, /pedestrianDummy\.scale\.set\(1\.3, 1\.3, 1\.3\)/);
  assert.match(buildings, /group\.scale\.set\(visualScale\.x, visualScale\.y, visualScale\.z\)/);
  assert.match(buildings, /BoxGeometry\(0\.17, 0\.96, 0\.05\)/);
  assert.match(buildings, /BoxGeometry\(0\.20, 0\.55, 0\.04\)/);
  assert.ok(renderer.length < 35_000, "city renderer must remain under its architecture size budget");
});
