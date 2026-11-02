import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const renderer=fs.readFileSync(new URL("../src/race-renderer-3d.js",import.meta.url),"utf8");
const pbr=fs.readFileSync(new URL("../src/vehicle-pbr.js",import.meta.url),"utf8");
const credits=fs.readFileSync(new URL("../src/racing/ENVIRONMENT_ASSET_CREDITS.md",import.meta.url),"utf8");

test("race renderer uses real Poly Haven CDN surfaces for asphalt and biome terrain",()=>{
 for(const key of ["asphalt","grass","sand","snow","rock","concrete","bark","foliage"]){
  assert.match(renderer,new RegExp(key+':"https://dl\\.polyhaven\\.org/file/ph-assets/Textures/jpg/1k/'));
 }
 assert.match(renderer,/crossOrigin="anonymous"/);
 assert.match(renderer,/image\.onerror/);
 assert.match(renderer,/surfaceTextures\.loaded\+\+/);
 assert.match(renderer,/texture:surfaceKey\?surfaceTextures\.get\(surfaceKey\)/);
});

test("world-space PBR shader samples scanned textures without requiring UV vertex buffers",()=>{
 assert.match(pbr,/uniform sampler2D uSurfaceTexture/);
 assert.match(pbr,/uniform float uSurfaceEnabled/);
 assert.match(pbr,/texture2D\(uSurfaceTexture,uv\)/);
 assert.match(renderer,/gl\.uniform1f\(uniforms\.surfaceEnabled,p\.texture\?1:0\)/);
});

test("terrain, road and building meshes receive distinct texture families",()=>{
 assert.match(renderer,/part\(roadTris,theme\[1\],0,"environment","asphalt"\)/);
 assert.match(renderer,/part\(groundTris,theme\[0\],0,"environment",terrainTexture\)/);
 assert.match(renderer,/\[landscape,"#778b78",0,terrainTexture\]/);
 assert.match(renderer,/\[buildings,urban\?"#5c4d85":"#747b82",0,"concrete"\]/);assert.match(renderer,/\[treeTrunks,"#70533b",0,"bark"\]/);assert.match(renderer,/\[treeFoliage,theme\[3\],0,"foliage"\]/);
 assert.match(credits,/CC0 1\.0/);
 assert.match(credits,/Poly Haven/);
});
