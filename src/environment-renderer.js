const TAU = Math.PI * 2;

function polygon(ctx, points, fill, stroke = null) {
  ctx.beginPath();
  points.forEach(([x, y], index) => index ? ctx.lineTo(x, y) : ctx.moveTo(x, y));
  ctx.closePath();
  ctx.fillStyle = fill;
  ctx.fill();
  if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 1.5; ctx.stroke(); }
}

function drawTree(ctx, x, y, scale, palette, pine = false) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(scale, scale);
  ctx.fillStyle = "rgba(8,18,20,.28)";
  ctx.beginPath(); ctx.ellipse(12, 17, 27, 13, -.18, 0, TAU); ctx.fill();
  ctx.fillStyle = "#493a2c";
  polygon(ctx, [[-6,3],[3,3],[7,22],[0,26],[-7,20]], "#493a2c", "#2c2924");
  polygon(ctx, [[1,4],[5,6],[8,22],[3,20]], "#92704e");
  ctx.strokeStyle = "#5b4532"; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(0, 9); ctx.lineTo(-10, -5); ctx.moveTo(1, 8); ctx.lineTo(12, -8); ctx.stroke();
  if (pine) {
    polygon(ctx, [[0,-34],[25,3],[13,4],[30,22],[-28,22],[-12,4],[-25,4]], palette.mid, "#28483d");
    polygon(ctx, [[0,-34],[0,17],[-13,17],[-4,0],[-15,0]], palette.light);
    polygon(ctx, [[0,-19],[18,9],[5,8]], palette.dark);
  } else {
    polygon(ctx, [[-27,-7],[-22,7],[-4,16],[18,11],[29,-5],[18,5],[-4,11],[-18,2]], palette.dark, "#234b37");
    ctx.fillStyle = palette.dark;
    ctx.beginPath(); ctx.ellipse(-8, -8, 23, 18, -.3, 0, TAU); ctx.fill();
    ctx.fillStyle = palette.mid;
    ctx.beginPath(); ctx.ellipse(10, -16, 24, 20, .2, 0, TAU); ctx.fill();
    ctx.fillStyle = palette.light;
    ctx.beginPath(); ctx.ellipse(-5, -27, 15, 12, -.25, 0, TAU); ctx.fill();
    ctx.fillStyle = "rgba(255,255,255,.16)";
    ctx.beginPath(); ctx.ellipse(11, -20, 8, 5, .3, 0, TAU); ctx.fill();
  }
  ctx.restore();
}

function drawBuilding(ctx, x, y, scale, palette, tall = false) {
  const h = tall ? 42 : 27, w = tall ? 42 : 34;
  ctx.save(); ctx.translate(x, y); ctx.scale(scale, scale);
  ctx.fillStyle = "rgba(5,12,22,.34)";
  ctx.beginPath(); ctx.ellipse(12, 19, w * .8, 13, -.12, 0, TAU); ctx.fill();
  polygon(ctx, [[-w/2,-h/2],[w/2,-h/2],[w/2, h/2+7],[-w/2,h/2+7]], palette.wall, "#26384a");
  polygon(ctx, [[w/2,-h/2],[w/2+10,-h/2-8],[w/2+10,h/2-1],[w/2,h/2+7]], palette.side, "#26384a");
  polygon(ctx, [[-w/2,-h/2],[w/2,-h/2],[w/2+10,-h/2-8],[-w/2+10,-h/2-8]], palette.roof, "#dce7ed");
  ctx.fillStyle = palette.window;
  for (let row = 0; row < (tall ? 3 : 2); row++) for (let col = 0; col < 2; col++) {
    ctx.fillRect(-w/2+7+col*13, -h/2+8+row*12, 6, 7);
    ctx.fillStyle = "rgba(255,255,255,.32)";
    ctx.fillRect(-w/2+7+col*13, -h/2+8+row*12, 2, 7);
    ctx.fillStyle = palette.window;
  }
  ctx.restore();
}

