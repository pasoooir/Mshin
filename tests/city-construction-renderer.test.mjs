import test from "node:test";
import assert from "node:assert/strict";
import { createCityConstructionRenderer } from "../src/city/city-construction-renderer.js";

function makeThree() {
  class Group {
    constructor(){this.children=[];this.userData={};this.position={set:(x,y,z)=>{this.x=x;this.y=y;this.z=z;}};}
    add(...items){this.children.push(...items);}
  }
  class Geometry { constructor(...args){this.args=args;} }
  class Material { constructor(options={}){this.options=options;this.disposed=false;} dispose(){this.disposed=true;} }
  class Mesh { constructor(geometry,material){this.geometry=geometry;this.material=material;this.position={set(){}};this.rotation={set(){}};this.castShadow=false;this.receiveShadow=false;this.userData={};} }
  class Texture { constructor(canvas){this.canvas=canvas;this.needsUpdate=false;this.disposed=false;} dispose(){this.disposed=true;} }
  class Sprite { constructor(material){this.material=material;this.position={set(){}};this.scale={set(){}};} }
  return {Group,Mesh,BoxGeometry:Geometry,CylinderGeometry:Geometry,SphereGeometry:Geometry,MeshStandardMaterial:Material,CanvasTexture:Texture,SpriteMaterial:Material,Sprite,SRGBColorSpace:"srgb"};
}

test("construction site creates three workers with one pickaxe and two shovels",()=>{
  const previous=document.createElement;
  const drawCalls=[];
  globalThis.document={createElement:()=>({width:0,height:0,getContext:()=>({
    clearRect(){},beginPath(){},roundRect(){},fill(){},stroke(){},fillText(text){drawCalls.push(text)}
  })})};
  try{
    const buildings={children:[]};
    const renderer=createCityConstructionRenderer(makeThree(),buildings);
    const item={id:4,x:17,y:14,type:"home",construction:{duration:45,remaining:45}};
    const site=renderer.createSite(item);
    buildings.children.push(site);
    assert.equal(site.userData.workers.length,3);
    assert.equal(site.userData.workers.filter(worker=>worker.userData.toolType==="pickaxe").length,1);
    assert.equal(site.userData.workers.filter(worker=>worker.userData.toolType==="shovel").length,2);
    renderer.update();
    assert.ok(drawCalls.includes("⏱ 45s"),"countdown badge must show the live remaining time");
    item.construction.remaining=21;
    renderer.update();
    assert.ok(drawCalls.includes("⏱ 21s"),"countdown badge must update when simulation time advances");
    renderer.disposeSite(site);
    assert.equal(site.userData.labelTexture.disposed,true);
  }finally{
    if(previous)globalThis.document={createElement:previous};else delete globalThis.document;
  }
});
