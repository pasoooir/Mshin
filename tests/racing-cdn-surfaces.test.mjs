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

test("non-urban roadside house roofs emit valid three-vertex faces",()=>{
 assert.match(renderer,/tri\(roof,\[x-w\/2-7,eave,z-d\/2-7\],\[x\+w\/2\+7,eave,z-d\/2-7\],\[x,peak,z-d\/2-7\]\)/);
 assert.match(renderer,/tri\(roof,\[x\+w\/2\+7,eave,z\+d\/2\+7\],\[x-w\/2-7,eave,z\+d\/2\+7\],\[x,peak,z\+d\/2\+7\]\)/);
});

test("optional CDN textures have bounded mobile loading and preserve fallback rendering",()=>{
 assert.match(renderer,/6500/);
 assert.match(renderer,/CDN texture timed out/);
 assert.match(renderer,/createProceduralSurfacePixels\(key,fallbackSize\)/);
 assert.match(renderer,/const fallbackSize=128/);
 assert.match(renderer,/palettes=\{asphalt:\[74,78,80\],grass:\[91,137,57\]/);
 assert.match(renderer,/gl\.generateMipmap\(gl\.TEXTURE_2D\)/);
 assert.match(renderer,/navigator\.connection\?\.saveData/);
 assert.match(renderer,/softwareRenderer\|\|navigator\.connection/);
 assert.match(renderer,/rendererDestroyed\|\|lost\|\|generation!==surfaceLoadGeneration/);
 assert.match(renderer,/surfaceImages\.clear\(\)/);
 assert.match(renderer,/gl\.deleteTexture\(texture\)/);
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
 assert.match(renderer,/part\(curbRedTris,"#d94337",\.72\)/);
 assert.match(renderer,/part\(curbWhiteTris,"#f1eee4",\.78\)/);
});

test("world-space PBR shader samples scanned textures without requiring UV vertex buffers",()=>{
 assert.match(pbr,/uniform sampler2D uSurfaceTexture/);
 assert.match(pbr,/uniform float uSurfaceEnabled/);
 assert.match(pbr,/texture2D\(uSurfaceTexture,uv\)/);
 assert.match(renderer,/gl\.uniform1f\(uniforms\.surfaceEnabled,p\.texture\?1:0\)/);
});

test("terrain, road and building meshes receive distinct texture families",()=>{
 assert.match(renderer,/part\(roadTris,theme\[1\],\.92,"environment","asphalt"\)/);
 assert.match(renderer,/part\(groundTris,theme\[0\],\.16,"environment",terrainTexture\)/);
 assert.match(renderer,/\[landscape,"#778b78",0,terrainTexture\]/);
 assert.match(renderer,/\[buildings,urban\?"#5c4d85":"#747b82",0,"concrete"\]/);assert.match(renderer,/\[treeTrunks,"#70533b",0,"bark"\]/);assert.match(renderer,/\[treeFoliage,theme\[3\],0,"foliage"\]/);
 assert.match(credits,/CC0 1\.0/);
 assert.match(credits,/Poly Haven/);
});

test("WebGL shader warmup restores the full canvas viewport before scene rendering",()=>{
 assert.match(renderer,/gl\.viewport\(0,0,1,1\);gl\.drawArrays\(gl\.TRIANGLES,0,3\);gl\.finish\(\);[\\s\\S]{0,500}?gl\.viewport\(0,0,canvas\.width,canvas\.height\);/);
});

test("race surfaces wind upward and correct downward horizontal face normals defensively",()=>{
 assert.match(renderer,/quad\(roadTris,l0,r0,r1,l1\)/);
 assert.match(renderer,/quad\(shoulderTris,sl0,l0,l1,sl1\)/);
 assert.match(renderer,/quad\(shoulderTris,r0,sr0,sr1,r1\)/);
 assert.match(renderer,/quad\(groundTris,outerL,outerR,outerR1,outerL1\)/);
 assert.match(renderer,/if\(Math\.abs\(ny\)>\.65&&ny<0\)\{nx=-nx;ny=-ny;nz=-nz;\}/);
});