function drawRock(ctx, x, y, scale, palette, icy = false) {
  ctx.save(); ctx.translate(x, y); ctx.scale(scale, scale);
  ctx.fillStyle = "rgba(5,12,20,.28)";
  ctx.beginPath(); ctx.ellipse(8, 12, 23, 10, -.2, 0, TAU); ctx.fill();
  polygon(ctx, [[-22,5],[-14,-13],[-2,-25],[15,-18],[24,2],[13,14],[-12,16]], palette.dark, "#5b6570");
  polygon(ctx, [[-14,-13],[-2,-25],[15,-18],[4,-3],[-5,3]], palette.light);
  if (icy) polygon(ctx, [[-2,-25],[15,-18],[4,-3]], "#f8ffff");
  ctx.restore();
}

function drawPalm(ctx, x, y, scale, palette) {
  ctx.save(); ctx.translate(x, y); ctx.scale(scale, scale);
  ctx.fillStyle = "rgba(5,15,17,.28)";
  ctx.beginPath(); ctx.ellipse(10, 17, 25, 10, -.2, 0, TAU); ctx.fill();
  polygon(ctx, [[-3,17],[1,-12],[6,-14],[5,18]], "#76553b");
  for (let i = 0; i < 7; i++) {
    ctx.save(); ctx.rotate(i * TAU / 7);
    ctx.fillStyle = i % 2 ? palette.mid : palette.light;
    ctx.beginPath(); ctx.moveTo(2,-12); ctx.quadraticCurveTo(26,-34,37,-9); ctx.quadraticCurveTo(18,-19,2,-12); ctx.fill();
    ctx.restore();
  }
  ctx.restore();
}

function drawCrowd(ctx, x, y, seed, palette) {
  ctx.save(); ctx.translate(x, y);
  ctx.fillStyle = "rgba(0,0,0,.24)";
  ctx.beginPath(); ctx.ellipse(7, 8, 43, 15, 0, 0, TAU); ctx.fill();
  for (let i = 0; i < 9; i++) {
    const px = (i - 4) * 9, py = (i % 3) * 5;
    const colors = [palette.light, "#e9e8d8", "#e65e52", "#3b6e9d", "#f3c65e"];
    ctx.fillStyle = colors[(i + seed) % colors.length];
    ctx.beginPath(); ctx.ellipse(px, py, 3.2, 5.3, 0, 0, TAU); ctx.fill();
    ctx.fillStyle = "#e9c6a2";
    ctx.beginPath(); ctx.arc(px, py - 6, 2.7, 0, TAU); ctx.fill();
    ctx.strokeStyle = "rgba(255,255,255,.28)"; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(px, py - 1); ctx.lineTo(px + (i % 2 ? 3 : -3), py - 8); ctx.stroke();
  }
  ctx.restore();
}

