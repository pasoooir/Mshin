import test from "node:test";
import assert from "node:assert/strict";
import { createCityStreetLights } from "../src/city/city-street-lighting.js";

class MockObject3D {
  position={set:(x,y,z)=>{this.x=x;this.y=y;this.z=z;}};
  rotation={set:(x,y,z)=>{this.rx=x;this.ry=y;this.rz=z;}};
  scale={set(){}};
  updateMatrix(){this.matrix={x:this.x,y:this.y,z:this.z,rotation:this.ry};}
}
class MockInstancedMesh {
  constructor(geometry,material,capacity){this.geometry=geometry;this.material=material;this.capacity=capacity;this.instances=[];this.instanceMatrix={};}
  setMatrixAt(index,matrix){this.instances[index]=matrix;}
}
class MockBufferGeometry {
  attributes={};
  setAttribute(name,value){this.attributes[name]=value;}
  computeVertexNormals(){this.normalsComputed=true;}
  dispose(){this.disposed=true;}
}
const THREE={
  BufferGeometry:MockBufferGeometry,
  Float32BufferAttribute:class{constructor(array,itemSize){this.array=array;this.itemSize=itemSize;}},
  MeshStandardMaterial:class{constructor(options){this.options=options;}dispose(){this.disposed=true;}},
  InstancedMesh:MockInstancedMesh,Object3D:MockObject3D
};

test("street lights are deterministic, sit beside roads and use one instanced draw call",()=>{
  const scene={children:[],add(mesh){this.children.push(mesh);},remove(mesh){this.children=this.children.filter(item=>item!==mesh);}};
  const materials=new Set();
  const isRoadCell=value=>(value%8===7||value%8===0)&&![0,16,47,63].includes(value);
  const result=createCityStreetLights(THREE,scene,isRoadCell,64,materials);
  assert.ok(result.count>=160,"the road network should receive a useful but sparse lighting layer");
  assert.equal(scene.children.length,1,"all street lamps must be submitted as one instanced mesh");
  assert.equal(result.mesh.count,result.count);
  assert.equal(result.mesh.instances.length,result.count);
  assert.equal(result.mesh.geometry.normalsComputed,true);
  assert.equal(result.mesh.material.options.vertexColors,true);
  assert.equal(materials.has(result.mesh.material),true,"night atmosphere must control the lamp emissive material");
  assert.ok(result.mesh.instances.every(point=>Number.isFinite(point.x)&&Number.isFinite(point.z)));
  assert.ok(result.mesh.instances.every(point=>Math.abs(point.z)>0&&Math.abs(point.x)>0));
  assert.ok(result.mesh.instances.every(point=>{
    const roadX=Math.round(point.x/2+31.5),roadY=Math.round(point.z/2+31.5);
    return point.rotation===0
      ? !isRoadCell(roadX)&&(isRoadCell(roadY-1)||isRoadCell(roadY+1))
      : !isRoadCell(roadY)&&(isRoadCell(roadX-1)||isRoadCell(roadX+1));
  }),"every lamp base must sit on a sidewalk edge beside a road, never in a road intersection");
  result.dispose();
  assert.equal(scene.children.length,0);
  assert.equal(materials.size,0);
  assert.equal(result.mesh.geometry.disposed,true);
});

test("street lighting safely creates no instances when the grid has no roads",()=>{
  const scene={children:[],add(mesh){this.children.push(mesh);},remove(){}};
  const result=createCityStreetLights(THREE,scene,()=>false,64,new Set());
  assert.equal(result.count,0);
  assert.equal(result.mesh.count,0);
  assert.equal(scene.children.length,1);
});
