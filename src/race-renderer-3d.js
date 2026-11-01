// Native WebGL 3D race renderer. No CDN or external runtime dependency.
const VERT=`
attribute vec3 aPosition;
attribute vec3 aNormal;
uniform mat4 uMvp;
uniform mat4 uModel;
varying vec3 vNormal;
void main(){gl_Position=uMvp*vec4(aPosition,1.0);vNormal=mat3(uModel)*aNormal;}
`;
const FRAG=`
precision mediump float;
uniform vec3 uColor;
uniform float uEmissive;
varying vec3 vNormal;
void main(){
 vec3 n=normalize(vNormal),l=normalize(vec3(-.38,.86,.42));
 float diffuse=max(dot(n,l),0.0);
 float hemi=.28+.25*max(n.y,0.0);
 vec3 color=uColor*(hemi+diffuse*.72)+uColor*uEmissive;
 gl_FragColor=vec4(color,1.0);
}
`;
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
 const vertex=shader(gl,gl.VERTEX_SHADER,VERT),fragment=shader(gl,gl.FRAGMENT_SHADER,FRAG),p=gl.createProgram();
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
function makeGeometry(gl,triangles){const data=[];for(let i=0;i<triangles.length;i+=9){const a=triangles.slice(i,i+3),b=triangles.slice(i+3,i+6),c=triangles.slice(i+6,i+9),n=norm(cross(sub(b,a),sub(c,a)));for(const p of [a,b,c])data.push(...p,...n)}const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(data),gl.STATIC_DRAW);return {buffer,count:data.length/6}}
function tri(out,a,b,c){out.push(...a,...b,...c)}
function quad(out,a,b,c,d){tri(out,a,b,c);tri(out,a,c,d)}
function box(out,x,y,z,w,h,d){const x0=x-w/2,x1=x+w/2,y0=y-h/2,y1=y+h/2,z0=z-d/2,z1=z+d/2;quad(out,[x0,y0,z1],[x1,y0,z1],[x1,y1,z1],[x0,y1,z1]);quad(out,[x1,y0,z0],[x0,y0,z0],[x0,y1,z0],[x1,y1,z0]);quad(out,[x0,y0,z0],[x0,y0,z1],[x0,y1,z1],[x0,y1,z0]);quad(out,[x1,y0,z1],[x1,y0,z0],[x1,y1,z0],[x1,y1,z1]);quad(out,[x0,y1,z1],[x1,y1,z1],[x1,y1,z0],[x0,y1,z0]);quad(out,[x0,y0,z0],[x1,y0,z0],[x1,y0,z1],[x0,y0,z1])}
function cylinder(out,x,y,z,r,depth,segments=12){for(let i=0;i<segments;i++){const a=i/segments*Math.PI*2,b=(i+1)/segments*Math.PI*2,p=[x,y+Math.cos(a)*r,z+Math.sin(a)*r],q=[x,y+Math.cos(b)*r,z+Math.sin(b)*r],p2=[x+depth,y+Math.cos(a)*r,z+Math.sin(a)*r],q2=[x+depth,y+Math.cos(b)*r,z+Math.sin(b)*r];quad(out,p,q,q2,p2)}}
function hexColor(value){const h=String(value||"#e94f45").replace("#","");return [0,2,4].map(i=>parseInt(h.slice(i,i+2),16)/255).map(v=>Number.isFinite(v)?v:1)}
const THEMES=[["#7cae48","#333c43","#777f83","#d9c99b"],["#c5a06a","#3e3730","#92785c","#ead2a5"],["#b7e3f1","#596d7b","#d4eff6","#f4fbff"],["#4caa8e","#393d38","#b5a080","#f4dc9d"],["#29284f","#202738","#7d4eaa","#ed45cb"],["#69727a","#333b43","#59636b","#d7a45e"],["#648f78","#3b4146","#79858b","#c9d7ce"],["#c4a66d","#4b4036","#a58b63","#e8d6a5"],["#181d42","#202039","#4c4b79","#54dff1"],["#bb645f","#30394b","#778391","#f3d36a"]];
export function createRaceRenderer(canvas){
 const state={status:"initializing",frames:0,triangles:0,renderer:"WebGL 1",error:null,quality:{mobile:false,pixelRatio:1,detail:"high"}};
 let gl,program,uniforms,attributes,road=null,decor=[],carParts=[],lastStage=-1,lastSize="",lost=false;
  const mobile=matchMedia("(pointer:coarse)").matches||/Android|iPhone|iPad/i.test(navigator.userAgent);
  let cameraEye=null,cameraTarget=null,lastRenderAt=0,qualityScale=1;
 try{
  gl=canvas.getContext("webgl",{alpha:false,antialias:!mobile,depth:true,powerPreference:"high-performance",preserveDrawingBuffer:false})||canvas.getContext("experimental-webgl");
  if(!gl)throw new Error("WebGL is unavailable on this device");
  program=makeProgram(gl);attributes={position:gl.getAttribLocation(program,"aPosition"),normal:gl.getAttribLocation(program,"aNormal")};uniforms={mvp:gl.getUniformLocation(program,"uMvp"),model:gl.getUniformLocation(program,"uModel"),color:gl.getUniformLocation(program,"uColor"),emissive:gl.getUniformLocation(program,"uEmissive")};
  gl.enable(gl.DEPTH_TEST);gl.enable(gl.CULL_FACE);gl.cullFace(gl.BACK);gl.enable(gl.POLYGON_OFFSET_FILL);gl.polygonOffset(1,1);
  state.status="webgl-ready";
 }catch(e){state.status="unavailable";state.error=String(e?.message||e);return {state,render(){},destroy(){}}}
 function part(tris,color,emissive=0){return {mesh:makeGeometry(gl,tris),color:hexColor(color),emissive}}
 function disposeParts(parts){for(const item of parts){const buffer=item?.mesh?.buffer;if(buffer){try{gl.deleteBuffer(buffer)}catch{}}}}
 function buildTrack(snapshot){
  // Release the previous stage meshes before allocating the next stage to prevent GPU-memory growth.
  disposeParts([road,...decor]);road=null;decor=[];
  const theme=THEMES[snapshot.world||0],roadTris=[],shoulderTris=[],laneTris=[],groundTris=[];
  const segments=mobile?84:360,half=180;
  for(let i=0;i<segments;i++){
   const a=i/segments*Math.PI*2,b=(i+1)/segments*Math.PI*2,fa=snapshot.frameAt(a),fb=snapshot.frameAt(b);
   const point=(f,offset,y=0)=>[f.p.x+f.nx*offset,(f.height||0)+y,-(f.p.y+f.ny*offset)];
   const l0=point(fa,-half),r0=point(fa,half),l1=point(fb,-half),r1=point(fb,half);
   const sl0=point(fa,-half-26,-.04),sr0=point(fa,half+26,-.04),sl1=point(fb,-half-26,-.04),sr1=point(fb,half+26,-.04);
   quad(roadTris,l0,l1,r1,r0);quad(shoulderTris,sl0,sl1,l1,l0);quad(shoulderTris,r0,r1,sr1,sr0);
   for(const offset of [-90,0,90]){const width=offset===0?2.5:1.5;const p0=point(fa,offset-width,.012),q0=point(fa,offset+width,.012),p1=point(fb,offset-width,.012),q1=point(fb,offset+width,.012);if(offset!==0&&i%3!==0)continue;quad(laneTris,p0,p1,q1,q0)}
   const outerL=point(fa,-half-26,-.12),outerR=point(fa,half+26,-.12),outerL1=point(fb,-half-26,-.12),outerR1=point(fb,half+26,-.12);
   quad(groundTris,outerL,outerL1,outerR1,outerR);
  }
  road=part(roadTris,theme[1]);decor=[part(shoulderTris,theme[2]),part(laneTris,"#e8e9e5"),part(groundTris,theme[0])];
  const trees=[],buildings=[],railTris=[],crowdBodies=[],crowdHeads=[],crowdLegs=[];
  for(let i=0;i<(mobile?18:70);i++){const t=i/(mobile?24:70)*Math.PI*2,f=snapshot.frameAt(t),side=i%2?1:-1,dist=260+(i%5)*52,x=f.p.x+f.nx*side*dist,z=-(f.p.y+f.ny*side*dist);
   if((snapshot.world||0)===4||(snapshot.world||0)===8){box(buildings,x,48,z,44+(i%3)*16,95+(i%4)*32,42);box(buildings,x,100+(i%4)*32,z,48+(i%3)*16,5,46)}
   else{box(trees,x,(f.height||0)+18,z,9,36,9);const cone=[];const baseY=(f.height||0)+22,rad=24+(i%3)*7,top=(f.height||0)+74+(i%4)*8;for(let j=0;j<8;j++){const aa=j/8*Math.PI*2,bb=(j+1)/8*Math.PI*2;tri(cone,[x+Math.cos(aa)*rad,baseY,z+Math.sin(aa)*rad],[x+Math.cos(bb)*rad,baseY,z+Math.sin(bb)*rad],[x,top,z])}trees.push(...cone)}
  }
  decor.push(part(trees,theme[3]),part(buildings,(snapshot.world||0)===4?"#5c4d85":"#747b82"));
  for(let i=0;i<360;i+=(mobile?18:4)){
   const a=i/360*Math.PI*2,b=(i+1)/360*Math.PI*2,fa=snapshot.frameAt(a),fb=snapshot.frameAt(b);
   for(const side of [-1,1]){
    const offset=side*(half+15),p0=[fa.p.x+fa.nx*offset,(fa.height||0)+12,-(fa.p.y+fa.ny*offset)],p1=[fb.p.x+fb.nx*offset,(fb.height||0)+12,-(fb.p.y+fb.ny*offset)],q0=[p0[0],p0[1]+19,p0[2]],q1=[p1[0],p1[1]+19,p1[2]];
    quad(railTris,p0,p1,q1,q0);
   }
  }
  for(let i=0;i<(mobile?10:54);i++){
   const t=(i+.5)/(mobile?16:54)*Math.PI*2,f=snapshot.frameAt(t),side=i%2?1:-1,offset=238+(i%4)*13,x=f.p.x+f.nx*side*offset,z=-(f.p.y+f.ny*side*offset),base=f.height||0;
   box(crowdBodies,x,base+27,z,11,20,8);box(crowdBodies,x-7,base+27,z,5,17,5);box(crowdBodies,x+7,base+27,z,5,17,5);
   box(crowdHeads,x,base+43,z,9,9,9);box(crowdLegs,x-3,base+12,z,5,13,6);box(crowdLegs,x+3,base+12,z,5,13,6);
  }
  decor.push(part(railTris,"#d9dfe2"),part(crowdBodies,"#e85b47"),part(crowdHeads,"#d4a47e"),part(crowdLegs,"#263344"));
  lastStage=snapshot.stageId;
 }
 function buildCar(){
  const body=[],glass=[],trim=[],wheels=[];
  box(body,0,18,0,66,22,116);box(body,0,32,-5,55,14,66);box(body,0,39,-6,46,3,58);
  box(glass,0,40,22,43,16,25);box(glass,0,40,-29,43,15,20);
  box(trim,-24,16,57,8,7,5);box(trim,24,16,57,8,7,5);box(trim,-23,16,-58,9,7,5);box(trim,23,16,-58,9,7,5);
  for(const x of [-37,37])for(const z of [-37,38]){cylinder(wheels,x,13,z,13,9,14);cylinder(trim,x+(x<0?-9:9),13,z,7,2,12)}
  carParts=[part(body,"#e94f45"),part(glass,"#8bd7ed"),part(trim,"#e7e9e9"),part(wheels,"#171c23")];
 }
 function resize(){const portrait=matchMedia("(orientation: portrait)").matches;const cssWidth=portrait?innerHeight:innerWidth,cssHeight=portrait?innerWidth:innerHeight;const dpr=Math.min(devicePixelRatio||1,mobile?.68:1.5)*qualityScale,w=Math.max(1,Math.round(cssWidth*dpr)),h=Math.max(1,Math.round(cssHeight*dpr)),key=w+"x"+h;if(key===lastSize)return;lastSize=key;canvas.width=w;canvas.height=h;gl.viewport(0,0,w,h);state.quality={mobile,pixelRatio:dpr,detail:mobile?"mobile-balanced":"high",width:w,height:h}}
 function drawPart(p,vp,model){gl.uniformMatrix4fv(uniforms.model,false,model);gl.uniformMatrix4fv(uniforms.mvp,false,mul(vp,model));gl.uniform3fv(uniforms.color,p.color);gl.uniform1f(uniforms.emissive,p.emissive);gl.bindBuffer(gl.ARRAY_BUFFER,p.mesh.buffer);gl.enableVertexAttribArray(attributes.position);gl.vertexAttribPointer(attributes.position,3,gl.FLOAT,false,24,0);gl.enableVertexAttribArray(attributes.normal);gl.vertexAttribPointer(attributes.normal,3,gl.FLOAT,false,24,12);gl.drawArrays(gl.TRIANGLES,0,p.mesh.count);state.triangles+=p.mesh.count/3}
 function drawVehicle(t,lateral,yaw,color,damage=0,kind="car",snapshot){
  const f=snapshot.frameAt(t),x=f.p.x+f.nx*lateral,z=-(f.p.y+f.ny*lateral),heading=-(f.angle+yaw);
  const model=mul(translate(x,f.height||0,z),rotateY(heading));carParts[0].color=hexColor(color);
  for(let i=0;i<carParts.length;i++)drawPart(carParts[i],vp,model);
  
 }
 let vp,partCacheSmoke;
 function render(snapshot){
  if(!gl||lost||!snapshot||!["race","countdown","paused"].includes(snapshot.state))return;
  resize();if(lastStage!==snapshot.stageId)buildTrack(snapshot);
  if(!carParts.length)buildCar();
  const f=snapshot.frameAt(snapshot.player.t),x=f.p.x+f.nx*snapshot.player.lateral,z=-(f.p.y+f.ny*snapshot.player.lateral),angle=f.angle+snapshot.player.yaw;
  const roadHeight=f.height||0;const desiredEye=[x-Math.cos(angle)*270,roadHeight+155,z+Math.sin(angle)*270],desiredTarget=[x+Math.cos(angle)*250,roadHeight+20,z-Math.sin(angle)*250];
  const now=performance.now(),cameraDt=lastRenderAt?Math.min((now-lastRenderAt)/1000,mobile?.05:.1):1/60;lastRenderAt=now;const follow=1-Math.exp(-cameraDt/(mobile?.16:.11));
  if(!cameraEye){cameraEye=desiredEye.slice();cameraTarget=desiredTarget.slice()}else{for(let i=0;i<3;i++){cameraEye[i]+=(desiredEye[i]-cameraEye[i])*follow;cameraTarget[i]+=(desiredTarget[i]-cameraTarget[i])*follow}}
  const projection=perspective(Math.PI/3.15,canvas.width/Math.max(1,canvas.height),1,7000),view=lookAt(cameraEye,cameraTarget,[0,1,0]);vp=mul(projection,view);
  const theme=THEMES[snapshot.world||0];gl.clearColor(...hexColor(theme[0]).map((v,i)=>v*(i === 0 ? 0.55 : 0.72)),1);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);state.triangles=0;
  drawPart(road,vp,translate(0,0,0));for(const p of decor)drawPart(p,vp,translate(0,0,0));
  const playerT=snapshot.player.t,visibleRivals=[];for(const r of snapshot.rivals){if(r.despawned||r.destruction?.despawned)continue;const renderDistance=Math.abs(Math.atan2(Math.sin(r.distance-playerT),Math.cos(r.distance-playerT)));if(renderDistance<.72)visibleRivals.push({vehicle:r,distance:renderDistance})}visibleRivals.sort((a,b)=>a.distance-b.distance);for(let i=0;i<Math.min(visibleRivals.length,mobile?3:7);i++){const r=visibleRivals[i].vehicle;drawVehicle(r.distance,r.lateral,r.yaw||0,r.color||"#56a8ed",r.damage?.total||r.damage||0,r.type,snapshot)}
  drawVehicle(snapshot.player.t,snapshot.player.lateral,snapshot.player.yaw,snapshot.player.color,snapshot.player.damage,"player",snapshot);
  state.frames++;state.stageId=snapshot.stageId;state.playerPosition={x,z};state.camera="perspective-chase";
 }
 function onLost(e){e.preventDefault();lost=true;state.status="context-lost"}
 function onRestored(){
  lost=false;
  try{
   // A restored WebGL context invalidates every program, uniform and buffer handle.
   // Recreate the complete GPU pipeline before allowing the next frame to render.
   program=makeProgram(gl);
   attributes={position:gl.getAttribLocation(program,"aPosition"),normal:gl.getAttribLocation(program,"aNormal")};
   uniforms={mvp:gl.getUniformLocation(program,"uMvp"),model:gl.getUniformLocation(program,"uModel"),color:gl.getUniformLocation(program,"uColor"),emissive:gl.getUniformLocation(program,"uEmissive")};
   gl.enable(gl.DEPTH_TEST);gl.enable(gl.CULL_FACE);gl.cullFace(gl.BACK);gl.enable(gl.POLYGON_OFFSET_FILL);gl.polygonOffset(1,1);
   road=null;decor=[];carParts=[];lastStage=-1;lastSize="";
   state.status="webgl-ready";state.error=null;
   resize();
  }catch(e){state.status="unavailable";state.error=String(e?.message||e)}
 }
 canvas.addEventListener("webglcontextlost",onLost);canvas.addEventListener("webglcontextrestored",onRestored);
 return {state,render,resize,setQuality(scale){qualityScale=clamp(scale,.58,1);lastSize="";resize()},destroy(){canvas.removeEventListener("webglcontextlost",onLost);canvas.removeEventListener("webglcontextrestored",onRestored);disposeParts([road,...decor,...carParts]);if(program)gl.deleteProgram(program)}};
}
