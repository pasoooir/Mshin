/**
 * Batched four-elevation architecture kit.
 * Reuses geometry and InstancedMesh batches to keep detailed facades mobile-friendly.
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
  // One shared geometry per facade category; per-floor allocations leak because
  // InstancedMesh only retains the first geometry registered for each batch.
  const frontWindow = new THREE.BoxGeometry(windowWidth, windowHeight, facadeOffset);
  const frameGeometry = new THREE.BoxGeometry(facadeOffset, windowHeight + 0.10, 0.035);
  const sideGeometry = new THREE.BoxGeometry(facadeOffset, windowHeight, windowWidth);
  const floorBandGeometry = new THREE.BoxGeometry(bodyWidth + 0.045, 0.055, bodyDepth + 0.045);
  const addInstance = (key, geometry, material, position, rotation = [0, 0, 0]) => {
    let batch = batches.get(key);
    if (!batch) { batch = { geometry, material, transforms: [] }; batches.set(key, batch); }
    batch.transforms.push({ position, rotation });
  };

  for (let floor = 0; floor < floors; floor++) {
    const floorHeight = (height - 0.48) / floors;
    const y = 0.40 + floor * floorHeight + floorHeight * 0.52;
    const columns = Math.max(2, Math.floor((bodyWidth - 0.24) / (isIndustrial ? 0.48 : 0.43)));
    for (let column = 0; column < columns; column++) {
      const x = -bodyWidth / 2 + 0.18 + column * ((bodyWidth - 0.36) / Math.max(1, columns - 1));
      if (y > height + 0.18) continue;
      addInstance("front-windows", frontWindow, glassMat, [x,y,bodyDepth/2+facadeOffset]);
      addInstance("front-windows", frontWindow, glassMat, [x,y,-bodyDepth/2-facadeOffset], [0,Math.PI,0]);
      addInstance("front-frames", frameGeometry, trimMat, [x-windowWidth/2,y,bodyDepth/2+0.045]);
      addInstance("front-frames", frameGeometry, trimMat, [x+windowWidth/2,y,-bodyDepth/2-0.045]);
    }
    const sideCount = Math.max(2, Math.floor((bodyDepth - 0.24) / 0.43));
    for (let side = 0; side < sideCount; side++) {
      const z = -bodyDepth/2+0.18+side*((bodyDepth-0.36)/Math.max(1,sideCount-1));
      addInstance("side-windows",sideGeometry,glassMat,[bodyWidth/2+facadeOffset,y,z]);
      addInstance("side-windows",sideGeometry,glassMat,[-bodyWidth/2-facadeOffset,y,z]);
    }
    if (!isLowRise && floor > 0) {
      addInstance("floor-bands",floorBandGeometry,trimMat,[0,0.32+floor*height/floors,0]);
    }
  }

  const roofY=0.34+height+(type==="home"?0.72:0.12);
  const addBox=(w,h,d,material,x,y,z)=>{
    const mesh=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),material);
    mesh.position.set(x,y,z); mesh.castShadow=false; mesh.receiveShadow=true; group.add(mesh);
  };
  if (!isLowRise) {
    addBox(bodyWidth+0.18,0.20,0.12,trimMat,0,roofY,bodyDepth/2);
    addBox(bodyWidth+0.18,0.20,0.12,trimMat,0,roofY,-bodyDepth/2);
    addBox(0.12,0.20,bodyDepth,trimMat,bodyWidth/2,roofY,0);
    addBox(0.12,0.20,bodyDepth,trimMat,-bodyWidth/2,roofY,0);
  }
  if (type==="shop") {
    addBox(bodyWidth*0.72,0.82,0.045,glassMat,0,0.82,bodyDepth/2+0.06);
    addBox(bodyWidth+0.18,0.10,0.62,accentMat,0,1.34,bodyDepth/2+0.22);
    addBox(bodyWidth+0.12,0.08,0.08,trimMat,0,1.43,bodyDepth/2+0.10);
  }

  const dummy=new THREE.Object3D();
  let windowCount=0,frameCount=0,floorBandCount=0;
  for (const [key,batch] of batches) {
    const instances=new THREE.InstancedMesh(batch.geometry,batch.material,batch.transforms.length);
    instances.castShadow=false; instances.receiveShadow=true;
    batch.transforms.forEach((entry,index)=>{
      dummy.position.set(...entry.position); dummy.rotation.set(...entry.rotation);
      dummy.scale.set(1,1,1); dummy.updateMatrix(); instances.setMatrixAt(index,dummy.matrix);
    });
    instances.instanceMatrix.needsUpdate=true; group.add(instances);
    if (key.includes("windows")) windowCount+=batch.transforms.length;
    else if (key.includes("frames")) frameCount+=batch.transforms.length;
    else floorBandCount+=batch.transforms.length;
  }

  if (type==="home"||type==="shop"||!isLowRise) {
    const unit=new THREE.Group();
    const casing=new THREE.Mesh(new THREE.BoxGeometry(0.42,0.24,0.34),roofMat||accentMat);
    casing.position.y=0.12; unit.add(casing);
    const fan=new THREE.Mesh(new THREE.CylinderGeometry(0.105,0.105,0.035,10),trimMat);
    fan.position.y=0.26; unit.add(fan);
    unit.position.set(bodyWidth*0.22,roofY+0.04,-bodyDepth*0.20); group.add(unit);
    if(type!=="home"){const second=unit.clone();second.position.x=-bodyWidth*0.22;second.position.z=bodyDepth*0.20;group.add(second);}
  }
  return {windowCount,frameCount,floorBandCount,elevations:4,floors,facadeBatchCount:batches.size};
}
