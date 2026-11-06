import { getCitySeasonalWeather } from "./city-seasonal-weather.js";
import { getCityAtmosphericColors } from "./city-color-science.js";
const SEASON_FOLIAGE = [
  ["#477c4e", "#6f9b57", "#9caf69"],
  ["#356e42", "#4e8750", "#79a65d"],
  ["#a45f3e", "#c18448", "#d2a15b"],
  ["#627c70", "#84978a", "#a6b5a5"]
];

export function advanceRainSegments(positions, delta, speed, drift, random = Math.random) {
  if (!positions || positions.length % 6 !== 0) throw new TypeError("Rain positions must contain complete line-segment pairs");
  for (let i = 0; i < positions.length; i += 6) {
    let x = positions[i] + drift * delta;
    let y = positions[i + 1] - speed * delta;
    if (y < -18) {
      y = 18 + random() * 12;
      x = (random() - 0.5) * 54;
    }
    if (Math.abs(x) > 29) x *= -0.92;
    const z = positions[i + 2];
    positions[i] = x;
    positions[i + 1] = y;
    positions[i + 3] = x - 0.18;
    positions[i + 4] = y - 0.9;
    positions[i + 5] = z;
  }
}

export function createCityAtmosphere(THREE, { scene, camera, sun, hemisphere, fill, windowMaterials, getViewport, getFoliageMaterials = () => [] }) {
  const initialAtmosphere = getCityAtmosphericColors(720, "spring", "clear");
  scene.background = new THREE.Color(initialAtmosphere.zenith);
  scene.fog.color.set(initialAtmosphere.horizon);

  // A camera-following atmospheric dome provides a continuous zenith-to-horizon
  // gradient and a soft solar halo; it is not a flat skybox or a single RGB fill.
  const skyGeometry = new THREE.SphereGeometry(900, 32, 20);
  const skyMaterial = new THREE.ShaderMaterial({
    uniforms: {
      uZenith: { value: new THREE.Color(initialAtmosphere.zenith) },
      uHorizon: { value: new THREE.Color(initialAtmosphere.horizon) },
      uSunDirection: { value: new THREE.Vector3(-0.35, 0.75, -0.55).normalize() },
      uSunColor: { value: new THREE.Color(initialAtmosphere.sunlight) },
      uSunIntensity: { value: 1.0 }
    },
    vertexShader: `
      varying vec3 vWorldDirection;
      void main() {
        vec4 worldPosition = modelMatrix * vec4(position, 1.0);
        vWorldDirection = normalize(worldPosition.xyz - cameraPosition);
        gl_Position = projectionMatrix * viewMatrix * worldPosition;
      }
    `,
    fragmentShader: `
      uniform vec3 uZenith;
      uniform vec3 uHorizon;
      uniform vec3 uSunDirection;
      uniform vec3 uSunColor;
      uniform float uSunIntensity;
      varying vec3 vWorldDirection;
      void main() {
        vec3 direction = normalize(vWorldDirection);
        float vertical = clamp(direction.y, -0.12, 1.0);
        float gradient = smoothstep(-0.10, 0.76, vertical);
        vec3 sky = mix(uHorizon, uZenith, gradient);
        float sunAngle = max(dot(direction, normalize(uSunDirection)), 0.0);
        float solarDisc = pow(sunAngle, 220.0) * uSunIntensity;
        float solarHalo = pow(sunAngle, 13.0) * uSunIntensity * 0.13;
        float horizonGlow = pow(1.0 - abs(vertical), 5.0) * uSunIntensity * 0.035;
        vec3 colour = sky + uSunColor * (solarDisc + solarHalo + horizonGlow);
        gl_FragColor = vec4(colour, 1.0);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }
    `,
    side: THREE.BackSide,
    depthWrite: false,
    depthTest: false,
    toneMapped: true
  });
  const skyDome = new THREE.Mesh(skyGeometry, skyMaterial);
  skyDome.name = "MshinPhotorealisticAtmosphericSky";
  skyDome.frustumCulled = false;
  skyDome.renderOrder = -1000;
  camera.getWorldPosition(skyDome.position);
  scene.add(skyDome);

  const skyRig = new THREE.Group();
  const sunDisc = new THREE.Mesh(new THREE.SphereGeometry(2.35, 18, 12),
    new THREE.MeshBasicMaterial({ color: "#fff36a", depthWrite: false }));
  const moonDisc = new THREE.Mesh(new THREE.SphereGeometry(1.65, 16, 10),
    new THREE.MeshBasicMaterial({ color: "#dce8ff", depthWrite: false }));
  const starPositions = new Float32Array(72 * 3);
  let starSeed = 0x4d534849;
  const random = () => { starSeed = (Math.imul(starSeed, 1664525) + 1013904223) >>> 0; return starSeed / 4294967296; };
  for (let i = 0; i < 72; i++) {
    starPositions[i * 3] = random() - 0.5;
    starPositions[i * 3 + 1] = 0.44 + random() * 0.12;
    starPositions[i * 3 + 2] = -118;
  }
  const starGeometry = new THREE.BufferGeometry();
  starGeometry.setAttribute("position", new THREE.BufferAttribute(starPositions, 3));
  const stars = new THREE.Points(starGeometry, new THREE.PointsMaterial({
    color: "#e5edff", size: 0.34, sizeAttenuation: false, transparent: true, opacity: 0.9, depthWrite: false
  }));
  skyRig.add(stars, sunDisc, moonDisc);
  camera.add(skyRig);
  scene.add(camera);

  // Camera-space weather fields keep the effect inexpensive and independent of city geometry.
  const weatherRig = new THREE.Group();
  let particleSeed = 0x57454154;
  const particleRandom = () => { particleSeed = (Math.imul(particleSeed, 1664525) + 1013904223) >>> 0; return particleSeed / 4294967296; };
  function makeWeatherGeometry(count, rain = false) {
    const positions = new Float32Array(count * (rain ? 6 : 3));
    for (let i = 0; i < count; i++) {
      const offset = i * (rain ? 6 : 3);
      const x = (particleRandom() - 0.5) * 54;
      const y = (particleRandom() - 0.5) * 34;
      const z = -12 - particleRandom() * 28;
      positions[offset] = x; positions[offset + 1] = y; positions[offset + 2] = z;
      if (rain) { positions[offset + 3] = x - 0.18; positions[offset + 4] = y - 0.9; positions[offset + 5] = z; }
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));
    return geometry;
  }
  const rainGeometry = makeWeatherGeometry(96, true);
  const snowGeometry = makeWeatherGeometry(100);
  const leafGeometry = makeWeatherGeometry(42);
  const rainMaterial = new THREE.LineBasicMaterial({ color: "#9bdcff", transparent: true, opacity: 0.52, depthWrite: false });
  const snowMaterial = new THREE.PointsMaterial({ color: "#f3f8ff", size: 0.22, transparent: true, opacity: 0.88, depthWrite: false });
  const leafMaterial = new THREE.PointsMaterial({ color: "#df9653", size: 0.34, transparent: true, opacity: 0.9, depthWrite: false });
  const rain = new THREE.LineSegments(rainGeometry, rainMaterial);
  const snow = new THREE.Points(snowGeometry, snowMaterial);
  const leaves = new THREE.Points(leafGeometry, leafMaterial);
  const heatHazeGeometry = new THREE.PlaneGeometry(64, 30);
  const heatHazeMaterial = new THREE.MeshBasicMaterial({ color: "#ffd9a6", transparent: true, opacity: 0.06, depthWrite: false, side: THREE.DoubleSide });
  const heatHaze = new THREE.Mesh(heatHazeGeometry, heatHazeMaterial);
  heatHaze.position.set(0, -5, -30);
  weatherRig.add(rain, snow, leaves, heatHaze);
  camera.add(weatherRig);

  let lightingBucket = -1;
  let currentSeason = -1;
  let lastWeatherFrame = 0;
  let lightingStats = { minuteOfDay: 720, daylight: 1, windowGlow: 0.06, phase: "day" };
  let weatherStats = { season: "spring", seasonLabel: "بهار", weather: "clear", intensity: 0, wind: 0, day: 0 };

  function resize() {
    const { width, height } = getViewport();
    const skyWidth = 50 * width / Math.max(1, height);
    sunDisc.position.set(-skyWidth * 0.36, 21, -116);
    moonDisc.position.set(skyWidth * 0.36, 21, -116);
    const positions = starGeometry.getAttribute("position");
    for (let i = 0; i < 72; i++) positions.setXYZ(i, starPositions[i * 3] * skyWidth * 1.8, starPositions[i * 3 + 1] * 42, -118);
    positions.needsUpdate = true;
  }

  function animateField(geometry, delta, speed, drift) {
    const attribute = geometry.getAttribute("position");
    const positions = attribute.array;
    for (let i = 0; i < positions.length; i += 3) {
      positions[i + 1] -= speed * delta;
      positions[i] += drift * delta;
      if (positions[i + 1] < -18) {
        positions[i + 1] = 18 + particleRandom() * 12;
        positions[i] = (particleRandom() - 0.5) * 54;
      }
      if (Math.abs(positions[i]) > 29) positions[i] *= -0.92;
    }
    attribute.needsUpdate = true;
  }
  function animateRain(geometry, delta, speed, drift) {
    const attribute = geometry.getAttribute("position");
    advanceRainSegments(attribute.array, delta, speed, drift, particleRandom);
    attribute.needsUpdate = true;
  }

  function update(city) {
    const seasonal = getCitySeasonalWeather(city);
    weatherStats = { ...seasonal, rainVisible: seasonal.weather === "rain", snowVisible: seasonal.weather === "snow" || seasonal.weather === "frost", leavesVisible: seasonal.weather === "wind" && seasonal.season === "autumn", heatHazeVisible: seasonal.weather === "heat" };
    if (seasonal.seasonIndex !== currentSeason) {
      currentSeason = seasonal.seasonIndex;
      lightingBucket = -1;
      const foliage = getFoliageMaterials() || [];
      for (let i = 0; i < foliage.length; i++) foliage[i].color?.set(SEASON_FOLIAGE[currentSeason][i % 3]);
      sun.color.set(["#fff0c2", "#fff0bd", "#ffe0ad", "#e4edff"][currentSeason]);
    }
    const now = (typeof performance !== "undefined" ? performance.now() : Date.now()) / 1000;
    const delta = lastWeatherFrame ? Math.min(0.06, Math.max(0, now - lastWeatherFrame)) : 0;
    lastWeatherFrame = now;
    rain.visible = weatherStats.rainVisible;
    snow.visible = weatherStats.snowVisible;
    leaves.visible = weatherStats.leavesVisible;
    heatHaze.visible = weatherStats.heatHazeVisible;
    heatHazeMaterial.opacity = 0.025 + seasonal.intensity * 0.065;
    rainMaterial.opacity = 0.28 + seasonal.intensity * 0.38;
    snowMaterial.opacity = 0.5 + seasonal.intensity * 0.45;
    leafMaterial.opacity = 0.45 + seasonal.intensity * 0.5;
    if (rain.visible) animateRain(rainGeometry, delta, 32 + seasonal.intensity * 20, seasonal.wind * 5);
    if (snow.visible) animateField(snowGeometry, delta, 3 + seasonal.intensity * 4, seasonal.wind * 1.6);
    if (leaves.visible) animateField(leafGeometry, delta, 6 + seasonal.intensity * 8, seasonal.wind * 8);

    const minute = 720; // Permanent midday until the city reaches a stable release.
    const daylight = Math.max(0, Math.min(1, Math.sin(minute / 1440 * Math.PI * 2 - Math.PI / 2)));
    const night = 1 - daylight;
    const bucket = Math.round(daylight * 40);
    const atmosphereColours = getCityAtmosphericColors(minute, seasonal.season, seasonal.weather);
    const zenithColour = new THREE.Color(atmosphereColours.zenith);
    const horizonColour = new THREE.Color(atmosphereColours.horizon);
    const sunColour = new THREE.Color(atmosphereColours.sunlight);
    const solarAngle = (minute / 1440) * Math.PI * 2 - Math.PI / 2;
    const sunDirection = new THREE.Vector3(Math.cos(solarAngle), Math.sin(solarAngle), -0.34).normalize();
    const daylightFactor = currentSeason === 3 ? 0.88 : 1;
    sun.intensity = (0.035 + daylight * 3.315) * daylightFactor;
    sun.position.copy(sunDirection).multiplyScalar(150);
    sun.color.copy(sunColour);
    hemisphere.intensity = 0.48 + daylight * 1.72;
    hemisphere.color.copy(zenithColour);
    hemisphere.groundColor.set(seasonal.season === "winter" ? "#89969b" : "#596b4e");
    fill.intensity = 0.22 + daylight * 0.82;
    camera.getWorldPosition(skyDome.position);
    skyMaterial.uniforms.uZenith.value.copy(zenithColour);
    skyMaterial.uniforms.uHorizon.value.copy(horizonColour);
    skyMaterial.uniforms.uSunDirection.value.copy(sunDirection);
    skyMaterial.uniforms.uSunColor.value.copy(sunColour);
    skyMaterial.uniforms.uSunIntensity.value = daylight * (seasonal.weather === "rain" ? 0.38 : 1);
    const viewportWidth = 50 * getViewport().width / Math.max(1, getViewport().height);
    sunDisc.position.set(Math.cos(solarAngle) * viewportWidth * 0.36, -8 + daylight * 35, -116);
    scene.background.copy(zenithColour);
    scene.fog.color.copy(horizonColour);
    const glow = 0.06 + night * 1.02;
    if (bucket !== lightingBucket) {
      lightingBucket = bucket;
      for (const material of windowMaterials) {
        material.emissive.set(night > 0.45 ? "#ffbd70" : "#3e9db0");
        material.emissiveIntensity = glow;
      }
      sunDisc.visible = daylight > 0.08;
      moonDisc.visible = night > 0.28;
      stars.visible = night > 0.72;
    }
    lightingStats = {
      minuteOfDay: minute, daylight: Number(daylight.toFixed(3)), windowGlow: Number(glow.toFixed(3)),
      phase: daylight > 0.72 ? "day" : night > 0.72 ? "night" : "twilight",
      season: seasonal.season, seasonLabel: seasonal.seasonLabel, weather: seasonal.weather,
      skyColor: atmosphereColours.zenith,
      horizonColor: atmosphereColours.horizon,
      sunlightColor: atmosphereColours.sunlight,
      colorDepth: "24-bit RGB",
      skyDome: true
    };
  }

  resize();
  return {
    update, resize,
    getStats() {
      return {
        lighting: { ...lightingStats }, weather: { ...weatherStats },
        visibleStars: stars.visible ? 72 : 0,
        celestialBodies: Number(sunDisc.visible) + Number(moonDisc.visible)
      };
    },
    dispose() {
      camera.remove(skyRig, weatherRig);
      scene.remove(skyDome);
      skyGeometry.dispose(); skyMaterial.dispose();
      starGeometry.dispose(); stars.material.dispose();
      sunDisc.geometry.dispose(); sunDisc.material.dispose();
      moonDisc.geometry.dispose(); moonDisc.material.dispose();
      rainGeometry.dispose(); snowGeometry.dispose(); leafGeometry.dispose(); heatHazeGeometry.dispose();
      rainMaterial.dispose(); snowMaterial.dispose(); leafMaterial.dispose(); heatHazeMaterial.dispose();
    }
  };
}
