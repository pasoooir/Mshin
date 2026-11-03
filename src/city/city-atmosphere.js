const DAY_SKY = "#9bd4ee";
const NIGHT_SKY = "#101b35";

export function createCityAtmosphere(THREE, { scene, camera, sun, hemisphere, fill, windowMaterials, getViewport }) {
  const daySky = new THREE.Color(DAY_SKY);
  const nightSky = new THREE.Color(NIGHT_SKY);
  scene.background = daySky.clone();
  scene.fog.color.copy(daySky);

  const skyRig = new THREE.Group();
  const sunDisc = new THREE.Mesh(
    new THREE.SphereGeometry(2.35, 18, 12),
    new THREE.MeshBasicMaterial({ color: "#ffe2a0", depthWrite: false })
  );
  const moonDisc = new THREE.Mesh(
    new THREE.SphereGeometry(1.65, 16, 10),
    new THREE.MeshBasicMaterial({ color: "#dce8ff", depthWrite: false })
  );
  const starPositions = new Float32Array(72 * 3);
  let starSeed = 0x4d534849;
  const nextRandom = () => {
    starSeed = (Math.imul(starSeed, 1664525) + 1013904223) >>> 0;
    return starSeed / 4294967296;
  };
  for (let index = 0; index < 72; index++) {
    starPositions[index * 3] = nextRandom() - 0.5;
    starPositions[index * 3 + 1] = 0.44 + nextRandom() * 0.12;
    starPositions[index * 3 + 2] = -118;
  }
  const starGeometry = new THREE.BufferGeometry();
  starGeometry.setAttribute("position", new THREE.BufferAttribute(starPositions, 3));
  const stars = new THREE.Points(starGeometry, new THREE.PointsMaterial({
    color: "#e5edff", size: 0.34, sizeAttenuation: false, transparent: true, opacity: 0.9, depthWrite: false
  }));
  skyRig.add(stars, sunDisc, moonDisc);
  camera.add(skyRig);
  scene.add(camera);

  let lightingBucket = -1;
  let lightingStats = { minuteOfDay: 495, daylight: 0, windowGlow: 0, phase: "day" };
  function resize() {
    const { width, height } = getViewport();
    const skyWidth = 50 * width / Math.max(1, height);
    sunDisc.position.set(-skyWidth * 0.36, 21, -116);
    moonDisc.position.set(skyWidth * 0.36, 21, -116);
    const positions = starGeometry.getAttribute("position");
    for (let index = 0; index < 72; index++) {
      positions.setXYZ(index, starPositions[index * 3] * skyWidth * 1.8,
        starPositions[index * 3 + 1] * 42, -118);
    }
    positions.needsUpdate = true;
  }

  function update(city) {
    const minute = Number.isFinite(city.minuteOfDay) ? ((city.minuteOfDay % 1440) + 1440) % 1440 : 495;
    const daylight = Math.max(0, Math.min(1, Math.sin(minute / 1440 * Math.PI * 2 - Math.PI / 2)));
    const night = 1 - daylight;
    const bucket = Math.round(daylight * 40);
    sun.intensity = 0.12 + daylight * 3.23;
    hemisphere.intensity = 0.62 + daylight * 1.63;
    fill.intensity = 0.28 + daylight * 0.77;
    if (bucket !== lightingBucket) {
      lightingBucket = bucket;
      const sky = nightSky.clone().lerp(daySky, daylight);
      scene.background.copy(sky);
      scene.fog.color.copy(sky);
      const glow = 0.06 + night * 1.02;
      for (const material of windowMaterials) {
        material.emissive.set(night > 0.45 ? "#ffbd70" : "#3e9db0");
        material.emissiveIntensity = glow;
      }
      sunDisc.visible = daylight > 0.08;
      moonDisc.visible = night > 0.28;
      stars.visible = night > 0.72;
      lightingStats = {
        minuteOfDay: minute,
        daylight: Number(daylight.toFixed(3)),
        windowGlow: Number(glow.toFixed(3)),
        phase: daylight > 0.72 ? "day" : night > 0.72 ? "night" : "twilight",
        skyColor: "#" + sky.getHexString()
      };
    }
  }

  resize();
  return {
    update,
    resize,
    getStats() {
      return {
        lighting: { ...lightingStats },
        visibleStars: stars.visible ? 72 : 0,
        celestialBodies: Number(sunDisc.visible) + Number(moonDisc.visible)
      };
    },
    dispose() {
      camera.remove(skyRig);
      starGeometry.dispose();
      stars.material.dispose();
      sunDisc.geometry.dispose();
      sunDisc.material.dispose();
      moonDisc.geometry.dispose();
      moonDisc.material.dispose();
    }
  };
}
