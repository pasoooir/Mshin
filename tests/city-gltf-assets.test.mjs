import test from "node:test";
import assert from "node:assert/strict";
import { readFile, access } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"..");
const manifest=JSON.parse(await readFile(path.join(root,"assets/city/models/manifest.json"),"utf8"));
test("city GLTF manifest defines three distinct local architectural models",async()=>{
 assert.equal(manifest.schemaVersion,1);assert.equal(manifest.coordinateSystem,"right-handed-y-up");assert.equal(manifest.units,"meters");assert.equal(manifest.assets.length,3);
 assert.deepEqual(manifest.assets.map(x=>x.buildingType),["house","apartment","shop"]);
 for(const asset of manifest.assets){assert.equal(asset.format,"glTF 2.0");assert.equal(asset.license,"CC0-1.0");assert.ok(Array.isArray(asset.scale)&&asset.scale.length===3&&asset.scale.every(v=>v>0));assert.ok(asset.uri.startsWith("./assets/city/models/"));assert.doesNotMatch(asset.uri,/^https?:/i);await access(path.join(root,asset.uri.replace(/^\.\//,"")));}
});
test("each model is self-contained glTF 2.0 with PBR materials and embedded geometry",async()=>{
 for(const asset of manifest.assets){const model=JSON.parse(await readFile(path.join(root,asset.uri.replace(/^\.\//,"")),"utf8"));assert.equal(model.asset.version,"2.0");assert.equal(model.extras.provenance.license,"CC0-1.0");assert.deepEqual(model.extras.dimensions,asset.dimensions);assert.ok(model.materials.length>=4);assert.ok(model.meshes[0].primitives.length>=2);assert.ok(model.buffers[0].uri.startsWith("data:application/octet-stream;base64,"));assert.ok(model.buffers[0].byteLength>0);assert.equal(Buffer.from(model.buffers[0].uri.split(",")[1],"base64").byteLength,model.buffers[0].byteLength);assert.ok(model.bufferViews.every(v=>v.byteOffset+v.byteLength<=model.buffers[0].byteLength));assert.ok(model.accessors.some(a=>a.type==="VEC3"));assert.ok(model.meshes[0].primitives.every(p=>p.attributes.POSITION!==undefined&&p.attributes.NORMAL!==undefined&&p.indices!==undefined));assert.ok(model.materials.every(m=>m.pbrMetallicRoughness?.baseColorFactor?.length===4));assert.ok(!JSON.stringify(model).match(/https?:\/\//i));}
});
test("neighborhood preview loads local architecture models with a procedural fallback",async()=>{
 const html=await readFile(path.join(root,"city-neighborhood-preview.html"),"utf8");assert.match(html,/GLTFLoader/);assert.match(html,/model\.scale\.set/);
 assert.ok(html.includes("./assets/city/models/manifest.json"));
 assert.match(html,/fallback\.group\.removeFromParent\(\)/);assert.match(html,/catch\(error\)/);
});
