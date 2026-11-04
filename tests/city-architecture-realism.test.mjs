import test from "node:test";
import assert from "node:assert/strict";
import { addRealisticArchitecture } from "../src/city/city-architecture-realism.js";

function createThreeDouble() {
  class Geometry { constructor(...args){this.args=args;} }
  class Mesh { constructor(geometry,material){this.geometry=geometry;this.material=material;this.position={set(){}};} }
  class Group { constructor(){this.children=[];this.position={set(){}};} add(...items){this.children.push(...items);} clone(){const g=new Group();g.children=[...this.children];return g;} }
  class Object3D { constructor(){this.position={set:(x,y,z)=>{this.xyz=[x,y,z];}};this.matrix={};} updateMatrix(){this.matrix={position:this.xyz};} }
  class InstancedMesh { constructor(geometry,material,count){this.geometry=geometry;this.material=material;this.count=count;this.matrices=[];this.instanceMatrix={};} setMatrixAt(i,m){this.matrices[i]=m;} }
  return {BoxGeometry:Geometry,CylinderGeometry:Geometry,Mesh,Group,Object3D,InstancedMesh};
}

test("realistic architecture batches four elevations into instanced facade draws", () => {
  const THREE=createThreeDouble(), group=new THREE.Group(), material={};
  const result=addRealisticArchitecture(THREE,{group,type:"administrative",height:5.2,bodyWidth:1.34,bodyDepth:1.34,glassMat:material,trimMat:material,accentMat:material,roofMat:material});
  assert.equal(result.elevations,4);
  assert.ok(result.windowCount>=24);
  assert.ok(result.drawCallBatches<=8,"facade details must use a small bounded set of draw calls");
  const batches=group.children.filter(item=>item instanceof THREE.InstancedMesh);
  assert.equal(batches.length,result.drawCallBatches);
  assert.equal(batches.reduce((sum,item)=>sum+item.count,0),result.windowCount);
  assert.ok(group.children.some(item=>item instanceof THREE.Group),"roof mechanical units remain visible");
});

test("low-rise residential and commercial forms retain roof equipment and instanced windows", () => {
  const THREE=createThreeDouble();
  for (const type of ["home","shop"]) {
    const group=new THREE.Group();
    const result=addRealisticArchitecture(THREE,{group,type,height:2.8,bodyWidth:1.34,bodyDepth:1.34,glassMat:{},trimMat:{},accentMat:{},roofMat:{}});
    assert.equal(result.elevations,4);
    assert.ok(result.windowCount>0);
    assert.ok(group.children.some(item=>item instanceof THREE.Group));
    assert.ok(group.children.some(item=>item instanceof THREE.InstancedMesh));
  }
});
