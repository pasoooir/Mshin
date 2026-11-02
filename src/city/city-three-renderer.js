const THREE_CDN = "https://cdn.jsdelivr.net/npm/three@0.180.0/build/three.module.js";
const THREE_FALLBACK_CDN = "https://unpkg.com/three@0.180.0/build/three.module.js";
const GRID_SIZE = 32;
const ROAD_CELLS = new Set([7, 8, 15, 16, 23, 24]);

export async function createCityThreeRenderer(sourceCanvas) {
  let THREE;
  try { THREE = await import(THREE_CDN); }
  catch (primaryError) {
    try { THREE = await import(THREE_FALLBACK_CDN); }
    catch (fallbackError) {
      throw new Error("Three.js could not load from either configured CDN: " + primaryError.message + " | " + fallbackError.message);
    }
  }

  const renderer = new THREE.WebGLRenderer({
    antialias: true,
    alpha: false,
    powerPreference: "high-performance",
    stencil: false,
    depth: true
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
  renderer.setSize(window.innerWidth, window.innerHeight, false);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.08;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;

  const canvas = renderer.domElement;
  canvas.id = "cityThreeViewport";
  canvas.setAttribute("aria-label", "نمای سه‌بعدی شهر خالی با شبکه خیابان‌ها و قطعات زمین");
  canvas.style.cssText = "position:fixed;inset:0;width:100%;height:100%;z-index:1;pointer-events:none;display:block;touch-action:none";
  sourceCanvas.parentNode.insertBefore(canvas, sourceCanvas.nextSibling);
  sourceCanvas.style.opacity = "0";

  const scene = new THREE.Scene();
  const sky = new THREE.Color("#b9d8e2");
  scene.background = sky;
  scene.fog = new THREE.Fog("#b9d8e2", 95, 190);

  const camera = new THREE.OrthographicCamera(-40, 40, 25, -25, 0.1, 260);
  camera.position.set(48, 58, 48);
  camera.lookAt(0, 0, 0);

  scene.add(new THREE.HemisphereLight("#f1fbff", "#526b48", 2.0));
  const sun = new THREE.DirectionalLight("#fff0d5", 3.0);
  sun.position.set(-42, 68, -35);
  sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024);
  sun.shadow.camera.left = -52;
  sun.shadow.camera.right = 52;
  sun.shadow.camera.top = 52;
  sun.shadow.camera.bottom = -52;
  sun.shadow.bias = -0.00025;
  scene.add(sun);
  const fill = new THREE.DirectionalLight("#9bd7ff", 0.85);
  fill.position.set(38, 24, 42);
  scene.add(fill);

  function makeSurfaceTexture(base, fleck, seed, count, scale = 1) {
    const textureCanvas = document.createElement("canvas");
    textureCanvas.width = textureCanvas.height = 512;
    const g = textureCanvas.getContext("2d");
    g.fillStyle = base;
    g.fillRect(0, 0, 512, 512);
    let state = seed >>> 0;
    const random = () => {
      state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
      return state / 4294967296;
    };
    for (let i = 0; i < count; i++) {
      const size = 0.5 + random() * 3.0 * scale;
      g.globalAlpha = 0.07 + random() * 0.18;
      g.fillStyle = fleck;
      g.fillRect(random() * 512, random() * 512, size, size);
    }
    g.globalAlpha = 1;
    const texture = new THREE.CanvasTexture(textureCanvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
    texture.anisotropy = Math.min(renderer.capabilities.getMaxAnisotropy(), 4);
    return texture;
  }

  const grassMap = makeSurfaceTexture("#86a96d", "#d9e8b9", 741, 11500);
  const roadMap = makeSurfaceTexture("#353e47", "#b5c0c2", 912, 6800, 0.8);
  const sidewalkMap = makeSurfaceTexture("#c2c0ae", "#f4f0df", 1187, 2400);
  const grassMaterial = new THREE.MeshStandardMaterial({ map: grassMap, roughness: 1 });
  const alternateGrassMaterial = new THREE.MeshStandardMaterial({ map: grassMap, color: "#dce8c7", roughness: 1 });
  const roadMaterial = new THREE.MeshStandardMaterial({ map: roadMap, roughness: 0.96, metalness: 0.015 });
  const sidewalkMaterial = new THREE.MeshStandardMaterial({ map: sidewalkMap, roughness: 0.94 });
  const curbMaterial = new THREE.MeshStandardMaterial({ color: "#e4dfc9", roughness: 0.88 });
  const markingMaterial = new THREE.MeshStandardMaterial({ color: "#f8edc8", roughness: 0.8 });
  const plotLineMaterial = new THREE.LineBasicMaterial({ color: "#e6e9ce", transparent: true, opacity: 0.62 });

  const ground = new THREE.Mesh(
    new THREE.PlaneGeometry(210, 210),
    new THREE.MeshStandardMaterial({ color: "#718d61", roughness: 1 })
  );
  ground.rotation.x = -Math.PI / 2;
  ground.position.y = -0.34;
  ground.receiveShadow = true;
  scene.add(ground);

  const grassGeometry = new THREE.BoxGeometry(1.94, 0.22, 1.94);
  const roadGeometry = new THREE.BoxGeometry(1.99, 0.16, 1.99);
  const grassA = new THREE.InstancedMesh(grassGeometry, grassMaterial, 1024);
  const grassB = new THREE.InstancedMesh(grassGeometry, alternateGrassMaterial, 1024);
  const roads = new THREE.InstancedMesh(roadGeometry, roadMaterial, 1024);
  const dummy = new THREE.Object3D();
  let grassCountA = 0, grassCountB = 0, roadCount = 0;
  const plotEdges = [];
  const curbInstances = [];
  const markingInstances = [];

  for (let y = 0; y < GRID_SIZE; y++) {
    for (let x = 0; x < GRID_SIZE; x++) {
      const px = (x - 15.5) * 2;
      const pz = (y - 15.5) * 2;
      const isRoad = ROAD_CELLS.has(x) || ROAD_CELLS.has(y);
      dummy.position.set(px, isRoad ? -0.01 : 0.025, pz);
      dummy.updateMatrix();
      if (isRoad) {
        roads.setMatrixAt(roadCount++, dummy.matrix);
        continue;
      }
      const alternate = (x + y) % 2 === 1;
      (alternate ? grassB : grassA).setMatrixAt(alternate ? grassCountB++ : grassCountA++, dummy.matrix);
      const edgeY = 0.142;
      plotEdges.push(
        px - 0.91, edgeY, pz - 0.91, px + 0.91, edgeY, pz - 0.91,
        px + 0.91, edgeY, pz - 0.91, px + 0.91, edgeY, pz + 0.91,
        px + 0.91, edgeY, pz + 0.91, px - 0.91, edgeY, pz + 0.91,
        px - 0.91, edgeY, pz + 0.91, px - 0.91, edgeY, pz - 0.91
      );

      // Raised concrete curbs give every empty parcel a readable street edge.
      for (const [dx, dz, sx, sz] of [[1,0,0.08,1.72],[-1,0,0.08,1.72],[0,1,1.72,0.08],[0,-1,1.72,0.08]]) {
        const nx = x + dx, ny = y + dz;
        if (nx < 0 || ny < 0 || nx >= GRID_SIZE || ny >= GRID_SIZE || !(ROAD_CELLS.has(nx) || ROAD_CELLS.has(ny))) continue;
        curbInstances.push({ x: px + dx * 0.94, z: pz + dz * 0.94, sx, sz });
      }
    }
  }
  grassA.count = grassCountA;
  grassB.count = grassCountB;
  roads.count = roadCount;
  grassA.instanceMatrix.needsUpdate = grassB.instanceMatrix.needsUpdate = roads.instanceMatrix.needsUpdate = true;
  grassA.receiveShadow = grassB.receiveShadow = roads.receiveShadow = true;
  scene.add(grassA, grassB, roads);

  const curbGeometry = new THREE.BoxGeometry(1, 0.15, 1);
  const curbs = new THREE.InstancedMesh(curbGeometry, curbMaterial, Math.max(1, curbInstances.length));
  curbInstances.forEach((v, i) => {
    dummy.position.set(v.x, 0.13, v.z);
    dummy.scale.set(v.sx, 1, v.sz);
    dummy.updateMatrix();
    curbs.setMatrixAt(i, dummy.matrix);
  });
  curbs.count = curbInstances.length;
  curbs.instanceMatrix.needsUpdate = true;
  curbs.castShadow = true;
  curbs.receiveShadow = true;
  scene.add(curbs);

  // Fine cadastral outlines make the initial empty city read as thousands of buildable lots.
  const plotGeometry = new THREE.BufferGeometry();
  plotGeometry.setAttribute("position", new THREE.Float32BufferAttribute(plotEdges, 3));
  scene.add(new THREE.LineSegments(plotGeometry, plotLineMaterial));

  // Every street gets a dashed centre line; the broad intersections get zebra crossings.
  const roadMarkings = [];
  for (let y = 0; y < GRID_SIZE; y++) {
    if (!ROAD_CELLS.has(y)) continue;
    for (let x = 0; x < GRID_SIZE; x++) {
      if (ROAD_CELLS.has(x) || x % 2 !== 0) continue;
      const z = (y - 15.5) * 2;
      roadMarkings.push((x - 15.5) * 2 - 0.36, 0.078, z, (x - 15.5) * 2 + 0.36, 0.078, z);
    }
  }
  for (let x = 0; x < GRID_SIZE; x++) {
    if (!ROAD_CELLS.has(x)) continue;
    for (let y = 0; y < GRID_SIZE; y++) {
      if (ROAD_CELLS.has(y) || y % 2 !== 0) continue;
      const px = (x - 15.5) * 2;
      roadMarkings.push(px, 0.078, (y - 15.5) * 2 - 0.36, px, 0.078, (y - 15.5) * 2 + 0.36);
    }
  }
  const markingGeometry = new THREE.BufferGeometry();
  markingGeometry.setAttribute("position", new THREE.Float32BufferAttribute(roadMarkings, 3));
  scene.add(new THREE.LineSegments(markingGeometry, new THREE.LineBasicMaterial({ color: "#f4e8c2", transparent: true, opacity: 0.86 })));

  const crossings = new THREE.Group();
  const stripeGeometry = new THREE.BoxGeometry(0.14, 0.025, 0.72);
  const stripeGeometryRotated = new THREE.BoxGeometry(0.72, 0.025, 0.14);
  const stripeMaterial = new THREE.MeshStandardMaterial({ color: "#f7f0dc", roughness: 0.8 });
  const intersectionCenters = [7.5, 15.5, 23.5];
  for (const ix of intersectionCenters) {
    for (const iz of intersectionCenters) {
      const cx = (ix - 15.5) * 2, cz = (iz - 15.5) * 2;
      for (let n = -3; n <= 3; n++) {
        const s1 = new THREE.Mesh(stripeGeometry, stripeMaterial);
        s1.position.set(cx + n * 0.24, 0.09, cz - 2.05);
        crossings.add(s1);
        const s2 = new THREE.Mesh(stripeGeometry, stripeMaterial);
        s2.position.set(cx + n * 0.24, 0.09, cz + 2.05);
        crossings.add(s2);
        const s3 = new THREE.Mesh(stripeGeometryRotated, stripeMaterial);
        s3.position.set(cx - 2.05, 0.09, cz + n * 0.24);
        crossings.add(s3);
        const s4 = new THREE.Mesh(stripeGeometryRotated, stripeMaterial);
        s4.position.set(cx + 2.05, 0.09, cz + n * 0.24);
        crossings.add(s4);
      }
    }
  }
  scene.add(crossings);

  // Subtle parcel subdivision lines create smaller build pads inside each city block.
  const lotLines = [];
  for (let y = 0; y < GRID_SIZE; y += 2) {
    for (let x = 0; x < GRID_SIZE; x++) {
      if (ROAD_CELLS.has(y) || ROAD_CELLS.has(x)) continue;
      const left = (x - 15.5) * 2, right = left + 2;
      const z = (y - 15.5) * 2;
      lotLines.push(left, 0.151, z, right, 0.151, z);
    }
  }
  const lotGeometry = new THREE.BufferGeometry();
  lotGeometry.setAttribute("position", new THREE.Float32BufferAttribute(lotLines, 3));
  scene.add(new THREE.LineSegments(lotGeometry, new THREE.LineBasicMaterial({ color: "#f1e8cb", transparent: true, opacity: 0.42 })));

  const buildings = new THREE.Group();
  scene.add(buildings);
  let buildingSignature = "";
  const windowMaterial = new THREE.MeshStandardMaterial({ color: "#bfe4ed", emissive: "#477b8c", emissiveIntensity: 0.16, roughness: 0.32, metalness: 0.12 });
  const roofMaterials = ["#d9d2bb", "#6f8790", "#a9b4ad", "#b58a64"].map(color => new THREE.MeshStandardMaterial({ color, roughness: 0.88 }));
  function updateBuildings(city) {
    const next = city.buildings.map(v => [v.id, v.type, v.x, v.y, v.level].join(":")).join("|");
    if (next === buildingSignature) return;
    buildingSignature = next;
    while (buildings.children.length) {
      const child = buildings.children.pop();
      buildings.remove(child);
    }
    for (const item of city.buildings) {
      const x = (item.x - 15.5) * 2, z = (item.y - 15.5) * 2;
      if (item.type === "park") {
        const lawn = new THREE.Mesh(new THREE.BoxGeometry(1.72, 0.2, 1.72), new THREE.MeshStandardMaterial({ color: "#4d9852", roughness: 1 }));
        lawn.position.set(x, 0.22, z);
        buildings.add(lawn);
        continue;
      }
      const height = 1.4 + (item.level || 1) * 0.7;
      const palette = item.type === "home" ? ["#dfc49a", "#b8c6c8"] : item.type === "shop" ? ["#6aaeb5", "#d5bd8d"] : item.type === "industrial" ? ["#98a7aa", "#677b82"] : ["#9d9ac5", "#d5d1e7"];
      const wallMaterial = new THREE.MeshStandardMaterial({ color: palette[0], roughness: 0.8 });
      const body = new THREE.Mesh(new THREE.BoxGeometry(1.28, height, 1.28), wallMaterial);
      body.position.set(x, 0.22 + height / 2, z);
      body.castShadow = true;
      body.receiveShadow = true;
      buildings.add(body);
      const roof = new THREE.Mesh(new THREE.BoxGeometry(1.36, 0.14, 1.36), roofMaterials[item.id % roofMaterials.length]);
      roof.position.set(x, 0.22 + height + 0.07, z);
      buildings.add(roof);
      for (const side of [-1, 1]) {
        const window = new THREE.Mesh(new THREE.BoxGeometry(0.045, Math.min(0.9, height * 0.45), 0.46), windowMaterial);
        window.position.set(x + side * 0.65, 0.45 + height * 0.58, z);
        buildings.add(window);
      }
    }
  }

  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();
  const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  let width = window.innerWidth, height = window.innerHeight;

  function resize() {
    width = window.innerWidth;
    height = window.innerHeight;
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
    renderer.setSize(width, height, false);
    const aspect = width / Math.max(1, height);
    camera.left = -25 * aspect;
    camera.right = 25 * aspect;
    camera.top = 25;
    camera.bottom = -25;
    camera.updateProjectionMatrix();
  }

  function updateCamera(cam) {
    const zoom = Math.max(0.4, Math.min(1.7, (cam.zoom || 0.72) * 1.25));
    camera.zoom = zoom;
    const worldScale = height / 50;
    const targetX = -(cam.x || 0) / worldScale;
    const targetZ = -(cam.y || 0) / worldScale;
    camera.position.set(48 + targetX, 58, 48 + targetZ);
    camera.lookAt(targetX, 0, targetZ);
    camera.updateProjectionMatrix();
  }

  function render(city, view, cam) {
    updateCamera(cam);
    updateBuildings(city);
    renderer.render(scene, camera);
  }

  function tileAt(screenX, screenY) {
    pointer.set(screenX / Math.max(1, width) * 2 - 1, -screenY / Math.max(1, height) * 2 + 1);
    raycaster.setFromCamera(pointer, camera);
    const point = new THREE.Vector3();
    if (!raycaster.ray.intersectPlane(groundPlane, point)) return { x: -1, y: -1 };
    return { x: Math.floor(point.x / 2 + 16), y: Math.floor(point.z / 2 + 16) };
  }

  function screenForTile(x, y) {
    const point = new THREE.Vector3((x - 15.5) * 2, 0.16, (y - 15.5) * 2).project(camera);
    return { x: (point.x + 1) * width / 2, y: (1 - point.y) * height / 2 };
  }

  function onResize() { resize(); }
  resize();
  window.addEventListener("resize", onResize);
  return {
    render,
    tileAt,
    screenForTile,
    resize,
    destroy() {
      window.removeEventListener("resize", onResize);
      renderer.dispose();
      grassMap.dispose();
      roadMap.dispose();
      sidewalkMap.dispose();
      canvas.remove();
      sourceCanvas.style.opacity = "";
    }
  };
}
