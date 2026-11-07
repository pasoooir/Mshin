/**
 * Mshin coastal world foundation.
 * Procedural, original shoreline and animated ocean; no remote assets.
 * The playable 32x32 build grid remains untouched. The coast is a natural
 * world boundary outside the southern edge of the initial buildable district.
 */
export function createCityCoastalWorld(THREE) {
  const root = new THREE.Group();
  root.name = "mshin-coastal-world";
  const segments = 96;
  const rows = 18;
  const width = 2200;
  const shoreZ = x => 154 + Math.sin(x * 0.006) * 8 + Math.sin(x * 0.017) * 2.4;

  const sandCanvas = document.createElement("canvas");
  sandCanvas.width = sandCanvas.height = 256;
  const ctx = sandCanvas.getContext("2d");
  ctx.fillStyle = "#d9c18f";
  ctx.fillRect(0, 0, 256, 256);
  let seed = 0x53414e44;
  const random = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
  for (let i = 0; i < 4200; i++) {
    const shade = Math.floor(150 + random() * 65);
    ctx.fillStyle = `rgba(${shade},${shade - 18},${shade - 48},${0.08 + random() * 0.2})`;
    const x = random() * 256, y = random() * 256, size = 0.4 + random() * 1.8;
    ctx.fillRect(x, y, size, size);
  }
  const sandTexture = new THREE.CanvasTexture(sandCanvas);
  sandTexture.colorSpace = THREE.SRGBColorSpace;
  sandTexture.wrapS = sandTexture.wrapT = THREE.RepeatWrapping;
  sandTexture.repeat.set(18, 5);
  sandTexture.anisotropy = 4;
  const sandMaterial = new THREE.MeshStandardMaterial({ map: sandTexture, color: "#f1dfb5", roughness: 0.98 });
  const beachPositions = [], beachUvs = [], beachIndices = [];
  for (let i = 0; i <= segments; i++) {
    const x = -width / 2 + width * i / segments;
    const shore = shoreZ(x);
    const inland = shore - 86 - Math.sin(x * 0.011) * 5;
    beachPositions.push(x, -0.16, inland, x, -0.11, shore);
    beachUvs.push(i / segments * 18, 0, i / segments * 18, 5);
    if (i < segments) {
      const a = i * 2;
      beachIndices.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
    }
  }
  const beachGeometry = new THREE.BufferGeometry();
  beachGeometry.setAttribute("position", new THREE.Float32BufferAttribute(beachPositions, 3));
  beachGeometry.setAttribute("uv", new THREE.Float32BufferAttribute(beachUvs, 2));
  beachGeometry.setIndex(beachIndices);
  beachGeometry.computeVertexNormals();
  const beach = new THREE.Mesh(beachGeometry, sandMaterial);
  beach.name = "natural-sandy-beach";
  beach.receiveShadow = true;
  root.add(beach);

  const waterPositions = [], waterUvs = [], waterIndices = [];
  const oceanDepth = 18000;
  for (let row = 0; row <= rows; row++) {
    const depth = row / rows;
    for (let i = 0; i <= segments; i++) {
      const x = -width / 2 + width * i / segments;
      waterPositions.push(x, -0.02, shoreZ(x) + depth * oceanDepth);
      waterUvs.push(i / segments * 18, depth * 90);
      if (row < rows && i < segments) {
        const a = row * (segments + 1) + i;
        waterIndices.push(a, a + segments + 1, a + 1, a + 1, a + segments + 1, a + segments + 2);
      }
    }
  }
  const waterGeometry = new THREE.BufferGeometry();
  waterGeometry.setAttribute("position", new THREE.Float32BufferAttribute(waterPositions, 3));
  waterGeometry.setAttribute("uv", new THREE.Float32BufferAttribute(waterUvs, 2));
  waterGeometry.setIndex(waterIndices);
  waterGeometry.computeVertexNormals();
  const waterUniforms = { uTime: { value: 0 }, uDeep: { value: new THREE.Color("#087fa0") }, uShallow: { value: new THREE.Color("#36c6c4") } };
  const waterMaterial = new THREE.ShaderMaterial({
    uniforms: waterUniforms,
    vertexShader: `
      varying vec2 vUv;
      varying vec3 vWorld;
      uniform float uTime;
      void main() {
        vUv = uv;
        vec3 p = position;
        float wave = sin(p.x * 0.035 + uTime * 0.75) * 0.13 + sin(p.z * 0.018 - uTime * 0.52) * 0.10;
        p.y += wave;
        vec4 world = modelMatrix * vec4(p, 1.0);
        vWorld = world.xyz;
        gl_Position = projectionMatrix * viewMatrix * world;
      }`,
    fragmentShader: `
      varying vec2 vUv;
      varying vec3 vWorld;
      uniform float uTime;
      uniform vec3 uDeep;
      uniform vec3 uShallow;
      void main() {
        float depth = smoothstep(0.0, 0.22, vUv.y);
        float ripple = sin(vWorld.x * 0.11 + uTime * 1.3) * sin(vWorld.z * 0.055 - uTime * 0.8);
        float glint = pow(max(0.0, ripple), 9.0) * 0.16;
        vec3 colour = mix(uShallow, uDeep, depth);
        colour += vec3(0.36, 0.52, 0.48) * glint;
        gl_FragColor = vec4(colour, 1.0);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
    side: THREE.DoubleSide,
    roughness: 0.26,
    metalness: 0.04
  });
  const ocean = new THREE.Mesh(waterGeometry, waterMaterial);
  ocean.name = "animated-turquoise-ocean";
  ocean.receiveShadow = false;
  ocean.frustumCulled = false;
  root.add(ocean);

  // A narrow translucent wash gives the shoreline a readable, irregular surf edge.
  const foamPoints = [];
  for (let i = 0; i <= segments; i++) {
    const x = -width / 2 + width * i / segments;
    foamPoints.push(new THREE.Vector3(x, 0.015, shoreZ(x) + Math.sin(x * 0.035) * 1.4));
  }
  const foamCurve = new THREE.CatmullRomCurve3(foamPoints);
  const foam = new THREE.Mesh(
    new THREE.TubeGeometry(foamCurve, segments * 2, 0.62, 5, false),
    new THREE.MeshBasicMaterial({ color: "#d9f6e9", transparent: true, opacity: 0.58 })
  );
  foam.name = "shoreline-surf";
  root.add(foam);

  return {
    group: root,
    update(timeMs) { waterUniforms.uTime.value = (Number(timeMs) || 0) * 0.001; },
    getStats() {
      return { coastalWorld: true, oceanSurface: true, animatedWater: true, sandyBeach: true, shorelineSegments: segments, oceanDrawCalls: 2 };
    },
    dispose() {
      beachGeometry.dispose(); waterGeometry.dispose(); foam.geometry.dispose();
      sandTexture.dispose(); sandMaterial.dispose(); waterMaterial.dispose(); foam.material.dispose();
      root.removeFromParent();
    }
  };
}
