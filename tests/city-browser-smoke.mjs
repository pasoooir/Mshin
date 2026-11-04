import {chromium} from "playwright";
import assert from "node:assert/strict";
import fs from "node:fs";

const cityToolCategories={select:"manage",bulldoze:"manage",road:"roads","zone-residential":"roads","zone-commercial":"roads","zone-industrial":"roads","zone-administrative":"roads","zone-recreational":"roads",home:"buildings",shop:"buildings",power:"services",water:"services",sewage:"services",waste:"services",police:"services",fire:"services",health:"services",education:"services",service:"services",park:"services"};
async function clickCityTool(page,type){
 const category=cityToolCategories[type];
 if(!category)throw new Error("Missing city tool category: "+type);
 await page.locator('[data-city-category="'+category+'"]').click();
 await page.locator('[data-city-tool="'+type+'"]').click();
}

const browser=await chromium.launch({headless:true,args:["--no-sandbox","--disable-dev-shm-usage","--enable-webgl","--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"]});
fs.mkdirSync("artifacts/city-camera-video",{recursive:true});
const cameraContext=await browser.newContext({viewport:{width:844,height:390},screen:{width:844,height:390},deviceScaleFactor:1,isMobile:true,hasTouch:true,recordVideo:{dir:"artifacts/city-camera-video",size:{width:844,height:390}}});
const page=await cameraContext.newPage();
const errors=[];page.on("pageerror",e=>errors.push(e.stack||String(e)));page.on("console",m=>{if(m.type()==="error")errors.push("console: "+m.text())});page.on("requestfailed",r=>errors.push("request failed: "+r.url()+" "+r.failure()?.errorText));
try{
 await page.addInitScript(()=>{
  window.__cityFullscreen=false;window.__cityEntryOrder=[];
  Object.defineProperty(Document.prototype,"fullscreenElement",{configurable:true,get(){return window.__cityFullscreen?document.documentElement:null}});
  HTMLElement.prototype.requestFullscreen=async function(){
   if(!navigator.userActivation?.isActive)throw new DOMException("User activation required","NotAllowedError");
   window.__cityEntryOrder.push("fullscreen");window.__cityFullscreen=true;
   document.dispatchEvent(new Event("fullscreenchange"));
  };
  Object.defineProperty(screen,"orientation",{configurable:true,value:{lock:async value=>{
   if(!window.__cityFullscreen)throw new Error("orientation lock must follow fullscreen");
   window.__cityEntryOrder.push("orientation:"+value);
  }}});
 });
 await page.goto("http://127.0.0.1:4173/city.html",{waitUntil:"domcontentloaded"});
 const rendererBootStartedAt=Date.now();
 await page.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:60000,polling:100});
 const rendererBootDuration=Date.now()-rendererBootStartedAt;
 assert.ok(rendererBootDuration<60000,"compact city renderer must finish initialization within the bounded 60-second mobile startup budget");
 const viewportMeta=await page.locator('meta[name="viewport"]').getAttribute("content");
 assert.match(viewportMeta,/viewport-fit=cover/,"city must opt into safe-area-aware mobile viewport sizing");
 const initialVisualViewport=await page.evaluate(()=>({width:visualViewport.width,height:visualViewport.height}));
 assert.ok(Math.abs(initialVisualViewport.width-844)<=1&&Math.abs(initialVisualViewport.height-390)<=1,"city must start sized to the visible landscape viewport");
 await page.setViewportSize({width:780,height:360});
 await page.waitForFunction(()=>Math.abs(parseFloat(document.querySelector("#cityViewport").style.width)-visualViewport.width)<=1
  &&Math.abs(parseFloat(document.querySelector("#cityViewport").style.height)-visualViewport.height)<=1,undefined,{timeout:5000});
 const resizedCityViewport=await page.evaluate(()=>({visualWidth:visualViewport.width,visualHeight:visualViewport.height,canvasWidth:parseFloat(document.querySelector("#cityViewport").style.width),canvasHeight:parseFloat(document.querySelector("#cityViewport").style.height)}));
 assert.ok(Math.abs(resizedCityViewport.canvasWidth-780)<=1&&Math.abs(resizedCityViewport.canvasHeight-360)<=1,"city canvas must follow browser chrome/visible viewport resizing");
 await page.setViewportSize({width:844,height:390});
 await page.waitForFunction(()=>Math.abs(parseFloat(document.querySelector("#cityViewport").style.width)-844)<=1
  &&Math.abs(parseFloat(document.querySelector("#cityViewport").style.height)-390)<=1,undefined,{timeout:5000});



 const toolMenu=await page.evaluate(()=>({categories:[...document.querySelectorAll("[data-city-category]")].map(b=>b.textContent.trim()),panels:[...document.querySelectorAll("[data-city-panel]")].map(p=>p.hidden),tools:document.querySelectorAll("[data-city-tool]").length}));
 assert.equal(toolMenu.categories.length,4,"mobile construction controls must be grouped into four clear categories");
 assert.equal(toolMenu.tools,20,"grouping must preserve every existing city tool");
 assert.ok(toolMenu.panels.every(Boolean),"all tool panels must start auto-hidden to keep the map uncluttered");
 await page.locator('[data-city-category="buildings"]').click();
 assert.equal(await page.locator('[data-city-panel="buildings"]').isVisible(),true,"tapping a category must reveal only its tool panel");
 await page.locator('[data-city-tool="home"]').click();
 assert.equal(await page.locator('[data-city-panel="buildings"]').isVisible(),false,"choosing a tool must automatically hide its category panel");
 assert.equal(await page.locator('[data-city-tool="home"]').getAttribute("aria-pressed"),"true","the chosen city tool must remain selected after auto-hide");

 assert.ok(await page.locator("#cityThreeViewport").count()===1,"city must render through the Three.js WebGL scene");
 const renderStats=await page.evaluate(()=>window.MshinCity3DStats);
 assert.equal(renderStats.renderer,"three.js");
 assert.equal(renderStats.version,"180");
 assert.equal(renderStats.visualStyle,"realistic-pbr-city","the city renderer must use the realistic architectural PBR art direction");
 assert.equal(renderStats.proceduralTextures,6,"terrain, asphalt, brick, concrete, roof and sidewalk must use dedicated texture families");
 assert.equal(renderStats.pbrMaterialSets,6,"all six city surface families must expose complete PBR map sets");
 assert.equal(renderStats.normalMappedSurfaces,6,"all six city surface families must use generated normal maps");
 assert.equal(renderStats.roughnessMappedSurfaces,6,"all six city surface families must use generated roughness maps");
 assert.equal(renderStats.texturedBuildingMaterials,4,"residential, commercial, industrial and civic materials must use PBR textures");
 assert.ok(renderStats.backgroundCityBuildings>=70,"the playable district must sit inside a large 3D urban skyline");
 assert.ok(renderStats.backgroundCityWindows>1000,"distant high-rise facades must carry instanced four-sided windows");
 assert.equal(await page.locator("#cityRenderStatus").textContent(),"نمای سه‌بعدی فعال","the UI must report when the actual 3D renderer is ready");
 assert.ok((await page.locator(".cityBrand small").textContent()).includes("۰.۱۵.۴"),"the city UI must expose the deployed version");
 assert.ok(renderStats.decorativeTrees>0,"the locked-world perimeter must include optimized 3D tree scenery");
 assert.equal(renderStats.decorativeTreesOutsideBuildableGrid,renderStats.decorativeTrees,"decorative trees must stay outside every locked and unlocked buildable parcel");
 assert.equal(renderStats.decorativeStreetLights,0,"do not place street furniture in parcels until a dedicated sidewalk/ROW exists");
 assert.equal(renderStats.streetFurniturePlacementReady,true,"the road grid must expose a dedicated non-buildable sidewalk/ROW before street furniture is enabled");
 assert.ok(renderStats.sidewalkStrips>0,"road edges must render instanced pedestrian sidewalks inside the right-of-way");
 assert.equal(renderStats.plots,676,"all 676 non-road cells must be rendered as 3D buildable parcels");
 assert.equal(renderStats.roadTiles,348,"the complete road grid must be rendered in 3D");
 assert.ok(renderStats.raisedCurbs>0,"street grid must retain raised curb geometry");
 assert.equal(renderStats.crosswalkStripes,0,"do not paint pedestrian crossings until pedestrian graph and crossing priority are implemented");
 assert.ok(renderStats.lockedPlots>=1600&&renderStats.visiblePlots>=2300,"the visible world must include a large locked expansion grid, not blank margins");
 assert.equal(renderStats.visibleRoadTiles,1392,"the expanded 64×64 world must have a continuous road network");
 await page.setViewportSize({width:390,height:844});
 await page.waitForFunction(()=>getComputedStyle(document.querySelector("#cityOrientationGate")).display!=="none",undefined,{timeout:5000});
 await page.locator("#cityEnterLandscape").click();
 await page.waitForFunction(()=>window.__mshinCityEntryDebug?.lockRequested===true,undefined,{timeout:5000});
 await page.setViewportSize({width:844,height:390});
 const entryAcceptance=await page.evaluate(()=>({order:window.__cityEntryOrder,debug:window.__mshinCityEntryDebug}));
 assert.deepEqual(entryAcceptance.order,["fullscreen","orientation:landscape"],"mobile city must request fullscreen before locking landscape orientation");
 assert.equal(entryAcceptance.debug.fullscreenGranted,true,"fullscreen must be granted from the first trusted mobile gesture");
 assert.equal(entryAcceptance.debug.lockGranted,true,"landscape orientation lock must be attempted after fullscreen");
 assert.equal(await page.locator("#cityOrientationGate").evaluate(el=>getComputedStyle(el).display),"none","landscape entry must reveal the game world immediately");
 await page.screenshot({path:"artifacts/city-empty-world-landscape.png"});

 assert.ok(renderStats.drawCalls<80,"instanced city ground must stay within a mobile-friendly draw-call budget");

 // The same 3D scene must respond to the deterministic simulation clock.
 await page.evaluate(()=>{window.MshinCityDebug.city.minuteOfDay=0;window.MshinCityDebug.draw()});
 const nightLighting=await page.evaluate(()=>window.MshinCity3DStats.lighting);
 assert.equal(nightLighting.phase,"night","midnight must activate the night lighting state");
 assert.equal(nightLighting.daylight,0,"midnight must have no direct daylight");
 assert.equal(await page.evaluate(()=>window.MshinCity3DStats.celestialBodies),1,"night must display the moon and hide the sun");
 assert.ok(nightLighting.windowGlow>=1,"building windows must illuminate at night");
 assert.equal(await page.evaluate(()=>window.MshinCity3DStats.visibleStars),72,"night scene must render the deterministic star field");
 await page.evaluate(()=>{window.MshinCityDebug.city.minuteOfDay=720;window.MshinCityDebug.draw()});
 const noonLighting=await page.evaluate(()=>window.MshinCity3DStats.lighting);
 assert.equal(noonLighting.phase,"day","midday must activate the daylight state");
 assert.equal(noonLighting.daylight,1,"midday must have full daylight");
 assert.equal(await page.evaluate(()=>window.MshinCity3DStats.celestialBodies),1,"day must display the sun and hide the moon");
 assert.notEqual(nightLighting.skyColor,noonLighting.skyColor,"the visible sky color must change between night and day");
 assert.ok(noonLighting.windowGlow<0.1,"building window glow must be subdued during daytime");
 assert.equal(await page.evaluate(()=>window.MshinCity3DStats.visibleStars),0,"day scene must hide stars");
 // Render a non-persistent asset showcase containing every current city building
 // family, then orbit the same real WebGL scene through a complete 360 degrees.
 const objectShowcase=await page.evaluate(()=>{
  const city=window.MshinCityDebug.city,original=city.buildings,originalZoom=window.MshinCityDebug.view.zoom;
  const types=["home","shop","industrial","administrative","park","police","fire","health","education","power","water","sewage","waste"];
  city.buildings=types.map((type,index)=>({id:9000+index,type,x:12+(index%5)*2,y:11+Math.floor(index/5)*3,level:Math.min(5,1+index%4),residents:type==="home"?12:0}));
  const orbitAngles=[0,Math.PI/2,Math.PI,Math.PI*1.5,Math.PI*2];
  const samples=[];
  for(const orbit of orbitAngles){window.MshinCityDebug.view;window.MshinCityDebug.setCameraOrbit(orbit);window.MshinCityDebug.draw();samples.push(window.MshinCity3DStats.cameraOrbit)}
  const count=window.MshinCity3DStats.stylizedBuildings;
  return{count,samples,originalCount:original.length,originalZoom};
 });
 assert.equal(objectShowcase.count,13,"all 13 authored city object families must render as real 3D scene groups");
 assert.equal(objectShowcase.originalCount,0,"the visual asset showcase must start from an empty city");
 assert.deepEqual(objectShowcase.samples,[0,Math.PI/2,Math.PI,Math.PI*1.5,Math.PI*2],"asset showcase must remain renderable at all four cardinal orbit angles and the 360-degree wrap");
 await page.evaluate(()=>{window.MshinCityDebug.setCameraOrbit(Math.PI/4);window.MshinCityDebug.setCameraZoom(1.5);window.MshinCityDebug.draw()});
 await page.screenshot({path:"artifacts/city-3d-object-showcase-360.png"});
 await page.evaluate(zoom=>{const city=window.MshinCityDebug.city;city.buildings=[];city.population=0;city.citizens=[];window.MshinCityDebug.setCameraOrbit(0);window.MshinCityDebug.setCameraZoom(zoom);window.MshinCityDebug.draw()},objectShowcase.originalZoom);
 await page.evaluate(()=>{window.MshinCityDebug.city.minuteOfDay=495;window.MshinCityDebug.draw()});

 const mapControls=await page.evaluate(()=>({zoom:window.MshinCityDebug.view.zoom,buttons:[...document.querySelectorAll(".cityMapControls button")].map(b=>{const r=b.getBoundingClientRect();return{width:r.width,height:r.height,visible:r.width>0&&r.height>0}})}));
 assert.ok(mapControls.zoom>=.7,"mobile city should open with a useful exploration zoom");assert.equal(mapControls.buttons.length,3);assert.ok(mapControls.buttons.every(b=>b.visible&&b.width>=44&&b.height>=44),"map zoom controls must be visible 44px touch targets");
 await page.locator("#cityZoomIn").click();const zoomedIn=await page.evaluate(()=>window.MshinCityDebug.view.zoom);assert.ok(zoomedIn>mapControls.zoom,"zoom-in control must enlarge the map");
 await page.locator("#cityZoomOut").click();const zoomedOut=await page.evaluate(()=>window.MshinCityDebug.view.zoom);assert.ok(zoomedOut<zoomedIn,"zoom-out control must reduce map scale");
 await page.locator("#cityRecenter").click();assert.ok(Math.abs(await page.evaluate(()=>window.MshinCityDebug.view.zoom)-.72)<.001,"recenter must restore the mobile map scale");
 assert.equal(await page.title(),"شهر من | مِشین");
 const initial=await page.evaluate(()=>({population:window.MshinCityDebug.city.population,buildings:window.MshinCityDebug.city.buildings.length,roads:window.MshinCityDebug.city.grid.flat().filter(t=>t==="road").length,citizens:window.MshinCityDebug.city.citizens.length,traffic:window.MshinCityDebug.city.traffic.length,animals:window.MshinCityDebug.city.animals.length,width:document.querySelector("#cityViewport").width}));
 const windowTrafficInvariant=await page.evaluate(()=>window.MshinCityDebug.city.traffic.every(vehicle=>Number.isFinite(vehicle.x)&&Number.isFinite(vehicle.y)&&window.MshinCityDebug.city.grid[Math.round(vehicle.y)]?.[Math.round(vehicle.x)]==="road"));
 assert.equal(initial.population,0,"new city must start without residents");assert.equal(initial.buildings,0,"new city must contain no buildings");assert.ok(initial.roads>=300,"the whole map must be subdivided by a complete road grid");assert.equal(initial.citizens,0);assert.ok(initial.traffic<=12,"live simulation traffic must stay within its bounded fleet");assert.ok(windowTrafficInvariant,"traffic must remain on valid road tiles");assert.equal(initial.animals,0);assert.ok(initial.width>=320,"city canvas must use the available phone display width: "+JSON.stringify(initial));
 const rebuildsBeforePlacement=await page.evaluate(()=>window.MshinCity3DStats.buildingRebuilds);
 await clickCityTool(page,"park");const target=await page.evaluate(()=>window.MshinCityDebug.screenForTile(14,14));await page.mouse.click(target.x,target.y);
 assert.equal(await page.evaluate(()=>window.MshinCityDebug.city.grid[14][14]),"building","park tool should place a city asset");
 const parkVisual=await page.evaluate(()=>window.MshinCity3DStats);
 assert.equal(parkVisual.stylizedBuildings,1,"placed park must become a rendered 3D scene object");
 assert.equal(parkVisual.shadowAutoUpdate,false,"static city shadows must not be regenerated every mobile frame");
 assert.equal(parkVisual.buildingRebuilds,rebuildsBeforePlacement+1,"a structural building change should rebuild the 3D building layer exactly once");
 await page.waitForTimeout(150);
 assert.equal(await page.evaluate(()=>window.MshinCity3DStats.buildingRebuilds),rebuildsBeforePlacement+1,"unchanged buildings must not be recreated during subsequent render frames");
 await page.locator("#citySave").click();assert.ok(await page.evaluate(()=>JSON.parse(localStorage.getItem("mshin-city-save-v2"))?.buildings?.some(b=>b.x===14&&b.y===14)),"city changes should persist");
 await clickCityTool(page,"select");
 const zoomBefore=await page.evaluate(()=>window.MshinCityDebug.view.zoom),orbitBefore=await page.evaluate(()=>window.MshinCityDebug.view.orbit),focusAnchorBefore=await page.evaluate(()=>window.MshinCityDebug.groundPointAt(190,220));
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",91,120,220);send("pointerdown",92,260,220);send("pointermove",92,320,220);send("pointerup",92,320,220);send("pointerup",91,120,220)});
 const zoomAfter=await page.evaluate(()=>window.MshinCityDebug.view.zoom),orbitAfter=await page.evaluate(()=>window.MshinCityDebug.view.orbit);assert.ok(zoomAfter>zoomBefore,"two-finger pinch must zoom the city map");assert.notEqual(orbitAfter,orbitBefore,"two-finger horizontal drag must orbit the 3D camera around the buildings");
 const focusAnchorAfter=await page.evaluate(()=>window.MshinCityDebug.groundPointAt(220,220));
 assert.ok(focusAnchorBefore&&focusAnchorAfter,"browser acceptance must obtain real Three.js ground-raycast anchors");
 assert.ok(Math.hypot(focusAnchorBefore.x-focusAnchorAfter.x,focusAnchorBefore.z-focusAnchorAfter.z)<0.08,"pinch/orbit world anchor drifted: "+JSON.stringify({before:focusAnchorBefore,after:focusAnchorAfter,drift:Math.hypot(focusAnchorBefore.x-focusAnchorAfter.x,focusAnchorBefore.z-focusAnchorAfter.z)}));

 const translationZoomBefore=await page.evaluate(()=>window.MshinCityDebug.view.zoom);
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",701,100,220);send("pointerdown",702,200,220);send("pointermove",701,200,220);send("pointermove",702,300,220);send("pointerup",701,200,220);send("pointerup",702,300,220)});
 const translationZoomAfter=await page.evaluate(()=>window.MshinCityDebug.view.zoom);
 assert.ok(Math.abs(translationZoomAfter-translationZoomBefore)<0.0001,"equal two-finger translation must rotate the view without changing zoom");

 const pureRotationZoomBefore=await page.evaluate(()=>window.MshinCityDebug.view.zoom);
 const pureRotationOrbitBefore=await page.evaluate(()=>window.MshinCityDebug.view.orbit);
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",711,150,180);send("pointerdown",712,250,180);send("pointermove",711,200,130);send("pointermove",712,200,230);send("pointerup",711,200,130);send("pointerup",712,200,230)});
 assert.ok(Math.abs((await page.evaluate(()=>window.MshinCityDebug.view.zoom))-pureRotationZoomBefore)<0.0001,"pure two-finger twist must not change zoom");
 assert.ok(Math.abs((await page.evaluate(()=>window.MshinCityDebug.view.orbit))-pureRotationOrbitBefore)>0.1,"twisting the two-finger line must rotate the camera around the focus");
 const pitchBefore=await page.evaluate(()=>window.MshinCityDebug.view.pitch);
 const tiltZoomBefore=await page.evaluate(()=>window.MshinCityDebug.view.zoom);
 const tiltOrbitBefore=await page.evaluate(()=>window.MshinCityDebug.view.orbit);
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",721,140,180);send("pointerdown",722,260,180);send("pointermove",721,140,260);send("pointermove",722,260,260);send("pointerup",722,260,260);send("pointerup",721,140,260)});
 const pitchAfter=await page.evaluate(()=>window.MshinCityDebug.view.pitch);
 assert.ok(pitchAfter<pitchBefore,"vertical two-finger movement must tilt the camera toward the city");
 assert.ok(Math.abs((await page.evaluate(()=>window.MshinCityDebug.view.zoom))-tiltZoomBefore)<0.0001,"vertical camera tilt must not alter pinch zoom");
 assert.ok(Math.abs((await page.evaluate(()=>window.MshinCityDebug.view.orbit))-tiltOrbitBefore)<0.0001,"vertical camera tilt must not alter horizontal orbit");


 const orbitStart=await page.evaluate(()=>window.MshinCityDebug.view.orbit);
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));for(let i=0;i<9;i++){const a=100+i*3,b=200+i*3;send("pointerdown",200+i*2,a,220);send("pointerdown",201+i*2,b,220);send("pointermove",200+i*2,a+100,220);send("pointermove",201+i*2,b+100,220);send("pointerup",200+i*2,a+100,220);send("pointerup",201+i*2,b+100,220)}});
 const fullTurnOrbit=await page.evaluate(()=>window.MshinCityDebug.view.orbit);
 assert.ok(fullTurnOrbit>orbitStart+Math.PI*2,"repeated two-finger horizontal gestures must cross 360 degrees without wrapping or jumping");
 const inertiaReleaseBefore=await page.evaluate(()=>window.MshinCityDebug.view.orbit);
 const releaseSnapshot=await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",450,100,220);send("pointerdown",451,200,220);send("pointermove",450,130,220);send("pointermove",451,230,220);send("pointerup",450,130,220);send("pointerup",451,230,220);const state=window.MshinCityDebug.view;return{gesture:state.gesture,orbit:state.orbit}});
 const inertiaStateAtRelease=releaseSnapshot.gesture;
 const orbitAtRelease=releaseSnapshot.orbit;
 assert.ok(inertiaStateAtRelease.inertiaActive,"lifting the last finger must start inertial motion");
 await page.waitForFunction(start=>window.MshinCityDebug.view.orbit>start,orbitAtRelease,{polling:50,timeout:2000});
 const orbitAfterRelease=await page.evaluate(()=>window.MshinCityDebug.view.orbit);
 const inertiaStateAfter=await page.evaluate(()=>window.MshinCityDebug.view.gesture);
 assert.ok(orbitAfterRelease>orbitAtRelease,"camera orbit must retain a short, damped inertial glide after fingers lift: "+JSON.stringify({inertiaStateAtRelease,inertiaStateAfter,orbitAtRelease,orbitAfterRelease}));
 await page.waitForFunction(()=>window.MshinCityDebug.view.gesture.inertiaActive===false,undefined,{polling:50,timeout:2500});
 const settledState=await page.evaluate(()=>window.MshinCityDebug.view.gesture);
 assert.equal(settledState.inertiaActive,false,"damped orbit inertia must reach its terminal state");
 const settledOrbit=await page.evaluate(()=>window.MshinCityDebug.view.orbit);
 await page.waitForTimeout(150);
 assert.ok(Math.abs((await page.evaluate(()=>window.MshinCityDebug.view.orbit))-settledOrbit)<0.01,"camera inertia must decay to a stable stop");

 const pinchStart=await page.evaluate(()=>window.MshinCityDebug.view.zoom);
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",501,120,220);send("pointerdown",502,280,220);send("pointermove",502,180,220);send("pointerup",502,180,220);send("pointerup",501,120,220)});
 const pinchOut=await page.evaluate(()=>window.MshinCityDebug.view.zoom);
 assert.ok(pinchOut<pinchStart,"bringing two fingers together must zoom out");
 const transitionBefore=await page.evaluate(()=>window.MshinCityDebug.view);
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",551,100,220);send("pointerdown",552,200,220);send("pointerup",552,200,220);send("pointerup",551,100,220);send("pointerdown",553,100,220);send("pointerdown",554,200,220);send("pointercancel",554,200,220);send("pointerup",553,100,220)});
 const transitionAfter=await page.evaluate(()=>window.MshinCityDebug.view);
 assert.equal(transitionAfter.zoom,transitionBefore.zoom,"pointer-count transitions and cancellation must not alter zoom");
 assert.equal(transitionAfter.orbit,transitionBefore.orbit,"pointer-count transitions and cancellation must not jump orbit");

 // A two-to-one transition must rebase to a stationary pan without carrying stale orbit inertia.
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",561,100,220);send("pointerdown",562,220,220);send("pointermove",562,260,220);send("pointerup",562,260,220);send("pointermove",561,104,220);send("pointerup",561,104,220)});
 const rebasedGesture=await page.evaluate(()=>window.MshinCityDebug.view.gesture);
 assert.equal(rebasedGesture.inertiaActive,false,"continuing with one finger must not inherit the previous two-finger fling");

 // Sustained combined input must remain finite and within zoom bounds, without accumulating pointer drift.
 const sustainedStart=await page.evaluate(()=>({orbit:window.MshinCityDebug.view.orbit,zoom:window.MshinCityDebug.view.zoom}));
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",571,160,220);send("pointerdown",572,280,220);for(let i=0;i<120;i++){const offset=i%2?1:-1;send("pointermove",571,160+i*0.7,220+offset);send("pointermove",572,280+i*0.7,220-offset)}send("pointerup",572,364,419);send("pointerup",571,244,421)});
 const sustainedEnd=await page.evaluate(()=>({orbit:window.MshinCityDebug.view.orbit,zoom:window.MshinCityDebug.view.zoom,gesture:window.MshinCityDebug.view.gesture}));
 assert.ok(Number.isFinite(sustainedEnd.orbit)&&Math.abs(sustainedEnd.orbit-sustainedStart.orbit)>0.5,"long-running orbit must remain finite and responsive");
 assert.ok(sustainedEnd.zoom>=0.05&&sustainedEnd.zoom<=1.5,"long-running pinch must remain inside camera zoom limits");
 await page.waitForTimeout(1220);
 assert.equal((await page.evaluate(()=>window.MshinCityDebug.view.gesture.inertiaActive)),false,"long gesture inertia must settle instead of drifting indefinitely");
 const focusTile=await page.evaluate(()=>window.MshinCityDebug.screenForTile(14,14));
 await page.evaluate(({x,y})=>{const c=document.querySelector("#cityViewport"),event=type=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:601,pointerType:"touch",clientX:x,clientY:y}));event("pointerdown");event("pointerup")},focusTile);
 const focusedCamera=await page.evaluate(()=>window.MshinCityDebug.view);
 const selectedBuildingTile=await page.evaluate(()=>window.MshinCityDebug.selected);
 assert.deepEqual(selectedBuildingTile,{x:14,y:14},"tapping a building must retain normal building selection while focusing the camera");
 assert.ok(Number.isFinite(focusedCamera.targetX)&&Number.isFinite(focusedCamera.targetY)&&Number.isFinite(focusedCamera.targetZ),"tapping a building must set a full 3D raycast-derived camera focus target");
 await page.waitForTimeout(450);
 assert.equal(await page.evaluate(()=>window.MshinCityDebug.city.buildings.length),1,"camera gestures and focus must not mutate city construction data");
 fs.mkdirSync("artifacts",{recursive:true});
 fs.writeFileSync("artifacts/city-camera-focus-state.json",JSON.stringify({camera:focusedCamera,selectedBuilding:selectedBuildingTile,viewport:await page.evaluate(()=>({width:innerWidth,height:innerHeight}))},null,2));
 await page.locator("#cityRecenter").dispatchEvent("click");
 const recenteredCamera=await page.evaluate(()=>window.MshinCityDebug.view);
 assert.equal(recenteredCamera.targetX,null,"recenter must clear the previous world-space X focus");
 assert.equal(recenteredCamera.targetY,null,"recenter must clear the previous 3D height focus");
 assert.equal(recenteredCamera.targetZ,null,"recenter must clear the previous world-space Z focus");
 assert.equal(recenteredCamera.orbit,0,"recenter must restore the initial city-facing orbit");


 await clickCityTool(page,"zone-residential");const zoneTarget=await page.evaluate(()=>window.MshinCityDebug.screenForTile(17,14));await page.mouse.click(zoneTarget.x,zoneTarget.y);
 assert.equal(await page.evaluate(()=>window.MshinCityDebug.city.grid[14][17]),"zone-residential","mobile players must be able to zone a road-connected tile");
 await page.evaluate(()=>{for(let i=0;i<12;i++)window.MshinCityDebug.step()});
 assert.ok(await page.evaluate(()=>window.MshinCityDebug.city.buildings.some(b=>b.x===17&&b.y===14&&b.type==="home")),"residential zoning must grow into a home when demand exists");
 await page.waitForFunction(()=>window.MshinCity3DStats?.stylizedBuildings>=2,undefined,{timeout:5000});
 assert.ok(await page.evaluate(()=>window.MshinCity3DStats.stylizedBuildings>=2),"new residential buildings must be rendered with the 3D building family system");
 try{await page.waitForFunction(()=>window.MshinCity3DStats?.pedestrians===window.MshinCityDebug.city.citizens.length&&window.MshinCity3DStats.pedestrians>0,undefined,{timeout:5000})}catch(error){const diagnostic=await page.evaluate(()=>({population:window.MshinCityDebug.city.population,citizens:window.MshinCityDebug.city.citizens,buildings:window.MshinCityDebug.city.buildings,renderer:window.MshinCity3DStats,cityReady:document.documentElement.dataset.cityReady}));throw new Error("pedestrian render did not synchronize with city simulation: "+JSON.stringify(diagnostic)+"; "+error.message)}
 const pedestrianAcceptance=await page.evaluate(()=>({
  population:window.MshinCityDebug.city.population,
  agents:window.MshinCityDebug.city.citizens.length,
  rendered:window.MshinCity3DStats.pedestrians,
  onRoad:window.MshinCityDebug.city.citizens.every(c=>window.MshinCityDebug.city.grid[c.roadY]?.[c.roadX]==="road"),
  drawCalls:window.MshinCity3DStats.drawCalls
 }));
 assert.ok(pedestrianAcceptance.population>=12&&pedestrianAcceptance.agents>0,"residential population must produce visible pedestrian agents");
 assert.equal(pedestrianAcceptance.rendered,pedestrianAcceptance.agents,"every active citizen agent must be rendered in the 3D city");
 assert.equal(pedestrianAcceptance.onRoad,true,"pedestrian route nodes must remain on connected road tiles");
 assert.ok(pedestrianAcceptance.drawCalls<80,"instanced pedestrians must preserve the mobile draw-call budget");
 for(const [type,x,y] of [["power",18,17],["water",14,17],["police",18,14]]){await clickCityTool(page,type);const point=await page.evaluate(({x,y})=>window.MshinCityDebug.screenForTile(x,y),{x,y});const projected=await page.evaluate(({x,y})=>window.MshinCityDebug.tileAtScreen(x,y),point);assert.deepEqual(projected,{x,y},type+" screen projection must round-trip to the same city tile");await page.mouse.click(point.x,point.y);const diagnostic=await page.evaluate(({x,y,type})=>({placed:window.MshinCityDebug.city.buildings.some(b=>b.x===x&&b.y===y&&b.type===type),tool:window.MshinCityDebug.activeTool,selected:window.MshinCityDebug.selected,toast:document.querySelector("#cityToast")?.textContent,treasury:window.MshinCityDebug.city.treasury,cell:window.MshinCityDebug.city.grid[y]?.[x]}),{x,y,type});assert.ok(diagnostic.placed,type+" infrastructure/service should be constructible on mobile: "+JSON.stringify(diagnostic))}
 await page.evaluate(()=>window.MshinCityDebug.step());
 const serviceStats=await page.evaluate(()=>window.MshinCityDebug.city.stats);
 assert.ok(serviceStats.utilityCoverage>0&&serviceStats.publicServiceCoverage>0&&serviceStats.overallCoverage>0,"utility and public service coverage must update the city simulation");
 const secondHome=await page.evaluate(()=>window.MshinCityDebug.place(17,13,"home"));assert.equal(secondHome.ok,true,"a second road-accessible home should be constructible");
 await page.locator("#cityBudget").click();
 assert.equal(await page.locator("#cityBudgetPanel").isVisible(),true,"mobile players must be able to open the budget panel");
 const budgetLayout=await page.evaluate(()=>{
  const panel=document.querySelector("#cityBudgetPanel"),r=panel.getBoundingClientRect();
  return{display:getComputedStyle(panel).display,left:r.left,top:r.top,right:r.right,bottom:r.bottom,width:innerWidth,height:innerHeight,
   sliders:[...panel.querySelectorAll('input[type="range"]')].map(el=>({width:el.getBoundingClientRect().width,height:el.getBoundingClientRect().height}))};
 });
 assert.equal(budgetLayout.display,"grid","budget controls must open as a styled dialog");
 assert.ok(budgetLayout.left>=0&&budgetLayout.top>=0&&budgetLayout.right<=budgetLayout.width&&budgetLayout.bottom<=budgetLayout.height,"budget dialog must fit inside the landscape mobile viewport");
 assert.equal(budgetLayout.sliders.length,3,"all three tax sectors must be adjustable");
 assert.ok(budgetLayout.sliders.every(slider=>slider.width>=140&&slider.height>=38),"tax sliders must remain usable touch targets on landscape phones: "+JSON.stringify(budgetLayout));
 const baselineTax=await page.evaluate(()=>window.MshinCityDebug.economy.taxRevenue);
 const budgetControls=await page.evaluate(()=>[...document.querySelectorAll(".cityTaxControl input")].map(input=>{const r=input.getBoundingClientRect();return{width:r.width,height:r.height,value:input.value}}));
 assert.equal(budgetControls.length,3,"budget must expose residential, commercial and industrial tax controls");
 assert.ok(budgetControls.every(control=>control.width>120&&control.height>=40),"tax sliders must remain touch-friendly on mobile landscape");
 await page.locator("#cityTaxResidential").evaluate(input=>{input.value="14";input.dispatchEvent(new Event("input",{bubbles:true}))});
 const taxAcceptance=await page.evaluate(()=>({rates:window.MshinCityDebug.city.taxRates,saved:JSON.parse(localStorage.getItem("mshin-city-save-v2"))?.taxRates,economy:window.MshinCityDebug.economy}));
 assert.equal(taxAcceptance.rates.residential,14,"residential tax slider must update simulation policy");
 assert.equal(taxAcceptance.saved.residential,14,"tax policy must persist immediately");
 assert.ok(taxAcceptance.economy.taxRevenue>0,"budget must calculate tax revenue from occupied sectors");
 await page.evaluate(()=>window.MshinCityDebug.step());
 const adjustedTax=await page.evaluate(()=>window.MshinCityDebug.city.stats.taxRevenue);
 assert.ok(adjustedTax>baselineTax,"raising residential tax must increase live tax revenue");
 assert.ok(await page.evaluate(()=>window.MshinCityDebug.city.stats.net!==undefined),"city simulation must publish a net budget balance");
 await page.locator("#cityBudgetDone").click();
 assert.equal(await page.locator("#cityBudgetPanel").isVisible(),false,"budget panel must close without blocking city controls");
 assert.equal(await page.evaluate(()=>document.activeElement.id),"cityBudget","closing the budget dialog must restore focus to its trigger");
 await page.locator("#cityBudget").click();
 await page.keyboard.press("Escape");
 assert.equal(await page.locator("#cityBudgetPanel").isVisible(),false,"Escape must close the budget dialog on mobile browsers");
 assert.equal(await page.evaluate(()=>document.activeElement.id),"cityBudget","Escape dismissal must restore focus to the budget trigger");
 await page.locator("#cityBackup").click();
 assert.equal(await page.locator("#cityStoragePanel").isVisible(),true,"mobile players must be able to open save and backup management");
 const downloadPromise=page.waitForEvent("download");
 await page.locator("#cityExportBackup").click();
 const backupDownload=await downloadPromise;
 assert.match(backupDownload.suggestedFilename(),/^mshin-city-\d{4}-\d{2}-\d{2}\.json$/,"city backup must download as a dated JSON file");
 const backupPath=await backupDownload.path();
 const backupPayload=JSON.parse(fs.readFileSync(backupPath,"utf8"));
 assert.equal(backupPayload.format,"mshin-city-save","export must use the portable city backup envelope");
 assert.equal(backupPayload.city.schemaVersion,2,"export must contain the current validated city schema");
 assert.equal(backupPayload.city.taxRates.residential,14,"backup must include the current tax policy");
 const backupTreasury=backupPayload.city.treasury,backupName=backupPayload.city.name;
 await page.evaluate(()=>{window.MshinCityDebug.city.name="TEMPORARY-UNRESTORED-CITY";window.MshinCityDebug.save()});
 const migrationCheck=await page.evaluate(async payload=>{
  const {migrateCitySave,isValidCitySave}=await import("/src/city/city-save.js");
  const restored=migrateCitySave(payload);
  return{valid:Boolean(restored&&isValidCitySave(restored)),treasury:restored?.treasury,version:payload.version,exportedAt:payload.exportedAt};
 },backupPayload);
 assert.equal(migrationCheck.valid,true,"exported backup must validate before UI import: "+JSON.stringify(migrationCheck));
 let importDialogSeen=false;
 page.once("dialog",dialog=>{importDialogSeen=true;dialog.accept()});
 const chooserPromise=page.waitForEvent("filechooser");
 await page.locator("#cityImportBackup").click();
 const chooser=await chooserPromise;
 await chooser.setFiles({name:"mshin-city-restore.json",mimeType:"application/json",buffer:Buffer.from(JSON.stringify(backupPayload))});
 await page.waitForFunction(expected=>window.MshinCityDebug.city.name===expected||document.querySelector("#cityToast").textContent.startsWith("بازیابی انجام نشد:"),backupName,{timeout:10000});
 const importResult=await page.evaluate(()=>({name:window.MshinCityDebug.city.name,treasury:window.MshinCityDebug.city.treasury,taxRates:window.MshinCityDebug.city.taxRates,panelHidden:document.querySelector("#cityStoragePanel").classList.contains("hidden"),toast:document.querySelector("#cityToast").textContent}));
 assert.equal(importDialogSeen,true,"backup replacement must require and display confirmation");
 assert.equal(importResult.name,backupName,"backup import must restore the saved city name: "+importResult.toast);
 assert.ok(importResult.treasury>0&&importResult.taxRates.residential===14,"backup import must restore treasury and tax policy");
 assert.equal(importResult.panelHidden,true,"successful restore must close the storage dialog");
 assert.equal(await page.evaluate(()=>document.activeElement.id),"cityBackup","closing storage must restore focus to its trigger");
 const demolition=await page.evaluate(()=>{const b=window.MshinCityDebug.city.buildings.find(v=>v.type==="home"&&!(v.x===17&&v.y===14));if(!b)throw new Error("test fixture needs a second residential building");return window.MshinCityDebug.actAt(b.x,b.y,"bulldoze")});
 assert.equal(demolition.cell,"grass","bulldoze action must remove the selected residential building");assert.equal(demolition.saved.grid.flat().filter(v=>v==="building").length,await page.evaluate(()=>window.MshinCityDebug.city.buildings.length),"demolition must persist immediately");
 await page.evaluate(()=>{for(let i=0;i<6;i++)window.MshinCityDebug.step()});await page.waitForTimeout(100);
 assert.ok(await page.evaluate(()=>JSON.parse(localStorage.getItem("mshin-city-save-v2"))?.tick>=6),"simulation must autosave without a manual save");
 await page.bringToFront();await page.locator('[data-city-speed="1"]').click();await page.waitForFunction(()=>document.visibilityState==="visible");const before=await page.evaluate(()=>window.MshinCityDebug.city.tick);await page.waitForTimeout(4000);const simulation=await page.evaluate(()=>({tick:window.MshinCityDebug.city.tick,visibility:document.visibilityState,speedLabel:document.querySelector("#citySpeedLabel")?.textContent}));assert.ok(simulation.tick>before,"simulation should advance while the mobile city is visible at 1x speed: "+JSON.stringify({before,...simulation}));
 const drawCallsBeforeTraffic=await page.evaluate(()=>window.MshinCity3DStats.drawCalls);
 await page.waitForFunction(()=>window.MshinCity3DStats?.trafficVehicles>0,undefined,{timeout:8000});
 const trafficAcceptance=await page.evaluate(()=>{
  const city=window.MshinCityDebug.city;
  return {
   vehicles:city.traffic.length,
   rendered:window.MshinCity3DStats.trafficVehicles,
   onRoad:city.traffic.every(vehicle=>city.grid[Math.round(vehicle.y)]?.[Math.round(vehicle.x)]==="road"),
   moving:city.traffic.some(vehicle=>(vehicle.routeStep||0)>0||Math.abs(vehicle.x-Math.round(vehicle.x))>.05||Math.abs(vehicle.y-Math.round(vehicle.y))>.05),
   drawCalls:window.MshinCity3DStats.drawCalls
  };
 });
 assert.ok(trafficAcceptance.vehicles>0,"the live city simulation must spawn road traffic");
 assert.equal(trafficAcceptance.rendered,trafficAcceptance.vehicles,"every active vehicle must be rendered by the 3D city renderer");
 assert.equal(trafficAcceptance.onRoad,true,"mobile traffic must stay on connected road tiles");
 assert.equal(trafficAcceptance.moving,true,"vehicles must progress along their road routes rather than remain static");
 assert.ok(trafficAcceptance.drawCalls<=drawCallsBeforeTraffic+2,"instanced traffic must add at most two draw calls regardless of the active vehicle count: "+JSON.stringify({before:drawCallsBeforeTraffic,after:trafficAcceptance.drawCalls,vehicles:trafficAcceptance.vehicles}));
 assert.ok(await page.evaluate(()=>window.MshinCityDebug.save()),"traffic state must remain persistable with the city save");
 const mobile=await page.evaluate(()=>{const rect=s=>{const r=document.querySelector(s).getBoundingClientRect();return{x:r.x,y:r.y,width:r.width,height:r.height,right:r.right,bottom:r.bottom}};return{viewport:{width:innerWidth,height:innerHeight},documentWidth:document.documentElement.scrollWidth,brand:rect(".cityBrand"),metrics:rect(".cityMetrics"),tools:rect(".cityTools"),bottom:rect(".cityBottom"),categoryButtons:[...document.querySelectorAll(".cityToolCategory")].map(b=>{const r=b.getBoundingClientRect();return{width:r.width,height:r.height}}),viewportMeta:document.querySelector('meta[name="viewport"]').content}});
 assert.equal(mobile.documentWidth,mobile.viewport.width,"mobile city must not create horizontal page overflow");
 assert.ok(mobile.tools.y>mobile.metrics.bottom,"mobile construction dock must sit below the city metrics");
 assert.ok(mobile.tools.bottom<=mobile.bottom.y+1,"mobile tool dock must not overlap the bottom status bar");
 assert.ok(mobile.categoryButtons.length===4&&mobile.categoryButtons.every(b=>b.width>=40&&b.height>=44),"all four mobile category controls must remain at least 40×44 CSS pixels");await page.locator('[data-city-category="roads"]').click();const openToolTargets=await page.locator('[data-city-panel="roads"] .cityTool').evaluateAll(items=>items.map(b=>{const r=b.getBoundingClientRect();return{width:r.width,height:r.height}}));assert.ok(openToolTargets.length===6&&openToolTargets.every(b=>b.width>=40&&b.height>=44),"every revealed construction tool must remain a usable mobile touch target");await page.locator('[data-city-category="roads"]').click();
 assert.ok(!/user-scalable=no|maximum-scale=1/.test(mobile.viewportMeta),"mobile browser zoom must remain enabled");
 await page.screenshot({path:"artifacts/city-mobile-landscape-844x390.png"});
 const compactPage=await browser.newPage({viewport:{width:360,height:640},screen:{width:360,height:640},deviceScaleFactor:1,isMobile:true,hasTouch:true});
 try{
  const compactErrors=[];
  compactPage.on("pageerror",error=>compactErrors.push(error.stack||String(error)));
  compactPage.on("console",message=>{if(message.type()==="error")compactErrors.push("console: "+message.text())});
  compactPage.on("requestfailed",request=>compactErrors.push("request failed: "+request.url()+" "+request.failure()?.errorText));
  await compactPage.goto("http://127.0.0.1:4173/city.html");
  try{
   await compactPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:60000});
  }catch(error){
   const diagnostic=await compactPage.evaluate(()=>({ready:document.documentElement.dataset.cityReady,rendererReady:window.MshinCity3DReady===true,rendererError:window.MshinCity3DError||null,status:document.querySelector("#cityRenderStatus")?.textContent,webgl:typeof WebGLRenderingContext,canvasCount:document.querySelectorAll("canvas").length}));
   // A late Playwright poll can time out after the renderer has become ready;
   // trust the immediate diagnostic only when both readiness flags and a canvas exist.
   if(!(diagnostic.ready==="true"&&diagnostic.rendererReady===true&&diagnostic.canvasCount>0)){
    throw new Error("compact portrait 3D renderer did not become ready: "+JSON.stringify({diagnostic,errors:compactErrors})+"; "+error.message);
   }
  }
  const compact=await compactPage.evaluate(()=>({width:document.documentElement.scrollWidth,viewport:innerWidth,gate:getComputedStyle(document.querySelector("#cityOrientationGate")).display,tools:document.querySelector(".cityTools").getBoundingClientRect().toJSON(),bottom:document.querySelector(".cityBottom").getBoundingClientRect().toJSON()}));
  assert.equal(compact.gate,"grid","portrait phones must be stopped at the landscape orientation gate");
  assert.equal(compact.width,compact.viewport,"compact phone layout must not overflow horizontally");
  assert.ok(compact.tools.bottom<=compact.bottom.y+1,"compact phone controls must remain separated");
  fs.mkdirSync("artifacts",{recursive:true});
  await compactPage.screenshot({path:"artifacts/city-portrait-orientation-gate.png",fullPage:true});
  const orientationShim=await compactPage.evaluate(()=>({lockType:typeof screen.orientation?.lock,orientationType:screen.orientation?.type,handlerType:typeof window.__mshinEnterCityLandscape,onclickType:typeof document.querySelector("#cityEnterLandscape")?.onclick,pointerHandler:document.querySelector("#cityEnterLandscape")?.getAttribute("onpointerdown"),buttonVisible:(()=>{const r=document.querySelector("#cityEnterLandscape").getBoundingClientRect();return r.width>0&&r.height>0})()}));
  assert.equal(orientationShim.lockType,"function","orientation shim missing: "+JSON.stringify(orientationShim));assert.equal(orientationShim.handlerType,"function","landscape entry handler missing: "+JSON.stringify(orientationShim));assert.equal(orientationShim.onclickType,"function","landscape button onclick missing: "+JSON.stringify(orientationShim));
  await compactPage.locator("#cityEnterLandscape").click();
  try{await compactPage.waitForFunction(()=>window.__mshinCityEntryDebug?.lockRequested===true,undefined,{timeout:5000})}catch(error){const diagnostic=await compactPage.evaluate(()=>({entryDebug:window.__mshinCityEntryDebug,lockType:typeof screen.orientation?.lock,orientationType:screen.orientation?.type,gate:getComputedStyle(document.querySelector("#cityOrientationGate")).display}));throw new Error("orientation lock was not requested: "+JSON.stringify(diagnostic)+"; "+error.message)}
  assert.equal(await compactPage.evaluate(()=>window.__mshinCityEntryDebug.fullscreenRequested),true,"city entry must request fullscreen from the button gesture");
  assert.equal(await compactPage.locator("#cityOrientationGate").evaluate(el=>getComputedStyle(el).display),"grid","portrait gate must remain visible when the browser cannot rotate the device");
 }finally{await compactPage.close()}
 // Chromium can reject Browser.setWindowBounds after fullscreen/orientation APIs
 // have been exercised. Verify landscape in a fresh page with its final viewport.
 // Isolate CSS landscape layout from the browser-specific mobile screen-orientation emulation.
 // Reuse the warmed mobile context so the second page shares the cached
 // Three.js module rather than requiring another external CDN transfer.
 const landscapePage=await cameraContext.newPage();
 await landscapePage.setViewportSize({width:844,height:390});
 const landscapeErrors=[];
 landscapePage.on("pageerror",error=>landscapeErrors.push(error.stack||String(error)));
 landscapePage.on("console",message=>{if(message.type()==="error")landscapeErrors.push("console: "+message.text())});
 landscapePage.on("requestfailed",request=>landscapeErrors.push("request failed: "+request.url()+" "+request.failure()?.errorText));
 try{
  await landscapePage.goto("http://127.0.0.1:4173/city.html",{waitUntil:"domcontentloaded"});
  try{
   await landscapePage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:30000});
  }catch(error){
   const diagnostic=await landscapePage.evaluate(()=>({ready:document.documentElement.dataset.cityReady,rendererReady:window.MshinCity3DReady===true,rendererError:window.MshinCity3DError||null,status:document.querySelector("#cityRenderStatus")?.textContent,webgl:typeof WebGLRenderingContext,canvasCount:document.querySelectorAll("canvas").length}));
   throw new Error("landscape 3D renderer did not become ready: "+JSON.stringify({diagnostic,errors:landscapeErrors})+"; "+error.message);
  }
  try{await landscapePage.waitForFunction(()=>getComputedStyle(document.querySelector("#cityOrientationGate")).display==="none",undefined,{timeout:5000})}catch(error){const diagnostic=await landscapePage.evaluate(()=>({innerWidth,innerHeight,screenWidth:screen.width,screenHeight:screen.height,mediaLandscape:matchMedia("(orientation: landscape)").matches,mediaPortrait:matchMedia("(orientation: portrait)").matches,orientation:screen.orientation?.type,gateClass:document.querySelector("#cityOrientationGate")?.className,gateHidden:document.querySelector("#cityOrientationGate")?.hidden,gateDisplay:getComputedStyle(document.querySelector("#cityOrientationGate")).display,cityOrientation:document.documentElement.dataset.cityOrientation}));throw new Error("landscape orientation gate did not close: "+JSON.stringify(diagnostic)+"; "+error.message)}
  const landscape=await landscapePage.evaluate(()=>({width:document.documentElement.scrollWidth,viewport:innerWidth,height:innerHeight,gate:getComputedStyle(document.querySelector("#cityOrientationGate")).display}));
  assert.equal(landscape.gate,"none","landscape page must show the city rather than the portrait gate");
  assert.equal(landscape.width,landscape.viewport,"landscape city must not overflow horizontally");
  fs.mkdirSync("artifacts",{recursive:true});
  await landscapePage.screenshot({path:"artifacts/city-vertical-slice.png",fullPage:true});
  await landscapePage.evaluate(()=>localStorage.setItem("mshin-city-save-v2",JSON.stringify({schemaVersion:2,cityId:"corrupt",name:"broken",seed:1,tick:0,treasury:0,population:0,grid:[[]]})));
  await landscapePage.reload({waitUntil:"domcontentloaded"});
  await landscapePage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:30000});
  const recovery=await landscapePage.evaluate(()=>({
    gridRows:window.MshinCityDebug.city.grid.length,
    gridColumns:window.MshinCityDebug.city.grid.every(row=>row.length===32),
    buildings:window.MshinCityDebug.city.buildings.length,
    zones:window.MshinCityDebug.city.zones.length,
    traffic:window.MshinCityDebug.city.traffic.length,
    saved:window.MshinCityDebug.save()
  }));
  assert.equal(recovery.gridRows,32,"malformed local saves must recover to a complete city grid");
  assert.equal(recovery.gridColumns,true,"save recovery must restore all 32 columns");
  assert.equal(recovery.buildings,0,"malformed save recovery must not retain invalid building records");
  assert.equal(recovery.zones,0,"malformed save recovery must not retain invalid zones");
  assert.equal(recovery.traffic,0,"malformed save recovery must not retain invalid traffic");
 }finally{await landscapePage.close()}
 const legacyGrid=Array.from({length:32},()=>Array(32).fill("grass"));
 for(let y=0;y<32;y++)for(let x=0;x<32;x++)if([7,15,23].includes(x)||[7,15,23].includes(y))legacyGrid[y][x]="road";
 for(let y=0;y<5;y++)for(let x=26;x<31;x++)legacyGrid[y][x]="water";
 legacyGrid[14][17]="building";
 const legacyFixture={schemaVersion:1,cityId:"legacy-city-01",name:"شهر قدیمی",seed:20261102,tick:42,minuteOfDay:815,treasury:12345,population:12,happiness:76,grid:legacyGrid,buildings:[{id:1,type:"home",x:17,y:14,level:1,age:4,residents:12}],trees:[{x:10,y:10,size:1.2}],citizens:[{id:1,x:11.5,y:12.2,phase:1.4,pace:.16}],traffic:[{id:1,x:15,y:15,speed:1.2,color:"#f5bd58"}],nextBuildingId:2,stats:{income:13,expenses:2,jobs:8,traffic:3}};
 const migrationPage=await browser.newPage({viewport:{width:844,height:390},screen:{width:844,height:390},deviceScaleFactor:1,isMobile:true,hasTouch:true});
 const migrationErrors=[];migrationPage.on("pageerror",error=>migrationErrors.push(String(error)));
 try{
  await migrationPage.addInitScript(legacy=>localStorage.setItem("mshin-city-save-v1",JSON.stringify(legacy)),legacyFixture);
  await migrationPage.goto("http://127.0.0.1:4173/city.html");
  await migrationPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:30000});
  const migrated=await migrationPage.evaluate(()=>({city:window.MshinCityDebug.city,current:JSON.parse(localStorage.getItem("mshin-city-save-v2")),legacy:localStorage.getItem("mshin-city-save-v1")}));
  assert.equal(migrated.city.schemaVersion,2,"legacy v1 saves must migrate to the current v2 schema");
  assert.equal(migrated.city.treasury,12345,"migration must preserve treasury");
  assert.equal(migrated.city.buildings.length,1,"migration must preserve constructed buildings");
  assert.equal(migrated.city.population,12,"migration must preserve population");
  assert.equal(migrated.city.citizens.length,4,"legacy citizens must be rebuilt on the current road network");
  assert.equal(migrated.city.traffic.length,0,"legacy rail traffic must be regenerated by the current traffic simulation");
  assert.equal(migrated.current.schemaVersion,2,"migrated state must be written to the current local save key");
  assert.equal(migrated.legacy,null,"legacy storage key must be retired only after successful migration");
  assert.deepEqual(migrationErrors,[],"legacy save migration must not throw browser errors");
 }finally{await migrationPage.close()}
 const recoveryPage=await browser.newPage({viewport:{width:844,height:390},screen:{width:844,height:390},deviceScaleFactor:1,isMobile:true,hasTouch:true});
 const recoveryErrors=[];recoveryPage.on("pageerror",error=>recoveryErrors.push(String(error)));
 try{
  await recoveryPage.addInitScript(snapshot=>{
   localStorage.setItem("mshin-city-save-v2","{corrupt");
   localStorage.setItem("mshin-city-save-v1","{corrupt-legacy");
   localStorage.setItem("mshin-city-save-v2.backup",JSON.stringify(snapshot));
  },backupPayload.city);
  await recoveryPage.goto("http://127.0.0.1:4173/city.html");
  await recoveryPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:30000});
  const recovered=await recoveryPage.evaluate(()=>({treasury:window.MshinCityDebug.city.treasury,rows:window.MshinCityDebug.city.grid.length,stored:JSON.parse(localStorage.getItem("mshin-city-save-v2")),recovery:localStorage.getItem("mshin-city-save-v2.recovery"),legacyRaw:localStorage.getItem("mshin-city-save-v1"),legacyRecovery:localStorage.getItem("mshin-city-save-v1.recovery")}));
  assert.equal(recovered.treasury,backupPayload.city.treasury,"a valid previous snapshot must recover after the active save is corrupted");
  assert.equal(recovered.rows,32,"backup recovery must restore the complete city grid");
  assert.equal(recovered.stored.schemaVersion,2,"backup recovery must rewrite the active save");
  assert.equal(recovered.recovery,"{corrupt","the rejected raw save must remain available for manual recovery");
  assert.equal(recovered.legacyRaw,"{corrupt-legacy","the legacy test fixture must survive page boot");
  assert.equal(recovered.legacyRecovery,"{corrupt-legacy","the malformed legacy save must be preserved separately");
  assert.deepEqual(recoveryErrors,[],"backup recovery must not throw browser errors");
 }finally{await recoveryPage.close()}
 const invalidRecoveryPage=await browser.newPage({viewport:{width:844,height:390},screen:{width:844,height:390},deviceScaleFactor:1,isMobile:true,hasTouch:true});
 const invalidRecoveryErrors=[];invalidRecoveryPage.on("pageerror",error=>invalidRecoveryErrors.push(String(error)));
 try{
  await invalidRecoveryPage.addInitScript(()=>{
   localStorage.setItem("mshin-city-save-v2","{corrupt-active");
   localStorage.setItem("mshin-city-save-v1","{corrupt-legacy");
   localStorage.setItem("mshin-city-save-v2.backup","{corrupt-backup");
  });
  await invalidRecoveryPage.goto("http://127.0.0.1:4173/city.html");
  await invalidRecoveryPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:30000});
  const preserved=await invalidRecoveryPage.evaluate(()=>({
   active:localStorage.getItem("mshin-city-save-v2.recovery"),
   legacy:localStorage.getItem("mshin-city-save-v1.recovery"),
   backup:localStorage.getItem("mshin-city-save-v2.backup.recovery"),
   population:window.MshinCityDebug.city.population,
   gridRows:window.MshinCityDebug.city.grid.length
  }));
  assert.equal(preserved.active,"{corrupt-active","active v2 raw save must remain recoverable");
  assert.equal(preserved.legacy,"{corrupt-legacy","legacy v1 raw save must remain recoverable");
  assert.equal(preserved.backup,"{corrupt-backup","malformed backup raw data must remain recoverable");
  assert.equal(preserved.population,0,"when no valid snapshot exists, load must start a clean city rather than partially importing corruption");
  assert.equal(preserved.gridRows,32,"corrupt-save fallback must produce a complete city grid");
  assert.deepEqual(invalidRecoveryErrors,[],"corrupt-save fallback must not throw browser errors");
 }finally{await invalidRecoveryPage.close()}
 const noFullscreenPage=await browser.newPage({viewport:{width:844,height:390},screen:{width:844,height:390},deviceScaleFactor:1,isMobile:true,hasTouch:true});
 const noFullscreenErrors=[];noFullscreenPage.on("pageerror",error=>noFullscreenErrors.push(String(error)));
 try{
  await noFullscreenPage.addInitScript(()=>{
   Object.defineProperty(HTMLElement.prototype,"requestFullscreen",{configurable:true,value:undefined});
   Object.defineProperty(screen,"orientation",{configurable:true,value:undefined});
  });
  await noFullscreenPage.goto("http://127.0.0.1:4173/city.html");
  await noFullscreenPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:30000});
  const fallback=await noFullscreenPage.evaluate(()=>({hidden:document.querySelector("#cityOrientationGate").hidden,entered:window.__mshinCityEntryDebug.entered,mode:document.documentElement.dataset.cityOrientation}));
  assert.equal(fallback.mode,"landscape","fallback fixture must represent a landscape phone");
  assert.equal(fallback.hidden,true,"landscape play must not be blocked when fullscreen and orientation APIs are unavailable");
  assert.equal(fallback.entered,true,"the no-fullscreen fallback must publish a successful city entry");
  assert.deepEqual(noFullscreenErrors,[],"no-fullscreen landscape entry must not throw browser errors");
 }finally{await noFullscreenPage.close()}
 const deniedFullscreenPage=await browser.newPage({viewport:{width:390,height:844},screen:{width:390,height:844},deviceScaleFactor:1,isMobile:true,hasTouch:true});
 const deniedFullscreenErrors=[];deniedFullscreenPage.on("pageerror",error=>deniedFullscreenErrors.push(String(error)));
 try{
  await deniedFullscreenPage.addInitScript(()=>{
   HTMLElement.prototype.requestFullscreen=async function(){throw new DOMException("Fullscreen permission denied","NotAllowedError")};
  });
  await deniedFullscreenPage.goto("http://127.0.0.1:4173/city.html");
  await deniedFullscreenPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:30000});
  await deniedFullscreenPage.locator("#cityEnterLandscape").click();
  await deniedFullscreenPage.waitForFunction(()=>window.__mshinCityEntryDebug.fullscreenRequested===true,undefined,{timeout:5000});
  await deniedFullscreenPage.setViewportSize({width:844,height:390});
  await deniedFullscreenPage.waitForFunction(()=>window.__mshinCityEntryDebug.entered===true&&document.querySelector("#cityOrientationGate").hidden,undefined,{timeout:5000});
  const deniedFallback=await deniedFullscreenPage.evaluate(()=>({fallback:window.__mshinCityEntryDebug.fullscreenFallback,hidden:document.querySelector("#cityOrientationGate").hidden,mode:document.documentElement.dataset.cityOrientation}));
  assert.equal(deniedFallback.mode,"landscape","denied-fullscreen fixture must finish in landscape");
  assert.equal(deniedFallback.hidden,true,"landscape play must proceed after fullscreen permission is denied");
  assert.equal(deniedFallback.fallback,"landscape-after-fullscreen-denied","the denied-fullscreen fallback must be observable");
  assert.deepEqual(deniedFullscreenErrors,[],"denied-fullscreen landscape entry must not throw browser errors");
 }finally{await deniedFullscreenPage.close()}
 assert.deepEqual(errors,[],"city route must not throw runtime errors");
 const cameraVideo=page.video();
 await cameraContext.close();
 const cameraVideoPath=await cameraVideo.path();
 fs.copyFileSync(cameraVideoPath,"artifacts/city-camera-gesture.webm");
 process.stdout.write("City browser smoke passed: empty 3D grid, WebGL renderer, pinch zoom, zoning, construction, services, road-following traffic, 3D vehicle instancing, deep save validation/recovery, demolition persistence, autosave and live simulation.\\n");
}finally{await browser.close()}
