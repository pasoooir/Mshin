import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const renderer=fs.readFileSync(new URL("../src/race-renderer-3d.js",import.meta.url),"utf8");
const pbr=fs.readFileSync(new URL("../src/vehicle-pbr.js",import.meta.url),"utf8");
const credits=fs.readFileSync(new URL("../src/racing/ENVIRONMENT_ASSET_CREDITS.md",import.meta.url),"utf8");

test("race renderer uses only committed local CC0 textures with procedural fallback",()=>{
 const expected={
  asphalt:"asphalt_03_diff_1k.jpg",grass:"grass_ground_diff_1k.jpg",sand:"sand_01_diff_1k.jpg",snow:"snow_03_diff_1k.jpg",
  rock:"rocky_terrain_02_diff_1k.jpg",concrete:"concrete_floor_02_diff_1k.jpg",bark:"bark_brown_02_diff_1k.jpg",foliage:"leafy_grass_diff_1k.jpg"
 };
 for(const [key,file] of Object.entries(expected)) assert.ok(renderer.includes(key+':"../assets/textures/'+file+'"'));
 assert.match(renderer,/new URL\(source,import\.meta\.url\)\.href/);
 assert.match(renderer,/sourceCounts:\{local:0\}/);
 assert.match(renderer,/state\.surfaceTextures\.loaded\+\+/);
 assert.doesNotMatch(renderer,/https?:\/\/dl\.polyhaven\.org|source\.fallback|sourceCounts\.cdn/);
 assert.match(renderer,/texture:surfaceKey\?surfaceTextures\.get\(surfaceKey\)/);
});

test("non-urban roadside house roofs emit valid three-vertex faces",()=>{
 assert.match(renderer,/tri\(roof,\[x-w\/2-7,eave,z-d\/2-7\],\[x\+w\/2\+7,eave,z-d\/2-7\],\[x,peak,z-d\/2-7\]\)/);
 assert.match(renderer,/tri\(roof,\[x\+w\/2\+7,eave,z\+d\/2\+7\],\[x-w\/2-7,eave,z\+d\/2\+7\],\[x,peak,z\+d\/2\+7\]\)/);
});

test("local texture loading is bounded and procedural fallback survives network-free startup",()=>{
 assert.match(renderer,/6500/);
 assert.match(renderer,/Local texture timed out/);
 assert.match(renderer,/createProceduralSurfacePixels\(key,fallbackSize\)/);
 assert.match(renderer,/const fallbackSize=128/);
 assert.match(renderer,/gl\.generateMipmap\(gl\.TEXTURE_2D\)/);
 assert.match(renderer,/rendererDestroyed\|\|lost\|\|generation!==surfaceLoadGeneration/);
 assert.match(renderer,/surfaceImages\.clear\(\)/);
 assert.match(renderer,/gl\.deleteTexture\(texture\)/);
 assert.doesNotMatch(renderer,/navigator\.connection\?\.saveData|softwareRenderer\|\|navigator\.connection/);
});

test("race ground plane faces upward and remains inside the camera far plane",()=>{
 assert.match(renderer,/quad\(terrainBaseTris,\[-30000,-40,-30000\],\[-30000,-40,30000\],\[30000,-40,30000\],\[30000,-40,-30000\]\)/);
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
 assert.match(renderer,/gl\.viewport\(0,0,1,1\);gl\.drawArrays\(gl\.TRIANGLES,0,3\);gl\.finish\(\);[\s\S]*?gl\.viewport\(0,0,canvas\.width,canvas\.height\);/);
});

test("large terrain background cannot depth-occlude the mobile racing circuit",()=>{
 assert.match(renderer,/terrainBaseTris=\[\]/);
 assert.match(renderer,/const terrainBasePart=part\(terrainBaseTris,theme\[0\]/);
 assert.match(renderer,/state\.terrainBaseVertices=terrainBasePart\.mesh\.count;state\.roadVertices=nextRoad\.mesh\.count/);
 assert.match(renderer,/drawPart\(drawParts\[0\],vp,translate\(0,0,0\)\);[\s\S]*?gl\.clear\(gl\.DEPTH_BUFFER_BIT\);[\s\S]*?for\(let i=1;i<drawParts\.length;i\+\+\)drawPart/);
 assert.match(renderer,/roadLikePixels/);
});

test("race surfaces wind upward and correct downward horizontal face normals defensively",()=>{
 assert.match(renderer,/quad\(roadTris,l0,r0,r1,l1\)/);
 assert.match(renderer,/quad\(shoulderTris,sl0,l0,l1,sl1\)/);
 assert.match(renderer,/quad\(shoulderTris,r0,sr0,sr1,r1\)/);
 assert.match(renderer,/quad\(groundTris,outerL,outerR,outerR1,outerL1\)/);
 assert.match(renderer,/if\(Math\.abs\(ny\)>\.65&&ny<0\)\{nx=-nx;ny=-ny;nz=-nz;\}/);
});

test("local CC0 race texture downloader and offline precache are declared",()=>{
 const downloader=fs.readFileSync(new URL("../scripts/download-race-textures.mjs",import.meta.url),"utf8");
 for(const name of ["asphalt_03","grass_ground","sand_01","snow_03","rocky_terrain_02","concrete_floor_02","bark_brown_02","leafy_grass"]) assert.ok(downloader.includes(name));
 assert.match(credits,/assets\/textures\//);
 assert.match(credits,/same-origin URLs/);
 assert.doesNotMatch(renderer,/https?:\/\/dl\.polyhaven\.org/);
});
