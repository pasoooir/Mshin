/**
 * Merge static building meshes across the whole city into material-compatible
 * geometry batches. This reduces scene submissions without dropping façade,
 * roof, trim, or rooftop detail. Dynamic/instanced objects are left untouched.
 */
export function batchCityStaticGeometry(THREE, root, options = {}) {
  const minimumMeshes = Math.max(2, options.minimumMeshes || 2);
  root.updateMatrixWorld(true);
  const inverseRoot = new THREE.Matrix4().copy(root.matrixWorld).invert();
  const buckets = new Map();
  const untouched = [];
  let sourceMeshes = 0;

  const materialKey = (material, geometry) => {
    const color = material.color?.getHexString?.() || "";
    const emissive = material.emissive?.getHexString?.() || "";
    const map = material.map?.uuid || "";
    const normal = material.normalMap?.uuid || "";
    const roughnessMap = material.roughnessMap?.uuid || "";
    return [
      material.type, color, emissive, material.roughness ?? "", material.metalness ?? "",
      material.opacity ?? "", material.transparent ? 1 : 0, material.side ?? "",
      material.vertexColors ? 1 : 0, geometry.getAttribute("normal") ? 1 : 0, geometry.getAttribute("uv") ? 1 : 0, map, normal, roughnessMap,
      material.emissiveIntensity ?? "", material.wireframe ? 1 : 0
    ].join("|");
  };

  root.traverse(object => {
    if (!object.isMesh || object.isInstancedMesh || !object.geometry || Array.isArray(object.material)) return;
    const material = object.material;
    if (!material || !object.geometry.getAttribute("position")) return;
    const key = materialKey(material, object.geometry);
    if (!buckets.has(key)) buckets.set(key, { material, entries: [] });
    buckets.get(key).entries.push(object);
    sourceMeshes++;
  });

  const batches = [];
  for (const { material, entries } of buckets.values()) {
    if (entries.length < minimumMeshes) {
      untouched.push(...entries);
      continue;
    }
    const positions = [], normals = [], uvs = [], indices = [];
    let vertexOffset = 0;
    for (const mesh of entries) {
      const geometry = mesh.geometry;
      const position = geometry.getAttribute("position");
      const normal = geometry.getAttribute("normal");
      const uv = geometry.getAttribute("uv");
      const relative = new THREE.Matrix4().multiplyMatrices(inverseRoot, mesh.matrixWorld);
      const normalMatrix = new THREE.Matrix3().getNormalMatrix(relative);
      const p = new THREE.Vector3();
      const n = new THREE.Vector3();
      for (let i = 0; i < position.count; i++) {
        p.fromBufferAttribute(position, i).applyMatrix4(relative);
        positions.push(p.x, p.y, p.z);
        if (normal) {
          n.fromBufferAttribute(normal, i).applyMatrix3(normalMatrix).normalize();
          normals.push(n.x, n.y, n.z);
        }
        if (uv) uvs.push(uv.getX(i), uv.getY(i));
      }
      const index = geometry.getIndex();
      if (index) {
        for (let i = 0; i < index.count; i++) indices.push(index.getX(i) + vertexOffset);
      } else {
        for (let i = 0; i < position.count; i++) indices.push(i + vertexOffset);
      }
      vertexOffset += position.count;
    }
    const merged = new THREE.BufferGeometry();
    merged.setAttribute("position", new THREE.Float32BufferAttribute(positions, 3));
    if (normals.length) merged.setAttribute("normal", new THREE.Float32BufferAttribute(normals, 3));
    if (uvs.length) merged.setAttribute("uv", new THREE.Float32BufferAttribute(uvs, 2));
    merged.setIndex(indices);
    merged.computeBoundingSphere();
    const batch = new THREE.Mesh(merged, material.clone());
    batch.name = "city-global-static-batch";
    batch.castShadow = entries.some(mesh => mesh.castShadow);
    batch.receiveShadow = entries.some(mesh => mesh.receiveShadow);
    batch.userData.sourceMeshCount = entries.length;
    batches.push(batch);
  }

  // Preserve non-mesh objects and the small groups that are not worth merging.
  const retained = new Set(untouched);
  const remove = [];
  root.traverse(object => {
    if (object !== root && object.isMesh && !retained.has(object)) remove.push(object);
  });
  for (const object of remove) object.parent?.remove(object);
  for (const batch of batches) root.add(batch);

  return {
    sourceMeshes,
    batchedMeshes: batches.reduce((sum, batch) => sum + batch.userData.sourceMeshCount, 0),
    drawCallBatches: batches.length,
    remainingMeshes: untouched.length,
    batches
  };
}
