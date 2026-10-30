import { readFileSync, existsSync } from "node:fs";
import assert from "node:assert/strict";
const worlds=JSON.parse(readFileSync("data/worlds.json","utf8"));
const data=JSON.parse(readFileSync("data/stages.json","utf8"));
assert.equal(worlds.worlds.length,10);assert.equal(data.totalStages,50);assert.equal(data.stages.length,50);
assert.equal(new Set(data.stages.map(s=>s.id)).size,50);
for(const s of data.stages){assert.ok(worlds.worlds.some(w=>w.id===s.worldId));assert.ok(existsSync("."+s.preview));}
for(const path of ["index.html","src/game.js","src/physics.js","src/stage-catalog.ts","assets/scripts/MshinGame.ts","assets/scripts/VehicleController.ts","assets/scripts/WorldRenderer.ts","assets/scripts/ProgressStore.ts","settings/v2/packages/project.json","tsconfig.json"])assert.ok(existsSync(path),"Missing "+path);
console.log("PASS: 10 worlds, 50 metadata records, 50 previews and Cocos project source/config files.");
