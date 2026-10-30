import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"..");
test("Cocos vector art library is a complete preloaded catalogue",async()=>{
 const art=JSON.parse(await readFile(path.join(root,"assets/resources/vector-art.json"),"utf8"));
 assert.equal(art.renderer,"cocos-graphics-vector");
 assert.equal(art.preloadPolicy,"load-before-main-menu");
 assert.equal(art.worlds.length,10);
 assert.equal(Object.keys(art.cars).length,5);
 for(const world of art.worlds){assert.ok(world.ground.startsWith("#"));assert.ok(world.accent.startsWith("#"));assert.ok(world.decoration);}
 for(const car of Object.values(art.cars)){assert.ok(car.body.startsWith("#"));assert.ok(car.glass.startsWith("#"));}
});
test("Cocos runtime gates the home menu behind JsonAsset preload",async()=>{
 const game=await readFile(path.join(root,"assets/scripts/MshinGame.ts"),"utf8");
 assert.match(game,/resources\.load\("vector-art",\s*JsonAsset/);
 assert.match(game,/this\.showHome\(\)/);
 assert.match(game,/hudRefresh/);
});
