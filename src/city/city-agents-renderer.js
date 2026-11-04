// Instanced vehicle and pedestrian rendering, isolated from city scene orchestration.
export function createCityAgents(THREE, scene) {
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

  return {
    updateTraffic,
    updatePedestrians,
    getTrafficCount: () => trafficBodies.count,
    getPedestrianCount: () => pedestrianBodies.count
  };
}
