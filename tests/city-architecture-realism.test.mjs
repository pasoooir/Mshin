import test from "node:test";
import assert from "node:assert/strict";
import { addRealisticArchitecture } from "../src/city/city-architecture-realism.js";
function createThree(){
 class Geometry{static created=0;constructor(...args){this.args=args;Geometry.created++;}}
 class Mesh{constructor(geometry,material){this.geometry=geometry;this.material=material;this.position={set(){}};}}
 class InstancedMesh extends Mesh{constructor(g,m,count){super(g,m);this.count=count;this.matrices=[];this.instanceMatrix={};}setMatrixAt(i,m){this.matrices[i]={...m};}}
 class Group{constructor(){this.children=[];this.position={set(){}};}add(...items){this.children.push(...items);}clone(){const g=new Group();g.children=[...this.children];return g;}}
 class Object3D{constructor(){this.position={set:(x,y,z)=>{this.p=[x,y,z];}};this.rotation={set:(x,y,z)=>{this.r=[x,y,z];}};this.scale={set(){}};this.matrix={};}updateMatrix(){this.matrix={position:this.p,rotation:this.r};}}
 return {BoxGeometry:Geometry,CylinderGeometry:Geometry,Mesh,InstancedMesh,Group,Object3D};
}
test("facade details are instanced with shared geometry and four-sided placement",()=>{
 const THREE=createThree(),group=new THREE.Group(),material={}; THREE.BoxGeometry.created=0;
 const result=addRealisticArchitecture(THREE,{group,type:"administrative",height:5.2,bodyWidth:1.34,bodyDepth:1.34,glassMat:material,trimMat:material,accentMat:material,roofMat:material});
 assert.equal(result.elevations,4); assert.ok(result.windowCount>=24); assert.ok(result.floorBandCount>=2);
 const batches=group.children.filter(x=>x instanceof THREE.InstancedMesh);
 assert.equal(batches.length,result.facadeBatchCount); assert.ok(batches.length<=4);
 assert.equal(batches.reduce((sum,x)=>sum+x.count,0),result.windowCount+result.frameCount+result.floorBandCount);
 assert.ok(THREE.BoxGeometry.created<=10,"geometry must be reused instead of allocated per floor");
 const front=batches.find(x=>x.geometry.args[2]===0.018);
 assert.ok(front,"front/rear glazing batch must exist");
 const zs=front.matrices.map(x=>x.position[2]); assert.ok(zs.some(z=>z>0)&&zs.some(z=>z<0),"front and rear elevations need windows");
 const side=batches.find(x=>x.geometry.args[0]===0.018&&x.geometry.args[2]===0.29);
 assert.ok(side,"side glazing batch must exist");
 const xs=side.matrices.map(x=>x.position[0]); assert.ok(xs.some(x=>x>0)&&xs.some(x=>x<0),"left and right elevations need windows");
 assert.ok(group.children.some(x=>x instanceof THREE.Group),"rooftop mechanical units must remain present");
});
test("low-rise homes and shops retain rooftop equipment and storefront detail",()=>{
 const THREE=createThree();
 for(const type of ["home","shop"]){
  const group=new THREE.Group();
  const result=addRealisticArchitecture(THREE,{group,type,height:2.8,bodyWidth:1.34,bodyDepth:1.34,glassMat:{},trimMat:{},accentMat:{},roofMat:{}});
  assert.equal(result.elevations,4); assert.ok(result.windowCount>0); assert.ok(group.children.some(x=>x instanceof THREE.Group));
  if(type==="shop") assert.ok(group.children.filter(x=>x instanceof THREE.Mesh).length>=3,"shopfront glazing and canopy must remain");
 }
});
