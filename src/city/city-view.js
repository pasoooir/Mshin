import { CITY_ZONES, placeCityZone, developCityZones } from "./city-zoning.js";
import { createCityCameraController } from "./city-camera-controller.js";
import { CITY_SERVICE_TYPES, computeCityServices, computeCityResidentServiceSatisfaction } from "./city-services.js";
import { stepCityTraffic } from "./city-traffic.js";
import { syncCityCitizens, stepCityCitizens } from "./city-population.js";
import { computeCityEmployment } from "./city-employment.js";
import { computeCityCommuting } from "./city-commuting.js";
import { CITY_DEFAULT_TAX_RATES, setCityTaxRate, computeCityEconomy, cityTaxPressure } from "./city-economy.js";
import { isValidCitySave, normalizeCitySaveData, migrateCitySave, createCitySaveBackup } from "./city-save.js";
export { isValidCitySave, migrateCitySave, createCitySaveBackup };
export function normalizeCitySave(value){return normalizeCitySaveData(value)||createInitialCity();}
const SIZE=32,KEY="mshin-city-save-v2",LEGACY_KEY="mshin-city-save-v1",BACKUP_KEY=KEY+".backup",RECOVERY_KEY=KEY+".recovery",LEGACY_RECOVERY_KEY=LEGACY_KEY+".recovery",BACKUP_RECOVERY_KEY=BACKUP_KEY+".recovery",COST={road:120,home:900,shop:1500,industrial:2600,administrative:3200,service:2800,park:650,...Object.fromEntries(Object.entries(CITY_SERVICE_TYPES).map(([type,definition])=>[type,definition.cost]))};
const rand=(seed)=>{let s=seed>>>0;return()=>{s=(s+0x6d2b79f5)>>>0;let v=s;v=Math.imul(v^(v>>>15),v|1);v^=v+Math.imul(v^(v>>>7),v|61);return(v^(v>>>14))>>>0}};
const f=r=>r()/4294967296,inside=(x,y)=>Number.isInteger(x)&&Number.isInteger(y)&&x>=0&&y>=0&&x<SIZE&&y<SIZE;
const roadNear=(g,x,y)=>[[1,0],[-1,0],[0,1],[0,-1]].some(([a,b])=>inside(x+a,y+b)&&g[y+b][x+a]==="road");
export function createInitialCity(seed=20261102){
 const grid=Array.from({length:SIZE},()=>Array(SIZE).fill("grass"));
 for(let y=0;y<SIZE;y++)for(let x=0;x<SIZE;x++)if([7,8,15,16,23,24].includes(x)||[7,8,15,16,23,24].includes(y))grid[y][x]="road";
 return {schemaVersion:2,cityId:"mshin-green-valley",name:"دره سبز",seed:seed>>>0,tick:0,minuteOfDay:495,treasury:124500,population:0,happiness:100,taxRates:{...CITY_DEFAULT_TAX_RATES},grid,buildings:[],zones:[],trees:[],citizens:[],traffic:[],nextTrafficId:1,nextCitizenId:1,animals:[],nextBuildingId:1,stats:{income:0,expenses:0,net:0,taxRevenue:0,maintenance:0,serviceUpkeep:0,jobs:0,traffic:0}};
}
export function stepCity(city,seconds=1){
 if(!city||city.schemaVersion!==2||!Number.isFinite(seconds)||seconds<=0)throw new TypeError("A valid city and positive step are required");
 city.tick++;city.minuteOfDay=(city.minuteOfDay+10)%1440;
 if(city.tick%12===0)developCityZones(city);
 const infrastructure=computeCityServices(city);
 const homes=city.buildings.filter(b=>b.type==="home"),shops=city.buildings.filter(b=>b.type==="shop"),industrial=city.buildings.filter(b=>b.type==="industrial"),administrative=city.buildings.filter(b=>b.type==="administrative"),services=city.buildings.filter(b=>b.type==="service"),parks=city.buildings.filter(b=>b.type==="park");
 const employment=computeCityEmployment(city);
 const commuting=(city.tick%6===1||!Number.isFinite(city.stats?.commuteCoverage)||!Array.isArray(city._commuteAssignments))
  ?computeCityCommuting(city,employment)
  :{assignedWorkers:city.stats.commutingWorkers??0,commuteCoverage:city.stats.commuteCoverage??0,averageCommuteDistance:city.stats.averageCommuteDistance??0,averageCongestionDelay:city.stats.averageCongestionDelay??0,unreachableWorkers:city.stats.unreachableWorkers??0,assignments:city._commuteAssignments};
 const economy=computeCityEconomy(city,infrastructure,commuting);
 if(commuting.assignments)Object.defineProperty(city,"_commuteAssignments",{value:commuting.assignments,writable:true,configurable:true,enumerable:false});
 const residentServiceSatisfaction=computeCityResidentServiceSatisfaction(city);
 const occupiedResidents=homes.reduce((sum,home)=>sum+Math.max(0,Number(home.residents)||0),0);
 city.stats={income:economy.income,expenses:economy.expenses,net:economy.net,taxRevenue:economy.taxRevenue,maintenance:economy.maintenance,serviceUpkeep:economy.serviceUpkeep,jobs:employment.jobs,laborForce:employment.laborForce,employed:employment.employed,unemployed:employment.unemployed,vacancies:employment.vacancies,unemploymentRate:employment.unemploymentRate,employmentDemand:employment.demandIndex,commutingWorkers:commuting.assignedWorkers,commuteCoverage:commuting.commuteCoverage,averageCommuteDistance:commuting.averageCommuteDistance,averageCongestionDelay:commuting.averageCongestionDelay??0,commuteProductivityPercent:economy.commuteProductivityPercent,commuteEconomicLoss:economy.commuteEconomicLoss,unreachableWorkers:commuting.unreachableWorkers,traffic:Math.min(100,Math.round(city.traffic.length*3+shops.length*1.4+industrial.length*2)),utilityCoverage:infrastructure.utilityCoverage,publicServiceCoverage:infrastructure.publicServiceCoverage,overallCoverage:infrastructure.overallCoverage,serviceCoverage:infrastructure.coverage,serviceDemandCoverage:infrastructure.demandCoverage,serviceCapacityUsage:infrastructure.capacityUsage,residentServiceSatisfaction};
 city.treasury+=economy.net;if(city.tick%12===0&&homes.length&&city.population<homes.length*25)city.population++;
 syncCityCitizens(city);stepCityCitizens(city,seconds,city._commuteAssignments||[]);
 const serviceScore=occupiedResidents>0?residentServiceSatisfaction/100:(infrastructure.utilityCoverage*.6+infrastructure.publicServiceCoverage*.4)/100;
 city.happiness=Math.max(25,Math.min(98,city.happiness+(serviceScore-.35)*.08+(parks.length>2?.05:0)-cityTaxPressure(city.taxRates)-employment.unemploymentRate*.0003-Math.min(.015,(city.stats.averageCongestionDelay||0)*.0001)));
 
 stepCityTraffic(city,seconds);
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
 city.grid[y][x]="building";city.buildings.push(b);city.population+=residents;syncCityCitizens(city);return{ok:true,item:b,cost:COST[type]};
}
export function projectCityTile(x,y,w=32,h=16){return{x:(x-y)*w/2,y:(x+y)*h/2}}
function load(){
 try{
  const currentRaw=localStorage.getItem(KEY);
  if(currentRaw){
   let parsed=null,current=null;
   try{parsed=JSON.parse(currentRaw);current=migrateCitySave(parsed)}catch{}
   if(current){if(parsed?.schemaVersion===1)persist(current);return current}
   try{localStorage.setItem(RECOVERY_KEY,currentRaw.slice(0,1000000))}catch{}
  }
  const legacyRaw=localStorage.getItem(LEGACY_KEY);
  if(legacyRaw){
   try{localStorage.setItem(LEGACY_RECOVERY_KEY,legacyRaw.slice(0,1000000))}catch{}
   let migrated=null;
   try{migrated=migrateCitySave(JSON.parse(legacyRaw))}catch{}
   if(migrated&&persist(migrated)){localStorage.removeItem(LEGACY_KEY);return migrated}
  }
  const backupRaw=localStorage.getItem(BACKUP_KEY);
  if(backupRaw){
   let backup=null;
   try{backup=migrateCitySave(JSON.parse(backupRaw))}catch{}
   if(backup){persist(backup);return backup}
   try{localStorage.setItem(BACKUP_RECOVERY_KEY,backupRaw.slice(0,1000000))}catch{}
  }
 }catch{}
 return createInitialCity();
}
function persist(city){
 if(!isValidCitySave(city))return false;
 const serialized=JSON.stringify(city);
 try{
  const previous=localStorage.getItem(KEY);
  if(previous){
   try{if(isValidCitySave(JSON.parse(previous)))localStorage.setItem(BACKUP_KEY,previous)}catch{}
  }
  localStorage.setItem(KEY,serialized);
  return true;
 }catch{return false}
}
function mount(){
 let canvas=document.getElementById("cityViewport");const ctx=canvas?.getContext("2d");if(!canvas||!ctx)return;let threeRenderer=null;
 const $=id=>document.getElementById(id),city=load(),view={w:innerWidth,h:innerHeight,dpr:1},cam={x:0,y:0,zoom:1,orbit:0};
 if(syncCityCitizens(city))persist(city);
 let tool="select",speed=1,acc=0,last=0,selected=null,pointers=new Map(),gesture=null,toastFrames=0,raf=0,resizeFrame=0,lastPersistTick=city.tick;
 const TW=32,TH=16,centerY=(SIZE-1)*TH/2;
 const tilePoint=(x,y)=>{const p=projectCityTile(x,y,TW,TH);return{x:p.x,y:p.y-centerY}};
 function resize(){const viewport=window.visualViewport;view.w=Math.max(1,Math.round(viewport?.width||innerWidth));view.h=Math.max(1,Math.round(viewport?.height||innerHeight));view.dpr=Math.min(devicePixelRatio||1,1.6);canvas.width=Math.round(view.w*view.dpr);canvas.height=Math.round(view.h*view.dpr);canvas.style.width=view.w+"px";canvas.style.height=view.h+"px";if(!cam.initialized){cam.zoom=matchMedia("(max-width:760px), (max-height:520px)").matches?.72:Math.max(.42,Math.min(1.18,Math.min(view.w/1040,view.h/740)*1.08));cam.initialized=true}}
 function tileAt(px,py){if(threeRenderer)return threeRenderer.tileAt(px,py);const sx=(px-view.w/2-cam.x)/cam.zoom,sy=(py-view.h*.23-cam.y)/cam.zoom+centerY,a=sx/16,b=sy/8;return{x:Math.floor((a+b)/2+.5),y:Math.floor((b-a)/2+.5)}}
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
 function toolName(){return({select:"انتخاب",road:"خیابان",home:"مسکونی",shop:"تجاری",industrial:"صنعتی",administrative:"اداری",service:"خدمات",park:"پارک",power:"برق",water:"آب",sewage:"فاضلاب",waste:"پسماند",police:"پلیس",fire:"آتش‌نشانی",health:"درمان",education:"آموزش","zone-residential":"زون مسکونی","zone-commercial":"زون تجاری","zone-industrial":"زون صنعتی","zone-administrative":"زون اداری","zone-recreational":"زون تفریحی",bulldoze:"تخریب"})[tool]||tool}
 function updateBudgetPanel(){
  const panel=$("cityBudgetPanel");if(!panel||panel.classList.contains("hidden"))return;
  const fmt=value=>Math.round(value||0).toLocaleString("fa-IR");
  $("cityBudgetIncome").textContent=fmt(city.stats.income);
  $("cityBudgetExpenses").textContent=fmt(city.stats.expenses);
  $("cityBudgetNet").textContent=(city.stats.net>=0?"+":"")+fmt(city.stats.net);
  $("cityBudgetTreasury").textContent=fmt(city.treasury);
  for(const sector of Object.keys(CITY_DEFAULT_TAX_RATES)){
   const slider=$("cityTax"+sector[0].toUpperCase()+sector.slice(1));
   const output=$("cityTax"+sector[0].toUpperCase()+sector.slice(1)+"Value");
   if(slider)slider.value=city.taxRates[sector];
   if(output)output.textContent=city.taxRates[sector].toLocaleString("fa-IR")+"٪";
  }
  $("cityBudgetTaxRevenue").textContent=fmt(city.stats.taxRevenue);
  $("cityBudgetMaintenance").textContent=fmt(city.stats.maintenance);
  $("cityBudgetServiceUpkeep").textContent=fmt(city.stats.serviceUpkeep);
  if($("cityBudgetCommuteProductivity"))$("cityBudgetCommuteProductivity").textContent=(city.stats.commuteProductivityPercent??100).toLocaleString("fa-IR")+"٪";
  if($("cityBudgetCommuteLoss"))$("cityBudgetCommuteLoss").textContent=fmt(city.stats.commuteEconomicLoss);
 }
 function hud(){
  $("cityPopulation").textContent=city.population.toLocaleString("fa-IR");$("cityTreasury").textContent=Math.round(city.treasury).toLocaleString("fa-IR")+" ₮";$("cityJobs").textContent=city.stats.jobs.toLocaleString("fa-IR");$("cityHappiness").textContent=Math.round(city.happiness).toLocaleString("fa-IR")+"٪";if($("cityInfrastructure"))$("cityInfrastructure").textContent=(city.stats.overallCoverage??0).toLocaleString("fa-IR")+"٪";if($("cityUnemployment"))$("cityUnemployment").textContent=(city.stats.unemploymentRate??0).toLocaleString("fa-IR")+"٪";if($("cityCommuteCoverage"))$("cityCommuteCoverage").textContent=(city.stats.commuteCoverage??0).toLocaleString("fa-IR")+"٪";
  $("cityClock").textContent=String(Math.floor(city.minuteOfDay/60)).padStart(2,"0")+":"+String(city.minuteOfDay%60).padStart(2,"0");$("cityTick").textContent="روز "+(1+Math.floor(city.tick/144)).toLocaleString("fa-IR");
  $("cityStatus").textContent=tool==="select"?"شهر زنده است؛ برای ساخت، ابزار پایین را انتخاب کن.":"ابزار فعال: "+toolName();$("cityBudgetHint").textContent="درآمد +"+city.stats.income.toLocaleString("fa-IR")+" · هزینه -"+city.stats.expenses.toLocaleString("fa-IR")+" · تراز "+(city.stats.net>=0?"+":"")+Math.round(city.stats.net||0).toLocaleString("fa-IR");$("citySaveState").textContent=toastFrames>0?"ذخیره شد ✓":"ذخیره محلی";if(toastFrames>0)toastFrames--;
  updateBudgetPanel();
 }
 function draw(){if(threeRenderer){threeRenderer.render(city,view,cam);window.MshinCity3DStats=threeRenderer.getStats();hud();return}

  ctx.setTransform(view.dpr,0,0,view.dpr,0,0);ctx.clearRect(0,0,view.w,view.h);
  const sky=ctx.createLinearGradient(0,0,0,view.h);sky.addColorStop(0,"#a7cbd1");sky.addColorStop(.52,"#c9d8c0");sky.addColorStop(1,"#718c75");ctx.fillStyle=sky;ctx.fillRect(0,0,view.w,view.h);
  ctx.save();ctx.translate(view.w/2+cam.x,view.h*.23+cam.y);ctx.scale(cam.zoom,cam.zoom);
  for(let y=0;y<SIZE;y++)for(let x=0;x<SIZE;x++)ground(x,y,city.grid[y][x]);
  [...city.trees.map(t=>({d:t.x+t.y,draw:()=>tree(t)})),...city.buildings.map(b=>({d:b.x+b.y,draw:()=>building(b)}))].sort((a,b)=>a.d-b.d).forEach(v=>v.draw());
  cars();people();animals();if(selected){const p=tilePoint(selected.x,selected.y);ctx.strokeStyle="#fff1a6";ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(p.x,p.y-8);ctx.lineTo(p.x+16,p.y);ctx.lineTo(p.x,p.y+8);ctx.lineTo(p.x-16,p.y);ctx.closePath();ctx.stroke()}ctx.restore();
  $("cityPopulation").textContent=city.population.toLocaleString("fa-IR");$("cityTreasury").textContent=Math.round(city.treasury).toLocaleString("fa-IR")+" ₮";$("cityJobs").textContent=city.stats.jobs.toLocaleString("fa-IR");$("cityHappiness").textContent=Math.round(city.happiness).toLocaleString("fa-IR")+"٪";if($("cityInfrastructure"))$("cityInfrastructure").textContent=(city.stats.overallCoverage??0).toLocaleString("fa-IR")+"٪";
  $("cityClock").textContent=String(Math.floor(city.minuteOfDay/60)).padStart(2,"0")+":"+String(city.minuteOfDay%60).padStart(2,"0");$("cityTick").textContent="روز "+(1+Math.floor(city.tick/144)).toLocaleString("fa-IR");
  $("cityStatus").textContent=tool==="select"?"شهر زنده است؛ برای ساخت، ابزار پایین را انتخاب کن.":"ابزار فعال: "+toolName();$("cityBudgetHint").textContent="درآمد +"+city.stats.income.toLocaleString("fa-IR")+" · هزینه -"+city.stats.expenses.toLocaleString("fa-IR")+" · زیرساخت "+(city.stats.overallCoverage??0).toLocaleString("fa-IR")+"٪";$("citySaveState").textContent=toastFrames>0?"ذخیره شد ✓":"ذخیره محلی";if(toastFrames>0)toastFrames--;
 }
 const cityToolsNav=document.querySelector(".cityTools");
 function closeCityToolPanels(){
  if(!cityToolsNav)return;
  cityToolsNav.dataset.openPanel="";
  cityToolsNav.querySelectorAll("[data-city-panel]").forEach(panel=>{panel.hidden=true});
  cityToolsNav.querySelectorAll("[data-city-category]").forEach(button=>button.setAttribute("aria-expanded","false"));
 }
 function openCityToolPanel(category){
  if(!cityToolsNav)return;
  const alreadyOpen=cityToolsNav.dataset.openPanel===category;
  closeCityToolPanels();
  if(alreadyOpen)return;
  const panel=cityToolsNav.querySelector('[data-city-panel="'+category+'"]');
  const button=cityToolsNav.querySelector('[data-city-category="'+category+'"]');
  if(panel&&button){panel.hidden=false;cityToolsNav.dataset.openPanel=category;button.setAttribute("aria-expanded","true")}
 }
 function setTool(next){tool=next;document.querySelectorAll("[data-city-tool]").forEach(b=>{const active=b.dataset.cityTool===tool;b.classList.toggle("active",active);b.setAttribute("aria-pressed",String(active))});closeCityToolPanels();cityToolsNav?.querySelectorAll("[data-city-category]").forEach(button=>{const panel=cityToolsNav.querySelector('[data-city-panel="'+button.dataset.cityCategory+'"]');button.classList.toggle("has-active-tool",Boolean(panel?.querySelector('[data-city-tool="'+tool+'"]')))});canvas.style.cursor=tool==="select"?"grab":"crosshair";draw()}
 function apply(x,y){
  if(!inside(x,y))return;selected={x,y};
  if(tool==="select"){draw();return}
  if(tool==="bulldoze"){let changed=false;if(city.grid[y][x]==="building"){const b=city.buildings.find(v=>v.x===x&&v.y===y);if(b){city.buildings=city.buildings.filter(v=>v.id!==b.id);if(b.type==="home"){city.population=Math.max(0,city.population-b.residents);syncCityCitizens(city)}city.grid[y][x]="grass";city.treasury+=Math.round((COST[b.type]||0)*.35);$("cityToast").textContent="ساختمان تخریب شد؛ ۳۵٪ هزینه بازیابی شد.";changed=true}}else if(city.grid[y][x]==="road"){const dependent=city.buildings.some(b=>Math.abs(b.x-x)+Math.abs(b.y-y)===1&&[[1,0],[-1,0],[0,1],[0,-1]].some(([dx,dy])=>inside(b.x+dx,b.y+dy)&&city.grid[b.y+dy][b.x+dx]==="road"&&!(b.x+dx===x&&b.y+dy===y)));if(dependent){$("cityToast").textContent="این خیابان تنها مسیر دسترسی یک ساختمان است."}else{city.grid[y][x]="grass";$("cityToast").textContent="قطعه خیابان حذف شد.";changed=true}}if(changed)persist(city);draw();return}
  const result=placeCityItem(city,x,y,tool);$("cityToast").textContent=result.ok?"ساخت انجام شد · هزینه "+result.cost.toLocaleString("fa-IR"):result.reason;if(result.ok)persist(city);draw()
 }
 cityToolsNav?.querySelectorAll("[data-city-category]").forEach(button=>button.addEventListener("click",()=>openCityToolPanel(button.dataset.cityCategory)));
 document.querySelectorAll("[data-city-tool]").forEach(b=>b.addEventListener("click",()=>setTool(b.dataset.cityTool)));
 document.addEventListener("keydown",event=>{if(event.key==="Escape")closeCityToolPanels()});
 document.querySelectorAll("[data-city-speed]").forEach(b=>b.addEventListener("click",()=>{speed=Number(b.dataset.citySpeed);document.querySelectorAll("[data-city-speed]").forEach(v=>v.classList.toggle("active",v===b));$("citySpeedLabel").textContent=speed===0?"متوقف":speed+"×"}));
 $("cityZoomIn").addEventListener("click",()=>{cam.zoom=Math.min(1.5,cam.zoom*1.18);draw()});$("cityZoomOut").addEventListener("click",()=>{cam.zoom=Math.max(.05,cam.zoom/1.18);draw()});$("cityRecenter").addEventListener("click",()=>{cameraController.cancelMotion();cam.x=0;cam.y=0;cam.targetX=undefined;cam.targetY=undefined;cam.targetZ=undefined;cam.currentTargetX=undefined;cam.currentTargetY=undefined;cam.currentTargetZ=undefined;cam.orbit=0;cam.pitch=0.51;cam.zoom=matchMedia("(max-width:760px), (max-height:520px)").matches?.72:Math.max(.42,Math.min(1.18,Math.min(view.w/1040,view.h/740)*1.08));draw()});
 $("citySave").addEventListener("click",()=>{const ok=persist(city);if(ok)lastPersistTick=city.tick;$("cityToast").textContent=ok?"شهر با موفقیت ذخیره شد.":"ذخیره‌سازی در این مرورگر در دسترس نیست.";toastFrames=120;draw()});
 $("cityReset").addEventListener("click",()=>{if(!confirm("شهر فعلی با یک شهر تازه جایگزین شود؟"))return;const fresh=createInitialCity((city.seed+7919)>>>0);Object.keys(city).forEach(k=>delete city[k]);Object.assign(city,fresh);persist(city);draw()});
 $("cityHelp").addEventListener("click",()=>$("cityHelpPanel").classList.toggle("hidden"));$("cityCloseHelp").addEventListener("click",()=>$("cityHelpPanel").classList.add("hidden"));
 const budgetPanel=$("cityBudgetPanel"),budgetTrigger=$("cityBudget");
 function closeCityBudget(){
  if(budgetPanel.classList.contains("hidden"))return;
  budgetPanel.classList.add("hidden");
  budgetTrigger?.focus();
 }
 budgetTrigger.addEventListener("click",()=>{
  budgetPanel.classList.remove("hidden");
  updateBudgetPanel();
  $("cityCloseBudget").focus();
 });
 $("cityCloseBudget").addEventListener("click",closeCityBudget);
 $("cityBudgetDone").addEventListener("click",closeCityBudget);
 budgetPanel.addEventListener("keydown",event=>{
  if(event.key==="Escape"){event.preventDefault();event.stopPropagation();closeCityBudget();return}
  if(event.key!=="Tab")return;
  const focusable=[...budgetPanel.querySelectorAll('button:not([disabled]),input:not([disabled]),[href],[tabindex]:not([tabindex="-1"])')].filter(element=>element.getClientRects().length);
  const first=focusable[0],last=focusable[focusable.length-1];
  if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus()}
  else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first?.focus()}
 });
 for(const sector of Object.keys(CITY_DEFAULT_TAX_RATES)){
  const slider=$("cityTax"+sector[0].toUpperCase()+sector.slice(1));
  slider.addEventListener("input",()=>{
   const result=setCityTaxRate(city,sector,Number(slider.value));
   if(result.ok){persist(city);updateBudgetPanel()}
  });
 }
 const storagePanel=$("cityStoragePanel"),storageTrigger=$("cityBackup"),importFile=$("cityImportFile");
 function closeCityStorage(){
  if(storagePanel.classList.contains("hidden"))return;
  storagePanel.classList.add("hidden");
  storageTrigger?.focus();
 }
 storageTrigger.addEventListener("click",()=>{
  storagePanel.classList.remove("hidden");
  $("cityCloseStorage").focus();
 });
 $("cityCloseStorage").addEventListener("click",closeCityStorage);
 $("cityExportBackup").addEventListener("click",()=>{
  try{
   const payload=createCitySaveBackup(city),blob=new Blob([JSON.stringify(payload,null,2)],{type:"application/json"});
   const url=URL.createObjectURL(blob),link=document.createElement("a");
   link.href=url;link.download="mshin-city-"+new Date().toISOString().slice(0,10)+".json";
   document.body.append(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),30000);
   $("cityToast").textContent="نسخه پشتیبان شهر دانلود شد.";toastFrames=120;draw();
  }catch(error){$("cityToast").textContent="ساخت نسخه پشتیبان ناموفق بود: "+String(error.message||error);toastFrames=150;draw()}
 });
 $("cityImportBackup").addEventListener("click",()=>importFile.click());
 importFile.addEventListener("change",async event=>{
  const file=event.target.files?.[0];if(!file)return;
  try{
   if(file.size>2_000_000)throw new Error("حجم فایل پشتیبان بیش از ۲ مگابایت است");
   const payload=JSON.parse(await file.text()),restored=migrateCitySave(payload);
   if(!restored||!isValidCitySave(restored))throw new Error("ساختار فایل پشتیبان معتبر نیست");
   if(!confirm("شهر فعلی با نسخه پشتیبان انتخاب‌شده جایگزین شود؟"))return;
   if(!persist(restored))throw new Error("ذخیره نسخه بازیابی‌شده در این مرورگر ممکن نیست");
   Object.keys(city).forEach(key=>delete city[key]);Object.assign(city,restored);
   lastPersistTick=city.tick;closeCityStorage();$("cityToast").textContent="شهر از نسخه پشتیبان بازیابی شد.";toastFrames=150;draw();
  }catch(error){$("cityToast").textContent="بازیابی انجام نشد: "+String(error.message||error);toastFrames=150;draw()}
  finally{importFile.value=""}
 });
 storagePanel.addEventListener("keydown",event=>{
  if(event.key==="Escape"){event.preventDefault();event.stopPropagation();closeCityStorage();return}
  if(event.key!=="Tab")return;
  const focusable=[...storagePanel.querySelectorAll('button:not([disabled]),input:not([disabled]),[href],[tabindex]:not([tabindex="-1"])')].filter(element=>element.getClientRects().length);
  const first=focusable[0],last=focusable[focusable.length-1];
  if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus()}
  else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first?.focus()}
 });
 const cameraController=createCityCameraController({canvas,camera:cam,getRenderer:()=>threeRenderer,getTileAt:tileAt,onTap:(x,y)=>apply(x,y),onChange:()=>{if(!threeRenderer)draw()},isCameraLocked:()=>tool!=="select"&&tool!=="bulldoze"});
  const scheduleViewportResize=()=>{if(resizeFrame)return;resizeFrame=requestAnimationFrame(()=>{resizeFrame=0;resize();threeRenderer?.resize();draw()})};
 addEventListener("resize",scheduleViewportResize,{passive:true});
 window.visualViewport?.addEventListener("resize",scheduleViewportResize,{passive:true});addEventListener("keydown",e=>{if(e.key==="Escape")setTool("select");if(e.key==="+"||e.key==="=")cam.zoom=Math.min(1.5,cam.zoom*1.1);if(e.key==="-")cam.zoom=Math.max(.42,cam.zoom/1.1)});
 resize();import("./city-three-renderer.js").then(({createCityThreeRenderer})=>createCityThreeRenderer(canvas)).then(renderer=>{threeRenderer=renderer;window.MshinCity3DStats=renderer.getStats();window.MshinCity3DReady=true;const renderStatus=document.getElementById("cityRenderStatus");if(renderStatus)renderStatus.textContent="نمای سه‌بعدی فعال";draw()}).catch(error=>{window.MshinCity3DError=String(error);const renderStatus=document.getElementById("cityRenderStatus");if(renderStatus)renderStatus.textContent="حالت دوبعدی · خطای بارگذاری ۳بعدی";console.error("3D city renderer failed to load",error)});window.MshinCityDebug={get city(){return city},get activeTool(){return tool},get selected(){return selected},get view(){return{zoom:cam.zoom,x:cam.x,y:cam.y,orbit:cam.orbit||0,pitch:cam.pitch??0.51,targetX:cam.targetX??null,targetY:cam.targetY??null,targetZ:cam.targetZ??null,gesture:cameraController.getState()}},tileAtScreen(x,y){return threeRenderer?threeRenderer.tileAt(x,y):tileAt(x,y)},screenForTile(x,y){if(threeRenderer)return threeRenderer.screenForTile(x,y);const p=tilePoint(x,y);return{x:view.w/2+cam.x+p.x*cam.zoom,y:view.h*.23+cam.y+p.y*cam.zoom}},groundPointAt(x,y){return threeRenderer?.groundPointAt(x,y)??null},actAt(x,y,nextTool){if(nextTool)tool=nextTool;apply(x,y);return{tool,cell:inside(x,y)?city.grid[y][x]:null,saved:JSON.parse(localStorage.getItem(KEY)||"null")}},save:()=>persist(city),step:()=>stepCity(city),draw:()=>draw(),setCameraOrbit(value){if(Number.isFinite(value)){cam.orbit=value;draw()}},setCameraPitch(value){if(Number.isFinite(value)){cam.pitch=Math.max(.24,Math.min(.96,value));draw()}},setCameraZoom(value){if(Number.isFinite(value)){cam.zoom=Math.max(.05,Math.min(1.5,value));draw()}},place:(x,y,t)=>placeCityItem(city,x,y,t),setTaxRate:(sector,rate)=>{const result=setCityTaxRate(city,sector,rate);if(result.ok){persist(city);draw()}return result},get economy(){return computeCityEconomy(city,computeCityServices(city))}};
 document.documentElement.dataset.cityReady="true";
 let lastRender=0;
 function frame(now){if(document.hidden){raf=0;return}const dt=Math.min(.25,Math.max(0,(now-last)/1000||0));last=now;if(speed>0){acc+=dt*speed;let count=0;while(acc>=1&&count<4){stepCity(city);acc-=1;count++}}if(city.tick-lastPersistTick>=6){if(persist(city))lastPersistTick=city.tick}if(now-lastRender>=33){draw();lastRender=now}raf=requestAnimationFrame(frame)}
 function resumeCityLoop(){if(document.hidden||raf)return;last=0;lastRender=0;raf=requestAnimationFrame(frame)}
 function pauseCityLoop(){if(raf)cancelAnimationFrame(raf);raf=0;persist(city)}
 document.addEventListener("visibilitychange",()=>{if(document.hidden)pauseCityLoop();else resumeCityLoop()});
 raf=requestAnimationFrame(frame);addEventListener("pagehide",pauseCityLoop,{once:true});
}
if(typeof document!=="undefined"){if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",mount,{once:true});else mount()}
