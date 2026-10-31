// Lightweight 2.5D trackside art for the browser renderer. Geometry is deterministic per stage.
const TAU = Math.PI * 2;
export function getHelicopterShadowPose(time, stageId, center, tangent) {
  const phase = time * 0.00011 + stageId * 0.37;
  const side = Math.sin(phase) * 0.18;
  const forward = 0.16 + Math.cos(phase * 0.7) * 0.035;
  return {
    x: center.x + tangent.nx * side * 420 + tangent.x * forward * 520,
    y: center.y + tangent.ny * side * 420 + tangent.y * forward * 520,
    rotation: Math.atan2(tangent.y, tangent.x) + Math.sin(phase) * 0.12,
    scale: 0.92 + Math.sin(phase * 1.3) * 0.07,
    rotor: time * 0.018
  };
}
function seeded(seed) { let s = seed >>> 0; return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; }; }
function tree(ctx, x, y, size, kind, palette, seed) {
  const r = seeded(seed); ctx.save(); ctx.translate(x, y);
  ctx.fillStyle = "#07131c55"; ctx.beginPath(); ctx.ellipse(9, 13, size * 1.12, size * .72, -.2, 0, TAU); ctx.fill();
  ctx.fillStyle = "#493b2b"; ctx.fillRect(-size * .13, -size * .08, size * .26, size * .9);
  ctx.fillStyle = "#0005"; ctx.beginPath(); ctx.ellipse(0, size * .12, size * .42, size * .3, 0, 0, TAU); ctx.fill();
  const colors = kind === "pine" ? ["#174a3d", "#27694d", "#39835b"] : kind === "snow" ? ["#b7d9dc", "#e7f4ef", "#8db8b9"] : ["#286044", "#397b4c", "#65a85b"];
  for (let n = 0; n < 3; n++) { const a = n * TAU / 3 + r() * .3, rr = size * (.22 + r() * .18); ctx.fillStyle = colors[n]; ctx.beginPath(); ctx.ellipse(Math.cos(a) * rr, -size * .2 + Math.sin(a) * rr * .55, size * (.54 - n * .07), size * (.42 - n * .04), a * .18, 0, TAU); ctx.fill(); }
  ctx.fillStyle = "#ffffff35"; ctx.beginPath(); ctx.ellipse(-size * .2, -size * .34, size * .28, size * .12, -.4, 0, TAU); ctx.fill(); ctx.restore();
}
function building(ctx, x, y, w, h, accent) {
  ctx.save(); ctx.translate(x, y); ctx.fillStyle = "#07131c55"; ctx.beginPath(); ctx.moveTo(-w/2+10, -h/2+12); ctx.lineTo(w/2+20, -h/2+12); ctx.lineTo(w/2+20, h/2+12); ctx.lineTo(-w/2+10, h/2+12); ctx.fill();
  ctx.fillStyle = "#64717a"; ctx.beginPath(); ctx.moveTo(-w/2, -h/2); ctx.lineTo(-w/2+15, -h/2-12); ctx.lineTo(w/2+15, -h/2-12); ctx.lineTo(w/2, -h/2); ctx.closePath(); ctx.fill();
  ctx.fillStyle = "#9aa7aa"; ctx.fillRect(-w/2, -h/2, w, h); ctx.fillStyle = "#4b5c68"; ctx.fillRect(-w/2+8, -h/2+7, w-16, h-14);
  ctx.fillStyle = accent; for (let i=0;i<Math.max(2,Math.floor(w/20));i++) ctx.fillRect(-w/2+13+i*18, -h/2+12, 8, 7);
  ctx.fillStyle = "#d7d5c6"; ctx.fillRect(-w/2+5, -h/2-5, w-10, 7); ctx.restore();
}
function crowd(ctx, x, y, seed) {
  const r=seeded(seed); ctx.save(); ctx.fillStyle="#0004"; ctx.beginPath(); ctx.ellipse(0,8,42,12,0,0,TAU); ctx.fill();
  for(let i=0;i<18;i++){const px=x+(r()-.5)*76,py=y+(r()-.5)*17,s=3+r()*2;ctx.fillStyle=["#f2d17b","#e56e5b","#d8e6ee","#4b88b8","#313f54"][i%5];ctx.beginPath();ctx.arc(px,py,s,0,TAU);ctx.fill();ctx.fillRect(px-s*.55,py+s*.55,s*1.1,s*1.8);}
  ctx.restore();
}
export function renderAerialScenery(ctx, stage, frameAt, world) {
  const random=seeded((stage.seed||stage.id||1)*7919), accent=world[4], kind=stage.world;
  for(let i=0;i<54;i++){
    const t=i/54*TAU, f=frameAt(t), side=i%2?1:-1, distance=248+random()*205;
    const x=f.p.x+f.nx*side*distance, y=f.p.y+f.ny*side*distance, size=19+random()*17;
    if(kind===0||kind===3||kind===6) tree(ctx,x,y,size,kind===6?"pine":"broadleaf",world,stage.seed+i);
    else if(kind===1||kind===7){ctx.save();ctx.fillStyle="#0004";ctx.beginPath();ctx.ellipse(x+8,y+9,size*1.25,size*.7,.3,0,TAU);ctx.fill();ctx.fillStyle=kind===1?"#b58b55":"#9d896d";ctx.beginPath();ctx.moveTo(x-size,y+size*.4);ctx.lineTo(x-size*.3,y-size*.8);ctx.lineTo(x+size*.5,y-size*.5);ctx.lineTo(x+size,y+size*.4);ctx.closePath();ctx.fill();ctx.fillStyle="#fff3";ctx.beginPath();ctx.moveTo(x-size*.3,y-size*.8);ctx.lineTo(x+size*.5,y-size*.5);ctx.lineTo(x+size*.1,y);ctx.closePath();ctx.fill();ctx.restore();}
    else if(kind===2){tree(ctx,x,y,size,"snow",world,stage.seed+i);}
    else if(kind===4||kind===5||kind===9){if(i%3===0)building(ctx,x,y,48+random()*34,42+random()*34,accent);else{ctx.fillStyle="#0005";ctx.beginPath();ctx.ellipse(x+8,y+9,24,12,0,0,TAU);ctx.fill();ctx.fillStyle="#68757b";ctx.fillRect(x-16,y-17,32,31);ctx.fillStyle=accent;ctx.fillRect(x-12,y-12,24,5);}}
    else {ctx.save();ctx.fillStyle="#0005";ctx.beginPath();ctx.ellipse(x+6,y+8,24,13,0,0,TAU);ctx.fill();ctx.fillStyle=accent;ctx.beginPath();ctx.ellipse(x,y,23,10,.2,0,TAU);ctx.fill();ctx.fillStyle="#fff8";ctx.fillRect(x-13,y-3,26,3);ctx.restore();}
    if(i%9===0) crowd(ctx,x+side*25,y+side*16,stage.seed+i*31);
  }
  // Safety barriers and occasional service tents establish rally-event scale.
  for(let i=0;i<22;i++){const f=frameAt((i+.35)/22*TAU),side=i%2?1:-1,x=f.p.x+f.nx*side*218,y=f.p.y+f.ny*side*218;ctx.save();ctx.translate(x,y);ctx.rotate(f.angle);ctx.fillStyle="#0004";ctx.fillRect(-22,7,48,8);ctx.fillStyle=i%2?"#f0e8d2":"#e66c56";ctx.fillRect(-24,-5,48,13);ctx.fillStyle="#fff9";ctx.fillRect(-20,-4,7,10);ctx.fillRect(-2,-4,7,10);ctx.fillRect(16,-4,7,10);ctx.restore();}
}
export function drawHelicopterShadow(ctx, pose) {
  ctx.save(); ctx.translate(pose.x,pose.y); ctx.rotate(pose.rotation); ctx.scale(pose.scale,pose.scale);
  ctx.globalAlpha=.23; ctx.filter="blur(5px)"; ctx.fillStyle="#07101b";
  ctx.beginPath(); ctx.ellipse(0,0,49,17,0,0,TAU); ctx.fill();
  ctx.beginPath(); ctx.moveTo(-8,-8); ctx.lineTo(-43,-30); ctx.lineTo(-47,-26); ctx.lineTo(-15,-2); ctx.lineTo(-15,2); ctx.lineTo(-47,26); ctx.lineTo(-43,30); ctx.lineTo(-8,8); ctx.closePath(); ctx.fill();
  ctx.fillRect(34,-4,44,8); ctx.beginPath(); ctx.ellipse(80,0,12,5,0,0,TAU); ctx.fill();
  ctx.rotate(pose.rotor); ctx.fillRect(-3,-68,6,136); ctx.fillRect(-68,-3,136,6);
  ctx.filter="none"; ctx.restore();
}
