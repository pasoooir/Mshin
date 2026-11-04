import test from "node:test";
import assert from "node:assert/strict";
import { addRealisticArchitecture } from "../src/city/city-architecture-realism.js";
function createThree(){
 class Geometry{constructor(...args){this.args=args;}}
 class Mesh{constructor(geometry,material){this.geometry=geometry;this.material=material;this.position={set(){}};}}
 class InstancedMesh extends Mesh{constructor(g,m,count){super(g,m);this.count=count;this.instanceMatrix={};}setMatrixAt(){}}
 class Group{constructor(){this.children=[];this.position={set(){}};}add(...items){this.children.push(...items);}clone(){const g=new Group();g.children=[...this.children];return g;}}
 class Object3D{constructor(){this.position={set(){}};this.rotation={set(){}};this.scale={set(){}};this.matrix={};}updateMatrix(){}}
 return {BoxGeometry:Geometry,CylinderGeometry:Geometry,Mesh,InstancedMesh,Group,Object3D};
}
test("facade details are instanced within a strict draw-call budget",()=>{
 const THREE=createThree(),group=new THREE.Group(),material={};
 const result=addRealisticArchitecture(THREE,{group,type:"administrative",height:5.2,bodyWidth:1.34,bodyDepth:1.34,glassMat:material,trimMat:material,accentMat:material,roofMat:material});
 assert.equal(result.elevations,4); assert.ok(result.windowCount>=24); assert.ok(result.floorBandCount>=2);
 const batches=group.children.filter(x=>x instanceof THREE.InstancedMesh);
 assert.equal(batches.length,result.facadeBatchCount); assert.ok(batches.length<=4);
 assert.equal(batches.reduce((sum,x)=>sum+x.count,0),result.windowCount+result.frameCount+result.floorBandCount);
 assert.ok(group.children.some(x=>x instanceof THREE.Group));
});
test("low-rise homes and shops retain rooftop equipment",()=>{
 const THREE=createThree();
 for(const type of ["home","shop"]){
  const group=new THREE.Group();
  const result=addRealisticArchitecture(THREE,{group,type,height:2.8,bodyWidth:1.34,bodyDepth:1.34,glassMat:{},trimMat:{},accentMat:{},roofMat:{}});
  assert.equal(result.elevations,4);assert.ok(result.windowCount>0);assert.ok(group.children.some(x=>x instanceof THREE.Group));
 }
});
