import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/race-renderer-3d.js", import.meta.url), "utf8");

test("trackside ad panels render readable vector MSHIN and race-series artwork", () => {
  assert.match(source, /const BILLBOARD_FONT=/);
  assert.match(source, /function billboardText\(/);
  assert.match(source, /billboardText\(billboardAccents,"MSHIN"/);
  assert.match(source, /billboardText\(billboardAccents,"RACE"/);
});

test("unbooked sponsor inventory has a branded house-ad fallback", () => {
  assert.match(source, /available:true,creative:\{type:"house-ad",brand:"MSHIN",campaign:"RACE-SERIES"\}/);
  assert.match(source, /state\.adSlots=billboardSlots/);
});

test("ad artwork uses the existing procedural geometry path without image or CDN dependencies", () => {
  assert.match(source, /quad\(out,point\(x-half,y-half,depth\),point\(x\+half,y-half,depth\),point\(x\+half,y\+half,depth\),point\(x-half,y\+half,depth\)\)/);
  assert.doesNotMatch(source, /https?:\/\//);
});
