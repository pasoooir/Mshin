/**
 * Batched four-elevation architecture details.
 * Reuses a small set of geometries and InstancedMesh batches so facade detail
 * does not multiply draw calls on mobile GPUs.
 */
export function addRealisticArchitecture(THREE, options) {
  const { group, type, height, bodyWidth, bodyDepth, glassMat, trimMat, accentMat, roofMat } = options;
  const isIndustrial = type === "industrial";
  const isLowRise = type === "home" || type === "shop";
  const floors = Math.max(1, Math.min(12, Math.floor((height - 0.45) / (isIndustrial ? 1.05 : 0.72))));
  const windowWidth = isIndustrial ? 0.24 : 0.29;
  const windowHeight = isIndustrial ? 0.34 : 0.40;
  const facadeOffset = 0.018;
  const batches = new Map();
  const addInstance = (key, geometry, material, x, y, z) => {
    if (!batches.has(key)) batches.set(key, { geometry, material, positions: [] });
    batches.get(key).positions.push([x, y, z]);
  };
  const addBox = (w, h, d, material, x, y, z, key) => {
    const id = key || [w,h,d,material === glassMat ? "glass" : material === trimMat ? "trim" : "accent"].join(":");
    addInstance(id, new THREE.BoxGeometry(w,h,d), material, x,y,z);
  };

  for (let floor = 0; floor < floors; floor++) {
    const y = 0.40 + floor * (height - 0.48) / floors + (height - 0.48) / floors * 0.52;
    const columns = Math.max(2, Math.floor((bodyWidth - 0.24) / (isIndustrial ? 0.48 : 0.43)));
    for (let column = 0; column < columns; column++) {
      const x = -bodyWidth / 2 + 0.18 + column * ((bodyWidth - 0.36) / Math.max(1, columns - 1));
      if (y > height + 0.18) continue;
      addBox(windowWidth,windowHeight,facadeOffset,glassMat,x,y,bodyDepth/2+facadeOffset,"window-front");
      addBox(windowWidth,windowHeight,facadeOffset,glassMat,x,y,-bodyDepth/2-facadeOffset,"window-back");
      addBox(facadeOffset,windowHeight,windowWidth,glassMat,bodyWidth/2+facadeOffset,y,x,"window-east");
      addBox(facadeOffset,windowHeight,windowWidth,glassMat,-bodyWidth/2-facadeOffset,y,x,"window-west");
      addBox(0.035,windowHeight+0.10,facadeOffset,trimMat,x-windowWidth/2,y,bodyDepth/2+0.045,"frame-front");
      addBox(0.035,windowHeight+0.10,facadeOffset,trimMat,x+windowWidth/2,y,-bodyDepth/2-0.045,"frame-back");
    }
    if (!isLowRise && floor > 0) addBox(bodyWidth+0.045,0.055,bodyDepth+0.045,trimMat,0,0.32+floor*height/floors,0,"floor-band");
  }

  if (type === "shop") {
    addBox(bodyWidth*0.72,0.82,0.045,glassMat,0,0.82,bodyDepth/2+0.06,"storefront");
    addBox(bodyWidth+0.18,0.10,0.62,accentMat,0,1.34,bodyDepth/2+0.22,"canopy");
    addBox(bodyWidth+0.12,0.08,0.08,trimMat,0,1.43,bodyDepth/2+0.10,"canopy-trim");
  }

  const roofY = 0.34 + height + (type === "home" ? 0.72 : 0.12);
  if (!isLowRise) {
    addBox(bodyWidth+0.18,0.20,0.12,trimMat,0,roofY,bodyDepth/2,"parapet-long");
    addBox(bodyWidth+0.18,0.20,0.12,trimMat,0,roofY,-bodyDepth/2,"parapet-long");
    addBox(0.12,0.20,bodyDepth,trimMat,bodyWidth/2,roofY,0,"parapet-side");
    addBox(0.12,0.20,bodyDepth,trimMat,-bodyWidth/2,roofY,0,"parapet-side");
  }

  let instanceCount = 0;
  for (const batch of batches.values()) {
    const mesh = new THREE.InstancedMesh(batch.geometry,batch.material,batch.positions.length);
    const dummy = new THREE.Object3D();
    for (let i=0;i<batch.positions.length;i++) {
      const [x,y,z] = batch.positions[i];
      dummy.position.set(x,y,z);
      dummy.updateMatrix();
      mesh.setMatrixAt(i,dummy.matrix);
    }
    mesh.instanceMatrix.needsUpdate = true;
    mesh.castShadow = false;
    mesh.receiveShadow = true;
    group.add(mesh);
    instanceCount += batch.positions.length;
  }

  if (type === "home" || type === "shop" || !isLowRise) {
    const unitMaterial = roofMat || accentMat;
    const unit = new THREE.Group();
    const casing = new THREE.Mesh(new THREE.BoxGeometry(0.42,0.24,0.34),unitMaterial);
    casing.position.y=0.12; unit.add(casing);
    const fan = new THREE.Mesh(new THREE.CylinderGeometry(0.105,0.105,0.035,10),trimMat);
    fan.position.y=0.26; unit.add(fan);
    unit.position.set(bodyWidth*0.22,roofY+0.04,-bodyDepth*0.20); group.add(unit);
    if (type !== "home") {
      const second=unit.clone(); second.position.x=-bodyWidth*0.22; second.position.z=bodyDepth*0.20; group.add(second);
    }
  }
  return { windowCount: instanceCount, frameCount: batches.size, floorBandCount: floors-1 > 0 && !isLowRise ? floors-1 : 0, elevations:4, floors, drawCallBatches:batches.size };
}
