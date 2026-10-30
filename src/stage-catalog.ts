export interface WorldTheme { id:string; name:string; ground:string; road:string; shoulder:string; accent:string; hazard:string; grip:number; decoration:string; }
export interface StageDefinition { id:number; name:string; world:WorldTheme; stageInWorld:number; seed:number; trackWidth:number; trackScale:number; laps:number; hazardCount:number; routeStyle:string; }
export interface Point { x:number; y:number; }
export const WORLD_THEMES:readonly WorldTheme[]=Object.freeze([
{id:"green-valley",name:"Green Valley",ground:"#83C95F",road:"#65727B",shoulder:"#F5E5B8",accent:"#F6D45C",hazard:"hay bale",grip:1,decoration:"tree"},
{id:"desert-storm",name:"Desert Storm",ground:"#E9B96C",road:"#A77A50",shoulder:"#F8D99B",accent:"#D66E36",hazard:"cactus",grip:.88,decoration:"dune"},
{id:"frozen-world",name:"Frozen World",ground:"#BCEAF4",road:"#7897B5",shoulder:"#EAFBFF",accent:"#62D6F0",hazard:"ice crystal",grip:.68,decoration:"pine"},
{id:"tropical-island",name:"Tropical Island",ground:"#55CDB2",road:"#A58B68",shoulder:"#F9E2A0",accent:"#F477A7",hazard:"palm stump",grip:.92,decoration:"palm"},
{id:"neon-city",name:"Neon City",ground:"#20234F",road:"#303653",shoulder:"#F04BC7",accent:"#4CEBFA",hazard:"neon barrier",grip:1.04,decoration:"tower"},
{id:"industrial-zone",name:"Industrial Zone",ground:"#707D87",road:"#3D4852",shoulder:"#D5A45F",accent:"#FFB44D",hazard:"crate",grip:.96,decoration:"pipe"},
{id:"mountain-rush",name:"Mountain Rush",ground:"#78AE91",road:"#65717A",shoulder:"#D8E2CB",accent:"#E4A45D",hazard:"rock",grip:.9,decoration:"pine"},
{id:"ancient-world",name:"Ancient World",ground:"#D6B77D",road:"#9A805F",shoulder:"#F2DDAA",accent:"#C56D43",hazard:"pillar",grip:.94,decoration:"ruin"},
{id:"space-racing",name:"Space Racing",ground:"#171B3D",road:"#44466B",shoulder:"#8B6BFF",accent:"#5BE8E7",hazard:"energy gate",grip:1.02,decoration:"planet"},
{id:"ultimate-championship",name:"Ultimate Championship",ground:"#D86C68",road:"#3D4B67",shoulder:"#F5D46F",accent:"#F8F3E8",hazard:"championship block",grip:1,decoration:"grandstand"}
]);
const NAMES=[
["Meadow Run","Forest Loop","Village Sprint","Canopy Bridge","Valley Cup"],
["Dune Dash","Sandy Switchbacks","Canyon Rush","Old Mine Run","Sandstorm Rally"],
["Snowdrop Sprint","Pinecone Pass","Crystal Lake","Frostbite Climb","Aurora Circuit"],
["Palm Coast","Lagoon Twist","Coral Run","Volcano Shore","Island Grand Prix"],
["Midnight Mile","Cyber Boulevard","Laser Loop","Skyline Drift","Neon Finale"],
["Assembly Alley","Cargo Circuit","Smokestack Run","Factory Shift","Steelworks Cup"],
["Eagle Ridge","Alpine Switchback","Cloud Pass","Rockfall Run","Summit Challenge"],
["Temple Trail","Obelisk Run","Lost Colosseum","Golden Labyrinth","Pharaoh's Cup"],
["Moonbase Sprint","Asteroid Belt","Orbital Loop","Nebula Run","Cosmic Grand Prix"],
["Rookie Arena","Velocity Stadium","Pro Circuit","Champion's Route","Ultimate Crown"]];
const STYLES=["oval","sweeper","chicane","hairpin","technical"];
export const STAGES:readonly StageDefinition[]=Object.freeze(WORLD_THEMES.flatMap((world,wi)=>NAMES[wi].map((name,si)=>({id:wi*5+si+1,name,world,stageInWorld:si+1,seed:(wi+1)*97+(si+1)*31,trackWidth:104-(si%3)*7,trackScale:1+(si-2)*.055,laps:3,hazardCount:5+si*2+wi,routeStyle:STYLES[si]}))));
export function getStage(id:number):StageDefinition {const stage=STAGES.find(s=>s.id===id);if(!stage)throw new RangeError("Unknown stage id: "+id);return stage;}
export function generateTrackPath(stage:StageDefinition,segments=96):Point[] {
 const points:Point[]=[],rx=560*stage.trackScale,ry=340*stage.trackScale;
 for(let i=0;i<segments;i++){const a=i*Math.PI*2/segments,seed=stage.seed,wave=1+.105*Math.sin(2*a+seed*.017)+.055*Math.cos(3*a+seed*.031)+.028*Math.sin(5*a+seed*.013),chicane=stage.stageInWorld===3?.075*Math.sin(7*a+seed*.01):0;points.push({x:Math.cos(a)*rx*(wave+chicane),y:Math.sin(a)*ry*(wave-chicane)});}
 return points;
}
export function nearestTrackPoint(point:Point,path:readonly Point[]):{point:Point;distance:number;segment:number} {
 if(path.length<2)throw new RangeError("Track path requires at least two points");
 let best={point:{x:path[0].x,y:path[0].y},distance:Number.POSITIVE_INFINITY,segment:0};
 for(let i=0;i<path.length;i++){const a=path[i],b=path[(i+1)%path.length],dx=b.x-a.x,dy=b.y-a.y,denom=dx*dx+dy*dy,t=denom===0?0:Math.max(0,Math.min(1,((point.x-a.x)*dx+(point.y-a.y)*dy)/denom)),candidate={x:a.x+t*dx,y:a.y+t*dy},distance=Math.hypot(point.x-candidate.x,point.y-candidate.y);if(distance<best.distance)best={point:candidate,distance,segment:i};}
 return best;
}
