/** Mobile-budget street lighting, anchored to the existing non-buildable sidewalk strips. */
export function createCityStreetLighting(THREE, scene, isRoadCell, gridSize) {
  const poleMaterial = new THREE.MeshStandardMaterial({ color: "#39434a", roughness: 0.72, metalness: 0.62 });
  const lampMaterial = new THREE.MeshStandardMaterial({
    color: "#ffe6a8", emissive: "#ffd27a", emissiveIntensity: 0.72,
    roughness: 0.38, metalness: 0.12
  });
  const poleGeometry = new THREE.CylinderGeometry(0.055, 0.075, 1.62, 6);
  const lampGeometry = new THREE.BoxGeometry(0.34, 0.12, 0.18);
  const positions = [];
  const isRoad = (x, y) => isRoadCell(x) || isRoadCell(y);
  const world = value => (value - 31.5) * 2;

  // Place one pair of lamps per road segment, never at junctions or on parcels.
  for (let y = 0; y < gridSize; y++) {
    for (let x = 0; x < gridSize; x++) {
      const verticalRoad = isRoadCell(x) && !isRoadCell(y);
      const horizontalRoad = isRoadCell(y) && !isRoadCell(x);
      if (verticalRoad && y % 8 === 3) {
        for (const dx of [-1, 1]) {
          const nx = x + dx;
          if (nx < 0 || nx >= gridSize || isRoad(nx, y)) continue;
          positions.push({ x: world(x) + dx * 0.68, z: world(y), rotation: dx < 0 ? 0 : Math.PI });
        }
      } else if (horizontalRoad && x % 8 === 3) {
        for (const dz of [-1, 1]) {
          const ny = y + dz;
          if (ny < 0 || ny >= gridSize || isRoad(x, ny)) continue;
          positions.push({ x: world(x), z: world(y) + dz * 0.68, rotation: dz < 0 ? Math.PI / 2 : -Math.PI / 2 });
        }
      }
    }
  }

  const capacity = Math.max(1, positions.length);
  const poles = new THREE.InstancedMesh(poleGeometry, poleMaterial, capacity);
  const lamps = new THREE.InstancedMesh(lampGeometry, lampMaterial, capacity);
  const dummy = new THREE.Object3D();
  positions.forEach((point, index) => {
    dummy.position.set(point.x, 0.94, point.z);
    dummy.rotation.set(0, point.rotation, 0);
    dummy.scale.set(1, 1, 1);
    dummy.updateMatrix();
    poles.setMatrixAt(index, dummy.matrix);

    dummy.position.set(point.x, 1.78, point.z);
    dummy.rotation.set(0, point.rotation, 0);
    dummy.updateMatrix();
    lamps.setMatrixAt(index, dummy.matrix);
  });
  for (const mesh of [poles, lamps]) {
    mesh.count = positions.length;
    mesh.instanceMatrix.needsUpdate = true;
    mesh.castShadow = false;
    mesh.receiveShadow = false;
    scene.add(mesh);
  }
  return { count: positions.length, drawCalls: positions.length ? 2 : 0, poles, lamps };
}
