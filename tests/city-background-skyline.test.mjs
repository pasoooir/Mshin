import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const skyline = await readFile(new URL("../src/city/city-background-skyline.js", import.meta.url), "utf8");
const renderer = await readFile(new URL("../src/city/city-three-renderer.js", import.meta.url), "utf8");

test("first-launch city does not render a distant skyline before the player builds", () => {
  assert.ok(skyline.includes("index < 18"));
  assert.ok(skyline.includes("positions.push([along, -352], [along, 352], [-352, along], [352, along])"));
  assert.ok(skyline.includes("new THREE.InstancedMesh(unitGeometry, concreteMaterial, 48)"));
  assert.ok(skyline.includes("new THREE.InstancedMesh(unitGeometry, masonryMaterial, 48)"));
  assert.match(renderer,/const backgroundSkyline = \{ buildingCount: 0, windowCount: 0, dispose\(\) \{\} \};/);\n  assert.doesNotMatch(renderer,/const backgroundSkyline = createCityBackgroundSkyline/);
  assert.ok(renderer.includes("backgroundCityBuildings: backgroundSkyline.buildingCount"));\n  assert.ok(renderer.includes("backgroundCityWindows: backgroundSkyline.windowCount"));
});

test("background towers have variable heights, rooftop equipment and four-sided windows", () => {
  assert.ok(skyline.includes("const floors = 5 + Math.floor(random() * 9)"));
  assert.ok(skyline.includes("roofUnits.setMatrixAt"));
  assert.ok(skyline.includes("windows.setMatrixAt"));
  assert.ok(skyline.includes("side < 0 ? Math.PI : 0"));
  assert.ok(skyline.includes("side > 0 ? Math.PI / 2 : -Math.PI / 2"));
  assert.ok(skyline.includes("background-city-skyline"));
});

test("skyline stays instanced and releases its own GPU resources", () => {
  assert.ok(skyline.includes("new THREE.InstancedMesh(new THREE.BoxGeometry(0.56, 0.72, 0.055), glassMaterial, 16000)"));
  assert.ok(skyline.includes("dispose()"));
  assert.ok(skyline.includes("windowMaterials.delete(glassMaterial)"));
  assert.ok(renderer.includes("backgroundSkyline.dispose()"));
});
