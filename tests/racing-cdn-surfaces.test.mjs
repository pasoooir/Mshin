import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const renderer=fs.readFileSync(new URL("../src/race-renderer-3d.js",import.meta.url),"utf8");
const pbr=fs.readFileSync(new URL("../src/vehicle-pbr.js",import.meta.url),"utf8");
const credits=fs.readFileSync(new URL("../src/racing/ENVIRONMENT_ASSET_CREDITS.md",import.meta.url),"utf8");

test("race renderer builds every surface from repository-local procedural RGBA8 maps",()=>{
 for(const key of ["asphalt","grass","sand","snow","rock","concrete","bark","foliage"]){
  assert.match(renderer,new RegExp('"'+key+'"'));
 }
 assert.match(renderer,/provider:"Repository-local procedural RGBA8"/);
 assert.match(renderer,/createProceduralSurfacePixels\(key,surfaceSize\)/);
 assert.match(renderer,/state\.surfaceTextures\.proceduralReady\+\+/);
 assert.doesNotMatch(renderer,/dl\.polyhaven\.org|surfaceSources|CDN texture/);
 assert.match(renderer,/texture:surfaceKey\?surfaceTextures\.get\(surfaceKey\)/);
});

test("non-urban roadside house roofs emit valid three-vertex faces",()=>{
 assert.match(renderer,/tri\(roof,\[x-w\/2-7,eave,z-d\/2-7\],\[x\+w\/2\+7,eave,z-d\/2-7\],\[x,peak,z-d\/2-7\]\)/);
 assert.match(renderer,/tri\(roof,\[x\+w\/2\+7,eave,z\+d\/2\+7\],\[x-w\/2-7,eave,z\+d\/2\+7\],\[x,peak,z\+d\/2\+7\]\)/);
});

test("racing surfaces require no network, image loader, or CDN timeout",()=>{
 assert.doesNotMatch(renderer,/new Image\(\)/);
 assert.doesNotMatch(renderer,/https?:\/\//);
 assert.doesNotMatch(renderer,/navigator\.connection\?\.saveData/);
 assert.match(renderer,/new Uint8Array\(\[126,126,126,255\]\)|createProceduralSurfacePixels/);
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

test("race ground plane faces upward, stays inside the far plane, and restores the viewport after shader warmup",()=>{
 assert.match(renderer,/quad\(groundTris,\[-30000,-40,-30000\],\[-30000,-40,30000\],\[30000,-40,30000\],\[30000,-40,-30000\]\)/);
 assert.match(renderer,/perspective\(Math\.PI\/2\.95,canvas\.width\/Math\.max\(1,canvas\.height\),1,60000\)/);
 assert.match(renderer,/gl\.viewport\(0,0,gl\.drawingBufferWidth,gl\.drawingBufferHeight\)/);
});
