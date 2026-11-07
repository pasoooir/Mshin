/**
 * Mshin coastal world — procedural, hand-composed color fields for a vivid
 * SimCity-style coastal scene. All textures are generated locally at runtime.
 */
function makeOrganicTexture(THREE, kind = "grass") {
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = 1024;
  const ctx = canvas.getContext("2d", { alpha: false });
  const g = ctx.createLinearGradient(0, 0, 1024, 1024);
  if (kind === "grass") {
    g.addColorStop(0, "#78b94f"); g.addColorStop(0.28, "#8bc65b");
    g.addColorStop(0.58, "#6eaa45"); g.addColorStop(0.82, "#91c75b");
    g.addColorStop(1, "#5e9d43");
  } else {
    g.addColorStop(0, "#e7d5a8"); g.addColorStop(0.5, "#f3dfb0"); g.addColorStop(1, "#c9ad7c");
  }
  ctx.fillStyle = g; ctx.fillRect(0, 0, 1024, 1024);
  let seed = kind === "grass" ? 0x47524153 : 0x53414e44;
  const rand = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
  // Soft, overlapping color blooms create painted gradients rather than a flat fill.
  for (let i = 0; i < 170; i++) {
    const x = rand() * 1024, y = rand() * 1024, r = 18 + rand() * 115;
    const bloom = ctx.createRadialGradient(x, y, 0, x, y, r);
    if (kind === "grass") {
      const palette = ["rgba(179,207,91,0.22)", "rgba(42,119,53,0.16)", "rgba(220,205,105,0.13)", "rgba(39,139,77,0.12)"];
      bloom.addColorStop(0, palette[Math.floor(rand() * palette.length)]);
    } else bloom.addColorStop(0, "rgba(255,244,207,0.24)");
    bloom.addColorStop(1, "rgba(255,255,255,0)");
    ctx.fillStyle = bloom; ctx.fillRect(x-r, y-r, r*2, r*2);
  }
  // Fine natural grain: deterministic and subtle enough to survive mobile rendering.
  for (let i = 0; i < 52000; i++) {
    const x = rand() * 1024, y = rand() * 1024;
    const a = 0.025 + rand() * 0.075;
    ctx.fillStyle = kind === "grass"
      ? (rand() > 0.5 ? `rgba(24,75,34,${a})` : `rgba(245,230,151,${a})`)
      : `rgba(111,86,54,${a})`;
    ctx.fillRect(x, y, 0.6 + rand() * 1.5, 0.6 + rand() * 1.5);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  texture.anisotropy = Math.min(8, 4);
  texture.generateMipmaps = true;
  texture.minFilter = THREE.LinearMipmapLinearFilter;
  texture.magFilter = THREE.LinearFilter;
  return texture;
}

export function createCityNaturalGrassTexture(THREE) {
  return makeOrganicTexture(THREE, "grass");
}

export function createCityCoastalWorld(THREE) {
  const root = new THREE.Group();
  root.name = "mshin-coastal-world";
  const segments = 192;
  const rows = 72;
  const width = 2400;
  const shoreZ = x => 154 + Math.sin(x * 0.0052) * 10 + Math.sin(x * 0.014) * 3.2 + Math.sin(x * 0.031) * 0.9;

  const sandTexture = makeOrganicTexture(THREE, "sand");
  sandTexture.repeat.set(3.2, 1.2);
  const sandMaterial = new THREE.MeshStandardMaterial({
    map: sandTexture, color: "#fff1cf", roughness: 0.94,
    bumpMap: sandTexture, bumpScale: 0.16
  });
  const beachPositions = [], beachUvs = [], beachIndices = [], beachColors = [];
  const sandStops = [new THREE.Color("#e5c995"), new THREE.Color("#f4dfb2"), new THREE.Color("#c8b17f"), new THREE.Color("#a98f65")];
  for (let i = 0; i <= segments; i++) {
    const x = -width / 2 + width * i / segments;
    const shore = shoreZ(x);
    const inland = shore - 88 - Math.sin(x * 0.009) * 7;
    for (let j = 0; j < 2; j++) {
      const variation = 0.5 + 0.5 * Math.sin(x * 0.023) * Math.cos(x * 0.008);
      const c = new THREE.Color().lerpColors(j === 0 ? sandStops[0] : sandStops[2], j === 0 ? sandStops[1] : sandStops[3], variation);
      beachPositions.push(x, -0.16 + Math.sin(x * 0.03) * 0.025, j ? shore : inland);
      beachUvs.push(i / segments * 3.2, t * 1.2);
      beachColors.push(c.r, c.g, c.b);
    }
    if (i < segments) {
      const a = i * 2;
      beachIndices.push(a, a + 1, a + 2, a + 1, a + 3, a + 2);
    }
  }
  const beachGeometry = new THREE.BufferGeometry();
  beachGeometry.setAttribute("position", new THREE.Float32BufferAttribute(beachPositions, 3));
  beachGeometry.setAttribute("uv", new THREE.Float32BufferAttribute(beachUvs, 2));
  beachGeometry.setAttribute("color", new THREE.Float32BufferAttribute(beachColors, 3));
  beachGeometry.setIndex(beachIndices); beachGeometry.computeVertexNormals();
  sandMaterial.vertexColors = true;
  const beach = new THREE.Mesh(beachGeometry, sandMaterial);
  beach.name = "natural-sandy-beach"; beach.receiveShadow = true; root.add(beach);

  // A continuous color gradient, from transparent aqua shallows to deep cobalt,
  // is shaded with intersecting wave fields and animated sun glitter.
  const waterPositions = [], waterUvs = [], waterIndices = [];
  const oceanDepth = 1800;
  for (let row = 0; row <= rows; row++) {
    const depth = row / rows;
    for (let i = 0; i <= segments; i++) {
      const x = -width / 2 + width * i / segments;
      waterPositions.push(x, -0.035, shoreZ(x) + depth * oceanDepth);
      waterUvs.push(i / segments, depth);
      if (row < rows && i < segments) {
        const a = row * (segments + 1) + i;
        waterIndices.push(a, a + segments + 1, a + 1, a + 1, a + segments + 1, a + segments + 2);
      }
    }
  }
  const waterGeometry = new THREE.BufferGeometry();
  waterGeometry.setAttribute("position", new THREE.Float32BufferAttribute(waterPositions, 3));
  waterGeometry.setAttribute("uv", new THREE.Float32BufferAttribute(waterUvs, 2));
  waterGeometry.setIndex(waterIndices); waterGeometry.computeVertexNormals();
  const waterUniforms = {
    uTime: { value: 0 },
    uShallow: { value: new THREE.Color("#a7eee0") },
    uLagoon: { value: new THREE.Color("#36c8c4") },
    uCoastal: { value: new THREE.Color("#168eae") },
    uDeep: { value: new THREE.Color("#07517e") },
    uHorizon: { value: new THREE.Color("#277fa3") }
  };
  const waterMaterial = new THREE.ShaderMaterial({
    uniforms: waterUniforms,
    vertexShader: `
      varying vec2 vUv; varying vec3 vWorld; varying vec3 vView;
      uniform float uTime;
      void main() {
        vUv = uv;
        vec3 p = position;
        float a = sin(p.x * 0.026 + p.z * 0.013 + uTime * 0.72);
        float b = sin(p.x * 0.061 - p.z * 0.021 - uTime * 0.91);
        float c = sin(p.x * 0.009 + p.z * 0.037 + uTime * 0.43);
        p.y += a * 0.20 + b * 0.055 + c * 0.12;
        vec4 world = modelMatrix * vec4(p, 1.0);
        vec4 mv = viewMatrix * world;
        vWorld = world.xyz; vView = -mv.xyz;
        gl_Position = projectionMatrix * mv;
      }`,
    fragmentShader: `
      varying vec2 vUv; varying vec3 vWorld; varying vec3 vView;
      uniform float uTime;
      uniform vec3 uShallow; uniform vec3 uLagoon; uniform vec3 uCoastal;
      uniform vec3 uDeep; uniform vec3 uHorizon;
      float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
      float noise(vec2 p) {
        vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
        return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),
                   mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.,1.)),f.x),f.y);
      }
      void main() {
        float d = clamp(vUv.y, 0.0, 1.0);
        vec3 col = mix(uShallow, uLagoon, smoothstep(0.015,0.11,d));
        col = mix(col, uCoastal, smoothstep(0.09,0.38,d));
        col = mix(col, uDeep, smoothstep(0.34,0.83,d));
        col = mix(col, uHorizon, smoothstep(0.88,1.0,d)*0.28);
        float n1 = noise(vWorld.xz*0.026 + vec2(uTime*0.10,-uTime*0.07));
        float n2 = noise(vWorld.xz*0.071 - vec2(uTime*0.17,uTime*0.12));
        float wave = sin(vWorld.x*0.075 + vWorld.z*0.027 + uTime*1.15)
                   * sin(vWorld.z*0.051 - vWorld.x*0.018 - uTime*0.82);
        float caustic = smoothstep(0.72,0.98,n1*0.58+n2*0.42) * (1.0-smoothstep(0.02,0.28,d));
        float crest = pow(max(0.0,wave*0.5+0.5),18.0) * (0.12+0.2*n2);
        float glint = pow(max(0.0, sin(vWorld.x*0.13+vWorld.z*0.032+uTime*1.7)
                            * sin(vWorld.x*0.021-vWorld.z*0.12-uTime*0.8)),13.0);
        float fresnel = pow(1.0-max(0.0,dot(normalize(vView),vec3(0.,1.,0.))),3.0);
        col += vec3(0.22,0.38,0.30)*caustic*0.22;
        col += vec3(0.55,0.77,0.73)*(crest*0.34+glint*0.12);
        col += vec3(0.12,0.28,0.36)*fresnel*0.13;
        gl_FragColor = vec4(col,1.0);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
    side: THREE.DoubleSide,
    depthWrite: true
  });
  const ocean = new THREE.Mesh(waterGeometry, waterMaterial);
  ocean.name = "animated-gradient-ocean"; ocean.frustumCulled = false; root.add(ocean);

  // Several irregular foam ribbons fade into wet sand instead of a hard white outline.
  const foamMaterials = [];
  for (let band = 0; band < 3; band++) {
    const points = [];
    for (let i = 0; i <= segments; i++) {
      const x = -width / 2 + width * i / segments;
      const wobble = Math.sin(x * (0.031 + band * 0.009) + band) * (0.8 + band * 0.35);
      points.push(new THREE.Vector3(x, 0.035 + band * 0.002, shoreZ(x) + wobble + band * 1.35));
    }
    const material = new THREE.MeshBasicMaterial({
      color: band === 0 ? "#f4fff0" : "#c8f5e9",
      transparent: true, opacity: [0.68, 0.34, 0.16][band], depthWrite: false
    });
    foamMaterials.push(material);
    const foam = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points), segments * 2, 0.34 + band * 0.2, 5, false), material);
    foam.name = `shoreline-foam-${band + 1}`; root.add(foam);
  }
  return {
    group: root,
    update(timeMs) { waterUniforms.uTime.value = (Number(timeMs) || 0) * 0.001; },
    getStats() {
      return { coastalWorld: true, oceanSurface: true, animatedWater: true, oceanColorGradient: true,
        multiscaleWaveFields: 3, shorelineFoamBands: 3, sandyBeach: true, shorelineSegments: segments,
        trueColorRendering: true };
    },
    dispose() {
      beachGeometry.dispose(); waterGeometry.dispose(); sandTexture.dispose();
      sandMaterial.dispose(); waterMaterial.dispose();
      for (const material of foamMaterials) material.dispose();
      root.traverse(o => { if (o.geometry && o !== beach && o !== ocean) o.geometry.dispose(); });
      root.removeFromParent();
    }
  };
}
