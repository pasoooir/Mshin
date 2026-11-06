/** Convert a world-space track frame to the same bounded minimap space as the circuit path. */
export function projectRaceMapPoint(frame, lateral = 0, bounds = {}) {
  const x = Number.isFinite(bounds.x) ? bounds.x : 0;
  const y = Number.isFinite(bounds.y) ? bounds.y : 0;
  const width = Math.max(1, Number(bounds.width) || 1);
  const height = Math.max(1, Number(bounds.height) || 1);
  const radiusX = Math.max(1, (Number(bounds.trackRadiusX) || 1) * 2.3);
  const radiusY = Math.max(1, (Number(bounds.trackRadiusY) || 1) * 2.3);
  const offset = Number.isFinite(lateral) ? lateral : 0;
  const worldX = frame.p.x + frame.nx * offset;
  const worldY = frame.p.y + frame.ny * offset;
  return {
    x: x + width / 2 + worldX / radiusX * width,
    y: y + height / 2 + 9 + worldY / radiusY * height
  };
}
