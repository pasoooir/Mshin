import { CITY_ZONES, placeCityZone, developCityZones, isCityZoneCell } from "./city-zoning.js";
import { CITY_SERVICE_TYPES, computeCityServices } from "./city-services.js";
const SIZE=32,KEY="mshin-city-save-v1",COST={road:120,home:900,shop:1500,industrial:2600,administrative:3200,service:2800,park:650,...Object.fromEntries(Object.entries(CITY_SERVICE_TYPES).map(([type,definition])=>[type,definition.cost]))};
const rand=(seed)=>{let s=seed>>>0;return()=>{s=(s+0x6d2b79f5)>>>0;let v=s;v=Math.imul(v^(v>>>15),v|1);v^=v+Math.imul(v^(v>>>7),v|61);return(v^(v>>>14))>>>0}};
const f=r=>r()/4294967296,inside=(x,y)=>Number.isInteger(x)&&Number.isInteger(y)&&x>=0&&y>=0&&x<SIZE&&y<SIZE;
const roadNear=(g,x,y)=>[[1,0],[-1,0],[0,1],[0,-1]].some(([a,b])=>inside(x+a,y+b)&&g[y+b][x+a]==="road");
export function createInitialCity(seed=20261102){
 const r=rand(seed),grid=Array.from({length:SIZE},()=>Array(SIZE).fill("grass"));
 for(let y=0;y<SIZE;y++)for(let x=0;x<SIZE;x++)if([7,15,23].includes(x)||[7,15,23].includes(y))grid[y][x]="road";
 for(let y=0;y<5;y++)for(let x=26;x<31;x++)grid[y][x]="water";
 const buildings=[];let id=1;
 const add=(type,x,y,level=1)=>{if(grid[y][x]!=="grass")return;grid[y][x]="building";buildings.push({id:id++,type,x,y,level,age:0,residents:type==="home"?8+Math.floor(f(r)*13):0})};
 [[11,12],[12,12],[13,12],[17,12],[18,12],[19,12],[11,18],[12,18],[13,18],[17,18],[18,18],[19,18],[8,12],[8,13],[8,14],[22,12],[22,13],[22,14],[12,8],[13,8],[18,8],[19,8]].forEach(([x,y],i)=>add("home",x,y,i%5===0?2:1));
 [[12,10],[18,10],[10,18],[20,18],[8,10],[24,18],[18,22],[12,22]].forEach(([x,y],i)=>add("shop",x,y,i%3===0?2:1));
 [[14,12],[16,18],[22,16],[8,16]].forEach(([x,y])=>add("service",x,y));
 [[10,10],[20,10],[10,20],[20,20],[25,12],[5,19]].forEach(([x,y])=>add("park",x,y));
 const trees=[];for(let y=2;y<SIZE-2;y++)for(let x=2;x<SIZE-2;x++)if(grid[y][x]==="grass"&&f(r)>.91)trees.push({x,y,size:.75+f(r)*.55});
 const citizens=Array.from({length:28},(_,i)=>({id:i+1,x:10+f(r)*12,y:10+f(r)*12,phase:f(r)*6.28,pace:.12+f(r)*.12}));
 const traffic=Array.from({length:9},(_,i)=>({id:i+1,x:1+i*3.5,y:i%3===0?15:i%3===1?7:23,speed:.8+f(r)*.55,color:["#f5bd58","#e76c59","#75b9d6","#d6e1ec","#a7c77a"][i%5]}));
 const animals=Array.from({length:10},(_,i)=>({id:i+1,type:["cat","dog","bird"][i%3],x:9+f(r)*14,y:9+f(r)*14,phase:f(r)*6.28,pace:.08+f(r)*.1}));
 return {schemaVersion:1,cityId:"mshin-green-valley",name:"دره سبز",seed:seed>>>0,tick:0,minuteOfDay:495,treasury:124500,population:buildings.filter(b=>b.type==="home").reduce((n,b)=>n+b.residents,0),happiness:76,grid,buildings,zones:[],trees,citizens,traffic,animals,nextBuildingId:id,stats:{income:0,expenses:0,jobs:42,traffic:18}};
}
export function stepCity(city,seconds=1){
 if(!city||city.schemaVersion!==1||!Number.isFinite(seconds)||seconds<=0)throw new TypeError("A valid city and positive step are required");
 city.tick++;city.minuteOfDay=(city.minuteOfDay+10)%1440;
 if(city.tick%12===0)developCityZones(city);
 const infrastructure=computeCityServices(city);
 const homes=city.buildings.filter(b=>b.type==="home"),shops=city.buildings.filter(b=>b.type==="shop"),industrial=city.buildings.filter(b=>b.type==="industrial"),administrative=city.buildings.filter(b=>b.type==="administrative"),services=city.buildings.filter(b=>b.type==="service"),parks=city.buildings.filter(b=>b.type==="park");
 const income=Math.round(homes.length*13+shops.length*46+industrial.length*72+administrative.length*28+services.length*8),expenses=Math.round(services.length*31+parks.length*7+industrial.length*24+administrative.length*12+city.buildings.length*2);
 city.stats={income,expenses:expenses+infrastructure.upkeep,jobs:shops.length*9+industrial.length*18+administrative.length*12+services.length*6,traffic:Math.min(100,Math.round(city.traffic.length*3+shops.length*1.4+industrial.length*2)),utilityCoverage:infrastructure.utilityCoverage,publicServiceCoverage:infrastructure.publicServiceCoverage,overallCoverage:infrastructure.overallCoverage,serviceCoverage:infrastructure.coverage};
 city.treasury+=income-expenses-infrastructure.upkeep;if(city.tick%12===0&&homes.length&&city.population<homes.length*25)city.population++;
 const serviceScore=(infrastructure.utilityCoverage*.6+infrastructure.publicServiceCoverage*.4)/100;
 city.happiness=Math.max(25,Math.min(98,city.happiness+(serviceScore-.35)*.08+(parks.length>2?.05:0)));
 for(const p of city.citizens){p.phase+=p.pace*seconds;p.x+=Math.cos(p.phase)*.012;p.y+=Math.sin(p.phase)*.009;if(p.x<7||p.x>24)p.phase=Math.PI-p.phase;if(p.y<7||p.y>24)p.phase=-p.phase;p.x=Math.max(7,Math.min(24,p.x));p.y=Math.max(7,Math.min(24,p.y))}
 for(const v of city.traffic){v.x+=v.speed*seconds*.24;if(v.x>SIZE+1)v.x=-1}
 for(const a of city.animals||[]){a.phase+=a.pace*seconds;a.x+=Math.cos(a.phase)*.009;a.y+=Math.sin(a.phase)*.007;a.x=Math.max(8,Math.min(25,a.x));a.y=Math.max(8,Math.min(25,a.y))}
 return city;
}
export function placeCityItem(city,x,y,type){
 if(typeof type==="string"&&type.startsWith("zone-"))return placeCityZone(city,x,y,type.slice(5));
 if(!inside(x,y))return{ok:false,reason:"خارج از محدوده شهر"};
 if(!Object.hasOwn(COST,type))return{ok:false,reason:"ابزار ناشناخته است"};
 if(city.grid[y][x]!=="grass")return{ok:false,reason:"این قطعه زمین اشغال شده است"};
 if(city.treasury<COST[type])return{ok:false,reason:"بودجه کافی نیست"};
 if(type!=="road"&&!roadNear(city.grid,x,y))return{ok:false,reason:"ساختمان باید به خیابان دسترسی داشته باشد"};
 city.treasury-=COST[type];if(type==="road"){city.grid[y][x]="road";return{ok:true,item:"road",cost:COST.road}};
 const residents=type==="home"?12:0,b={id:city.nextBuildingId++,type,x,y,level:1,age:0,residents};
 city.grid[y][x]="building";city.buildings.push(b);city.population+=residents;return{ok:true,item:b,cost:COST[type]};
}
export function isValidCitySave(v){return!!(v&&v.schemaVersion===1&&typeof v.cityId==="string"&&typeof v.name==="string"&&Number.isSafeInteger(v.seed)&&Number.isSafeInteger(v.tick)&&v.tick>=0&&Number.isFinite(v.treasury)&&Number.isInteger(v.population)&&Array.isArray(v.grid)&&v.grid.length===SIZE&&v.grid.every(row=>Array.isArray(row)&&row.length===SIZE&&row.every(t=>["grass","road","building","water"].includes(t)||isCityZoneCell(t)))&&["buildings","trees","citizens","traffic"].every(k=>Array.isArray(v[k]))&&(v.zones===undefined||Array.isArray(v.zones)))}
export function projectCityTile(x,y,w=32,h=16){return{x:(x-y)*w/2,y:(x+y)*h/2}}
function load(){try{const v=JSON.parse(localStorage.getItem(KEY)||"null");if(!isValidCitySave(v))return createInitialCity();v.zones=Array.isArray(v.zones)?v.zones:[];return v}catch{return createInitialCity()}}
function persist(city){try{localStorage.setItem(KEY,JSON.stringify(city));return true}catch{return false}}
function mount(){
 const canvas=document.getElementById("cityViewport");let ctx=canvas?.getContext("2d");if(!canvas||!ctx)return;
 const $=id=>document.getElementById(id),city=load(),view={w:innerWidth,h:innerHeight,dpr:1},cam={x:0,y:0,zoom:1};
 let tool="select",speed=1,acc=0,last=0,selected=null,pointers=new Map(),gesture=null,toastFrames=0,raf=0,lastPersistTick=city.tick,loopRunning=false;
 const TW=32,TH=16,centerY=(SIZE-1)*TH/2;
 let staticLayer=null,cacheBuilds=0,frameCount=0,drawCount=0,needsDraw=true,lastDrawAt=0,lastHudUpdate=0;
 const tilePoint=(x,y)=>{const p=projectCityTile(x,y,TW,TH);return{x:p.x,y:p.y-centerY}};
 function resize(){view.w=innerWidth;view.h=innerHeight;view.dpr=Math.min(devicePixelRatio||1,1.6);canvas.width=Math.round(view.w*view.dpr);canvas.height=Math.round(view.h*view.dpr);canvas.style.width=view.w+"px";canvas.style.height=view.h+"px";if(!cam.initialized){cam.zoom=matchMedia("(max-width:760px)").matches?.72:Math.max(.42,Math.min(1.18,Math.min(view.w/1040,view.h/740)*1.08));cam.initialized=true}}
 function tileAt(px,py){const sx=(px-view.w/2-cam.x)/cam.zoom,sy=(py-view.h*.23-cam.y)/cam.zoom+centerY,a=sx/16,b=sy/8;return{x:Math.floor((a+b)/2+.5),y:Math.floor((b-a)/2+.5)}}
 function poly(points,fill,stroke){ctx.beginPath();points.forEach((p,i)=>i?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y));ctx.closePath();ctx.fillStyle=fill;ctx.fill();if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=.8;ctx.stroke()}}
 function ground(x,y,type){const p=tilePoint(x,y),park=city.buildings.some(b=>b.type==="park"&&b.x===x&&b.y===y),zoneType=type.startsWith("zone-")?type.slice(5):null,zoneColor=zoneType&&CITY_ZONES[zoneType]?.color,colors=type==="road"?["#414b56","#343e49"]:type==="water"?["#4b9fc0","#397fa4"]:zoneColor?[zoneColor,zoneColor]:park?["#5b9a60","#478452"]:["#7eaa68","#71995d"];
 poly([{x:p.x,y:p.y-8},{x:p.x+16,y:p.y},{x:p.x,y:p.y+8},{x:p.x-16,y:p.y}],colors[(x+y)%2],"#ffffff0c");
 if(zoneType){ctx.save();ctx.globalAlpha=.35;ctx.fillStyle="#102337";ctx.font="900 9px system-ui";ctx.textAlign="center";ctx.textBaseline="middle";ctx.fillText(CITY_ZONES[zoneType].label.slice(0,1),p.x,p.y);ctx.restore()}
 if(type==="road"){const h=city.grid[y][Math.max(0,x-1)]==="road"||city.grid[y][Math.min(SIZE-1,x+1)]==="road",v=city.grid[Math.max(0,y-1)][x]==="road"||city.grid[Math.min(SIZE-1,y+1)][x]==="road";ctx.save();ctx.strokeStyle="#f4d98c88";ctx.lineWidth=1;ctx.setLineDash([4,5]);ctx.beginPath();if(h&&v){ctx.moveTo(p.x-7,p.y-3.5);ctx.lineTo(p.x+7,p.y+3.5)}else if(h){ctx.moveTo(p.x-10,p.y);ctx.lineTo(p.x+10,p.y)}else if(v){ctx.moveTo(p.x,p.y-5);ctx.lineTo(p.x,p.y+5)}ctx.stroke();ctx.restore()}
 if(type==="water"){ctx.fillStyle="#c5f3f766";ctx.beginPath();ctx.ellipse(p.x-3,p.y-2,5,1.6,-.25,0,6.28);ctx.fill()}
 }
 function building(b){const p=tilePoint(b.x,b.y),t=b.type;if(t==="park"){ctx.fillStyle="#244b3155";ctx.beginPath();ctx.ellipse(p.x+1,p.y+2,14,5,0,0,6.28);ctx.fill();ctx.fillStyle="#3c7d48";ctx.beginPath();ctx.arc(p.x,p.y-8,7,0,6.28);ctx.fill();ctx.fillStyle="#82b76c";ctx.beginPath();ctx.arc(p.x-2,p.y-11,4,0,6.28);ctx.fill();ctx.fillStyle="#806a4b";ctx.fillRect(p.x-1,p.y-7,2,9);return}
 const service=CITY_SERVICE_TYPES[t],h=t==="home"?22+b.level*8:t==="shop"?27+b.level*5:t==="industrial"?42:t==="administrative"?40:service?38:35,w=t==="industrial"||t==="education"?22:18,d=10,top=p.y-h;
 ctx.fillStyle="#1a2c2b44";ctx.beginPath();ctx.ellipse(p.x+2,p.y+4,16,6,0,0,6.28);ctx.fill();
 poly([{x:p.x-w/2,y:top+d/2},{x:p.x,y:top+d},{x:p.x,y:p.y+d/2},{x:p.x-w/2,y:p.y}],t==="home"?"#d9a978":t==="shop"?"#5b9eaa":t==="industrial"?"#89949d":t==="administrative"?"#9b8ac2":service?service.color:"#b9c9d8","#253c4933");
 poly([{x:p.x,y:top+d},{x:p.x+w/2,y:top+d/2},{x:p.x+w/2,y:p.y},{x:p.x,y:p.y+d/2}],t==="home"?"#a97759":t==="shop"?"#3f7888":t==="industrial"?"#59636d":t==="administrative"?"#76669c":service?service.color:"#849bae","#253c4933");
 poly([{x:p.x-w/2,y:top+d/2},{x:p.x,y:top},{x:p.x+w/2,y:top+d/2},{x:p.x,y:top+d}],t==="home"?"#e8c68b":t==="shop"?"#7fc1c0":t==="industrial"?"#b9c3ca":t==="administrative"?"#c8b9e7":service?service.color:"#d8e2ed","#ffffff55");
 if(t==="service"){ctx.fillStyle="#d34d4d";ctx.fillRect(p.x-2,top+5,4,15);ctx.fillRect(p.x-7,top+10,14,4)}
 else{const rows=t==="home"?2:t==="industrial"?3:t==="administrative"?2:1,cols=t==="industrial"?3:2;for(let row=0;row<rows;row++)for(let col=0;col<cols;col++){ctx.fillStyle="#d8f5f2";ctx.fillRect(p.x-w/2+4+col*6,top+7+row*9,3.2,4.5)}}
 if(t==="shop"){ctx.fillStyle="#f4d27a";ctx.fillRect(p.x-7,top+d+2,14,4)}
 if(t==="industrial"){ctx.fillStyle="#4c5860";ctx.fillRect(p.x+5,top-13,5,16);ctx.fillStyle="#b6c1c8";ctx.beginPath();ctx.arc(p.x+7,top-16,4,0,6.28);ctx.fill()}
 if(t==="administrative"){ctx.fillStyle="#d7c7ee";ctx.fillRect(p.x-1,top-10,2,11);ctx.fillStyle="#d7a96d";ctx.fillRect(p.x+1,top-10,7,4)}
 if(service){ctx.fillStyle="#172b3d";ctx.font="1000 12px system-ui";ctx.textAlign="center";ctx.textBaseline="middle";const glyph={power:"⚡",water:"💧",sewage:"≈",waste:"♻",police:"★",fire:"✚",health:"+",education:"▤"}[t]||"●";ctx.fillText(glyph,p.x,top+18)}
 }
 function tree(t){const p=tilePoint(t.x,t.y),s=t.size;ctx.fillStyle="#233d2e55";ctx.beginPath();ctx.ellipse(p.x+2,p.y+3,7*s,3*s,0,0,6.28);ctx.fill();ctx.fillStyle="#74583b";ctx.fillRect(p.x-1.5,p.y-9*s,3,10*s);ctx.fillStyle="#36774b";ctx.beginPath();ctx.arc(p.x,p.y-12*s,7*s,0,6.28);ctx.fill();ctx.fillStyle="#65a85d";ctx.beginPath();ctx.arc(p.x-2*s,p.y-15*s,4*s,0,6.28);ctx.fill()}
 function people(){for(const p of city.citizens){const q=tilePoint(p.x,p.y);ctx.fillStyle="#25364b55";ctx.beginPath();ctx.ellipse(q.x,q.y+2,2.8,1.4,0,0,6.28);ctx.fill();ctx.fillStyle=p.id%3===0?"#e9c56b":p.id%3===1?"#e7edf2":"#d98b75";ctx.beginPath();ctx.arc(q.x,q.y-4,2.1,0,6.28);ctx.fill();ctx.strokeStyle="#f5dfbd";ctx.lineWidth=1.2;ctx.beginPath();ctx.moveTo(q.x,q.y-2);ctx.lineTo(q.x,q.y+1);ctx.stroke()}}
 function cars(){for(const v of city.traffic){const p=tilePoint(v.x,v.y);ctx.save();ctx.translate(p.x,p.y-1);ctx.fillStyle="#1a2635aa";ctx.beginPath();ctx.ellipse(0,3,7,2.8,0,0,6.28);ctx.fill();ctx.fillStyle=v.color;ctx.beginPath();ctx.roundRect(-6,-4,12,7,2);ctx.fill();ctx.fillStyle="#d8efff";ctx.beginPath();ctx.roundRect(-3.5,-3,5,3,1);ctx.fill();ctx.restore()}}
 function animals(){for(const a of city.animals||[]){const p=tilePoint(a.x,a.y);ctx.save();ctx.translate(p.x,p.y);if(a.type==="bird"){ctx.strokeStyle="#eaf4dc";ctx.lineWidth=1.6;ctx.beginPath();ctx.arc(-2,-2,3,Math.PI,Math.PI*1.85);ctx.arc(2,-2,3,Math.PI*1.15,Math.PI*2);ctx.stroke()}else{ctx.fillStyle=a.type==="cat"?"#d9b28a":"#b7c2ca";ctx.beginPath();ctx.ellipse(0,-2,4.2,2.8,0,0,6.28);ctx.fill();ctx.beginPath();ctx.arc(-2,-5,1.8,0,6.28);ctx.arc(2,-5,1.8,0,6.28);ctx.fill();ctx.strokeStyle="#f4e7d6";ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(3,0);ctx.lineTo(6,-2);ctx.stroke()}ctx.restore()}}
 function rebuildStaticLayer(){
  const layer=document.createElement("canvas");layer.width=SIZE*TW+128;layer.height=SIZE*TH+160;
  const layerContext=layer.getContext("2d");if(!layerContext)return false;
  const liveContext=ctx;ctx=layerContext;
  try{
   ctx.setTransform(1,0,0,1,0,0);ctx.translate(layer.width/2,centerY+80);
   for(let y=0;y<SIZE;y++)for(let x=0;x<SIZE;x++)ground(x,y,city.grid[y][x]);
   const ordered=[...city.trees.map(t=>({d:t.x+t.y,draw:()=>tree(t)})),...city.buildings.map(b=>({d:b.x+b.y,draw:()=>building(b)}))].sort((a,b)=>a.d-b.d);
   for(const item of ordered)item.draw();
  }finally{ctx=liveContext}
  staticLayer=layer;cacheBuilds++;needsDraw=true;return true;
 }
 function toolName(){return({select:"انتخاب",road:"خیابان",home:"مسکونی",shop:"تجاری",industrial:"صنعتی",administrative:"اداری",service:"خدمات",park:"پارک",power:"برق",water:"آب",sewage:"فاضلاب",waste:"پسماند",police:"پلیس",fire:"آتش‌نشانی",health:"درمان",education:"آموزش","zone-residential":"زون مسکونی","zone-commercial":"زون تجاری","zone-industrial":"زون صنعتی","zone-administrative":"زون اداری","zone-recreational":"زون تفریحی",bulldoze:"تخریب"})[tool]||tool}
 function draw(){
  drawCount++;ctx.setTransform(view.dpr,0,0,view.dpr,0,0);ctx.clearRect(0,0,view.w,view.h);
  const sky=ctx.createLinearGradient(0,0,0,view.h);sky.addColorStop(0,"#a7cbd1");sky.addColorStop(.52,"#c9d8c0");sky.addColorStop(1,"#718c75");ctx.fillStyle=sky;ctx.fillRect(0,0,view.w,view.h);
  ctx.save();ctx.translate(view.w/2+cam.x,view.h*.23+cam.y);ctx.scale(cam.zoom,cam.zoom);
  if(staticLayer)ctx.drawImage(staticLayer,-staticLayer.width/2,-centerY-80);
  cars();people();animals();if(selected){const p=tilePoint(selected.x,selected.y);ctx.strokeStyle="#fff1a6";ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(p.x,p.y-8);ctx.lineTo(p.x+16,p.y);ctx.lineTo(p.x,p.y+8);ctx.lineTo(p.x-16,p.y);ctx.closePath();ctx.stroke()}ctx.restore();
  const hudNow=performance.now();if(hudNow-lastHudUpdate>=250){lastHudUpdate=hudNow;
   $("cityPopulation").textContent=city.population.toLocaleString("fa-IR");$("cityTreasury").textContent=Math.round(city.treasury).toLocaleString("fa-IR")+" ₮";$("cityJobs").textContent=city.stats.jobs.toLocaleString("fa-IR");$("cityHappiness").textContent=Math.round(city.happiness).toLocaleString("fa-IR")+"٪";if($("cityInfrastructure"))$("cityInfrastructure").textContent=(city.stats.overallCoverage??0).toLocaleString("fa-IR")+"٪";
   $("cityClock").textContent=String(Math.floor(city.minuteOfDay/60)).padStart(2,"0")+":"+String(city.minuteOfDay%60).padStart(2,"0");$("cityTick").textContent="روز "+(1+Math.floor(city.tick/144)).toLocaleString("fa-IR");
   $("cityStatus").textContent=tool==="select"?"شهر زنده است؛ برای ساخت، ابزار پایین را انتخاب کن.":"ابزار فعال: "+toolName();$("cityBudgetHint").textContent="درآمد +"+city.stats.income.toLocaleString("fa-IR")+" · هزینه -"+city.stats.expenses.toLocaleString("fa-IR")+" · زیرساخت "+(city.stats.overallCoverage??0).toLocaleString("fa-IR")+"٪";$("citySaveState").textContent=toastFrames>0?"ذخیره شد ✓":"ذخیره محلی";if(toastFrames>0)toastFrames--;
  }needsDraw=false;
 }
 function setTool(next){tool=next;document.querySelectorAll("[data-city-tool]").forEach(b=>{const active=b.dataset.cityTool===tool;b.classList.toggle("active",active);b.setAttribute("aria-pressed",String(active))});canvas.style.cursor=tool==="select"?"grab":"crosshair";draw()}
 function apply(x,y){
  if(!inside(x,y))return;selected={x,y};
  if(tool==="select"){draw();return}
  if(tool==="bulldoze"){let changed=false;if(city.grid[y][x]==="building"){const b=city.buildings.find(v=>v.x===x&&v.y===y);if(b){city.buildings=city.buildings.filter(v=>v.id!==b.id);if(b.type==="home")city.population=Math.max(0,city.population-b.residents);city.grid[y][x]="grass";city.treasury+=Math.round((COST[b.type]||0)*.35);$("cityToast").textContent="ساختمان تخریب شد؛ ۳۵٪ هزینه بازیابی شد.";changed=true}}else if(city.grid[y][x]==="road"){const dependent=city.buildings.some(b=>Math.abs(b.x-x)+Math.abs(b.y-y)===1&&[[1,0],[-1,0],[0,1],[0,-1]].some(([dx,dy])=>inside(b.x+dx,b.y+dy)&&city.grid[b.y+dy][b.x+dx]==="road"&&!(b.x+dx===x&&b.y+dy===y)));if(dependent){$("cityToast").textContent="این خیابان تنها مسیر دسترسی یک ساختمان است."}else{city.grid[y][x]="grass";$("cityToast").textContent="قطعه خیابان حذف شد.";changed=true}}if(changed){persist(city);rebuildStaticLayer()}draw();return}
  const result=placeCityItem(city,x,y,tool);$("cityToast").textContent=result.ok?"ساخت انجام شد · هزینه "+result.cost.toLocaleString("fa-IR"):result.reason;if(result.ok){persist(city);rebuildStaticLayer()}draw()
 }
 document.querySelectorAll("[data-city-tool]").forEach(b=>b.addEventListener("click",()=>setTool(b.dataset.cityTool)));
 document.querySelectorAll("[data-city-speed]").forEach(b=>b.addEventListener("click",()=>{speed=Number(b.dataset.citySpeed);document.querySelectorAll("[data-city-speed]").forEach(v=>v.classList.toggle("active",v===b));$("citySpeedLabel").textContent=speed===0?"متوقف":speed+"×"}));
 $("cityZoomIn").addEventListener("click",()=>{cam.zoom=Math.min(1.5,cam.zoom*1.18);draw()});$("cityZoomOut").addEventListener("click",()=>{cam.zoom=Math.max(.42,cam.zoom/1.18);draw()});$("cityRecenter").addEventListener("click",()=>{cam.x=0;cam.y=0;cam.zoom=matchMedia("(max-width:760px)").matches?.72:Math.max(.42,Math.min(1.18,Math.min(view.w/1040,view.h/740)*1.08));draw()});
 $("citySave").addEventListener("click",()=>{const ok=persist(city);if(ok)lastPersistTick=city.tick;$("cityToast").textContent=ok?"شهر با موفقیت ذخیره شد.":"ذخیره‌سازی در این مرورگر در دسترس نیست.";toastFrames=120;draw()});
 $("cityReset").addEventListener("click",()=>{if(!confirm("شهر فعلی با یک شهر تازه جایگزین شود؟"))return;const fresh=createInitialCity((city.seed+7919)>>>0);Object.keys(city).forEach(k=>delete city[k]);Object.assign(city,fresh);persist(city);rebuildStaticLayer();draw()});
 $("cityHelp").addEventListener("click",()=>$("cityHelpPanel").classList.toggle("hidden"));$("cityCloseHelp").addEventListener("click",()=>$("cityHelpPanel").classList.add("hidden"));
 canvas.addEventListener("pointerdown",e=>{pointers.set(e.pointerId,{x:e.clientX,y:e.clientY,startX:e.clientX,startY:e.clientY});try{canvas.setPointerCapture?.(e.pointerId)}catch{}if(pointers.size===1){gesture={mode:"pan",id:e.pointerId,cx:cam.x,cy:cam.y,moved:false}}else if(pointers.size===2){const pts=[...pointers.values()],dx=pts[1].x-pts[0].x,dy=pts[1].y-pts[0].y,distance=Math.max(1,Math.hypot(dx,dy)),midX=(pts[0].x+pts[1].x)/2,midY=(pts[0].y+pts[1].y)/2;gesture={mode:"pinch",distance,zoom:cam.zoom,worldX:(midX-view.w/2-cam.x)/cam.zoom,worldY:(midY-view.h*.23-cam.y)/cam.zoom,moved:true}}});
 canvas.addEventListener("pointermove",e=>{const point=pointers.get(e.pointerId);if(!point)return;point.x=e.clientX;point.y=e.clientY;if(pointers.size>=2&&gesture?.mode==="pinch"){const pts=[...pointers.values()].slice(0,2),dx=pts[1].x-pts[0].x,dy=pts[1].y-pts[0].y,distance=Math.max(1,Math.hypot(dx,dy)),midX=(pts[0].x+pts[1].x)/2,midY=(pts[0].y+pts[1].y)/2;cam.zoom=Math.max(.42,Math.min(1.5,gesture.zoom*distance/gesture.distance));cam.x=midX-view.w/2-gesture.worldX*cam.zoom;cam.y=midY-view.h*.23-gesture.worldY*cam.zoom;draw();return}if(pointers.size===1&&gesture?.mode==="pan"){const dx=point.x-point.startX,dy=point.y-point.startY;if(Math.hypot(dx,dy)>5)gesture.moved=true;cam.x=gesture.cx+dx;cam.y=gesture.cy+dy;if(gesture.moved){canvas.style.cursor="grabbing";draw()}}});
 const finishPointer=e=>{if(!pointers.has(e.pointerId))return;const point=pointers.get(e.pointerId),wasPinching=gesture?.mode==="pinch";if(!wasPinching&&pointers.size===1&&gesture?.mode==="pan"&&!gesture.moved&&Math.hypot(e.clientX-point.startX,e.clientY-point.startY)<=5){const p=tileAt(e.clientX,e.clientY);apply(p.x,p.y)}pointers.delete(e.pointerId);if(pointers.size===1){const [id,remaining]=[...pointers.entries()][0];gesture={mode:"pan",id,cx:cam.x,cy:cam.y,startX:remaining.x,startY:remaining.y,moved:wasPinching||Boolean(gesture?.moved)}}else if(pointers.size===0)gesture=null;canvas.style.cursor=tool==="select"?"grab":"crosshair"};
 canvas.addEventListener("pointerup",finishPointer);canvas.addEventListener("pointercancel",finishPointer);canvas.addEventListener("wheel",e=>{e.preventDefault();cam.zoom=Math.max(.42,Math.min(1.5,cam.zoom*(e.deltaY<0?1.08:.92)));draw()},{passive:false});
 addEventListener("resize",()=>{resize();needsDraw=true;draw()});
 canvas.addEventListener("contextrestored",()=>{ctx=canvas.getContext("2d");if(ctx){rebuildStaticLayer();draw()} });addEventListener("keydown",e=>{if(e.key==="Escape")setTool("select");if(e.key==="+"||e.key==="=")cam.zoom=Math.min(1.5,cam.zoom*1.1);if(e.key==="-")cam.zoom=Math.max(.42,cam.zoom/1.1)});
 resize();rebuildStaticLayer();window.MshinCityPerformance={get frames(){return frameCount},get draws(){return drawCount},get staticLayerReady(){return!!staticLayer},get cacheBuilds(){return cacheBuilds},get loopActive(){return loopRunning}};window.MshinCityDebug={get city(){return city},get activeTool(){return tool},get view(){return{zoom:cam.zoom,x:cam.x,y:cam.y}},screenForTile(x,y){const p=tilePoint(x,y);return{x:view.w/2+cam.x+p.x*cam.zoom,y:view.h*.23+cam.y+p.y*cam.zoom}},actAt(x,y,nextTool){if(nextTool)tool=nextTool;apply(x,y);return{tool,cell:inside(x,y)?city.grid[y][x]:null,saved:JSON.parse(localStorage.getItem(KEY)||"null")}},save:()=>persist(city),step:()=>stepCity(city),place:(x,y,t)=>placeCityItem(city,x,y,t)};
 document.documentElement.dataset.cityReady="true";
 function frame(now){if(document.hidden){loopRunning=false;raf=0;return}frameCount++;const dt=Math.min(.25,Math.max(0,(now-last)/1000||0));last=now;if(speed>0){acc+=dt*speed;let count=0;while(acc>=1&&count<4){stepCity(city);acc-=1;count++}needsDraw=true}if(city.tick-lastPersistTick>=6){if(persist(city))lastPersistTick=city.tick}if(needsDraw&&now-lastDrawAt>=50){draw();lastDrawAt=now}raf=requestAnimationFrame(frame)}
 function startLoop(){if(loopRunning||document.hidden)return;loopRunning=true;last=performance.now();raf=requestAnimationFrame(frame)}
 document.addEventListener("visibilitychange",()=>{if(document.hidden){cancelAnimationFrame(raf);raf=0;loopRunning=false;persist(city)}else startLoop()});
 startLoop();addEventListener("pagehide",()=>{cancelAnimationFrame(raf);raf=0;loopRunning=false;persist(city)},{once:true});
}
if(typeof document!=="undefined"){if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",mount,{once:true});else mount()}