export function drawWorldEnvironment(ctx, world, frameAt) {
  const palettes = [
    {dark:"#24543b",mid:"#3e8750",light:"#8ecb68"},
    {dark:"#88603c",mid:"#bd8b52",light:"#efd18a"},
    {dark:"#486d83",mid:"#8eb9c8",light:"#e8fbff"},
    {dark:"#28664f",mid:"#31936d",light:"#78d8a0"},
    {dark:"#25264d",mid:"#444d82",light:"#8a78ef"},
    {dark:"#394650",mid:"#64737d",light:"#a6b2b8"},
    {dark:"#344c42",mid:"#668c70",light:"#c3d5b5"},
    {dark:"#69543d",mid:"#a88a5e",light:"#e3c68d"},
    {dark:"#30345d",mid:"#6567a7",light:"#9f9cff"},
    {dark:"#59434a",mid:"#a45d60",light:"#f0b46b"}
  ];
  const palette = palettes[Math.max(0, Math.min(9, world | 0))];
  for (let i = 0; i < 42; i++) {
    const t = i / 42 * TAU, f = frameAt(t), side = i % 2 ? 1 : -1;
    const offset = 218 + (i % 4) * 30;
    const x = f.p.x + f.nx * side * offset, y = f.p.y + f.ny * side * (145 + (i % 4) * 22);
    const scale = 1.08 + (i % 5) * .12;
    ctx.save(); ctx.translate(x, y); ctx.rotate(t);
    if (world === 0 || world === 6 || world === 9) drawTree(ctx, 0, 0, scale, palette, world === 6);
    else if (world === 1) drawRock(ctx, 0, 0, scale * 1.15, palette);
    else if (world === 2) drawTree(ctx, 0, 0, scale, palette, true);
    else if (world === 3) drawPalm(ctx, 0, 0, scale, palette);
    else if (world === 4 || world === 5 || world === 7 || world === 8) drawBuilding(ctx, 0, 0, scale, {
      wall: world === 4 ? "#343b67" : palette.mid,
      side: palette.dark, roof: palette.light,
      window: world === 4 || world === 8 ? "#73eaff" : "#d9e9ed"
    }, i % 3 === 0);
    ctx.restore();
  }
  // Spectator clusters and event infrastructure are deliberately outside the racing surface.
  for (let i = 0; i < 6; i++) {
    const t = (i * 7 + 2) / 42 * TAU, f = frameAt(t), side = i % 2 ? 1 : -1;
    const x = f.p.x + f.nx * side * 330, y = f.p.y + f.ny * side * 270;
    drawCrowd(ctx, x, y, i + world, palette);
    if (i % 2 === 0) drawBuilding(ctx, x + f.nx * 58, y + f.ny * 34, .58, {
      wall:"#d6e0e5", side:"#738594", roof:"#f2f5f6", window:"#78b9d9"
    }, false);
  }
}

export function drawHelicopterShadow(ctx, frameAt, timeMs = 0) {
  const t = (timeMs * .000075) % TAU, f = frameAt(t);
  const lateral = 55 + Math.sin(timeMs * .00009) * 135;
  const x = f.p.x + f.nx * lateral, y = f.p.y + f.ny * lateral;
  const rotation = f.angle + Math.sin(timeMs * .00022) * .12;
  const rotor = timeMs * .035;
  ctx.save(); ctx.translate(x, y); ctx.rotate(rotation); ctx.scale(1.3, 1.3);
  ctx.globalAlpha = .34;
  ctx.fillStyle = "rgba(4,10,20,.12)"; ctx.beginPath(); ctx.ellipse(0, 8, 48, 76, 0, 0, TAU); ctx.fill();
  ctx.strokeStyle = "rgba(4,10,20,.18)"; ctx.lineWidth = 5; ctx.beginPath(); ctx.ellipse(0, -4, 61, 61, 0, 0, TAU); ctx.stroke();
  ctx.fillStyle = "#07101b"; ctx.shadowColor = "#07101b"; ctx.shadowBlur = 10;
  // Tail boom and stabilizer.
  polygon(ctx, [[-7,12],[-4,12],[-23,58],[-28,58]], "#07101b");
  ctx.fillRect(-34,54,16,4);
  // Fuselage silhouette and landing skids.
  ctx.beginPath(); ctx.ellipse(0, 5, 15, 29, 0, 0, TAU); ctx.fill();
  ctx.beginPath(); ctx.ellipse(0, -4, 11, 13, 0, 0, TAU); ctx.fill();
  ctx.fillRect(-19, 19, 38, 3); ctx.fillRect(-16, 23, 3, 7); ctx.fillRect(13, 23, 3, 7);
  // Rotating main rotor and tail rotor silhouettes.
  ctx.save(); ctx.rotate(rotor);
  ctx.fillRect(-3, -57, 6, 114); ctx.fillRect(-54, -3, 108, 6);
  ctx.restore();
  ctx.save(); ctx.translate(-27, 57); ctx.rotate(-rotor * 1.7);
  ctx.fillRect(-2, -12, 4, 24); ctx.fillRect(-10, -2, 20, 4);
  ctx.restore();
  ctx.restore();
}
