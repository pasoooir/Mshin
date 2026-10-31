export const RACE_CAMERA_MODES = Object.freeze(["side", "top", "southeast", "southwest"]);
export const RACE_CAMERA_LABELS = Object.freeze({
  side: "SIDE",
  top: "TOP",
  southeast: "SE",
  southwest: "SW"
});

export function nextRaceCameraMode(mode) {
  const index = RACE_CAMERA_MODES.indexOf(mode);
  return RACE_CAMERA_MODES[(index + 1 + RACE_CAMERA_MODES.length) % RACE_CAMERA_MODES.length];
}

export function projectRacePoint(point, cameraPoint, cameraAngle, viewport, options = {}) {
  const dx = point.x - cameraPoint.x;
  const dy = point.y - cameraPoint.y;
  const forwardX = Math.cos(cameraAngle);
  const forwardY = Math.sin(cameraAngle);
  const rightX = -forwardY;
  const rightY = forwardX;
  const depth = dx * forwardX + dy * forwardY + (options.cameraOffset ?? 190);
  const lateral = dx * rightX + dy * rightY;
  const focal = options.focalLength ?? Math.min(viewport.width * 0.92, viewport.height * 1.28);
  const cameraHeight = options.cameraHeight ?? 420;
  const perspective = focal / Math.max(80, depth + cameraHeight);
  const horizon = options.horizon ?? viewport.height * 0.31;
  const screenY = horizon + (viewport.height - horizon) * cameraHeight / Math.max(cameraHeight, depth + cameraHeight);
  return {
    x: viewport.width * 0.5 + lateral * perspective + (options.yaw ?? 0) * (screenY - horizon),
    y: screenY,
    scale: perspective,
    depth
  };
}

function roundedPath(ctx, x, y, width, height, radius) {
  ctx.beginPath();
  ctx.roundRect(x, y, width, height, radius);
}

