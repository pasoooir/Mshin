import { PBR_VERTEX, PBR_FRAGMENT, createVehicleEnvironment, VEHICLE_MATERIALS } from "./vehicle-pbr.js";
// True WebGL vehicle showroom: real orbitable 3D geometry, not a flat SVG rotated with CSS.
const PROFILES={
 rally:{paint:"#d83b35",accent:"#f4f0e8",width:1,length:1,height:1,cabin:1,wheel:15,ride:0,style:"rally"},
 comet:{paint:"#343b43",accent:"#e63d4b",width:1.08,length:1.18,height:.78,cabin:.72,wheel:14,ride:-3,style:"gt"},
 lynx:{paint:"#73818a",accent:"#f1a52d",width:1.15,length:1.02,height:1.18,cabin:1.2,wheel:19,ride:8,style:"suv"},
 thunder:{paint:"#20a9a5",accent:"#d9ffff",width:1.08,length:1.08,height:.82,cabin:.75,wheel:15,ride:-1,style:"electric"},
 raptor:{paint:"#c58b36",accent:"#252d32",width:1.18,length:1.06,height:1.12,cabin:1.04,wheel:20,ride:11,style:"offroad"},
 "ai-formula":{paint:"#d6e1ed",accent:"#ed3147",width:.9,length:1.2,height:.72,cabin:.5,wheel:19,ride:-2,style:"formula"},
 "ai-pickup":{paint:"#b06d39",accent:"#f2d2a1",width:1.12,length:1.12,height:1.1,cabin:1.02,wheel:18,ride:8,style:"pickup"},
 "ai-rallycross":{paint:"#5c9b63",accent:"#e8efcf",width:1.1,length:1.05,height:1.08,cabin:.98,wheel:17,ride:5,style:"rallycross"},
 "ai-touring":{paint:"#8a4bb4",accent:"#f1d6ff",width:1.08,length:1.02,height:1,cabin:.96,wheel:16,ride:1,style:"touring"},
 "ai-prototype":{paint:"#d0d9df",accent:"#4de1e2",width:1,length:1.22,height:.78,cabin:.7,wheel:16,ride:-1,style:"prototype"}
};
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const color=s=>{const h=s.replace("#","");return [0,2,4].map(i=>parseInt(h.slice(i,i+2),16)/255)};
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]];
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const normalize=v=>{const n=Math.hypot(...v)||1;return v.map(x=>x/n)};
function perspective(fov,aspect,near,far){const f=1/Math.tan(fov/2),d=1/(near-far);return new Float32Array([f/aspect,0,0,0,0,f,0,0,0,0,(far+near)*d,-1,0,0,2*far*near*d,0])}
function lookAt(eye,target,up){const z=normalize(sub(eye,target)),x=normalize(cross(up,z)),y=cross(z,x);return new Float32Array([x[0],y[0],z[0],0,x[1],y[1],z[1],0,x[2],y[2],z[2],0,-x.reduce((s,v,i)=>s+v*eye[i],0),-y.reduce((s,v,i)=>s+v*eye[i],0),-z.reduce((s,v,i)=>s+v*eye[i],0),1])}
function multiply(a,b){const o=new Float32Array(16);for(let c=0;c<4;c++)for(let r=0;r<4;r++)o[c*4+r]=a[r]*b[c*4]+a[4+r]*b[c*4+1]+a[8+r]*b[c*4+2]+a[12+r]*b[c*4+3];return o}
function shader(gl,type,source){const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw new Error(gl.getShaderInfoLog(s)||"Vehicle showroom shader failed");return s}
function programFor(gl){const p=gl.createProgram(),v=shader(gl,gl.VERTEX_SHADER,PBR_VERTEX),f=shader(gl,gl.FRAGMENT_SHADER,PBR_FRAGMENT);gl.attachShader(p,v);gl.attachShader(p,f);gl.linkProgram(p);gl.deleteShader(v);gl.deleteShader(f);if(!gl.getProgramParameter(p,gl.LINK_STATUS))throw new Error(gl.getProgramInfoLog(p)||"Vehicle showroom program failed");return p}
function geometry(){return []}
function tri(out,a,b,c){out.push(...a,...b,...c)}
function quad(out,a,b,c,d){tri(out,a,b,c);tri(out,a,c,d)}
function box(out,x,y,z,w,h,d){const x0=x-w/2,x1=x+w/2,y0=y-h/2,y1=y+h/2,z0=z-d/2,z1=z+d/2;quad(out,[x0,y0,z1],[x1,y0,z1],[x1,y1,z1],[x0,y1,z1]);quad(out,[x1,y0,z0],[x0,y0,z0],[x0,y1,z0],[x1,y1,z0]);quad(out,[x0,y0,z0],[x0,y0,z1],[x0,y1,z1],[x0,y1,z0]);quad(out,[x1,y0,z1],[x1,y0,z0],[x1,y1,z0],[x1,y1,z1]);quad(out,[x0,y1,z1],[x1,y1,z1],[x1,y1,z0],[x0,y1,z0]);quad(out,[x0,y0,z0],[x1,y0,z0],[x1,y0,z1],[x0,y0,z1])}
function cylinderX(out,x,y,z,r,depth,segments=24){for(let i=0;i<segments;i++){const a=i/segments*Math.PI*2,b=(i+1)/segments*Math.PI*2,p=[x,y+Math.cos(a)*r,z+Math.sin(a)*r],q=[x,y+Math.cos(b)*r,z+Math.sin(b)*r],p2=[x+depth,y+Math.cos(a)*r,z+Math.sin(a)*r],q2=[x+depth,y+Math.cos(b)*r,z+Math.sin(b)*r];quad(out,p,q,q2,p2);tri(out,[x,y,z],q,p);tri(out,[x+depth,y,z],p2,q2)}}
function mesh(gl,vertices,paint,materialName="body",emissive=0){const data=new Float32Array(vertices.length/3*6);let k=0;for(let i=0;i<vertices.length;i+=9){const a=vertices.slice(i,i+3),b=vertices.slice(i+3,i+6),c=vertices.slice(i+6,i+9),n=normalize(cross(sub(b,a),sub(c,a)));for(let j=0;j<3;j++){data[k++]=vertices[i+j*3];data[k++]=vertices[i+j*3+1];data[k++]=vertices[i+j*3+2];data[k++]=n[0];data[k++]=n[1];data[k++]=n[2]}}const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,data,gl.STATIC_DRAW);const material=VEHICLE_MATERIALS[materialName]||VEHICLE_MATERIALS.body;return {buffer,count:data.length/6,color:color(paint),...material,emissive}}
export function buildVehicleGeometry(id){
 const p=PROFILES[id]||PROFILES.rally,w=p.width,L=p.length,h=p.height,body=geometry(),glass=geometry(),trim=geometry(),rubber=geometry(),rims=geometry(),brakes=geometry(),interior=geometry(),lights=geometry(),aero=geometry(),decals=geometry();
 // Low, wide racing shell with a tapered nose, shoulder volume and raised rear haunches.
 const stations=[[-68,19,9,22],[-54,29,11,29],[-30,34,13,33],[4,36,13,35],[39,33,12,32],[61,27,12,27],[69,20,13,20]];
 const rings=stations.map(([z,bottom,side,top])=>[[-bottom*w,10*h,z*L],[bottom*w,10*h,z*L],[side*w,22*h,z*L],[top*w,34*h,z*L],[-top*w,34*h,z*L],[-side*w,22*h,z*L]]);
 for(let i=0;i<rings.length-1;i++)for(let j=0;j<6;j++)quad(body,rings[i][j],rings[i][(j+1)%6],rings[i+1][(j+1)%6],rings[i+1][j]);
 for(let i=1;i<stations.length-1;i++){const a=stations[i],b=stations[i+1];quad(body,[-a[3]*w,34*h,a[0]*L],[a[3]*w,34*h,a[0]*L],[b[3]*w,34*h,b[0]*L],[-b[3]*w,34*h,b[0]*L])}
 // Integrated greenhouse: windshield, fastback rear screen, roof and side glass.
 const base=32*p.cabin,roof=base+20*p.cabin,low=25*p.cabin*w,high=17*p.cabin*w;
 const fz=25*L,rz=-39*L,rf=8*L,rr=-25*L;
 quad(body,[-low,base,fz],[low,base,fz],[high,roof,rf],[-high,roof,rf]);
 quad(body,[low,base,rz],[-low,base,rz],[-high,roof,rr],[high,roof,rr]);
 quad(body,[-low,base,rz],[-low,base,fz],[-high,roof,rf],[-high,roof,rr]);
 quad(body,[low,base,fz],[low,base,rz],[high,roof,rr],[high,roof,rf]);
 quad(body,[-high,roof,rf],[high,roof,rf],[high,roof,rr],[-high,roof,rr]);
 quad(glass,[-low+2,base+2,fz-2],[low-2,base+2,fz-2],[high-2,roof-2,rf+1],[-high+2,roof-2,rf+1]);
 quad(glass,[low-2,base+2,rz+2],[-low+2,base+2,rz+2],[-high+2,roof-2,rr-1],[high-2,roof-2,rr-1]);
 for(const side of [-1,1])quad(glass,[side*(low-2),base+3,fz-6],[side*(low-2),base+3,rz+6],[side*(high-2),roof-3,rr+4],[side*(high-2),roof-3,rf-4]);
 // Deep wheel arches, flared fenders and integrated side aero.
 for(const side of [-1,1]){
  for(const zc of [-43,43]){
   const x=side*38*w,cy=p.wheel+12+p.ride;
   for(let i=0;i<16;i++){const a=i/16*Math.PI,b=(i+1)/16*Math.PI,point=(r,t,offset)=>[x+side*offset,cy+Math.sin(t)*r,zc*L+Math.cos(t)*r];quad(body,point(p.wheel+7,a,0),point(p.wheel+7,b,0),point(p.wheel+1,b,0),point(p.wheel+1,a,0))}
   for(let i=0;i<16;i++){const a=i/16*Math.PI,b=(i+1)/16*Math.PI,point=(r,t,offset)=>[x+side*offset,cy+Math.sin(t)*r,zc*L+Math.cos(t)*r];quad(trim,point(p.wheel+8,a,2),point(p.wheel+8,b,2),point(p.wheel+5,b,5),point(p.wheel+5,a,5))}
  }
  // Mirrors, side skirts, recessed door seams and crisp shoulder creases.
  box(trim,side*39*w,13*h,0,3,4,74*L);box(trim,side*35*w,25*h,-2*L,1.2,1.5,80*L);
  box(trim,side*35*w,29*h,3*L,1.2,1.2,48*L);
  box(trim,side*39*w,39*p.cabin,8*L,8,4,8);
  box(trim,side*43*w,40*p.cabin,8*L,4,3,5);
  // Carbon side vent and vertical door cut lines.
  box(aero,side*35*w,23*h,-23*L,2,7,13);
  box(trim,side*34*w,21*h,0,1,1,2);
 }
 // Hood creases, front grille, intakes and LED signatures.
 for(const side of [-1,1]){
  box(trim,side*11*w,28*h,45*L,1.5,1.4,32*L);
  box(lights,side*21*w,24*h,65*L,12*w,3,2);
  box(lights,side*21*w,22*h,-66*L,11*w,3,2);
 }
 box(aero,0,10*h,68*L,62*w,3,10);
 box(trim,0,19*h,68*L,24*w,7,2);
 box(trim,0,18*h,69*L,13*w,3,2);
 box(trim,0,13*h,-67*L,44*w,5,4);
 // Cockpit furniture, roll structure and race-grade cabin details visible through the glazing.
 box(interior,-10*w,31*p.cabin,-7*L,13,5,17);box(interior,10*w,31*p.cabin,-7*L,13,5,17);
 box(interior,-10*w,39*p.cabin,-13*L,11,17*p.cabin,5);box(interior,10*w,39*p.cabin,-13*L,11,17*p.cabin,5);
 box(interior,0,32*p.cabin,23*L,48*w,5,9);box(interior,0,37*p.cabin,28*L,3,3,4);
 box(interior,-21*w,42*p.cabin,-2*L,2,19*p.cabin,2);box(interior,21*w,42*p.cabin,-2*L,2,19*p.cabin,2);
 // Touring wing and rear diffuser; off-road and SUV profiles receive tall clearance details.
 if(p.style!=="electric"){box(aero,0,53*p.cabin,-63*L,62*w,3,6);box(aero,-27*w,44*p.cabin,-63*L,3,13,5);box(aero,27*w,44*p.cabin,-63*L,3,13,5)}
 if(p.style==="offroad"||p.style==="suv"){box(aero,0,59*h,-5*L,52*w,3,46*L);box(aero,-24*w,51*h,-5*L,3,15,42*L);box(aero,24*w,51*h,-5*L,3,15,42*L);box(trim,0,68*h,0,4,3,105*L)}
 if(p.style==="rally"){for(const side of [-1,1])box(decals,side*20*w,35*h,-2*L,5,1,100*L);box(aero,0,59*h,-59*L,72*w,3,5)}
 if(p.style==="gt"){
  // Zola-inspired graphite supercar package: low nose, deep side intakes,
  // carbon splitter, sculpted rear diffuser and a wide, supported rear wing.
  box(aero,0,10*h,70*L,82*w,3,16);
  box(aero,0,12*h,73*L,94*w,3,8);
  for(const side of [-1,1]){
   box(aero,side*34*w,20*h,3*L,5,12*h,34*L);
   box(trim,side*36*w,23*h,4*L,2,8*h,26*L);
   box(aero,side*28*w,11*h,-57*L,8,5,23*L);
   box(trim,side*21*w,27*h,55*L,13*w,2,12*L);
   box(lights,side*25*w,25*h,65*L,15*w,2.2,3);
  }
  box(aero,0,8*h,-68*L,78*w,4,9);
  for(const fin of [-3,-1,1,3])box(aero,fin*9*w,8*h,-67*L,2,5,16);
  box(aero,0,58*h,-62*L,88*w,3,6);
  box(aero,-34*w,43*h,-62*L,3,15,6);
  box(aero,34*w,43*h,-62*L,3,15,6);
  box(trim,0,18*h,69*L,18*w,5,2);
 }
 if(p.style==="electric"){box(decals,0,35*h,-2*L,7,1,100*L);box(aero,0,13*h,-67*L,50*w,4,5)}
 if(p.style==="suv"||p.style==="offroad"){box(body,0,31*h,-44*L,48*w,7*h,34*L)}
 if(p.style==="offroad"){box(trim,0,64*h,0,4,4,115*L);box(aero,0,8*h,0,68*w,4,12)}
 if(p.style==="formula"){box(aero,0,12*h,73*L,88*w,4,14);box(aero,0,14*h,-72*L,92*w,4,13);box(body,0,27*h,4*L,17*w,10*h,48*L);box(aero,-22*w,19*h,-4*L,15*w,7*h,48*L);box(aero,22*w,19*h,-4*L,15*w,7*h,48*L)}
 if(p.style==="pickup"){box(body,0,31*h,-45*L,50*w,9*h,36*L);for(const side of [-1,1])box(trim,side*26*w,43*h,-45*L,3,13*h,39*L);box(trim,0,43*h,-64*L,52*w,13*h,3)}
 if(p.style==="rallycross"){for(const side of [-1,1]){box(aero,side*42*w,24*h,-43*L,7,8*h,31*L);box(aero,side*42*w,24*h,43*L,7,8*h,31*L)}box(aero,0,59*h,-61*L,78*w,4,6);box(aero,0,58*h,0,5,4,35*L)}
 if(p.style==="touring"){box(aero,0,13*h,68*L,70*w,4,10);box(aero,0,55*h,-61*L,68*w,4,6);for(const side of [-1,1])box(decals,side*22*w,35*h,-4*L,5,1,112*L)}
 if(p.style==="prototype"){box(aero,0,48*h,-4*L,5,20*h,90*L);box(aero,0,12*h,70*L,80*w,4,12);box(aero,0,55*h,-65*L,84*w,4,7);box(body,0,32*h,-3*L,30*w,10*h,58*L)}
 // Four tires, sidewall rings, brake discs, multi-spoke alloys and center-lock hubs.
 for(const x0 of [-38*w,38*w])for(const z0 of [-43*L,43*L]){
  const x=x0-(x0<0?9:-1),y=p.wheel+12+p.ride,z=z0;
  cylinderX(rubber,x,y,z,p.wheel,18,28);
  cylinderX(rims,x+(x0<0?16:0),y,z,p.wheel*.68,2,24);
  cylinderX(rims,x+(x0<0?16:0),y,z,p.wheel*.48,2.5,20);
  cylinderX(trim,x+(x0<0?19:0),y,z,3.8,2,16);
  for(let spoke=0;spoke<10;spoke++){const a=spoke/10*Math.PI*2,xx=x+(x0<0?19:0)+1.2,cy=y+Math.cos(a)*p.wheel*.43,cz=z+Math.sin(a)*p.wheel*.43;box(rims,xx,cy,cz,2,2.1,Math.max(2,p.wheel*.48))}
 }
 // Exhaust tips, hood louvres, washer jets, windshield wipers and panel hardware.
 for(const side of [-1,1]){cylinderX(trim,side*18*w-3,11*h,-69*L,3.2,7,18);box(aero,side*10*w,35*h,43*L,5,1.2,13*L);box(trim,side*12*w,33*h,43*L,1.2,1,13*L);box(trim,side*14*w,34*h,24*L,2,1,12)}
 box(trim,0,31*p.cabin,24*L,35*w,1.2,2);box(trim,0,29*p.cabin,21*L,28*w,1,2);
 // Carbon brake vents, mirrors, race number plates and subtle pinstriping.
 box(decals,0,36*h,0,15,1,12);
 return [
  {vertices:body,paint:p.paint,material:"body",emissive:0},{vertices:glass,paint:"#122d42",material:"glass",emissive:.02},
  {vertices:trim,paint:"#aebbc5",material:"trim",emissive:0},{vertices:rubber,paint:"#11151a",material:"rubber",emissive:0},
  {vertices:rims,paint:"#dce6ed",material:"rims",emissive:.01},{vertices:lights,paint:"#eafcff",material:"lights",emissive:.32},
  {vertices:aero,paint:"#202b35",material:"aero",emissive:0},{vertices:decals,paint:p.accent,material:"decals",emissive:.01}
 ];
}

