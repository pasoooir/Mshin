/**
 * Authoritative visual asset inventory for Mshin's requested world categories.
 * Dimensions are real-world metres (1 Three.js world unit = 1 metre).
 * This catalogue is data only: a category is not considered implemented until
 * its model is wired into placement, save validation, rendering and browser QA.
 */
export const CITY_VISUAL_ASSET_CATALOG = Object.freeze({
  house: {
    label: "خانه",
    group: "residential",
    dimensions: { width: 12, depth: 15, height: 7.5 },
    footprintTiles: { width: 2, depth: 2 },
    materials: ["plaster", "brick", "roof-tile", "wood", "glass", "stone"],
    details: ["four-sided facade", "doors", "recessed windows", "roof geometry", "gutters", "porch", "balcony", "yard"],
    referenceSearch: "real residential house exterior architecture photo PBR materials"
  },
  shop: {
    label: "مغازه",
    group: "commercial",
    dimensions: { width: 8, depth: 10, height: 5.5 },
    footprintTiles: { width: 1, depth: 2 },
    materials: ["plaster", "brick", "glass", "aluminium", "concrete"],
    details: ["full storefront glazing", "entrance door", "sign fascia", "awning", "interior depth", "side and rear facade"],
    referenceSearch: "real small street retail shop facade storefront"
  },
  tower: {
    label: "برج",
    group: "residential-commercial",
    dimensions: { width: 28, depth: 28, height: 90 },
    footprintTiles: { width: 4, depth: 4 },
    materials: ["curtain-wall-glass", "aluminium", "concrete", "steel"],
    details: ["repeated floor slabs", "balconies", "window grid", "roof plant", "core", "podium", "entrance canopy"],
    referenceSearch: "real high rise residential tower architecture facade"
  },
  hardware_store: {
    label: "فروشگاه ابزارآلات",
    group: "commercial",
    dimensions: { width: 22, depth: 18, height: 8 },
    footprintTiles: { width: 3, depth: 3 },
    materials: ["metal-cladding", "concrete", "glass", "painted-steel"],
    details: ["large retail frontage", "loading door", "tool signage", "display windows", "loading bay", "parking apron"],
    referenceSearch: "real hardware store exterior warehouse retail architecture"
  },
  school: {
    label: "مدرسه",
    group: "education",
    dimensions: { width: 42, depth: 30, height: 12 },
    footprintTiles: { width: 6, depth: 4 },
    materials: ["brick", "render", "concrete", "glass", "painted-metal"],
    details: ["multiple wings", "classroom window rhythm", "main entrance", "stairs", "courtyard", "playground", "sports court"],
    referenceSearch: "real school campus exterior architecture courtyard"
  },
  cafe_restaurant: {
    label: "کافه و رستوران",
    group: "commercial-hospitality",
    dimensions: { width: 18, depth: 16, height: 7 },
    footprintTiles: { width: 3, depth: 2 },
    materials: ["brick", "timber", "glass", "stone", "metal"],
    details: ["glazed dining facade", "kitchen/service access", "signage", "terrace", "canopy", "outdoor seating"],
    referenceSearch: "real cafe restaurant exterior architecture outdoor terrace"
  },
  mosque: {
    label: "مسجد",
    group: "religious-cultural",
    dimensions: { width: 32, depth: 38, height: 22 },
    footprintTiles: { width: 5, depth: 5 },
    materials: ["stone", "brick", "glazed-tile", "plaster", "copper", "glass"],
    details: ["dome", "minaret", "prayer hall", "entrance portal", "mihrab massing", "courtyard", "arcades", "tilework"],
    referenceSearch: "real mosque architecture exterior dome minaret courtyard"
  },
  supermarket: {
    label: "فروشگاه بزرگ",
    group: "commercial",
    dimensions: { width: 38, depth: 28, height: 9 },
    footprintTiles: { width: 5, depth: 4 },
    materials: ["concrete", "metal-cladding", "glass", "asphalt"],
    details: ["wide glazed entrance", "loading dock", "large sign", "parking", "roof plant", "service yard"],
    referenceSearch: "real supermarket big box retail exterior architecture"
  },
  factory: {
    label: "کارخانه",
    group: "industrial",
    dimensions: { width: 60, depth: 42, height: 16 },
    footprintTiles: { width: 8, depth: 6 },
    materials: ["concrete", "corrugated-metal", "steel", "glass"],
    details: ["industrial bays", "loading docks", "roof vents", "chimneys", "service yard", "pipework"],
    referenceSearch: "real industrial factory exterior building architecture"
  },
  office: {
    label: "ساختمان اداری",
    group: "commercial",
    dimensions: { width: 24, depth: 20, height: 32 },
    footprintTiles: { width: 4, depth: 3 },
    materials: ["glass", "aluminium", "concrete", "stone"],
    details: ["floor bands", "curtain wall", "lobby", "canopy", "roof plant", "side and rear facade"],
    referenceSearch: "real mid rise office building exterior architecture"
  }
});

export const CITY_WORLD_ASSET_CATEGORIES = Object.freeze([
  "sky-and-atmosphere", "sun-moon-stars", "clouds", "mountains-and-horizon",
  "terrain-and-soil", "grass-and-ground-cover", "trees-and-plants", "water",
  "roads-and-markings", "sidewalks-and-curbs", "street-lights-and-signage",
  "vehicles-and-traffic", "pedestrians-and-animals", "street-furniture",
  "parks-and-playgrounds", "bridges-and-infrastructure"
]);

export function getCityAssetDefinition(category) {
  return CITY_VISUAL_ASSET_CATALOG[category] || null;
}
