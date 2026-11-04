import test from "node:test";
import assert from "node:assert/strict";
import { createHighGfxBuilding } from "../src/city/city-building-high-gfx.js";

class Vector2 {
  constructor(x, y) { this.x = x; this.y = y; }
}
class Vector3 {
  set(x, y, z) { this.x = x; this.y = y; this.z = z; }
}
class Group {
  constructor() {
    this.children = [];
    this.position = new Vector3();
    this.rotation = new Vector3();
    this.scale = new Vector3();
    this.userData = {};
  }
  add(...objects) { this.children.push(...objects); }
}
class Geometry {
  constructor(...args) { this.args = args; this.attributes = {}; }
  setAttribute(name, value) { this.attributes[name] = value; }
  setIndex(value) { this.index = value; }
  computeVertexNormals() {}
}
class Material {
  constructor(options = {}) { Object.assign(this, options); }
}
class Mesh {
  constructor(geometry, material) {
    this.geometry = geometry;
    this.material = material;
    this.position = new Vector3();
    this.rotation = new Vector3();
    this.scale = new Vector3();
    this.castShadow = false;
    this.receiveShadow = false;
  }
}
class InstancedMesh extends Mesh {
  constructor(geometry, material, capacity) {
    super(geometry, material);
    this.capacity = capacity;
    this.count = capacity;
    this.instanceMatrix = { needsUpdate: false };
    this.matrices = [];
  }
  setMatrixAt(index, matrix) { this.matrices[index] = matrix; }
}
class Object3D {
  constructor() {
    this.position = new Vector3();
    this.rotation = new Vector3();
    this.scale = new Vector3();
    this.matrix = {};
  }
  updateMatrix() { this.matrix = { position: this.position, rotation: this.rotation, scale: this.scale }; }
}
const THREE = {
  Group,
  Vector2,
  Object3D,
  Mesh,
  InstancedMesh,
  MeshStandardMaterial: Material,
  BoxGeometry: Geometry,
  BufferGeometry: Geometry,
  Float32BufferAttribute: Geometry,
  CylinderGeometry: Geometry,
  SphereGeometry: Geometry,
  TorusGeometry: Geometry
};

function makeSurface(label) {
  return {
    map: { label: label + "-albedo" },
    normalMap: { label: label + "-normal" },
    roughnessMap: { label: label + "-roughness" }
  };
}

function build(type, id = 17) {
  const brickSurface = makeSurface("brick");
  const concreteSurface = makeSurface("concrete");
  const roofSurface = makeSurface("roof");
  const windowMaterials = new Set();
  const group = createHighGfxBuilding(THREE, { id, type, x: 15, y: 15, level: 3 }, {
    brickSurface,
    concreteSurface,
    roofSurface,
    windowMaterials
  });
  const body = group.children.find(child => Array.isArray(child.material));
  assert.ok(body, "building body must expose per-face wall materials");
  return { group, body, brickSurface, concreteSurface, roofSurface, windowMaterials };
}

function findRoofMaterial(group, roofSurface) {
  return group.children
    .filter(child => child instanceof Mesh)
    .map(child => child.material)
    .flat()
    .find(material => material?.map === roofSurface.map);
}

test("residential building applies brick albedo, normal and roughness maps to front and side walls", () => {
  const result = build("home");
  const [front, side] = result.body.material;
  for (const material of [front, side]) {
    assert.equal(material.map, result.brickSurface.map);
    assert.equal(material.normalMap, result.brickSurface.normalMap);
    assert.equal(material.roughnessMap, result.brickSurface.roughnessMap);
    assert.ok(material.color === "#f4eee6" || material.color === "#ded7cc");
  }
  assert.ok(findRoofMaterial(result.group, result.roofSurface), "residential roof must consume roof PBR maps");
});

test("industrial building applies concrete PBR maps instead of brick maps", () => {
  const result = build("industrial");
  const [front, side] = result.body.material;
  for (const material of [front, side]) {
    assert.equal(material.map, result.concreteSurface.map);
    assert.equal(material.normalMap, result.concreteSurface.normalMap);
    assert.equal(material.roughnessMap, result.concreteSurface.roughnessMap);
    assert.notEqual(material.map, result.brickSurface.map);
  }
  assert.ok(findRoofMaterial(result.group, result.roofSurface), "industrial roof must consume roof PBR maps");
});

test("administrative building uses concrete PBR maps and keeps facade tint neutral", () => {
  const result = build("administrative");
  const [front, side] = result.body.material;
  assert.equal(front.map, result.concreteSurface.map);
  assert.equal(side.map, result.concreteSurface.map);
  assert.equal(front.color, "#eeeeea");
  assert.equal(side.color, "#d9dcd8");
});

test("PBR material maps retain independent channels and are registered without aliasing facade families", () => {
  const result = build("home");
  const roof = findRoofMaterial(result.group, result.roofSurface);
  assert.ok(roof);
  assert.notEqual(roof.map, result.brickSurface.map);
  assert.notEqual(roof.normalMap, result.brickSurface.normalMap);
  assert.notEqual(roof.roughnessMap, result.brickSurface.roughnessMap);
  assert.ok(result.windowMaterials.size > 0, "window materials remain registered for renderer cleanup");
});
