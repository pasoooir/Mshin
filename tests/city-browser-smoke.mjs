import {chromium} from "playwright";
import assert from "node:assert/strict";
import fs from "node:fs";

async function captureScreenshot(page,path){
 const startedAt=Date.now();
 let paused=false,timer,phase="pause-render-loop";
 const deadline=new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error("City frame export exceeded the hard 10-second limit during "+phase+": "+path)),10000)});
 try{
  const operation=(async()=>{
   paused=await page.evaluate(()=>{
    const debug=window.MshinCityDebug;
    if(typeof debug?.pauseLoop!=="function"||typeof debug?.resumeLoop!=="function")return false;
    debug.pauseLoop();
    debug.draw();
    return true;
   });
   if(!paused)throw new Error("City render loop could not be paused before frame export: "+path);
   phase="settle-final-frame";
   await page.waitForTimeout(80);
   phase="read-webgl-frame";
   const dataUrl=await page.evaluate(()=>{
    const canvas=document.querySelector("#cityThreeViewport");
    if(!(canvas instanceof HTMLCanvasElement))throw new Error("Three.js city canvas is missing");
    const attributes=canvas.getContext("webgl2")?.getContextAttributes()||canvas.getContext("webgl")?.getContextAttributes();
    if(!attributes?.preserveDrawingBuffer)throw new Error("Smoke mode must preserve the WebGL frame buffer for deterministic export");
    return canvas.toDataURL("image/png");
   });
   phase="write-png-artifact";
   const comma=dataUrl.indexOf(",");
   if(comma<0||!dataUrl.startsWith("data:image/png;base64,"))throw new Error("City frame export returned an invalid PNG data URL");
   fs.mkdirSync(path.slice(0,path.lastIndexOf("/"))||".",{recursive:true});
   fs.writeFileSync(path,Buffer.from(dataUrl.slice(comma+1),"base64"));
   if(Date.now()-startedAt>10000)throw new Error("City frame export exceeded the hard 10-second limit: "+path);
  })();
  await Promise.race([operation,deadline]);
 }finally{
  clearTimeout(timer);
  if(paused)page.evaluate(()=>window.MshinCityDebug?.resumeLoop?.()).catch(()=>{});
 }
}


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
 await page.goto("http://127.0.0.1:4173/city.html?cityCapture=1",{waitUntil:"domcontentloaded"});
 const rendererBootStartedAt=Date.now();
 try{await page.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{timeout:60000,polling:100})}catch(error){const diagnostic=await page.evaluate(()=>({ready:document.documentElement.dataset.cityReady,rendererReady:window.MshinCity3DReady===true,rendererError:window.MshinCity3DError||null,status:document.querySelector("#cityRenderStatus")?.textContent,canvasCount:document.querySelectorAll("canvas").length}));throw new Error("city renderer startup failed: "+JSON.stringify({diagnostic,errors})+"; "+error.message)}
 const rendererBootDuration=Date.now()-rendererBootStartedAt;
 assert.ok(rendererBootDuration<60000,"compact city renderer must finish initialization within the bounded 60-second mobile startup budget");
 const cityLocale=await page.evaluate(()=>({lang:document.documentElement.lang,direction:document.documentElement.dir,text:document.body.innerText}));
 assert.equal(cityLocale.lang,"en","city interface language must be English");assert.equal(cityLocale.direction,"ltr","city interface must use left-to-right layout");assert.doesNotMatch(cityLocale.text,/[۰-۹٠-٩]/,"city UI must display Latin digits only");
 const viewportMeta=await page.locator('meta[name="viewport"]').getAttribute("content");
 assert.match(viewportMeta,/viewport-fit=cover/,"city must opt into safe-area-aware mobile viewport sizing");
 const initialVisualViewport=await page.evaluate(()=>({width:visualViewport.width,height:visualViewport.height}));
 assert.ok(Math.abs(initialVisualViewport.width-844)<=1&&Math.abs(initialVisualViewport.height-390)<=1,"city must start sized to the visible landscape viewport");
 const landscapeHud=await page.evaluate(()=>{
  const box=selector=>{const r=document.querySelector(selector).getBoundingClientRect();return {left:r.left,right:r.right,top:r.top,bottom:r.bottom,width:r.width,height:r.height}};
  return {viewport:{width:innerWidth,height:innerHeight},brand:box(".cityBrand"),actions:box(".cityActions"),metrics:box(".cityMetrics")};
 });
 assert.ok(landscapeHud.brand.width>0&&landscapeHud.actions.width>0&&landscapeHud.metrics.width>0,"landscape HUD sections must be laid out");
 assert.ok(landscapeHud.brand.right<=landscapeHud.actions.left+1||landscapeHud.actions.right<=landscapeHud.brand.left+1,"brand and action buttons must not overlap in landscape");
 assert.ok(landscapeHud.metrics.top>=Math.min(landscapeHud.brand.bottom,landscapeHud.actions.bottom)-1,"city metrics must occupy their own row below the brand/actions row");
 assert.ok(landscapeHud.metrics.left>=0&&landscapeHud.metrics.right<=landscapeHud.viewport.width,"all seven city metrics must remain inside the landscape viewport");

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
 assert.equal(await page.evaluate(()=>typeof window.MshinCityDebug.pauseLoop==="function"&&typeof window.MshinCityDebug.resumeLoop==="function"),true,"city smoke screenshots must be able to pause and resume the live renderer without changing game state");
 const renderStats=await page.evaluate(()=>window.MshinCity3DStats);
 assert.equal(renderStats.renderer,"three.js");
 assert.equal(renderStats.rendererTier,"mobile","touch-enabled mobile browser smoke must activate the mobile GPU profile");
 assert.ok(renderStats.pixelRatio<=0.65,"capture-mode renderer pixel ratio must stay within the bounded SwiftShader readback budget");
 assert.equal(renderStats.preserveDrawingBuffer,true,"smoke-only WebGL frame export must preserve the buffer without changing production rendering");
 assert.equal(renderStats.antialias,false,"mobile renderer must disable costly multisample antialiasing");
 assert.equal(renderStats.shadowMapSize,512,"mobile renderer must use the constrained 512px shadow map");
 assert.equal(renderStats.version,"180");
 assert.equal(renderStats.visualStyle,"full-spectrum-natural-coastal-world","the city renderer must use the full-spectrum natural coastal PBR art direction");
 assert.equal(renderStats.continuousGrassland,true,"the world must be one continuous grass surface");
 assert.equal(renderStats.visiblePlotGridLines,0,"plot borders and checkerboard lines must never be rendered");
 assert.equal(renderStats.groundExtentMeters,1000000,"the continuous terrain must extend beyond every supported zoom-out view without exposing the page backdrop");
 assert.equal(renderStats.proceduralTextures,6,"terrain, asphalt, brick, concrete, roof and sidewalk must use dedicated texture families");
 assert.equal(renderStats.pbrMaterialSets,6,"all six city surface families must expose complete PBR map sets");
 assert.equal(renderStats.normalMappedSurfaces,6,"all six city surface families must use generated normal maps");
 assert.equal(renderStats.roughnessMappedSurfaces,6,"all six city surface families must use generated roughness maps");
 assert.equal(renderStats.texturedBuildingMaterials,4,"residential, commercial, industrial and civic materials must use PBR textures");
 assert.equal(renderStats.backgroundCityBuildings,0,"a new city must not contain decorative houses or apartment buildings");
 assert.equal(renderStats.backgroundCityWindows,0,"a new city must not render windows on nonexistent buildings");
 assert.equal(await page.locator("#cityRenderStatus").textContent(),"3D Renderer Ready","the UI must report when the actual 3D renderer is ready");
 assert.ok((await page.locator(".cityBrand small").textContent()).includes("0.15.7"),"the city UI must expose the deployed version");
 assert.equal(renderStats.decorativeTrees,0,"a brand-new city must show an uninterrupted grassland without decorative trees");
 assert.equal(renderStats.decorativeTreesOutsideBuildableGrid,0,"the empty starting meadow must not contain any decorative tree props");
 assert.equal(renderStats.decorativeStreetLights,0,"do not place street furniture in parcels until a dedicated sidewalk/ROW exists");
 assert.equal(renderStats.streetFurniturePlacementReady,false,"the road grid must expose a dedicated non-buildable sidewalk/ROW before street furniture is enabled");
 assert.equal(renderStats.sidewalkStrips,0,"the empty starting world must not contain sidewalks before roads are built");
 assert.equal(renderStats.plots,1024,"all 1024 plots in the playable grid must be empty and buildable");
 assert.equal(renderStats.roadTiles,0,"a new city must not contain prebuilt roads");
 assert.equal(renderStats.raisedCurbs,0,"the empty starting world must not contain road curbs");
 assert.equal(renderStats.crosswalkStripes,0,"do not paint pedestrian crossings until pedestrian graph and crossing priority are implemented");
 assert.ok(renderStats.lockedPlots>=1600&&renderStats.visiblePlots>=2300,"the visible world must include a large locked expansion grid, not blank margins");
 assert.equal(renderStats.visibleRoadTiles,0,"the initial world must not render prebuilt roads");
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
 await captureScreenshot(page,"artifacts/city-empty-world-landscape.png");
 await page.evaluate(()=>window.MshinCityDebug.setCameraZoom(0.05));
 const meadowZoomOut=await page.evaluate(()=>({zoom:window.MshinCityDebug.view.zoom,stats:window.MshinCity3DStats}));
 assert.ok(Math.abs(meadowZoomOut.zoom-0.42)<0.001,"zoom-out must stop before the camera exposes areas outside the playable world");
 assert.equal(meadowZoomOut.stats.minimumZoom,0.42,"the renderer and touch controls must share one minimum zoom");
 await page.evaluate(()=>{window.MshinCityDebug.setCameraPitch(0.24);window.MshinCityDebug.setCameraTarget(5000,5000)});
 const boundedCamera=await page.evaluate(()=>({view:window.MshinCityDebug.view,limit:window.MshinCity3DStats.cameraTargetLimitMeters}));
 assert.ok(Math.abs(boundedCamera.view.targetX)<=boundedCamera.limit+0.001&&Math.abs(boundedCamera.view.targetZ)<=boundedCamera.limit+0.001,"camera panning must stay inside the playable world even at the widest zoom-out and lowest pitch");
 await page.evaluate(()=>{window.MshinCityDebug.setCameraTarget(0,0);window.MshinCityDebug.setCameraPitch(0.51)});
 assert.equal(meadowZoomOut.stats.continuousGrassland,true,"zooming out must keep the same continuous grass terrain");
  assert.equal(meadowZoomOut.stats.groundExtentMeters,1000000,"maximum zoom-out must retain million-meter terrain coverage so no blank canvas edge can enter the viewport");
 assert.equal(meadowZoomOut.stats.visiblePlotGridLines,0,"zooming out must never reveal square plot outlines");
 await captureScreenshot(page,"artifacts/city-meadow-maximum-zoom-out.png");
 await page.evaluate(()=>window.MshinCityDebug.setCameraZoom(0.72));

 assert.ok(renderStats.drawCalls<80,"instanced city ground must stay within a mobile-friendly draw-call budget");

 // Daylight is intentionally locked until the city reaches a stable release.
 await page.evaluate(()=>{window.MshinCityDebug.city.minuteOfDay=0;window.MshinCityDebug.draw()});
 const lockedDayLighting=await page.evaluate(()=>window.MshinCity3DStats.lighting);
 assert.equal(lockedDayLighting.phase,"day","even a saved midnight value must render as daytime");
 assert.equal(lockedDayLighting.minuteOfDay,720,"the renderer must normalize all clock values to midday");
 assert.equal(lockedDayLighting.daylight,1,"the city must retain full daylight");
 assert.equal(await page.evaluate(()=>window.MshinCity3DStats.celestialBodies),1,"day must display the sun and hide the moon");
 assert.ok(lockedDayLighting.windowGlow<0.1,"building windows must remain subdued during daytime");
 assert.equal(await page.evaluate(()=>window.MshinCity3DStats.visibleStars),0,"the permanent day scene must never render stars");
 await page.evaluate(()=>{window.MshinCityDebug.city.minuteOfDay=1080;window.MshinCityDebug.draw()});
 const eveningAttempt=await page.evaluate(()=>window.MshinCity3DStats.lighting);
 assert.equal(eveningAttempt.phase,"day","attempting to render evening must still remain daytime");
 assert.equal(eveningAttempt.minuteOfDay,720,"the city must never enter twilight or night before stability");
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
 await captureScreenshot(page,"artifacts/city-3d-object-showcase-360.png");
 await page.evaluate(zoom=>{const city=window.MshinCityDebug.city;city.buildings=[];city.population=0;city.citizens=[];window.MshinCityDebug.setCameraOrbit(0);window.MshinCityDebug.setCameraZoom(zoom);window.MshinCityDebug.draw()},objectShowcase.originalZoom);
 await page.evaluate(()=>{window.MshinCityDebug.city.minuteOfDay=495;window.MshinCityDebug.draw()});

 const mapControls=await page.evaluate(()=>({zoom:window.MshinCityDebug.view.zoom,zoomButtons:document.querySelectorAll("#cityZoomIn,#cityZoomOut").length,recenter:document.querySelector("#cityRecenter")?.getBoundingClientRect().toJSON(),canvas:document.querySelector("#cityThreeViewport")?.getBoundingClientRect().toJSON()}));
 assert.ok(mapControls.zoom>=.7,"mobile city should open with a useful exploration zoom");assert.equal(mapControls.zoomButtons,0,"manual plus/minus zoom buttons must be removed; touch zoom is gesture-only");assert.ok(mapControls.recenter?.width>=40&&mapControls.recenter?.height>=40,"recenter remains available as a single camera utility");
 assert.ok(mapControls.canvas.width>=844&&mapControls.canvas.height>=390,"3D city canvas must fill the entire landscape viewport without letterboxing");
 await page.locator("#cityRecenter").click();assert.ok(Math.abs(await page.evaluate(()=>window.MshinCityDebug.view.zoom)-.72)<.001,"recenter must restore the mobile map scale");
 assert.equal(await page.title(),"My City | Mshin");
 const initial=await page.evaluate(()=>({population:window.MshinCityDebug.city.population,buildings:window.MshinCityDebug.city.buildings.length,roads:window.MshinCityDebug.city.grid.flat().filter(t=>t==="road").length,citizens:window.MshinCityDebug.city.citizens.length,traffic:window.MshinCityDebug.city.traffic.length,animals:window.MshinCityDebug.city.animals.length,width:document.querySelector("#cityViewport").width}));
 const windowTrafficInvariant=await page.evaluate(()=>window.MshinCityDebug.city.traffic.every(vehicle=>Number.isFinite(vehicle.x)&&Number.isFinite(vehicle.y)&&window.MshinCityDebug.city.grid[Math.round(vehicle.y)]?.[Math.round(vehicle.x)]==="road"));
 assert.equal(initial.population,0,"new city must start without residents");assert.equal(initial.buildings,0,"new city must contain no buildings");assert.equal(initial.roads,0,"the first-time city must contain no roads");assert.equal(initial.citizens,0);assert.ok(initial.traffic<=12,"live simulation traffic must stay within its bounded fleet");assert.ok(windowTrafficInvariant,"traffic must remain on valid road tiles");assert.equal(initial.animals,0);assert.ok(initial.width>=320,"city canvas must use the available phone display width: "+JSON.stringify(initial));
 const rebuildsBeforePlacement=await page.evaluate(()=>window.MshinCity3DStats.buildingRebuilds);
 await clickCityTool(page,"road");const roadTarget=await page.evaluate(()=>window.MshinCityDebug.screenForTile(14,14));await page.mouse.click(roadTarget.x,roadTarget.y);assert.equal(await page.evaluate(()=>window.MshinCity3DStats.roadTiles),1,"a road must become visible only after the player builds it");await clickCityTool(page,"park");const target=await page.evaluate(()=>window.MshinCityDebug.screenForTile(14,15));await page.mouse.click(target.x,target.y);
 assert.equal(await page.evaluate(()=>window.MshinCityDebug.city.grid[15][14]),"building","park tool should place a city asset");
 const parkVisual=await page.evaluate(()=>window.MshinCity3DStats);
 assert.equal(parkVisual.stylizedBuildings,1,"placed park must become a rendered 3D scene object");
 assert.equal(parkVisual.shadowAutoUpdate,false,"static city shadows must not be regenerated every mobile frame");
 assert.equal(parkVisual.buildingRebuilds,rebuildsBeforePlacement+1,"a structural building change should rebuild the 3D building layer exactly once");
 await page.waitForTimeout(150);
 assert.equal(await page.evaluate(()=>window.MshinCity3DStats.buildingRebuilds),rebuildsBeforePlacement+1,"unchanged buildings must not be recreated during subsequent render frames");
 await page.locator("#citySave").click();assert.ok(await page.evaluate(()=>JSON.parse(localStorage.getItem("mshin-city-save-v2"))?.buildings?.some(b=>b.x===14&&b.y===15)),"city changes should persist");
 await clickCityTool(page,"select");
 const zoomBefore=await page.evaluate(()=>window.MshinCityDebug.view.zoom),orbitBefore=await page.evaluate(()=>window.MshinCityDebug.view.orbit),focusAnchorBefore=await page.evaluate(()=>window.MshinCityDebug.groundPointAt(190,220));
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",91,120,220);send("pointerdown",92,260,220);send("pointermove",92,320,220);send("pointerup",92,320,220);send("pointerup",91,120,220)});
 const zoomAfter=await page.evaluate(()=>window.MshinCityDebug.view.zoom),orbitAfter=await page.evaluate(()=>window.MshinCityDebug.view.orbit);assert.ok(zoomAfter>zoomBefore,"two-finger pinch must zoom the city map");assert.equal(orbitAfter,orbitBefore,"parallel two-finger movement must pan, not orbit");
 const focusAnchorAfter=await page.evaluate(()=>window.MshinCityDebug.groundPointAt(220,220));
 assert.ok(focusAnchorBefore&&focusAnchorAfter,"browser acceptance must obtain real Three.js ground-raycast anchors");
 assert.ok(Math.hypot(focusAnchorBefore.x-focusAnchorAfter.x,focusAnchorBefore.z-focusAnchorAfter.z)<0.08,"pinch/orbit world anchor drifted: "+JSON.stringify({before:focusAnchorBefore,after:focusAnchorAfter,drift:Math.hypot(focusAnchorBefore.x-focusAnchorAfter.x,focusAnchorBefore.z-focusAnchorAfter.z)}));

 const translationZoomBefore=await page.evaluate(()=>window.MshinCityDebug.view.zoom);
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",701,100,220);send("pointerdown",702,200,220);send("pointermove",701,200,220);send("pointermove",702,300,220);send("pointerup",701,200,220);send("pointerup",702,300,220)});
 const translationZoomAfter=await page.evaluate(()=>window.MshinCityDebug.view.zoom);
 assert.ok(Math.abs(translationZoomAfter-translationZoomBefore)<0.0001,"equal two-finger translation must not change zoom");

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
 assert.equal(pitchAfter,pitchBefore,"vertical two-finger movement must pan, not tilt the camera");
 assert.ok(Math.abs((await page.evaluate(()=>window.MshinCityDebug.view.zoom))-tiltZoomBefore)<0.0001,"vertical camera tilt must not alter pinch zoom");
 assert.ok(Math.abs((await page.evaluate(()=>window.MshinCityDebug.view.orbit))-tiltOrbitBefore)<0.0001,"vertical camera tilt must not alter horizontal orbit");


 const orbitStart=await page.evaluate(()=>window.MshinCityDebug.view.orbit);
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));for(let i=0;i<9;i++){const a=200+i*2,b=201+i*2;send("pointerdown",a,200,220);send("pointerdown",b,250,220);for(let step=1;step<=8;step++){const angle=step*Math.PI/4;send("pointermove",b,200+50*Math.cos(angle),220+50*Math.sin(angle))}send("pointerup",a,200,220);send("pointerup",b,250,220)}});
 const fullTurnOrbit=await page.evaluate(()=>window.MshinCityDebug.view.orbit);
 assert.ok(fullTurnOrbit>orbitStart+Math.PI*2,"repeated two-finger horizontal gestures must cross 360 degrees without wrapping or jumping");
 const inertiaReleaseBefore=await page.evaluate(()=>window.MshinCityDebug.view.orbit);
 const releaseSnapshot=await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",450,100,220);send("pointerdown",451,200,220);send("pointermove",451,200,260);send("pointerup",450,100,220);send("pointerup",451,200,260);const state=window.MshinCityDebug.view;return{gesture:state.gesture,orbit:state.orbit}});
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
 await page.waitForFunction(()=>window.MshinCityDebug.view.gesture.inertiaActive===false,undefined,{polling:50,timeout:2000});
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
 await page.evaluate(()=>{const c=document.querySelector("#cityViewport"),send=(type,id,x,y)=>c.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:id,pointerType:"touch",clientX:x,clientY:y}));send("pointerdown",571,160,220);send("pointerdown",572,280,220);for(let i=1;i<=120;i++){const angle=i*0.025,span=120*(1+0.08*Math.sin(i*0.11)),cx=160+i*0.25,cy=220+i*0.12;send("pointermove",571,cx,cy);send("pointermove",572,cx+span*Math.cos(angle),cy+span*Math.sin(angle))}const endAngle=3, endSpan=120*(1+0.08*Math.sin(120*0.11)),endCx=190,endCy=234.4;send("pointerup",572,endCx+endSpan*Math.cos(endAngle),endCy+endSpan*Math.sin(endAngle));send("pointerup",571,endCx,endCy)});
 const sustainedEnd=await page.evaluate(()=>({orbit:window.MshinCityDebug.view.orbit,zoom:window.MshinCityDebug.view.zoom,gesture:window.MshinCityDebug.view.gesture}));
 assert.ok(Number.isFinite(sustainedEnd.orbit)&&Math.abs(sustainedEnd.orbit-sustainedStart.orbit)>0.5,"long-running orbit must remain finite and responsive");
 assert.ok(sustainedEnd.zoom>=0.42&&sustainedEnd.zoom<=1.5,"long-running pinch must remain inside camera zoom limits");
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


 await clickCityTool(page,"road");const zoneAccessTarget=await page.evaluate(()=>window.MshinCityDebug.screenForTile(17,13));await page.mouse.click(zoneAccessTarget.x,zoneAccessTarget.y);await clickCityTool(page,"zone-residential");const zoneTarget=await page.evaluate(()=>window.MshinCityDebug.screenForTile(17,14));await page.mouse.click(zoneTarget.x,zoneTarget.y);
 assert.equal(await page.evaluate(()=>window.MshinCityDebug.city.grid[14][17]),"zone-residential","mobile players must be able to zone a road-connected tile");
 await page.evaluate(()=>{for(let i=0;i<12;i++)window.MshinCityDebug.step()});
 assert.ok(await page.evaluate(()=>window.MshinCityDebug.city.buildings.some(b=>b.x===17&&b.y===14&&b.type==="home")),"residential zoning must grow into a home when demand exists");
 await clickCityTool(page,"road");for(const [x,y] of [[14,13],[15,13],[16,13]]){const point=await page.evaluate(([x,y])=>window.MshinCityDebug.screenForTile(x,y),[x,y]);await page.mouse.click(point.x,point.y)}await clickCityTool(page,"select");
 assert.equal(await page.evaluate(()=>[[14,13],[15,13],[16,13]].every(([x,y])=>window.MshinCityDebug.city.grid[y][x]==="road")),true,"the traffic acceptance fixture must build a connected road segment");
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
 for(const type of ["power","water","police"]){await clickCityTool(page,type);const target=await page.evaluate(()=>{const city=window.MshinCityDebug.city,w=innerWidth,h=innerHeight;for(let y=0;y<32;y++)for(let x=0;x<32;x++){if(city.grid[y][x]!=="grass")continue;const adjacent=[[1,0],[-1,0],[0,1],[0,-1]].some(([dx,dy])=>city.grid[y+dy]?.[x+dx]==="road");if(!adjacent)continue;const point=window.MshinCityDebug.screenForTile(x,y);if(point.x<18||point.x>w-18||point.y<115||point.y>h-90)continue;const hit=document.elementFromPoint(point.x,point.y);if(hit?.id!=="cityViewport")continue;const projected=window.MshinCityDebug.tileAtScreen(point.x,point.y);if(projected?.x===x&&projected?.y===y)return{x,y,point}}return null});assert.ok(target,type+" test must find a visible free road-adjacent parcel");const {x,y,point}=target;await page.mouse.click(point.x,point.y);const diagnostic=await page.evaluate(({x,y,type})=>({placed:window.MshinCityDebug.city.buildings.some(b=>b.x===x&&b.y===y&&b.type===type),tool:window.MshinCityDebug.activeTool,selected:window.MshinCityDebug.selected,toast:document.querySelector("#cityToast")?.textContent,treasury:window.MshinCityDebug.city.treasury,cell:window.MshinCityDebug.city.grid[y]?.[x]}),{x,y,type});assert.deepEqual(diagnostic.selected,{x,y},type+" map tap must reach the intended free parcel");assert.ok(diagnostic.placed,type+" infrastructure/service should be constructible on mobile: "+JSON.stringify(diagnostic))}
 await page.evaluate(()=>window.MshinCityDebug.step());
 const serviceStats=await page.evaluate(()=>window.MshinCityDebug.city.stats);
 assert.ok(serviceStats.utilityCoverage>0&&serviceStats.publicServiceCoverage>0&&serviceStats.overallCoverage>0,"utility and public service coverage must update the city simulation");
 const secondHome=await page.evaluate(()=>window.MshinCityDebug.place(18,13,"home"));assert.equal(secondHome.ok,true,"a second road-accessible home should be constructible");
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
 await page.waitForFunction(expected=>window.MshinCityDebug.city.name===expected||document.querySelector("#cityToast").textContent.startsWith("Restore failed:"),backupName,{timeout:10000});
 const importResult=await page.evaluate(()=>({name:window.MshinCityDebug.city.name,treasury:window.MshinCityDebug.city.treasury,taxRates:window.MshinCityDebug.city.taxRates,panelHidden:document.querySelector("#cityStoragePanel").classList.contains("hidden"),toast:document.querySelector("#cityToast").textContent}));
 assert.equal(importDialogSeen,true,"backup replacement must require and display confirmation");
 assert.equal(importResult.name,backupName,"backup import must restore the saved city name: "+importResult.toast);
 assert.ok(importResult.treasury>0&&importResult.taxRates.residential===14,"backup import must restore treasury and tax policy");
 assert.equal(importResult.panelHidden,true,"successful restore must close the storage dialog");
 assert.equal(await page.evaluate(()=>document.activeElement.id),"cityBackup","closing storage must restore focus to its trigger");
 const demolition=await page.evaluate(()=>{
  const b=window.MshinCityDebug.city.buildings.find(v=>v.type==="home"&&!(v.x===17&&v.y===14));
  if(!b)throw new Error("test fixture needs a second residential building");
  const result=window.MshinCityDebug.actAt(b.x,b.y,"bulldoze");
  return { ...result, x:b.x, y:b.y, persisted:JSON.parse(localStorage.getItem("mshin-city-save-v2")) };
 });
 assert.equal(demolition.cell,"grass","bulldoze action must remove the selected residential building");
 assert.equal(demolition.saved.grid[demolition.y]?.[demolition.x],"grass","the demolished tile must be empty in the immediate save snapshot");
 assert.deepEqual(demolition.persisted?.grid,demolition.saved.grid,"demolition must write the same updated grid to local storage immediately");
 assert.deepEqual(demolition.persisted?.grid,await page.evaluate(()=>window.MshinCityDebug.city.grid),"persisted city grid must match the live grid after demolition");
 await page.evaluate(()=>{for(let i=0;i<6;i++)window.MshinCityDebug.step()});await page.waitForTimeout(100);
 assert.ok(await page.evaluate(()=>JSON.parse(localStorage.getItem("mshin-city-save-v2"))?.tick>=6),"simulation must autosave without a manual save");
 await page.bringToFront();await page.locator('[data-city-speed="1"]').click();await page.waitForFunction(()=>document.visibilityState==="visible");const before=await page.evaluate(()=>window.MshinCityDebug.city.tick);await page.waitForTimeout(4000);const simulation=await page.evaluate(()=>({tick:window.MshinCityDebug.city.tick,visibility:document.visibilityState,speedLabel:document.querySelector("#citySpeedLabel")?.textContent}));assert.ok(simulation.tick>before,"simulation should advance while the mobile city is visible at 1x speed: "+JSON.stringify({before,...simulation}));
 const drawCallsBeforeTraffic=await page.evaluate(()=>window.MshinCity3DStats.drawCalls);
 await page.waitForFunction(()=>window.MshinCity3DStats?.trafficVehicles>0,undefined,{timeout:8000});
 try{await page.waitForFunction(()=>window.MshinCity3DStats?.trafficVehicles===window.MshinCityDebug.city.traffic.length,undefined,{polling:50,timeout:3000})}catch(error){const diagnostic=await page.evaluate(()=>({activeVehicles:window.MshinCityDebug.city.traffic.length,renderedVehicles:window.MshinCity3DStats?.trafficVehicles,drawCalls:window.MshinCity3DStats?.drawCalls,tick:window.MshinCityDebug.city.tick}));throw new Error("3D traffic instances did not synchronize with the active vehicle fleet: "+JSON.stringify(diagnostic)+"; "+error.message)}
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
 const saveDiagnostics=await page.evaluate(()=>({saved:window.MshinCityDebug.save(),state:window.MshinCityDebug.saveDiagnostics()}));assert.ok(saveDiagnostics.saved,"traffic state must remain persistable with the city save: "+JSON.stringify(saveDiagnostics.state));
 const mobile=await page.evaluate(()=>{const rect=s=>{const r=document.querySelector(s).getBoundingClientRect();return{x:r.x,y:r.y,width:r.width,height:r.height,right:r.right,bottom:r.bottom}};return{viewport:{width:innerWidth,height:innerHeight},documentWidth:document.documentElement.scrollWidth,brand:rect(".cityBrand"),metrics:rect(".cityMetrics"),tools:rect(".cityTools"),bottom:rect(".cityBottom"),categoryButtons:[...document.querySelectorAll(".cityToolCategory")].map(b=>{const r=b.getBoundingClientRect();return{width:r.width,height:r.height}}),viewportMeta:document.querySelector('meta[name="viewport"]').content}});
 assert.equal(mobile.documentWidth,mobile.viewport.width,"mobile city must not create horizontal page overflow");
 const toolMetricsOverlap=mobile.tools.x<mobile.metrics.right&&mobile.tools.right>mobile.metrics.x&&mobile.tools.y<mobile.metrics.bottom&&mobile.tools.bottom>mobile.metrics.y;assert.equal(toolMetricsOverlap,false,"mobile construction rail and top metric strip must not physically overlap: "+JSON.stringify({tools:mobile.tools,metrics:mobile.metrics,viewport:mobile.viewport}));
 assert.ok(mobile.tools.bottom<=mobile.bottom.y+1,"mobile edge controls must leave the lower simulation controls unobstructed");
 assert.ok(mobile.categoryButtons.length===4&&mobile.categoryButtons.every(b=>b.width>=40&&b.height>=44),"all four mobile category controls must remain at least 40×44 CSS pixels");await page.locator('[data-city-category="roads"]').click();const openToolTargets=await page.locator('[data-city-panel="roads"] .cityTool').evaluateAll(items=>items.map(b=>{const r=b.getBoundingClientRect();return{width:r.width,height:r.height}}));assert.ok(openToolTargets.length===6&&openToolTargets.every(b=>b.width>=40&&b.height>=44),"every revealed construction tool must remain a usable mobile touch target");await page.locator('[data-city-category="roads"]').click();
 assert.ok(!/user-scalable=no|maximum-scale=1/.test(mobile.viewportMeta),"mobile browser zoom must remain enabled");
 await captureScreenshot(page,"artifacts/city-mobile-landscape-844x390.png");
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
  await captureScreenshot(compactPage,"artifacts/city-portrait-orientation-gate.png",{fullPage:true});
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
   await landscapePage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{polling:1000,timeout:60000});
  }catch(error){
   const diagnostic=await landscapePage.evaluate(()=>({ready:document.documentElement.dataset.cityReady,rendererReady:window.MshinCity3DReady===true,rendererError:window.MshinCity3DError||null,status:document.querySelector("#cityRenderStatus")?.textContent,webgl:typeof WebGLRenderingContext,canvasCount:document.querySelectorAll("canvas").length}));
   // Playwright's waitForFunction can time out while a backgrounded page's
   // polling is throttled even though the renderer completed successfully.
   // Accept only a fresh DOM snapshot proving both boot flags and the actual
   // Three.js canvas; otherwise preserve the timeout as a real failure.
   if(!(diagnostic.ready==="true"&&diagnostic.rendererReady===true
     &&diagnostic.status==="3D Renderer Ready"&&diagnostic.canvasCount>=2)){
    throw new Error("landscape 3D renderer did not become ready: "+JSON.stringify({diagnostic,errors:landscapeErrors})+"; "+error.message);
   }
  }
  try{await landscapePage.waitForFunction(()=>getComputedStyle(document.querySelector("#cityOrientationGate")).display==="none",undefined,{timeout:5000})}catch(error){const diagnostic=await landscapePage.evaluate(()=>({innerWidth,innerHeight,screenWidth:screen.width,screenHeight:screen.height,mediaLandscape:matchMedia("(orientation: landscape)").matches,mediaPortrait:matchMedia("(orientation: portrait)").matches,orientation:screen.orientation?.type,gateClass:document.querySelector("#cityOrientationGate")?.className,gateHidden:document.querySelector("#cityOrientationGate")?.hidden,gateDisplay:getComputedStyle(document.querySelector("#cityOrientationGate")).display,cityOrientation:document.documentElement.dataset.cityOrientation}));throw new Error("landscape orientation gate did not close: "+JSON.stringify(diagnostic)+"; "+error.message)}
  const landscape=await landscapePage.evaluate(()=>({width:document.documentElement.scrollWidth,viewport:innerWidth,height:innerHeight,gate:getComputedStyle(document.querySelector("#cityOrientationGate")).display}));
  assert.equal(landscape.gate,"none","landscape page must show the city rather than the portrait gate");
  assert.equal(landscape.width,landscape.viewport,"landscape city must not overflow horizontally");
  fs.mkdirSync("artifacts",{recursive:true});
  await captureScreenshot(landscapePage,"artifacts/city-vertical-slice.png",{fullPage:true});
  await landscapePage.evaluate(()=>localStorage.setItem("mshin-city-save-v2",JSON.stringify({schemaVersion:2,cityId:"corrupt",name:"broken",seed:1,tick:0,treasury:0,population:0,grid:[[]]})));
  await landscapePage.reload({waitUntil:"domcontentloaded"});
  try{await landscapePage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{polling:1000,timeout:60000})}catch(error){const diagnostic=await landscapePage.evaluate(()=>({ready:document.documentElement.dataset.cityReady,rendererReady:window.MshinCity3DReady===true,rendererError:window.MshinCity3DError||null,status:document.querySelector("#cityRenderStatus")?.textContent,canvasCount:document.querySelectorAll("canvas").length,debugReady:Boolean(window.MshinCityDebug),save:localStorage.getItem("mshin-city-save-v2")?.slice(0,240)}));if(!(diagnostic.ready==="true"&&diagnostic.rendererReady&&diagnostic.status==="3D Renderer Ready"&&diagnostic.canvasCount>=2&&diagnostic.debugReady))throw new Error("renderer did not recover after malformed-save reload: "+JSON.stringify({diagnostic,errors:landscapeErrors})+"; "+error.message)}
  const recovery=await landscapePage.evaluate(()=>({
    gridRows:window.MshinCityDebug.city.grid.length,
    gridColumns:window.MshinCityDebug.city.grid.every(row=>row.length===32),
    buildings:window.MshinCityDebug.city.buildings.length,
    buildingsValid:window.MshinCityDebug.city.buildings.every(b=>Number.isSafeInteger(b.id)&&b.id>0&&Number.isInteger(b.x)&&Number.isInteger(b.y)&&b.x>=0&&b.x<32&&b.y>=0&&b.y<32&&window.MshinCityDebug.city.grid[b.y][b.x]==="building"),
    zones:window.MshinCityDebug.city.zones.length,
    zonesValid:window.MshinCityDebug.city.zones.every(z=>Number.isInteger(z.x)&&Number.isInteger(z.y)&&window.MshinCityDebug.city.grid[z.y]?.[z.x]==="zone-"+z.type),
    traffic:window.MshinCityDebug.city.traffic.length,
    trafficValid:window.MshinCityDebug.city.traffic.every(v=>Number.isFinite(v.x)&&Number.isFinite(v.y)&&window.MshinCityDebug.city.grid[Math.round(v.y)]?.[Math.round(v.x)]==="road"),
    saved:window.MshinCityDebug.save()
  }));
  assert.equal(recovery.gridRows,32,"malformed local saves must recover to a complete city grid");
  assert.equal(recovery.gridColumns,true,"save recovery must restore all 32 columns");
  assert.ok(recovery.buildingsValid,"save recovery must not retain invalid building records");
  assert.ok(recovery.zonesValid,"save recovery must not retain invalid zoning records");
  assert.ok(recovery.traffic<=12&&recovery.trafficValid,"save recovery must keep only valid traffic records on road cells");
 }finally{await landscapePage.close()}
 const legacyGrid=Array.from({length:32},()=>Array(32).fill("grass"));
 for(let y=0;y<32;y++)for(let x=0;x<32;x++)if([7,15,23].includes(x)||[7,15,23].includes(y))legacyGrid[y][x]="road";
 for(let y=0;y<5;y++)for(let x=26;x<31;x++)legacyGrid[y][x]="water";
 legacyGrid[14][17]="building";
 const legacyFixture={schemaVersion:1,cityId:"legacy-city-01",name:"Old City",seed:20261102,tick:42,minuteOfDay:815,treasury:12345,population:12,happiness:76,grid:legacyGrid,buildings:[{id:1,type:"home",x:17,y:14,level:1,age:4,residents:12}],trees:[{x:10,y:10,size:1.2}],citizens:[{id:1,x:11.5,y:12.2,phase:1.4,pace:.16}],traffic:[{id:1,x:15,y:15,speed:1.2,color:"#f5bd58"}],nextBuildingId:2,stats:{income:13,expenses:2,jobs:8,traffic:3}};
 const migrationPage=await browser.newPage({viewport:{width:844,height:390},screen:{width:844,height:390},deviceScaleFactor:1,isMobile:true,hasTouch:true});
 const migrationErrors=[];migrationPage.on("pageerror",error=>migrationErrors.push(String(error)));
 try{
  await migrationPage.addInitScript(legacy=>localStorage.setItem("mshin-city-save-v1",JSON.stringify(legacy)),legacyFixture);
  await migrationPage.goto("http://127.0.0.1:4173/city.html");
  try{await migrationPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{polling:1000,timeout:60000})}catch(error){const diagnostic=await migrationPage.evaluate(()=>({ready:document.documentElement.dataset.cityReady,rendererReady:window.MshinCity3DReady===true,rendererError:window.MshinCity3DError||null,status:document.querySelector("#cityRenderStatus")?.textContent,canvasCount:document.querySelectorAll("canvas").length,save:localStorage.getItem("mshin-city-save-v2")?.slice(0,240)}));if(!(diagnostic.ready==="true"&&diagnostic.rendererReady&&diagnostic.status==="3D Renderer Ready"&&diagnostic.canvasCount>=2))throw new Error("renderer did not become ready during legacy migration: "+JSON.stringify({diagnostic,errors:migrationErrors})+"; "+error.message)}
  const migrated=await migrationPage.evaluate(()=>({city:window.MshinCityDebug.city,current:JSON.parse(localStorage.getItem("mshin-city-save-v2")),legacy:localStorage.getItem("mshin-city-save-v1")}));
  assert.equal(migrated.city.schemaVersion,2,"legacy v1 saves must migrate to the current v2 schema");
  assert.equal(migrated.city.minuteOfDay,720,"legacy night timestamps must be normalized to permanent midday");
  assert.equal(migrated.current.minuteOfDay,720,"the normalized midday timestamp must be persisted to the active save");
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
 const recoveryErrors=[];recoveryPage.on("pageerror",error=>recoveryErrors.push(error.stack||String(error)));recoveryPage.on("console",message=>{if(message.type()==="error")recoveryErrors.push("console: "+message.text())});recoveryPage.on("requestfailed",request=>recoveryErrors.push("request failed: "+request.url()+" "+request.failure()?.errorText));
 try{
  await recoveryPage.addInitScript(snapshot=>{
   localStorage.setItem("mshin-city-save-v2","{corrupt");
   localStorage.setItem("mshin-city-save-v1","{corrupt-legacy");
   localStorage.setItem("mshin-city-save-v2.backup",JSON.stringify(snapshot));
  },backupPayload.city);
  await recoveryPage.goto("http://127.0.0.1:4173/city.html",{waitUntil:"domcontentloaded"});
  await recoveryPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true",undefined,{timeout:15000});
  // Recovery validation is independent of simulation controls; do not block renderer acceptance on an optional HUD control.
  await recoveryPage.evaluate(()=>document.querySelector('[data-city-speed="0"]')?.click());

  try{await recoveryPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{polling:1000,timeout:60000})}catch(error){const diagnostic=await recoveryPage.evaluate(()=>({ready:document.documentElement.dataset.cityReady,rendererReady:window.MshinCity3DReady===true,rendererError:window.MshinCity3DError||null,status:document.querySelector("#cityRenderStatus")?.textContent,canvasCount:document.querySelectorAll("canvas").length,debugReady:Boolean(window.MshinCityDebug),activeSave:localStorage.getItem("mshin-city-save-v2")?.slice(0,180),backupBytes:localStorage.getItem("mshin-city-save-v2.backup")?.length||0}));if(!(diagnostic.ready==="true"&&diagnostic.rendererReady&&diagnostic.status==="3D Renderer Ready"&&diagnostic.canvasCount>=2&&diagnostic.debugReady))throw new Error("3D renderer did not become ready during backup recovery: "+JSON.stringify({diagnostic,errors:recoveryErrors})+"; "+error.message)}
  const recovered=await recoveryPage.evaluate(()=>({treasury:window.MshinCityDebug.city.treasury,cityId:window.MshinCityDebug.city.cityId,name:window.MshinCityDebug.city.name,seed:window.MshinCityDebug.city.seed,rows:window.MshinCityDebug.city.grid.length,stored:JSON.parse(localStorage.getItem("mshin-city-save-v2")),recovery:localStorage.getItem("mshin-city-save-v2.recovery"),legacyRaw:localStorage.getItem("mshin-city-save-v1"),legacyRecovery:localStorage.getItem("mshin-city-save-v1.recovery")}));
  assert.equal(recovered.cityId,backupPayload.city.cityId,"backup recovery must restore the original city identity");
  assert.equal(recovered.name,backupPayload.city.name,"backup recovery must restore the original city name");
  assert.equal(recovered.seed,backupPayload.city.seed,"backup recovery must restore the original world seed");
  assert.equal(recovered.stored.treasury,recovered.treasury,"the recovered active save must match the live restored city state");
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
  await invalidRecoveryPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true",undefined,{timeout:15000});
  // A corrupt-save fallback must be tested even if the speed HUD is temporarily unavailable.
  await invalidRecoveryPage.evaluate(()=>document.querySelector('[data-city-speed="0"]')?.click());

  try{await invalidRecoveryPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{polling:1000,timeout:60000})}catch(error){const diagnostic=await invalidRecoveryPage.evaluate(()=>({ready:document.documentElement.dataset.cityReady,rendererReady:window.MshinCity3DReady===true,rendererError:window.MshinCity3DError||null,status:document.querySelector("#cityRenderStatus")?.textContent,canvasCount:document.querySelectorAll("canvas").length,debugReady:Boolean(window.MshinCityDebug),active:localStorage.getItem("mshin-city-save-v2.recovery"),legacy:localStorage.getItem("mshin-city-save-v1.recovery"),backup:localStorage.getItem("mshin-city-save-v2.backup.recovery")}));if(!(diagnostic.ready==="true"&&diagnostic.rendererReady&&diagnostic.status==="3D Renderer Ready"&&diagnostic.canvasCount>=2&&diagnostic.debugReady))throw new Error("city boot did not complete during corrupt-save fallback: "+JSON.stringify({diagnostic,errors:invalidRecoveryErrors})+"; "+error.message)}
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
  try{await noFullscreenPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{polling:1000,timeout:60000})}catch(error){const diagnostic=await noFullscreenPage.evaluate(()=>({ready:document.documentElement.dataset.cityReady,rendererReady:window.MshinCity3DReady===true,status:document.querySelector("#cityRenderStatus")?.textContent,canvasCount:document.querySelectorAll("canvas").length,debugReady:Boolean(window.MshinCityDebug)}));if(!(diagnostic.ready==="true"&&diagnostic.rendererReady&&diagnostic.status==="3D Renderer Ready"&&diagnostic.canvasCount>=2&&diagnostic.debugReady))throw new Error("renderer did not become ready in no-fullscreen fallback: "+JSON.stringify(diagnostic)+"; "+error.message)}
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
  try{await deniedFullscreenPage.waitForFunction(()=>document.documentElement.dataset.cityReady==="true"&&window.MshinCity3DReady===true,undefined,{polling:1000,timeout:60000})}catch(error){const diagnostic=await deniedFullscreenPage.evaluate(()=>({ready:document.documentElement.dataset.cityReady,rendererReady:window.MshinCity3DReady===true,status:document.querySelector("#cityRenderStatus")?.textContent,canvasCount:document.querySelectorAll("canvas").length,debugReady:Boolean(window.MshinCityDebug)}));if(!(diagnostic.ready==="true"&&diagnostic.rendererReady&&diagnostic.status==="3D Renderer Ready"&&diagnostic.canvasCount>=2&&diagnostic.debugReady))throw new Error("renderer did not become ready in denied-fullscreen fallback: "+JSON.stringify(diagnostic)+"; "+error.message)}
  await deniedFullscreenPage.locator("#cityEnterLandscape").click();
  await deniedFullscreenPage.waitForFunction(()=>window.__mshinCityEntryDebug.fullscreenRequested===true,undefined,{timeout:5000});
  await deniedFullscreenPage.setViewportSize({width:844,height:390});
  await deniedFullscreenPage.waitForFunction(()=>window.__mshinCityEntryDebug.entered===true&&document.querySelector("#cityOrientationGate").hidden,undefined,{timeout:10000}).catch(async error=>{
   const diagnostic=await deniedFullscreenPage.evaluate(()=>({debug:window.__mshinCityEntryDebug,hidden:document.querySelector("#cityOrientationGate")?.hidden,orientation:document.documentElement.dataset.cityOrientation,viewport:{width:innerWidth,height:innerHeight},mediaLandscape:matchMedia("(orientation: landscape)").matches,fullscreen:!!document.fullscreenElement}));
   throw new Error("denied-fullscreen landscape fallback did not complete: "+JSON.stringify(diagnostic)+"; "+error.message);
  });
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
