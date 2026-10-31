// Deterministic 2.5D trackside scenery. Objects use layered faces, contact shadows and depth-scaled silhouettes.
const TAU = Math.PI * 2;
const CROWD_COLORS = ["#f2d17b", "#e56e5b", "#d8e6ee", "#4b88b8", "#313f54", "#75b96c"];
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
function seeded(seed) {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}
function tree(ctx, x, y, size, kind, seed) {
  const random = seeded(seed);
  const pine = kind === "pine";
  const snow = kind === "snow";
  const colors = pine ? ["#123e35", "#1d5b45", "#34785a"] : snow ? ["#9dbfc5", "#d9ecea", "#f1f8f2"] : ["#214d38", "#34734a", "#559a50"];
  ctx.save();
  ctx.translate(x, y);
  // A displaced, soft footprint anchors the tree to the ground.
  ctx.fillStyle = "#07131c55";
  ctx.beginPath(); ctx.ellipse(size * .24, size * .48, size * .94, size * .42, -.16, 0, TAU); ctx.fill();
  // Tapered trunk with a lit edge and two exposed roots.
  ctx.fillStyle = "#493b2b";
  ctx.beginPath();
  ctx.moveTo(-size * .14, size * .38); ctx.lineTo(-size * .09, -size * .27);
  ctx.lineTo(size * .1, -size * .27); ctx.lineTo(size * .16, size * .38);
  ctx.closePath(); ctx.fill();
  ctx.strokeStyle = "#b18a58"; ctx.lineWidth = Math.max(1, size * .045);
  ctx.beginPath(); ctx.moveTo(-size * .04, size * .24); ctx.lineTo(-size * .025, -size * .2); ctx.stroke();
  ctx.fillStyle = "#382f27";
  ctx.beginPath(); ctx.moveTo(-size * .1, size * .3); ctx.lineTo(-size * .42, size * .48); ctx.lineTo(-size * .08, size * .4); ctx.closePath(); ctx.fill();
  ctx.beginPath(); ctx.moveTo(size * .1, size * .3); ctx.lineTo(size * .42, size * .46); ctx.lineTo(size * .08, size * .4); ctx.closePath(); ctx.fill();
  if (pine) {
    for (let layer = 0; layer < 4; layer++) {
      const top = -size * (.96 - layer * .22), half = size * (.28 + layer * .12);
      ctx.fillStyle = colors[layer % colors.length];
      ctx.beginPath(); ctx.moveTo(0, top); ctx.lineTo(half, top + size * .5); ctx.lineTo(-half, top + size * .5); ctx.closePath(); ctx.fill();
      ctx.fillStyle = "#ffffff22";
      ctx.beginPath(); ctx.moveTo(0, top); ctx.lineTo(-half * .18, top + size * .25); ctx.lineTo(half * .14, top + size * .25); ctx.closePath(); ctx.fill();
    }
  } else {
    // Three overlapping crown masses create an unmistakable raised canopy.
    for (let n = 0; n < 5; n++) {
      const angle = n * TAU / 5 + random() * .22;
      const radius = size * (.2 + random() * .2);
      const cx = Math.cos(angle) * radius, cy = -size * .47 + Math.sin(angle) * radius * .42;
      ctx.fillStyle = colors[n % colors.length];
      ctx.beginPath(); ctx.ellipse(cx, cy, size * (.42 + random() * .08), size * (.3 + random() * .06), angle * .15, 0, TAU); ctx.fill();
      ctx.fillStyle = "#07131c20";
      ctx.beginPath(); ctx.ellipse(cx + size * .1, cy + size * .12, size * .3, size * .16, .2, 0, TAU); ctx.fill();
    }
    ctx.fillStyle = "#ffffff3b";
    ctx.beginPath(); ctx.ellipse(-size * .2, -size * .63, size * .25, size * .1, -.42, 0, TAU); ctx.fill();
  }
  ctx.restore();
}
function building(ctx, x, y, w, h, accent, depth = 13) {
  ctx.save();
  ctx.translate(x, y);
  // Ground shadow, right-side wall, roof and front facade are separate planes.
  ctx.fillStyle = "#07131c66";
  ctx.beginPath(); ctx.moveTo(-w * .48, h * .36); ctx.lineTo(w * .62, h * .36); ctx.lineTo(w * .76, h * .53); ctx.lineTo(-w * .32, h * .53); ctx.closePath(); ctx.fill();
  ctx.fillStyle = "#46545f";
  ctx.beginPath(); ctx.moveTo(w / 2, -h / 2); ctx.lineTo(w / 2 + depth, -h / 2 - depth * .55); ctx.lineTo(w / 2 + depth, h / 2 - depth * .55); ctx.lineTo(w / 2, h / 2); ctx.closePath(); ctx.fill();
  ctx.fillStyle = "#9aa7aa";
  ctx.beginPath(); ctx.moveTo(-w / 2, -h / 2); ctx.lineTo(-w / 2 + depth, -h / 2 - depth * .55); ctx.lineTo(w / 2 + depth, -h / 2 - depth * .55); ctx.lineTo(w / 2, -h / 2); ctx.closePath(); ctx.fill();
  ctx.fillStyle = "#75858b"; ctx.fillRect(-w / 2, -h / 2, w, h);
  ctx.fillStyle = "#4b5c68"; ctx.fillRect(-w / 2 + 5, -h / 2 + 6, w - 10, h - 12);
  const columns = Math.max(2, Math.floor(w / 17)), rows = Math.max(1, Math.floor(h / 18));
  for (let row = 0; row < rows; row++) for (let col = 0; col < columns; col++) {
    const wx = -w / 2 + 10 + col * ((w - 20) / columns), wy = -h / 2 + 10 + row * ((h - 18) / rows);
    ctx.fillStyle = "#172b3a"; ctx.fillRect(wx, wy, 8, 10);
    ctx.fillStyle = accent; ctx.fillRect(wx + 1, wy + 1, 6, 6);
    ctx.fillStyle = "#ffffff55"; ctx.fillRect(wx + 1, wy + 1, 1.5, 6);
  }
  // Roof coping and a bright facade edge help the building read from above.
  ctx.fillStyle = "#d7d5c6";
  ctx.beginPath(); ctx.moveTo(-w / 2 - 2, -h / 2); ctx.lineTo(-w / 2 + depth, -h / 2 - depth * .55); ctx.lineTo(w / 2 + depth + 2, -h / 2 - depth * .55); ctx.lineTo(w / 2 + 2, -h / 2); ctx.closePath(); ctx.fill();
  ctx.fillStyle = "#ffffff66"; ctx.fillRect(-w / 2, -h / 2, 3, h);
  ctx.restore();
}
function crowd(ctx, x, y, seed, scale = 1) {
  const random = seeded(seed);
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(scale, scale);
  // A long stand shadow makes the group sit on the same ground plane as the props.
  ctx.fillStyle = "#0005";
  ctx.beginPath(); ctx.ellipse(0, 8, 43, 13, -.05, 0, TAU); ctx.fill();
  for (let i = 0; i < 12; i++) {
    const px = (random() - .5) * 76, py = (random() - .5) * 13, height = 7 + random() * 3;
    const color = CROWD_COLORS[i % CROWD_COLORS.length];
    ctx.save(); ctx.translate(px, py);
    // Legs, torso, arms and head remain legible as tiny top-down human silhouettes.
    ctx.strokeStyle = "#17232d"; ctx.lineWidth = 1.7;
    ctx.beginPath();
    ctx.moveTo(-1, height * .45); ctx.lineTo(-2.2, height + 3);
    ctx.moveTo(1, height * .45); ctx.lineTo(2.4, height + 3);
    ctx.moveTo(-2, -height * .3); ctx.lineTo(-4.5, height * .18);
    ctx.moveTo(2, -height * .3); ctx.lineTo(4.5, height * .18);
    ctx.stroke();
    ctx.fillStyle = color;
    ctx.beginPath(); ctx.moveTo(-3, -height * .1); ctx.lineTo(-2, -height * .65); ctx.lineTo(2, -height * .65); ctx.lineTo(3, -height * .1); ctx.lineTo(2, height * .55); ctx.lineTo(-2, height * .55); ctx.closePath(); ctx.fill();
    ctx.fillStyle = "#e9c29c"; ctx.beginPath(); ctx.arc(0, -height * .95, 2.2, 0, TAU); ctx.fill();
    ctx.fillStyle = "#ffffff66"; ctx.fillRect(-1.7, -height * .5, 1, height * .55);
    ctx.restore();
  }
  ctx.restore();
}
function rock(ctx, x, y, size, sand = false) {
  ctx.save(); ctx.translate(x, y);
  ctx.fillStyle = "#0005"; ctx.beginPath(); ctx.ellipse(5, size * .42, size * 1.05, size * .48, .2, 0, TAU); ctx.fill();
  ctx.fillStyle = sand ? "#8e6b49" : "#66747a";
  ctx.beginPath(); ctx.moveTo(-size, size * .2); ctx.lineTo(-size * .55, -size * .65); ctx.lineTo(size * .1, -size); ctx.lineTo(size * .85, -size * .45); ctx.lineTo(size, size * .3); ctx.closePath(); ctx.fill();
  ctx.fillStyle = "#ffffff35"; ctx.beginPath(); ctx.moveTo(-size * .55, -size * .65); ctx.lineTo(size * .1, -size); ctx.lineTo(size * .42, -size * .12); ctx.lineTo(-size * .12, size * .02); ctx.closePath(); ctx.fill();
  ctx.restore();
}
export function renderAerialScenery(ctx, stage, frameAt, world) {
  const random = seeded((stage.seed || stage.id || 1) * 7919), accent = world[4], kind = stage.world;
  for (let i = 0; i < 54; i++) {
    const t = i / 54 * TAU, frame = frameAt(t), side = i % 2 ? 1 : -1, distance = 248 + random() * 205;
    const x = frame.p.x + frame.nx * side * distance, y = frame.p.y + frame.ny * side * distance;
    const size = (19 + random() * 17) * (1.16 - (distance - 248) / 205 * .34);
    if (kind === 0 || kind === 3 || kind === 6) tree(ctx, x, y, size, kind === 6 ? "pine" : "broadleaf", stage.seed + i);
    else if (kind === 1 || kind === 7) rock(ctx, x, y, size, kind === 1);
    else if (kind === 2) tree(ctx, x, y, size, "snow", stage.seed + i);
    else if (kind === 4 || kind === 5 || kind === 9) {
      if (i % 3 === 0) building(ctx, x, y, 48 + random() * 34, 42 + random() * 34, accent, 10 + random() * 9);
      else {
        ctx.save(); ctx.fillStyle = "#0005"; ctx.beginPath(); ctx.ellipse(x + 9, y + 13, 25, 13, 0, 0, TAU); ctx.fill();
        ctx.fillStyle = "#45535f"; ctx.fillRect(x - 15, y - 17, 30, 32);
        ctx.fillStyle = "#7f9297"; ctx.beginPath(); ctx.moveTo(x - 15, y - 17); ctx.lineTo(x - 7, y - 23); ctx.lineTo(x + 22, y - 23); ctx.lineTo(x + 15, y - 17); ctx.closePath(); ctx.fill();
        ctx.fillStyle = accent; ctx.fillRect(x - 11, y - 11, 22, 5); ctx.fillStyle = "#ffffff77"; ctx.fillRect(x - 11, y - 11, 3, 3); ctx.restore();
      }
    } else {
      ctx.save(); ctx.fillStyle = "#0005"; ctx.beginPath(); ctx.ellipse(x + 7, y + 11, 25, 13, 0, 0, TAU); ctx.fill();
      ctx.fillStyle = accent; ctx.beginPath(); ctx.ellipse(x, y, 23, 10, .2, 0, TAU); ctx.fill();
      ctx.fillStyle = "#fff9"; ctx.fillRect(x - 13, y - 3, 26, 3); ctx.restore();
    }
    if (i % 9 === 0) crowd(ctx, x + side * 25, y + side * 16, stage.seed + i * 31, .82 + random() * .22);
  }
  // Alternating 3D crash barriers: top lip, front face and cast shadow.
  for (let i = 0; i < 22; i++) {
    const frame = frameAt((i + .35) / 22 * TAU), side = i % 2 ? 1 : -1;
    const x = frame.p.x + frame.nx * side * 218, y = frame.p.y + frame.ny * side * 218;
    ctx.save(); ctx.translate(x, y); ctx.rotate(frame.angle);
    ctx.fillStyle = "#0005"; ctx.fillRect(-23, 8, 49, 8);
    ctx.fillStyle = "#6a7478"; ctx.fillRect(-24, -4, 48, 15);
    ctx.fillStyle = i % 2 ? "#f0e8d2" : "#e66c56"; ctx.fillRect(-24, -7, 48, 12);
    ctx.fillStyle = "#ffffffaa"; ctx.fillRect(-20, -6, 7, 9); ctx.fillRect(-2, -6, 7, 9); ctx.fillRect(16, -6, 7, 9);
    ctx.restore();
  }
}
export function drawHelicopterShadow(ctx, pose) {
  ctx.save();
  ctx.translate(pose.x, pose.y); ctx.rotate(pose.rotation); ctx.scale(pose.scale, pose.scale);
  // Rotor disk and fuselage are softened separately to mimic height above the track.
  ctx.globalAlpha = .2; ctx.filter = "blur(7px)"; ctx.fillStyle = "#07101b";
  ctx.beginPath(); ctx.ellipse(0, 0, 53, 20, 0, 0, TAU); ctx.fill();
  ctx.beginPath(); ctx.moveTo(-8, -8); ctx.lineTo(-43, -30); ctx.lineTo(-47, -26); ctx.lineTo(-15, -2); ctx.lineTo(-15, 2); ctx.lineTo(-47, 26); ctx.lineTo(-43, 30); ctx.lineTo(-8, 8); ctx.closePath(); ctx.fill();
  ctx.fillRect(34, -4, 44, 8); ctx.beginPath(); ctx.ellipse(80, 0, 12, 5, 0, 0, TAU); ctx.fill();
  ctx.globalAlpha = .13; ctx.rotate(pose.rotor); ctx.fillRect(-3, -76, 6, 152); ctx.fillRect(-76, -3, 152, 6);
  ctx.filter = "none"; ctx.restore();
}
