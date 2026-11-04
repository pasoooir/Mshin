import test from "node:test";
import assert from "node:assert/strict";
import { CITY_VISUAL_ASSET_CATALOG, CITY_WORLD_ASSET_CATEGORIES, getCityAssetDefinition } from "../src/city/city-visual-asset-catalog.js";

test("all specifically requested building categories have real-world dimensions and visual requirements", () => {
  for (const key of ["house","shop","tower","hardware_store","school","cafe_restaurant","mosque"]) {
    const asset = getCityAssetDefinition(key);
    assert.ok(asset, key + " catalogue entry missing");
    assert.ok(asset.dimensions.width >= 8 && asset.dimensions.depth >= 8 && asset.dimensions.height >= 5);
    assert.ok(asset.footprintTiles.width >= 1 && asset.footprintTiles.depth >= 1);
    assert.ok(asset.materials.length >= 3);
    assert.ok(asset.details.length >= 5);
    assert.match(asset.referenceSearch, /real/i);
  }
});

test("world inventory includes sky, atmosphere, space objects and all major city environment families", () => {
  for (const key of ["sky-and-atmosphere","sun-moon-stars","clouds","mountains-and-horizon","terrain-and-soil","grass-and-ground-cover","water","roads-and-markings","vehicles-and-traffic","street-furniture"]) {
    assert.ok(CITY_WORLD_ASSET_CATEGORIES.includes(key), key + " world category missing");
  }
});

test("catalogue returns null for unknown categories and stable definitions for known ones", () => {
  assert.equal(getCityAssetDefinition("unknown-category"), null);
  assert.equal(getCityAssetDefinition("mosque").label, "مسجد");
});
