import { buildVehicleGeometry } from "./vehicle-showroom-3d.js";
import { PBR_VERTEX, PBR_FRAGMENT, createVehicleEnvironment, VEHICLE_MATERIALS } from "./vehicle-pbr.js";
import { vehicleModelHeading } from "./vehicle-controls.js";
// Native WebGL 3D race renderer. No CDN or external runtime dependency.
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]];
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const norm=v=>{const n=Math.hypot(...v)||1;return v.map(x=>x/n)};
function perspective(f,a,n,fz){const q=1/Math.tan(f/2),d=1/(n-fz);return new Float32Array([q/a,0,0,0,0,q,0,0,0,0,(fz+n)*d,-1,0,0,2*fz*n*d,0])}
function lookAt(eye,target,up){const z=norm(sub(eye,target)),x=norm(cross(up,z)),y=cross(z,x);return new Float32Array([x[0],y[0],z[0],0,x[1],y[1],z[1],0,x[2],y[2],z[2],0,-x.reduce((s,v,i)=>s+v*eye[i],0),-y.reduce((s,v,i)=>s+v*eye[i],0),-z.reduce((s,v,i)=>s+v*eye[i],0),1])}
function mul(a,b){const o=new Float32Array(16);for(let c=0;c<4;c++)for(let r=0;r<4;r++)o[c*4+r]=a[r]*b[c*4]+a[4+r]*b[c*4+1]+a[8+r]*b[c*4+2]+a[12+r]*b[c*4+3];return o}
function translate(x,y,z){return new Float32Array([1,0,0,0,0,1,0,0,0,0,1,0,x,y,z,1])}
function rotateY(a){const c=Math.cos(a),s=Math.sin(a);return new Float32Array([c,0,-s,0,0,1,0,0,s,0,c,0,0,0,0,1])}
function scale(x,y,z){return new Float32Array([x,0,0,0,0,y,0,0,0,0,z,0,0,0,0,1])}
function shader(gl,type,source){const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw new Error(gl.getShaderInfoLog(s)||"3D shader compile failed");return s}
function makeProgram(gl){
 const vertex=shader(gl,gl.VERTEX_SHADER,PBR_VERTEX),fragment=shader(gl,gl.FRAGMENT_SHADER,PBR_FRAGMENT),p=gl.createProgram();
 try{
  gl.attachShader(p,vertex);gl.attachShader(p,fragment);gl.linkProgram(p);
  if(!gl.getProgramParameter(p,gl.LINK_STATUS))throw new Error(gl.getProgramInfoLog(p)||"3D program link failed");
  gl.detachShader(p,vertex);gl.detachShader(p,fragment);gl.deleteShader(vertex);gl.deleteShader(fragment);
  return p;
 }catch(error){
  try{gl.deleteProgram(p)}catch{}
  try{gl.deleteShader(vertex)}catch{}
  try{gl.deleteShader(fragment)}catch{}
  throw error;
 }
}
function makeGeometry(gl,triangles){
  // Preallocate the final interleaved vertex buffer and calculate face normals
  // from scalar coordinates. Avoid per-triangle slice/map/spread allocations.
  const vertexCount=triangles.length/3,data=new Float32Array(vertexCount*6);
  let out=0;
  for(let i=0;i<triangles.length;i+=9){
   const ax=triangles[i],ay=triangles[i+1],az=triangles[i+2];
   const bx=triangles[i+3],by=triangles[i+4],bz=triangles[i+5];
   const cx=triangles[i+6],cy=triangles[i+7],cz=triangles[i+8];
   const abx=bx-ax,aby=by-ay,abz=bz-az,acx=cx-ax,acy=cy-ay,acz=cz-az;
   const nx0=aby*acz-abz*acy,ny0=abz*acx-abx*acz,nz0=abx*acy-aby*acx;
   const inverseLength=1/(Math.hypot(nx0,ny0,nz0)||1);
   const nx=nx0*inverseLength,ny=ny0*inverseLength,nz=nz0*inverseLength;
   for(let vertex=0;vertex<3;vertex++){
    const offset=i+vertex*3;
    data[out++]=triangles[offset];data[out++]=triangles[offset+1];data[out++]=triangles[offset+2];
    data[out++]=nx;data[out++]=ny;data[out++]=nz;
   }
  }
  const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,data,gl.STATIC_DRAW);
  return {buffer,count:vertexCount};
 }
