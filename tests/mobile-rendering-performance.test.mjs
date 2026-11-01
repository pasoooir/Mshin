import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [html, game, renderer] = await Promise.all([
  readFile(new URL("../index.html", import.meta.url), "utf8"),
  readFile(new URL("../src/web-game.js", import.meta.url), "utf8"),
  readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8")
]);

test("portrait phones rotate the active WebGL canvas with the landscape game", () => {
  assert.match(html, /#game,#game3d,#assetLoader,#countdownOverlay,#hud,\.overlay/);
  assert.match(html, /#game,#game3d\{display:block!important\}/);
  assert.match(html, /transform:rotate\(90deg\) translateY\(-100%\)!important/);
});

test("mobile WebGL uses a bounded landscape drawing buffer and lower GPU cost", () => {
  assert.match(renderer, /const mobile=matchMedia\("\(pointer:coarse\)"\)/);
  assert.match(renderer, /antialias:!mobile/);
  assert.match(renderer, /mobile\?\.78:1\.5/);
  assert.match(renderer, /portrait\?innerHeight:innerWidth/);
  assert.match(renderer, /mobile\?112:360/);
  assert.match(renderer, /mobile\?24:70/);
});

test("race simulation advances in stable fixed 60 Hz steps", () => {
  assert.match(game, /const FIXED_STEP=1\/60/);
  assert.match(game, /while\(simulationAccumulator>=FIXED_STEP&&steps<\(mobileDevice\?3:8\)\)\{update\(FIXED_STEP\)/);
  assert.match(game, /simulationAccumulator=Math\.min\(simulationAccumulator\+frameDelta,mobileDevice\?\.05:\.1\)/);
});

test("3D chase camera eases toward its target instead of snapping", () => {
  assert.match(renderer, /cameraDt=lastRenderAt\?Math\.min\(\(now-lastRenderAt\)\/1000,mobile\?\.05:\.1\):1\/60/);
  assert.match(renderer, /Math\.exp\(-cameraDt\/\(mobile\?\.16:\.11\)\)/);
  assert.match(renderer, /cameraEye\[i\]\+=\(desiredEye\[i\]-cameraEye\[i\]\)\*follow/);
});

test("3D stage rebuilds release previous GPU buffers instead of leaking meshes", () => {
  assert.match(renderer, /function disposeParts\(parts\)\{for\(const item of parts\).*?gl\.deleteBuffer\(buffer\)/);
  assert.match(renderer, /disposeParts\(\[road,\.\.\.decor\]\);road=null;decor=\[\]/);
  assert.match(renderer, /destroy\(\).*?disposeParts\(\[road,\.\.\.decor,\.\.\.carParts\]\)/);
});

test("WebGL context restoration recreates the shader pipeline and invalidated stage buffers", () => {
  assert.match(renderer, /function onRestored\(\)\{[\s\S]*?program=makeProgram\(gl\)/);
  assert.match(renderer, /attributes=\{position:gl\.getAttribLocation\(program,"aPosition"\)/);
  assert.match(renderer, /uniforms=\{mvp:gl\.getUniformLocation\(program,"uMvp"\)/);
  assert.match(renderer, /road=null;decor=\[\];carParts=\[\];lastStage=-1;lastSize=""/);
  assert.match(renderer, /state\.status="webgl-ready";state\.error=null/);
});

test("WebGL program creation releases temporary compiled shader objects", () => {
  assert.match(renderer, /function makeProgram\(gl\)\{[\s\S]*?gl\.detachShader\(p,vertex\);gl\.detachShader\(p,fragment\);gl\.deleteShader\(vertex\);gl\.deleteShader\(fragment\)/);
  assert.match(renderer, /catch\(error\)\{[\s\S]*?gl\.deleteProgram\(p\)[\s\S]*?gl\.deleteShader\(vertex\)[\s\S]*?gl\.deleteShader\(fragment\)/);
});

test("mobile rendering targets 60fps without dropping alternate high-refresh callbacks", () => {
  assert.match(game, /const FIXED_STEP=1\\/60,RENDER_STEP=1\\/60/);
  assert.match(game, /renderAccumulator\\+=frameDelta/);
  assert.match(game, /renderAccumulator>=RENDER_STEP/);
  assert.doesNotMatch(game, /ts-last<16\\.5/);
});

test("mobile renderer adapts drawing resolution to measured render cost", () => {
  assert.match(game, /renderCostEMA>22/);
  assert.match(game, /renderCostEMA<14/);
  assert.match(game, /race3d\\.setQuality\\?\\.\\(adaptiveQuality\\)/);
  assert.match(renderer, /setQuality\\(scale\\)\\{qualityScale=clamp\\(scale,\\.58,1\\)/);
});

test("driving acceleration, top speed and displayed speed are increased", () => {
  assert.match(game, /maxSpeed=model\\.max\\*1\\.22/);
  assert.match(game, /accel=model\\.accel\\*1\\.3/);
  assert.match(game, /cruiseSpeed:activeCar\\(\\)\\.max\\*1\\.2/);
  assert.match(game, /textContent=Math\\.round\\(car\\.speed\\*\\.55\\)/);
});

test("AI-to-AI collision work uses an angular broad phase before track geometry", () => {
  assert.match(game, /angularGap=Math\\.abs\\(Math\\.atan2\\(Math\\.sin\\(b\\.distance-a\\.distance\\)/);
  assert.ok(game.indexOf("angularGap>.14") < game.indexOf("const fa=frameAt(a.distance%(Math.PI*2)),fb=frameAt(b.distance%(Math.PI*2))"));
});
