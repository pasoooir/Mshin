import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const renderer=fs.readFileSync(new URL("../src/race-renderer-3d.js",import.meta.url),"utf8");
const stadium=fs.readFileSync(new URL("../src/nascar-stadium.js",import.meta.url),"utf8");

test("racing scene builds curved NASCAR-style grandstands on both sides of the oval",()=>{
 assert.match(renderer,/const standSections=mobile\?16:softwareRenderer\?22:40/);
 assert.match(renderer,/const standRows=mobile\?4:5/);
 assert.match(renderer,/for\(const side of \[-1,1\]\)/);
 assert.match(renderer,/stadiumDecks/);
 assert.match(renderer,/stadiumRisers/);
 assert.match(renderer,/stadiumSupports/);
 assert.match(renderer,/stadiumCanopies/);
 assert.match(renderer,/state\.environmentCounts\.grandstandSections=standSections\*2/);
 assert.match(renderer,/state\.environmentCounts\.grandstandRows=standRows/);
});

test("grandstands contain individually modeled spectators and stay in the bounded upload pipeline",()=>{
 assert.match(renderer,/const peoplePerRow=mobile\?1:softwareRenderer\?1:2/);
 assert.match(renderer,/stadiumSpectators\+\+/);
 assert.match(renderer,/state\.environmentCounts\.spectators\+=stadiumSpectators/);
 for(const name of ["stadiumDecks","stadiumRisers","stadiumSupports","stadiumCanopies"]){
  assert.match(renderer,new RegExp("\\["+name+","));
 }
 assert.match(renderer,/const maxUploadValues=4096\*9/);
});

test("grandstand generation yields between section batches instead of blocking the mobile frame",()=>{
 assert.match(renderer,/if\(section%4===3\)yield \{progress:/);
});
