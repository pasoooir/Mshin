/**
 * Add reusable, camera-orbit-safe facade and rooftop details to a city building.
 * Geometry is kept low-poly and local to the building group for mobile rendering.
 */
export function addOrbitReadyBuildingDetails(THREE, {
  group, type, height, bodyWidth, bodyDepth, trimMat, accentMat, glassMat, windowGeometry
}) {
  const addMesh = (geometry, material, x, y, z, rotationY = 0, castShadow = true) => {
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(x, y, z);
    mesh.rotation.y = rotationY;
    mesh.castShadow = castShadow;
    mesh.receiveShadow = true;
    group.add(mesh);
    return mesh;
  };

  const windows = new THREE.InstancedMesh(windowGeometry, glassMat, 64);
  const dummy = new THREE.Object3D();
  let windowCount = 0;
  const floors = Math.min(5, Math.max(1, Math.floor(height / 0.62)));
  const columns = bodyWidth > 1.4 ? [-0.42, 0, 0.42] : [-0.34, 0.34];
  for (let floor = 0; floor < floors; floor++) {
    const y = 0.70 + floor * 0.55;
    for (const wx of columns) {
      for (const side of [-1, 1]) {
        dummy.position.set(wx, y, side * (bodyDepth / 2 + 0.035));
        dummy.rotation.set(0, side < 0 ? Math.PI : 0, 0);
        dummy.scale.set(1, 1, 1);
        dummy.updateMatrix();
        windows.setMatrixAt(windowCount++, dummy.matrix);
      }
      for (const side of [-1, 1]) {
        dummy.position.set(side * (bodyWidth / 2 + 0.035), y, wx);
        dummy.rotation.set(0, side > 0 ? Math.PI / 2 : -Math.PI / 2, 0);
        dummy.scale.set(1, 1, 1);
        dummy.updateMatrix();
        windows.setMatrixAt(windowCount++, dummy.matrix);
      }
    }
  }
  windows.count = windowCount;
  windows.instanceMatrix.needsUpdate = true;
  group.add(windows);

  addMesh(new THREE.BoxGeometry(bodyWidth + 0.22, 0.10, bodyDepth + 0.22), trimMat, 0, 0.39 + height, 0, 0, false);
  for (const side of [-1, 1]) {
    addMesh(new THREE.BoxGeometry(bodyWidth + 0.08, 0.07, 0.045), accentMat, 0, 0.52, side * (bodyDepth / 2 + 0.055), 0, false);
    addMesh(new THREE.BoxGeometry(0.045, height * 0.84, 0.07), trimMat, side * (bodyWidth / 2 + 0.018), 0.34 + height * 0.5, bodyDepth / 2 + 0.055, 0, false);
  }

  if (type === "home") {
    addMesh(new THREE.BoxGeometry(0.18, 0.52, 0.18), trimMat, 0.42, height + 0.72, -0.28);
    addMesh(new THREE.BoxGeometry(0.24, 0.08, 0.24), accentMat, 0.42, height + 1.0, -0.28, 0, false);
    // A compact instanced balcony on every facade keeps the house readable
    // through a full camera orbit instead of decorating only the front face.
    const balconyFloors = Math.min(3, Math.max(1, Math.floor(height / 0.8)));
    const balconyPlatformGeometry = new THREE.BoxGeometry(0.58, 0.07, 0.42);
    const balconyRailGeometry = new THREE.BoxGeometry(0.58, 0.06, 0.055);
    const balconyPlatforms = new THREE.InstancedMesh(balconyPlatformGeometry, trimMat, balconyFloors * 4);
    const balconyRails = new THREE.InstancedMesh(balconyRailGeometry, accentMat, balconyFloors * 4);
    let balconyIndex = 0;
    for (let floor = 0; floor < balconyFloors; floor++) {
      const y = 1.02 + floor * 0.72;
      for (const face of [
        { x: 0, z: bodyDepth / 2 + 0.16, rotation: 0, railX: 0, railZ: bodyDepth / 2 + 0.38 },
        { x: 0, z: -bodyDepth / 2 - 0.16, rotation: 0, railX: 0, railZ: -bodyDepth / 2 - 0.38 },
        { x: bodyWidth / 2 + 0.16, z: 0, rotation: Math.PI / 2, railX: bodyWidth / 2 + 0.38, railZ: 0 },
        { x: -bodyWidth / 2 - 0.16, z: 0, rotation: Math.PI / 2, railX: -bodyWidth / 2 - 0.38, railZ: 0 }
      ]) {
        dummy.position.set(face.x, y, face.z);
        dummy.rotation.set(0, face.rotation, 0);
        dummy.scale.set(1, 1, 1);
        dummy.updateMatrix();
        balconyPlatforms.setMatrixAt(balconyIndex, dummy.matrix);
        dummy.position.set(face.railX, y + 0.10, face.railZ);
        dummy.updateMatrix();
        balconyRails.setMatrixAt(balconyIndex, dummy.matrix);
        balconyIndex++;
      }
    }
    balconyPlatforms.count = balconyIndex;
    balconyRails.count = balconyIndex;
    balconyPlatforms.instanceMatrix.needsUpdate = true;
    balconyRails.instanceMatrix.needsUpdate = true;
    balconyPlatforms.castShadow = false;
    balconyRails.castShadow = false;
    group.add(balconyPlatforms, balconyRails);
  } else if (type === "shop") {
    for (const side of [-1, 1]) {
      addMesh(new THREE.BoxGeometry(0.055, 0.82, bodyDepth * 0.56), glassMat, side * (bodyWidth / 2 + 0.036), 0.86, 0, 0, false);
      addMesh(new THREE.BoxGeometry(0.08, 0.24, 0.08), accentMat, side * (bodyWidth / 2 + 0.10), 1.55, 0, 0, false);
    }
  } else if (["power", "water", "sewage", "waste", "police", "fire", "health", "education"].includes(type)) {
    const serviceColors = {
      power: "#e8c65f", water: "#68b9dc", sewage: "#9aab91", waste: "#b9b56d",
      police: "#6d8ed1", fire: "#d96e58", health: "#e78c9c", education: "#9a85c9"
    };
    const serviceColor = new THREE.MeshStandardMaterial({ color: serviceColors[type], roughness: 0.72, metalness: 0.04 });
    addMesh(new THREE.BoxGeometry(0.62, 0.42, 0.10), serviceColor, 0, height + 0.34, bodyDepth / 2 + 0.08, 0, false);
    const roofY = height + 0.43;
    if (type === "police") {
      // Blue beacon and a compact radio mast give the station a readable skyline.
      addMesh(new THREE.CylinderGeometry(0.10, 0.13, 0.16, 10), serviceColor, 0, roofY + 0.10, 0);
      addMesh(new THREE.SphereGeometry(0.12, 10, 7), new THREE.MeshStandardMaterial({
        color: "#eaf7ff", emissive: "#4d9fff", emissiveIntensity: 0.8, roughness: 0.25
      }), 0, roofY + 0.25, 0);
      addMesh(new THREE.CylinderGeometry(0.025, 0.035, 0.82, 6), trimMat, 0.48, roofY + 0.42, -0.38);
      addMesh(new THREE.BoxGeometry(0.42, 0.045, 0.045), trimMat, 0.48, roofY + 0.78, -0.38);
    } else if (type === "fire") {
      // Tall hose-drying tower with a crossbar, distinct from a generic roof mast.
      addMesh(new THREE.BoxGeometry(0.34, 1.08, 0.34), serviceColor, 0.48, roofY + 0.48, -0.36);
      addMesh(new THREE.BoxGeometry(0.44, 0.10, 0.42), accentMat, 0.48, roofY + 1.06, -0.36);
      addMesh(new THREE.CylinderGeometry(0.055, 0.055, 0.72, 8), trimMat, 0.48, roofY + 1.40, -0.36);
    } else if (type === "health") {
      // Medical cross on a raised, softly rounded sign.
      addMesh(new THREE.BoxGeometry(0.18, 0.78, 0.18), trimMat, 0, roofY + 0.38, 0, 0, false);
      addMesh(new THREE.BoxGeometry(0.78, 0.18, 0.18), trimMat, 0, roofY + 0.38, 0, 0, false);
      addMesh(new THREE.BoxGeometry(0.46, 0.08, 0.46), serviceColor, 0, roofY + 0.02, 0, 0, false);
    } else if (type === "education") {
      // School clock and flag pole replace the generic civic cross.
      addMesh(new THREE.CylinderGeometry(0.28, 0.28, 0.12, 16), serviceColor, 0, roofY + 0.20, 0);
      addMesh(new THREE.BoxGeometry(0.035, 0.20, 0.025), trimMat, 0, roofY + 0.31, 0.07, 0, false);
      addMesh(new THREE.CylinderGeometry(0.025, 0.035, 0.92, 6), trimMat, 0.48, roofY + 0.48, -0.38);
      addMesh(new THREE.BoxGeometry(0.34, 0.20, 0.035), accentMat, 0.63, roofY + 0.78, -0.38, 0, false);
    } else if (type === "power") {
      // Two transformer insulators and a compact distribution frame.
      for (const x of [-0.34, 0.34]) {
        addMesh(new THREE.CylinderGeometry(0.075, 0.10, 0.38, 8), serviceColor, x, roofY + 0.20, 0);
        addMesh(new THREE.CylinderGeometry(0.12, 0.12, 0.07, 8), trimMat, x, roofY + 0.42, 0);
      }
      addMesh(new THREE.BoxGeometry(0.92, 0.07, 0.10), trimMat, 0, roofY + 0.50, 0, 0, false);
    } else if (type === "water") {
      // Elevated cylindrical reservoir and visible supply pipe.
      addMesh(new THREE.CylinderGeometry(0.34, 0.34, 0.58, 12), serviceColor, 0, roofY + 0.30, 0);
      addMesh(new THREE.SphereGeometry(0.34, 12, 7, 0, Math.PI * 2, 0, Math.PI / 2), trimMat, 0, roofY + 0.59, 0);
      addMesh(new THREE.CylinderGeometry(0.055, 0.055, 0.62, 8), accentMat, 0.42, roofY + 0.18, 0.34);
    } else if (type === "sewage") {
      // Paired treatment vents and a horizontal pipe identify wastewater treatment.
      for (const x of [-0.32, 0.32]) {
        addMesh(new THREE.CylinderGeometry(0.11, 0.13, 0.52, 10), serviceColor, x, roofY + 0.25, 0);
        addMesh(new THREE.TorusGeometry(0.11, 0.035, 6, 12), trimMat, x, roofY + 0.52, 0);
      }
      addMesh(new THREE.CylinderGeometry(0.07, 0.07, 0.84, 8), accentMat, 0, roofY + 0.14, 0.34, Math.PI / 2);
    } else if (type === "waste") {
      // Three colored collection hoppers and a small compactor block.
      for (const x of [-0.34, 0, 0.34]) {
        addMesh(new THREE.BoxGeometry(0.22, 0.30, 0.24), serviceColor, x, roofY + 0.15, 0);
        addMesh(new THREE.BoxGeometry(0.24, 0.055, 0.26), trimMat, x, roofY + 0.33, 0, 0, false);
      }
      addMesh(new THREE.BoxGeometry(0.40, 0.30, 0.32), accentMat, 0, roofY + 0.15, 0.42);
    }
  }
}
