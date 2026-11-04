/**
 * Authoritative city-space dimensions. Every Three.js world unit represents one metre.
 * A simulation tile is an 8 m urban parcel/road segment; building footprints are
 * authored against this physical spacing rather than rendered as 2 m toy blocks.
 */
export const WORLD_UNIT_METERS = 1;
export const CITY_TILE_METERS = 8;
export const CITY_GRID_SIZE = 32;
export const VISUAL_GRID_SIZE = CITY_GRID_SIZE * 2;
export const CITY_WORLD_EXTENT_METERS = CITY_GRID_SIZE * CITY_TILE_METERS;

export const cityTileToWorld = coordinate =>
  (Number(coordinate) - (CITY_GRID_SIZE - 1) / 2) * CITY_TILE_METERS;

export const worldToCityTile = coordinate =>
  Math.floor(Number(coordinate) / CITY_TILE_METERS + CITY_GRID_SIZE / 2 - 0.5);

export function getBuildingVisualScale(type) {
  // Geometry is authored in a compact local architectural kit. Scale it into
  // metre-sized buildings while preserving human-scale doors and floor heights.
  const horizontal = type === "industrial" ? 4.8 : 4.8;
  const vertical = 2.2;
  return { x: horizontal, y: vertical, z: horizontal };
}
