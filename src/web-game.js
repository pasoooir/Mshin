import { createGameAudio } from "./audio.js";
const canvas=document.querySelector("#game"),ctx=canvas.getContext("2d"),$=id=>document.getElementById(id);
const worlds=[
["Green Valley","#83c95f","#65727b","#f5e5b8","#f6d45c","#e8b84f",1,"🌳"],
["Desert Storm","#e9b96c","#a77a50","#f8d99b","#d66e36","#55a34c",.88,"🌵"],
["Frozen World","#bceaf4","#7897b5","#eafbff","#62d6f0","#dffbff",.68,"❄️"],
["Tropical Island","#55cdb2","#a58b68","#f9e2a0","#f477a7","#48a98e",.92,"🌴"],
["Neon City","#20234f","#303653","#f04bc7","#4ce bfa".replace(" ",""),"#ff4bc8",1.04,"🏙️"],
["Industrial Zone","#707d87","#3d4852","#d5a45f","#ffb44d","#c8a06b",.96,"🏭"],
["Mountain Rush","#78ae91","#65717a","#d8e2cb","#e4a45d","#8b8170",.9,"🏔️"],
["Ancient World","#d6b77d","#9a805f","#f2ddaa","#c56d43","#bd9b6a",.94,"🏛️"],
["Space Racing","#171b3d","#44466b","#8b6bff","#5be8e7","#a48bff",1.02,"🪐"],
["Ultimate Championship","#d86c68","#3d4b67","#f5d46f","#f8f3e8","#f1f1f1",1,"🏁"]
];
const names=[["Meadow Run","Forest Loop","Village Sprint","Canopy Bridge","Valley Cup"],["Dune Dash","Sandy Switchbacks","Canyon Rush","Old Mine Run","Sandstorm Rally"],["Snowdrop Sprint","Pinecone Pass","Crystal Lake","Frostbite Climb","Aurora Circuit"],["Palm Coast","Lagoon Twist","Coral Run","Volcano Shore","Island Grand Prix"],["Midnight Mile","Cyber Boulevard","Laser Loop","Skyline Drift","Neon Finale"],["Assembly Alley","Cargo Circuit","Smokestack Run","Factory Shift","Steelworks Cup"],["Eagle Ridge","Alpine Switchback","Cloud Pass","Rockfall Run","Summit Challenge"],["Temple Trail","Obelisk Run","Lost Colosseum","Golden Labyrinth","Pharaoh's Cup"],["Moonbase Sprint","Asteroid Belt","Orbital Loop","Nebula Run","Cosmic Grand Prix"],["Rookie Arena","Velocity Stadium","Pro Circuit","Champion's Route","Ultimate Crown"]];
const styles=["oval","sweeper","chicane","hairpin","technical"],stages=worlds.flatMap((w,wi)=>names[wi].map((name,si)=>({id:wi*5+si+1,world:wi,slot:si,name,style:styles[si],seed:(wi+1)*97+(si+1)*31,grip:w[6],hazards:5+si*2+wi})));
let selectedWorld=0,selectedStage=1,stage=stages[0],progress=loadProgress(),state="home",width=innerWidth,height=innerHeight,dpr=1,zoom=1,last=0;
const input={steer:0,gas:false,brake:false},car={t:0,lateral:0,speed:0},race={elapsed:0,laps:0,lastT:0,finished:false};
let obstacles=[];
const audio=createGameAudio();
function loadProgress(){try{const p=JSON.parse(localStorage.getItem("mshin-progress-v1")||"{}");return {completed:Array.isArray(p.completed)?p.completed.filter(n=>Number.isInteger(n)&&n>=1&&n<=50):[],best:p.best&&typeof p.best==="object"?p.best:{}}}catch{return {completed:[],best:{}}}}
function saveProgress(){try{localStorage.setItem("mshin-progress-v1",JSON.stringify(progress))}catch{}}
function resize(){dpr=Math.min(devicePixelRatio||1,2);width=innerWidth;height=innerHeight;canvas.width=Math.round(width*dpr);canvas.height=Math.round(height*dpr);zoom=Math.min(width/1000,height/650,1);ctx.setTransform(dpr,0,0,dpr,0,0)}
addEventListener("resize",resize);resize();
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v)),fmt=s=>{let m=Math.floor(s/60),v=Math.floor(s%60);return String(m).padStart(2,"0")+":"+String(v).padStart(2,"0")};
function center(t){const s=stage,phase=s.seed*.017,amp=[.025,.07,.12,.095,.14][s.slot],harm=[2,2,6,3,7][s.slot],wave=1+amp*Math.sin(harm*t+phase)+.045*Math.cos(3*t+s.seed*.031)+.022*Math.sin(5*t+s.seed*.013);return {x:Math.cos(t)*440*wave,y:Math.sin(t)*270*(wave-.025*Math.sin(2*t+phase))}}
function frameAt(t){const p=center(t),a=center(t-.002),b=center(t+.002),dx=b.x-a.x,dy=b.y-a.y,len=Math.hypot(dx,dy)||1;return {p,nx:-dy/len,ny:dx/len,angle:Math.atan2(dy,dx)}}
function carPoint(){const f=frameAt(car.t);return {x:f.p.x+f.nx*car.lateral,y:f.p.y+f.ny*car.lateral,...f}}
function makeObstacles(){obstacles=[];for(let i=0;i<stage.hazards;i++){const t=(i+.48)*Math.PI*2/stage.hazards+(stage.seed%11)*.025;obstacles.push({t,lateral:(i%2?1:-1)*(25+(i%3)*17),hit:false})}}
function drawTrack(){const w=worlds[stage.world];ctx.fillStyle=w[1];ctx.fillRect(-1300,-1000,2600,2000);
 for(let i=0;i<110;i++){const x=((i*173)%2200)-1100,y=((i*97)%1600)-800;ctx.fillStyle=i%4===0?w[3]:w[5];ctx.globalAlpha=.18;ctx.beginPath();ctx.arc(x,y,2+i%4,0,Math.PI*2);ctx.fill()}ctx.globalAlpha=1;
 const path=[];for(let i=0;i<=240;i++)path.push(center(i/240*Math.PI*2));
 function stroke(col,wide,dash=[]){ctx.beginPath();path.forEach((p,i)=>i?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y));ctx.closePath();ctx.strokeStyle=col;ctx.lineWidth=wide;ctx.setLineDash(dash);ctx.lineJoin="round";ctx.stroke();ctx.setLineDash([])}
 stroke("#0005",174);stroke(w[2],160);stroke(w[4],128);stroke(w[2],108);stroke("#ffffffbb",3,[18,18]);
 for(let i=0;i<64;i++){const f=frameAt(i/64*Math.PI*2);ctx.save();ctx.translate(f.p.x,f.p.y);ctx.rotate(f.angle);ctx.fillStyle=i%2?"#fff":"#f05c58";ctx.fillRect(-7,-85,14,13);ctx.fillRect(-7,72,14,13);ctx.restore()}
 const start=frameAt(0);ctx.save();ctx.translate(start.p.x,start.p.y);ctx.rotate(start.angle);for(let r=0;r<2;r++)for(let c=0;c<10;c++){ctx.fillStyle=(r+c)%2?"#fff":"#182338";ctx.fillRect(-55+c*11,-8+r*16,11,16)}ctx.restore();
 // Distinct themed scenery and trackside props.
 for(let i=0;i<42;i++){const t=i/42*Math.PI*2,f=frameAt(t),side=i%2?1:-1,x=f.p.x+f.nx*side*(145+(i%4)*22),y=f.p.y+f.ny*side*(145+(i%4)*22);ctx.save();ctx.translate(x,y);ctx.rotate(t);ctx.fillStyle=w[5];ctx.globalAlpha=.9;
  if(stage.world===0){ctx.beginPath();ctx.arc(-7,-5,15,0,Math.PI*2);ctx.arc(9,-2,13,0,Math.PI*2);ctx.fill();ctx.fillStyle="#9bdc74";ctx.beginPath();ctx.arc(-10,-10,5,0,Math.PI*2);ctx.fill()}
  else if(stage.world===1){ctx.fillRect(-5,-23,10,42);ctx.fillRect(-17,-8,12,7);ctx.fillRect(5,-15,12,7)}
  else if(stage.world===2){ctx.beginPath();ctx.moveTo(0,-27);ctx.lineTo(16,-5);ctx.lineTo(8,22);ctx.lineTo(-8,22);ctx.lineTo(-16,-5);ctx.closePath();ctx.fill();ctx.strokeStyle="#fff";ctx.stroke()}
  else if(stage.world===3){ctx.fillRect(-3,-4,6,25);for(let k=0;k<5;k++){ctx.save();ctx.rotate(k*Math.PI*2/5);ctx.fillRect(0,-24,4,20);ctx.restore()}}
  else if(stage.world===4||stage.world===8){ctx.shadowColor=w[4];ctx.shadowBlur=16;ctx.fillRect(-13,-28,26,56);ctx.fillStyle=w[4];ctx.fillRect(-7,-20,4,4);ctx.fillRect(3,-8,4,4);ctx.fillRect(-7,6,4,4)}
  else if(stage.world===5){ctx.fillRect(-18,-7,36,14);ctx.fillRect(-13,-18,7,36);ctx.fillRect(7,-18,7,36)}
  else if(stage.world===6){ctx.beginPath();ctx.moveTo(0,-28);ctx.lineTo(24,20);ctx.lineTo(-24,20);ctx.closePath();ctx.fill();ctx.fillStyle="#e9f0e5";ctx.beginPath();ctx.moveTo(0,-28);ctx.lineTo(8,-12);ctx.lineTo(-5,-12);ctx.closePath();ctx.fill()}
  else if(stage.world===7){ctx.fillRect(-14,-23,28,46);ctx.fillStyle=w[4];ctx.fillRect(-18,-25,36,6);ctx.fillRect(-18,19,36,6)}
  else{ctx.beginPath();ctx.moveTo(-18,-18);ctx.lineTo(18,-18);ctx.lineTo(10,18);ctx.lineTo(-10,18);ctx.closePath();ctx.fill()}ctx.restore()}
 obstacles.forEach((o,i)=>{const f=frameAt(o.t),x=f.p.x+f.nx*o.lateral,y=f.p.y+f.ny*o.lateral;ctx.save();ctx.translate(x,y);ctx.rotate(o.t);ctx.fillStyle="#0005";ctx.beginPath();ctx.ellipse(4,8,18,12,0,0,Math.PI*2);ctx.fill();ctx.fillStyle=w[5];ctx.strokeStyle=w[4];ctx.lineWidth=3;ctx.beginPath();
 if(stage.world===0){ctx.roundRect(-18,-13,36,26,9)}
 else if(stage.world===1){ctx.roundRect(-10,-19,20,38,8);ctx.fillRect(-18,-5,8,6);ctx.fillRect(10,-13,8,6)}
 else if(stage.world===2){ctx.moveTo(0,-22);ctx.lineTo(15,-4);ctx.lineTo(9,19);ctx.lineTo(-9,19);ctx.lineTo(-15,-4);ctx.closePath()}
 else if(stage.world===3){ctx.roundRect(-18,-8,36,16,6);ctx.moveTo(-12,-8);ctx.lineTo(-5,-18);ctx.moveTo(12,-8);ctx.lineTo(5,-18)}
 else if(stage.world===4||stage.world===8){ctx.rect(-20,-8,40,16);ctx.moveTo(-14,-16);ctx.lineTo(-14,16);ctx.moveTo(14,-16);ctx.lineTo(14,16)}
 else if(stage.world===5){ctx.rect(-16,-16,32,32);ctx.moveTo(-16,-5);ctx.lineTo(16,-5);ctx.moveTo(0,-16);ctx.lineTo(0,16)}
 else if(stage.world===6){ctx.moveTo(-20,14);ctx.lineTo(-8,-15);ctx.lineTo(4,-3);ctx.lineTo(15,-19);ctx.lineTo(22,14);ctx.closePath()}
 else if(stage.world===7){ctx.rect(-13,-18,26,36);ctx.rect(-18,-22,36,6)}
 else{ctx.roundRect(-20,-10,40,20,5);ctx.moveTo(-13,-17);ctx.lineTo(-13,17);ctx.moveTo(13,-17);ctx.lineTo(13,17)}
 ctx.fill();ctx.stroke();ctx.restore()})
}
function drawCar(){const c=carPoint();ctx.save();ctx.translate(c.x,c.y);ctx.rotate(c.angle);ctx.fillStyle="#0007";ctx.beginPath();ctx.ellipse(3,7,19,29,0,0,Math.PI*2);ctx.fill();ctx.fillStyle="#222d3a";[[-14,-15],[14,-15],[-14,15],[14,15]].forEach(([x,y])=>{ctx.beginPath();ctx.roundRect(x-4,y-7,8,14,3);ctx.fill()});ctx.fillStyle="#f15d4e";ctx.beginPath();ctx.roundRect(-12,-25,24,50,8);ctx.fill();ctx.fillStyle="#bceeff";ctx.beginPath();ctx.roundRect(-9,-13,18,15,4);ctx.fill();ctx.fillStyle="#fff0b5";ctx.fillRect(-8,-22,5,4);ctx.fillRect(3,-22,5,4);ctx.restore()}
function draw(){ctx.clearRect(0,0,width,height);const c=carPoint();ctx.save();ctx.translate(width/2,height/2);ctx.scale(zoom,zoom);ctx.translate(-c.x,-c.y);drawTrack();drawCar();ctx.restore()}
function renderWorlds(){const root=$("worlds");root.innerHTML="";worlds.forEach((w,i)=>{const b=document.createElement("button");b.className="world"+(i===selectedWorld?" active":"");b.innerHTML=w[7]+" "+w[0]+"<small>WORLD "+String(i+1).padStart(2,"0")+"</small>";b.onclick=()=>{selectedWorld=i;selectedStage=i*5+1;renderWorlds();renderStages()};root.append(b)})}
function renderStages(){const w=worlds[selectedWorld];$("worldTitle").textContent=w[7]+" "+w[0];const root=$("stages");root.innerHTML="";stages.filter(s=>s.world===selectedWorld).forEach(s=>{const b=document.createElement("button");b.className="stage"+(s.id===selectedStage?" active":"");const best=progress.best[s.id];b.innerHTML="STAGE "+String(s.slot+1).padStart(2,"0")+" · "+s.name+"<small>"+s.style.toUpperCase()+" · "+(best? "BEST "+fmt(best):"NOT RACED")+"</small>";b.onclick=()=>{selectedStage=s.id;renderStages()};root.append(b)})}
function show(id){["home","select","pausePanel","finish"].forEach(k=>$(k).classList.toggle("hidden",k!==id));$("hud").classList.toggle("hidden",id!=="race"&&id!=="pausePanel"&&id!=="finish")}
function begin(){stage=stages[selectedStage-1];car.t=0;car.lateral=0;car.speed=0;race.elapsed=0;race.laps=0;race.lastT=0;race.finished=false;input.steer=0;input.gas=false;input.brake=false;makeObstacles();$("stageName").textContent="WORLD "+String(stage.world+1).padStart(2,"0")+" · STAGE "+String(stage.slot+1).padStart(2,"0");$("lap").textContent="0 / 3";$("time").textContent="00:00";$("speed").textContent="0";state="race";audio.unlock();audio.update(0,true);show("race")}
function complete(){race.finished=true;state="finish";audio.update(0,false);audio.finish();progress.completed=[...new Set([...progress.completed,stage.id])];const old=Number(progress.best[stage.id])||Infinity;if(race.elapsed<old)progress.best[stage.id]=race.elapsed;saveProgress();$("finishText").textContent=stage.name+" completed in "+fmt(race.elapsed)+". "+(race.elapsed<=old?"New personal best!":"Best: "+fmt(progress.best[stage.id]) );show("finish")}
function update(dt){if(state!=="race")return;const grip=stage.grip;car.speed= input.brake?Math.max(0,car.speed-470*dt):input.gas?Math.min(330,car.speed+245*dt):Math.max(0,car.speed-82*dt);car.t+=car.speed/430*dt;car.lateral=clamp(car.lateral+input.steer*(80+car.speed*.45)*dt/stage.grip,-105,105);const roadEdge=Math.abs(car.lateral);if(roadEdge>43)car.speed=Math.max(0,car.speed-(roadEdge-43)*1.2*dt);car.t=(car.t+Math.PI*2)%(Math.PI*2);if(car.t<race.lastT-.5){race.laps++;$("lap").textContent=Math.min(race.laps,3)+" / 3";if(race.laps>=3){race.elapsed+=dt;complete();return}}race.lastT=car.t;race.elapsed+=dt;
 const c=carPoint();obstacles.forEach(o=>{const f=frameAt(o.t),x=f.p.x+f.nx*o.lateral,y=f.p.y+f.ny*o.lateral;if(Math.hypot(c.x-x,c.y-y)<26&&!o.hit){car.speed*=.42;audio.collision();o.hit=true;setTimeout(()=>o.hit=false,800)}});$("time").textContent=fmt(race.elapsed);$("speed").textContent=Math.round(car.speed*.42)}
