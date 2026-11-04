const THREE_CDN = "https://cdn.jsdelivr.net/npm/three@0.180.0/build/three.module.js";
const THREE_FALLBACK_CDN = "https://unpkg.com/three@0.180.0/build/three.module.js";
import { createHighGfxBuilding } from "./city-building-high-gfx.js";
import { CITY_TILE_METERS, cityTileToWorld, worldToCityTile } from "./city-world-scale.js";
import { createCityAtmosphere } from "./city-atmosphere.js";
import { createCityCloudLayer } from "./city-cloud-layer.js";
import { updateCityCameraTransform } from "./city-camera-projection.js";
import { createCitySidewalkLayer } from "./city-street-renderer.js";
import { createCityPbrSurfaces } from "./city-pbr-textures.js";
import { createCityBackgroundSkyline } from "./city-background-skyline.js";
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
  scene.fog = new THREE.Fog("#9bd4ee", 480, 1100);
  const camera = new THREE.OrthographicCamera(-40, 40, 25, -25, 0.1, 1400);
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
  const cloudLayer = createCityCloudLayer(THREE, { scene, camera });
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
    new THREE.PlaneGeometry(820, 820),
    new THREE.MeshStandardMaterial({ ...grassSurface, color: "#a6b68a", roughness: 1, normalScale: new THREE.Vector2(0.24, 0.24) })
  );
  ground.rotation.x = -Math.PI / 2;
  ground.position.y = -0.34;
  ground.receiveShadow = true;
  scene.add(ground);
  const grassGeometry = new THREE.BoxGeometry(CITY_TILE_METERS - 0.06, 0.22, CITY_TILE_METERS - 0.06);
  const roadGeometry = new THREE.BoxGeometry(CITY_TILE_METERS - 0.01, 0.16, CITY_TILE_METERS - 0.01);
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
      const px = cityTileToWorld(x - 16);
      const pz = cityTileToWorld(y - 16);
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
      const edgeHalf = CITY_TILE_METERS * 0.47;
      const edges = active ? activePlotEdges : lockedPlotEdges;
      edges.push(
        px - edgeHalf, edgeY, pz - edgeHalf, px + edgeHalf, edgeY, pz - edgeHalf,
        px + edgeHalf, edgeY, pz - edgeHalf, px + edgeHalf, edgeY, pz + edgeHalf,
        px + edgeHalf, edgeY, pz + edgeHalf, px - edgeHalf, edgeY, pz + edgeHalf,
        px - edgeHalf, edgeY, pz + edgeHalf, px - edgeHalf, edgeY, pz - edgeHalf
      );
      for (const [dx, dz, sx, sz] of [[1,0,0.12,CITY_TILE_METERS*0.94],[-1,0,0.12,CITY_TILE_METERS*0.94],[0,1,CITY_TILE_METERS*0.94,0.12],[0,-1,CITY_TILE_METERS*0.94,0.12]]) {
        const nx = x + dx, ny = y + dz;
        if (nx < 0 || ny < 0 || nx >= VISUAL_GRID || ny >= VISUAL_GRID || !(isRoadCell(nx) || isRoadCell(ny))) continue;
        curbInstances.push({ x: px + dx * CITY_TILE_METERS * 0.47, z: pz + dz * CITY_TILE_METERS * 0.47, sx, sz });
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
  const roadMarkings = [];
  const roadCenters = [7.5, 15, 23.5, 31.5, 39.5, 48, 55.5];
  for (const center of roadCenters) {
    const z = cityTileToWorld(center - 16);
    const x = cityTileToWorld(center - 16);
    for (let index = 0; index < VISUAL_GRID; index++) {
      if (!isRoadCell(index) && index % 2 === 0) {
        const along = cityTileToWorld(index - 16);
        roadMarkings.push(along - 1.4, 0.078, z, along + 1.4, 0.078, z);
        roadMarkings.push(x, 0.078, along - 1.4, x, 0.078, along + 1.4);
      }
    }
  }
  addLineLayer(roadMarkings, new THREE.LineBasicMaterial({ color: "#f4e8c2", transparent: true, opacity: 0.86 }));
  const crosswalkStripeCount = 0;
  const lotLines = [];
  for (let y = 0; y < VISUAL_GRID; y += 2) {
    for (let x = 0; x < VISUAL_GRID; x++) {
      if (isRoadCell(y) || isRoadCell(x)) continue;
      const left = cityTileToWorld(x - 16) - CITY_TILE_METERS / 2, right = left + CITY_TILE_METERS;
      const z = cityTileToWorld(y - 16);
      lotLines.push(left, 0.151, z, right, 0.151, z);
    }
  }
  addLineLayer(lotLines, new THREE.LineBasicMaterial({ color: "#f1e8cb", transparent: true, opacity: 0.42 }));
  const boundary = new THREE.LineLoop(
    new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(-32, 0.19, -32), new THREE.Vector3(32, 0.19, -32),
      new THREE.Vector3(32, 0.19, 32), new THREE.Vector3(-32, 0.19, 32)
    ]),
    new THREE.LineBasicMaterial({ color: "#e7bd69", transparent: true, opacity: 0.92 })
  );
  scene.add(boundary);
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
  const decorativeStreetLightCount = 0;
  const sidewalkLayer = createCitySidewalkLayer(THREE, scene, isRoadCell, VISUAL_GRID, sidewalkSurface);
  const streetFurniturePlacementReady = sidewalkLayer.count > 0;
  const buildings = new THREE.Group();
  scene.add(buildings);
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
      const x = cityTileToWorld(vehicle.x);
      const z = cityTileToWorld(vehicle.y);
      const rotation = Number.isFinite(vehicle.heading) ? Math.PI / 2 - vehicle.heading : 0;
      trafficDummy.position.set(x, 0.395, z);
      trafficDummy.rotation.set(0, rotation, 0);
      trafficDummy.scale.set(1.76, 1.5, 2.53);
      trafficDummy.updateMatrix();
      trafficBodies.setMatrixAt(index, trafficDummy.matrix);
      trafficBodies.setColorAt(index, new THREE.Color(vehicle.color || trafficPalette[index % trafficPalette.length]));
      trafficDummy.position.y = 0.57;
      trafficDummy.position.z = z - 0.08;
      trafficDummy.scale.set(1.76, 1.5, 2.53);
      trafficDummy.updateMatrix();
      trafficWindows.setMatrixAt(index, trafficDummy.matrix);
    }
    trafficBodies.count = vehicles.length;
    trafficWindows.count = vehicles.length;
    trafficBodies.instanceMatrix.needsUpdate = true;
    trafficWindows.instanceMatrix.needsUpdate = true;
    if (trafficBodies.instanceColor) trafficBodies.instanceColor.needsUpdate = true;
  }
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
      const x = cityTileToWorld(citizen.x);
      const z = cityTileToWorld(citizen.y);
      const rotation = Number.isFinite(citizen.heading) ? Math.PI / 2 - citizen.heading : 0;
      pedestrianDummy.position.set(x, 0.70, z);
      pedestrianDummy.rotation.set(0, rotation, 0);
      pedestrianDummy.scale.set(1.8, 2.8, 1.8);
      pedestrianDummy.updateMatrix();
      pedestrianBodies.setMatrixAt(index, pedestrianDummy.matrix);
      pedestrianBodies.setColorAt(index, new THREE.Color(pedestrianPalette[(citizen.id - 1) % pedestrianPalette.length]));
      pedestrianDummy.position.set(x, 1.48, z);
      pedestrianDummy.rotation.set(0, 0, 0);
      pedestrianDummy.scale.set(1.3, 1.3, 1.3);
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
  function updateBuildings(city) {
    const next = city.buildings.map(v => [v.id, v.type, v.x, v.y, v.level].join(":")).join("|");
    if (next === buildingSignature) return;
    buildingSignature = next;
    buildingRebuilds++;
    renderer.shadowMap.needsUpdate = true;
    for (const child of [...buildings.children]) {
      buildings.remove(child);
      child.traverse(object => {
        if (object.geometry && ![trunkGeometry, canopyGeometry, canopySmallGeometry].includes(object.geometry)) object.geometry.dispose();
        if (object.material) {
          if (Array.isArray(object.material)) object.material.forEach(material => { windowMaterials.delete(material); material.dispose(); });
          else { windowMaterials.delete(object.material); object.material.dispose(); }
        }
      });
    }
    for (const item of city.buildings) {
  buildings.add(createHighGfxBuilding(THREE, item, {
    trunkGeometry,
    canopyGeometry,
    canopySmallGeometry,
    brickSurface,
    concreteSurface,
    roofSurface,
    windowMaterials
  }));
    }
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
    const zoom = Math.max(0.0625, Math.min(1.875, (cam.zoom || 0.72) * 1.25));
    camera.zoom = zoom;
    const transform = updateCityCameraTransform(camera, cam, height);
    cameraOrbit = transform.orbit;
    cameraPitch = transform.pitch;
  }
  function render(city, view, cam) {
    updateCamera(cam);
    atmosphere.update(city);
    cloudLayer.update(city, atmosphere.getStats());
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
    return { x: worldToCityTile(point.x), y: worldToCityTile(point.z) };
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
    const point = new THREE.Vector3(cityTileToWorld(x), 0.16, cityTileToWorld(y)).project(camera);
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
        worldUnitMeters: 1,
        cityTileMeters: CITY_TILE_METERS,
        cityWorldExtentMeters: CITY_TILE_METERS * 32,
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
      cloudLayer.dispose();
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
