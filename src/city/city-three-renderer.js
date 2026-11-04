const THREE_CDN = "https://cdn.jsdelivr.net/npm/three@0.180.0/build/three.module.js";
const THREE_FALLBACK_CDN = "https://unpkg.com/three@0.180.0/build/three.module.js";
import { createCityAtmosphere } from "./city-atmosphere.js";
import { updateCityCameraTransform } from "./city-camera-projection.js";
import { addOrbitReadyBuildingDetails } from "./city-building-details.js";
import { createCitySidewalkLayer } from "./city-street-renderer.js";
import { createCityStreetLights } from "./city-street-lighting.js";
import { createCityPbrSurfaces } from "./city-pbr-textures.js";
import { createCityBackgroundSkyline } from "./city-background-skyline.js";
import { addRealisticArchitecture } from "./city-architecture-realism.js";
const VISUAL_GRID = 64;
const ACTIVE_START = 16;
const ACTIVE_END = 48;
const ACTIVE_SIZE = 32;
const isRoadCell = value => (value % 8 === 7 || value % 8 === 0) && value !== 0 && value !== 16 && value !== 47 && value !== 63;
const isActiveCell = (x, y) => x >= ACTIVE_START && x < ACTIVE_END && y >= ACTIVE_START && y < ACTIVE_END;

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
  // City buildings and the sun are static between construction changes; avoid
  // regenerating the full shadow map on every mobile frame.
  renderer.shadowMap.autoUpdate = false;
  renderer.shadowMap.needsUpdate = true;

  const canvas = renderer.domElement;
  canvas.id = "cityThreeViewport";
  canvas.setAttribute("aria-label", "نمای سه‌بعدی شهر خالی با شبکه خیابان‌ها و قطعات زمین");
  canvas.style.cssText = "position:fixed;inset:0;width:100%;height:100%;z-index:1;pointer-events:none;display:block;touch-action:none";
  sourceCanvas.parentNode.insertBefore(canvas, sourceCanvas.nextSibling);
  sourceCanvas.style.opacity = "0";

  const scene = new THREE.Scene();
  scene.background = new THREE.Color("#9bd4ee");
  scene.fog = new THREE.Fog("#9bd4ee", 145, 260);
  const camera = new THREE.OrthographicCamera(-40, 40, 25, -25, 0.1, 320);
  camera.position.set(48, 38, 48);
  camera.lookAt(0, 0, 0);

  const hemisphere = new THREE.HemisphereLight("#fff7e8", "#537c48", 2.25);
  scene.add(hemisphere);
  const sun = new THREE.DirectionalLight("#fff1d2", 3.35);
  sun.position.set(-42, 68, -35);
  sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024);
  sun.shadow.camera.left = -76;
  sun.shadow.camera.right = 76;
  sun.shadow.camera.top = 76;
  sun.shadow.camera.bottom = -76;
  sun.shadow.bias = -0.00025;
  scene.add(sun);
  const fill = new THREE.DirectionalLight("#a9e2ff", 1.05);
  fill.position.set(38, 24, 42);
  scene.add(fill);
  const windowMaterials = new Set();
  const atmosphere = createCityAtmosphere(THREE, {
    scene, camera, sun, hemisphere, fill, windowMaterials,
    getViewport: () => ({ width: window.innerWidth, height: window.innerHeight }),
    getFoliageMaterials: () => canopyMaterials
  });

  const {
    grassSurface, asphaltSurface, brickSurface, concreteSurface, roofSurface, sidewalkSurface
  } = createCityPbrSurfaces(THREE, renderer);
  const backgroundSkyline = createCityBackgroundSkyline(THREE, scene, concreteSurface, brickSurface, windowMaterials);
  const grassMaterial = new THREE.MeshStandardMaterial({ ...grassSurface, roughness: 0.96, normalScale: new THREE.Vector2(0.32, 0.32) });
  const alternateGrassMaterial = new THREE.MeshStandardMaterial({ ...grassSurface, color: "#dce8c7", roughness: 0.98, normalScale: new THREE.Vector2(0.28, 0.28) });
  const lockedGrassMaterial = new THREE.MeshStandardMaterial({ ...grassSurface, color: "#899783", roughness: 1, normalScale: new THREE.Vector2(0.22, 0.22) });
  const lockedGrassAlternateMaterial = new THREE.MeshStandardMaterial({ ...grassSurface, color: "#9aa48e", roughness: 1, normalScale: new THREE.Vector2(0.22, 0.22) });
  const roadMaterial = new THREE.MeshStandardMaterial({ ...asphaltSurface, roughness: 0.94, metalness: 0.02, normalScale: new THREE.Vector2(0.42, 0.42) });
  const lockedRoadMaterial = new THREE.MeshStandardMaterial({ ...asphaltSurface, color: "#aab2b1", roughness: 0.98, normalScale: new THREE.Vector2(0.3, 0.3) });
  const curbMaterial = new THREE.MeshStandardMaterial({ color: "#f1e8d0", roughness: 0.82 });
  const plotLineMaterial = new THREE.LineBasicMaterial({ color: "#f8efcf", transparent: true, opacity: 0.72 });
  const lockedPlotLineMaterial = new THREE.LineBasicMaterial({ color: "#d1d8c4", transparent: true, opacity: 0.34 });

  const ground = new THREE.Mesh(
    new THREE.PlaneGeometry(140, 140),
    new THREE.MeshStandardMaterial({ ...grassSurface, color: "#a6b68a", roughness: 1, normalScale: new THREE.Vector2(0.24, 0.24) })
  );
  ground.rotation.x = -Math.PI / 2;
  ground.position.y = -0.34;
  ground.receiveShadow = true;
  scene.add(ground);

  const grassGeometry = new THREE.BoxGeometry(1.94, 0.22, 1.94);
  const roadGeometry = new THREE.BoxGeometry(1.99, 0.16, 1.99);
  const grassA = new THREE.InstancedMesh(grassGeometry, grassMaterial, 2304);
  const grassB = new THREE.InstancedMesh(grassGeometry, alternateGrassMaterial, 2304);
  const lockedGrassA = new THREE.InstancedMesh(grassGeometry, lockedGrassMaterial, 2304);
  const lockedGrassB = new THREE.InstancedMesh(grassGeometry, lockedGrassAlternateMaterial, 2304);
  const roads = new THREE.InstancedMesh(roadGeometry, roadMaterial, 1792);
  const lockedRoads = new THREE.InstancedMesh(roadGeometry, lockedRoadMaterial, 1792);
  const dummy = new THREE.Object3D();
  let activeGrassA = 0, activeGrassB = 0, activeRoads = 0;
  let lockedGrassCountA = 0, lockedGrassCountB = 0, lockedRoadCount = 0;
  const activePlotEdges = [], lockedPlotEdges = [], curbInstances = [];

  for (let y = 0; y < VISUAL_GRID; y++) {
    for (let x = 0; x < VISUAL_GRID; x++) {
      const px = (x - 31.5) * 2;
      const pz = (y - 31.5) * 2;
      const active = isActiveCell(x, y);
      const road = isRoadCell(x) || isRoadCell(y);
      dummy.position.set(px, road ? -0.01 : 0.025, pz);
      dummy.rotation.set(0, 0, 0);
      dummy.scale.set(1, 1, 1);
      dummy.updateMatrix();

      if (road) {
        (active ? roads : lockedRoads).setMatrixAt(active ? activeRoads++ : lockedRoadCount++, dummy.matrix);
        continue;
      }

      const alternate = (x + y) % 2 === 1;
      if (active) {
        (alternate ? grassB : grassA).setMatrixAt(alternate ? activeGrassB++ : activeGrassA++, dummy.matrix);
      } else {
        (alternate ? lockedGrassB : lockedGrassA).setMatrixAt(alternate ? lockedGrassCountB++ : lockedGrassCountA++, dummy.matrix);
      }

      const edgeY = 0.142;
      const edges = active ? activePlotEdges : lockedPlotEdges;
      edges.push(
        px - 0.91, edgeY, pz - 0.91, px + 0.91, edgeY, pz - 0.91,
        px + 0.91, edgeY, pz - 0.91, px + 0.91, edgeY, pz + 0.91,
        px + 0.91, edgeY, pz + 0.91, px - 0.91, edgeY, pz + 0.91,
        px - 0.91, edgeY, pz + 0.91, px - 0.91, edgeY, pz - 0.91
      );

      for (const [dx, dz, sx, sz] of [[1,0,0.08,1.72],[-1,0,0.08,1.72],[0,1,1.72,0.08],[0,-1,1.72,0.08]]) {
        const nx = x + dx, ny = y + dz;
        if (nx < 0 || ny < 0 || nx >= VISUAL_GRID || ny >= VISUAL_GRID || !(isRoadCell(nx) || isRoadCell(ny))) continue;
        curbInstances.push({ x: px + dx * 0.94, z: pz + dz * 0.94, sx, sz });
      }
    }
  }

  for (const mesh of [grassA, grassB, lockedGrassA, lockedGrassB, roads, lockedRoads]) {
    mesh.instanceMatrix.needsUpdate = true;
    mesh.receiveShadow = true;
  }
  grassA.count = activeGrassA;
  grassB.count = activeGrassB;
  roads.count = activeRoads;
  lockedGrassA.count = lockedGrassCountA;
  lockedGrassB.count = lockedGrassCountB;
  lockedRoads.count = lockedRoadCount;
  scene.add(grassA, grassB, lockedGrassA, lockedGrassB, roads, lockedRoads);

  const curbGeometry = new THREE.BoxGeometry(1, 0.15, 1);
  const curbs = new THREE.InstancedMesh(curbGeometry, curbMaterial, Math.max(1, curbInstances.length));
  curbInstances.forEach((v, i) => {
    dummy.position.set(v.x, 0.13, v.z);
    dummy.rotation.set(0, 0, 0);
    dummy.scale.set(v.sx, 1, v.sz);
    dummy.updateMatrix();
    curbs.setMatrixAt(i, dummy.matrix);
  });
  curbs.count = curbInstances.length;
  curbs.instanceMatrix.needsUpdate = true;
  curbs.receiveShadow = true;
  scene.add(curbs);

  function addLineLayer(points, material) {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.Float32BufferAttribute(points, 3));
    const lines = new THREE.LineSegments(geometry, material);
    scene.add(lines);
    return lines;
  }
  addLineLayer(activePlotEdges, plotLineMaterial);
  addLineLayer(lockedPlotEdges, lockedPlotLineMaterial);

  // Road dashes and crosswalks are instanced to keep the mobile GPU draw-call count low.
  const roadMarkings = [];
  const roadCenters = [7.5, 15, 23.5, 31.5, 39.5, 48, 55.5];
  for (const center of roadCenters) {
    const z = (center - 31.5) * 2;
    const x = (center - 31.5) * 2;
    for (let index = 0; index < VISUAL_GRID; index++) {
      if (!isRoadCell(index) && index % 2 === 0) {
        const along = (index - 31.5) * 2;
        roadMarkings.push(along - 0.36, 0.078, z, along + 0.36, 0.078, z);
        roadMarkings.push(x, 0.078, along - 0.36, x, 0.078, along + 0.36);
      }
    }
  }
  addLineLayer(roadMarkings, new THREE.LineBasicMaterial({ color: "#f4e8c2", transparent: true, opacity: 0.86 }));

  // Pedestrian crossings are intentionally not rendered until a pedestrian graph,
  // legal crossing nodes and signal/priority state exist. Painted zebra stripes would
  // falsely advertise a safe/operational crossing on the current road-only graph.
  const crosswalkStripeCount = 0;

  const lotLines = [];
  for (let y = 0; y < VISUAL_GRID; y += 2) {
    for (let x = 0; x < VISUAL_GRID; x++) {
      if (isRoadCell(y) || isRoadCell(x)) continue;
      const left = (x - 31.5) * 2, right = left + 2;
      const z = (y - 31.5) * 2;
      lotLines.push(left, 0.151, z, right, 0.151, z);
    }
  }
  addLineLayer(lotLines, new THREE.LineBasicMaterial({ color: "#f1e8cb", transparent: true, opacity: 0.42 }));

  // Gold boundary clearly separates the initially unlocked district from future expansion.
  const boundary = new THREE.LineLoop(
    new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(-32, 0.19, -32), new THREE.Vector3(32, 0.19, -32),
      new THREE.Vector3(32, 0.19, 32), new THREE.Vector3(-32, 0.19, 32)
    ]),
    new THREE.LineBasicMaterial({ color: "#e7bd69", transparent: true, opacity: 0.92 })
  );
  scene.add(boundary);

  // Perimeter greenery stays strictly outside the 64x64 parcel grid.
  // It is decorative-only and cannot overlap locked or unlocked buildable cells.
  const environment = new THREE.Group();
  scene.add(environment);
  const trunkGeometry = new THREE.CylinderGeometry(0.10, 0.15, 1.05, 6);
  const canopyGeometry = new THREE.SphereGeometry(0.62, 9, 7);
  const canopySmallGeometry = new THREE.SphereGeometry(0.42, 8, 6);
  const trunkMaterial = new THREE.MeshStandardMaterial({ color: "#8b5b38", roughness: 0.96 });
  const canopyMaterials = [
    new THREE.MeshStandardMaterial({ color: "#3f9b58", roughness: 1 }),
    new THREE.MeshStandardMaterial({ color: "#58ad58", roughness: 1 }),
    new THREE.MeshStandardMaterial({ color: "#78bd5d", roughness: 1 })
  ];
  const treeTrunks = new THREE.InstancedMesh(trunkGeometry, trunkMaterial, 180);
  const treeCanopies = canopyMaterials.map(material => new THREE.InstancedMesh(canopyGeometry, material, 180));
  const treeHighlights = canopyMaterials.map(material => new THREE.InstancedMesh(canopySmallGeometry, material, 180));
  let decorativeTreeCount = 0;
  let decorativeTreesOutsideBuildableGrid = 0;
  const treeSpeciesCounts = canopyMaterials.map(() => 0);
  const perimeterTreePositions = [];
  for (let offset = -60; offset <= 60; offset += 10) {
    perimeterTreePositions.push([-68, offset], [68, offset], [offset, -68], [offset, 68]);
  }
  for (const [px, pz] of perimeterTreePositions) {
    const species = (Math.round(px + 68) * 13 + Math.round(pz + 68) * 7) % canopyMaterials.length;
    if (Math.abs(px) > 64 || Math.abs(pz) > 64) decorativeTreesOutsideBuildableGrid++;
    dummy.position.set(px, 0.68, pz);
    dummy.rotation.set(0, 0, 0);
    dummy.scale.set(0.9 + species * 0.08, 0.9 + species * 0.1, 0.9 + species * 0.08);
    dummy.updateMatrix();
    treeTrunks.setMatrixAt(decorativeTreeCount, dummy.matrix);
    dummy.position.set(px, 1.45, pz);
    dummy.scale.set(1, 1, 1);
    dummy.updateMatrix();
    const speciesIndex = treeSpeciesCounts[species]++;
    treeCanopies[species].setMatrixAt(speciesIndex, dummy.matrix);
    dummy.position.set(px - 0.22, 1.68, pz - 0.16);
    dummy.scale.set(1, 1, 1);
    dummy.updateMatrix();
    treeHighlights[species].setMatrixAt(speciesIndex, dummy.matrix);
    decorativeTreeCount++;
  }
  treeTrunks.count = decorativeTreeCount;
  treeTrunks.instanceMatrix.needsUpdate = true;
  environment.add(treeTrunks);
  for (let species = 0; species < canopyMaterials.length; species++) {
    for (const mesh of [treeCanopies[species], treeHighlights[species]]) {
      mesh.count = treeSpeciesCounts[species];
      mesh.instanceMatrix.needsUpdate = true;
      if (mesh.count) environment.add(mesh);
    }
  }

  // Sidewalk furniture is kept outside parcel cells and batched into a single
  // instanced draw call so the night-city lighting detail stays mobile-friendly.
  const streetLights = createCityStreetLights(THREE, scene, isRoadCell, VISUAL_GRID, windowMaterials);
  const decorativeStreetLightCount = streetLights.count;
  const sidewalkLayer = createCitySidewalkLayer(THREE, scene, isRoadCell, VISUAL_GRID, sidewalkSurface);
  const streetFurniturePlacementReady = sidewalkLayer.count > 0 && decorativeStreetLightCount > 0;

  const buildings = new THREE.Group();
  scene.add(buildings);

  // Keep moving city traffic in two instanced batches so the mobile renderer
  // adds only two draw calls regardless of the number of visible vehicles.
  const trafficGroup = new THREE.Group();
  scene.add(trafficGroup);
  const trafficBodyGeometry = new THREE.BoxGeometry(1.02, 0.42, 1.78);
  const trafficGlassGeometry = new THREE.BoxGeometry(0.72, 0.28, 0.72);
  const trafficBodyMaterial = new THREE.MeshStandardMaterial({ color: "#ffffff", roughness: 0.48, metalness: 0.12 });
  const trafficGlassMaterial = new THREE.MeshStandardMaterial({ color: "#c8edf5", emissive: "#397f91", emissiveIntensity: 0.12, roughness: 0.24, metalness: 0.08 });
  const trafficBodies = new THREE.InstancedMesh(trafficBodyGeometry, trafficBodyMaterial, 12);
  const trafficWindows = new THREE.InstancedMesh(trafficGlassGeometry, trafficGlassMaterial, 12);
  trafficBodies.castShadow = false;
  trafficBodies.receiveShadow = true;
  trafficWindows.castShadow = false;
  trafficWindows.receiveShadow = true;
  trafficGroup.add(trafficBodies, trafficWindows);
  const trafficDummy = new THREE.Object3D();
  const trafficPalette = ["#f2bd4d", "#65c8dc", "#d77e8b", "#a8c98a", "#b69be8", "#e5e9ef"];

  function updateTraffic(city) {
    const vehicles = Array.isArray(city.traffic) ? city.traffic.slice(0, 12) : [];
    for (let index = 0; index < vehicles.length; index++) {
      const vehicle = vehicles[index];
      const x = (vehicle.x - 15.5) * 2;
      const z = (vehicle.y - 15.5) * 2;
      const rotation = Number.isFinite(vehicle.heading) ? Math.PI / 2 - vehicle.heading : 0;
      trafficDummy.position.set(x, 0.48, z);
      trafficDummy.rotation.set(0, rotation, 0);
      trafficDummy.scale.set(1, 1, 1);
      trafficDummy.updateMatrix();
      trafficBodies.setMatrixAt(index, trafficDummy.matrix);
      trafficBodies.setColorAt(index, new THREE.Color(vehicle.color || trafficPalette[index % trafficPalette.length]));

      trafficDummy.position.y = 0.78;
      trafficDummy.position.z = z - 0.08;
      trafficDummy.scale.set(1, 1, 1);
      trafficDummy.updateMatrix();
      trafficWindows.setMatrixAt(index, trafficDummy.matrix);
    }
    trafficBodies.count = vehicles.length;
    trafficWindows.count = vehicles.length;
    trafficBodies.instanceMatrix.needsUpdate = true;
    trafficWindows.instanceMatrix.needsUpdate = true;
    if (trafficBodies.instanceColor) trafficBodies.instanceColor.needsUpdate = true;
  }

  // Pedestrians are instanced in two batches; agent count never adds per-person draw calls.
  const pedestrianGroup = new THREE.Group();
  scene.add(pedestrianGroup);
  const pedestrianBodyGeometry = new THREE.CylinderGeometry(0.12, 0.14, 0.42, 6);
  const pedestrianHeadGeometry = new THREE.SphereGeometry(0.13, 8, 6);
  const pedestrianBodyMaterial = new THREE.MeshStandardMaterial({ color: "#ffffff", roughness: 0.88 });
  const pedestrianHeadMaterial = new THREE.MeshStandardMaterial({ color: "#f0d1b2", roughness: 0.92 });
  const pedestrianBodies = new THREE.InstancedMesh(pedestrianBodyGeometry, pedestrianBodyMaterial, 64);
  const pedestrianHeads = new THREE.InstancedMesh(pedestrianHeadGeometry, pedestrianHeadMaterial, 64);
  pedestrianBodies.castShadow = false;
  pedestrianBodies.receiveShadow = false;
  pedestrianBodies.frustumCulled = false;
  pedestrianHeads.castShadow = false;
  pedestrianHeads.receiveShadow = false;
  pedestrianHeads.frustumCulled = false;
  pedestrianGroup.add(pedestrianBodies, pedestrianHeads);
  const pedestrianDummy = new THREE.Object3D();
  const pedestrianPalette = ["#e9c56b", "#e7edf2", "#d98b75", "#8bc7b5", "#b69be8"];

  function updatePedestrians(city) {
    const citizens = Array.isArray(city.citizens) ? city.citizens.slice(0, 64) : [];
    for (let index = 0; index < citizens.length; index++) {
      const citizen = citizens[index];
      const x = (citizen.x - 15.5) * 2;
      const z = (citizen.y - 15.5) * 2;
      const rotation = Number.isFinite(citizen.heading) ? Math.PI / 2 - citizen.heading : 0;
      pedestrianDummy.position.set(x, 0.48, z);
      pedestrianDummy.rotation.set(0, rotation, 0);
      pedestrianDummy.scale.set(1, 1, 1);
      pedestrianDummy.updateMatrix();
      pedestrianBodies.setMatrixAt(index, pedestrianDummy.matrix);
      pedestrianBodies.setColorAt(index, new THREE.Color(pedestrianPalette[(citizen.id - 1) % pedestrianPalette.length]));
      pedestrianDummy.position.set(x, 0.78, z);
      pedestrianDummy.rotation.set(0, 0, 0);
      pedestrianDummy.updateMatrix();
      pedestrianHeads.setMatrixAt(index, pedestrianDummy.matrix);
    }
    pedestrianBodies.count = citizens.length;
    pedestrianHeads.count = citizens.length;
    pedestrianBodies.instanceMatrix.needsUpdate = true;
    pedestrianHeads.instanceMatrix.needsUpdate = true;
    if (pedestrianBodies.instanceColor) pedestrianBodies.instanceColor.needsUpdate = true;
  }

  let buildingSignature = "";
  let buildingRebuilds = 0;
  const windowGeometry = new THREE.BoxGeometry(0.22, 0.28, 0.055);
  const balconyGeometry = new THREE.BoxGeometry(0.62, 0.07, 0.10);
  const columnGeometry = new THREE.BoxGeometry(0.11, 1, 0.11);
  const signGeometry = new THREE.BoxGeometry(0.92, 0.28, 0.10);
  const awningGeometry = new THREE.BoxGeometry(1.05, 0.14, 0.48);

  function addBuildingMesh(group, geometry, material, x, y, z, rotationY = 0, castShadow = true) {
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(x, y, z);
    mesh.rotation.y = rotationY;
    mesh.castShadow = castShadow;
    mesh.receiveShadow = true;
    group.add(mesh);
    return mesh;
  }

  function createBuilding(item) {
    const group = new THREE.Group();
    const x = (item.x - 15.5) * 2, z = (item.y - 15.5) * 2;
    group.position.set(x, 0, z);
    const type = item.type;
    if (type === "park") {
      const lawn = new THREE.Mesh(new THREE.BoxGeometry(1.76, 0.20, 1.76), new THREE.MeshStandardMaterial({ color: "#66b95e", roughness: 1 }));
      lawn.position.y = 0.22;
      lawn.receiveShadow = true;
      group.add(lawn);
      const parkTree = new THREE.Group();
      const parkTrunk = new THREE.MeshStandardMaterial({ color: "#8b5b38", roughness: 0.96 });
      const parkCanopy = new THREE.MeshStandardMaterial({ color: "#58ad58", roughness: 1 });
      const parkHighlight = new THREE.MeshStandardMaterial({ color: "#78bd5d", roughness: 1 });
      const trunk = new THREE.Mesh(trunkGeometry, parkTrunk);
      trunk.position.set(-0.32, 0.85, -0.16);
      const crown = new THREE.Mesh(canopyGeometry, parkCanopy);
      crown.position.set(-0.32, 1.55, -0.16);
      const crown2 = new THREE.Mesh(canopySmallGeometry, parkHighlight);
      crown2.position.set(-0.53, 1.78, -0.28);
      parkTree.add(trunk, crown, crown2);
      group.add(parkTree);
      const path = new THREE.Mesh(new THREE.BoxGeometry(1.35, 0.035, 0.24), new THREE.MeshStandardMaterial({ color: "#e9d7a6", roughness: 1 }));
      path.position.set(0.12, 0.34, 0.38);
      path.rotation.y = -0.35;
      group.add(path);
      const bench = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.10, 0.16), new THREE.MeshStandardMaterial({ color: "#a96e42", roughness: 0.8 }));
      bench.position.set(0.36, 0.48, -0.36);
      group.add(bench);
      return group;
    }

    const palettes = {
      home: [
        { wall: "#c9bba5", side: "#a99b87", roof: "#62534b", trim: "#e4dccd", accent: "#687f7c" },
        { wall: "#b9b1a4", side: "#948c80", roof: "#4d5962", trim: "#e6e0d4", accent: "#8a6553" },
        { wall: "#c2c7bd", side: "#9ca69c", roof: "#65594f", trim: "#e9e5da", accent: "#6f8580" },
        { wall: "#d0c2a9", side: "#ad987b", roof: "#59636a", trim: "#eee5d4", accent: "#92765a" }
      ],
      shop: [
        { wall: "#b9aa96", side: "#918170", roof: "#505b60", trim: "#e7dfd1", accent: "#915b48" },
        { wall: "#aeb8b8", side: "#87999a", roof: "#4e5a60", trim: "#e5e9e5", accent: "#6e7f70" },
        { wall: "#c2b5a8", side: "#9c877a", roof: "#5b6269", trim: "#ece4d9", accent: "#a16f54" }
      ],
      industrial: [
        { wall: "#9da7a7", side: "#7f8b8c", roof: "#4e5a60", trim: "#c7cbc5", accent: "#b4864c" },
        { wall: "#b1b1a5", side: "#898f89", roof: "#59636a", trim: "#d7d4c8", accent: "#a47a4e" }
      ],
      civic: [
        { wall: "#b8b2a5", side: "#918b80", roof: "#4f5d67", trim: "#e9e1d2", accent: "#9b8060" },
        { wall: "#c5bca9", side: "#9c927e", roof: "#56666b", trim: "#eee7d9", accent: "#8d6a58" }
      ]
    };
    const family = type === "home" ? "home" : type === "shop" ? "shop" : type === "industrial" ? "industrial" : "civic";
    const paletteList = palettes[family];
    const palette = paletteList[(item.id * 7 + item.x * 3 + item.y) % paletteList.length];
    const level = Math.max(1, item.level || 1);
    const height = type === "home" ? 2.15 + level * 0.52 : type === "shop" ? 2.45 + level * 0.28 : type === "industrial" ? 2.7 : 2.5 + level * 0.36;
    const bodyWidth = type === "industrial" ? 1.52 : 1.34;
    const bodyDepth = type === "industrial" ? 1.48 : 1.34;
    const facadeSurface = type === "industrial" || type === "administrative" ? concreteSurface : brickSurface;
    const wall = new THREE.MeshStandardMaterial({ ...facadeSurface, color: palette.wall, roughness: 0.88, normalScale: new THREE.Vector2(0.34, 0.34) });
    const sideWall = new THREE.MeshStandardMaterial({ ...facadeSurface, color: palette.side, roughness: 0.9, normalScale: new THREE.Vector2(0.3, 0.3) });
    const roofMat = new THREE.MeshStandardMaterial({ ...roofSurface, color: palette.roof, roughness: 0.92, normalScale: new THREE.Vector2(0.48, 0.48) });
    const trimMat = new THREE.MeshStandardMaterial({ color: palette.trim, roughness: 0.68 });
    const accentMat = new THREE.MeshStandardMaterial({ color: palette.accent, roughness: 0.7 });
    const glassMat = new THREE.MeshStandardMaterial({ color: "#d8f5f6", emissive: "#3e9db0", emissiveIntensity: 0.16, roughness: 0.24, metalness: 0.08 });
    windowMaterials.add(glassMat);
    const darkMat = new THREE.MeshStandardMaterial({ color: "#52616b", roughness: 0.9 });
    const baseMat = new THREE.MeshStandardMaterial({ color: "#e8dfc8", roughness: 0.96 });

    addBuildingMesh(group, new THREE.BoxGeometry(1.72, 0.20, 1.72), baseMat, 0, 0.22, 0, 0, false);
    const body = addBuildingMesh(group, new THREE.BoxGeometry(bodyWidth, height, bodyDepth), wall, 0, 0.32 + height / 2, 0);
    body.material = [wall, sideWall, wall, wall, sideWall, sideWall];
    addBuildingMesh(group, new THREE.BoxGeometry(bodyWidth + 0.13, 0.12, bodyDepth + 0.13), trimMat, 0, 0.34 + height, 0, 0, false);

    if (type === "home") {
      // Rectangular two-slope gable roof with a continuous ridge; unlike the
      // former pyramid primitive, this reads as a real residential roof from orbit.
      const roofWidth = bodyWidth + 0.28;
      const roofDepth = bodyDepth + 0.28;
      const ridgeHeight = 0.78;
      const roofGeometry = new THREE.BufferGeometry();
      roofGeometry.setAttribute("position", new THREE.Float32BufferAttribute([
        -roofWidth / 2, 0, -roofDepth / 2, 0, ridgeHeight, -roofDepth / 2,
        0, ridgeHeight, roofDepth / 2, -roofWidth / 2, 0, roofDepth / 2,
        0, ridgeHeight, -roofDepth / 2, roofWidth / 2, 0, -roofDepth / 2,
        roofWidth / 2, 0, roofDepth / 2, 0, ridgeHeight, roofDepth / 2
      ], 3));
      roofGeometry.setAttribute("uv", new THREE.Float32BufferAttribute([
        0,0, .5,0, .5,1, 0,1, 0,0, .5,0, .5,1, 0,1
      ], 2));
      roofGeometry.setIndex([0,1,2,0,2,3,4,5,6,4,6,7]);
      roofGeometry.computeVertexNormals();
      const roof = new THREE.Mesh(roofGeometry, roofMat);
      roof.position.set(0, 0.32 + height, 0);
      roof.castShadow = true;
      roof.receiveShadow = true;
      group.add(roof);
      const ridge = new THREE.Mesh(new THREE.BoxGeometry(0.10, 0.10, roofDepth + 0.04), trimMat);
      ridge.position.set(0, 0.32 + height + ridgeHeight, 0);
      group.add(ridge);
      const balcony = new THREE.InstancedMesh(balconyGeometry, trimMat, Math.max(2, level * 2));
      const balconyDummy = new THREE.Object3D();
      let balconyCount = 0;
      for (let floor = 0; floor < Math.min(level, 3); floor++) {
        const y = 0.95 + floor * 0.52;
        for (const side of [-1, 1]) {
          balconyDummy.position.set(side * 0.02, y, bodyDepth / 2 + 0.10);
          balconyDummy.rotation.set(0, 0, 0);
          balconyDummy.scale.set(1, 1, 1);
          balconyDummy.updateMatrix();
          balcony.setMatrixAt(balconyCount++, balconyDummy.matrix);
        }
      }
      balcony.count = balconyCount;
      balcony.instanceMatrix.needsUpdate = true;
      group.add(balcony);
    } else if (type === "shop") {
      addBuildingMesh(group, signGeometry, accentMat, 0, 1.45, bodyDepth / 2 + 0.075, 0, false);
      addBuildingMesh(group, awningGeometry, roofMat, 0, 1.08, bodyDepth / 2 + 0.18, 0, false);
      for (let stripe = -2; stripe <= 2; stripe++) {
        addBuildingMesh(group, new THREE.BoxGeometry(0.10, 0.15, 0.49), trimMat, stripe * 0.20, 1.08, bodyDepth / 2 + 0.19, 0, false);
      }
    } else if (type === "industrial") {
      const chimney = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.15, 1.2, 8), darkMat);
      chimney.position.set(0.48, 0.95 + height, -0.38);
      chimney.castShadow = true;
      group.add(chimney);
      const tank = new THREE.Mesh(new THREE.CylinderGeometry(0.28, 0.28, 0.62, 10), trimMat);
      tank.position.set(-0.42, 0.65 + height, 0.28);
      group.add(tank);
      const tankCap = new THREE.Mesh(new THREE.SphereGeometry(0.28, 10, 6, 0, Math.PI * 2, 0, Math.PI / 2), roofMat);
      tankCap.position.set(-0.42, 0.96 + height, 0.28);
      group.add(tankCap);
    } else {
      const columns = new THREE.InstancedMesh(columnGeometry, trimMat, 4);
      const columnDummy = new THREE.Object3D();
      let columnIndex = 0;
      for (const px of [-0.48, -0.16, 0.16, 0.48]) {
        columnDummy.position.set(px, 0.92, bodyDepth / 2 + 0.08);
        columnDummy.scale.set(1, 1.65, 1);
        columnDummy.updateMatrix();
        columns.setMatrixAt(columnIndex++, columnDummy.matrix);
      }
      columns.count = columnIndex;
      columns.instanceMatrix.needsUpdate = true;
      group.add(columns);
      addBuildingMesh(group, signGeometry, accentMat, 0, 1.85, bodyDepth / 2 + 0.09, 0, false);
    }

    addOrbitReadyBuildingDetails(THREE, { group, type, height, bodyWidth, bodyDepth, trimMat, accentMat, glassMat, windowGeometry });
    addRealisticArchitecture(THREE, { group, type, height, bodyWidth, bodyDepth, trimMat, accentMat, glassMat, roofMat });
    const fin = new THREE.Mesh(new THREE.BoxGeometry(0.08, height * 0.82, 0.08), accentMat);
    fin.position.set(-bodyWidth / 2 - 0.02, 0.34 + height * 0.52, bodyDepth / 2 + 0.045);
    group.add(fin);
    return group;
  }

  function updateBuildings(city) {
    const next = city.buildings.map(v => [v.id, v.type, v.x, v.y, v.level].join(":")).join("|");
    if (next === buildingSignature) return;
    buildingSignature = next;
    buildingRebuilds++;
    renderer.shadowMap.needsUpdate = true;
    for (const child of [...buildings.children]) {
      buildings.remove(child);
      child.traverse(object => {
        if (object.geometry && ![trunkGeometry, canopyGeometry, canopySmallGeometry, windowGeometry, balconyGeometry, columnGeometry, signGeometry, awningGeometry].includes(object.geometry)) object.geometry.dispose();
        if (object.material) {
          if (Array.isArray(object.material)) object.material.forEach(material => { windowMaterials.delete(material); material.dispose(); });
          else { windowMaterials.delete(object.material); object.material.dispose(); }
        }
      });
    }
    for (const item of city.buildings) buildings.add(createBuilding(item));
  }

  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();
  const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -0.14);
  let width = window.innerWidth, height = window.innerHeight, cameraOrbit = 0, cameraPitch = Math.atan2(38, Math.hypot(48, 48));

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
    atmosphere.resize();
  }

  function updateCamera(cam) {
    const zoom = Math.max(0.525, Math.min(1.875, (cam.zoom || 0.72) * 1.25));
    camera.zoom = zoom;
    const transform = updateCityCameraTransform(camera, cam, height);
    cameraOrbit = transform.orbit;
    cameraPitch = transform.pitch;
  }

  function render(city, view, cam) {
    updateCamera(cam);
    atmosphere.update(city);
    updateBuildings(city);
    updateTraffic(city);
    updatePedestrians(city);
    renderer.render(scene, camera);
  }

  function tileAt(screenX, screenY) {
    pointer.set(screenX / Math.max(1, width) * 2 - 1, -screenY / Math.max(1, height) * 2 + 1);
    raycaster.setFromCamera(pointer, camera);
    const point = new THREE.Vector3();
    if (!raycaster.ray.intersectPlane(groundPlane, point)) return { x: -1, y: -1 };
    return { x: Math.floor(point.x / 2 + 16), y: Math.floor(point.z / 2 + 16) };
  }

  function groundPointAt(screenX, screenY) {
    pointer.set(screenX / Math.max(1, width) * 2 - 1, -screenY / Math.max(1, height) * 2 + 1);
    raycaster.setFromCamera(pointer, camera);
    const point = new THREE.Vector3();
    return raycaster.ray.intersectPlane(groundPlane, point) ? { x: point.x, z: point.z } : null;
  }

  function focusPointAt(screenX, screenY) {
    pointer.set(screenX / Math.max(1, width) * 2 - 1, -screenY / Math.max(1, height) * 2 + 1);
    raycaster.setFromCamera(pointer, camera);
    const hits = raycaster.intersectObjects(buildings.children, true);
    if (hits.length) return { x: hits[0].point.x, y: hits[0].point.y, z: hits[0].point.z };
    return groundPointAt(screenX, screenY);
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
    groundPointAt,
    focusPointAt,
    updateCamera,
    resize,
    getStats() {
      return {
        renderer: "three.js",
        cameraOrbit,
        cameraPitch,
        version: THREE.REVISION,
        visualStyle: "realistic-pbr-city",
        proceduralTextures: 6,
        pbrMaterialSets: 6,
        normalMappedSurfaces: 6,
        roughnessMappedSurfaces: 6,
        texturedBuildingMaterials: 4,
        backgroundCityBuildings: backgroundSkyline.buildingCount,
        backgroundCityWindows: backgroundSkyline.windowCount,
        decorativeTrees: decorativeTreeCount,
        decorativeTreesOutsideBuildableGrid,
        decorativeStreetLights: decorativeStreetLightCount,
        streetFurniturePlacementReady,
        stylizedBuildings: buildings.children.length,
        realisticArchitecture: true,
        trafficVehicles: trafficBodies.count,
        pedestrians: pedestrianBodies.count,
        plots: activeGrassA + activeGrassB,
        roadTiles: activeRoads,
        lockedPlots: lockedGrassCountA + lockedGrassCountB,
        lockedRoadTiles: lockedRoadCount,
        visiblePlots: activeGrassA + activeGrassB + lockedGrassCountA + lockedGrassCountB,
        visibleRoadTiles: activeRoads + lockedRoadCount,
        raisedCurbs: curbInstances.length,
        sidewalkStrips: sidewalkLayer.count,
        crosswalkStripes: crosswalkStripeCount,
        drawCalls: renderer.info.render.calls,
        pixelRatio: renderer.getPixelRatio(),
        shadowAutoUpdate: renderer.shadowMap.autoUpdate,
        buildingRebuilds,
        ...atmosphere.getStats()
      };
    },
    destroy() {
      window.removeEventListener("resize", onResize);
      renderer.dispose();
      atmosphere.dispose();
      streetLights.dispose();
      backgroundSkyline.dispose();
      for (const surface of [grassSurface, asphaltSurface, brickSurface, concreteSurface, roofSurface, sidewalkSurface]) {
        surface.map.dispose();
        surface.normalMap.dispose();
        surface.roughnessMap.dispose();
      }
      canvas.remove();
      sourceCanvas.style.opacity = "";
    }
  };
}
