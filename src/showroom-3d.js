const vertexSource = `
attribute vec3 aPosition;
attribute vec3 aNormal;
uniform mat4 uMvp;
uniform mat4 uModel;
varying vec3 vNormal;
varying vec3 vWorldPosition;
void main(){
  vec4 world=uModel*vec4(aPosition,1.0);
  vWorldPosition=world.xyz;
  vNormal=mat3(uModel)*aNormal;
  gl_Position=uMvp*vec4(aPosition,1.0);
}`;
const fragmentSource = `
precision mediump float;
uniform vec3 uColor;
uniform float uMetallic;
varying vec3 vNormal;
varying vec3 vWorldPosition;
void main(){
  vec3 n=normalize(vNormal);
  vec3 light=normalize(vec3(-0.45,0.82,0.62));
  float diffuse=max(dot(n,light),0.0);
  float rim=pow(1.0-max(dot(n,normalize(vec3(0.0,0.0,1.0))),0.0),2.0)*0.16;
  float spec=pow(max(dot(reflect(-light,n),normalize(vec3(0.2,0.7,0.7))),0.0),mix(18.0,52.0,uMetallic))*0.24*uMetallic;
  vec3 color=uColor*(0.32+diffuse*0.68)+vec3(0.38,0.72,0.92)*rim+vec3(spec);
  gl_FragColor=vec4(color,1.0);
}`;

