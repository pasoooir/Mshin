import test from "node:test";
import assert from "node:assert/strict";
import { addRealisticArchitecture } from "../src/city/city-architecture-realism.js";

test("realistic architecture articulates all four elevations and roof plant", () => {
  const created = [];
  class Geometry { constructor(...args){this.args=args;} }
  class Mesh { constructor(geometry, material){this.geometry=geometry;this.material=material;this.position={set:(...v)=>{this.xyz=v;}};this.castShadow=false;this.receiveShadow=false;} }
  class Group { constructor(){this.children=[];this.position={set(){}};} add(...items){this.children.push(...items);} clone(){const copy=new Group();copy.children=[...this.children];return copy;} }
  const THREE={BoxGeometry:Geometry,CylinderGeometry:Geometry,Mesh,Group};
  const group=new Group();
  const material={};
  const result=addRealisticArchitecture(THREE,{group,type:"administrative",height:5.2,bodyWidth:1.34,bodyDepth:1.34,glassMat:material,trimMat:material,accentMat:material,roofMat:material});
  assert.equal(result.elevations,4);
  assert.ok(result.windowCount>=24);
  assert.ok(result.floorBandCount>=2);
  assert.ok(group.children.length>=result.windowCount);
  assert.ok(group.children.some(item=>item instanceof Group),"roof mechanical units must be grouped separately");
});

test("low-rise residential and commercial forms keep roof equipment", () => {
  const created=[];
  class Geometry { constructor(...args){this.args=args;} }
  class Mesh { constructor(geometry,material){this.position={set(){}};this.geometry=geometry;this.material=material;} }
  class Group { constructor(){this.children=[];this.position={set(){}};} add(...items){this.children.push(...items);} clone(){const g=new Group();g.children=[...this.children];return g;} }
  const THREE={BoxGeometry:Geometry,CylinderGeometry:Geometry,Mesh,Group};
  for (const type of ["home","shop"]) {
    const group=new Group();
    const result=addRealisticArchitecture(THREE,{group,type,height:2.8,bodyWidth:1.34,bodyDepth:1.34,glassMat:{},trimMat:{},accentMat:{},roofMat:{}});
    assert.equal(result.elevations,4);
    assert.ok(result.windowCount>0);
    assert.ok(group.children.some(item=>item instanceof Group));
  }
});
