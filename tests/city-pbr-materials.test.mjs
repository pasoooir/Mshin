import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const renderer = await readFile(new URL("../src/city/city-three-renderer.js", import.meta.url), "utf8");
const textures = await readFile(new URL("../src/city/city-pbr-textures.js", import.meta.url), "utf8");
const streets = await readFile(new URL("../src/city/city-street-renderer.js", import.meta.url), "utf8");

test("city surfaces use layered tileable albedo, normal and roughness maps", () => {
  assert.ok(textures.includes("function makePbrSurface(THREE, renderer, kind, base, seed)"));
  for (const family of ["grass", "asphalt", "brick", "concrete", "roof", "sidewalk"]) {
    assert.ok(textures.includes('makePbrSurface(THREE, renderer, "' + family + '"'), family + " texture family must exist");
  }
  assert.ok(textures.includes("new THREE.CanvasTexture(normalCanvas)"));
  assert.ok(textures.includes("new THREE.CanvasTexture(roughCanvas)"));
  assert.ok(textures.includes("texture.wrapS = texture.wrapT = THREE.RepeatWrapping"));
  assert.ok(textures.includes("normalMap: normalTexture"));
  assert.ok(textures.includes("roughnessMap: roughnessTexture"));
});

test("roads, terrain, building facades and roofs consume physically based surface maps", () => {
  assert.ok(renderer.includes("...grassSurface"));
  assert.ok(renderer.includes("...asphaltSurface"));
  assert.ok(renderer.includes("...facadeSurface"));
  assert.ok(renderer.includes("...roofSurface"));
  assert.ok(renderer.includes("type === \"industrial\" || type === \"administrative\" ? concreteSurface : brickSurface"));
  assert.ok(renderer.includes("sidewalkSurface"));
  assert.ok(streets.includes("...(surface || {})"));
});

test("residential roof silhouette is a rectangular two-slope gable, not a pyramid primitive", () => {
  assert.ok(renderer.includes("Rectangular two-slope gable roof"));
  assert.ok(renderer.includes("roofGeometry.setIndex([0,1,2,0,2,3,4,5,6,4,6,7])"));
  assert.ok(!renderer.includes("new THREE.ConeGeometry(1.08, 0.72, 4)"));
});

test("city visual identity uses a muted architectural palette and reports PBR acceptance metrics", () => {
  assert.ok(renderer.includes('visualStyle: "realistic-pbr-city"'));
  assert.ok(renderer.includes("pbrMaterialSets: 6"));
  assert.ok(renderer.includes("normalMappedSurfaces: 6"));
  assert.ok(!renderer.includes('visualStyle: "vibrant-stylized-3d"'));
});
