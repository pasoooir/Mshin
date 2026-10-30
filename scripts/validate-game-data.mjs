import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import assert from "node:assert/strict";
const worlds=JSON.parse(readFileSync("data/worlds.json","utf8"));
const data=JSON.parse(readFileSync("data/stages.json","utf8"));
assert.equal(worlds.worlds.length,10);
assert.equal(data.totalStages,50);
assert.equal(data.stages.length,50);
assert.equal(new Set(data.stages.map(s=>s.id)).size,50);
for(const s of data.stages){assert.ok(worlds.worlds.some(w=>w.id===s.worldId));assert.ok(existsSync(resolve(s.preview.slice(1))),"Missing "+s.preview);}
assert.ok(existsSync("index.html"),"Playable prototype entry page missing");
assert.ok(existsSync("src/game.js"),"Game runtime missing");
assert.ok(existsSync("src/physics.js"),"Driving physics missing");
console.log("PASS: 10 worlds, 50 stages, 50 SVG previews and playable prototype files.");
