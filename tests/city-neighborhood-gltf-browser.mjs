import { chromium } from "playwright";
import assert from "node:assert/strict";
import { mkdir } from "node:fs/promises";
import path from "node:path";

const browser = await chromium.launch({headless:true,args:["--use-gl=swiftshader","--enable-webgl","--ignore-gpu-blocklist"]});
const errors=[];
const failedRequests=[];
const consoleMessages=[];
try {
 const context=await browser.newContext({viewport:{width:412,height:915},deviceScaleFactor:1,isMobile:true,hasTouch:true});
 const page=await context.newPage();
 page.on("pageerror",error=>errors.push(error.message));
 page.on("console",message=>{if(message.type()==="error"||message.type()==="warning")consoleMessages.push({type:message.type(),text:message.text()});});
 page.on("requestfailed",request=>failedRequests.push({url:request.url(),error:request.failure()?.errorText}));
 const responses=new Map();
 page.on("response",response=>{if(response.url().includes("/assets/city/models/"))responses.set(response.url(),response.status());});
 const response=await page.goto("http://127.0.0.1:4173/city-neighborhood-preview.html",{waitUntil:"domcontentloaded",timeout:30000});
 assert.equal(response?.status(),200,"neighborhood preview route must load");
 try {
  await page.waitForFunction(()=>window.__MSHIN_NEIGHBORHOOD_PREVIEW__?.architectureModels?.size===3 && window.__MSHIN_NEIGHBORHOOD_PREVIEW__?.renderer?.info?.render?.calls>0,null,{timeout:25000});
 } catch (error) {
  const diagnostic=await page.evaluate(()=>({title:document.title,bodyClass:document.body.className,readyState:document.readyState,previewReady:!!window.__MSHIN_NEIGHBORHOOD_PREVIEW__,modelCount:window.__MSHIN_NEIGHBORHOOD_PREVIEW__?.architectureModels?.size,manifestLoaded:performance.getEntriesByType("resource").filter(x=>x.name.includes("/assets/city/models/")).map(x=>x.name)}));
  throw new Error(JSON.stringify({message:error.message,diagnostic,errors,failedRequests,consoleMessages}));
 }
 const runtime=await page.evaluate(()=>{
  const app=window.__MSHIN_NEIGHBORHOOD_PREVIEW__;
  return {models:[...app.architectureModels.keys()],meshCount:app.scene.children.filter(item=>item.isMesh||item.isGroup).length,renderer:app.renderer.info.render,bodyClass:document.body.className};
 });
 assert.deepEqual(runtime.models.sort(),["apartment","house","shop"]);
 assert.ok(runtime.meshCount>=20,"neighborhood scene should contain its architecture and street/landscape meshes");
 assert.ok(runtime.renderer.calls>=1,"WebGL renderer should draw the neighborhood");
 assert.ok(runtime.bodyClass.includes("webgl-ready"),"successful first frame should reveal the 3D scene");
 for(const type of ["house","apartment","shop"]){
  const match=[...responses.entries()].find(([url])=>url.endsWith(`/${type}.gltf`));
  assert.ok(match, `${type} GLTF model should be requested from the local repository`);
  assert.equal(match[1],200,`${type} GLTF model should return HTTP 200`);
 }
 assert.deepEqual(errors,[],"preview must not raise browser page errors");
 assert.deepEqual(failedRequests,[],"preview must not have failed network requests");
 await mkdir("artifacts",{recursive:true});
 await page.screenshot({path:path.resolve("artifacts/city-neighborhood-gltf.png"),fullPage:true});
 console.log(JSON.stringify({status:"passed",models:runtime.models,drawCalls:runtime.renderer.calls,meshCount:runtime.meshCount,screenshot:"artifacts/city-neighborhood-gltf.png"}));
 await context.close();
} finally {
 await browser.close();
}
