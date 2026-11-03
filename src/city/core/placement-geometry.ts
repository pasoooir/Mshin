export interface CityPlacementVector3 {
  x: number;
  y: number;
  z: number;
}

export interface CityPlacementRay {
  origin: CityPlacementVector3;
  direction: CityPlacementVector3;
}

/** Returns the finite forward ray intersection with a horizontal ground plane. */
export function intersectCityPlacementGround(
  ray: CityPlacementRay,
  groundHeight: number,
  maxDistance: number
): CityPlacementVector3 | null {
  const { origin, direction } = ray;
  if (![origin.x, origin.y, origin.z, direction.x, direction.y, direction.z, groundHeight, maxDistance].every(Number.isFinite)) {
    return null;
  }
  if (Math.abs(direction.y) < 0.0001 || maxDistance < 0) return null;
  const distance = (groundHeight - origin.y) / direction.y;
  if (!Number.isFinite(distance) || distance < 0 || distance > maxDistance) return null;
  const point = {
    x: origin.x + direction.x * distance,
    y: groundHeight,
    z: origin.z + direction.z * distance
  };
  return [point.x, point.y, point.z].every(Number.isFinite) ? point : null;
}

/** Snaps X/Z to a grid while preserving the requested ground height. */
export function snapCityPlacementPoint(
  point: CityPlacementVector3,
  gridSize: number
): CityPlacementVector3 | null {
  if (![point.x, point.y, point.z, gridSize].every(Number.isFinite)) return null;
  const spacing = Math.max(0, gridSize);
  if (spacing === 0) return { x: point.x, y: point.y, z: point.z };
  return {
    x: Math.round(point.x / spacing) * spacing,
    y: point.y,
    z: Math.round(point.z / spacing) * spacing
  };
}
