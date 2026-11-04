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
    for (const side of [-1, 1]) {
      addMesh(new THREE.BoxGeometry(0.62, 0.045, 0.055), trimMat, 0, 1.08, side * (bodyDepth / 2 + 0.13), 0, false);
    }
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
    if (type === "fire") {
      const mast = addMesh(new THREE.CylinderGeometry(0.075, 0.09, 0.92, 8), accentMat, 0.48, height + 0.54, -0.42);
      mast.rotation.z = 0.08;
    } else if (["health", "education", "police"].includes(type)) {
      addMesh(new THREE.BoxGeometry(0.12, 0.64, 0.12), trimMat, 0, height + 0.55, 0, 0, false);
      addMesh(new THREE.BoxGeometry(0.64, 0.12, 0.12), trimMat, 0, height + 0.55, 0, 0, false);
    } else {
      const equipment = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.24, 0.42, 10), serviceColor);
      equipment.position.set(0, height + 0.36, 0);
      equipment.castShadow = true;
      group.add(equipment);
    }
  }
}
