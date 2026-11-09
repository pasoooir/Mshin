// Deterministic offline PNG icon artwork generator for Pasoo City BuildIt.
// Uses only Node built-ins. Produces 128x128 RGBA PNGs with a fully transparent canvas.
const building = ["residential_1","residential_2","residential_villa","residential_apartment","residential_farm","building_supplies","shop_chain","restaurant_traditional","fast_food","art_supplies","hardware_store","farmers_market","furniture_store","factory_small","factory_basic","factory_mass","factory_hightech","factory_nano","industrial_1","industrial_2","industrial_3","power_wind","power_coal","power_wind_deluxe","power_solar","power_oil","power_nuclear","water_tower","water_pump","sewage_small","sewage_basic","sewage_deluxe","waste_dump_small","waste_dump","waste_incinerator","waste_recycling","fire_station_small","fire_station","fire_station_deluxe","police_station","police_small","police_basic","police_precinct","clinic_small","clinic","hospital","town_hall","park_small"];
const raw = ["metal","wood","plastic","seeds","minerals","chemicals","textiles","sugar_spices","glass","animal_feed","electrical"];
const crafted = ["nails","planks","bricks","cement","glue","paint","hammer","measuring_tape","shovel","chair","table","vegetables"];
const ui = ["placeholder","storage","trade","save","cancel","close","collect","lock","back","confirm","bulldoze","build_menu","settings","info","plus","money","population","happiness","level","warning","check","arrow_left","arrow_right","services","commercial","industrial","road","residential","parks","hard_hat"];
const unique = [...building.map(id=>({category:categoryOf(id),id})),...raw.map(id=>({category:"raw",id})),...crafted.map(id=>({category:"crafted",id})),...ui.map(id=>({category:"ui",id}))];
function categoryOf(id){if(id.startsWith("residential_"))return "residential";if(id.startsWith("factory_")||id.startsWith("industrial_"))return "industrial";if(["building_supplies","shop_chain","restaurant_traditional","fast_food","art_supplies","hardware_store","farmers_market","furniture_store"].includes(id))return "commercial";if(id==="park_small")return "specializations";return "services";}
function allPaths(){
 const out=[]; const add=(cat,id,sourceCat=cat,sourceId=id)=>out.push({path:"godot-city-buildit/assets/icons/"+cat+"/"+id+".png",source:sourceCat+"/"+sourceId});
 for(const x of unique)add(x.category,x.id);
 const rawIds=raw,craftIds=crafted;
 // Every raw/crafted item gets its own source artwork.
 // Required UI aliases point to the closest matching dedicated glyph.
 const uiAliases={simoleons:"money",golden_key:"money",fire:"services",power:"services",water:"services",park:"parks",police:"services",health:"services",sewage:"services",waste:"services",government:"services",education:"services",transportation:"services",entertainment:"services",gambling:"services",beach:"parks",mountain:"parks",landmark:"services",trade_depot:"trade",global_trade:"trade",epic:"level",regions:"services",fallback:"placeholder"};
 for(const id of Object.keys(uiAliases))add("ui",id,"ui",uiAliases[id]);
 const serviceGroups={group_power:"power_wind",group_water:"water_tower",group_sewage:"sewage_basic",group_waste:"waste_recycling",group_fire:"fire_station",group_police:"police_station",group_health:"hospital",group_government:"town_hall"};
 for(const [id,src] of Object.entries(serviceGroups))add("services",id,"services",src);
 for(const x of building){const cat=categoryOf(x);if(cat==="services")add("services",x,"services",x);else if(cat==="specializations")add("specializations",x,"specializations",x);else if(cat==="residential"||cat==="commercial"||cat==="industrial"){}}
 for(const id of ["group_parks","group_education","group_transportation","group_entertainment","group_gambling","group_landmarks","group_worship"])add("specializations",id,"specializations","park_small");
 for(const id of ["road","road_build","road_upgrade","road_bulldoze"])add("roads",id,"ui",id==="road"?"road":"bulldoze");
 for(const [id,src] of Object.entries({smoke:"warning",no_power:"services",no_water:"services",no_fire_coverage:"services",storage_full:"warning",ready_collect:"collect",upgrading:"hard_hat",abandoned:"warning"}))add("status",id,"ui",src);
 // Every actual service/residential/commercial/industrial building is in its matching folder.
 for(const x of building){const cat=categoryOf(x);if(cat!=="services"&&cat!=="specializations")add(cat,x,cat,x);}
 return out;
}
function hash(s){let h=2166136261;for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619);}return h>>>0;}
function rgba(hex,a=255){const s=hex.slice(1);return [parseInt(s.slice(0,2),16),parseInt(s.slice(2,4),16),parseInt(s.slice(4,6),16),a];}
function pngFor(category,id){
 const W=128,H=128,px=new Uint8Array(W*H*4),h=hash(category+"/"+id);
 const palette=["#49A8D5","#E3A64B","#69B77F","#D87568","#8B80CF","#4C9E9A","#D18DB7","#8DA8BD"];
 const main=rgba(palette[h%palette.length]),dark=rgba("#26394A"),light=rgba("#F7F4E8"),accent=rgba(palette[(h>>>4)%palette.length]);
 function put(x,y,c){x=Math.round(x/2);y=Math.round(y/2);if(x<0||y<0||x>=W||y>=H)return;const k=(y*W+x)*4;px[k]=c[0];px[k+1]=c[1];px[k+2]=c[2];px[k+3]=c[3]??255;}
 function poly(p,c){const pts=p.map(q=>[q[0]/2,q[1]/2]);let min=H,max=0;for(const q of pts){min=Math.min(min,q[1]);max=Math.max(max,q[1]);}for(let y=Math.max(0,Math.floor(min));y<=Math.min(H-1,Math.ceil(max));y++){const xs=[];for(let i=0,j=pts.length-1;i<pts.length;j=i++){const a=pts[i],b=pts[j];if((a[1]>y)!==(b[1]>y))xs.push((b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]);}xs.sort((a,b)=>a-b);for(let i=0;i+1<xs.length;i+=2)for(let x=Math.ceil(xs[i]);x<=Math.floor(xs[i+1]);x++)put(x*2,y*2,c);}}
 function rect(x,y,w,hh,c){poly([[x,y],[x+w,y],[x+w,y+hh],[x,y+hh]],c);}
 function circle(cx,cy,r,c){for(let y=cy-r;y<=cy+r;y+=2)for(let x=cx-r;x<=cx+r;x+=2)if((x-cx)**2+(y-cy)**2<=r*r)put(x,y,c);}
 function line(x1,y1,x2,y2,w,c){const n=Math.max(Math.abs(x2-x1),Math.abs(y2-y1),1);for(let i=0;i<=n;i++){const x=x1+(x2-x1)*i/n,y=y1+(y2-y1)*i/n;circle(x,y,w/2,c);}}
 function frame(){circle(128,211,53,rgba("#15283A",50));circle(188,68,5,rgba("#FFFFFF",180));}
 function buildingIcon(){
   const levels=category==="industrial"?2+(h%2):category==="services"?2:category==="residential"?1:1+(h%2);
   const y=204-levels*38;
   poly([[64,204],[128,230],[194,196],[128,166]],rgba("#203447"));
   poly([[64,y+22],[128,y+49],[128,230],[64,204]],main);
   poly([[128,y+49],[194,y+17],[194,196],[128,230]],rgba("#38556C"));
   poly([[64,y+22],[128,y-10],[194,y+17],[128,y+49]],accent);
   for(let yy=y+54;yy<195;yy+=27){rect(82,yy,10,13,light);rect(105,yy,10,13,light);rect(143,yy+2,10,13,rgba("#BFE8F1"));rect(166,yy+2,10,13,rgba("#BFE8F1"));}
   rect(115,174,22,55,dark);
   if(category==="residential"){poly([[57,y+23],[128,y-17],[201,y+18],[128,y+57]],rgba("#D77D58"));}
   if(category==="industrial"){rect(150,y-34,16,42,rgba("#6F899B"));circle(158,y-38,9,light);}
   if(id.includes("fire")){poly([[128,45],[151,84],[142,111],[163,126],[150,164],[128,177],[104,163],[91,134],[108,110],[109,81]],rgba("#F47756"));}
   else if(id.includes("police")){poly([[128,60],[171,78],[164,132],[128,167],[92,132],[85,78]],rgba("#6D9FEA"));circle(128,109,14,light);}
   else if(id.includes("clinic")||id==="hospital"){rect(118,72,20,73,light);rect(91,98,74,20,light);rect(123,76,10,65,rgba("#E65C5C"));rect(95,103,65,10,rgba("#E65C5C"));}
   else if(id.includes("power")){poly([[128,50],[109,104],[131,104],[118,150],[157,90],[135,90]],rgba("#FFE27A"));}
   else if(id.includes("water")){poly([[128,49],[91,107],[97,141],[128,164],[159,141],[165,107]],rgba("#78D2F1"));}
   else if(id.includes("park")){rect(121,112,14,51,rgba("#916D4A"));circle(128,91,34,rgba("#67C58A"));}
   else if(id.includes("waste")||id.includes("recycling")){line(93,108,162,108,8,rgba("#8BD39B"));line(162,108,143,88,8,rgba("#8BD39B"));line(162,108,143,129,8,rgba("#8BD39B"));}
 }
 function objectIcon(){
   if(category==="raw"){
     if(id==="metal"||id==="minerals"){poly([[68,150],[91,92],[133,80],[183,116],[167,174],[105,190]],main);poly([[68,150],[105,190],[167,174],[133,80]],rgba("#58788B"));if(id==="metal")poly([[76,132],[105,105],[151,120],[130,154]],light);}
     else if(id==="wood"){for(let i=0;i<3;i++){rect(68+i*18,104+i*18,116,32,rgba("#A96E42"));circle(68+i*18,120+i*18,16,rgba("#DCA66A"));circle(68+i*18,120+i*18,7,dark);}}
     else if(id==="plastic"||id==="chemicals"){rect(91,85,74,100,main);rect(109,64,38,28,accent);rect(102,120,52,12,light);circle(128,157,15,rgba("#BDECF2"));}
     else if(id==="seeds"||id==="animal_feed"){poly([[83,88],[173,88],[162,187],[94,187]],rgba("#C79A5C"));poly([[83,88],[128,64],[173,88]],accent);for(let i=0;i<7;i++)circle(102+(i%3)*22,122+Math.floor(i/3)*20,5,rgba("#76522F"));}
     else if(id==="textiles"){rect(84,84,88,102,rgba("#DDAAC4"));circle(128,135,40,light);circle(128,135,26,rgba("#A86E9C"));circle(128,135,12,rgba("#F7E4EC"));}
     else if(id==="sugar_spices"){rect(87,91,82,93,rgba("#D8B77D"));rect(101,72,54,22,light);circle(112,124,10,rgba("#E9D3A0"));circle(142,147,9,rgba("#A95C42"));}
     else if(id==="glass"){poly([[77,72],[168,84],[181,183],[89,174]],rgba("#9EE5F3",180));line(93,91,151,99,7,light);line(98,112,157,120,5,rgba("#E3FAFF"));}
     else {poly([[84,100],[172,100],[160,183],[96,183]],rgba("#6AA9C8"));rect(105,75,46,24,accent);for(let x=112;x<151;x+=17)circle(x,135,5,rgba("#2E526A"));}
   } else {
     if(id==="nails"){for(let i=0;i<4;i++){line(75+i*25,170-i*13,143+i*20,85-i*8,9,rgba("#AFC5D2"));circle(75+i*25,170-i*13,8,light);}}
     else if(id==="planks"){for(let i=0;i<3;i++)poly([[62,120+i*24],[156,90+i*24],[194,108+i*24],[100,139+i*24]],rgba("#C48A50"));}
     else if(id==="bricks"){for(let r=0;r<3;r++)for(let c=0;c<2;c++){const x=70+c*58+(r%2)*25,y=93+r*35;rect(x,y,54,29,rgba("#C66F58"));}}
     else if(id==="cement"){poly([[82,78],[170,78],[158,190],[96,190]],rgba("#B9C3C9"));rect(100,67,56,20,light);}
     else if(id==="glue"||id==="paint"){rect(91,95,74,92,id==="paint"?rgba("#D85D58"):rgba("#E5D8A9"));rect(108,72,40,27,dark);if(id==="paint")rect(91,128,74,18,accent);}
     else if(id==="hammer"){line(100,112,157,179,18,rgba("#B77C4A"));rect(83,72,94,30,rgba("#AABAC4"));}
     else if(id==="measuring_tape"){circle(128,130,53,rgba("#F2C84B"));circle(128,130,35,rgba("#F9E8A8"));circle(128,130,15,rgba("#D59C31"));}
     else if(id==="shovel"){line(128,98,128,190,12,rgba("#A8794F"));poly([[93,89],[128,54],[163,89],[151,127],[105,127]],rgba("#9FB4C0"));}
     else if(id==="chair"){rect(91,73,74,70,rgba("#B9824D"));rect(98,140,14,57,dark);rect(147,140,14,57,dark);rect(87,111,82,30,rgba("#D39B5E"));}
     else if(id==="table"){rect(69,104,118,24,rgba("#C48B50"));rect(82,126,15,65,dark);rect(159,126,15,65,dark);}
     else {rect(84,112,88,67,rgba("#68B96E"));circle(105,103,22,rgba("#E85C55"));circle(145,93,23,rgba("#E8B94C"));circle(146,136,22,rgba("#74B95D"));}
   }
 }
 function uiIcon(){
   if(id==="storage"){rect(66,90,124,93,rgba("#A9794F"));poly([[66,90],[128,57],[190,90],[128,123]],rgba("#D9A56D"));rect(113,112,30,40,rgba("#E8D2A8"));}
   else if(id==="trade"||id==="arrow_left"||id==="arrow_right"||id==="back"){const rev=id==="arrow_left"||id==="back";line(rev?175:81,128,rev?81:175,128,18,main);poly(rev?[[81,128],[120,88],[120,168]]:[[175,128],[136,88],[136,168]],main);}
   else if(id==="save"){rect(67,68,122,120,rgba("#4F8FC0"));rect(86,68,82,45,rgba("#E8F2F6"));rect(95,136,66,52,rgba("#B8D3E2"));}
   else if(id==="cancel"||id==="close"){line(83,83,173,173,20,rgba("#ED776B"));line(173,83,83,173,20,rgba("#ED776B"));}
   else if(id==="collect"){poly([[65,103],[190,103],[175,181],[81,181]],rgba("#C68B50"));line(83,103,102,70,11,rgba("#E4B47D"));line(173,103,154,70,11,rgba("#E4B47D"));poly([[104,135],[123,154],[158,116],[170,128],[123,171],[92,147]],rgba("#EAF7E9"));}
   else if(id==="lock"){rect(76,113,104,78,rgba("#E9B94D"));line(96,113,96,94,12,light);line(96,94,128,65,12,light);line(128,65,160,94,12,light);line(160,94,160,113,12,light);}
   else if(id==="confirm"||id==="check"){line(70,133,111,170,18,rgba("#6ED39A"));line(111,170,190,80,18,rgba("#6ED39A"));}
   else if(id==="plus"){line(128,65,128,191,20,main);line(65,128,191,128,20,main);}
   else if(id==="money"){circle(128,128,61,rgba("#E9BB4F"));circle(128,128,44,rgba("#F8DE8D"));circle(128,128,26,rgba("#B77D2E"));}
   else if(id==="population"){circle(100,97,23,rgba("#E9B67E"));circle(157,97,23,rgba("#86C5E8"));poly([[63,183],[72,136],[100,122],[128,143],[137,183]],rgba("#E9B67E"));poly([[119,183],[128,143],[157,122],[184,139],[194,183]],rgba("#86C5E8"));}
   else if(id==="happiness"){circle(128,128,67,rgba("#F1C45A"));circle(106,113,8,dark);circle(150,113,8,dark);line(93,146,110,163,6,dark);line(110,163,146,163,6,dark);line(146,163,164,146,6,dark);}
   else if(id==="warning"){poly([[128,52],[204,190],[52,190]],rgba("#F1C65D"));line(128,95,128,143,12,dark);circle(128,166,7,dark);}
   else if(id==="info"){circle(128,128,68,rgba("#6FB6E8"));circle(128,86,8,light);rect(119,110,18,62,light);}
   else if(id==="settings"){circle(128,128,59,rgba("#9BAAB7"));circle(128,128,24,dark);for(let a=0;a<8;a++){const an=a*Math.PI/4;rect(120+Math.cos(an)*57,120+Math.sin(an)*57,16,16,rgba("#9BAAB7"));}}
   else if(id==="level"){circle(128,128,65,rgba("#E6B84D"));poly([[128,68],[143,111],[190,112],[153,141],[166,185],[128,159],[90,185],[103,141],[66,112],[113,111]],rgba("#FFF1B7"));}
   else if(id==="bulldoze"||id==="build_menu"||id==="hard_hat"){poly([[63,128],[83,77],[173,77],[194,128]],rgba("#E6B947"));rect(72,126,112,27,rgba("#E6B947"));line(87,77,87,57,12,dark);line(87,57,166,57,12,dark);}
   else if(id==="road"){poly([[90,57],[166,57],[201,197],[55,197]],rgba("#536779"));line(128,70,128,101,7,rgba("#F9D96A"));line(128,125,128,151,7,rgba("#F9D96A"));line(128,174,128,190,7,rgba("#F9D96A"));}
   else if(id==="services"){poly([[128,60],[175,84],[175,169],[128,196],[81,169],[81,84]],rgba("#6EACC2"));circle(128,128,26,light);}
   else if(id==="residential"){poly([[55,122],[128,61],[201,122],[184,140],[128,94],[72,140]],rgba("#D77D58"));rect(78,124,100,65,main);rect(117,148,22,41,dark);}
   else if(id==="commercial"||id==="industrial"){rect(70,86,116,100,main);poly([[60,88],[128,50],[196,88]],accent);for(let x=86;x<170;x+=28)rect(x,110,14,20,light);}
   else if(id==="parks"){rect(119,130,17,59,rgba("#936D4C"));circle(128,103,41,rgba("#65C78A"));}
   else if(id==="placeholder"){circle(128,128,65,rgba("#7894A8"));line(88,88,168,168,13,light);line(168,88,88,168,13,light);}
   else {circle(128,128,60,main);circle(128,128,25,light);}
 }
 frame();
 if(category==="raw"||category==="crafted")objectIcon();
 else if(category==="ui")uiIcon();
 else buildingIcon();
 // all four corners remain fully transparent; this is a true alpha PNG.
 const stride=W*4,scan=new Uint8Array((stride+1)*H);
 for(let y=0;y<H;y++){const o=y*(stride+1);scan[o]=0;scan.set(px.subarray(y*stride,(y+1)*stride),o+1);}
 function adler(a){let x=1,y=0;for(const v of a){x=(x+v)%65521;y=(y+x)%65521;}return ((y<<16)|x)>>>0;}
 function crc(a){let c=0xffffffff;for(const v of a){c^=v;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return (c^0xffffffff)>>>0;}
 function be(n){return [(n>>>24)&255,(n>>>16)&255,(n>>>8)&255,n&255];}
 function chunk(t,d){const b=new Uint8Array(t.length+d.length);for(let i=0;i<t.length;i++)b[i]=t.charCodeAt(i);b.set(d,t.length);return new Uint8Array([...be(d.length),...b,...be(crc(b))]);}
 const z=[0x78,0x01];for(let off=0;off<scan.length;){const n=Math.min(65535,scan.length-off),fin=off+n>=scan.length;z.push(fin?1:0,n&255,n>>>8,(~n)&255,((~n)>>>8)&255);for(let i=0;i<n;i++)z.push(scan[off+i]);off+=n;}z.push(...be(adler(scan)));
 const ihdr=new Uint8Array([...be(W),...be(H),8,6,0,0,0]),chunks=[chunk("IHDR",ihdr),chunk("IDAT",new Uint8Array(z)),chunk("IEND",new Uint8Array())],sig=[137,80,78,71,13,10,26,10];
 const png=new Uint8Array(sig.length+chunks.reduce((n,c)=>n+c.length,0));let p=0;png.set(sig,p);p+=sig.length;for(const c of chunks){png.set(c,p);p+=c.length;}
 const abc="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",out=[];for(let i=0;i<png.length;i+=3){const a=png[i],b=i+1<png.length?png[i+1]:0,c=i+2<png.length?png[i+2]:0,v=(a<<16)|(b<<8)|c;out.push(abc[(v>>18)&63]+abc[(v>>12)&63]+(i+1<png.length?abc[(v>>6)&63]:"=")+(i+2<png.length?abc[v&63]:"="));}return out.join("");
}
return {unique,allPaths,pngFor};