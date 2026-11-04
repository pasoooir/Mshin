import test from "node:test";
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
