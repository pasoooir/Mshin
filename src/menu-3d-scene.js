const VERT=`
attribute vec3 aPosition;
attribute vec3 aNormal;
attribute vec3 aColor;
uniform mat4 uMvp;
uniform mat4 uModel;
varying vec3 vColor;
varying float vLight;
void main(){
  vec3 n=normalize(mat3(uModel)*aNormal);
  vLight=.42+.58*max(dot(n,normalize(vec3(-.42,.88,.28))),0.0);
  vColor=aColor;
  gl_Position=uMvp*vec4(aPosition,1.0);
}`;
const FRAG=`
precision mediump float;
varying vec3 vColor;
varying float vLight;
void main(){gl_FragColor=vec4(vColor*(.68+.42*vLight),1.0);}
`;
const COLORS={rally:"#ed5147",comet:"#39a9ff",lynx:"#8bce65",thunder:"#f4d64e",raptor:"#d88a45"};
const hex=h=>[parseInt(h.slice(1,3),16)/255,parseInt(h.slice(3,5),16)/255,parseInt(h.slice(5,7),16)/255];
function mat4(){return new Float32Array(16)}
function identity(){const m=mat4();m[0]=m[5]=m[10]=m[15]=1;return m}
function multiply(a,b){const o=mat4();for(let c=0;c<4;c++)for(let r=0;r<4;r++)o[c*4+r]=a[r]*b[c*4]+a[4+r]*b[c*4+1]+a[8+r]*b[c*4+2]+a[12+r]*b[c*4+3];return o}
function translate(x,y,z){const m=identity();m[12]=x;m[13]=y;m[14]=z;return m}
function scale(x,y,z){const m=identity();m[0]=x;m[5]=y;m[10]=z;return m}
function rotateY(a){const m=identity(),c=Math.cos(a),s=Math.sin(a);m[0]=c;m[2]=-s;m[8]=s;m[10]=c;return m}
function rotateX(a){const m=identity(),c=Math.cos(a),s=Math.sin(a);m[5]=c;m[6]=s;m[9]=-s;m[10]=c;return m}
function rotateZ(a){const m=identity(),c=Math.cos(a),s=Math.sin(a);m[0]=c;m[1]=s;m[4]=-s;m[5]=c;return m}
function perspective(fovy,aspect,near,far){const f=1/Math.tan(fovy/2),m=mat4();m[0]=f/aspect;m[5]=f;m[10]=(far+near)/(near-far);m[11]=-1;m[14]=(2*far*near)/(near-far);return m}
function lookAt(eye,center,up){const sub=(a,b)=>a.map((v,i)=>v-b[i]),norm=v=>{const l=Math.hypot(...v)||1;return v.map(x=>x/l)},cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]],z=norm(sub(eye,center)),x=norm(cross(up,z)),y=cross(z,x),m=identity();m[0]=x[0];m[1]=y[0];m[2]=z[0];m[4]=x[1];m[5]=y[1];m[6]=z[1];m[8]=x[2];m[9]=y[2];m[10]=z[2];m[12]=-(x[0]*eye[0]+x[1]*eye[1]+x[2]*eye[2]);m[13]=-(y[0]*eye[0]+y[1]*eye[1]+y[2]*eye[2]);m[14]=-(z[0]*eye[0]+z[1]*eye[1]+z[2]*eye[2]);return m}
function meshData(){return {p:[],n:[],c:[]}}
function tri(d,a,b,c,color){const u=[b[0]-a[0],b[1]-a[1],b[2]-a[2]],v=[c[0]-a[0],c[1]-a[1],c[2]-a[2]],n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]],l=Math.hypot(...n)||1;n.forEach((_,i)=>n[i]/=l);for(const p of [a,b,c]){d.p.push(...p);d.n.push(...n);d.c.push(...color)}}
function quad(d,a,b,c,e,color){tri(d,a,b,c,color);tri(d,a,c,e,color)}
function box(colorHex){const d=meshData(),c=hex(colorHex),x=.5,y=.5,z=.5;quad(d,[-x,-y,z],[x,-y,z],[x,y,z],[-x,y,z],c);quad(d,[x,-y,-z],[-x,-y,-z],[-x,y,-z],[x,y,-z],c);quad(d,[-x,-y,-z],[-x,-y,z],[-x,y,z],[-x,y,-z],c);quad(d,[x,-y,z],[x,-y,-z],[x,y,-z],[x,y,z],c);quad(d,[-x,y,z],[x,y,z],[x,y,-z],[-x,y,-z],c);quad(d,[-x,-y,-z],[x,-y,-z],[x,-y,z],[-x,-y,z],c);return d}
function cylinder(colorHex,segments=14){const d=meshData(),c=hex(colorHex);for(let i=0;i<segments;i++){const a=i/segments*Math.PI*2,b=(i+1)/segments*Math.PI*2,p0=[Math.cos(a)*.5,-.5,Math.sin(a)*.5],p1=[Math.cos(b)*.5,-.5,Math.sin(b)*.5],p2=[Math.cos(b)*.5,.5,Math.sin(b)*.5],p3=[Math.cos(a)*.5,.5,Math.sin(a)*.5];quad(d,p0,p1,p2,p3,c);tri(d,[0,.5,0],p3,p2,c);tri(d,[0,-.5,0],p1,p0,c)}return d}
function cone(colorHex,segments=9){const d=meshData(),c=hex(colorHex),tip=[0,1,0];for(let i=0;i<segments;i++){const a=i/segments*Math.PI*2,b=(i+1)/segments*Math.PI*2,p=[Math.cos(a)*.5,0,Math.sin(a)*.5],q=[Math.cos(b)*.5,0,Math.sin(b)*.5];tri(d,p,q,tip,c);tri(d,[0,0,0],q,p,c)}return d}
function plane(colorHex){const d=meshData(),c=hex(colorHex);quad(d,[-.5,0,.5],[.5,0,.5],[.5,0,-.5],[-.5,0,-.5],c);return d}
function ring(outerX,outerZ,innerX,innerZ,colorHex){const d=meshData(),c=hex(colorHex),steps=100;for(let i=0;i<steps;i++){const a=i/steps*Math.PI*2,b=(i+1)/steps*Math.PI*2;const p=[Math.cos(a)*outerX,.03,Math.sin(a)*outerZ],q=[Math.cos(b)*outerX,.03,Math.sin(b)*outerZ],r=[Math.cos(b)*innerX,.03,Math.sin(b)*innerZ],s=[Math.cos(a)*innerX,.03,Math.sin(a)*innerZ];quad(d,p,s,r,q,c)}return d}
function createMesh(gl,d){const make=(data,size)=>{const b=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,b);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(data),gl.STATIC_DRAW);return b};return {p:make(d.p),n:make(d.n),c:make(d.c),count:d.p.length/3}}
function compile(gl,type,source){const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw new Error(gl.getShaderInfoLog(s)||"shader compile failed");return s}
function makeProgram(gl){const p=gl.createProgram();gl.attachShader(p,compile(gl,gl.VERTEX_SHADER,VERT));gl.attachShader(p,compile(gl,gl.FRAGMENT_SHADER,FRAG));gl.linkProgram(p);if(!gl.getProgramParameter(p,gl.LINK_STATUS))throw new Error(gl.getProgramInfoLog(p)||"shader link failed");return p}
function createRenderer(canvas,mode){const gl=canvas.getContext("webgl",{alpha:true,antialias:true,powerPreference:"low-power"})||canvas.getContext("experimental-webgl");if(!gl)throw new Error("WebGL is not available");const program=makeProgram(gl),loc={p:gl.getAttribLocation(program,"aPosition"),n:gl.getAttribLocation(program,"aNormal"),c:gl.getAttribLocation(program,"aColor"),mvp:gl.getUniformLocation(program,"uMvp"),model:gl.getUniformLocation(program,"uModel")};gl.useProgram(program);gl.enable(gl.DEPTH_TEST);gl.disable(gl.CULL_FACE);gl.clearColor(.025,.055,.085,0);const cache=new Map();let drawCalls=0;
 const get=h=>{if(!cache.has(h))cache.set(h,createMesh(gl,h()));return cache.get(h)};
 const paintMeshes=new Map();const meshes={ground:get(()=>plane("#243b35")),garageFloor:get(()=>plane("#111c2a")),garageWall:get(()=>box("#17293a")),garagePillar:get(()=>box("#263d50")),garageNeon:get(()=>ring(4.15,4.15,4.02,4.02,"#47c7e8")),road:get(()=>ring(13,8,8.7,5.7,"#303943")),shoulder:get(()=>ring(13.45,8.45,13,8,"#d3a65d")),inner:get(()=>ring(8.7,5.7,8.35,5.35,"#d9e2cf")),lane:get(()=>ring(10.98,6.98,10.86,6.86,"#e9e4ce")),body:get(()=>box("#ed5147")),dark:get(()=>box("#111a23")),glass:get(()=>box("#7ec4d9")),rubber:get(()=>cylinder("#10151a",18)),hub:get(()=>cylinder("#aab7bf",16)),trunk:get(()=>cylinder("#72533a",8)),leaf:get(()=>cone("#35765a",10)),building:get(()=>box("#42566a")),light:get(()=>box("#e6c36b")),platform:get(()=>cylinder("#23313c",48))};
 function bind(mesh){for(const [key,buffer] of [["p",mesh.p],["n",mesh.n],["c",mesh.c]]){const a=loc[key];gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.enableVertexAttribArray(a);gl.vertexAttribPointer(a,3,gl.FLOAT,false,0,0)}}
 function draw(mesh,model,vp){bind(mesh);gl.uniformMatrix4fv(loc.model,false,model);gl.uniformMatrix4fv(loc.mvp,false,multiply(vp,model));gl.drawArrays(gl.TRIANGLES,0,mesh.count);drawCalls++}
 function car(colorHex,angle,time,garage,vp){const base=translate(garage?0:10.5,.46,garage?0:0),turn=multiply(base,rotateY(angle));let paint=paintMeshes.get(colorHex);if(!paint){paint=createMesh(gl,box(colorHex));paintMeshes.set(colorHex,paint)}const part=(mesh,pos,sz,rot=identity())=>draw(mesh,multiply(multiply(multiply(turn,translate(...pos)),rot),scale(...sz)),vp);
  part(paint,[0,.05,0],[1.85,.52,3.5]);part(paint,[0,.34,1.05],[1.62,.2,1.12]);part(paint,[0,.4,-1.12],[1.58,.2,.82]);part(paint,[0,.45,-.22],[1.48,.42,1.72]);part(paint,[0,.76,-.28],[1.34,.16,1.48]);part(meshes.glass,[0,.75,.36],[1.2,.08,.62],rotateX(-.28));part(meshes.glass,[0,.75,-.91],[1.18,.08,.55],rotateX(.3));part(meshes.glass,[-.68,.72,-.26],[.06,.25,1.02]);part(meshes.glass,[.68,.72,-.26],[.06,.25,1.02]);part(meshes.dark,[0,.2,1.77],[1.9,.22,.24]);part(meshes.dark,[0,.18,-1.72],[1.85,.2,.22]);part(paint,[0,.65,-1.68],[1.72,.12,.25]);part(meshes.dark,[-.55,.55,-1.67],[.12,.3,.12]);part(meshes.dark,[.55,.55,-1.67],[.12,.3,.12]);part(meshes.dark,[0,.25,1.89],[.78,.14,.06]);part(meshes.light,[-.58,.25,1.91],[.3,.1,.08]);part(meshes.light,[.58,.25,1.91],[.3,.1,.08]);part(meshes.dark,[-.72,.12,-1.84],[.12,.1,.16]);part(meshes.dark,[.72,.12,-1.84],[.12,.1,.16]);
  for(const x of [-.98,.98])for(const z of [-1.12,1.12]){const wheel=multiply(rotateZ(Math.PI/2),rotateY(time*2));part(meshes.rubber,[x,.02,z],[.62,.3,.72],wheel);part(meshes.hub,[x,.02,z],[.25,.34,.28],wheel)}
  part(meshes.dark,[0,.43,-1.1],[1.1,.18,.55]);
 }
 let disposed=false;function render(time,angle,colorHex){if(disposed)return;const rect=canvas.getBoundingClientRect(),logicalWidth=canvas.clientWidth||rect.width,logicalHeight=canvas.clientHeight||rect.height,w=Math.max(1,Math.round(logicalWidth*(devicePixelRatio||1))),h=Math.max(1,Math.round(logicalHeight*(devicePixelRatio||1)));if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;gl.viewport(0,0,w,h)}gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);const aspect=w/h,projection=perspective(mode==="garage"?.78:.7,aspect,.1,160),eye=mode==="garage"?[5.7,3.4,7.2]:[17+Math.sin(time*.00006)*1.1,12,18+Math.cos(time*.00006)*1.1],target=mode==="garage"?[0,.5,0]:[0,0,0],view=lookAt(eye,target,[0,1,0]),vp=multiply(projection,view);drawCalls=0;
  if(mode==="garage"){draw(meshes.garageFloor,multiply(translate(0,-.1,0),scale(90,.2,90)),vp);draw(meshes.garageWall,multiply(translate(0,2.7,-4.8),scale(17,6,.35)),vp);for(const x of [-5.4,5.4]){draw(meshes.garagePillar,multiply(translate(x,1.45,-3.8),scale(.55,2.9,.65)),vp);draw(meshes.light,multiply(translate(x,3.05,-3.7),scale(.72,.1,.12)),vp)}draw(meshes.light,multiply(translate(0,5.2,-3.9),scale(4.8,.12,.22)),vp);draw(meshes.platform,multiply(translate(0,.02,0),scale(6,.08,6)),vp);draw(meshes.garageNeon,identity(),vp);car(colorHex,angle,time,true,vp)}
  else {draw(meshes.ground,multiply(translate(0,-.18,0),scale(90,.2,90)),vp);draw(meshes.shoulder,identity(),vp);draw(meshes.road,identity(),vp);draw(meshes.inner,identity(),vp);draw(meshes.lane,identity(),vp);
   for(let i=0;i<28;i++){const a=i/28*Math.PI*2,x=Math.cos(a)*16.5,z=Math.sin(a)*11.2;draw(meshes.trunk,multiply(translate(x,.65,z),scale(.38,1.3,.38)),vp);draw(meshes.leaf,multiply(translate(x,1.8,z),scale(1.55,2.1,1.55)),vp)}
   for(let i=0;i<9;i++){const x=-18+i*4.4,z=(i%2? -13:13);draw(meshes.building,multiply(translate(x,1.5,z),scale(2.8,3+(i%3)*1.3,2.8)),vp)}
   const yaw=angle+Math.sin(time*.00018)*.12;car(colorHex,yaw,time,false,vp);
   for(let i=0;i<9;i++){const x=-12+i*3,z=-9;draw(meshes.light,multiply(translate(x,.55,z),scale(.12,1.1,.12)),vp)}
  }
  const stats={ready:true,mode,color:colorHex,drawCalls,meshes:cache.size+paintMeshes.size,webglVersion:gl.getParameter(gl.VERSION),frame:((mode==="garage"?window.Mshin3DGarage?.frame:window.Mshin3D?.frame)||0)+1};if(mode==="garage")window.Mshin3DGarage={...(window.Mshin3DGarage||{}),...stats,angle};else window.Mshin3D=stats;
 }
 function dispose(){disposed=true;for(const m of [...cache.values(),...paintMeshes.values()])for(const b of [m.p,m.n,m.c])gl.deleteBuffer(b);gl.deleteProgram(program)}
 return {render,dispose};
}
export function createMenu3DScene(){
 const bodyCanvas=document.createElement("canvas");bodyCanvas.id="mshinMenu3DCanvas";bodyCanvas.setAttribute("aria-hidden","true");bodyCanvas.className="mshin3d-canvas";
 const garageCanvas=document.createElement("canvas");garageCanvas.id="mshinGarage3DCanvas";garageCanvas.setAttribute("aria-hidden","true");garageCanvas.className="mshin3d-canvas mshin3d-garage";
 const fallback=()=>{window.Mshin3D={ready:false,mode:"fallback",reason:"WebGL unavailable"}};
 let menu=null,garage=null,mode="home",carId="rally",dragAngle=0,raf=0,started=performance.now();
 const body=document.body,stage=document.getElementById("showroomStage");
 body.prepend(bodyCanvas);if(stage)stage.prepend(garageCanvas);
 try{menu=createRenderer(bodyCanvas,"menu");}catch(error){fallback();bodyCanvas.classList.add("mshin3d-fallback");window.Mshin3D.reason=String(error)}
 if(stage)try{garage=createRenderer(garageCanvas,"garage");}catch(error){window.Mshin3DGarage={ready:false,reason:String(error)}}
 const updateVisibility=()=>{const home=!document.getElementById("home")?.classList.contains("hidden"),select=!document.getElementById("select")?.classList.contains("hidden"),garageTab=!!document.querySelector('[data-panel="cars"]:not([hidden])');mode=home?"home":select?"select":"hidden";const garageActive=select&&garageTab;bodyCanvas.classList.toggle("is-visible",mode!=="hidden"&&!garageActive);garageCanvas.classList.toggle("is-visible",garageActive);if(garageActive)mode="garage";};
 const observer=new MutationObserver(updateVisibility);for(const id of ["home","select"]){const el=document.getElementById(id);if(el)observer.observe(el,{attributes:true,attributeFilter:["class"]})}const tabs=document.querySelector(".menuTabs");if(tabs)observer.observe(tabs,{subtree:true,attributes:true,attributeFilter:["class","hidden"]});
 let lastFrame=0;const tick=now=>{if(now-lastFrame>=42){if(menu&&mode!=="hidden"&&mode!=="garage")menu.render(now-started,now*.000035,COLORS[carId]||COLORS.rally);if(garage&&mode==="garage")garage.render(now-started,dragAngle,COLORS[carId]||COLORS.rally);lastFrame=now}raf=requestAnimationFrame(tick)};
 let activePointer=null,lastDragCoordinate=0;const showroom=document.getElementById("showroomVehicle"),dragCoordinate=e=>window.MshinViewport?.softwareLandscape?e.clientY:e.clientX;showroom?.addEventListener("pointerdown",e=>{activePointer=e.pointerId;lastDragCoordinate=dragCoordinate(e)});showroom?.addEventListener("pointermove",e=>{if(activePointer!==e.pointerId)return;const coordinate=dragCoordinate(e);dragAngle+=(coordinate-lastDragCoordinate)*.012;lastDragCoordinate=coordinate;window.Mshin3DGarage={...(window.Mshin3DGarage||{}),angle:dragAngle,dragMoves:((window.Mshin3DGarage?.dragMoves)||0)+1}});const stopDrag=e=>{if(activePointer===e.pointerId)activePointer=null};showroom?.addEventListener("pointerup",stopDrag);showroom?.addEventListener("pointercancel",stopDrag);
 const resizeObserver=new ResizeObserver(()=>{if(menu)menu.render(performance.now()-started,0,COLORS[carId]);if(garage)garage.render(performance.now()-started,dragAngle,COLORS[carId])});resizeObserver.observe(bodyCanvas);if(stage)resizeObserver.observe(stage);
 document.querySelectorAll(".menuTab").forEach(b=>b.addEventListener("click",()=>{if(b.dataset.tab==="cars")requestAnimationFrame(updateVisibility);else requestAnimationFrame(updateVisibility)}));
 document.getElementById("play")?.addEventListener("click",()=>requestAnimationFrame(updateVisibility));
 document.querySelectorAll(".carChoice").forEach(b=>b.addEventListener("click",()=>{carId=window.MshinShowroom?.carId||carId}));
 const watchCars=new MutationObserver(()=>{const img=document.getElementById("showroomCarImage");if(img){const m=img.src.match(/car-([a-z]+)\.svg/);if(m&&COLORS[m[1]])carId=m[1]}});
 const garageNode=document.getElementById("garage");if(garageNode)watchCars.observe(garageNode,{childList:true,subtree:true});
 updateVisibility();raf=requestAnimationFrame(tick);
 return {setCar:id=>{if(COLORS[id])carId=id},setAngle:v=>{dragAngle=v},destroy:()=>{cancelAnimationFrame(raf);observer.disconnect();watchCars.disconnect();resizeObserver.disconnect();menu?.dispose();garage?.dispose();bodyCanvas.remove();garageCanvas.remove()}};
}
