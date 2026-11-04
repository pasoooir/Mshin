import test from "node:test";
import assert from "node:assert/strict";
import { createCitySidewalkLayer } from "../src/city/city-street-renderer.js";

class MockObject3D {
  position={set:(x,y,z)=>{this.x=x;this.y=y;this.z=z;}};
  rotation={set(){}};
  scale={set(){}};
  updateMatrix(){this.matrix={x:this.x,y:this.y,z:this.z};}
}
class MockInstancedMesh {
  constructor(geometry,material,capacity){this.geometry=geometry;this.material=material;this.capacity=capacity;this.instances=[];this.instanceMatrix={};}
  setMatrixAt(index,matrix){this.instances[index]=matrix;}
}
const THREE={
  MeshStandardMaterial:class{constructor(options){this.options=options;}},
  BoxGeometry:class{constructor(...dimensions){this.dimensions=dimensions;}},
  InstancedMesh:MockInstancedMesh,
  Object3D:MockObject3D
};

test("sidewalk renderer creates one instanced layer along road edges only",()=>{
  const scene={children:[],add(mesh){this.children.push(mesh);}};
  const isRoadCell=value=>value===3;
  const result=createCitySidewalkLayer(THREE,scene,isRoadCell,8);
  assert.equal(result.count,28,"a cross-shaped road grid should create only its 28 exposed pedestrian edge strips");
  assert.equal(scene.children.length,1,"all sidewalk segments must share one instanced draw call");
  assert.equal(result.mesh.count,28);
  assert.equal(result.mesh.instances.length,28);
  assert.equal(result.mesh.receiveShadow,true);
  assert.deepEqual(result.mesh.geometry.dimensions,[1,0.10,1]);
  assert.equal(result.mesh.material.options.roughness,0.94);
  assert.ok(result.mesh.instances.every(point=>Number.isFinite(point.x)&&Number.isFinite(point.y)&&Number.isFinite(point.z)));
});

test("sidewalk renderer remains empty and safe when no roads exist",()=>{
  const scene={children:[],add(mesh){this.children.push(mesh);}};
  const result=createCitySidewalkLayer(THREE,scene,()=>false,8);
  assert.equal(result.count,0);
  assert.equal(result.mesh.count,0);
  assert.equal(scene.children.length,1);
});