export function buildVehicleDamageGeometry(id){
 const p=PROFILES[id]||PROFILES.rally,w=p.width,L=p.length,h=p.height,light=geometry(),dark=geometry();
 // Fine metallic scratches follow the sculpted hood surface instead of floating above it.
 quad(light,[-17*w,29.8*h,55*L],[-14*w,29.8*h,55*L],[-25*w,34.8*h,28*L],[-28*w,34.8*h,28*L]);
 quad(light,[4*w,30.8*h,54*L],[7*w,30.8*h,54*L],[-3*w,34.8*h,29*L],[-6*w,34.8*h,29*L]);
 quad(dark,[17*w,30.2*h,52*L],[19*w,30.2*h,52*L],[11*w,34.2*h,30*L],[9*w,34.2*h,30*L]);
 quad(dark,[-3*w,30.6*h,58*L],[-1*w,30.6*h,58*L],[-9*w,34.4*h,34*L],[-11*w,34.4*h,34*L]);
 return [
  {vertices:light,paint:"#dce5eb",material:"trim",emissive:.035},
  {vertices:dark,paint:"#46515a",material:"trim",emissive:.01}
 ];
}

function buildVehicle(gl,id){return buildVehicleGeometry(id).map(item=>mesh(gl,item.vertices,item.paint,item.material,item.emissive));}
export function createVehicleShowroom(canvas){
 const state={status:"initializing",vehicle:"rally",yaw:-.55,pitch:.16,frames:0,triangles:0,materialPipeline:"automotive-pbr-ggx-clearcoat",environmentMapReady:false};
 let gl,program,locations,environment,parts=[],raf=0,last=0,width=0,height=0,drag=null,spinUntil=0,yaw=state.yaw,disposed=false,visible=!document.hidden,intersecting=true,contextLost=false;
 try{
  gl=canvas.getContext("webgl",{alpha:true,antialias:true,depth:true,powerPreference:"low-power"})||canvas.getContext("experimental-webgl");
  if(!gl)throw new Error("WebGL is unavailable");
  program=programFor(gl);environment=createVehicleEnvironment(gl);state.environmentMapReady=!!environment;locations={position:gl.getAttribLocation(program,"aPosition"),normal:gl.getAttribLocation(program,"aNormal"),mvp:gl.getUniformLocation(program,"uMvp"),model:gl.getUniformLocation(program,"uModel"),color:gl.getUniformLocation(program,"uBaseColor"),camera:gl.getUniformLocation(program,"uCameraPosition"),light:gl.getUniformLocation(program,"uLightDirection"),lightColor:gl.getUniformLocation(program,"uLightColor"),env:gl.getUniformLocation(program,"uEnvironmentMap"),metal:gl.getUniformLocation(program,"uMetallic"),roughness:gl.getUniformLocation(program,"uRoughness"),clearcoat:gl.getUniformLocation(program,"uClearcoat"),kind:gl.getUniformLocation(program,"uMaterialKind"),emissive:gl.getUniformLocation(program,"uEmissive")};
  gl.enable(gl.DEPTH_TEST);gl.disable(gl.CULL_FACE);gl.clearColor(0,0,0,0);
  parts=buildVehicle(gl,"rally");state.status="webgl-ready";
 }catch(error){state.status="unavailable";state.error=String(error?.message||error);return {state,setVehicle(){},spin360(){},destroy(){}}}
 const pointerDown=event=>{if(event.button!==undefined&&event.button!==0)return;drag={pointerId:event.pointerId,x:event.clientX,y:event.clientY};spinUntil=0;try{canvas.setPointerCapture?.(event.pointerId)}catch{}};
 const release=event=>{if(drag!==null&&(event?.pointerId==null||event.pointerId===drag.pointerId))drag=null};
 const move=event=>{if(!drag||event.pointerId!==drag.pointerId)return;const dx=event.clientX-drag.x,dy=event.clientY-drag.y;drag={...drag,x:event.clientX,y:event.clientY};yaw+=dx*.012;state.pitch=clamp(state.pitch+dy*.008,-.38,.62);};
 const onVisibility=()=>{visible=!document.hidden;if(visible&&intersecting&&!contextLost&&!disposed&&!raf){last=0;raf=requestAnimationFrame(draw)}};
 const onContextLost=event=>{event.preventDefault();contextLost=true;state.status="context-lost";if(raf)cancelAnimationFrame(raf);raf=0};
 const onContextRestored=()=>{state.status="context-restored-reload-required"};
 canvas.addEventListener("pointerdown",pointerDown);
 window.addEventListener("pointermove",move);window.addEventListener("pointerup",release);window.addEventListener("pointercancel",release);
 document.addEventListener("visibilitychange",onVisibility);
 canvas.addEventListener("webglcontextlost",onContextLost,false);
 canvas.addEventListener("webglcontextrestored",onContextRestored,false);
 const resize=()=>{const rect=canvas.getBoundingClientRect(),dpr=Math.min(devicePixelRatio||1,1.35);width=Math.max(1,Math.round(rect.width*dpr));height=Math.max(1,Math.round(rect.height*dpr));if(canvas.width!==width||canvas.height!==height){canvas.width=width;canvas.height=height;gl.viewport(0,0,width,height)}};
 const observer=typeof ResizeObserver!=="undefined"?new ResizeObserver(resize):null;observer?.observe(canvas);
 const intersectionObserver=typeof IntersectionObserver!=="undefined"?new IntersectionObserver(entries=>{intersecting=!!entries[0]?.isIntersecting;if(intersecting&&visible&&!contextLost&&!disposed&&!raf){last=0;raf=requestAnimationFrame(draw)}else if(!intersecting&&raf){cancelAnimationFrame(raf);raf=0}}):null;
 intersectionObserver?.observe(canvas);resize();
 const identity=new Float32Array([1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]);
 const draw=now=>{
  raf=0;if(disposed||!visible||!intersecting||contextLost)return;
  if(visible&&intersecting&&!contextLost)raf=requestAnimationFrame(draw);if(now-last<30)return;last=now;
  resize();if(spinUntil>now)yaw+=.14;state.yaw=yaw;state.frames++;
  gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);gl.useProgram(program);
  const aspect=width/Math.max(1,height),projection=perspective(.68,aspect,.1,900),distance=225;
  const eye=[Math.sin(yaw)*Math.cos(state.pitch)*distance,Math.sin(state.pitch)*distance+57,Math.cos(yaw)*Math.cos(state.pitch)*distance];
  const view=lookAt(eye,[0,31,0],[0,1,0]),mvp=multiply(projection,view);
  gl.uniformMatrix4fv(locations.mvp,false,mvp);gl.uniformMatrix4fv(locations.model,false,identity);gl.uniform3f(locations.camera,eye[0],eye[1],eye[2]);gl.uniform3f(locations.light,-.45,.88,.35);gl.uniform3f(locations.lightColor,4.2,3.9,3.55);gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_CUBE_MAP,environment);gl.uniform1i(locations.env,0);let triangles=0;
  for(const item of parts){gl.bindBuffer(gl.ARRAY_BUFFER,item.buffer);gl.enableVertexAttribArray(locations.position);gl.vertexAttribPointer(locations.position,3,gl.FLOAT,false,24,0);gl.enableVertexAttribArray(locations.normal);gl.vertexAttribPointer(locations.normal,3,gl.FLOAT,false,24,12);gl.uniform3fv(locations.color,item.color);gl.uniform1f(locations.metal,item.metallic);gl.uniform1f(locations.roughness,item.roughness);gl.uniform1f(locations.clearcoat,item.clearcoat);gl.uniform1f(locations.kind,item.kind);gl.uniform1f(locations.emissive,item.emissive);gl.drawArrays(gl.TRIANGLES,0,item.count);triangles+=item.count/3}
  state.triangles=triangles;
 };
 raf=requestAnimationFrame(draw);
 return {
  state,
  setVehicle(id){const next=PROFILES[id]?id:"rally";if(next===state.vehicle)return;for(const p of parts)gl.deleteBuffer(p.buffer);parts=buildVehicle(gl,next);state.vehicle=next;state.pitch=.16;yaw=-.55;state.yaw=yaw},
  spin360(){spinUntil=performance.now()+1500;},
  destroy(){if(disposed)return;disposed=true;if(raf)cancelAnimationFrame(raf);raf=0;observer?.disconnect();intersectionObserver?.disconnect();canvas.removeEventListener("pointerdown",pointerDown);canvas.removeEventListener("webglcontextlost",onContextLost);canvas.removeEventListener("webglcontextrestored",onContextRestored);document.removeEventListener("visibilitychange",onVisibility);window.removeEventListener("pointermove",move);window.removeEventListener("pointerup",release);window.removeEventListener("pointercancel",release);for(const p of parts)gl.deleteBuffer(p.buffer);try{gl.deleteProgram(program);gl.deleteTexture(environment)}catch{}}
 };
}
