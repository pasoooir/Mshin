import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8");

test("procedural 3D scene stays within a bounded first-build geometry budget", () => {
  assert.ok(source.includes("const segments=mobile?84:240,half=180;"),
    "desktop track tessellation is capped at 240 segments");
  assert.ok(source.includes("treeCount=mobile?18:48"),
    "desktop tree instances are capped at 48");
  assert.ok(source.includes("i+=(mobile?18:6)"),
    "trackside rail sampling is bounded on desktop");
  assert.ok(source.includes("spectatorCount=mobile?10:36"),
    "desktop crowd instances are capped at 36");
});

test("the scene keeps its full road width while reducing mesh density", () => {
  assert.ok(source.includes("const segments=mobile?84:240,half=180;"));
  assert.ok(source.includes("quad(roadTris,l0,l1,r1,r0)"),
    "the asphalt remains a continuous closed road ribbon");
});

test("WebGL geometry upload avoids per-triangle temporary arrays", () => {
  const start = source.indexOf("function makeGeometry(gl,triangles)");
  const end = source.indexOf("\nfunction tri(", start);
  assert.ok(start >= 0 && end > start, "geometry uploader must remain a named local helper");
  const uploader = source.slice(start, end);
  assert.match(uploader, /new Float32Array\(vertexCount\*6\)/);
  assert.match(uploader, /Math\.hypot\(nx0,ny0,nz0\)/);
  assert.doesNotMatch(uploader, /triangles\.slice|\.map\(|\.push\(/,
    "geometry upload must not allocate temporary vertex arrays per triangle");
  assert.match(source, /state\.trackBuildMs=performance\.now\(\)-trackBuildStarted/,
    "total incremental track construction time must be exposed for browser profiling");
});

test("track geometry is assembled in bounded frame-sized phases", () => {
  assert.match(source, /function\* buildTrack\(snapshot\)/,
    "track generation must be resumable instead of blocking one frame");
  assert.match(source, /yield \{parts:\[nextRoad,\.\.\.nextDecor\],progress:\.34\}/,
    "road geometry must be uploaded as the first bounded phase");
  assert.match(source, /progress:\.67/,
    "scenery geometry must be uploaded as a separate phase");
  assert.match(source, /trackBuildJob\.next\(\)/,
    "the render loop must advance no more than one construction phase per frame");
  assert.match(source, /state\.trackBuildProgress=step\.value\.progress/,
    "the renderer must expose incremental construction progress");
  assert.match(source, /if\(road\)drawPart\(road,vp/,
    "the renderer must remain safe before the first complete road mesh exists");
  assert.match(source, /disposeParts\(previous\)/,
    "old stage GPU buffers must be released only after the replacement is ready");
  assert.match(source, /yield \{progress:\.39\}/, "sky construction must yield before scenery generation");
  assert.match(source, /if\(i%4===3\)yield \{progress:/, "large scenery loops must yield in bounded chunks");
  assert.match(source, /if\(step\.value\.parts\)pendingTrackParts=step\.value\.parts/, "progress-only yields must preserve pending GPU buffers");
  assert.match(source, /const maxUploadValues=4096\*9/, "large scenery meshes must be split into bounded GPU upload batches");
  assert.match(source, /vertices\.slice\(offset,end\)/, "each GPU upload must contain only one bounded geometry slice");
  assert.match(source, /progress:\.68\+\.30\*\(uploadedValues\/Math\.max\(1,uploadValues\)\)/, "GPU upload progress must advance monotonically across all scenery batches");
});


test("all late trackside and crowd geometry enters the bounded upload queue", () => {
  const billboardBuild = source.indexOf("const billboardCount=mobile?8:20;");
  const uploadQueue = source.indexOf("const uploadQueue=[");
  const finalReturn = source.indexOf("return {road:nextRoad,decor:nextDecor,stageId:snapshot.stageId};", uploadQueue);
  assert.ok(billboardBuild >= 0 && uploadQueue > billboardBuild,
    "billboards, railings and late crowd geometry must be assembled before GPU uploads begin");
  assert.ok(finalReturn > uploadQueue, "bounded uploads must finish before the completed track is returned");
  const afterQueue = source.slice(uploadQueue, finalReturn);
  assert.match(afterQueue, /\[billboardPosts,/,
    "billboard geometry must be included in the chunked upload queue");
  assert.match(afterQueue, /\[railTris,/,
    "rail geometry must be included in the chunked upload queue");
  assert.match(afterQueue, /\[crowdBodies,/,
    "late crowd geometry must be included in the chunked upload queue");
  assert.doesNotMatch(afterQueue, /nextDecor\.push\(part\(billboardPosts/,
    "the completion frame must not synchronously upload the full late-scene meshes");
});

test("mesh upload duration is exposed for browser performance diagnostics", () => {
  assert.match(source, /state\.maxMeshUploadMs=Math\.max\(state\.maxMeshUploadMs\|\|0,elapsed\)/);
  assert.match(source, /maxMeshUploadMs:0,meshUploadCount:0/);
});


test("late track construction yields between rail, crowd and billboard batches", () => {
  assert.match(source, /if\(\+\+railSegmentsBuilt%\(mobile\?2:12\)===0\)yield \{progress:\.67\+/,
    "rail generation must not monopolize one render frame");
  assert.match(source, /if\(i%4===3\)yield \{progress:\.673\+/,
    "additional crowd geometry must be built in small frame-sized batches");
  assert.match(source, /if\(i%2===1\)yield \{progress:\.675\+/,
    "billboard generation must yield before the mesh upload queue");
  assert.match(source, /state\.maxTrackBuildStepMs=Math\.max/);
  assert.match(source, /state\.maxDrawPartMs=Math\.max/);
});
