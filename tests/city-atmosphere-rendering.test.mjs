import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const atmosphere = await readFile(new URL("../src/city/city-atmosphere.js", import.meta.url), "utf8");
const buildings = await readFile(new URL("../src/city/city-building-high-gfx.js", import.meta.url), "utf8");
const renderer = await readFile(new URL("../src/city/city-three-renderer.js", import.meta.url), "utf8");

test("city renders a real atmospheric sky dome with zenith-to-horizon gradient and solar scattering", () => {
  assert.ok(atmosphere.includes('new THREE.SphereGeometry(900, 32, 20)'));
  assert.ok(atmosphere.includes('new THREE.ShaderMaterial'));
  assert.ok(atmosphere.includes('smoothstep(-0.10,0.20,vertical)'));
  assert.ok(atmosphere.includes('smoothstep(0.20,0.78,vertical)'), "upper sky gradient must blend continuously into the zenith");
  assert.ok(atmosphere.includes('pow(sunAngle, 13.0)'));
  assert.ok(atmosphere.includes('camera.getWorldPosition(skyDome.position)'));
  assert.ok(atmosphere.includes('skyMaterial.uniforms.uSunDirection.value.copy(sunDirection)'));
  assert.ok(atmosphere.includes('#include <colorspace_fragment>'));
});

test("atmospheric colour is continuously evaluated from minute, season and weather", () => {
  assert.ok(atmosphere.includes('getCityAtmosphericColors(minute, seasonal.season, seasonal.weather)'));
  assert.ok(atmosphere.includes('horizonColor: atmosphereColours.horizon'));
  assert.ok(atmosphere.includes('colorDepth: "24-bit RGB"'));
  assert.ok(!atmosphere.includes('SEASON_SKIES'));
});

test("building surfaces use deterministic natural material variation rather than neon swatches", () => {
  assert.ok(buildings.includes('function naturalColour(hex, hueRange = 0.012'));
  assert.ok(buildings.includes('value.offsetHSL('));
  assert.ok(buildings.includes('const wallColour = naturalColour(palette.wall'));
  assert.ok(buildings.includes('const roofColour = naturalColour(palette.roof'));
  for (const neon of ["#39ed43", "#16e84a", "#42f52b", "#00e8a8", "#ff2f9b", "#13dfff", "#a8f8ff", "#18cfff"]) {
    assert.ok(!buildings.toLowerCase().includes(neon), "remove artificial neon colour " + neon);
  }
});

test("renderer keeps sRGB output and high-dynamic-range tone mapping enabled", () => {
  assert.ok(renderer.includes('renderer.outputColorSpace = THREE.SRGBColorSpace'));
  assert.ok(renderer.includes('renderer.toneMapping = THREE.ACESFilmicToneMapping'));
  assert.ok(renderer.includes('renderer.toneMappingExposure'));
});
