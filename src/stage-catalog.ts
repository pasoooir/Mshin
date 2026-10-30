export interface WorldTheme { id:string; name:string; ground:string; road:string; shoulder:string; accent:string; hazard:string; grip:number; decoration:string; }
export interface StageDefinition { id:number; name:string; world:WorldTheme; stageInWorld:number; seed:number; trackWidth:number; trackScale:number; laps:number; hazardCount:number; routeStyle:string; }
export interface Point { x:number; y:number; }
export const WORLD_THEMES:readonly WorldTheme[]=Object.freeze([
{id:"green-valley",name:"دره سبز",ground:"#83C95F",road:"#65727B",shoulder:"#F5E5B8",accent:"#F6D45C",hazard:"عدل کاه",grip:1,decoration:"tree"},
{id:"desert-storm",name:"توفان کویر",ground:"#E9B96C",road:"#A77A50",shoulder:"#F8D99B",accent:"#D66E36",hazard:"کاکتوس",grip:.88,decoration:"dune"},
{id:"frozen-world",name:"سرزمین یخ",ground:"#BCEAF4",road:"#7897B5",shoulder:"#EAFBFF",accent:"#62D6F0",hazard:"بلور یخ",grip:.68,decoration:"pine"},
{id:"tropical-island",name:"جزیره استوایی",ground:"#55CDB2",road:"#A58B68",shoulder:"#F9E2A0",accent:"#F477A7",hazard:"تنه نخل",grip:.92,decoration:"palm"},
{id:"neon-city",name:"شهر نئونی",ground:"#20234F",road:"#303653",shoulder:"#F04BC7",accent:"#4CEBFA",hazard:"مانع نئونی",grip:1.04,decoration:"tower"},
{id:"industrial-zone",name:"منطقه صنعتی",ground:"#707D87",road:"#3D4852",shoulder:"#D5A45F",accent:"#FFB44D",hazard:"جعبه",grip:.96,decoration:"pipe"},
{id:"mountain-rush",name:"یورش کوهستان",ground:"#78AE91",road:"#65717A",shoulder:"#D8E2CB",accent:"#E4A45D",hazard:"صخره",grip:.9,decoration:"pine"},
{id:"ancient-world",name:"دنیای باستان",ground:"#D6B77D",road:"#9A805F",shoulder:"#F2DDAA",accent:"#C56D43",hazard:"ستون",grip:.94,decoration:"ruin"},
{id:"space-racing",name:"مسابقه فضایی",ground:"#171B3D",road:"#44466B",shoulder:"#8B6BFF",accent:"#5BE8E7",hazard:"دروازه انرژی",grip:1.02,decoration:"planet"},
{id:"ultimate-championship",name:"قهرمانی نهایی",ground:"#D86C68",road:"#3D4B67",shoulder:"#F5D46F",accent:"#F8F3E8",hazard:"مانع قهرمانی",grip:1,decoration:"grandstand"}
]);
const NAMES=[
["دشت‌نوردی","پیچ جنگل","شتاب روستا","پل جنگلی","جام دره"],
["تاخت روی تپه‌های شنی","پیچ‌وخم شنی","یورش دره","مسیر معدن قدیمی","رالی طوفان شن"],
["شتاب برفی","گردنه کاجستان","دریاچه بلورین","صعود یخبندان","پیست شفق قطبی"],
["ساحل نخل‌ها","پیچ تالاب","مسیر مرجان‌ها","ساحل آتشفشانی","جایزه بزرگ جزیره"],
["مسیر نیمه‌شب","بلوار سایبری","پیچ لیزری","دریفت آسمان‌خراش‌ها","پایان نئونی"],
["کوچه مونتاژ","پیست باربری","مسیر دودکش‌ها","شیفت کارخانه","جام فولاد"],
["خط‌الرأس عقاب","پیچ کوهستانی","گردنه ابرها","مسیر ریزش سنگ","چالش قله"],
["راه معبد","مسیر ابلیسک","کولوسئوم گمشده","هزارتوی طلایی","جام فرعون"],
["شتاب پایگاه ماه","کمربند سیارک‌ها","مدار فضایی","مسیر سحابی","جایزه بزرگ کیهانی"],
["میدان تازه‌کارها","ورزشگاه سرعت","پیست حرفه‌ای‌ها","مسیر قهرمان","تاج قهرمانی"]];
const STYLES=["oval","sweeper","chicane","hairpin","technical"];
export const STAGES:readonly StageDefinition[]=Object.freeze(WORLD_THEMES.flatMap((world,wi)=>NAMES[wi].map((name,si)=>({id:wi*5+si+1,name,world,stageInWorld:si+1,seed:(wi+1)*97+(si+1)*31,trackWidth:224-(si%3)*14,trackScale:1+(si-2)*.055,laps:3,hazardCount:5+si*2+wi,routeStyle:STYLES[si]}))));
export function getStage(id:number):StageDefinition {const stage=STAGES.find(s=>s.id===id);if(!stage)throw new RangeError("Unknown stage id: "+id);return stage;}
export function generateTrackPath(stage:StageDefinition,segments=96):Point[] {
 const points:Point[]=[],rx=1500*stage.trackScale,ry=960*stage.trackScale;
 for(let i=0;i<segments;i++){
  const a=i*Math.PI*2/segments,seed=stage.seed,phase=seed*.017;
  const styleAmplitude=stage.routeStyle==="oval"?.025:stage.routeStyle==="sweeper"?.07:stage.routeStyle==="chicane"?.12:stage.routeStyle==="hairpin"?.095:.14;
  const harmonic=stage.routeStyle==="oval"?2:stage.routeStyle==="sweeper"?2:stage.routeStyle==="chicane"?6:stage.routeStyle==="hairpin"?3:7;
  const wave=1+styleAmplitude*Math.sin(harmonic*a+phase)+.045*Math.cos(3*a+seed*.031)+.022*Math.sin(5*a+seed*.013);
  points.push({x:Math.cos(a)*rx*wave,y:Math.sin(a)*ry*(wave-.025*Math.sin(2*a+phase))});
 }
 return points;
}
export function nearestTrackPoint(point:Point,path:readonly Point[]):{point:Point;distance:number;segment:number} {
 if(path.length<2)throw new RangeError("Track path requires at least two points");
 let best={point:{x:path[0].x,y:path[0].y},distance:Number.POSITIVE_INFINITY,segment:0};
 for(let i=0;i<path.length;i++){const a=path[i],b=path[(i+1)%path.length],dx=b.x-a.x,dy=b.y-a.y,denom=dx*dx+dy*dy,t=denom===0?0:Math.max(0,Math.min(1,((point.x-a.x)*dx+(point.y-a.y)*dy)/denom)),candidate={x:a.x+t*dx,y:a.y+t*dy},distance=Math.hypot(point.x-candidate.x,point.y-candidate.y);if(distance<best.distance)best={point:candidate,distance,segment:i};}
 return best;
}
