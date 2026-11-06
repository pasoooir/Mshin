import test from "node:test";
import assert from "node:assert/strict";
import {createRaceLives,registerPlayerExplosion} from "../src/race-lives.js";

test("player gets two same-position respawns and loses after the third explosion",()=>{
 const lives=createRaceLives(3);
 assert.deepEqual(registerPlayerExplosion(lives),{respawn:true,lost:false,remaining:2,explosions:1});
 assert.deepEqual(registerPlayerExplosion(lives),{respawn:true,lost:false,remaining:1,explosions:2});
 assert.deepEqual(registerPlayerExplosion(lives),{respawn:false,lost:true,remaining:0,explosions:3});
 assert.deepEqual(registerPlayerExplosion(lives),{respawn:false,lost:true,remaining:0,explosions:3});
});

test("race lives supports a single-life challenge",()=>{
 const lives=createRaceLives(1);
 assert.deepEqual(registerPlayerExplosion(lives),{respawn:false,lost:true,remaining:0,explosions:1});
});
