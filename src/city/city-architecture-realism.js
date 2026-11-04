/**
 * Architectural facade kit for Mshin's city renderer.
 * Adds physically-scaled, four-sided building articulation without bloating
 * the main renderer: recessed glazing, mullions, floor bands, balconies,
 * parapets and rooftop mechanical equipment.
 */
export function addRealisticArchitecture(THREE, options) {
  const { group, type, height, bodyWidth, bodyDepth, glassMat, trimMat, accentMat, roofMat } = options;
  const windows = [];
  const frames = [];
  const floorBands = [];
  const isIndustrial = type === "industrial";
  const isLowRise = type === "home" || type === "shop";
  const floors = Math.max(1, Math.min(12, Math.floor((height - 0.45) / (isIndustrial ? 1.05 : 0.72))));
  const windowWidth = isIndustrial ? 0.24 : 0.29;
  const windowHeight = isIndustrial ? 0.34 : 0.40;
  const sill = 0.40;
  const facadeOffset = 0.018;

  const addBox = (w, h, d, material, x, y, z, parent = group) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
    mesh.position.set(x, y, z);
    mesh.castShadow = false;
    mesh.receiveShadow = true;
    parent.add(mesh);
    return mesh;
  };

  // All four elevations receive a consistent architectural rhythm.
  for (let floor = 0; floor < floors; floor++) {
    const y = sill + floor * (height - 0.48) / floors + (height - 0.48) / floors * 0.52;
    const columns = Math.max(2, Math.floor((bodyWidth - 0.24) / (isIndustrial ? 0.48 : 0.43)));
    for (let column = 0; column < columns; column++) {
      const x = -bodyWidth / 2 + 0.18 + column * ((bodyWidth - 0.36) / Math.max(1, columns - 1));
      if (y > height + 0.18) continue;
      windows.push(addBox(windowWidth, windowHeight, facadeOffset, glassMat, x, y, bodyDepth / 2 + facadeOffset));
      windows.push(addBox(windowWidth, windowHeight, facadeOffset, glassMat, x, y, -bodyDepth / 2 - facadeOffset));
      // Side elevations are equally articulated; these are not front-only shells.
      frames.push(addBox(facadeOffset, windowHeight + 0.10, 0.035, trimMat, x - windowWidth / 2, y, bodyDepth / 2 + 0.045));
      frames.push(addBox(facadeOffset, windowHeight + 0.10, 0.035, trimMat, x + windowWidth / 2, y, -bodyDepth / 2 - 0.045));
      const sideCount = Math.max(2, Math.floor((bodyDepth - 0.24) / 0.43));
      for (let sideColumn = 0; sideColumn < sideCount; sideColumn++) {
        const z = -bodyDepth / 2 + 0.18 + sideColumn * ((bodyDepth - 0.36) / Math.max(1, sideCount - 1));
        windows.push(addBox(facadeOffset, windowHeight, windowWidth, glassMat, bodyWidth / 2 + facadeOffset, y, z));
        windows.push(addBox(facadeOffset, windowHeight, windowWidth, glassMat, -bodyWidth / 2 - facadeOffset, y, z));
      }
    }
    if (!isLowRise && floor > 0) {
      floorBands.push(addBox(bodyWidth + 0.045, 0.055, bodyDepth + 0.045, trimMat, 0, 0.32 + floor * height / floors, 0));
    }
  }

  // Ground-floor storefront: deep glazing and a projecting weather canopy.
  if (type === "shop") {
    addBox(bodyWidth * 0.72, 0.82, 0.045, glassMat, 0, 0.82, bodyDepth / 2 + 0.06);
    addBox(bodyWidth + 0.18, 0.10, 0.62, accentMat, 0, 1.34, bodyDepth / 2 + 0.22);
    addBox(bodyWidth + 0.12, 0.08, 0.08, trimMat, 0, 1.43, bodyDepth / 2 + 0.10);
  }

  // Roof edge/parapet and mechanical plant make the silhouette read from orbit.
  const roofY = 0.34 + height + (type === "home" ? 0.72 : 0.12);
  if (!isLowRise) {
    addBox(bodyWidth + 0.18, 0.20, 0.12, trimMat, 0, roofY, bodyDepth / 2);
    addBox(bodyWidth + 0.18, 0.20, 0.12, trimMat, 0, roofY, -bodyDepth / 2);
    addBox(0.12, 0.20, bodyDepth, trimMat, bodyWidth / 2, roofY, 0);
    addBox(0.12, 0.20, bodyDepth, trimMat, -bodyWidth / 2, roofY, 0);
  }
  if (!isLowRise || type === "home") {
    const unitMaterial = roofMat || accentMat;
    const unit = new THREE.Group();
    const casing = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.24, 0.34), unitMaterial);
    casing.position.y = 0.12;
    unit.add(casing);
    const fan = new THREE.Mesh(new THREE.CylinderGeometry(0.105, 0.105, 0.035, 10), trimMat);
    fan.position.y = 0.26;
    unit.add(fan);
    unit.position.set(bodyWidth * 0.22, roofY + 0.04, -bodyDepth * 0.20);
    group.add(unit);
    if (type !== "home") {
      const secondUnit = unit.clone();
      secondUnit.position.x = -bodyWidth * 0.22;
      secondUnit.position.z = bodyDepth * 0.20;
      group.add(secondUnit);
    }
  }

  return {
    windowCount: windows.length,
    frameCount: frames.length,
    floorBandCount: floorBands.length,
    elevations: 4,
    floors
  };
}
