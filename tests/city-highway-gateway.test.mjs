import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import * as THREE from "../vendor/three/build/three.module.min.js";
import { createCityHighwayGateway } from "../src/city/city-highway-gateway.js";

test("3D city world includes a divided regional highway and bidirectional gateway ramps", () => {
  const previousDocument = globalThis.document;
  globalThis.document = {
    createElement(name) {
      assert.equal(name, "canvas");
      return {
        width: 512,
        height: 128,
        getContext() {
          return {
            fillStyle: "",
            strokeStyle: "",
            lineWidth: 0,
            textAlign: "",
            textBaseline: "",
            font: "",
            fillRect() {},
            strokeRect() {},
            fillText() {}
          };
        }
      };
    }
  };
  const surface = () => ({
    map: new THREE.Texture(),
    normalMap: new THREE.Texture(),
    roughnessMap: new THREE.Texture()
  });
  const gateway = createCityHighwayGateway(THREE, {
    asphaltSurface: surface(),
    concreteSurface: surface()
  });
  const stats = gateway.getStats();
  assert.equal(stats.highwayCarriageways, 2);
  assert.equal(stats.highwayLanes, 6);
  assert.equal(stats.highwayRamps, 2);
  assert.equal(stats.cityGatewayRoads, 1);
  assert.ok(gateway.group.children.some(item => item.name === "highway-north-carriageway"));
  assert.ok(gateway.group.children.some(item => item.name === "highway-south-carriageway"));
  assert.ok(gateway.group.children.some(item => item.name === "highway-city-exit-ramp"));
  assert.ok(gateway.group.children.some(item => item.name === "city-highway-entry-ramp"));
  assert.ok(gateway.group.children.some(item => item.isInstancedMesh), "lane markings and guardrail posts should be instanced");
  assert.ok(gateway.group.children.length < 100, "highway meshes must stay bounded for mobile rendering");
  gateway.dispose();
  globalThis.document = previousDocument;
});

test("city renderer mounts the highway gateway and reports its diagnostics", async () => {
  const source = await readFile(new URL("../src/city/city-three-renderer.js", import.meta.url), "utf8");
  assert.match(source, /createCityHighwayGateway/);
  assert.match(source, /scene\.add\(highwayGateway\.group\)/);
  assert.match(source, /\.\.\.highwayGateway\.getStats\(\)/);
  assert.match(source, /highwayGateway\.dispose\(\)/);
});
