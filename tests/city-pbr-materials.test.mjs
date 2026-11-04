import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const renderer = await readFile(new URL("../src/city/city-three-renderer.js", import.meta.url), "utf8");
const buildingFactory = await readFile(new URL("../src/city/city-building-high-gfx.js", import.meta.url), "utf8");
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

test("active renderer forwards PBR facade and roof surfaces to the high-graphics building factory", () => {
  assert.ok(renderer.includes("...grassSurface"));
  assert.ok(renderer.includes("...asphaltSurface"));
  assert.match(renderer, /createHighGfxBuilding\(THREE,\s*item,\s*\{/);
  for (const surface of ["brickSurface", "concreteSurface", "roofSurface"]) {
    assert.match(renderer, new RegExp("\\b" + surface + ","));
  }
  assert.ok(renderer.includes("sidewalkSurface"));
  assert.ok(streets.includes("...(surface || {})"));
});

test("building factory selects brick or concrete maps and applies PBR maps to both wall orientations and roofs", () => {
  assert.match(buildingFactory, /brickSurface,\s*concreteSurface,\s*roofSurface/);
  assert.match(buildingFactory, /const facadeSurf = \(type === "industrial" \|\| type === "administrative"\) \? \(concreteSurface \|\| \{\}\) : \(brickSurface \|\| \{\}\);/);
  assert.equal((buildingFactory.match(/\.\.\.facadeSurf/g) || []).length, 2,
    "front and side wall materials must both receive the selected facade maps");
  assert.match(buildingFactory, /body\.material = \[wall, sideWall, wall, wall, sideWall, sideWall\]/);
  assert.match(buildingFactory, /\.\.\.\(roofSurface \|\| \{\}\)/);
});

test("residential roof silhouette remains a rectangular two-slope gable", () => {
  assert.ok(buildingFactory.includes("function addGableRoof(w, d, ridgeH, roofMat, trimMat, baseY)"));
  assert.ok(buildingFactory.includes("geo.setIndex([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])"));
  assert.ok(!buildingFactory.includes("new THREE.ConeGeometry(1.08, 0.72, 4)"));
});

test("city keeps the realistic PBR visual identity and neutral tints preserve albedo detail", () => {
  assert.ok(renderer.includes('visualStyle: "realistic-pbr-city"'));
  assert.ok(renderer.includes("pbrMaterialSets: 6"));
  assert.ok(renderer.includes("normalMappedSurfaces: 6"));
  assert.ok(buildingFactory.includes('const facadeTint = type === "industrial" || type === "administrative" ? "#eeeeea" : "#f4eee6"'));
  assert.ok(buildingFactory.includes('const sideFacadeTint = type === "industrial" || type === "administrative" ? "#d9dcd8" : "#ded7cc"'));
  assert.ok(buildingFactory.includes('color: "#e9e7e1"'));
  assert.ok(buildingFactory.includes("roughness: 0.82"));
  assert.ok(buildingFactory.includes("roughness: 0.85"));
});