function drawTree(ctx, x, y, scale, color, accent) {
  const size = Math.max(2, 30 * scale);
  ctx.fillStyle = "#17231b";
  ctx.beginPath();
  ctx.ellipse(x + size * .18, y + size * .2, size * .68, size * .23, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(x, y - size * 1.45);
  ctx.lineTo(x - size * .86, y + size * .35);
  ctx.lineTo(x + size * .86, y + size * .35);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = accent;
  ctx.beginPath();
  ctx.arc(x - size * .2, y - size * .5, size * .2, 0, Math.PI * 2);
  ctx.fill();
}

function drawRacingCar(ctx, x, y, scale, color, direction = 1, sideView = false) {
  const s = Math.max(.18, Math.min(1.5, scale));
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(s * direction, s);
  const length = sideView ? 88 : 64;
  const height = sideView ? 30 : 52;
  ctx.fillStyle = "#0009";
  ctx.beginPath();
  ctx.ellipse(0, height * .56, length * .62, height * .28, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#111923";
  for (const wheelX of [-length * .34, length * .34]) {
    ctx.beginPath();
    ctx.arc(wheelX, height * .34, sideView ? 10 : 8, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#82909d";
    ctx.beginPath();
    ctx.arc(wheelX, height * .34, sideView ? 4 : 3, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#111923";
  }
  ctx.fillStyle = color;
  ctx.beginPath();
  if (sideView) {
    ctx.moveTo(-length * .55, height * .12);
    ctx.lineTo(-length * .48, -height * .12);
    ctx.lineTo(-length * .22, -height * .2);
    ctx.lineTo(-length * .05, -height * .62);
    ctx.lineTo(length * .2, -height * .66);
    ctx.lineTo(length * .43, -height * .18);
    ctx.lineTo(length * .55, -height * .06);
    ctx.lineTo(length * .52, height * .22);
    ctx.lineTo(-length * .5, height * .22);
  } else {
    ctx.moveTo(-length * .48, height * .3);
    ctx.lineTo(-length * .38, -height * .3);
    ctx.lineTo(-length * .18, -height * .48);
    ctx.lineTo(length * .18, -height * .48);
    ctx.lineTo(length * .42, -height * .2);
    ctx.lineTo(length * .5, height * .3);
  }
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = "#bceeff";
  ctx.beginPath();
  if (sideView) {
    ctx.moveTo(-length * .12, -height * .24);
    ctx.lineTo(-length * .015, -height * .53);
    ctx.lineTo(length * .14, -height * .55);
    ctx.lineTo(length * .3, -height * .22);
  } else {
    ctx.moveTo(-length * .17, -height * .34);
    ctx.lineTo(length * .17, -height * .34);
    ctx.lineTo(length * .28, -height * .12);
    ctx.lineTo(-length * .28, -height * .12);
  }
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = "#fff3c4";
  ctx.fillRect(direction > 0 ? length * .43 : -length * .5, -height * .02, 5, 5);
  ctx.fillStyle = "#ff514c";
  ctx.fillRect(direction > 0 ? -length * .52 : length * .44, 0, 5, 5);
  ctx.restore();
}

function drawPlayerSideCar(ctx, width, height, color, steer, speed, mode) {
  const scale = Math.max(.66, Math.min(1.18, Math.min(width / 1050, height / 650)));
  const direction = mode === "southwest" ? -1 : 1;
  const x = width * .5 + Math.max(-1, Math.min(1, steer)) * 20;
  const y = height * .825;
  const length = 174 * scale;
  const bodyHeight = 58 * scale;
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(direction, 1);
  ctx.fillStyle = "#0009";
  ctx.beginPath();
  ctx.ellipse(0, bodyHeight * .42, length * .62, bodyHeight * .3, 0, 0, Math.PI * 2);
  ctx.fill();

  // Side-profile body with a low rally nose, raised rear quarter and visible cabin.
  ctx.beginPath();
  ctx.moveTo(-length * .56, bodyHeight * .12);
  ctx.lineTo(-length * .48, -bodyHeight * .02);
  ctx.lineTo(-length * .24, -bodyHeight * .16);
  ctx.lineTo(-length * .08, -bodyHeight * .64);
  ctx.lineTo(length * .22, -bodyHeight * .67);
  ctx.lineTo(length * .42, -bodyHeight * .2);
  ctx.lineTo(length * .58, -bodyHeight * .08);
  ctx.lineTo(length * .56, bodyHeight * .2);
  ctx.lineTo(-length * .5, bodyHeight * .2);
  ctx.closePath();
  ctx.fillStyle = color;
  ctx.fill();

  ctx.beginPath();
  ctx.moveTo(-length * .13, -bodyHeight * .25);
  ctx.lineTo(-length * .035, -bodyHeight * .57);
  ctx.lineTo(length * .17, -bodyHeight * .59);
  ctx.lineTo(length * .34, -bodyHeight * .23);
  ctx.closePath();
  ctx.fillStyle = "#b9eaff";
  ctx.fill();
  ctx.fillStyle = "#17212d";
  ctx.fillRect(-length * .02, -bodyHeight * .59, 3 * scale, bodyHeight * .34);
  ctx.fillStyle = "#f3f6f8";
  ctx.fillRect(length * .46, -bodyHeight * .02, 8 * scale, 5 * scale);
  ctx.fillStyle = "#ff514b";
  ctx.fillRect(-length * .53, bodyHeight * .02, 8 * scale, 6 * scale);

  for (const wheelX of [-length * .34, length * .34]) {
    ctx.fillStyle = "#0a1018";
    ctx.beginPath();
    ctx.arc(wheelX, bodyHeight * .25, 17 * scale, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#9ca9b5";
    ctx.beginPath();
    ctx.arc(wheelX, bodyHeight * .25, 8 * scale, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#e2e9ef";
    ctx.lineWidth = 2 * scale;
    ctx.beginPath();
    ctx.arc(wheelX, bodyHeight * .25, 4 * scale, 0, Math.PI * 2);
    ctx.stroke();
  }

  ctx.fillStyle = "#202b39";
  ctx.fillRect(-length * .57, -bodyHeight * .22, 12 * scale, 5 * scale);
  ctx.fillRect(length * .42, -bodyHeight * .24, 18 * scale, 5 * scale);
  if (speed > 160) {
    ctx.globalAlpha = .32;
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(-length * .82, bodyHeight * .1, length * .2, 2 * scale);
    ctx.fillRect(-length * .92, bodyHeight * .22, length * .28, 2 * scale);
  }
  ctx.restore();
}

export function drawPerspectiveRace(ctx, options) {
  const {
    width, height, mode = "side", car, stage, world, center, frameAt,
    rivals = [], obstacles = [], pickups = [], particles = [], carColor = "#f15d4e",
    roadHalfWidth = 180, now = 0
  } = options;
  const palette = world || ["", "#6eae56", "#59636d", "#f3e2b4", "#f4d35e", "#6e9a53"];
  const current = frameAt(car.t);
  const cameraPoint = { x: current.p.x + current.nx * (car.lateral || 0), y: current.p.y + current.ny * (car.lateral || 0) };
  const cameraAngle = current.angle;
  const horizon = height * (mode === "side" ? .34 : .29);
  const yaw = mode === "side" ? .18 : mode === "southeast" ? .12 : -.12;
  const viewport = { width, height };
  const project = (t, lateral = 0) => {
    const f = frameAt(t);
    return projectRacePoint({
      x: f.p.x + f.nx * lateral,
      y: f.p.y + f.ny * lateral
    }, cameraPoint, cameraAngle, viewport, { horizon, yaw });
  };

  ctx.save();
  const sky = ctx.createLinearGradient(0, 0, 0, height);
  sky.addColorStop(0, mode === "side" ? "#79b5df" : "#5d9fcf");
  sky.addColorStop(.52, "#d8e8df");
  sky.addColorStop(.53, palette[1]);
  sky.addColorStop(1, palette[1]);
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, width, height);

  // Distant layered hills create a horizon and parallax without per-frame image decoding.
  ctx.fillStyle = "#334b47";
  ctx.beginPath();
  ctx.moveTo(0, horizon + 28);
  for (let i = 0; i <= 8; i++) {
    const x = width * i / 8;
    ctx.lineTo(x, horizon - 28 - Math.sin(i * 1.73 + stage.seed) * 30);
  }
  ctx.lineTo(width, horizon + 40);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = "#587a54";
  ctx.fillRect(0, horizon + 22, width, height - horizon);

  const segments = 52;
  const samples = [];
  for (let i = 0; i <= segments; i++) {
    const t = car.t + i * .0175;
    const f = frameAt(t);
    const pointAt = lateral => projectRacePoint({
      x: f.p.x + f.nx * lateral,
      y: f.p.y + f.ny * lateral
    }, cameraPoint, cameraAngle, viewport, { horizon, yaw });
    samples.push({
      t,
      left: pointAt(-roadHalfWidth),
      right: pointAt(roadHalfWidth),
      shoulderLeft: pointAt(-roadHalfWidth - 38),
      shoulderRight: pointAt(roadHalfWidth + 38),
      lanes: [-90, 0, 90].map(pointAt),
      treeLeft: pointAt(-roadHalfWidth - 72),
      treeRight: pointAt(roadHalfWidth + 72)
    });
  }

  for (let i = segments - 1; i >= 0; i--) {
    const a = samples[i], b = samples[i + 1];
    ctx.fillStyle = i % 2 ? palette[3] : palette[5];
    ctx.beginPath();
    ctx.moveTo(a.shoulderLeft.x, a.shoulderLeft.y);
    ctx.lineTo(a.shoulderRight.x, a.shoulderRight.y);
    ctx.lineTo(b.shoulderRight.x, b.shoulderRight.y);
    ctx.lineTo(b.shoulderLeft.x, b.shoulderLeft.y);
    ctx.closePath();
    ctx.fill();

    ctx.fillStyle = palette[2];
    ctx.beginPath();
    ctx.moveTo(a.left.x, a.left.y);
    ctx.lineTo(a.right.x, a.right.y);
    ctx.lineTo(b.right.x, b.right.y);
    ctx.lineTo(b.left.x, b.left.y);
    ctx.closePath();
    ctx.fill();

    if (i % 3 === 0) {
      ctx.strokeStyle = "#f7f5df";
      ctx.lineWidth = Math.max(.8, a.left.scale * 3.2);
      for (let laneIndex = 0; laneIndex < 3; laneIndex++) {
        const p1 = a.lanes[laneIndex], p2 = b.lanes[laneIndex];
        ctx.beginPath();
        ctx.moveTo(p1.x, p1.y);
        ctx.lineTo(p2.x, p2.y);
        ctx.stroke();
      }
    }
    if (i % 5 === 0) {
      for (const side of [-1, 1]) {
        const p = side < 0 ? a.treeLeft : a.treeRight;
        drawTree(ctx, p.x, p.y, p.scale, palette[5], palette[4]);
      }
    }
  }

  // Stage scenery and roadside hazards are projected into the same camera space as the road.
  for (const obstacle of obstacles) {
    const ahead = (obstacle.t - car.t + Math.PI * 2) % (Math.PI * 2);
    if (ahead > .92) continue;
    const p = project(obstacle.t, obstacle.lateral);
    const size = Math.max(3, 22 * p.scale);
    ctx.fillStyle = "#1d2832";
    roundedPath(ctx, p.x - size, p.y - size * .7, size * 2, size * 1.4, size * .2);
    ctx.fill();
    ctx.strokeStyle = palette[4];
    ctx.lineWidth = Math.max(1, 3 * p.scale);
    ctx.stroke();
  }

  for (const pickup of pickups) {
    if (pickup.collected) continue;
    const ahead = (pickup.t - car.t + Math.PI * 2) % (Math.PI * 2);
    if (ahead > .92) continue;
    const p = project(pickup.t, pickup.lateral);
    const radius = Math.max(2, 12 * p.scale);
    ctx.fillStyle = "#63efff";
    ctx.beginPath();
    ctx.arc(p.x, p.y - radius, radius, 0, Math.PI * 2);
    ctx.fill();
  }

  for (const rival of rivals) {
    if (rival.destruction?.despawned) continue;
    const ahead = (rival.distance - car.t + Math.PI * 2) % (Math.PI * 2);
    if (ahead > 1.45) continue;
    const p = project(rival.distance, rival.lateral);
    drawRacingCar(ctx, p.x, p.y - 12 * p.scale, p.scale * .9, rival.color || "#dce4ec", mode === "southwest" ? -1 : 1, false);
  }

  if (particles.length) {
    ctx.save();
    ctx.globalCompositeOperation = "lighter";
    for (const particle of particles) {
      const point = projectRacePoint({ x: particle.x, y: particle.y }, cameraPoint, cameraAngle, viewport, { horizon, yaw });
      if (point.depth < -80 || point.y < horizon - 30 || point.y > height + 30) continue;
      ctx.globalAlpha = Math.max(0, Math.min(1, particle.life / particle.maxLife));
      ctx.fillStyle = particle.color;
      ctx.beginPath();
      ctx.arc(point.x, point.y, Math.max(1, particle.size * point.scale), 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
  }
  drawPlayerSideCar(ctx, width, height, carColor, car.steer || 0, car.speed || 0, mode);
  if (mode === "southeast" || mode === "southwest") {
    ctx.save();
    ctx.globalAlpha = .16;
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, height * .73, width, 2);
    ctx.restore();
  }
  ctx.restore();
}
