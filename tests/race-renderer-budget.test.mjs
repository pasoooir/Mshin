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
});
