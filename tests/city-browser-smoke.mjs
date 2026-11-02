import {chromium} from "playwright";
import assert from "node:assert/strict";
import fs from "node:fs";
const browser=await chromium.launch({headless:true,args:["--no-sandbox","--disable-dev-shm-usage","--enable-webgl","--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]});
const page=await browser.newPage({viewport:{width:844,height:390},screen:{width:844,height:390},deviceScaleFactor:1,isMobile:true,hasTouch:true});
const errors=[];page.on("pageerror",e=>errors.push(e.stack||String(e)));page.on("console",m=>{if(m.type()==="error")errors.push("console: "+m.text())});page.on("requestfailed",r=>errors.push("request failed: "+r.url()+" "+r.failure()?.errorText));
try{
 await page.goto("http://127.0.0.1:4173/city.html",{waitUntil:"domcontentloaded"});
 await page.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:30000});
 assert.ok(await page.locator("#cityThreeViewport").count()===1,"city must render through the Three.js WebGL scene");
 const renderStats=await page.evaluate(()=>window.MshinCity3DStats);
 assert.equal(renderStats.renderer,"three.js");
 assert.equal(renderStats.version,"180");
 assert.equal(renderStats.plots,676,"all 676 non-road cells must be rendered as 3D buildable parcels");
 assert.equal(renderStats.roadTiles,348,"the complete road grid must be rendered in 3D");
 assert.ok(renderStats.raisedCurbs>0&&renderStats.crosswalkStripes>=200,"streets need raised curbs and visible pedestrian crossings");
 assert.ok(renderStats.lockedPlots>=1600&&renderStats.visiblePlots>=2300,"the visible world must include a large locked expansion grid, not blank margins");
 assert.equal(renderStats.visibleRoadTiles,1392,"the expanded 64×64 world must have a continuous road network");
 assert.equal(await page.locator("#cityOrientationGate").evaluate(el=>getComputedStyle(el).display),"none","landscape entry must reveal the game world immediately");
 await page.screenshot({path:"artifacts/city-empty-world-landscape.png"});

 assert.ok(renderStats.drawCalls<80,"instanced city ground must stay within a mobile-friendly draw-call budget");

 const mapControls=await page.evaluate(()=>({zoom:window.MshinCityDebug.view.zoom,buttons:[...document.querySelectorAll(".cityMapControls button")].map(b=>{const r=b.getBoundingClientRect();return{width:r.width,height:r.height,visible:r.width>0&&r.height>0}})}));
 assert.ok(mapControls.zoom>=.7,"mobile city should open with a useful exploration zoom");assert.equal(mapControls.buttons.length,3);assert.ok(mapControls.buttons.every(b=>b.visible&&b.width>=44&&b.height>=44),"map zoom controls must be visible 44px touch targets");
 await page.locator("#cityZoomIn").click();const zoomedIn=await page.evaluate(()=>window.MshinCityDebug.view.zoom);assert.ok(zoomedIn>mapControls.zoom,"zoom-in control must enlarge the map");
 await page.locator("#cityZoomOut").click();const zoomedOut=await page.evaluate(()=>window.MshinCityDebug.view.zoom);assert.ok(zoomedOut<zoomedIn,"zoom-out control must reduce map scale");
 await page.locator("#cityRecenter").click();assert.ok(Math.abs(await page.evaluate(()=>window.MshinCityDebug.view.zoom)-.72)<.001,"recenter must restore the mobile map scale");
 assert.equal(await page.title(),"شهر من | مِشین");
 const initial=await page.evaluate(()=>({population:window.MshinCityDebug.city.population,buildings:window.MshinCityDebug.city.buildings.length,roads:window.MshinCityDebug.city.grid.flat().filter(t=>t==="road").length,citizens:window.MshinCityDebug.city.citizens.length,traffic:window.MshinCityDebug.city.traffic.length,animals:window.MshinCityDebug.city.animals.length,width:document.querySelector("#cityViewport").width}));
 assert.equal(initial.population,0,"new city must start without residents");assert.equal(initial.buildings,0,"new city must contain no buildings");assert.ok(initial.roads>=300,"the whole map must be subdivided by a complete road grid");assert.equal(initial.citizens,0);assert.equal(initial.traffic,0);assert.equal(initial.animals,0);assert.ok(initial.width>=320,"city canvas must use the available phone display width: "+JSON.stringify(initial));
 await page.locator('[data-city-tool="park"]').click();const target=await page.evaluate(()=>window.MshinCityDebug.screenForTile(14,14));await page.mouse.click(target.x,target.y);
 assert.equal(await page.evaluate(()=>window.MshinCityDebug.city.grid[14][14]),"building","park tool should place a city asset");
 await page.locator("#citySave").click();assert.ok(await page.evaluate(()=>JSON.parse(localStorage.getItem("mshin-city-save-v2"))?.buildings?.some(b=>b.x===14&&b.y===14)),"city changes should persist");
 const zoomBefore=await page.evaluate(()=>window.MshinCityDebug.view.zoom);
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",91,120,420);send("pointerdown",92,260,420);send("pointermove",92,320,420);send("pointerup",92,320,420);send("pointerup",91,120,420)});
 const zoomAfter=await page.evaluate(()=>window.MshinCityDebug.view.zoom);assert.ok(zoomAfter>zoomBefore,"two-finger pinch must zoom the city map");
 await page.locator('[data-city-tool="zone-residential"]').click();const zoneTarget=await page.evaluate(()=>window.MshinCityDebug.screenForTile(17,14));await page.mouse.click(zoneTarget.x,zoneTarget.y);
 assert.equal(await page.evaluate(()=>window.MshinCityDebug.city.grid[14][17]),"zone-residential","mobile players must be able to zone a road-connected tile");
 await page.evaluate(()=>{for(let i=0;i<12;i++)window.MshinCityDebug.step()});
 assert.ok(await page.evaluate(()=>window.MshinCityDebug.city.buildings.some(b=>b.x===17&&b.y===14&&b.type==="home")),"residential zoning must grow into a home when demand exists");
 for(const [type,x,y] of [["power",18,17],["water",14,17],["police",18,14]]){await page.locator('[data-city-tool="'+type+'"]').click();const point=await page.evaluate(({x,y})=>window.MshinCityDebug.screenForTile(x,y),{x,y});await page.mouse.click(point.x,point.y);assert.ok(await page.evaluate(({x,y,type})=>window.MshinCityDebug.city.buildings.some(b=>b.x===x&&b.y===y&&b.type===type),{x,y,type}),type+" infrastructure/service should be constructible on mobile")}
 await page.evaluate(()=>window.MshinCityDebug.step());
 const serviceStats=await page.evaluate(()=>window.MshinCityDebug.city.stats);
 assert.ok(serviceStats.utilityCoverage>0&&serviceStats.publicServiceCoverage>0&&serviceStats.overallCoverage>0,"utility and public service coverage must update the city simulation");
 const secondHome=await page.evaluate(()=>window.MshinCityDebug.place(17,13,"home"));assert.equal(secondHome.ok,true,"a second road-accessible home should be constructible");
 const demolition=await page.evaluate(()=>{const b=window.MshinCityDebug.city.buildings.find(v=>v.type==="home"&&!(v.x===17&&v.y===14));if(!b)throw new Error("test fixture needs a second residential building");return window.MshinCityDebug.actAt(b.x,b.y,"bulldoze")});
 assert.equal(demolition.cell,"grass","bulldoze action must remove the selected residential building");assert.equal(demolition.saved.grid.flat().filter(v=>v==="building").length,await page.evaluate(()=>window.MshinCityDebug.city.buildings.length),"demolition must persist immediately");
 await page.evaluate(()=>{for(let i=0;i<6;i++)window.MshinCityDebug.step()});await page.waitForTimeout(100);
 assert.ok(await page.evaluate(()=>JSON.parse(localStorage.getItem("mshin-city-save-v2"))?.tick>=6),"simulation must autosave without a manual save");
 await page.bringToFront();await page.locator('[data-city-speed="1"]').click();await page.waitForFunction(()=>document.visibilityState==="visible");const before=await page.evaluate(()=>window.MshinCityDebug.city.tick);await page.waitForTimeout(4000);const simulation=await page.evaluate(()=>({tick:window.MshinCityDebug.city.tick,visibility:document.visibilityState,speedLabel:document.querySelector("#citySpeedLabel")?.textContent}));assert.ok(simulation.tick>before,"simulation should advance while the mobile city is visible at 1x speed: "+JSON.stringify({before,...simulation}));
 const mobile=await page.evaluate(()=>{const rect=s=>{const r=document.querySelector(s).getBoundingClientRect();return{x:r.x,y:r.y,width:r.width,height:r.height,right:r.right,bottom:r.bottom}};return{viewport:{width:innerWidth,height:innerHeight},documentWidth:document.documentElement.scrollWidth,brand:rect(".cityBrand"),metrics:rect(".cityMetrics"),tools:rect(".cityTools"),bottom:rect(".cityBottom"),toolButtons:[...document.querySelectorAll(".cityTool")].map(b=>{const r=b.getBoundingClientRect();return{width:r.width,height:r.height,right:r.right,left:r.left}}),viewportMeta:document.querySelector('meta[name="viewport"]').content}});
 assert.equal(mobile.documentWidth,mobile.viewport.width,"mobile city must not create horizontal page overflow");
 assert.ok(mobile.tools.y>mobile.metrics.bottom,"mobile construction dock must sit below the city metrics");
 assert.ok(mobile.tools.bottom<=mobile.bottom.y+1,"mobile tool dock must not overlap the bottom status bar");
 assert.ok(mobile.toolButtons.every(b=>b.width>=40&&b.height>=44),"mobile touch targets must be at least 40×44 CSS pixels");assert.ok(await page.locator(".cityTools").evaluate(el=>el.scrollWidth>el.clientWidth),"extended city construction tools must remain horizontally reachable on phones");
 assert.ok(!/user-scalable=no|maximum-scale=1/.test(mobile.viewportMeta),"mobile browser zoom must remain enabled");
 await page.screenshot({path:"artifacts/city-mobile-landscape-844x390.png"});
 const compactPage=await browser.newPage({viewport:{width:360,height:640},screen:{width:360,height:640},deviceScaleFactor:1,isMobile:true,hasTouch:true});
 try{
  await compactPage.addInitScript(()=>{
   window.__cityOrientationCalls=[];
   document.documentElement.requestFullscreen=async()=>{window.__cityOrientationCalls.push("fullscreen")};
   Object.defineProperty(screen,"orientation",{configurable:true,value:{type:"portrait-primary",angle:0,lock:async mode=>{window.__cityOrientationCalls.push("lock:"+mode)},unlock:()=>{}}});
  });
  await compactPage.goto("http://127.0.0.1:4173/city.html");
  await compactPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:30000});
  const compact=await compactPage.evaluate(()=>({width:document.documentElement.scrollWidth,viewport:innerWidth,gate:getComputedStyle(document.querySelector("#cityOrientationGate")).display,tools:document.querySelector(".cityTools").getBoundingClientRect().toJSON(),bottom:document.querySelector(".cityBottom").getBoundingClientRect().toJSON()}));
  assert.equal(compact.gate,"grid","portrait phones must be stopped at the landscape orientation gate");
  assert.equal(compact.width,compact.viewport,"compact phone layout must not overflow horizontally");
  assert.ok(compact.tools.bottom<=compact.bottom.y+1,"compact phone controls must remain separated");
  fs.mkdirSync("artifacts",{recursive:true});
  await compactPage.screenshot({path:"artifacts/city-portrait-orientation-gate.png",fullPage:true});
  const orientationShim=await compactPage.evaluate(()=>({lockType:typeof screen.orientation?.lock,orientationType:screen.orientation?.type,buttonVisible:(()=>{const r=document.querySelector("#cityEnterLandscape").getBoundingClientRect();return r.width>0&&r.height>0})()}));
  assert.equal(orientationShim.lockType,"function","orientation shim missing: "+JSON.stringify(orientationShim));
  await compactPage.locator("#cityEnterLandscape").click();
  try{await compactPage.waitForFunction(()=>window.__cityOrientationCalls.includes("lock:landscape"),undefined,{timeout:5000})}catch(error){const diagnostic=await compactPage.evaluate(()=>({calls:window.__cityOrientationCalls,lockType:typeof screen.orientation?.lock,orientationType:screen.orientation?.type,gate:getComputedStyle(document.querySelector("#cityOrientationGate")).display}));throw new Error("orientation lock not requested: "+JSON.stringify(diagnostic)+"; "+error.message)}
  assert.deepEqual(await compactPage.evaluate(()=>window.__cityOrientationCalls),["fullscreen","lock:landscape"],"city entry must request fullscreen then native landscape lock from a user gesture");
  assert.equal(await compactPage.locator("#cityOrientationGate").evaluate(el=>getComputedStyle(el).display),"grid","portrait gate must remain visible when the browser cannot rotate the device");
 }finally{await compactPage.close()}
 // Chromium can reject Browser.setWindowBounds after fullscreen/orientation APIs
 // have been exercised. Verify landscape in a fresh page with its final viewport.
 const landscapePage=await browser.newPage({viewport:{width:844,height:390},deviceScaleFactor:1,isMobile:true,hasTouch:true});
 try{
  await landscapePage.goto("http://127.0.0.1:4173/city.html",{waitUntil:"domcontentloaded"});
  await landscapePage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:30000});
  await landscapePage.waitForFunction(()=>getComputedStyle(document.querySelector("#cityOrientationGate")).display==="none");
  const landscape=await landscapePage.evaluate(()=>({width:document.documentElement.scrollWidth,viewport:innerWidth,height:innerHeight,gate:getComputedStyle(document.querySelector("#cityOrientationGate")).display}));
  assert.equal(landscape.gate,"none","landscape page must show the city rather than the portrait gate");
  assert.equal(landscape.width,landscape.viewport,"landscape city must not overflow horizontally");
  fs.mkdirSync("artifacts",{recursive:true});
  await landscapePage.screenshot({path:"artifacts/city-vertical-slice.png",fullPage:true});
 }finally{await landscapePage.close()}
 assert.deepEqual(errors,[],"city route must not throw runtime errors");
 process.stdout.write("City browser smoke passed: empty 3D grid, WebGL renderer, pinch zoom, zoning, construction, service coverage, demolition persistence, autosave and live simulation.\\n");
}finally{await browser.close()}
