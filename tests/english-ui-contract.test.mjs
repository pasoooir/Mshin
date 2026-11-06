import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"..");
const read=relative=>readFile(path.join(root,relative),"utf8");

test("racing and city entry documents declare English left-to-right layout",async()=>{
 for(const file of ["index.html","city.html"]){const html=await read(file);assert.match(html,/<html lang="en" dir="ltr">/,file+" must declare English and LTR");}
});

test("visible game entry copy and dynamic game labels use Latin scripts and digits",async()=>{
 const files=["index.html","city.html","src/web-game.js","src/boot.js","src/city/city-view.js","src/stage-catalog.ts","src/asset-manifest.json","data/worlds.json","src/city/city-visual-asset-catalog.js","src/city/city-seasonal-weather.js"];
 for(const file of files){const source=await read(file);assert.doesNotMatch(source,/[۰-۹]/,file+" must not contain Persian digits");}
 for(const file of files){const source=await read(file);assert.doesNotMatch(source,/[\\u0600-\\u06ff]/,file+" must contain only English UI text and Latin digits");}
});