function loop(ts){const dt=last?Math.min((ts-last)/1000,.05):0;last=ts;update(dt);audio.update(car.speed,state==="race");draw();requestAnimationFrame(loop)}requestAnimationFrame(loop);
$("play").onclick=()=>{selectedWorld=0;selectedStage=1;renderWorlds();renderStages();state="select";show("select")};$("backHome").onclick=()=>{state="home";show("home")};$("startRace").onclick=begin;
$("soundToggle").onclick=()=>{const on=audio.toggle();$("soundToggle").textContent=on?"🔊":"🔇";$("soundToggle").setAttribute("aria-pressed",String(on));if(on)audio.unlock()};
$("pause").onclick=()=>{if(state==="race"){state="paused";audio.update(0,false);show("pausePanel")}};$("resume").onclick=()=>{state="race";audio.unlock();show("race")};$("quitRace").onclick=()=>{state="select";renderStages();show("select")};$("finishSelect").onclick=()=>{state="select";renderStages();show("select")};$("nextStage").onclick=()=>{if(stage.id<50){selectedStage=stage.id+1;selectedWorld=Math.floor((selectedStage-1)/5);renderWorlds();renderStages();begin()}else{state="select";renderWorlds();renderStages();show("select")}};
function hold(id,key){const el=$(id),on=e=>{e.preventDefault();input[key]=true;el.setPointerCapture?.(e.pointerId)},off=e=>{e.preventDefault();input[key]=false};el.addEventListener("pointerdown",on);["pointerup","pointercancel","lostpointercapture"].forEach(t=>el.addEventListener(t,off))}
hold("gas","gas");hold("brake","brake");const stick=$("stick"),knob=$("knob");let pointer=null;function steer(e){const r=stick.getBoundingClientRect(),dx=e.clientX-r.left-r.width/2,dy=e.clientY-r.top-r.height/2,len=Math.hypot(dx,dy)||1,n=Math.min(1,42/len);input.steer=clamp(dx/42,-1,1);knob.style.transform="translate("+dx*n+"px,"+dy*n+"px)"}stick.addEventListener("pointerdown",e=>{pointer=e.pointerId;stick.setPointerCapture(e.pointerId);steer(e)});stick.addEventListener("pointermove",e=>{if(e.pointerId===pointer)steer(e)});function release(e){if(e.pointerId!==pointer)return;pointer=null;input.steer=0;knob.style.transform="translate(0,0)"}["pointerup","pointercancel","lostpointercapture"].forEach(t=>stick.addEventListener(t,release));
addEventListener("keydown",e=>{if(["ArrowLeft","a","A"].includes(e.key))input.steer=-1;if(["ArrowRight","d","D"].includes(e.key))input.steer=1;if(["ArrowUp","w","W"].includes(e.key))input.gas=true;if(["ArrowDown","s","S"," "].includes(e.key))input.brake=true;if(e.key==="Escape")$("pause").click()});addEventListener("keyup",e=>{if(["ArrowLeft","a","A","ArrowRight","d","D"].includes(e.key))input.steer=0;if(["ArrowUp","w","W"].includes(e.key))input.gas=false;if(["ArrowDown","s","S"," "].includes(e.key))input.brake=false});