const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const sub=(a,b)=>[a[0]-b[0],a[1]-b[1],a[2]-b[2]];
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const normalize=v=>{const l=Math.hypot(v[0],v[1],v[2])||1;return [v[0]/l,v[1]/l,v[2]/l]};
function perspective(fovy,aspect,near,far){
 const f=1/Math.tan(fovy/2),nf=1/(near-far);
 return new Float32Array([f/aspect,0,0,0,0,f,0,0,0,0,(far+near)*nf,-1,0,0,2*far*near*nf,0]);
}
function lookAt(eye,center,up){
 const z=normalize(sub(eye,center)),x=normalize(cross(up,z)),y=cross(z,x);
 return new Float32Array([x[0],y[0],z[0],0,x[1],y[1],z[1],0,x[2],y[2],z[2],0,-(x[0]*eye[0]+x[1]*eye[1]+x[2]*eye[2]),-(y[0]*eye[0]+y[1]*eye[1]+y[2]*eye[2]),-(z[0]*eye[0]+z[1]*eye[1]+z[2]*eye[2]),1]);
}
function multiply(a,b){
 const out=new Float32Array(16);
 for(let c=0;c<4;c++)for(let r=0;r<4;r++)out[c*4+r]=a[r]*b[c*4]+a[4+r]*b[c*4+1]+a[8+r]*b[c*4+2]+a[12+r]*b[c*4+3];
 return out;
}
function rotationY(angle){
 const c=Math.cos(angle),s=Math.sin(angle);
 return new Float32Array([c,0,-s,0,0,1,0,0,s,0,c,0,0,0,0,1]);
}
function translation(x,y,z){return new Float32Array([1,0,0,0,0,1,0,0,0,0,1,0,x,y,z,1])}
function scale(x,y,z){return new Float32Array([x,0,0,0,0,y,0,0,0,0,z,0,0,0,0,1])}
function compose(a,b){return multiply(a,b)}
function shader(gl,type,source){
 const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);
 if(!gl.getShaderParameter(s,gl.COMPILE_STATUS)){const message=gl.getShaderInfoLog(s);gl.deleteShader(s);throw new Error(message||"Showroom shader compilation failed")}
 return s;
}
function program(gl){
 const p=gl.createProgram(),vs=shader(gl,gl.VERTEX_SHADER,vertexSource),fs=shader(gl,gl.FRAGMENT_SHADER,fragmentSource);
 gl.attachShader(p,vs);gl.attachShader(p,fs);gl.linkProgram(p);gl.deleteShader(vs);gl.deleteShader(fs);
 if(!gl.getProgramParameter(p,gl.LINK_STATUS))throw new Error(gl.getProgramInfoLog(p)||"Showroom shader link failed");
 return p;
}
function makeMesh(gl,triangles){
 const data=[];
 for(const tri of triangles){
  const n=normalize(cross(sub(tri[1],tri[0]),sub(tri[2],tri[0])));
  for(const p of tri)data.push(p[0],p[1],p[2],n[0],n[1],n[2]);
 }
 const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(data),gl.STATIC_DRAW);
 return {buffer,count:data.length/6};
}
function boxTriangles(cx,cy,cz,sx,sy,sz){
 const x=sx/2,y=sy/2,z=sz/2;
 const p=[[-x,-y,-z],[x,-y,-z],[x,y,-z],[-x,y,-z],[-x,-y,z],[x,-y,z],[x,y,z],[-x,y,z]].map(v=>[v[0]+cx,v[1]+cy,v[2]+cz]);
 const faces=[[0,3,2,1],[4,5,6,7],[4,7,3,0],[1,2,6,5],[3,7,6,2],[4,0,1,5]];
 const out=[];for(const [a,b,c,d] of faces){out.push([p[a],p[b],p[c]],[p[a],p[c],p[d]])}return out;
}
function loftTriangles(sections){
 const rings=sections.map(([z,w,h,y])=>Array.from({length:12},(_,i)=>{const a=i/12*Math.PI*2;return [Math.cos(a)*w,y+Math.sin(a)*h,z]}));
 const out=[];
 for(let r=0;r<rings.length-1;r++)for(let i=0;i<12;i++){
  const a=rings[r][i],b=rings[r][(i+1)%12],c=rings[r+1][(i+1)%12],d=rings[r+1][i];
  out.push([a,b,c],[a,c,d]);
 }
 return out;
}
function cylinderX(cx,cy,cz,r,length,segments=16){
 const out=[],x1=cx-length/2,x2=cx+length/2;
 for(let i=0;i<segments;i++){
  const a=i/segments*Math.PI*2,b=(i+1)/segments*Math.PI*2;
  const p1=[x1,cy+Math.cos(a)*r,cz+Math.sin(a)*r],p2=[x1,cy+Math.cos(b)*r,cz+Math.sin(b)*r],p3=[x2,cy+Math.cos(b)*r,cz+Math.sin(b)*r],p4=[x2,cy+Math.cos(a)*r,cz+Math.sin(a)*r];
  out.push([p1,p2,p3],[p1,p3,p4],[[x1,cy,cz],p2,p1],[[x2,cy,cz],p4,p3]);
 }
 return out;
}
function buildCar(gl){
 const parts=[];
 const add=(triangles,color,metallic=0)=>parts.push({mesh:makeMesh(gl,triangles),color,metallic});
 add(loftTriangles([[-1.65,.46,.24,.42],[-1.38,.55,.31,.47],[-.8,.59,.34,.49],[.55,.57,.32,.48],[1.25,.49,.27,.45],[1.62,.36,.2,.42]]),[.82,.12,.09],.82);
 add(loftTriangles([[-.95,.38,.25,.67],[-.58,.43,.43,.78],[.52,.41,.42,.78],[.98,.34,.23,.65]]),[.055,.12,.19],.55);
 add(boxTriangles(0,.99,-.04,.58,.055,.68),[.11,.2,.28],.75);
 add(boxTriangles(0,.66,1.34,.7,.1,.12),[.92,.93,.78],.35);
 add(boxTriangles(0,.65,-1.45,.78,.1,.1),[.95,.12,.055],.35);
 add(boxTriangles(0,.79,-1.52,1.08,.08,.12),[.12,.14,.17],.7);
 for(const x of [-.57,.57])for(const z of [-1.05,1.02]){
  add(cylinderX(x,.36,z,.34,.19),[.025,.03,.04],.18);
  add(cylinderX(x+(x>0?.105:-.105),.36,z,.205,.025),[.42,.5,.56],.86);
  add(cylinderX(x+(x>0?.121:-.121),.36,z,.085,.03),[.075,.1,.13],.8);
 }
 for(const x of [-.34,.34]){
  add(boxTriangles(x,.49,1.48,.17,.07,.035),[.8,.92,1],.65);
  add(boxTriangles(x,.48,-1.53,.2,.065,.035),[1,.055,.025],.3);
 }
 add(boxTriangles(0,.86,-1.36,1.1,.07,.1),[.16,.18,.21],.65);
 return parts;
}
function buildStage(gl){
 const parts=[];
 parts.push({mesh:makeMesh(gl,boxTriangles(0,-.13,0,14,.16,14)),color:[.055,.09,.13],metallic:.12});
 const lineTriangles=[];
 for(let i=-6;i<=6;i++){
  lineTriangles.push(...boxTriangles(i*.9,-.043,0,.012,.006,12),...boxTriangles(0,-.042,i*.9,12,.006,.012));
 }
 parts.push({mesh:makeMesh(gl,lineTriangles),color:[.12,.23,.29],metallic:.28});
 parts.push({mesh:makeMesh(gl,boxTriangles(0,-.045,0,3.1,.012,4.1)),color:[.075,.12,.17],metallic:.18});
 return parts;
}
export function createShowroom3D(canvas){
 let gl=null,programInfo=null,carParts=[],stageParts=[],raf=0,visible=false,destroyed=false,rotation=0,spinStart=0,spinFrom=0,spinDuration=1450,frameCount=0,autoRotate=0,lastFrame=0,modelScale=1,model={id:"rally",color:"#f15d4e"},lastSize="";
 const state={status:"initializing",carId:model.id,rotation:0,scale:1,frameCount:0,renderer:"WebGL 1"};
 try{
  gl=canvas.getContext("webgl",{alpha:false,antialias:true,depth:true,powerPreference:"low-power",preserveDrawingBuffer:true})||canvas.getContext("experimental-webgl");
  if(!gl)throw new Error("WebGL is unavailable");
  programInfo=program(gl);carParts=buildCar(gl);stageParts=buildStage(gl);
  const p=programInfo;
  state.status="webgl";
  gl.useProgram(p);
  const position=gl.getAttribLocation(p,"aPosition"),normal=gl.getAttribLocation(p,"aNormal");
  state.position=position;state.normal=normal;
  const uniforms={mvp:gl.getUniformLocation(p,"uMvp"),model:gl.getUniformLocation(p,"uModel"),color:gl.getUniformLocation(p,"uColor"),metallic:gl.getUniformLocation(p,"uMetallic")};
  gl.enable(gl.DEPTH_TEST);gl.enable(gl.CULL_FACE);gl.cullFace(gl.BACK);gl.clearColor(.025,.055,.09,1);
  const view=lookAt([3.1,2.25,4.25],[0,.42,0],[0,1,0]);
  function resize(){
   if(destroyed)return;
   const rect=canvas.getBoundingClientRect(),logicalWidth=canvas.clientWidth||rect.width,logicalHeight=canvas.clientHeight||rect.height,dpr=Math.min(window.devicePixelRatio||1,1.7),w=Math.max(1,Math.round(logicalWidth*dpr)),h=Math.max(1,Math.round(logicalHeight*dpr)),key=w+"x"+h;
   if(key===lastSize)return;lastSize=key;canvas.width=w;canvas.height=h;gl.viewport(0,0,w,h);
  }
  function drawParts(parts,viewProjection,modelMatrix){
   gl.uniformMatrix4fv(uniforms.model,false,modelMatrix);
   gl.uniformMatrix4fv(uniforms.mvp,false,multiply(viewProjection,modelMatrix));
   for(const part of parts){
    gl.bindBuffer(gl.ARRAY_BUFFER,part.mesh.buffer);
    gl.enableVertexAttribArray(position);gl.vertexAttribPointer(position,3,gl.FLOAT,false,24,0);
    gl.enableVertexAttribArray(normal);gl.vertexAttribPointer(normal,3,gl.FLOAT,false,24,12);
    gl.uniform3fv(uniforms.color,part.color);gl.uniform1f(uniforms.metallic,part.metallic);
    gl.drawArrays(gl.TRIANGLES,0,part.mesh.count);
   }
  }
  function render(now){
   if(destroyed||!visible)return;
   if(lastFrame&&now-lastFrame<1000/30){raf=window.requestAnimationFrame(render);return;}
   resize();
   const delta=lastFrame?Math.min((now-lastFrame)/1000,.05):0;lastFrame=now;if(autoRotate&&!spinStart)rotation=(rotation+autoRotate*delta)%360;
   if(spinStart){const t=clamp((now-spinStart)/spinDuration,0,1),ease=1-Math.pow(1-t,3);rotation=spinFrom+360*ease;if(t>=1)spinStart=0}
   const aspect=canvas.width/Math.max(1,canvas.height),projection=perspective(Math.PI/4.2,aspect,.1,60),vp=multiply(projection,view),turn=rotationY(rotation*Math.PI/180);
   gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
   drawParts(stageParts,vp,translation(0,0,0));
   drawParts(carParts,vp,compose(turn,scale(modelScale,modelScale,modelScale)));
   frameCount++;state.frameCount=frameCount;state.rotation=rotation;state.carId=model.id;
   raf=window.requestAnimationFrame(render);
  }
  const observer=typeof IntersectionObserver!=="undefined"?new IntersectionObserver(entries=>{visible=entries.some(e=>e.isIntersecting&&e.intersectionRatio>0);if(visible&&!raf)raf=window.requestAnimationFrame(render);else if(!visible&&raf){cancelAnimationFrame(raf);raf=0}}):null;
  observer?.observe(canvas);if(!observer){visible=true;raf=window.requestAnimationFrame(render);}
  const onVisibility=()=>{if(document.hidden&&raf){cancelAnimationFrame(raf);raf=0}else if(!document.hidden&&visible&&!raf)raf=requestAnimationFrame(render)};
  document.addEventListener("visibilitychange",onVisibility);
  const resizeObserver=typeof ResizeObserver!=="undefined"?new ResizeObserver(resize):null;resizeObserver?.observe(canvas);
  const onContextLost=e=>{e.preventDefault();state.status="fallback-image";canvas.parentElement?.classList.remove("has-webgl");if(raf)cancelAnimationFrame(raf);raf=0};
  const onContextRestored=()=>{state.status="fallback-image";canvas.parentElement?.classList.remove("has-webgl");destroyed=true};
  canvas.addEventListener("webglcontextlost",onContextLost);canvas.addEventListener("webglcontextrestored",onContextRestored);
  return {
   state,
   setCar(next){model=next||model;state.carId=model.id;const hex=String(model.color||"#f15d4e").replace("#","");const rgb=[0,2,4].map(i=>parseInt(hex.slice(i,i+2),16)/255);if(rgb.every(Number.isFinite)&&carParts[0])carParts[0].color=rgb;},
   setRotation(deg){rotation=((Number(deg)||0)%360+360)%360;spinStart=0;state.rotation=rotation;},
   spin(){spinFrom=rotation;spinStart=performance.now();if(visible&&!raf)raf=requestAnimationFrame(render);},
   setAutoRotate(speed){autoRotate=Number(speed)||0;},
   setScale(value){modelScale=clamp(Number(value)||1,.6,2.4);state.scale=modelScale;},
   pause(){if(raf){cancelAnimationFrame(raf);raf=0;}},
   resume(){if(!destroyed&&visible&&!raf)raf=window.requestAnimationFrame(render);},
   resize,
   destroy(){destroyed=true;observer?.disconnect();resizeObserver?.disconnect();document.removeEventListener("visibilitychange",onVisibility);canvas.removeEventListener("webglcontextlost",onContextLost);canvas.removeEventListener("webglcontextrestored",onContextRestored);if(raf)cancelAnimationFrame(raf);for(const part of [...carParts,...stageParts])gl.deleteBuffer(part.mesh.buffer);gl.deleteProgram(programInfo);},
  };
 }catch(error){
  state.status="fallback-image";state.error=String(error?.message||error);
  return {state,setCar(next){model=next||model;state.carId=model.id},setRotation(deg){rotation=Number(deg)||0;state.rotation=rotation},spin(){},setAutoRotate(){},setScale(){},pause(){},resume(){},resize(){},destroy(){}};
 }
}
