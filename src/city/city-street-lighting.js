/**
 * Low-poly street lamps placed only on the pedestrian strips beside road tiles.
 * All poles, arms and luminaires share one instanced mesh (one draw call).
 */
const POLE_COLOR = [0.16, 0.21, 0.23];
const ARM_COLOR = [0.20, 0.26, 0.28];
const LAMP_COLOR = [0.82, 0.72, 0.48];

function appendTriangle(positions, colors, a, b, c, color) {
  for (const point of [a, b, c]) {
    positions.push(point[0], point[1], point[2]);
    colors.push(color[0], color[1], color[2]);
  }
}

function appendQuad(positions, colors, a, b, c, d, color) {
  appendTriangle(positions, colors, a, b, c, color);
  appendTriangle(positions, colors, a, c, d, color);
}

function appendBox(positions, colors, center, size, color) {
  const [x,y,z]=center,[sx,sy,sz]=size;
  const x0=x-sx/2,x1=x+sx/2,y0=y-sy/2,y1=y+sy/2,z0=z-sz/2,z1=z+sz/2;
  appendQuad(positions,colors,[x0,y0,z1],[x1,y0,z1],[x1,y1,z1],[x0,y1,z1],color);
  appendQuad(positions,colors,[x1,y0,z0],[x0,y0,z0],[x0,y1,z0],[x1,y1,z0],color);
  appendQuad(positions,colors,[x0,y0,z0],[x0,y0,z1],[x0,y1,z1],[x0,y1,z0],color);
  appendQuad(positions,colors,[x1,y0,z1],[x1,y0,z0],[x1,y1,z0],[x1,y1,z1],color);
  appendQuad(positions,colors,[x0,y1,z1],[x1,y1,z1],[x1,y1,z0],[x0,y1,z0],color);
  appendQuad(positions,colors,[x0,y0,z0],[x1,y0,z0],[x1,y0,z1],[x0,y0,z1],color);
}

function appendCylinder(positions, colors, start, end, radius, color, segments=8) {
  const axis=end.map((value,index)=>value-start[index]);
  const length=Math.hypot(...axis)||1;
  const direction=axis.map(value=>value/length);
  const reference=Math.abs(direction[1])>.9?[0,0,1]:[0,1,0];
  const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
  const normalize=v=>{const n=Math.hypot(...v)||1;return v.map(x=>x/n)};
  const u=normalize(cross(direction,reference)),v=normalize(cross(direction,u));
  const ring=(origin,angle)=>origin.map((value,index)=>value+radius*(u[index]*Math.cos(angle)+v[index]*Math.sin(angle)));
  for(let i=0;i<segments;i++){
    const a=i/segments*Math.PI*2,b=(i+1)/segments*Math.PI*2;
    appendQuad(positions,colors,ring(start,a),ring(start,b),ring(end,b),ring(end,a),color);
  }
}

/** Returns deterministic street-lamp instances on sidewalks beside non-intersection road spans. */
export function createCityStreetLights(THREE, scene, isRoadCell, gridSize, windowMaterials) {
  const placements=[];
  for(let road=1;road<gridSize-1;road++){
    if(!isRoadCell(road))continue;
    for(let along=4;along<gridSize-2;along+=8){
      if(isRoadCell(along))continue;
      const horizontal=(road-31.5)*2;
      const longitudinal=(along-31.5)*2;
      for(const side of [-1,1]){
        // Install fixtures only on the exposed sidewalk edge of a road segment.
        if(isRoadCell(road+side))continue;
        placements.push({x:longitudinal,z:horizontal+side*1.36,rotation:0});
        placements.push({x:horizontal+side*1.36,z:longitudinal,rotation:Math.PI/2});
      }
    }
  }
  const positions=[],colors=[];
  appendCylinder(positions,colors,[0,0,0],[0,2.86,0],0.065,POLE_COLOR,8);
  appendCylinder(positions,colors,[0,2.76,0],[0.60,2.76,0],0.038,ARM_COLOR,7);
  appendBox(positions,colors,[0.48,2.68,0],[0.38,0.12,0.25],LAMP_COLOR);
  const geometry=new THREE.BufferGeometry();
  geometry.setAttribute("position",new THREE.Float32BufferAttribute(positions,3));
  geometry.setAttribute("color",new THREE.Float32BufferAttribute(colors,3));
  geometry.computeVertexNormals();
  const material=new THREE.MeshStandardMaterial({
    color:"#ffffff",vertexColors:true,roughness:0.64,metalness:0.42,
    emissive:"#ffbd70",emissiveIntensity:0
  });
  windowMaterials?.add(material);
  const mesh=new THREE.InstancedMesh(geometry,material,placements.length);
  const transform=new THREE.Object3D();
  placements.forEach((item,index)=>{
    transform.position.set(item.x,0.14,item.z);
    transform.rotation.set(0,item.rotation,0);
    transform.scale.set(1,1,1);
    transform.updateMatrix();
    mesh.setMatrixAt(index,transform.matrix);
  });
  mesh.count=placements.length;
  mesh.instanceMatrix.needsUpdate=true;
  mesh.castShadow=false;
  mesh.receiveShadow=true;
  mesh.frustumCulled=false;
  mesh.name="mshin-instanced-street-lights";
  scene.add(mesh);
  return {
    count:placements.length,
    mesh,
    dispose(){
      scene.remove(mesh);
      geometry.dispose();
      material.dispose();
      windowMaterials?.delete(material);
    }
  };
}
