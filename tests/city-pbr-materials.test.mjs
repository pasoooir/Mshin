import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const renderer = await readFile(new URL("../src/city/city-three-renderer.js", import.meta.url), "utf8");
const buildingGeometrySource = await readFile(new URL("../src/city/city-building-high-gfx.js", import.meta.url), "utf8");
const buildingGeometry = await readFile(new URL("../src/city/city-building-high-gfx.js", import.meta.url), "utf8");
const textures = await readFile(new URL("../src/city/city-pbr-textures.js", import.meta.url), "utf8");
const streets = await readFile(new URL("../src/city/city-street-renderer.js", import.meta.url), "utf8");
const cityView = await readFile(new URL("../src/city/city-view.js", import.meta.url), "utf8");

test("city surfaces use layered tileable albedo, normal and roughness maps", () => {
  assert.ok(textures.includes("function makePbrSurface(THREE, renderer, kind, base, seed)"));
  assert.ok(textures.includes("const size = compactDevice ? 256 : 512"), "mobile PBR maps must use a lower-cost resolution");
  assert.ok(textures.includes("compactDevice ? 4 : 8"), "mobile texture anisotropy must be capped");
  assert.ok(textures.includes("const detailScale = compactDevice ? 0.65 : 1"), "mobile procedural texture detail must use a bounded generation budget");
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
  assert.ok(renderer.includes("const grassGroundMap = naturalGrassTexture"), "the continuous meadow must use the PBR grass albedo map");
  assert.ok(renderer.includes("const grassGroundNormal = grassSurface.normalMap.clone()"), "the continuous meadow must use the PBR grass normal map");
  assert.ok(renderer.includes("...asphaltSurface"));
  assert.ok(buildingGeometrySource.includes("const facadeSurf = (type === \"industrial\" || type === \"administrative\")"));
  assert.ok(buildingGeometrySource.includes("...facadeSurf"));
  assert.ok(buildingGeometrySource.includes("facadeSurf.normalMap ? new THREE.Vector2"));

  assert.ok(buildingGeometrySource.includes("...(roofSurface || {})"));
  assert.ok(buildingGeometrySource.includes('type === "industrial" || type === "administrative"'));
  assert.ok(renderer.includes("sidewalkSurface"));
  assert.ok(streets.includes("...(surface || {})"));
});

test("residential roof silhouette is a rectangular two-slope gable, not a pyramid primitive", () => {
  assert.ok(buildingGeometry.includes("function addGableRoof(w, d, ridgeH, roofMat, trimMat, baseY)"), "gable roof must be built by the dedicated building-geometry module");
  assert.ok(buildingGeometry.includes("geo.setIndex([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])"), "gable roof must use two rectangular slopes with explicit triangular faces");
  assert.ok(!buildingGeometry.includes("new THREE.ConeGeometry(1.08, 0.72, 4)"), "residential gable must not regress to a pyramid primitive");
});

test("building updates preserve unchanged groups and rebuild only changed ids", () => {
  assert.ok(renderer.includes("const buildingObjects = new Map()"));
  assert.ok(renderer.includes("const desired = new Map(city.buildings.map"));
  assert.ok(renderer.includes("JSON.stringify([...desired].sort(([a], [b]) => a.localeCompare(b))"), "building signatures must not rebuild on array ordering alone");
  assert.ok(renderer.includes("if (wanted && wanted.signature === current.signature) continue"));
  assert.ok(renderer.includes("if (buildingObjects.has(key)) continue"));
  assert.ok(renderer.includes("buildings.remove(current.group)"));
});

test("building rebuild releases shared GPU resources once", () => {
  assert.ok(renderer.includes("const obsoleteGeometries = new Set()"));
  assert.ok(renderer.includes("const obsoleteMaterials = new Set()"));
  assert.ok(renderer.includes("for (const geometry of obsoleteGeometries) geometry.dispose()"));
  assert.ok(renderer.includes("for (const material of obsoleteMaterials)"));
  assert.ok(renderer.includes("material.dispose()"));
});

test("city visual identity uses a muted architectural palette and reports PBR acceptance metrics", () => {
  assert.ok(renderer.includes('visualStyle: "full-spectrum-natural-coastal-world"'));
  assert.ok(renderer.includes("pbrMaterialSets: 6"));
  assert.ok(renderer.includes("normalMappedSurfaces: 6"));
  assert.ok(renderer.includes("pbrGenerationMs"), "renderer must expose measured PBR generation time");
  assert.ok(renderer.includes("pbrTextureResolution"), "renderer must expose selected texture resolution");
  for (const metric of ["drawCalls", "renderedTriangles", "renderedPoints", "renderedLines", "geometryCount", "textureCount"]) {
    assert.ok(renderer.includes(metric), "renderer must expose " + metric + " for performance diagnostics");
  }
  assert.ok(renderer.includes("buildingMeshCountsByType"), "renderer must break building mesh counts down by type");
  for (const metric of ["buildingMeshCount", "buildingInstancedMeshCount", "buildingUniqueGeometryCount", "buildingUniqueMaterialCount"]) {
    assert.ok(renderer.includes(metric), "renderer must expose building complexity metric " + metric);
  }
  assert.ok(!renderer.includes('visualStyle: "vibrant-stylized-3d"'));
});

test("new city opens on one continuous textured meadow with no visible checkerboard plot grid", () => {
  assert.ok(renderer.includes("new THREE.PlaneGeometry(1000000, 1000000)"), "grass terrain must cover the widest supported camera view without exposing the page backdrop");
  assert.ok(renderer.includes("texture === grassGroundMap ? 16000 : 2048"), "grass PBR maps must retain natural blade scale across the large meadow");
  assert.ok(renderer.includes("continuousGrassland: true"));
  assert.ok(renderer.includes("visiblePlotGridLines: 0"));
  assert.ok(!renderer.includes("new THREE.BoxGeometry(CITY_TILE_METERS - 0.06"), "terrain must not be assembled from individual square grass tiles");
  assert.ok(!renderer.includes("addLineLayer(activePlotEdges"), "active parcel borders must not be visible on the meadow");
  assert.ok(!renderer.includes("addLineLayer(lockedPlotEdges"), "locked parcel borders must not be visible on the meadow");
  assert.ok(!renderer.includes("const lotLines = []"), "no repeated lot lines may create a checkerboard appearance");
  assert.ok(renderer.includes("const decorativeTreeCount = 0"), "the initial meadow must contain only grass before player construction");
  assert.ok(textures.includes("const bladeTones = ["), "grass must contain layered natural blade variation");
  assert.ok(textures.includes("9200 * detailScale"), "grass texture must include dense fine blade detail");
});

test("WebGL fallback also starts on a continuous grass meadow, not diamond cells", () => {
  assert.ok(cityView.includes("const meadowPattern=ctx.createPattern(meadowCanvas,\"repeat\")"));
  assert.ok(cityView.includes("ctx.fillStyle=meadowPattern;ctx.fillRect(0,0,view.w,view.h)"));
  assert.ok(cityView.includes('if(city.grid[y][x]==="road")ground(x,y,"road")'));
  assert.ok(!cityView.includes("for(let y=0;y<SIZE;y++)for(let x=0;x<SIZE;x++)ground(x,y,city.grid[y][x])"));
});
