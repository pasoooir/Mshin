// Procedural coastal water, sandy shore and locally generated terrain textures.
export function createCityNaturalSoilTexture(THREE, renderer, base = "#bfa77d") {
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = 256;
  const ctx = canvas.getContext("2d");
  ctx.fillStyle = base;
  ctx.fillRect(0, 0, 256, 256);
  let seed = 0x534f494c;
  const random = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
  for (let i = 0; i < 6200; i++) {
    ctx.fillStyle = random() > 0.5 ? "rgba(235,218,174,.13)" : "rgba(75,58,37,.10)";
    ctx.beginPath();
    ctx.ellipse(random() * 256, random() * 256, .35 + random() * 1.8, .3 + random() * 1.2, random() * Math.PI, 0, Math.PI * 2);
    ctx.fill();
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  texture.anisotropy = Math.min(renderer.capabilities.getMaxAnisotropy(), 4);
  texture.generateMipmaps = true;
  texture.minFilter = THREE.LinearMipmapLinearFilter;
  texture.magFilter = THREE.LinearFilter;
  return texture;
}

export function createCityNaturalGrassTexture(THREE, renderer, sourceTexture) {
  const texture = sourceTexture.clone();
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  texture.anisotropy = Math.min(renderer.capabilities.getMaxAnisotropy(), 4);
  texture.generateMipmaps = true;
  texture.needsUpdate = true;
  return texture;
}

export function createCityCoastalWorld(THREE, { scene, renderer }) {
  const group = new THREE.Group();
  group.name = "mshin-natural-coastal-world";
  const soilTexture = createCityNaturalSoilTexture(THREE, renderer);
  soilTexture.repeat.set(5, 1.2);
  const beachMaterial = new THREE.MeshStandardMaterial({ map: soilTexture, color: "#e8d5a6", roughness: .98 });
  const beach = new THREE.Mesh(new THREE.PlaneGeometry(2200, 170, 96, 8), beachMaterial);
  beach.name = "natural-sandy-beach";
  beach.rotation.x = -Math.PI / 2;
  beach.position.set(0, -.205, -355);
  beach.receiveShadow = true;
  group.add(beach);

  const waterMaterial = new THREE.ShaderMaterial({
    uniforms: {
      uTime: { value: 0 },
      uShallow: { value: new THREE.Color("#70d8cf") },
      uLagoon: { value: new THREE.Color("#27b9c2") },
      uCoastal: { value: new THREE.Color("#168fae") },
      uBlue: { value: new THREE.Color("#0876a7") },
      uDeep: { value: new THREE.Color("#06456f") }
    },
    vertexShader: `
      varying vec2 vUv;
      varying vec3 vWorld;
      uniform float uTime;
      void main() {
        vUv = uv;
        vec3 p = position;
        float multiscaleWaveFields = sin(p.x*.018+uTime*.7)*.10 + sin(p.x*.043-uTime*.42)*.045;
        p.z += multiscaleWaveFields;
        vec4 world = modelMatrix * vec4(p,1.0);
        vWorld = world.xyz;
        gl_Position = projectionMatrix * viewMatrix * world;
      }
    `,
    fragmentShader: `
      uniform float uTime;
      uniform vec3 uShallow; uniform vec3 uLagoon; uniform vec3 uCoastal; uniform vec3 uBlue; uniform vec3 uDeep;
      varying vec2 vUv; varying vec3 vWorld;
      float noise(vec2 p) {
        vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
        float a=fract(sin(dot(i,vec2(127.1,311.7)))*43758.5453);
        float b=fract(sin(dot(i+vec2(1.,0.),vec2(127.1,311.7)))*43758.5453);
        float c=fract(sin(dot(i+vec2(0.,1.),vec2(127.1,311.7)))*43758.5453);
        float d=fract(sin(dot(i+vec2(1.,1.),vec2(127.1,311.7)))*43758.5453);
        return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
      }
      void main() {
        float depth=clamp(vUv.y,0.,1.);
        vec3 colour=mix(uShallow,uLagoon,smoothstep(0.,.18,depth));
        colour=mix(colour,uCoastal,smoothstep(.18,.42,depth));
        colour=mix(colour,uBlue,smoothstep(.42,.72,depth));
        colour=mix(colour,uDeep,smoothstep(.72,1.,depth));
        float wave=sin(vWorld.x*.035+uTime*.8)*.5+sin(vWorld.x*.012-uTime*.34)*.5;
        float detail=noise(vWorld.xz*.055+vec2(uTime*.03,0.));
        float glint=pow(max(0.,wave*.5+detail*.5-.54),7.);
        float shoreline=1.-smoothstep(0.,.12,depth);
        float foam=smoothstep(.56,.76,noise(vWorld.xz*.11+vec2(uTime*.08,0.)))*shoreline;
        colour+=vec3(.22,.32,.34)*glint*.42;
        colour=mix(colour,vec3(.83,.94,.91),foam*.38);
        gl_FragColor=vec4(colour,1.);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }
    `,
    side: THREE.DoubleSide,
    depthWrite: true
  });
  waterMaterial.name = "animated-24bit-gradient-ocean";
  waterMaterial.userData.colorDepth = "24-bit RGB";
  const ocean = new THREE.Mesh(new THREE.PlaneGeometry(2400, 760), waterMaterial);
  ocean.name = "multi-layer-coastal-ocean";
  ocean.rotation.x = -Math.PI / 2;
  ocean.position.set(0, -.265, -820);
  group.add(ocean);

  const foamMaterial = new THREE.MeshBasicMaterial({ color: "#d8f0e8", transparent: true, opacity: .56, depthWrite: false });
  const foamGroup = new THREE.Group();
  foamGroup.name = "shoreline-foam-ribbons";
  for (let band = 0; band < 3; band++) {
    const points = [];
    for (let i = 0; i <= 96; i++) {
      const x = -1080 + i * 22.5;
      const z = -440 + Math.sin(i * .19 + band) * (2.4 + band) + Math.sin(i * .047) * 4;
      points.push(new THREE.Vector3(x, -.245 + band * .001, z));
    }
    const curve = new THREE.CatmullRomCurve3(points);
    const mesh = new THREE.Mesh(new THREE.TubeGeometry(curve, 192, .34 + band * .12, 4, false), foamMaterial);
    mesh.name = "shoreline-foam-" + band;
    foamGroup.add(mesh);
  }
  group.add(foamGroup);
  scene.add(group);
  let elapsed = 0;
  return {
    group,
    update(city, delta = 1 / 60) {
      elapsed += Math.min(.05, Math.max(0, Number(delta) || 0));
      waterMaterial.uniforms.uTime.value = elapsed;
    },
    dispose() {
      scene.remove(group);
      beach.geometry.dispose(); waterMaterial.dispose(); ocean.geometry.dispose(); soilTexture.dispose(); foamMaterial.dispose();
      foamGroup.traverse(object => { if (object.geometry) object.geometry.dispose(); });
    }
  };
}