function tri(out,a,b,c){out.push(...a,...b,...c)}
function quad(out,a,b,c,d){tri(out,a,b,c);tri(out,a,c,d)}
function box(out,x,y,z,w,h,d){const x0=x-w/2,x1=x+w/2,y0=y-h/2,y1=y+h/2,z0=z-d/2,z1=z+d/2;quad(out,[x0,y0,z1],[x1,y0,z1],[x1,y1,z1],[x0,y1,z1]);quad(out,[x1,y0,z0],[x0,y0,z0],[x0,y1,z0],[x1,y1,z0]);quad(out,[x0,y0,z0],[x0,y0,z1],[x0,y1,z1],[x0,y1,z0]);quad(out,[x1,y0,z1],[x1,y0,z0],[x1,y1,z0],[x1,y1,z1]);quad(out,[x0,y1,z1],[x1,y1,z1],[x1,y1,z0],[x0,y1,z0]);quad(out,[x0,y0,z0],[x1,y0,z0],[x1,y0,z1],[x0,y0,z1])}
function cylinder(out,x,y,z,r,depth,segments=12){for(let i=0;i<segments;i++){const a=i/segments*Math.PI*2,b=(i+1)/segments*Math.PI*2,p=[x,y+Math.cos(a)*r,z+Math.sin(a)*r],q=[x,y+Math.cos(b)*r,z+Math.sin(b)*r],p2=[x+depth,y+Math.cos(a)*r,z+Math.sin(a)*r],q2=[x+depth,y+Math.cos(b)*r,z+Math.sin(b)*r];quad(out,p,q,q2,p2)}}
function hexColor(value){const h=String(value||"#e94f45").replace("#","");return [0,2,4].map(i=>parseInt(h.slice(i,i+2),16)/255).map(v=>Number.isFinite(v)?v:1)}
const THEMES=[["#7cae48","#333c43","#777f83","#d9c99b"],["#c5a06a","#3e3730","#92785c","#ead2a5"],["#b7e3f1","#596d7b","#d4eff6","#f4fbff"],["#4caa8e","#393d38","#b5a080","#f4dc9d"],["#29284f","#202738","#7d4eaa","#ed45cb"],["#69727a","#333b43","#59636b","#d7a45e"],["#648f78","#3b4146","#79858b","#c9d7ce"],["#c4a66d","#4b4036","#a58b63","#e8d6a5"],["#181d42","#202039","#4c4b79","#54dff1"],["#bb645f","#30394b","#778391","#f3d36a"]];
export function createRaceRenderer(canvas){
 const state={status:"initializing",frames:0,triangles:0,renderer:"WebGL 1",materialPipeline:"automotive-pbr-ggx-clearcoat",environmentMapReady:false,error:null,adSlots:[],maxMeshUploadMs:0,meshUploadCount:0,maxTrackBuildStepMs:0,lastTrackBuildStepMs:0,maxDrawPartMs:0,maxDrawUniformsMs:0,lastDrawUniformsMs:0,maxDrawBufferSetupMs:0,lastDrawBufferSetupMs:0,maxDrawSubmitMs:0,lastDrawSubmitMs:0,maxDrawArraysMs:0,lastDrawArraysMs:0,maxDrawPartVertices:0,lastDrawPartVertices:0,lastDrawPartColor:null,drawPartCount:0,maxTrianglesPerFrame:0,lastFrameTriangles:0,maxVehicleBuildMs:0,lastVehicleBuildMs:0,vehicleBuildCount:0,maxResizeMs:0,lastResizeMs:0,maxClearMs:0,lastClearMs:0,maxRendererRenderMs:0,lastRendererRenderMs:0,softwareRenderer:false,gpuProfile:'detecting',captureNextFrameSample:false,lastFramePixelSample:null,quality:{mobile:false,pixelRatio:1,detail:"high"}};
 let gl,program,uniforms,attributes,softwareRenderer=false,environment=null,road=null,decor=[],surfaceTextures=new Map(),surfaceImages=new Set(),surfaceLoadGeneration=0,rendererDestroyed=false,carPartSets=new Map(),carBuildQueue=[],carBuildQueued=new Set(),lastStage=-1,lastSize="",lost=false,trackBuildJob=null,trackBuildStage=-1,pendingTrackParts=[],trackBuildStarted=0;
  const mobile=matchMedia("(pointer:coarse)").matches||/Android|iPhone|iPad/i.test(navigator.userAgent);
  let cameraEye=null,cameraTarget=null,lastRenderAt=0,qualityScale=1;
  // Create the WebGL context before sizing the canvas. The GPU profile must
  // determine the first drawing-buffer dimensions; otherwise software GPUs
  // allocate a full-resolution buffer and immediately reallocate it.
 try{
  gl=canvas.getContext("webgl",{alpha:false,antialias:!mobile,depth:true,powerPreference:"high-performance",preserveDrawingBuffer:false})||canvas.getContext("experimental-webgl");
  if(!gl)throw new Error("WebGL is unavailable on this device");
  // SwiftShader/llvmpipe execute WebGL on the CPU. Use a deliberately bounded
  // scene and render target there instead of letting one full-resolution PBR
  // frame monopolize the browser main thread during CI or on software GPUs.
  const debugRenderer=gl.getExtension("WEBGL_debug_renderer_info");
  const gpuProfile=debugRenderer?String(gl.getParameter(debugRenderer.UNMASKED_RENDERER_WEBGL)||""):String(gl.getParameter(gl.RENDERER)||"");
  softwareRenderer=/swiftshader|llvmpipe|lavapipe|software raster/i.test(gpuProfile);
  state.softwareRenderer=softwareRenderer;state.gpuProfile=gpuProfile.slice(0,120);
  if(softwareRenderer)qualityScale=.58;
  // This is the only initial framebuffer allocation, now using the detected
  // GPU profile (including the lower software-rendering scale).
  resize();
  program=makeProgram(gl);environment=createVehicleEnvironment(gl);state.environmentMapReady=!!environment;attributes={position:gl.getAttribLocation(program,"aPosition"),normal:gl.getAttribLocation(program,"aNormal")};uniforms={mvp:gl.getUniformLocation(program,"uMvp"),model:gl.getUniformLocation(program,"uModel"),color:gl.getUniformLocation(program,"uBaseColor"),camera:gl.getUniformLocation(program,"uCameraPosition"),light:gl.getUniformLocation(program,"uLightDirection"),lightColor:gl.getUniformLocation(program,"uLightColor"),env:gl.getUniformLocation(program,"uEnvironmentMap"),metal:gl.getUniformLocation(program,"uMetallic"),roughness:gl.getUniformLocation(program,"uRoughness"),clearcoat:gl.getUniformLocation(program,"uClearcoat"),kind:gl.getUniformLocation(program,"uMaterialKind"),emissive:gl.getUniformLocation(program,"uEmissive"),surface:gl.getUniformLocation(program,"uSurfaceTexture"),surfaceEnabled:gl.getUniformLocation(program,"uSurfaceEnabled")};
  // Force the browser/driver to compile and execute the linked shader pipeline
  // before the first countdown frame. Some headless and mobile GPUs defer this
  // work until the first real draw, producing a multi-second gameplay hitch.
  const warmupStarted=performance.now(),warmupBuffer=gl.createBuffer();
  const warmupVertices=new Float32Array([
   -0.5,-0.5,0,0,0,1,
    0.5,-0.5,0,0,0,1,
    0,0.5,0,0,0,1
  ]);
  gl.useProgram(program);gl.bindBuffer(gl.ARRAY_BUFFER,warmupBuffer);
  gl.bufferData(gl.ARRAY_BUFFER,warmupVertices,gl.STATIC_DRAW);
  gl.enableVertexAttribArray(attributes.position);gl.vertexAttribPointer(attributes.position,3,gl.FLOAT,false,24,0);
  gl.enableVertexAttribArray(attributes.normal);gl.vertexAttribPointer(attributes.normal,3,gl.FLOAT,false,24,12);
  const identity=new Float32Array([1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]);
  gl.uniformMatrix4fv(uniforms.mvp,false,identity);gl.uniformMatrix4fv(uniforms.model,false,identity);
  gl.uniform3f(uniforms.color,.5,.6,.7);gl.uniform3f(uniforms.camera,0,0,2);gl.uniform3f(uniforms.light,-.4,.8,.4);gl.uniform3f(uniforms.lightColor,3,3,3);gl.uniform1f(uniforms.metal,.5);gl.uniform1f(uniforms.roughness,.4);gl.uniform1f(uniforms.clearcoat,.5);gl.uniform1f(uniforms.kind,1);gl.uniform1f(uniforms.emissive,0);gl.uniform1i(uniforms.surface,1);gl.uniform1f(uniforms.surfaceEnabled,0);gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_CUBE_MAP,environment);gl.uniform1i(uniforms.env,0);
  gl.viewport(0,0,1,1);gl.drawArrays(gl.TRIANGLES,0,3);gl.finish();
  gl.deleteBuffer(warmupBuffer);gl.bindBuffer(gl.ARRAY_BUFFER,null);
  state.pipelineWarmupMs=performance.now()-warmupStarted;
  gl.enable(gl.DEPTH_TEST);gl.disable(gl.CULL_FACE);gl.enable(gl.POLYGON_OFFSET_FILL);gl.polygonOffset(1,1);
  state.status="webgl-ready";
 }catch(e){state.status="unavailable";state.error=String(e?.message||e);return {state,render(){},destroy(){}}}
 function createProceduralSurfacePixels(key,size=128){
  const pixels=new Uint8Array(size*size*4);
  const palettes={asphalt:[74,78,80],grass:[91,137,57],sand:[177,151,104],snow:[205,216,222],rock:[105,105,99],concrete:[126,128,126],bark:[91,65,43],foliage:[83,126,55]};
  const base=palettes[key]||[128,128,128];
  const hash=(x,y)=>{let n=(x*374761393+y*668265263+key.length*1442695041)|0;n=(n^(n>>>13))*1274126177;return ((n^(n>>>16))>>>0)/4294967295};
  for(let y=0;y<size;y++)for(let x=0;x<size;x++){
   const broad=Math.sin(x*.105+Math.sin(y*.071)*2.1)*Math.cos(y*.087+x*.023);
   const grain=(hash(x,y)-.5)*34+(hash(x>>2,y>>2)-.5)*19+broad*7;
   const i=(y*size+x)*4;
   for(let channel=0;channel<3;channel++){
    let value=base[channel]+grain;
    if(key==="asphalt"&&hash(x*3,y*3)>.94)value-=28;
    if(key==="grass")value+=Math.sin((x+y)*.17)*5;
    if(key==="snow")value+=Math.max(0,broad)*7;
    pixels[i+channel]=Math.max(0,Math.min(255,Math.round(value)));
   }
   pixels[i+3]=255;
  }
  return pixels;
}
 function loadSurfaceTexture(key,url){
  const generation=surfaceLoadGeneration,texture=gl.createTexture();
  if(!texture){state.surfaceTextures.failed++;return}
  gl.bindTexture(gl.TEXTURE_2D,texture);
  // Neutral fallback is immediately usable; remote textures never gate racing.
  const fallbackSize=128;
  gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,fallbackSize,fallbackSize,0,gl.RGBA,gl.UNSIGNED_BYTE,createProceduralSurfacePixels(key,fallbackSize));
  gl.generateMipmap(gl.TEXTURE_2D);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR_MIPMAP_LINEAR);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.REPEAT);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.REPEAT);
  surfaceTextures.set(key,texture);
  // Avoid spending mobile bandwidth/CPU on software renderers or data-saver sessions.
  if(softwareRenderer||navigator.connection?.saveData){state.surfaceTextures.skipped++;return}
  const image=new Image();surfaceImages.add(image);image.crossOrigin="anonymous";image.decoding="async";
  let settled=false;
  const finish=()=>{settled=true;clearTimeout(timer);surfaceImages.delete(image)};
  const timer=setTimeout(()=>{
   if(settled)return;finish();image.onload=null;image.onerror=null;image.src="";
   if(generation===surfaceLoadGeneration&&!rendererDestroyed){state.surfaceTextures.failed++;state.surfaceTextures.errors.push("CDN texture timed out: "+key)}
  },6500);
  image.onload=()=>{
   if(settled)return;finish();
   if(rendererDestroyed||lost||generation!==surfaceLoadGeneration)return;
   try{
    gl.bindTexture(gl.TEXTURE_2D,texture);gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,true);
    gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,image);gl.generateMipmap(gl.TEXTURE_2D);
    gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR_MIPMAP_LINEAR);state.surfaceTextures.loaded++;
   }catch(error){state.surfaceTextures.failed++;state.surfaceTextures.errors.push(String(error?.message||error))}
  };
  image.onerror=()=>{
   if(settled)return;finish();
   if(generation===surfaceLoadGeneration&&!rendererDestroyed){state.surfaceTextures.failed++;state.surfaceTextures.errors.push("CDN texture failed: "+key)}
  };
  image.src=url;
 }
 const surfaceSources={
  asphalt:"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/asphalt_03/asphalt_03_diff_1k.jpg",
  grass:"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/grass_ground/grass_ground_diff_1k.jpg",
  sand:"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/sand_01/sand_01_diff_1k.jpg",
  snow:"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/snow_03/snow_03_diff_1k.jpg",
  rock:"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/rocky_terrain_02/rocky_terrain_02_diff_1k.jpg",
  concrete:"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/concrete_floor_02/concrete_floor_02_diff_1k.jpg",
  bark:"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/bark_brown_02/bark_brown_02_diff_1k.jpg",
  foliage:"https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/leafy_grass/leafy_grass_diff_1k.jpg"
 };
 state.surfaceTextures={provider:"Poly Haven CDN",license:"CC0",requested:Object.keys(surfaceSources).length,loaded:0,failed:0,skipped:0,errors:[]};
 for(const [key,url] of Object.entries(surfaceSources))loadSurfaceTexture(key,url);
 function part(tris,color,emissive=0,materialName="environment",surfaceKey=null){const material=VEHICLE_MATERIALS[materialName]||{metallic:.06,roughness:.78,clearcoat:0,kind:0},started=performance.now(),mesh=makeGeometry(gl,tris),elapsed=performance.now()-started;state.maxMeshUploadMs=Math.max(state.maxMeshUploadMs||0,elapsed);state.meshUploadCount=(state.meshUploadCount||0)+1;return {mesh,color:hexColor(color),...material,emissive,texture:surfaceKey?surfaceTextures.get(surfaceKey)||null:null}}
 function disposeParts(parts){for(const item of parts){const buffer=item?.mesh?.buffer;if(buffer){try{gl.deleteBuffer(buffer)}catch{}}}}
 function* buildTrack(snapshot){
  const nextDecor=[];
  const theme=THEMES[snapshot.world||0],roadTris=[],shoulderTris=[],laneTris=[],yellowTris=[],curbRedTris=[],curbWhiteTris=[],groundTris=[];
  const terrainTexture=["grass","sand","snow","grass","rock","rock","grass","sand","rock","grass"][snapshot.world||0]||"grass";
  const segments=mobile?280:softwareRenderer?360:760,half=180;
  // Keep the playable terrain inside the camera far plane and wind its triangles upward.
  // The previous 130 km quad had downward-facing normals and corners beyond the
  // 60 km far plane, so mobile GPUs could clip/darken the entire ground surface.
  quad(groundTris,[-30000,-40,-30000],[-30000,-40,30000],[30000,-40,30000],[30000,-40,-30000]);
  for(let i=0;i<segments;i++){
   const a=i/segments*Math.PI*2,b=(i+1)/segments*Math.PI*2,fa=snapshot.frameAt(a),fb=snapshot.frameAt(b);
   const point=(f,offset,y=0)=>[f.p.x+f.nx*offset,(f.height||0)+y,-(f.p.y+f.ny*offset)];
   const l0=point(fa,-half),r0=point(fa,half),l1=point(fb,-half),r1=point(fb,half);
   const sl0=point(fa,-half-26,-.04),sr0=point(fa,half+26,-.04),sl1=point(fb,-half-26,-.04),sr1=point(fb,half+26,-.04);
   quad(roadTris,l0,l1,r1,r0);quad(shoulderTris,sl0,sl1,l1,l0);quad(shoulderTris,r0,r1,sr1,sr0);
   // Continuous white edge lines, twin dashed yellow centre lines and alternating kerbs.
   for(const offset of [-158,158]){const p0=point(fa,offset-1.8,.018),q0=point(fa,offset+1.8,.018),p1=point(fb,offset-1.8,.018),q1=point(fb,offset+1.8,.018);quad(laneTris,p0,p1,q1,q0)}
   if(i%2===0)for(const offset of [-5,5]){const p0=point(fa,offset-1.25,.02),q0=point(fa,offset+1.25,.02),p1=point(fb,offset-1.25,.02),q1=point(fb,offset+1.25,.02);quad(yellowTris,p0,p1,q1,q0)}
   const curbSide=(side,out)=>{const p0=point(fa,side*168,.026),q0=point(fa,side*180,.026),p1=point(fb,side*168,.026),q1=point(fb,side*180,.026);quad(out,p0,p1,q1,q0)};
   curbSide(-1,Math.floor(i/4)%2?curbWhiteTris:curbRedTris);curbSide(1,Math.floor(i/4)%2?curbWhiteTris:curbRedTris)
   const outerL=point(fa,-half-26,-.12),outerR=point(fa,half+26,-.12),outerL1=point(fb,-half-26,-.12),outerR1=point(fb,half+26,-.12);
   quad(groundTris,outerL,outerL1,outerR1,outerR);
  }
  // Track surfaces must remain legible even when the device uses SwiftShader or
  // a mobile GPU with weak/approximate fragment precision. Environment meshes
  // therefore carry a restrained emissive floor: direct/IBL lighting can enrich
  // them, but a bad normal or missing cubemap can no longer erase the circuit.
  const nextRoad=part(roadTris,theme[1],.92,"environment","asphalt");
  nextDecor.push(
   part(shoulderTris,theme[2],.62,"environment","concrete"),
   part(laneTris,"#f4f3e9",.78),
   part(yellowTris,"#f5c928",.82),
   part(curbRedTris,"#d94337",.72),
   part(curbWhiteTris,"#f1eee4",.78),
   part(groundTris,theme[0],.16,"environment",terrainTexture)
  );
  yield {parts:[nextRoad,...nextDecor],progress:.34};
  state.petCoats=[];const treeTrunks=[],treeFoliage=[],buildings=[],houses=[],shops=[],windows=[],doors=[],roofTris=[],landscape=[],treeShadows=[],buildingShadows=[],railTris=[],crowdBodies=[],crowdHeads=[],crowdLegs=[],crowdArms=[],petBodies=[],petHeads=[],petLegs=[],petEars=[],petTails=[],billboardPosts=[],billboardFaces=[],billboardFrames=[],billboardAccents=[],billboardSlots=[];
  const urban=[4,5,8].includes(snapshot.world||0),treeCount=mobile?18:softwareRenderer?22:48,buildingCount=mobile?8:softwareRenderer?12:22;
  const sphere=(out,cx,cy,cz,rx,ry,rz,segments=8,rings=5)=>{for(let r=0;r<rings;r++){const p0=-Math.PI/2+r*Math.PI/rings,p1=-Math.PI/2+(r+1)*Math.PI/rings;for(let s=0;s<segments;s++){const a=s*Math.PI*2/segments,b=(s+1)*Math.PI*2/segments,pt=(p,t)=>[cx+Math.cos(p)*Math.cos(t)*rx,cy+Math.sin(p)*ry,cz+Math.cos(p)*Math.sin(t)*rz];quad(out,pt(p0,a),pt(p0,b),pt(p1,b),pt(p1,a));}}};
  // Full 3D sky dome, layered cloud banks and a soft sun; drawn first so terrain occludes it naturally.
  const skyTris=[],cloudTris=[],sunTris=[];
  sphere(skyTris,0,0,0,56000,30000,56000,mobile?20:36,mobile?10:18);
  for(let i=0;i<(mobile?5:12);i++){const a=i/12*Math.PI*2,r=19000+(i%3)*2100,x=Math.cos(a)*r,y=7600+(i%4)*950,z=Math.sin(a)*r;sphere(cloudTris,x,y,z,2800+(i%3)*550,580+(i%2)*250,1250+(i%4)*280,mobile?8:14,mobile?4:7);sphere(cloudTris,x+1250,y+180,z-350,1850,460,900,mobile?8:12,mobile?4:6);}
  sphere(sunTris,-22000,19000,-24500,1750,1750,1750,16,10);
  nextDecor.push(part(skyTris,"#70b7ee",.42),part(cloudTris,"#f3f8ff",.22),part(sunTris,"#fff0bd",.72));
  yield {progress:.39};

  const disk=(out,x,y,z,r,segments=12)=>{for(let j=0;j<segments;j++){const a=j/segments*Math.PI*2,b=(j+1)/segments*Math.PI*2;tri(out,[x,y,z],[x+Math.cos(a)*r,y,z+Math.sin(a)*r],[x+Math.cos(b)*r,y,z+Math.sin(b)*r]);}};
  // A layered distant terrain silhouette gives every biome a readable horizon.
  for(let i=0;i<(mobile?32:72);i++){const count=mobile?32:72,a=i/count*Math.PI*2,r=27800+(i%5)*1900,x=Math.cos(a)*r,z=Math.sin(a)*r,h=(68+(i%7)*24)*10;const hill=[];sphere(hill,x,h*.34,z,(250+(i%4)*48)*10,h,(220+(i%3)*38)*10,mobile?9:16,mobile?5:8);landscape.push(...hill);if(i%4===3)yield {progress:.4+(i/(mobile?32:72))*.05}}
  for(let i=0;i<treeCount;i++){const t=i/(mobile?24:70)*Math.PI*2,f=snapshot.frameAt(t),side=i%2?1:-1,dist=270+(i%7)*66,x=f.p.x+f.nx*side*dist,z=-(f.p.y+f.ny*side*dist),base=f.height||0;
   disk(treeShadows,x,base+.6,z,24+(i%3)*4,10);
   // Trunk, branching limbs and layered foliage; mobile uses fewer repeated instances.
   box(treeTrunks,x,base+19,z,8,38,8);cylinder(treeTrunks,x-12,base+25,z,3,22,7);cylinder(treeTrunks,x+8,base+32,z,3,19,7);
   const foliage=[];sphere(foliage,x,base+48,z,22+(i%4)*4,28+(i%3)*5,22+(i%4)*4,mobile?8:12,mobile?5:7);sphere(foliage,x-13,base+62,z-4,16,19,16,7,5);sphere(foliage,x+12,base+59,z+5,17,20,17,7,5);treeFoliage.push(...foliage);if(i%4===3)yield {progress:.46+(i/treeCount)*.06};
  }
  // Residential blocks: pitched roof silhouettes, recessed doors, glazing and porches.
  for(let i=0;i<buildingCount;i++){const t=(i+.25)/buildingCount*Math.PI*2,f=snapshot.frameAt(t),side=i%2?1:-1,dist=520+(i%4)*125,x=f.p.x+f.nx*side*dist,z=-(f.p.y+f.ny*side*dist),base=f.height||0,w=96+(i%3)*22,h=58+(i%4)*12,d=84+(i%2)*18;
   disk(buildingShadows,x,base+.5,z,58,12);
   if(urban){box(buildings,x,base+h/2,z,w,h,d);box(roofTris,x,base+h+5,z,w+10,10,d+10);for(let floor=0;floor<Math.max(1,Math.floor(h/28));floor++)for(let sideX of [-1,1]){box(windows,x+sideX*w*.27,base+17+floor*25,z+d/2+.8,13,12,2);box(windows,x+sideX*w*.27,base+17+floor*25,z-d/2-.8,13,12,2)}}
   else{box(houses,x,base+h/2,z,w,h,d);const roof=[];const eave=base+h,peak=eave+40;tri(roof,[x-w/2-7,eave,z-d/2-7],[x+w/2+7,eave,z-d/2-7],[x,peak,z-d/2-7]);tri(roof,[x+w/2+7,eave,z+d/2+7],[x-w/2-7,eave,z+d/2+7],[x,peak,z+d/2+7]);tri(roof,[x-w/2-7,eave,z-d/2-7],[x-w/2-7,eave,z+d/2+7],[x,peak,z]);tri(roof,[x+w/2+7,eave,z+d/2+7],[x+w/2+7,eave,z-d/2-7],[x,peak,z]);roofTris.push(...roof);
    box(doors,x,base+14,z+d/2+1,13,28,2);for(const wx of [-w*.28,w*.28]){box(windows,x+wx,base+27,z+d/2+1,15,14,2);box(windows,x+wx,base+27,z+d/2+2,2,14,1);box(windows,x+wx,base+27,z+d/2+2,15,2,1)}}
  }
  yield {progress:.56};
  // Small roadside shops with awnings, display windows and a sign fascia.
  const shopCount=mobile?3:7;for(let i=0;i<shopCount;i++){const t=(i+.4)/shopCount*Math.PI*2,f=snapshot.frameAt(t),side=i%2?1:-1,x=f.p.x+f.nx*side*(690+(i%3)*75),z=-(f.p.y+f.ny*side*(690+(i%3)*75)),base=f.height||0;box(shops,x,base+38,z,116,76,76);box(shops,x,base+79,z+39,132,10,10);box(shops,x,base+60,z+43,132,20,11);box(windows,x,base+36,z+40,76,32,3);box(doors,x-43,base+29,z+42,18,56,4);box(roofTris,x,base+84,z,138,7,86);if(i%2===1)yield {progress:.58+(i/shopCount)*.03}}
  // Spectators with distinct torso, head, arms and legs rather than flat crowd blocks.
  const spectatorCount=mobile?10:softwareRenderer?14:36;for(let i=0;i<spectatorCount;i++){const t=(i+.5)/(mobile?16:54)*Math.PI*2,f=snapshot.frameAt(t),side=i%2?1:-1,offset=242+(i%4)*16,x=f.p.x+f.nx*side*offset,z=-(f.p.y+f.ny*side*offset),base=f.height||0;box(crowdBodies,x,base+28,z,10,22,8);sphere(crowdHeads,x,base+45,z,6,7,6,7,4);box(crowdArms,x-9,base+30,z,4,18,4);box(crowdArms,x+9,base+30,z,4,18,4);box(crowdLegs,x-3,base+12,z,4,13,5);box(crowdLegs,x+3,base+12,z,4,13,5);if(i%4===3)yield {progress:.62+(i/spectatorCount)*.02}}
  // Leashed dogs and cats near spectator lawns: four-legged silhouettes, tails and ears.
  const petCount=mobile?3:9;for(let i=0;i<petCount;i++){const t=(i+.7)/petCount*Math.PI*2,f=snapshot.frameAt(t),side=i%2?1:-1,x=f.p.x+f.nx*side*(305+(i%3)*22),z=-(f.p.y+f.ny*side*(305+(i%3)*22)),base=f.height||0,cat=i%2===1,coat=cat?"#777b83":"#b88c5c";sphere(petBodies,x,base+9,z,cat?13:18,8,cat?8:10,8,4);sphere(petHeads,x+13,base+14,z,8,8,8,8,4);for(const lx of [-8,7])for(const lz of [-5,5])box(petLegs,x+lx,base+3,z+lz,3,8,3);sphere(petTails,x-17,base+15,z-4,cat?3:4,cat?12:10,3,6,3);for(const ex of [-4,4]){const ear=[];tri(ear,[x+13+ex,base+19,z],[x+13+ex+3,base+14,z+2],[x+13+ex+1,base+27,z]);petEars.push(...ear)}if(!state.petCoats)state.petCoats=[];state.petCoats.push(coat);yield {progress:.65+(i/petCount)*.015}}
  // Soft contact-shadow decals sit directly on the ground under structures.
  state.environmentCounts={trees:treeCount,houses:urban?0:buildingCount,shops:shopCount,buildings:urban?buildingCount:0,spectators:spectatorCount,dogs:Math.ceil(petCount/2),cats:Math.floor(petCount/2),contactShadows:treeCount+buildingCount};
  yield {parts:[nextRoad,...nextDecor],progress:.67};
  const totalRailSegments=mobile?20:60;
  let railSegmentsBuilt=0;
  for(let i=0;i<360;i+=(mobile?18:softwareRenderer?12:6)){
   const a=i/360*Math.PI*2,b=(i+1)/360*Math.PI*2,fa=snapshot.frameAt(a),fb=snapshot.frameAt(b);
   for(const side of [-1,1]){
    const offset=side*(half+15),p0=[fa.p.x+fa.nx*offset,(fa.height||0)+12,-(fa.p.y+fa.ny*offset)],p1=[fb.p.x+fb.nx*offset,(fb.height||0)+12,-(fb.p.y+fb.ny*offset)],q0=[p0[0],p0[1]+19,p0[2]],q1=[p1[0],p1[1]+19,p1[2]];
    quad(railTris,p0,p1,q1,q0);
   }
   if(++railSegmentsBuilt%(mobile?2:12)===0)yield {progress:.67+.003*(railSegmentsBuilt/totalRailSegments)};
  }
  const extraCrowdCount=mobile?10:36;
  for(let i=0;i<extraCrowdCount;i++){
   const t=(i+.5)/(mobile?16:54)*Math.PI*2,f=snapshot.frameAt(t),side=i%2?1:-1,offset=238+(i%4)*13,x=f.p.x+f.nx*side*offset,z=-(f.p.y+f.ny*side*offset),base=f.height||0;
   box(crowdBodies,x,base+27,z,11,20,8);box(crowdBodies,x-7,base+27,z,5,17,5);box(crowdBodies,x+7,base+27,z,5,17,5);
   box(crowdHeads,x,base+43,z,9,9,9);box(crowdLegs,x-3,base+12,z,5,13,6);box(crowdLegs,x+3,base+12,z,5,13,6);
   if(i%4===3)yield {progress:.673+.002*(i/extraCrowdCount)};
  }

  // Trackside advertising inventory: permanent, camera-visible 3D placements.
  // Each slot has a stable world-scoped ID for a future sponsor artwork/booking system.
  const billboardCount=mobile?8:20;
  for(let i=0;i<billboardCount;i++){
   const t=(i+.5)/billboardCount*Math.PI*2,f=snapshot.frameAt(t),side=i%2?1:-1;
   const offset=270,base=f.height||0,nx=f.nx*side,nz=-f.ny*side,tx=f.ny,tz=f.nx;
   const cx=f.p.x+nx*offset,cz=-(f.p.y+f.ny*side*offset),halfWidth=52,low=base+49,high=base+81;
   const point=(along,y,depth=0)=>[cx+tx*along+nx*depth,y,cz+tz*along+nz*depth];
   const a=point(-halfWidth,low,.5),b=point(halfWidth,low,.5),c=point(halfWidth,high,.5),d=point(-halfWidth,high,.5);
   quad(billboardFaces,a,b,c,d);
   // Bright aluminum frame and two restrained racing-red trim bands.
   quad(billboardFrames,point(-halfWidth-3,low-3,.9),point(halfWidth+3,low-3,.9),point(halfWidth+3,low+1,.9),point(-halfWidth-3,low+1,.9));
   quad(billboardFrames,point(-halfWidth-3,high-1,.9),point(halfWidth+3,high-1,.9),point(halfWidth+3,high+3,.9),point(-halfWidth-3,high+3,.9));
   quad(billboardFrames,point(-halfWidth-3,low,.9),point(-halfWidth+1,low,.9),point(-halfWidth+1,high,.9),point(-halfWidth-3,high,.9));
   quad(billboardFrames,point(halfWidth-1,low,.9),point(halfWidth+3,low,.9),point(halfWidth+3,high,.9),point(halfWidth-1,high,.9));
   quad(billboardAccents,point(-halfWidth+5,high-5,1.1),point(halfWidth-5,high-5,1.1),point(halfWidth-5,high-1,1.1),point(-halfWidth+5,high-1,1.1));
   quad(billboardAccents,point(-halfWidth+5,low+2,1.1),point(halfWidth-5,low+2,1.1),point(halfWidth-5,low+6,1.1),point(-halfWidth+5,low+6,1.1));
   // A clean center panel remains intentionally unbranded for future paid creatives.
   quad(billboardAccents,point(-24,base+62,1.15),point(-13,base+62,1.15),point(-13,base+68,1.15),point(-24,base+68,1.15));
   quad(billboardAccents,point(-5,base+62,1.15),point(6,base+62,1.15),point(6,base+68,1.15),point(-5,base+68,1.15));
   quad(billboardAccents,point(14,base+62,1.15),point(25,base+62,1.15),point(25,base+68,1.15),point(14,base+68,1.15));
   for(const along of [-43,43]){
    const foot=point(along,base+21,-1);
    box(billboardPosts,foot[0],base+24,foot[2],7,48,7);
    box(billboardPosts,foot[0],base+3,foot[2],17,6,17);
   }
   billboardSlots.push({id:`world-${snapshot.world||0}-trackside-${String(i+1).padStart(2,"0")}`,world:snapshot.world||0,side,format:"trackside-3d",width:104,height:32,available:true,creative:null});
   if(i%2===1)yield {progress:.675+.004*(i/billboardCount)};
  }
  state.adSlots=billboardSlots;
  // Convert and upload large procedural meshes in bounded GPU batches. Building
  // the scene arrays is cheap compared with normal generation + bufferData for
  // one enormous mesh; keep each render() call below a small upload budget.
  const uploadQueue=[
   [landscape,"#778b78",0,terrainTexture],[treeShadows,"#26332b"],[buildingShadows,"#303a35"],[treeTrunks,"#70533b",0,"bark"],[treeFoliage,theme[3],0,"foliage"],
   [houses,"#d6c6a4",0,"concrete"],[buildings,urban?"#5c4d85":"#747b82",0,"concrete"],[roofTris,urban?"#343b4a":"#9b5942",0,"concrete"],
   [windows,"#8ec7d4",.05],[doors,"#493b34"],[shops,"#c8b08b",0,"concrete"],[crowdBodies,"#e85b47"],
   [crowdHeads,"#d4a47e"],[crowdArms,"#e2b18c"],[crowdLegs,"#263344"],[petBodies,"#b88c5c"],
   [petHeads,"#b88c5c"],[petLegs,"#75543c"],[petEars,"#8b5d4a"],[petTails,"#8b5d4a"],
   [billboardPosts,"#303d4b"],[billboardFaces,"#17324b"],[billboardFrames,"#d9e2e8"],
   [billboardAccents,"#ed344e",.12],[railTris,"#d9dfe2"]
  ];
  const uploadValues=uploadQueue.reduce((sum,item)=>sum+item[0].length,0);
  const maxUploadValues=4096*9;
  let uploadedValues=0;
  for(const [vertices,color,emissive=0,surfaceKey=null] of uploadQueue){
   for(let offset=0;offset<vertices.length;offset+=maxUploadValues){
    const end=Math.min(vertices.length,offset+maxUploadValues);
    nextDecor.push(part(vertices.slice(offset,end),color,emissive,"environment",surfaceKey));
    uploadedValues+=end-offset;
    yield {parts:[nextRoad,...nextDecor],progress:.68+.30*(uploadedValues/Math.max(1,uploadValues))};
   }
  }
  return {road:nextRoad,decor:nextDecor,stageId:snapshot.stageId};
 }
 function cancelTrackBuild(){if(pendingTrackParts.length)disposeParts(pendingTrackParts);pendingTrackParts=[];trackBuildJob=null;trackBuildStage=-1;}
 const VEHICLE_SHAPES={
 rally:{width:1,length:1,bodyY:1,cabinWidth:1,cabinY:1,cabinHeight:1,wheelRadius:14,wheelX:35,wheelZ:39,wing:1,style:"rally"},
 comet:{width:1.03,length:1.14,bodyY:.84,cabinWidth:.9,cabinY:.83,cabinHeight:.72,wheelRadius:13,wheelX:36,wheelZ:44,wing:1.15,style:"gt"},
 lynx:{width:1.13,length:1,bodyY:1.22,cabinWidth:1.08,cabinY:1.2,cabinHeight:1.24,wheelRadius:17,wheelX:39,wheelZ:39,wing:.25,style:"suv"},
 thunder:{width:1.08,length:1.06,bodyY:.86,cabinWidth:.92,cabinY:.84,cabinHeight:.74,wheelRadius:14,wheelX:37,wheelZ:41,wing:.45,style:"electric"},
 raptor:{width:1.17,length:1.04,bodyY:1.12,cabinWidth:1.04,cabinY:1.1,cabinHeight:1.08,wheelRadius:19,wheelX:41,wheelZ:41,wing:.55,style:"offroad"},
 "ai-formula":{width:.9,length:1.2,bodyY:.72,cabinWidth:.48,cabinY:.75,cabinHeight:.5,wheelRadius:19,wheelX:43,wheelZ:48,wing:1.5,style:"formula"},
 "ai-pickup":{width:1.12,length:1.12,bodyY:1.12,cabinWidth:.98,cabinY:1.08,cabinHeight:1.05,wheelRadius:17,wheelX:40,wheelZ:43,wing:.15,style:"pickup"},
 "ai-rallycross":{width:1.1,length:1.04,bodyY:1.08,cabinWidth:.98,cabinY:1.04,cabinHeight:.96,wheelRadius:16,wheelX:39,wheelZ:41,wing:1.1,style:"rallycross"},
 "ai-touring":{width:1.08,length:1.02,bodyY:1,cabinWidth:1.05,cabinY:1,cabinHeight:.94,wheelRadius:15,wheelX:38,wheelZ:40,wing:.8,style:"touring"},
 "ai-prototype":{width:1,length:1.22,bodyY:.78,cabinWidth:.78,cabinY:.78,cabinHeight:.62,wheelRadius:15,wheelX:38,wheelZ:48,wing:1.25,style:"prototype"}
 };
 const AI_VEHICLE_SHAPES=["ai-formula","ai-pickup","ai-rallycross","ai-touring","ai-prototype"];
 function vehicleShapeFor(kind,id){return kind==="player"?(VEHICLE_SHAPES[id]?id:"rally"):AI_VEHICLE_SHAPES[Math.abs(Number(id)||0)%5]}
 function buildCar(id="rally"){
  // Race scene and showroom consume the same detailed procedural mesh builder.
  const started=performance.now(),geometry=buildVehicleGeometry(id),parts=geometry.map(item=>part(item.vertices,item.paint,item.emissive,item.material)),elapsed=performance.now()-started;
  state.lastVehicleBuildMs=elapsed;state.maxVehicleBuildMs=Math.max(state.maxVehicleBuildMs||0,elapsed);state.vehicleBuildCount=(state.vehicleBuildCount||0)+1;
  return parts;
 }
 function getCarParts(id){
  if(carPartSets.has(id))return carPartSets.get(id);
  if(carPartSets.size===0){const parts=buildCar(id);carPartSets.set(id,parts);return parts;}
  if(!carBuildQueued.has(id)){carBuildQueued.add(id);carBuildQueue.push(id);}
  return carPartSets.values().next().value;
 }
 function resize(){const started=performance.now(),portrait=matchMedia("(orientation: portrait)").matches,cssWidth=portrait?innerHeight:innerWidth,cssHeight=portrait?innerWidth:innerHeight,dpr=Math.min(devicePixelRatio||1,mobile?.68:1.5)*qualityScale,w=Math.max(1,Math.round(cssWidth*dpr)),h=Math.max(1,Math.round(cssHeight*dpr)),key=w+"x"+h;if(key===lastSize){const elapsed=performance.now()-started;state.maxResizeMs=Math.max(state.maxResizeMs||0,elapsed);return}lastSize=key;canvas.width=w;canvas.height=h;gl.viewport(0,0,w,h);state.quality={mobile,pixelRatio:dpr,detail:mobile?"mobile-balanced":softwareRenderer?"software-balanced":"high",renderScale:qualityScale,width:w,height:h};const elapsed=performance.now()-started;state.lastResizeMs=elapsed;state.maxResizeMs=Math.max(state.maxResizeMs||0,elapsed)}
 function drawPart(p,vp,model){const started=performance.now(),uniformStarted=started;gl.activeTexture(gl.TEXTURE1);gl.bindTexture(gl.TEXTURE_2D,p.texture||null);gl.uniform1i(uniforms.surface,1);gl.uniform1f(uniforms.surfaceEnabled,p.texture?1:0);gl.uniformMatrix4fv(uniforms.model,false,model);gl.uniformMatrix4fv(uniforms.mvp,false,mul(vp,model));gl.uniform3fv(uniforms.color,p.color);gl.uniform1f(uniforms.metal,p.metallic);gl.uniform1f(uniforms.roughness,p.roughness);gl.uniform1f(uniforms.clearcoat,p.clearcoat);gl.uniform1f(uniforms.kind,p.kind);gl.uniform1f(uniforms.emissive,p.emissive);const uniformMs=performance.now()-uniformStarted,bufferStarted=performance.now();gl.bindBuffer(gl.ARRAY_BUFFER,p.mesh.buffer);gl.enableVertexAttribArray(attributes.position);gl.vertexAttribPointer(attributes.position,3,gl.FLOAT,false,24,0);gl.enableVertexAttribArray(attributes.normal);gl.vertexAttribPointer(attributes.normal,3,gl.FLOAT,false,24,12);const bufferSetupMs=performance.now()-bufferStarted,drawStarted=performance.now();gl.drawArrays(gl.TRIANGLES,0,p.mesh.count);const drawArraysMs=performance.now()-drawStarted,elapsed=performance.now()-started;state.maxDrawUniformsMs=Math.max(state.maxDrawUniformsMs||0,uniformMs);state.lastDrawUniformsMs=uniformMs;state.maxDrawBufferSetupMs=Math.max(state.maxDrawBufferSetupMs||0,bufferSetupMs);state.lastDrawBufferSetupMs=bufferSetupMs;state.maxDrawSubmitMs=Math.max(state.maxDrawSubmitMs||0,drawArraysMs);state.lastDrawSubmitMs=drawArraysMs;state.maxDrawArraysMs=Math.max(state.maxDrawArraysMs||0,drawArraysMs);state.lastDrawArraysMs=drawArraysMs;state.maxDrawPartVertices=Math.max(state.maxDrawPartVertices||0,p.mesh.count);state.lastDrawPartVertices=p.mesh.count;state.lastDrawPartColor=p.color;state.maxDrawPartMs=Math.max(state.maxDrawPartMs||0,elapsed);state.drawPartCount=(state.drawPartCount||0)+1;state.triangles+=p.mesh.count/3}
 function drawVehicle(t,lateral,yaw,color,damage=0,kind="car",vehicleId=0,snapshot){
  const f=snapshot.frameAt(t),x=f.p.x+f.nx*lateral,z=-(f.p.y+f.ny*lateral),heading=vehicleModelHeading(f.angle,yaw);
  const carParts=getCarParts(vehicleShapeFor(kind,vehicleId));
  const model=mul(translate(x,f.height||0,z),rotateY(heading));carParts[0].color=hexColor(color);
  for(let i=0;i<carParts.length;i++)drawPart(carParts[i],vp,model);
  
 }
 let vp,partCacheSmoke;
 const visibleRivals=[],visibleDistances=[];
 function render(snapshot){
  if(!gl||lost||!snapshot||!["race","countdown","paused"].includes(snapshot.state))return;
  const rendererStarted=performance.now(),drawCountAtStart=state.drawPartCount||0;
  resize();
  const playerProfile=vehicleShapeFor("player",snapshot.player.modelId);
  if(!carPartSets.has(playerProfile))carPartSets.set(playerProfile,buildCar(playerProfile));
  // Build at most one additional vehicle mesh set per frame. The player car
  // is created on demand; rival silhouettes are upgraded progressively so
  // ten detailed profiles cannot cause a first-frame GPU upload spike.
  if(carBuildQueue.length){const nextId=carBuildQueue.shift();carBuildQueued.delete(nextId);if(!carPartSets.has(nextId))carPartSets.set(nextId,buildCar(nextId));}
  if(lastStage!==snapshot.stageId&&trackBuildStage!==snapshot.stageId){cancelTrackBuild();trackBuildStage=snapshot.stageId;trackBuildStarted=performance.now();trackBuildJob=buildTrack(snapshot);state.trackBuildProgress=0;}
  if(trackBuildJob){const stepStarted=performance.now(),step=trackBuildJob.next(),stepMs=performance.now()-stepStarted;state.lastTrackBuildStepMs=stepMs;state.maxTrackBuildStepMs=Math.max(state.maxTrackBuildStepMs||0,stepMs);state.lastTrackBuildProgress=step.value?.progress??1;if(step.done){const previous=[road,...decor];road=step.value.road;decor=step.value.decor;lastStage=step.value.stageId;pendingTrackParts=[];trackBuildJob=null;state.trackBuildProgress=1;state.trackBuildMs=performance.now()-trackBuildStarted;disposeParts(previous);}else{if(step.value.parts)pendingTrackParts=step.value.parts;state.trackBuildProgress=step.value.progress;}}
  const f=snapshot.frameAt(snapshot.player.t),x=f.p.x+f.nx*snapshot.player.lateral,z=-(f.p.y+f.ny*snapshot.player.lateral),angle=f.angle+snapshot.player.yaw;
  const roadHeight=f.height||0;const desiredEye=[x-Math.cos(angle)*270,roadHeight+235,z+Math.sin(angle)*310],desiredTarget=[x+Math.cos(angle)*330,roadHeight+28,z-Math.sin(angle)*330];
  const now=performance.now(),cameraDt=lastRenderAt?Math.min((now-lastRenderAt)/1000,mobile?.05:.1):1/60;lastRenderAt=now;const follow=1-Math.exp(-cameraDt/(mobile?.16:.11));
  if(!cameraEye){cameraEye=desiredEye.slice();cameraTarget=desiredTarget.slice()}else{for(let i=0;i<3;i++){cameraEye[i]+=(desiredEye[i]-cameraEye[i])*follow;cameraTarget[i]+=(desiredTarget[i]-cameraTarget[i])*follow}}
  const projection=perspective(Math.PI/2.95,canvas.width/Math.max(1,canvas.height),1,60000),view=lookAt(cameraEye,cameraTarget,[0,1,0]);vp=mul(projection,view);
  const theme=THEMES[snapshot.world||0];gl.useProgram(program);gl.uniform3f(uniforms.camera,cameraEye[0],cameraEye[1],cameraEye[2]);gl.uniform3f(uniforms.light,-.38,.86,.42);gl.uniform3f(uniforms.lightColor,3.8,3.55,3.2);gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_CUBE_MAP,environment);gl.uniform1i(uniforms.env,0);const clearStarted=performance.now();gl.clearColor(...hexColor(theme[0]).map((v,i)=>v*(i === 0 ? 0.55 : 0.72)),1);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);const clearMs=performance.now()-clearStarted;state.lastClearMs=clearMs;state.maxClearMs=Math.max(state.maxClearMs||0,clearMs);state.triangles=0;
  // Draw the latest bounded build snapshot while the replacement track is still being assembled.\n  // Without this, the first gameplay frames show only the clear color until every city/track mesh finishes uploading.\n  const drawParts=road?[road,...decor]:pendingTrackParts;for(const p of drawParts)drawPart(p,vp,translate(0,0,0));
  const playerT=snapshot.player.t,maxVisible=mobile?3:softwareRenderer?2:7;visibleRivals.length=0;visibleDistances.length=0;for(const r of snapshot.rivals){if(r.despawned||r.destruction?.despawned)continue;const rawDelta=Math.abs(r.distance-playerT),delta=rawDelta%(Math.PI*2),distance=Math.min(delta,Math.PI*2-delta);if(distance>=.72)continue;let slot=visibleDistances.length;while(slot>0&&distance<visibleDistances[slot-1])slot--;if(slot>=maxVisible)continue;visibleRivals.splice(slot,0,r);visibleDistances.splice(slot,0,distance);if(visibleRivals.length>maxVisible){visibleRivals.pop();visibleDistances.pop()}}for(let i=0;i<visibleRivals.length;i++){const r=visibleRivals[i];drawVehicle(r.distance,r.lateral,r.yaw||0,r.color||"#56a8ed",r.damage?.total||r.damage||0,r.type,r.id,snapshot)}
  drawVehicle(snapshot.player.t,snapshot.player.lateral,snapshot.player.yaw,snapshot.player.color,snapshot.player.damage,"player",snapshot.player.modelId,snapshot);
  if(state.captureNextFrameSample){
   gl.finish();
   const sampleWidth=canvas.width,sampleHeight=canvas.height,samplePixels=new Uint8Array(sampleWidth*sampleHeight*4);
   gl.readPixels(0,0,sampleWidth,sampleHeight,gl.RGBA,gl.UNSIGNED_BYTE,samplePixels);
   let visiblePixels=0;const sampledColors=new Set();
   for(let i=0;i<samplePixels.length;i+=4*16){if(samplePixels[i]+samplePixels[i+1]+samplePixels[i+2]>24)visiblePixels++;sampledColors.add((samplePixels[i]>>4)+":"+(samplePixels[i+1]>>4)+":"+(samplePixels[i+2]>>4))}
   state.lastFramePixelSample={width:sampleWidth,height:sampleHeight,visiblePixels,uniqueColors:sampledColors.size,drawCalls:state.lastFrameDrawCalls,triangles:state.lastFrameTriangles,pixelBytes:samplePixels.byteLength,context:true,glError:gl.getError()};
   state.captureNextFrameSample=false;
  }
  state.frames++;state.stageId=snapshot.stageId;state.playerPosition={x,z};state.camera="perspective-chase";state.lastFrameTriangles=state.triangles;state.maxTrianglesPerFrame=Math.max(state.maxTrianglesPerFrame||0,state.lastFrameTriangles);state.lastFrameDrawCalls=(state.drawPartCount||0)-drawCountAtStart;state.maxRendererRenderMs=Math.max(state.maxRendererRenderMs||0,state.lastRendererRenderMs=performance.now()-rendererStarted);state.maxRendererRenderMs=Math.max(state.maxRendererRenderMs||0,state.lastRendererRenderMs);
 }
 function onLost(e){e.preventDefault();lost=true;state.status="context-lost"}
 function onRestored(){
  lost=false;
  try{
   // A restored WebGL context invalidates every program, uniform and buffer handle.
   // Recreate the complete GPU pipeline before allowing the next frame to render.
   program=makeProgram(gl);environment=createVehicleEnvironment(gl);state.environmentMapReady=!!environment;
   attributes={position:gl.getAttribLocation(program,"aPosition"),normal:gl.getAttribLocation(program,"aNormal")};
   uniforms={mvp:gl.getUniformLocation(program,"uMvp"),model:gl.getUniformLocation(program,"uModel"),color:gl.getUniformLocation(program,"uBaseColor"),camera:gl.getUniformLocation(program,"uCameraPosition"),light:gl.getUniformLocation(program,"uLightDirection"),lightColor:gl.getUniformLocation(program,"uLightColor"),env:gl.getUniformLocation(program,"uEnvironmentMap"),metal:gl.getUniformLocation(program,"uMetallic"),roughness:gl.getUniformLocation(program,"uRoughness"),clearcoat:gl.getUniformLocation(program,"uClearcoat"),kind:gl.getUniformLocation(program,"uMaterialKind"),emissive:gl.getUniformLocation(program,"uEmissive"),surface:gl.getUniformLocation(program,"uSurfaceTexture"),surfaceEnabled:gl.getUniformLocation(program,"uSurfaceEnabled")};
   surfaceLoadGeneration++;surfaceTextures.clear();state.surfaceTextures.loaded=0;state.surfaceTextures.failed=0;state.surfaceTextures.skipped=0;state.surfaceTextures.errors.length=0;for(const image of surfaceImages){image.onload=null;image.onerror=null;image.src=""}surfaceImages.clear();for(const [key,url] of Object.entries(surfaceSources))loadSurfaceTexture(key,url);
   gl.enable(gl.DEPTH_TEST);gl.disable(gl.CULL_FACE);gl.enable(gl.POLYGON_OFFSET_FILL);gl.polygonOffset(1,1);
   road=null;decor=[];carPartSets.clear();carBuildQueue.length=0;carBuildQueued.clear();lastStage=-1;lastSize="";trackBuildJob=null;trackBuildStage=-1;pendingTrackParts=[];state.trackBuildProgress=0;
   state.status="webgl-ready";state.error=null;
   resize();
  }catch(e){state.status="unavailable";state.error=String(e?.message||e)}
 }
 canvas.addEventListener("webglcontextlost",onLost);canvas.addEventListener("webglcontextrestored",onRestored);
 return {state,render,resize,setQuality(scale){qualityScale=clamp(scale,.58,1);lastSize="";resize()},destroy(){rendererDestroyed=true;surfaceLoadGeneration++;for(const image of surfaceImages){image.onload=null;image.onerror=null;image.src=""}surfaceImages.clear();canvas.removeEventListener("webglcontextlost",onLost);canvas.removeEventListener("webglcontextrestored",onRestored);disposeParts([road,...decor,...[...carPartSets.values()].flat(),...pendingTrackParts]);carBuildQueue.length=0;carBuildQueued.clear();for(const texture of surfaceTextures.values())try{gl.deleteTexture(texture)}catch{}surfaceTextures.clear();if(program)gl.deleteProgram(program);if(environment)gl.deleteTexture(environment)}};
}
