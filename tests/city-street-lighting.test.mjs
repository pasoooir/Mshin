import test from "node:test";
import assert from "node:assert/strict";
import { createCityStreetLighting } from "../src/city/city-street-lighting.js";

class MockObject3D {
  position={set:(x,y,z)=>{this.p=[x,y,z];}};
  rotation={set:(x,y,z)=>{this.r=[x,y,z];}};
  scale={set(){}};
  updateMatrix(){this.matrix={position:this.p,rotation:this.r};}
}
class MockInstancedMesh {
  constructor(geometry,material,capacity){this.geometry=geometry;this.material=material;this.capacity=capacity;this.instances=[];this.instanceMatrix={};}
  setMatrixAt(index,matrix){this.instances[index]=matrix;}
}
const THREE={
  MeshStandardMaterial:class{constructor(options){this.options=options;}},
  CylinderGeometry:class{constructor(...dimensions){this.dimensions=dimensions;}},
  BoxGeometry:class{constructor(...dimensions){this.dimensions=dimensions;}},
  InstancedMesh:MockInstancedMesh,
  Object3D:MockObject3D
};
const roadAxis=value=>(value%8===7||value%8===0)&&![0,16,47,63].includes(value);

test("street lights are instanced on sidewalk ROW with a fixed two-draw-call budget",()=>{
  const scene={children:[],add(mesh){this.children.push(mesh);}};
  const result=createCityStreetLighting(THREE,scene,roadAxis,64);
  assert.ok(result.count>0,"the road network should receive street lights");
  assert.equal(result.drawCalls,2);
  assert.equal(scene.children.length,2);
  assert.equal(result.poles.count,result.count);
  assert.equal(result.lamps.count,result.count);
  assert.ok(result.poles.instances.every(item=>Number.isFinite(item.position[0])&&Number.isFinite(item.position[1])&&Number.isFinite(item.position[2])));
  assert.ok(result.poles.instances.every(item=>item.position[1]===0.94));
  assert.ok(result.lamps.instances.every(item=>item.position[1]===1.78));
});

test("street lighting safely emits no instances when the road graph is empty",()=>{
  const scene={children:[],add(mesh){this.children.push(mesh);}};
  const result=createCityStreetLighting(THREE,scene,()=>false,64);
  assert.equal(result.count,0);
  assert.equal(result.drawCalls,0);
  assert.equal(scene.children.length,2);
});
