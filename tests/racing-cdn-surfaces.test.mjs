import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const renderer=fs.readFileSync(new URL("../src/race-renderer-3d.js",import.meta.url),"utf8");
const pbr=fs.readFileSync(new URL("../src/vehicle-pbr.js",import.meta.url),"utf8");
const credits=fs.readFileSync(new URL("../src/racing/ENVIRONMENT_ASSET_CREDITS.md",import.meta.url),"utf8");

test("race renderer creates all eight RGBA8 surfaces locally without any network requests",()=>{
 for(const key of ["asphalt","grass","sand","snow","rock","concrete","bark","foliage"]) assert.ok(renderer.includes('"'+key+'"'));
 assert.match(renderer,/provider:"Repository-local procedural RGBA8"/);
 assert.match(renderer,/createProceduralSurfacePixels\(key,surfaceSize\)/);
 assert.match(renderer,/const surfaceSize=256/);
 assert.match(renderer,/state\.surfaceTextures\.proceduralReady\+\+/);
 assert.doesNotMatch(renderer,/https?:\/\/|new Image\(\)|surfaceSources|CDN texture|Poly Haven/);
 assert.match(renderer,/texture:surfaceKey\?surfaceTextures\.get\(surfaceKey\)/);
});

test("non-urban roadside house roofs emit valid three-vertex faces",()=>{
 assert.match(renderer,/tri\(roof,\[x-w\/2-7,eave,z-d\/2-7\],\[x\+w\/2\+7,eave,z-d\/2-7\],\[x,peak,z-d\/2-7\]\)/);
 assert.match(renderer,/tri\(roof,\[x\+w\/2\+7,eave,z\+d\/2\+7\],\[x-w\/2-7,eave,z\+d\/2\+7\],\[x,peak,z\+d\/2\+7\]\)/);
});

test("context restoration rebuilds local textures and destroy releases GPU resources",()=>{
 assert.match(renderer,/for\(const key of surfaceKeys\)loadSurfaceTexture\(key\)/);
 assert.match(renderer,/gl\.deleteTexture\(texture\)/);
 assert.doesNotMatch(renderer,/surfaceImages|surfaceLoadGeneration|rendererDestroyed/);
});

test("race ground plane faces upward and remains inside the camera far plane",()=>{
 assert.match(renderer,/quad\(groundTris,\[-30000,-40,-30000\],\[-30000,-40,30000\],\[30000,-40,30000\],\[30000,-40,-30000\]\)/);
 assert.match(renderer,/perspective\(Math\.PI\/2\.95,canvas\.width\/Math\.max\(1,canvas\.height\),1,60000\)/);
});

test("race circuit uses professional centre lines, edge lines and alternating red-white kerbs",()=>{
 assert.match(renderer,/yellowTris=\[\],curbRedTris=\[\],curbWhiteTris=\[\]/);
 assert.match(renderer,/for\(const offset of \[-158,158\]\)/);
 assert.match(renderer,/if\(i%2===0\)for\(const offset of \[-5,5\]\)/);
 assert.match(renderer,/Math\.floor\(i\/4\)%2\?curbWhiteTris:curbRedTris/);
 assert.match(renderer,/part\(yellowTris,"#f5c928"/);
 assert.match(renderer,/part\(curbRedTris,"#d94337"\)/);
 assert.match(renderer,/part\(curbWhiteTris,"#f1eee4"\)/);
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
 assert.match(credits,/original procedural algorithms/);
 assert.match(credits,/Project original work/);
 assert.ok(credits.includes("Three.js 0.180.0"));
});
