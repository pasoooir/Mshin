import { createHighGfxBuilding } from "./city-building-high-gfx.js";
import { CITY_TILE_METERS, cityTileToWorld, worldToCityTile } from "./city-world-scale.js";
import { createCityAtmosphere } from "./city-atmosphere.js";
import { createCityCloudLayer } from "./city-cloud-layer.js";
import { updateCityCameraTransform } from "./city-camera-projection.js";
import { createCitySidewalkLayer } from "./city-street-renderer.js";
import { createCityPbrSurfaces } from "./city-pbr-textures.js";
import { createCityHighwayGateway } from "./city-highway-gateway.js";
import { createCityCoastalWorld, createCityNaturalGrassTexture } from "./city-coastal-world.js";
const VISUAL_GRID = 64;
const ACTIVE_START = 16;
const ACTIVE_END = 48;
const ACTIVE_SIZE = 32;
const isRoadCell = () => false;
export async function createCityThreeRenderer(sourceCanvas) {
  // Load the committed Three.js build from this GitHub Pages repository.
  const THREE = await import("../../vendor/three/build/three.module.min.js");
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
  canvas.setAttribute("aria-label", "Empty 3D city landscape with buildable plots");
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
  const pbrGenerationStartedAt = performance.now();
  const {
    grassSurface, asphaltSurface, brickSurface, concreteSurface, roofSurface, sidewalkSurface
  } = createCityPbrSurfaces(THREE, renderer);
  const pbrGenerationMs = performance.now() - pbrGenerationStartedAt;
  const pbrTextureResolution = grassSurface.map.image?.width || 0;
  const backgroundSkyline = { buildingCount: 0, windowCount: 0, dispose() {} };
  // A continuous meadow replaces the old per-cell grass slabs. Keep the terrain
  // effectively horizon-free at the widest supported zoom so no canvas/backdrop
  // can appear as a blank strip when the camera looks toward the world edge.
  const naturalGrassTexture = createCityNaturalGrassTexture(THREE);
  const grassGroundMap = naturalGrassTexture;
  const grassGroundNormal = grassSurface.normalMap.clone();
  const grassGroundRoughness = grassSurface.roughnessMap.clone();
  for (const texture of [grassGroundMap, grassGroundNormal, grassGroundRoughness]) {
    texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
    texture.repeat.set(texture === grassGroundMap ? 16000 : 2048, texture === grassGroundMap ? 16000 : 2048);
    texture.needsUpdate = true;
  }
  const groundMaterial = new THREE.MeshStandardMaterial({
    map: grassGroundMap,
    normalMap: grassGroundNormal,
    roughnessMap: grassGroundRoughness,
    color: "#ffffff",
    roughness: 1,
    normalScale: new THREE.Vector2(0.3, 0.3)
  });
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(1000000, 1000000), groundMaterial);
  ground.rotation.x = -Math.PI / 2;
  ground.position.y = -0.34;
  ground.receiveShadow = true;
  ground.frustumCulled = false;
  scene.add(ground);

  const coastalWorld = createCityCoastalWorld(THREE);
  scene.add(coastalWorld.group);

  const highwayGateway = createCityHighwayGateway(THREE, { asphaltSurface, concreteSurface });
  scene.add(highwayGateway.group);

  const roadGeometry = new THREE.BoxGeometry(CITY_TILE_METERS - 0.01, 0.16, CITY_TILE_METERS - 0.01);
  const roads = new THREE.InstancedMesh(roadGeometry, new THREE.MeshStandardMaterial({ ...asphaltSurface, roughness: 0.94, metalness: 0.02, normalScale: new THREE.Vector2(0.42, 0.42) }), 1024);
  roads.count = 0;
  roads.receiveShadow = true;
  scene.add(roads);
  const dummy = new THREE.Object3D();
  let activeRoads = 0;
  const curbInstances = [];
  const crosswalkStripeCount = 0;
  const sidewalkLayer = createCitySidewalkLayer(THREE, scene, isRoadCell, VISUAL_GRID, sidewalkSurface);
  const trunkGeometry = new THREE.CylinderGeometry(0.10, 0.15, 1.05, 6);
  const canopyGeometry = new THREE.SphereGeometry(0.62, 9, 7);
  const canopySmallGeometry = new THREE.SphereGeometry(0.42, 8, 6);
  const trunkMaterial = new THREE.MeshStandardMaterial({ color: "#8b5b38", roughness: 0.96 });
  const canopyMaterials = [
    new THREE.MeshStandardMaterial({ color: "#3f9b58", roughness: 1 }),
    new THREE.MeshStandardMaterial({ color: "#58ad58", roughness: 1 }),
    new THREE.MeshStandardMaterial({ color: "#78bd5d", roughness: 1 })
  ];
  // The new-city meadow is intentionally unobstructed: no decorative trees,
  // plot borders, roads, buildings or skyline are visible before player actions.
  const decorativeTreeCount = 0;
  const decorativeTreesOutsideBuildableGrid = 0;
  const decorativeStreetLightCount = 0;
  const streetFurniturePlacementReady = sidewalkLayer.count > 0;
  const buildings = new THREE.Group();
  scene.add(buildings);

  // The starting city remains empty; the highway is the only fixed infrastructure.
  const skylineTreeCount = 0;

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
  const buildingObjects = new Map();
  function updateBuildings(city) {
    const desired = new Map(city.buildings.map((item, index) => {
      const key = String(item.id ?? `index-${index}`);
      return [key, { item, signature: [item.id, item.type, item.x, item.y, item.level].join(":") }];
    }));
    const nextSignature = JSON.stringify([...desired].sort(([a], [b]) => a.localeCompare(b)).map(([key, value]) => [key, value.signature]));
    if (nextSignature === buildingSignature) return;
    buildingSignature = nextSignature;
    buildingRebuilds++;
    renderer.shadowMap.needsUpdate = true;

    const obsoleteGeometries = new Set();
    const obsoleteMaterials = new Set();
    for (const [key, current] of buildingObjects) {
      const wanted = desired.get(key);
      if (wanted && wanted.signature === current.signature) continue;
      buildings.remove(current.group);
      buildingObjects.delete(key);
      current.group.traverse(object => {
        if (object.geometry && ![trunkGeometry, canopyGeometry, canopySmallGeometry].includes(object.geometry)) {
          obsoleteGeometries.add(object.geometry);
        }
        if (Array.isArray(object.material)) object.material.forEach(material => obsoleteMaterials.add(material));
        else if (object.material) obsoleteMaterials.add(object.material);
      });
    }

    // Keep any resources still referenced by unchanged buildings alive.
    buildings.traverse(object => {
      if (object.geometry) obsoleteGeometries.delete(object.geometry);
      if (Array.isArray(object.material)) object.material.forEach(material => obsoleteMaterials.delete(material));
      else if (object.material) obsoleteMaterials.delete(object.material);
    });
    for (const geometry of obsoleteGeometries) geometry.dispose();
    for (const material of obsoleteMaterials) {
      windowMaterials.delete(material);
      material.dispose();
    }

    for (const [key, wanted] of desired) {
      if (buildingObjects.has(key)) continue;
      const group = createHighGfxBuilding(THREE, wanted.item, {
        trunkGeometry,
        canopyGeometry,
        canopySmallGeometry,
        brickSurface,
        concreteSurface,
        roofSurface,
        windowMaterials
      });
      buildings.add(group);
      buildingObjects.set(key, { signature: wanted.signature, group });
    }
  }
  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();
  const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -0.14);
  let width = window.innerWidth, height = window.innerHeight, cameraOrbit = 0, cameraPitch = Math.atan2(38, Math.hypot(48, 48)), lastCameraTargetLimit = 0;
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
    const zoom = Math.max(0.42, Math.min(1.5, cam.zoom || 0.72)) * 1.25;
    cam.zoom = zoom / 1.25;
    const pitch = Math.max(0.24, Math.min(0.96, Number.isFinite(cam.pitch) ? cam.pitch : 0.51));
    const verticalGroundHalf = 25 / (zoom * Math.max(0.23, Math.sin(pitch)));
    const horizontalHalf = 25 * (width / Math.max(1, height)) / zoom;
    const safeRadius = Math.hypot(verticalGroundHalf, horizontalHalf);
    const targetLimit = Math.max(0, CITY_TILE_METERS * VISUAL_GRID / 2 - safeRadius - 12);
    const worldScale = Math.max(1, height) / 50;
    const targetX = Number.isFinite(cam.currentTargetX) ? cam.currentTargetX : Number.isFinite(cam.targetX) ? cam.targetX : -(cam.x || 0) / worldScale;
    const targetZ = Number.isFinite(cam.currentTargetZ) ? cam.currentTargetZ : Number.isFinite(cam.targetZ) ? cam.targetZ : -(cam.y || 0) / worldScale;
    const boundedX = Math.max(-targetLimit, Math.min(targetLimit, targetX));
    const boundedZ = Math.max(-targetLimit, Math.min(targetLimit, targetZ));
    if (Number.isFinite(cam.currentTargetX)) cam.currentTargetX = boundedX;
    else if (Number.isFinite(cam.targetX)) cam.targetX = boundedX;
    else cam.x = -boundedX * worldScale;
    if (Number.isFinite(cam.currentTargetZ)) cam.currentTargetZ = boundedZ;
    else if (Number.isFinite(cam.targetZ)) cam.targetZ = boundedZ;
    else cam.y = -boundedZ * worldScale;
    cam.pitch = pitch;
    camera.zoom = zoom;
    const transform = updateCityCameraTransform(camera, cam, height);
    lastCameraTargetLimit = targetLimit;
    cameraOrbit = transform.orbit;
    cameraPitch = transform.pitch;
  }
  function getBuildingRenderStats() {
    let meshCount = 0;
    let instancedMeshCount = 0;
    const geometries = new Set();
    const materials = new Set();
    const meshCountsByType = {};
    for (const building of buildings.children) {
      const type = building.userData?.type || "unknown";
      let typeMeshCount = 0;
      building.traverse(object => {
        if (!object.isMesh) return;
        meshCount++;
        typeMeshCount++;
        if (object.isInstancedMesh) instancedMeshCount++;
        if (object.geometry) geometries.add(object.geometry);
        if (Array.isArray(object.material)) object.material.forEach(material => materials.add(material));
        else if (object.material) materials.add(object.material);
      });
      meshCountsByType[type] = (meshCountsByType[type] || 0) + typeMeshCount;
    }
    return {
      buildingMeshCountsByType: meshCountsByType,
      buildingMeshCount: meshCount,
      buildingInstancedMeshCount: instancedMeshCount,
      buildingUniqueGeometryCount: geometries.size,
      buildingUniqueMaterialCount: materials.size
    };
  }
  let roadStateKey = "";
  function updateRoads(city) {
    const roadCells = [];
    for (let y = 0; y < city.grid.length; y++) {
      for (let x = 0; x < city.grid[y].length; x++) {
        if (city.grid[y][x] === "road") roadCells.push([x, y]);
      }
    }
    const nextKey = roadCells.map(([x, y]) => x + ":" + y).join("|");
    if (nextKey === roadStateKey) return;
    roadStateKey = nextKey;
    roadCells.forEach(([x, y], index) => {
      dummy.position.set(cityTileToWorld(x), 0.12, cityTileToWorld(y));
      dummy.rotation.set(0, 0, 0);
      dummy.scale.set(1, 1, 1);
      dummy.updateMatrix();
      roads.setMatrixAt(index, dummy.matrix);
    });
    activeRoads = roadCells.length;
    roads.count = activeRoads;
    roads.instanceMatrix.needsUpdate = true;
  }
  function render(city, view, cam) {
    updateCamera(cam);
    updateRoads(city);
    coastalWorld.update(performance.now());
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
        visualStyle: "continuous-realistic-grassland",
        continuousGrassland: true,
        naturalGrassColorTexture: true,
        naturalGrassTextureResolution: naturalGrassTexture.image?.width || 0,
        visiblePlotGridLines: 0,
        groundExtentMeters: 1000000,
        cameraTargetLimitMeters: Number.isFinite(lastCameraTargetLimit) ? lastCameraTargetLimit : 0,
        minimumZoom: 0.42,
        proceduralTextures: 6,
        pbrTextureResolution,
        pbrGenerationMs: Math.round(pbrGenerationMs * 100) / 100,
        pbrMaterialSets: 6,
        normalMappedSurfaces: 6,
        roughnessMappedSurfaces: 6,
        texturedBuildingMaterials: 4,
        backgroundCityBuildings: backgroundSkyline.buildingCount,
      backgroundCityTrees: skylineTreeCount,
        backgroundCityWindows: backgroundSkyline.windowCount,
        decorativeTrees: decorativeTreeCount + skylineTreeCount,
        decorativeTreesOutsideBuildableGrid,
        decorativeStreetLights: decorativeStreetLightCount,
        streetFurniturePlacementReady,
        stylizedBuildings: buildings.children.length,
        ...getBuildingRenderStats(),
        realisticArchitecture: true,
        trafficVehicles: trafficBodies.count,
        pedestrians: pedestrianBodies.count,
        worldUnitMeters: 1,
        cityTileMeters: CITY_TILE_METERS,
        cityWorldExtentMeters: CITY_TILE_METERS * 32,
        plots: ACTIVE_SIZE * ACTIVE_SIZE,
        roadTiles: activeRoads,
        lockedPlots: VISUAL_GRID * VISUAL_GRID - ACTIVE_SIZE * ACTIVE_SIZE,
        lockedRoadTiles: 0,
        visiblePlots: VISUAL_GRID * VISUAL_GRID,
        visibleRoadTiles: activeRoads,
        raisedCurbs: 0,
        sidewalkStrips: sidewalkLayer.count,
        crosswalkStripes: crosswalkStripeCount,
        drawCalls: renderer.info.render.calls,
        renderedTriangles: renderer.info.render.triangles,
        renderedPoints: renderer.info.render.points,
        renderedLines: renderer.info.render.lines,
        geometryCount: renderer.info.memory.geometries,
        textureCount: renderer.info.memory.textures,
        pixelRatio: renderer.getPixelRatio(),
        shadowAutoUpdate: renderer.shadowMap.autoUpdate,
        buildingRebuilds,
        ...atmosphere.getStats(),
        ...highwayGateway.getStats(),
        ...coastalWorld.getStats()
      };
    },
    destroy() {
      window.removeEventListener("resize", onResize);
      highwayGateway.dispose();
      coastalWorld.dispose();
      naturalGrassTexture.dispose();
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
