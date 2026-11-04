/** Distant, non-interactive urban skyline that gives the playable district a real city context. */
export function createCityBackgroundSkyline(THREE, scene, concreteSurface, brickSurface, windowMaterials) {
  const group = new THREE.Group();
  group.name = "mshin-background-city-skyline";
  const unitGeometry = new THREE.BoxGeometry(1, 1, 1);
  const concreteMaterial = new THREE.MeshStandardMaterial({ ...concreteSurface, color: "#c2c0b7", roughness: 0.9 });
  const masonryMaterial = new THREE.MeshStandardMaterial({ ...brickSurface, color: "#a98c78", roughness: 0.92 });
  const glassMaterial = new THREE.MeshStandardMaterial({
    color: "#8ba4ad", emissive: "#385c70", emissiveIntensity: 0.18,
    roughness: 0.28, metalness: 0.12
  });
  windowMaterials.add(glassMaterial);
  const concreteBlocks = new THREE.InstancedMesh(unitGeometry, concreteMaterial, 48);
  const masonryBlocks = new THREE.InstancedMesh(unitGeometry, masonryMaterial, 48);
  const roofUnits = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), concreteMaterial, 48);
  const windows = new THREE.InstancedMesh(new THREE.BoxGeometry(0.56, 0.72, 0.055), glassMaterial, 9000);
  for (const mesh of [concreteBlocks, masonryBlocks, roofUnits, windows]) {
    mesh.castShadow = false;
    mesh.receiveShadow = true;
  }
  const dummy = new THREE.Object3D();
  let concreteCount = 0, masonryCount = 0, roofUnitCount = 0, windowCount = 0;
  let seed = 20261104;
  const random = () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed / 4294967296;
  };
  const positions = [];
  for (let index = 0; index < 18; index++) {
    const along = -112 + index * 13.2;
    positions.push([along, -88], [along, 88], [-88, along], [88, along]);
  }
  for (let index = 0; index < positions.length; index++) {
    const [x, z] = positions[index];
    const width = 5.2 + random() * 3.4;
    const depth = 5.0 + random() * 3.8;
    const floors = 5 + Math.floor(random() * 9);
    const height = floors * (2.0 + random() * 0.24);
    const isMasonry = index % 3 === 0;
    const target = isMasonry ? masonryBlocks : concreteBlocks;
    const instance = isMasonry ? masonryCount++ : concreteCount++;
    dummy.position.set(x, height / 2, z);
    dummy.rotation.set(0, 0, 0);
    dummy.scale.set(width, height, depth);
    dummy.updateMatrix();
    target.setMatrixAt(instance, dummy.matrix);
    if (target.setColorAt) {
      const tint = 0.88 + random() * 0.20;
      target.setColorAt(instance, new THREE.Color(tint, tint * (0.99 + random() * 0.02), tint * (0.96 + random() * 0.04)));
    }
    if (index % 3 === 1 || index % 4 === 0) {
      dummy.position.set(x + width * 0.08, height + 0.55, z - depth * 0.06);
      dummy.scale.set(width * 0.42, 1.1, depth * 0.42);
      dummy.updateMatrix();
      roofUnits.setMatrixAt(roofUnitCount++, dummy.matrix);
    }
    const floorSpacing = height / floors;
    const columnsX = Math.max(2, Math.floor(width / 1.35));
    const columnsZ = Math.max(2, Math.floor(depth / 1.35));
    for (let floor = 1; floor < floors; floor++) {
      const y = floor * floorSpacing + 0.45;
      for (let column = 0; column < columnsX; column++) {
        const px = x - width / 2 + (column + 0.5) * width / columnsX;
        for (const side of [-1, 1]) {
          dummy.position.set(px, y, z + side * (depth / 2 + 0.035));
          dummy.rotation.set(0, side < 0 ? Math.PI : 0, 0);
          dummy.scale.set(1, 1, 1);
          dummy.updateMatrix();
          windows.setMatrixAt(windowCount++, dummy.matrix);
        }
      }
      for (let column = 0; column < columnsZ; column++) {
        const pz = z - depth / 2 + (column + 0.5) * depth / columnsZ;
        for (const side of [-1, 1]) {
          dummy.position.set(x + side * (width / 2 + 0.035), y, pz);
          dummy.rotation.set(0, side > 0 ? Math.PI / 2 : -Math.PI / 2, 0);
          dummy.scale.set(1, 1, 1);
          dummy.updateMatrix();
          windows.setMatrixAt(windowCount++, dummy.matrix);
        }
      }
    }
  }
  concreteBlocks.count = concreteCount;
  masonryBlocks.count = masonryCount;
  roofUnits.count = roofUnitCount;
  windows.count = windowCount;
  for (const mesh of [concreteBlocks, masonryBlocks, roofUnits, windows]) mesh.instanceMatrix.needsUpdate = true;
  group.add(concreteBlocks, masonryBlocks, roofUnits, windows);
  scene.add(group);
  return {
    group,
    buildingCount: concreteCount + masonryCount,
    windowCount,
    dispose() {
      scene.remove(group);
      unitGeometry.dispose();
      roofUnits.geometry.dispose();
      windows.geometry.dispose();
      concreteMaterial.dispose();
      masonryMaterial.dispose();
      glassMaterial.dispose();
      windowMaterials.delete(glassMaterial);
    }
  };
}
