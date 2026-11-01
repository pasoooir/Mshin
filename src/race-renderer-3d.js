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
 vec3 n=normalize(vNormal);if(!gl_FrontFacing)n=-n;
 vec3 l=normalize(vec3(-.38,.86,.42));
 float diffuse=max(dot(n,l),0.0);
 float hemi=.38+.34*max(n.y,0.0);
 vec3 color=uColor*(hemi+diffuse*.78)+uColor*uEmissive;
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
 const state={status:"initializing",frames:0,triangles:0,renderer:"WebGL 1",error:null,quality:{mobile:false,pixelRatio:1,detail:"high"}};
 let gl,program,uniforms,attributes,road=null,decor=[],carPartSets=new Map(),carBuildQueue=[],carBuildQueued=new Set(),lastStage=-1,lastSize="",lost=false,trackBuildJob=null,trackBuildStage=-1,pendingTrackParts=[],trackBuildStarted=0;
  const mobile=matchMedia("(pointer:coarse)").matches||/Android|iPhone|iPad/i.test(navigator.userAgent);
  let cameraEye=null,cameraTarget=null,lastRenderAt=0,qualityScale=1;
 try{
  gl=canvas.getContext("webgl",{alpha:false,antialias:!mobile,depth:true,powerPreference:"high-performance",preserveDrawingBuffer:false})||canvas.getContext("experimental-webgl");
  if(!gl)throw new Error("WebGL is unavailable on this device");
  program=makeProgram(gl);attributes={position:gl.getAttribLocation(program,"aPosition"),normal:gl.getAttribLocation(program,"aNormal")};uniforms={mvp:gl.getUniformLocation(program,"uMvp"),model:gl.getUniformLocation(program,"uModel"),color:gl.getUniformLocation(program,"uColor"),emissive:gl.getUniformLocation(program,"uEmissive")};
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
  gl.uniform3f(uniforms.color,.5,.6,.7);gl.uniform1f(uniforms.emissive,0);
  gl.viewport(0,0,1,1);gl.drawArrays(gl.TRIANGLES,0,3);gl.finish();
  gl.deleteBuffer(warmupBuffer);gl.bindBuffer(gl.ARRAY_BUFFER,null);
  state.pipelineWarmupMs=performance.now()-warmupStarted;
  gl.enable(gl.DEPTH_TEST);gl.disable(gl.CULL_FACE);gl.enable(gl.POLYGON_OFFSET_FILL);gl.polygonOffset(1,1);
  state.status="webgl-ready";
 }catch(e){state.status="unavailable";state.error=String(e?.message||e);return {state,render(){},destroy(){}}}
 function part(tris,color,emissive=0){return {mesh:makeGeometry(gl,tris),color:hexColor(color),emissive}}
 function disposeParts(parts){for(const item of parts){const buffer=item?.mesh?.buffer;if(buffer){try{gl.deleteBuffer(buffer)}catch{}}}}
 function* buildTrack(snapshot){
  const nextDecor=[];
  const theme=THEMES[snapshot.world||0],roadTris=[],shoulderTris=[],laneTris=[],groundTris=[];
  const segments=mobile?84:240,half=180;
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
  const nextRoad=part(roadTris,theme[1]);nextDecor.push(part(shoulderTris,theme[2]),part(laneTris,"#e8e9e5"),part(groundTris,theme[0]));
  yield {parts:[nextRoad,...nextDecor],progress:.34};
  const trees=[],buildings=[],railTris=[],crowdBodies=[],crowdHeads=[],crowdLegs=[];
  for(let i=0;i<(mobile?18:48);i++){const t=i/(mobile?24:70)*Math.PI*2,f=snapshot.frameAt(t),side=i%2?1:-1,dist=260+(i%5)*52,x=f.p.x+f.nx*side*dist,z=-(f.p.y+f.ny*side*dist);
   if((snapshot.world||0)===4||(snapshot.world||0)===8){box(buildings,x,48,z,44+(i%3)*16,95+(i%4)*32,42);box(buildings,x,100+(i%4)*32,z,48+(i%3)*16,5,46)}
   else{box(trees,x,(f.height||0)+18,z,9,36,9);const cone=[];const baseY=(f.height||0)+22,rad=24+(i%3)*7,top=(f.height||0)+74+(i%4)*8;for(let j=0;j<8;j++){const aa=j/8*Math.PI*2,bb=(j+1)/8*Math.PI*2;tri(cone,[x+Math.cos(aa)*rad,baseY,z+Math.sin(aa)*rad],[x+Math.cos(bb)*rad,baseY,z+Math.sin(bb)*rad],[x,top,z])}trees.push(...cone)}
  }
  nextDecor.push(part(trees,theme[3]),part(buildings,(snapshot.world||0)===4?"#5c4d85":"#747b82"));
  yield {parts:[nextRoad,...nextDecor],progress:.67};
  for(let i=0;i<360;i+=(mobile?18:6)){
   const a=i/360*Math.PI*2,b=(i+1)/360*Math.PI*2,fa=snapshot.frameAt(a),fb=snapshot.frameAt(b);
   for(const side of [-1,1]){
    const offset=side*(half+15),p0=[fa.p.x+fa.nx*offset,(fa.height||0)+12,-(fa.p.y+fa.ny*offset)],p1=[fb.p.x+fb.nx*offset,(fb.height||0)+12,-(fb.p.y+fb.ny*offset)],q0=[p0[0],p0[1]+19,p0[2]],q1=[p1[0],p1[1]+19,p1[2]];
    quad(railTris,p0,p1,q1,q0);
   }
  }
  for(let i=0;i<(mobile?10:36);i++){
   const t=(i+.5)/(mobile?16:54)*Math.PI*2,f=snapshot.frameAt(t),side=i%2?1:-1,offset=238+(i%4)*13,x=f.p.x+f.nx*side*offset,z=-(f.p.y+f.ny*side*offset),base=f.height||0;
   box(crowdBodies,x,base+27,z,11,20,8);box(crowdBodies,x-7,base+27,z,5,17,5);box(crowdBodies,x+7,base+27,z,5,17,5);
   box(crowdHeads,x,base+43,z,9,9,9);box(crowdLegs,x-3,base+12,z,5,13,6);box(crowdLegs,x+3,base+12,z,5,13,6);
  }
  nextDecor.push(part(railTris,"#d9dfe2"),part(crowdBodies,"#e85b47"),part(crowdHeads,"#d4a47e"),part(crowdLegs,"#263344"));
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
  const p=VEHICLE_SHAPES[id]||VEHICLE_SHAPES.rally,w=p.width,l=p.length,h=p.bodyY,body=[],glass=[],trim=[],wheels=[],rims=[],lights=[],aero=[];
  const stations=[{z:-66,w:25,b:10,s:24,t:28},{z:-49,w:32,b:10,s:29,t:34},{z:-22,w:35,b:10,s:31,t:35},{z:18,w:34,b:10,s:30,t:34},{z:47,w:31,b:10,s:27,t:30},{z:65,w:23,b:12,s:22,t:24}];
  const rings=stations.map(q=>[[-q.w*w,q.b*h,q.z*l],[q.w*w,q.b*h,q.z*l],[q.w*w,q.s*h,q.z*l],[q.w*.76*w,q.t*h,q.z*l],[-q.w*.76*w,q.t*h,q.z*l],[-q.w*w,q.s*h,q.z*l]]);
  for(let i=0;i<rings.length-1;i++)for(let j=0;j<6;j++)quad(body,rings[i][j],rings[i][(j+1)%6],rings[i+1][(j+1)%6],rings[i+1][j]);
  for(let i=1;i<stations.length-1;i++){const a=stations[i],b=stations[i+1];quad(body,[-a.w*.76*w,a.t*h,a.z*l],[a.w*.76*w,a.t*h,a.z*l],[b.w*.76*w,b.t*h,b.z*l],[-b.w*.76*w,b.t*h,b.z*l])}
  const cabinLength=p.style==="gt"||p.style==="prototype"?38:p.style==="suv"||p.style==="pickup"?49:43;
  box(body,0,37*p.cabinY,-7,49*p.cabinWidth,15*p.cabinHeight,cabinLength*l);box(body,0,47*p.cabinY,-7,38*p.cabinWidth,4*p.cabinHeight,31*l);
  box(glass,0,42*p.cabinY,18*l,39*p.cabinWidth,13*p.cabinHeight,15*l);box(glass,0,41*p.cabinY,-31*l,38*p.cabinWidth,12*p.cabinHeight,14*l);
  box(glass,-25*p.cabinWidth,41*p.cabinY,-7,2,11*p.cabinHeight,32*l);box(glass,25*p.cabinWidth,41*p.cabinY,-7,2,11*p.cabinHeight,32*l);
  for(const side of [-1,1]){box(trim,side*31*w,27*h,-4*l,1.5,2.1,88*l);box(trim,side*28*w,22*h,-2*l,1.1,1.2,76*l);box(trim,side*29*w,31*h,-6*l,1.2,1.1,52*l);for(const z of [-p.wheelZ,p.wheelZ])box(trim,side*(p.wheelX+1)*w,p.wheelRadius*.9,z,2.4,2.2,p.wheelRadius*1.9);box(trim,side*29*w,13*h,0,2,3,47*l)}
  for(const side of [-1,1])box(trim,side*10*w,31*h,42*l,1.2,1.1,32*l);
  if(p.wing>.2){box(aero,0,11*h,65*l,58*w*p.wing,3*h,9*l);box(aero,0,38*h,-61*l,62*w*p.wing,3*h,5*l);box(aero,-27*w,35*h,-61*l,3,10*h,5*l);box(aero,27*w,35*h,-61*l,3,10*h,5*l)}
  if(p.style==="pickup"){box(body,0,29*h,-43*l,52*w,12*h,31*l);box(trim,-27*w,39*h,-43*l,2,12*h,34*l);box(trim,27*w,39*h,-43*l,2,12*h,34*l);box(trim,0,39*h,-58*l,54*w,12*h,2)}
  if(p.style==="suv"||p.style==="offroad"){box(aero,0,61*h,-5*l,52*w,3,48*l);box(aero,-23*w,54*h,-5*l,3,12,44*l);box(aero,23*w,54*h,-5*l,3,12,44*l)}
  if(p.style==="formula"){box(aero,0,12*h,72*l,76*w,3,12*l);box(aero,0,12*h,-72*l,80*w,3,12*l);box(body,0,27*h,-2*l,23*w,12*h,48*l)}
  for(const x of [-p.wheelX,p.wheelX])for(const z of [-p.wheelZ,p.wheelZ]){cylinder(wheels,x*w-p.wheelRadius*.35,p.wheelRadius+1,z*l,p.wheelRadius,10,20);cylinder(rims,x*w-p.wheelRadius*.35,p.wheelRadius+1,z*l,p.wheelRadius*.61,10,18);cylinder(trim,x*w-p.wheelRadius*.35,p.wheelRadius+1,z*l,3.2,10,12)}
  box(lights,-17*w,25*h,62*l,11*w,3*h,2);box(lights,17*w,25*h,62*l,11*w,3*h,2);box(lights,-17*w,23*h,-65*l,10*w,4*h,2);box(lights,17*w,23*h,-65*l,10*w,4*h,2);
  if(p.style!=="electric"){box(trim,0,20*h,65*l,22*w,7*h,2);box(trim,0,19*h,66*l,12*w,3*h,2)}
  return [part(body,"#e94f45"),part(glass,"#76c8e2",.08),part(trim,"#aeb9c3"),part(wheels,"#111820"),part(rims,"#c7d1d8",.04),part(lights,"#eaf8ff",.22),part(aero,"#202a35")]
 }
 function getCarParts(id){
  if(carPartSets.has(id))return carPartSets.get(id);
  if(carPartSets.size===0){const parts=buildCar(id);carPartSets.set(id,parts);return parts;}
  if(!carBuildQueued.has(id)){carBuildQueued.add(id);carBuildQueue.push(id);}
  return carPartSets.values().next().value;
 }
 function resize(){const portrait=matchMedia("(orientation: portrait)").matches;const cssWidth=portrait?innerHeight:innerWidth,cssHeight=portrait?innerWidth:innerHeight;const dpr=Math.min(devicePixelRatio||1,mobile?.68:1.5)*qualityScale,w=Math.max(1,Math.round(cssWidth*dpr)),h=Math.max(1,Math.round(cssHeight*dpr)),key=w+"x"+h;if(key===lastSize)return;lastSize=key;canvas.width=w;canvas.height=h;gl.viewport(0,0,w,h);state.quality={mobile,pixelRatio:dpr,detail:mobile?"mobile-balanced":"high",width:w,height:h}}
 function drawPart(p,vp,model){gl.uniformMatrix4fv(uniforms.model,false,model);gl.uniformMatrix4fv(uniforms.mvp,false,mul(vp,model));gl.uniform3fv(uniforms.color,p.color);gl.uniform1f(uniforms.emissive,p.emissive);gl.bindBuffer(gl.ARRAY_BUFFER,p.mesh.buffer);gl.enableVertexAttribArray(attributes.position);gl.vertexAttribPointer(attributes.position,3,gl.FLOAT,false,24,0);gl.enableVertexAttribArray(attributes.normal);gl.vertexAttribPointer(attributes.normal,3,gl.FLOAT,false,24,12);gl.drawArrays(gl.TRIANGLES,0,p.mesh.count);state.triangles+=p.mesh.count/3}
 function drawVehicle(t,lateral,yaw,color,damage=0,kind="car",vehicleId=0,snapshot){
  const f=snapshot.frameAt(t),x=f.p.x+f.nx*lateral,z=-(f.p.y+f.ny*lateral),heading=-(f.angle+yaw);
  const carParts=getCarParts(vehicleShapeFor(kind,vehicleId));
  const model=mul(translate(x,f.height||0,z),rotateY(heading));carParts[0].color=hexColor(color);
  for(let i=0;i<carParts.length;i++)drawPart(carParts[i],vp,model);
  
 }
 let vp,partCacheSmoke;
 const visibleRivals=[],visibleDistances=[];
 function render(snapshot){
  if(!gl||lost||!snapshot||!["race","countdown","paused"].includes(snapshot.state))return;
  resize();
  const playerProfile=vehicleShapeFor("player",snapshot.player.modelId);
  if(!carPartSets.has(playerProfile))carPartSets.set(playerProfile,buildCar(playerProfile));
  // Build at most one additional vehicle mesh set per frame. The player car
  // is created on demand; rival silhouettes are upgraded progressively so
  // ten detailed profiles cannot cause a first-frame GPU upload spike.
  if(carBuildQueue.length){const nextId=carBuildQueue.shift();carBuildQueued.delete(nextId);if(!carPartSets.has(nextId))carPartSets.set(nextId,buildCar(nextId));}
  if(lastStage!==snapshot.stageId&&trackBuildStage!==snapshot.stageId){cancelTrackBuild();trackBuildStage=snapshot.stageId;trackBuildStarted=performance.now();trackBuildJob=buildTrack(snapshot);state.trackBuildProgress=0;}
  if(trackBuildJob){const step=trackBuildJob.next();if(step.done){const previous=[road,...decor];road=step.value.road;decor=step.value.decor;lastStage=step.value.stageId;pendingTrackParts=[];trackBuildJob=null;state.trackBuildProgress=1;state.trackBuildMs=performance.now()-trackBuildStarted;disposeParts(previous);}else{pendingTrackParts=step.value.parts;state.trackBuildProgress=step.value.progress;}}
  const f=snapshot.frameAt(snapshot.player.t),x=f.p.x+f.nx*snapshot.player.lateral,z=-(f.p.y+f.ny*snapshot.player.lateral),angle=f.angle+snapshot.player.yaw;
  const roadHeight=f.height||0;const desiredEye=[x-Math.cos(angle)*270,roadHeight+235,z+Math.sin(angle)*310],desiredTarget=[x+Math.cos(angle)*330,roadHeight+28,z-Math.sin(angle)*330];
  const now=performance.now(),cameraDt=lastRenderAt?Math.min((now-lastRenderAt)/1000,mobile?.05:.1):1/60;lastRenderAt=now;const follow=1-Math.exp(-cameraDt/(mobile?.16:.11));
  if(!cameraEye){cameraEye=desiredEye.slice();cameraTarget=desiredTarget.slice()}else{for(let i=0;i<3;i++){cameraEye[i]+=(desiredEye[i]-cameraEye[i])*follow;cameraTarget[i]+=(desiredTarget[i]-cameraTarget[i])*follow}}
  const projection=perspective(Math.PI/2.95,canvas.width/Math.max(1,canvas.height),1,6000),view=lookAt(cameraEye,cameraTarget,[0,1,0]);vp=mul(projection,view);
  const theme=THEMES[snapshot.world||0];gl.useProgram(program);gl.clearColor(...hexColor(theme[0]).map((v,i)=>v*(i === 0 ? 0.55 : 0.72)),1);gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);state.triangles=0;
  if(road)drawPart(road,vp,translate(0,0,0));for(const p of decor)drawPart(p,vp,translate(0,0,0));
  const playerT=snapshot.player.t,maxVisible=mobile?3:7;visibleRivals.length=0;visibleDistances.length=0;for(const r of snapshot.rivals){if(r.despawned||r.destruction?.despawned)continue;const rawDelta=Math.abs(r.distance-playerT),delta=rawDelta%(Math.PI*2),distance=Math.min(delta,Math.PI*2-delta);if(distance>=.72)continue;let slot=visibleDistances.length;while(slot>0&&distance<visibleDistances[slot-1])slot--;if(slot>=maxVisible)continue;visibleRivals.splice(slot,0,r);visibleDistances.splice(slot,0,distance);if(visibleRivals.length>maxVisible){visibleRivals.pop();visibleDistances.pop()}}for(let i=0;i<visibleRivals.length;i++){const r=visibleRivals[i];drawVehicle(r.distance,r.lateral,r.yaw||0,r.color||"#56a8ed",r.damage?.total||r.damage||0,r.type,r.id,snapshot)}
  drawVehicle(snapshot.player.t,snapshot.player.lateral,snapshot.player.yaw,snapshot.player.color,snapshot.player.damage,"player",snapshot.player.modelId,snapshot);
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
   gl.enable(gl.DEPTH_TEST);gl.disable(gl.CULL_FACE);gl.enable(gl.POLYGON_OFFSET_FILL);gl.polygonOffset(1,1);
   road=null;decor=[];carPartSets.clear();carBuildQueue.length=0;carBuildQueued.clear();lastStage=-1;lastSize="";trackBuildJob=null;trackBuildStage=-1;pendingTrackParts=[];state.trackBuildProgress=0;
   state.status="webgl-ready";state.error=null;
   resize();
  }catch(e){state.status="unavailable";state.error=String(e?.message||e)}
 }
 canvas.addEventListener("webglcontextlost",onLost);canvas.addEventListener("webglcontextrestored",onRestored);
 return {state,render,resize,setQuality(scale){qualityScale=clamp(scale,.58,1);lastSize="";resize()},destroy(){canvas.removeEventListener("webglcontextlost",onLost);canvas.removeEventListener("webglcontextrestored",onRestored);disposeParts([road,...decor,...[...carPartSets.values()].flat(),...pendingTrackParts]);carBuildQueue.length=0;carBuildQueued.clear();if(program)gl.deleteProgram(program)}};
}
