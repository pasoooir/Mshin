import { TRACK, clamp, trackRadius, stepCar, resolveTrackCollision, lapProgress, crossedFinish } from "./physics.js";

const canvas = document.querySelector("#game");
const ctx = canvas.getContext("2d");
const $ = (id) => document.getElementById(id);
const car = { x: TRACK.rx, y: 0, heading: Math.PI / 2, speed: 0 };
const state = { running:false, paused:false, finished:false, elapsed:0, laps:0, lastProgress:0, steer:0, gas:false, brake:false, cameraX:0, cameraY:0 };
const obstacles = Array.from({length:10},(_,i)=>{const a=(i+0.42)*Math.PI*2/10;return{x:Math.cos(a)*TRACK.rx,y:Math.sin(a)*TRACK.ry,r:22,hit:false};});
let width=innerWidth,height=innerHeight,dpr=1,last=0;
function resize(){dpr=Math.min(devicePixelRatio||1,2);width=innerWidth;height=innerHeight;canvas.width=Math.round(width*dpr);canvas.height=Math.round(height*dpr);canvas.style.width=width+"px";canvas.style.height=height+"px";ctx.setTransform(dpr,0,0,dpr,0,0);}
addEventListener("resize",resize);resize();
function roundedRect(c,x,y,w,h,r){c.beginPath();c.roundRect(x,y,w,h,r);c.fill();}
function worldStart(){ctx.save();ctx.translate(width/2-state.cameraX,height/2-state.cameraY);}
function drawWorld(){
  ctx.fillStyle="#80c85d";ctx.fillRect(-width,-height,width*2,height*2);
  // Grass dots and playful flower patches
  for(let i=0;i<90;i++){const x=((i*137)%1200)-600,y=((i*83)%760)-380;ctx.fillStyle=i%3?"#a4df72":"#d7ee8d";ctx.beginPath();ctx.arc(x,y,2+(i%3),0,Math.PI*2);ctx.fill();}
  // Soft road shadow, outer shoulder, tarmac and inner grass island
  ctx.beginPath();ctx.ellipse(0,8,TRACK.rx+83,TRACK.ry+83,0,0,Math.PI*2);ctx.fillStyle="#477c3c";ctx.fill();
  ctx.beginPath();ctx.ellipse(0,0,TRACK.rx+76,TRACK.ry+76,0,0,Math.PI*2);ctx.fillStyle="#f7e7b8";ctx.fill();
  ctx.beginPath();ctx.ellipse(0,0,TRACK.rx+62,TRACK.ry+62,0,0,Math.PI*2);ctx.fillStyle="#66727a";ctx.fill();
  ctx.beginPath();ctx.ellipse(0,0,TRACK.rx-76,TRACK.ry-76,0,0,Math.PI*2);ctx.fillStyle="#80c85d";ctx.fill();
  // Dashed center line
  ctx.beginPath();ctx.ellipse(0,0,TRACK.rx,TRACK.ry,0,0,Math.PI*2);ctx.strokeStyle="#fff7d9";ctx.lineWidth=4;ctx.setLineDash([22,20]);ctx.stroke();ctx.setLineDash([]);
  // Edge rumble strips
  for(let i=0;i<48;i++){const a=i*Math.PI*2/48;for(const rr of [1.14,.86]){const x=Math.cos(a)*TRACK.rx*rr,y=Math.sin(a)*TRACK.ry*rr;ctx.save();ctx.translate(x,y);ctx.rotate(a);ctx.fillStyle=i%2?"#fff":"#f36c5e";roundedRect(ctx,-9,-5,18,10,3);ctx.restore();}}
  // Finish line at east side
  ctx.save();ctx.translate(TRACK.rx,0);ctx.rotate(Math.PI/2);for(let row=0;row<2;row++)for(let col=0;col<8;col++){ctx.fillStyle=(row+col)%2?"#fff":"#26313a";ctx.fillRect(-24+col*6,-13+row*13,6,13);}ctx.restore();
  // Trees and bushes outside the track
  for(let i=0;i<34;i++){const a=i*2.399,rad=1.42+(i%4)*.12,x=Math.cos(a)*TRACK.rx*rad,y=Math.sin(a)*TRACK.ry*rad;ctx.fillStyle="#326b42";ctx.beginPath();ctx.ellipse(x+4,y+7,17,13,0,0,Math.PI*2);ctx.fill();ctx.fillStyle=i%3?"#398d4e":"#54a95a";ctx.beginPath();ctx.arc(x,y,17,0,Math.PI*2);ctx.fill();ctx.fillStyle="#8bd66d";ctx.beginPath();ctx.arc(x-5,y-6,6,0,Math.PI*2);ctx.fill();}
  // Hay bales
  obstacles.forEach(o=>{ctx.fillStyle="#68472a";ctx.beginPath();ctx.ellipse(o.x+3,o.y+5,18,15,0,0,Math.PI*2);ctx.fill();ctx.fillStyle="#e8b84f";roundedRect(ctx,o.x-17,o.y-14,34,28,9);ctx.strokeStyle="#a66c2e";ctx.lineWidth=3;ctx.strokeRect(o.x-8,o.y-12,3,24);ctx.strokeRect(o.x+7,o.y-12,3,24);});
  ctx.restore();
}
function drawCar(){
  ctx.save();ctx.translate(width/2,height/2);ctx.rotate(car.heading);
  ctx.fillStyle="#25433266";ctx.beginPath();ctx.ellipse(3,7,17,27,0,0,Math.PI*2);ctx.fill();
  // wheels
  ctx.fillStyle="#26313a";[[-14,-15],[14,-15],[-14,15],[14,15]].forEach(([x,y])=>roundedRect(ctx,x-4,y-7,8,14,3));
  ctx.fillStyle="#f15d4e";ctx.beginPath();ctx.roundRect(-12,-24,24,48,8);ctx.fill();
  ctx.fillStyle="#bceeff";ctx.beginPath();ctx.roundRect(-9,-13,18,14,4);ctx.fill();
  ctx.fillStyle="#fff1bf";roundedRect(ctx,-8,-22,6,4,2);roundedRect(ctx,2,-22,6,4,2);
  ctx.fillStyle="#f7d35a";roundedRect(ctx,-8,15,5,4,2);roundedRect(ctx,3,15,5,4,2);
  ctx.restore();
}
function draw(){
  ctx.clearRect(0,0,width,height);
  state.cameraX=car.x;state.cameraY=car.y;
  worldStart();drawWorld();ctx.restore();drawCar();
  // small minimap
  const mw=112,mh=72,x=width-128,y=height>500?104:78;
  ctx.fillStyle="#173b2ccc";ctx.beginPath();ctx.roundRect(x,y,mw,mh,12);ctx.fill();
  ctx.strokeStyle="#e7f2c7";ctx.lineWidth=7;ctx.beginPath();ctx.ellipse(x+mw/2,y+mh/2,38,23,0,0,Math.PI*2);ctx.stroke();
  const px=x+mw/2+Math.cos(lapProgress(car.x,car.y)*Math.PI*2)*38,py=y+mh/2+Math.sin(lapProgress(car.x,car.y)*Math.PI*2)*23;ctx.fillStyle="#ff6554";ctx.beginPath();ctx.arc(px,py,4,0,Math.PI*2);ctx.fill();
}
function reset(){car.x=TRACK.rx;car.y=0;car.heading=Math.PI/2;car.speed=0;state.elapsed=0;state.laps=0;state.lastProgress=0;state.finished=false;obstacles.forEach(o=>o.hit=false);$("lap").textContent="0 / 3";$("time").textContent="00:00";$("result").classList.add("hidden");}
function update(dt){
  if(!state.running||state.paused||state.finished)return;
  state.elapsed+=dt;
  const r=trackRadius(car.x,car.y);stepCar(car,{throttle:state.gas,brake:state.brake,steer:state.steer,offRoad:r<TRACK.inner||r>TRACK.outer},dt);
  resolveTrackCollision(car);
  for(const o of obstacles){const d=Math.hypot(car.x-o.x,car.y-o.y);if(d<31&&!o.hit){car.speed*=.48;o.hit=true;setTimeout(()=>o.hit=false,650);}}
  const p=lapProgress(car.x,car.y);if(crossedFinish(state.lastProgress,p)){state.laps++;$("lap").textContent=state.laps+" / 3";if(state.laps>=3)finish();}
  state.lastProgress=p;
  $("time").textContent=fmt(state.elapsed);$("speed").textContent=Math.round(Math.abs(car.speed)*.42);
}
function fmt(s){const m=Math.floor(s/60),sec=Math.floor(s%60);return String(m).padStart(2,"0")+":"+String(sec).padStart(2,"0");}
function finish(){state.finished=true;state.running=false;$("resultTitle").textContent="🏆 Valley Champion!";$("resultText").textContent="You completed 3 laps in "+fmt(state.elapsed)+". Your first Green Valley race is complete!";$("result").classList.remove("hidden");}
function frame(ts){const dt=last?Math.min((ts-last)/1000,.05):0;last=ts;update(dt);draw();requestAnimationFrame(frame);}requestAnimationFrame(frame);
$("start").addEventListener("click",()=>{$("intro").classList.add("hidden");reset();state.running=true;});
$("again").addEventListener("click",()=>{reset();$("result").classList.add("hidden");state.running=true;});
$("pause").addEventListener("click",()=>{if(!state.running)return;state.paused=!state.paused;$("pause").textContent=state.paused?"▶":"Ⅱ";});
function bindHold(id,key){const el=$(id);const on=e=>{e.preventDefault();state[key]=true;el.setPointerCapture?.(e.pointerId);};const off=e=>{e.preventDefault();state[key]=false;};el.addEventListener("pointerdown",on);["pointerup","pointercancel","lostpointercapture"].forEach(t=>el.addEventListener(t,off));}
bindHold("gas","gas");bindHold("brake","brake");
const stick=$("stick"),knob=$("knob");let stickId=null;
function moveStick(e){const r=stick.getBoundingClientRect(),cx=r.left+r.width/2,cy=r.top+r.height/2,dx=e.clientX-cx,dy=e.clientY-cy,max=39,len=Math.hypot(dx,dy)||1,n=Math.min(1,max/len);state.steer=clamp(dx/max,-1,1);knob.style.transform=`translate(${dx*n}px,${dy*n}px)`;}
stick.addEventListener("pointerdown",e=>{e.preventDefault();stickId=e.pointerId;stick.setPointerCapture(e.pointerId);moveStick(e);});
stick.addEventListener("pointermove",e=>{if(e.pointerId===stickId)moveStick(e);});
function releaseStick(e){if(e.pointerId!==stickId)return;stickId=null;state.steer=0;knob.style.transform="translate(0,0)";}
["pointerup","pointercancel","lostpointercapture"].forEach(t=>stick.addEventListener(t,releaseStick));
addEventListener("keydown",e=>{if(["ArrowLeft","a","A"].includes(e.key))state.steer=-1;if(["ArrowRight","d","D"].includes(e.key))state.steer=1;if(["ArrowUp","w","W"].includes(e.key))state.gas=true;if(["ArrowDown","s","S"," "].includes(e.key))state.brake=true;if(e.key==="Escape")$("pause").click();});
addEventListener("keyup",e=>{if(["ArrowLeft","a","A","ArrowRight","d","D"].includes(e.key))state.steer=0;if(["ArrowUp","w","W"].includes(e.key))state.gas=false;if(["ArrowDown","s","S"," "].includes(e.key))state.brake=false;});
