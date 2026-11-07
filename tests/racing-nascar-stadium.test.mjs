import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const renderer=fs.readFileSync(new URL("../src/race-renderer-3d.js",import.meta.url),"utf8");
const stadium=fs.readFileSync(new URL("../src/nascar-stadium.js",import.meta.url),"utf8");

test("racing scene builds curved NASCAR-style grandstands on both sides of the oval",()=>{
 assert.match(stadium,/const standSections=mobile\?16:softwareRenderer\?22:40/);
 assert.match(stadium,/const standRows=mobile\?4:5/);
 assert.match(stadium,/for\(const side of \[-1,1\]\)/);
 for(const name of ["stadiumDecks","stadiumRisers","stadiumSupports","stadiumCanopies"]) assert.match(stadium,new RegExp(name));
 assert.match(stadium,/grandstandSections=standSections\*2/);
 assert.match(stadium,/grandstandRows=standRows/);
});

test("grandstands contain individually modeled spectators and bounded upload batching",()=>{
 assert.match(stadium,/const peoplePerRow=mobile\?1:softwareRenderer\?1:2/);
 assert.match(stadium,/stadiumSpectators\+\+/);
 assert.match(stadium,/environmentCounts\.spectators\+=stadiumSpectators/);
 for(const name of ["stadiumDecks","stadiumRisers","stadiumSupports","stadiumCanopies"]) assert.match(renderer,new RegExp("\\["+name+","));
 assert.match(renderer,/const maxUploadValues=4096\*9/);
});

test("grandstand generation yields between section batches instead of blocking the mobile frame",()=>{
 assert.match(stadium,/if\(section%4===3\)yield section/);
 assert.match(renderer,/for\(const section of stadiumBuild\)/);
});
