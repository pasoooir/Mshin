/** Instanced pedestrian sidewalks constrained to the non-buildable road right-of-way. */
export function createCitySidewalkLayer(THREE, scene, isRoadCell, gridSize, surface = null) {
  const material = new THREE.MeshStandardMaterial({
    ...(surface || {}),
    color: "#c8c4b6",
    roughness: 0.94,
    normalScale: new THREE.Vector2(0.24, 0.24)
  });
  const geometry = new THREE.BoxGeometry(1, 0.10, 1);
  const strips = [];
  for (let y = 0; y < gridSize; y++) {
    for (let x = 0; x < gridSize; x++) {
      if (!isRoadCell(x) && !isRoadCell(y)) continue;
      const px = (x - 31.5) * 2;
      const pz = (y - 31.5) * 2;
      for (const [dx, dz, sx, sz] of [[1,0,0.56,1.92],[-1,0,0.56,1.92],[0,1,1.92,0.56],[0,-1,1.92,0.56]]) {
        const nx = x + dx, ny = y + dz;
        if (nx < 0 || ny < 0 || nx >= gridSize || ny >= gridSize) continue;
        if (isRoadCell(nx) || isRoadCell(ny)) continue;
        strips.push({ x: px + dx * 0.68, z: pz + dz * 0.68, sx, sz });
      }
    }
  }
  const mesh = new THREE.InstancedMesh(geometry, material, Math.max(1, strips.length));
  const transform = new THREE.Object3D();
  strips.forEach((strip, index) => {
    transform.position.set(strip.x, 0.13, strip.z);
    transform.rotation.set(0, 0, 0);
    transform.scale.set(strip.sx, 1, strip.sz);
    transform.updateMatrix();
    mesh.setMatrixAt(index, transform.matrix);
  });
  mesh.count = strips.length;
  mesh.instanceMatrix.needsUpdate = true;
  mesh.receiveShadow = true;
  scene.add(mesh);
  return { count: strips.length, mesh };
}
