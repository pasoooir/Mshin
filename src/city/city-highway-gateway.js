/**
 * Original, procedural 3D regional highway and city gateway.
 * World scale: metres. The highway is outside the buildable 32x32 parcel area,
 * but inside the visible 64x64 landscape envelope.
 */
export function createCityHighwayGateway(THREE, { asphaltSurface, concreteSurface }) {
  const root = new THREE.Group();
  root.name = "mshin-regional-highway-gateway";
  const asphaltMap = asphaltSurface.map.clone();
  asphaltMap.wrapS = asphaltMap.wrapT = THREE.RepeatWrapping;
  asphaltMap.repeat.set(2.5, 34);
  asphaltMap.needsUpdate = true;
  const asphaltNormal = asphaltSurface.normalMap.clone();
  asphaltNormal.wrapS = asphaltNormal.wrapT = THREE.RepeatWrapping;
  asphaltNormal.repeat.copy(asphaltMap.repeat);
  asphaltNormal.needsUpdate = true;
  const roadMaterial = new THREE.MeshStandardMaterial({
    map: asphaltMap,
    normalMap: asphaltNormal,
    color: "#d8dce0",
    roughness: 0.91,
    metalness: 0.015,
    normalScale: new THREE.Vector2(0.48, 0.48)
  });
  const shoulderMaterial = new THREE.MeshStandardMaterial({ color: "#777d7d", roughness: 0.98 });
  const concreteMaterial = new THREE.MeshStandardMaterial({
    map: concreteSurface.map,
    normalMap: concreteSurface.normalMap,
    color: "#c4c4bc",
    roughness: 0.94
  });
  const markingMaterial = new THREE.MeshStandardMaterial({
    color: "#f4e8bf", roughness: 0.72, emissive: "#4c432b", emissiveIntensity: 0.035
  });
  const whiteMarkingMaterial = new THREE.MeshStandardMaterial({ color: "#f4f2e9", roughness: 0.7 });
  const railMaterial = new THREE.MeshStandardMaterial({ color: "#aeb8bc", metalness: 0.72, roughness: 0.34 });
  const darkMetalMaterial = new THREE.MeshStandardMaterial({ color: "#4c5558", metalness: 0.64, roughness: 0.48 });
  const grassMaterial = new THREE.MeshStandardMaterial({ color: "#688d4e", roughness: 1 });
  const dirtMaterial = new THREE.MeshStandardMaterial({ color: "#9a8968", roughness: 1 });
  const meshes = [];
  const addStrip = (curve, width, material, y = 0.02, segments = 100, name = "road-surface") => {
    const positions = [];
    const uvs = [];
    const indices = [];
    for (let i = 0; i <= segments; i++) {
      const t = i / segments;
      const point = curve.getPointAt(t);
      const tangent = curve.getTangentAt(t);
      const length = Math.hypot(tangent.x, tangent.z) || 1;
      const nx = -tangent.z / length;
      const nz = tangent.x / length;
      const half = width / 2;
      positions.push(point.x + nx * half, point.y + y, point.z + nz * half);
      positions.push(point.x - nx * half, point.y + y, point.z - nz * half);
      uvs.push(0, t * width * 0.22, 1, t * width * 0.22);
      if (i < segments) {
        const a = i * 2;
        indices.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
      }
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.Float32BufferAttribute(positions, 3));
    geometry.setAttribute("uv", new THREE.Float32BufferAttribute(uvs, 2));
    geometry.setIndex(indices);
    geometry.computeVertexNormals();
    const mesh = new THREE.Mesh(geometry, material);
    mesh.name = name;
    mesh.receiveShadow = true;
    mesh.castShadow = false;
    root.add(mesh);
    meshes.push(mesh);
    return mesh;
  };
  const curve = points => new THREE.CatmullRomCurve3(
    points.map(([x, y, z]) => new THREE.Vector3(x, y, z)), false, "centripetal"
  );
  const straight = (z, x0 = -310, x1 = 310) => curve([[x0, 0.05, z], [0, 0.05, z], [x1, 0.05, z]]);
  const mainNorth = straight(-199);
  const mainSouth = straight(-181);
  addStrip(mainNorth, 14.2, shoulderMaterial, 0, 120, "highway-north-shoulder");
  addStrip(mainSouth, 14.2, shoulderMaterial, 0, 120, "highway-south-shoulder");
  addStrip(mainNorth, 12.6, roadMaterial, 0.12, 120, "highway-north-carriageway");
  addStrip(mainSouth, 12.6, roadMaterial, 0.12, 120, "highway-south-carriageway");

  // Raised central median, planted with low shrubs and protected by concrete barriers.
  const median = new THREE.Mesh(new THREE.BoxGeometry(620, 0.48, 4.1), grassMaterial);
  median.position.set(0, 0.34, -190);
  median.receiveShadow = true;
  root.add(median);
  meshes.push(median);
  for (const z of [-190 - 2.15, -190 + 2.15]) {
    const barrier = new THREE.Mesh(new THREE.BoxGeometry(620, 0.82, 0.42), concreteMaterial);
    barrier.position.set(0, 0.72, z);
    barrier.castShadow = true;
    barrier.receiveShadow = true;
    root.add(barrier);
    meshes.push(barrier);
  }

  // Lane dividers: dashed, high-contrast, and slightly raised from the asphalt.
  const dashGeometry = new THREE.BoxGeometry(4.6, 0.025, 0.13);
  const laneDashes = new THREE.InstancedMesh(dashGeometry, whiteMarkingMaterial, 156);
  const dashTransform = new THREE.Object3D();
  let dashIndex = 0;
  for (const z of [-203.2, -199, -194.8, -185.2, -181, -176.8]) {
    for (let x = -300; x < 300; x += 12) {
      dashTransform.position.set(x + 2.3, 0.285, z);
      dashTransform.updateMatrix();
      laneDashes.setMatrixAt(dashIndex++, dashTransform.matrix);
    }
  }
  laneDashes.count = dashIndex;
  laneDashes.instanceMatrix.needsUpdate = true;
  root.add(laneDashes);
  meshes.push(laneDashes);
  // Solid edge lines and shoulder rumble strips.
  for (const z of [-205.0, -193.0, -187.0, -175.0]) {
    const line = new THREE.Mesh(new THREE.BoxGeometry(620, 0.028, 0.2), markingMaterial);
    line.position.set(0, 0.285, z);
    root.add(line);
    meshes.push(line);
  }

  const offRamp = curve([
    [-64, 0.16, -199], [-49, 0.16, -190], [-39, 0.16, -176],
    [-34, 0.16, -159], [-31, 0.16, -142], [-29, 0.16, -126]
  ]);
  const onRamp = curve([
    [-8, 0.16, -126], [-10, 0.16, -143], [-13, 0.16, -160],
    [-18, 0.16, -175], [-28, 0.16, -188], [-48, 0.16, -181]
  ]);
  addStrip(offRamp, 8.2, shoulderMaterial, 0.01, 72, "highway-city-exit-shoulder");
  addStrip(offRamp, 7.0, roadMaterial, 0.14, 72, "highway-city-exit-ramp");
  addStrip(onRamp, 8.2, shoulderMaterial, 0.01, 72, "city-highway-entry-shoulder");
  addStrip(onRamp, 7.0, roadMaterial, 0.14, 72, "city-highway-entry-ramp");

  // Ramp terminals join through a short collector, which reaches the city boundary
  // without pre-populating any of the player's buildable road cells.
  const rampCollector = curve([[-29, 0.17, -126], [-22, 0.17, -125], [-15, 0.17, -125], [-8, 0.17, -126]]);
  addStrip(rampCollector, 10.2, shoulderMaterial, 0.02, 36, "city-gateway-collector-shoulder");
  addStrip(rampCollector, 8.0, roadMaterial, 0.16, 36, "city-gateway-collector");
  const gateway = curve([[-18, 0.17, -125], [-18, 0.17, -124]]);
  addStrip(gateway, 14.0, shoulderMaterial, 0.02, 8, "city-gateway-shoulder");
  addStrip(gateway, 11.6, roadMaterial, 0.16, 8, "city-gateway-arterial");
  for (const side of [-1, 1]) {
    const edge = curve([[-29 + side * 5.25, 0.2, -126], [-24 + side * 5.25, 0.2, -112], [-20 + side * 5.25, 0.2, -96], [-18 + side * 5.25, 0.2, -80]]);
    const line = new THREE.Mesh(new THREE.TubeGeometry(edge, 48, 0.09, 5, false), whiteMarkingMaterial);
    root.add(line);
    meshes.push(line);
  }

  // Metallic guardrails follow the outside edges of ramps and highway shoulders.
  const guardrailPostData = [];
  const addGuardrail = (path, offset) => {
    const points = [];
    const samples = 64;
    for (let i = 0; i <= samples; i++) {
      const t = i / samples;
      const p = path.getPointAt(t);
      const tangent = path.getTangentAt(t);
      const l = Math.hypot(tangent.x, tangent.z) || 1;
      points.push(new THREE.Vector3(p.x - tangent.z / l * offset, p.y + 0.92, p.z + tangent.x / l * offset));
    }
    const railCurve = new THREE.CatmullRomCurve3(points);
    const rail = new THREE.Mesh(new THREE.TubeGeometry(railCurve, samples, 0.11, 6, false), railMaterial);
    rail.castShadow = true;
    rail.receiveShadow = true;
    root.add(rail);
    meshes.push(rail);
    for (let i = 0; i <= samples; i += 4) {
      const p = railCurve.getPoint(i / samples);
      guardrailPostData.push([p.x, p.y - 0.43, p.z]);
    }
  };
  for (const z of [-205.5, -192.5, -187.5, -174.5]) {
    const line = straight(z, -310, 310);
    addGuardrail(line, 0.0);
  }
  addGuardrail(offRamp, 4.05);
  addGuardrail(offRamp, -4.05);
  addGuardrail(onRamp, 4.05);
  addGuardrail(onRamp, -4.05);
  const postGeometry = new THREE.BoxGeometry(0.12, 0.78, 0.12);
  const guardrailPosts = new THREE.InstancedMesh(postGeometry, darkMetalMaterial, guardrailPostData.length);
  const postTransform = new THREE.Object3D();
  guardrailPostData.forEach(([x, y, z], index) => {
    postTransform.position.set(x, y, z);
    postTransform.updateMatrix();
    guardrailPosts.setMatrixAt(index, postTransform.matrix);
  });
  guardrailPosts.count = guardrailPostData.length;
  guardrailPosts.instanceMatrix.needsUpdate = true;
  root.add(guardrailPosts);
  meshes.push(guardrailPosts);

  // Earth shoulders and landscaped embankment transitions anchor the ramps to terrain.
  for (const [x, z, sx, sz] of [[-48, -179, 42, 28], [-34, -145, 28, 34], [-18, -110, 34, 30]]) {
    const mound = new THREE.Mesh(new THREE.BoxGeometry(sx, 0.42, sz), dirtMaterial);
    mound.position.set(x, -0.08, z);
    mound.receiveShadow = true;
    root.add(mound);
    meshes.push(mound);
  }

  // Original overhead signs with readable English road information.
  const makeSign = (x, z, text) => {
    const postMaterial = darkMetalMaterial;
    const post = new THREE.Mesh(new THREE.BoxGeometry(0.28, 7.2, 0.28), railMaterial);
    post.position.set(x, 3.6, z);
    post.castShadow = true;
    root.add(post);
    meshes.push(post);
    const board = new THREE.Mesh(new THREE.BoxGeometry(10.5, 2.2, 0.22), new THREE.MeshStandardMaterial({
      color: "#176b48", roughness: 0.66, metalness: 0.08
    }));
    board.position.set(x + 5.2, 7.0, z);
    board.castShadow = true;
    root.add(board);
    meshes.push(board);
    const support = new THREE.Mesh(new THREE.BoxGeometry(10.8, 0.18, 0.18), postMaterial);
    support.position.set(x + 5.2, 8.18, z);
    root.add(support);
    meshes.push(support);
    const signCanvas = document.createElement("canvas");
    signCanvas.width = 512;
    signCanvas.height = 128;
    const ctx = signCanvas.getContext("2d");
    ctx.fillStyle = "#176b48";
    ctx.fillRect(0, 0, 512, 128);
    ctx.strokeStyle = "#f5f3e9";
    ctx.lineWidth = 8;
    ctx.strokeRect(5, 5, 502, 118);
    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 44px Arial";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(text, 256, 64, 470);
    const texture = new THREE.CanvasTexture(signCanvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    const face = new THREE.Mesh(new THREE.PlaneGeometry(10.2, 2.0), new THREE.MeshBasicMaterial({ map: texture, side: THREE.DoubleSide }));
    face.position.set(x + 5.2, 7.0, z + 0.13);
    root.add(face);
    meshes.push(face);
    face.userData.texture = texture;
  };
  makeSign(-108, -207, "CITY EXIT  |  1 km");
  makeSign(92, -207, "REGIONAL HIGHWAY");

  // Lightweight live traffic: vehicles are instanced and follow the actual
  // carriageway/ramp splines, including the city gateway approach.
  const trafficBodyGeometry = new THREE.BoxGeometry(1.9, 0.62, 4.1);
  const trafficCabinGeometry = new THREE.BoxGeometry(1.48, 0.54, 1.95);
  const trafficBodyMaterial = new THREE.MeshStandardMaterial({ color: "#ffffff", roughness: 0.48, metalness: 0.12 });
  const trafficCabinMaterial = new THREE.MeshStandardMaterial({ color: "#a9d9e5", roughness: 0.24, metalness: 0.08 });
  const trafficBodies = new THREE.InstancedMesh(trafficBodyGeometry, trafficBodyMaterial, 16);
  const trafficCabins = new THREE.InstancedMesh(trafficCabinGeometry, trafficCabinMaterial, 16);
  trafficBodies.castShadow = false;
  trafficCabins.castShadow = false;
  root.add(trafficBodies, trafficCabins);
  meshes.push(trafficBodies, trafficCabins);
  const trafficDummy = new THREE.Object3D();
  const trafficColors = ["#f2bd4d", "#65c8dc", "#d77e8b", "#a8c98a", "#b69be8", "#e5e9ef"];
  const northTrafficPath = curve([[-310, 0.34, -199], [-150, 0.34, -199], [0, 0.34, -199], [150, 0.34, -199], [310, 0.34, -199]]);
  const southTrafficPath = curve([[310, 0.34, -181], [150, 0.34, -181], [0, 0.34, -181], [-150, 0.34, -181], [-310, 0.34, -181]]);
  const trafficRoutes = [
    ...Array.from({ length: 6 }, (_, index) => ({ path: northTrafficPath, offset: index / 6, speed: 0.018 + (index % 3) * 0.002 })),
    ...Array.from({ length: 6 }, (_, index) => ({ path: southTrafficPath, offset: index / 6, speed: 0.017 + (index % 3) * 0.002 })),
    { path: offRamp, offset: 0.18, speed: 0.035 },
    { path: offRamp, offset: 0.66, speed: 0.032 },
    { path: onRamp, offset: 0.28, speed: 0.034 },
    { path: onRamp, offset: 0.76, speed: 0.031 }
  ];
  function updateTraffic(deltaSeconds = 1 / 60) {
    const elapsed = Math.max(0, Math.min(0.1, Number(deltaSeconds) || 0));
    trafficRoutes.forEach((route, index) => {
      route.offset = (route.offset + route.speed * elapsed) % 1;
      const point = route.path.getPointAt(route.offset);
      const tangent = route.path.getTangentAt(route.offset);
      const heading = Math.atan2(tangent.x, tangent.z);
      trafficDummy.position.set(point.x, point.y + 0.38, point.z);
      trafficDummy.rotation.set(0, heading, 0);
      trafficDummy.scale.set(1, 1, 1);
      trafficDummy.updateMatrix();
      trafficBodies.setMatrixAt(index, trafficDummy.matrix);
      trafficBodies.setColorAt(index, new THREE.Color(trafficColors[index % trafficColors.length]));
      trafficDummy.position.y += 0.42;
      trafficDummy.position.z -= Math.cos(heading) * 0.18;
      trafficDummy.position.x -= Math.sin(heading) * 0.18;
      trafficDummy.scale.set(1, 1, 1);
      trafficDummy.updateMatrix();
      trafficCabins.setMatrixAt(index, trafficDummy.matrix);
    });
    trafficBodies.instanceMatrix.needsUpdate = true;
    trafficCabins.instanceMatrix.needsUpdate = true;
    if (trafficBodies.instanceColor) trafficBodies.instanceColor.needsUpdate = true;
  }
  updateTraffic(0);

  root.userData.highwayStats = {
    highwayCarriageways: 2,
    highwayLanes: 6,
    highwayRamps: 2,
    cityGatewayRoads: 1,
    highwayGuardrailSegments: 8,
    highwaySigns: 2,
    highwayAnimatedVehicles: trafficRoutes.length,
    highwayMeshCount: root.children.length,
    highwayWorldUnitMeters: 1
  };
  return {
    group: root,
    getStats: () => ({ ...root.userData.highwayStats }),
    updateTraffic,
    dispose() {
      for (const mesh of meshes) {
        mesh.geometry?.dispose();
        if (mesh.material && !Array.isArray(mesh.material)) {
          if (mesh.material.map && mesh.material.map !== asphaltMap && mesh.material.map !== concreteSurface.map) mesh.material.map.dispose?.();
          mesh.material.dispose();
        }
      }
      for (const texture of [asphaltMap, asphaltNormal]) texture.dispose();
      root.removeFromParent();
    }
  };
}
