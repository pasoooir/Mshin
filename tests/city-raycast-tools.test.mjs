import test from "node:test";
import assert from "node:assert/strict";
import { createCityRaycastTools } from "../src/city/city-raycast-tools.js";

let nextGroundPoint=null,nextHits=[];
class Vector2{set(x,y){this.x=x;this.y=y;return this;}}
class Vector3{
  constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z;}
  project(){this.x=0.25;this.y=-0.5;return this;}
}
class Raycaster{
  ray={intersectPlane(_plane,target){if(!nextGroundPoint)return null;Object.assign(target,nextGroundPoint);return target;}};
  setFromCamera(pointer,camera){this.pointer={x:pointer.x,y:pointer.y};this.camera=camera;}
  intersectObjects(){return nextHits;}
}
const THREE={Raycaster,Vector2,Vector3};

test("raycast tools convert viewport coordinates to world tiles and screen projection",()=>{
  nextGroundPoint={x:4.2,y:0.14,z:-2.2};nextHits=[];
  const tools=createCityRaycastTools(THREE,{camera:{},buildings:{children:[]},groundPlane:{},getViewport:()=>({width:800,height:400})});
  assert.deepEqual(tools.tileAt(400,200),{x:18,y:14});
  assert.deepEqual(tools.groundPointAt(200,100),{x:4.2,z:-2.2});
  assert.deepEqual(tools.screenForTile(10,12),{x:500,y:300});
});

test("focus raycast prefers the visible building surface and safely falls back to ground",()=>{
  nextGroundPoint={x:1,y:0.14,z:2};
  nextHits=[{point:{x:7,y:4.5,z:-3}}];
  const tools=createCityRaycastTools(THREE,{camera:{},buildings:{children:[{}]},groundPlane:{},getViewport:()=>({width:640,height:360})});
  assert.deepEqual(tools.focusPointAt(320,180),{x:7,y:4.5,z:-3});
  nextHits=[];
  assert.deepEqual(tools.focusPointAt(320,180),{x:1,z:2});
  nextGroundPoint=null;
  assert.deepEqual(tools.tileAt(320,180),{x:-1,y:-1});
  assert.equal(tools.groundPointAt(320,180),null);
});
