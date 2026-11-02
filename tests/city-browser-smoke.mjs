import {chromium} from "playwright";
import assert from "node:assert/strict";
import fs from "node:fs";
const browser=await chromium.launch({headless:true,args:["--no-sandbox"]});
const page=await browser.newPage({viewport:{width:1440,height:900},deviceScaleFactor:1});
const errors=[];page.on("pageerror",e=>errors.push(String(e)));
try{
 await page.goto("http://127.0.0.1:4173/city.html",{waitUntil:"domcontentloaded"});
 await page.waitForFunction(()=>document.documentElement.dataset.cityReady==="true",undefined,{timeout:10000});
 assert.equal(await page.title(),"شهر من | مِشین");
 const initial=await page.evaluate(()=>({population:window.MshinCityDebug.city.population,buildings:window.MshinCityDebug.city.buildings.length,roads:window.MshinCityDebug.city.grid.flat().filter(t=>t==="road").length,citizens:window.MshinCityDebug.city.citizens.length,traffic:window.MshinCityDebug.city.traffic.length,width:document.querySelector("#cityViewport").width}));
 assert.ok(initial.population>100,"entry page must show a populated city");assert.ok(initial.buildings>=30,"initial buildings should be visible");assert.ok(initial.roads>=100,"city should have a street grid");assert.ok(initial.citizens>=20&&initial.traffic>=6,"citizens and traffic should be present");assert.ok(initial.width>=600,"city must render on canvas");
 await page.setViewportSize({width:390,height:844});await page.waitForTimeout(100);
 const mobileView=await page.evaluate(()=>({zoom:window.MshinCityDebug.zoom,canvas:{width:document.querySelector("#cityViewport").clientWidth,height:document.querySelector("#cityViewport").clientHeight},controls:[...document.querySelectorAll(".cityMapControls button")].map(b=>{const r=b.getBoundingClientRect();return{width:r.width,height:r.height,visible:r.width>0&&r.height>0}}),scrollWidth:document.documentElement.scrollWidth}));
 assert.ok(mobileView.zoom>=1,"city must open at a genuinely enlarged mobile zoom level");assert.deepEqual(mobileView.canvas,{width:390,height:844});assert.equal(mobileView.scrollWidth,390,"city viewport must not overflow horizontally");assert.equal(mobileView.controls.length,3);assert.ok(mobileView.controls.every(b=>b.visible&&b.width>=40&&b.height>=40),"map navigation buttons must be touch friendly");
 await page.locator("#cityZoomIn").click();const zoomed=await page.evaluate(()=>window.MshinCityDebug.zoom);assert.ok(zoomed>mobileView.zoom,"zoom-in button must enlarge the map");await page.locator("#cityRecenter").click();assert.ok(Math.abs(await page.evaluate(()=>window.MshinCityDebug.zoom)-1.05)<.001,"recenter must restore the large mobile default");
 await page.setViewportSize({width:1440,height:900});
 await page.locator('[data-city-tool="park"]').click();const target=await page.evaluate(()=>window.MshinCityDebug.screenForTile(14,14));await page.mouse.click(target.x,target.y);
 assert.equal(await page.evaluate(()=>window.MshinCityDebug.city.grid[14][14]),"building","park tool should place a city asset");
 await page.locator("#citySave").click();assert.ok(await page.evaluate(()=>JSON.parse(localStorage.getItem("mshin-city-save-v1"))?.buildings?.some(b=>b.x===14&&b.y===14)),"city changes should persist");
 const before=await page.evaluate(()=>window.MshinCityDebug.city.tick);await page.waitForTimeout(1300);const after=await page.evaluate(()=>window.MshinCityDebug.city.tick);assert.ok(after>before,"simulation should advance");
 fs.mkdirSync("artifacts",{recursive:true});await page.screenshot({path:"artifacts/city-vertical-slice.png",fullPage:true});assert.deepEqual(errors,[],"city route must not throw runtime errors");
 process.stdout.write("City browser smoke passed: initial city, street grid, buildings, citizens, traffic, construction, local save and live simulation.\n");
}finally{await browser.close()}
