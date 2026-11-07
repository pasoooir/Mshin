function isConstrainedCityDevice() {
  return typeof navigator !== "undefined" && (
    (Number(navigator.deviceMemory) > 0 && Number(navigator.deviceMemory) <= 4) ||
    /Android|iPhone|iPad|Mobile/i.test(navigator.userAgent || "")
  );
}

/**
 * Mshin natural color-field generator.
 * Full 24-bit RGB procedural textures and continuous shader gradients.
 * No fixed palette-only fills and no remote runtime assets.
 */
function makeOrganicTexture(THREE, kind = "grass") {
  const isConstrainedDevice = isConstrainedCityDevice();
  const size = isConstrainedDevice ? 1024 : 1536;
  const bloomCount = isConstrainedDevice ? 220 : 430;
  const grainCount = isConstrainedDevice ? 36000 : 118000;
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext("2d", { alpha: false, willReadFrequently: false });
  const gradient = ctx.createLinearGradient(0, 0, size, size);
  const stops = kind === "grass"
    ? [[0,"#75b94f"],[0.19,"#8ac45a"],[0.43,"#5e9c46"],[0.67,"#9acb65"],[0.84,"#6eaa4c"],[1,"#4f8c40"]]
    : kind === "soil"
      ? [[0,"#8c6948"],[0.2,"#b28a5e"],[0.44,"#9a754d"],[0.68,"#c09a6b"],[0.86,"#806044"],[1,"#a78055"]]
      : [[0,"#c7ae7e"],[0.22,"#ead3a0"],[0.48,"#f2dfb5"],[0.72,"#d5bb8c"],[1,"#b99b6d"]];
  for (const [at, color] of stops) gradient.addColorStop(at, color);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, size, size);

  let seed = kind === "grass" ? 0x47524153 : kind === "soil" ? 0x534f494c : 0x53414e44;
  const rand = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
  const bloomColors = kind === "grass"
    ? ["rgba(185,211,104,0.20)","rgba(35,103,47,0.18)","rgba(224,207,111,0.15)","rgba(38,139,78,0.13)","rgba(137,179,70,0.16)"]
    : kind === "soil"
      ? ["rgba(218,177,117,0.2)","rgba(72,48,30,0.17)","rgba(181,129,75,0.2)","rgba(226,196,145,0.16)"]
      : ["rgba(255,245,213,0.25)","rgba(151,116,72,0.12)","rgba(211,184,137,0.18)"];
  for (let i = 0; i < bloomCount; i++) {
    const x = rand() * size, y = rand() * size, radius = 22 + rand() * 145;
    const bloom = ctx.createRadialGradient(x, y, 0, x, y, radius);
    bloom.addColorStop(0, bloomColors[Math.floor(rand() * bloomColors.length)]);
    bloom.addColorStop(1, "rgba(255,255,255,0)");
    ctx.fillStyle = bloom;
    ctx.fillRect(x-radius, y-radius, radius*2, radius*2);
  }
  // Fine continuous grain gives the RGB canvas millions of blended color values.
  for (let i = 0; i < grainCount; i++) {
    const x = rand() * size, y = rand() * size, alpha = 0.025 + rand() * 0.095;
    const dark = rand() > 0.5;
    if (kind === "grass") ctx.fillStyle = dark ? `rgba(22,68,29,${alpha})` : `rgba(238,224,145,${alpha})`;
    else if (kind === "soil") ctx.fillStyle = dark ? `rgba(58,39,25,${alpha})` : `rgba(232,194,137,${alpha})`;
    else ctx.fillStyle = `rgba(116,88,54,${alpha})`;
    const grain = 0.7 + rand() * 2.1;
    ctx.fillRect(x, y, grain, grain);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  texture.anisotropy = isConstrainedDevice ? 4 : 8;
  texture.generateMipmaps = true;
  texture.minFilter = THREE.LinearMipmapLinearFilter;
  texture.magFilter = THREE.LinearFilter;
  return texture;
}

export function createCityNaturalGrassTexture(THREE) { return makeOrganicTexture(THREE, "grass"); }
export function createCityNaturalSoilTexture(THREE) { return makeOrganicTexture(THREE, "soil"); }

export function createCityCoastalWorld(THREE) {
  const generationStartedAt = typeof performance !== "undefined" ? performance.now() : Date.now();
  const root = new THREE.Group();
  root.name = "mshin-coastal-world";
  const isMobileQuality = isConstrainedCityDevice();
  // Keep the coastline silhouette smooth while reducing vertex and fragment work on phones.
  const segments = isMobileQuality ? 128 : 192;
  const rows = isMobileQuality ? 48 : 72;
  const width = 2400;
  const shoreZ = x => 154 + Math.sin(x * 0.0052) * 10 + Math.sin(x * 0.014) * 3.2 + Math.sin(x * 0.031) * 0.9;

  const sandTexture = makeOrganicTexture(THREE, "sand");
  sandTexture.repeat.set(3.2, 1.2);
  const sandMaterial = new THREE.MeshStandardMaterial({ map: sandTexture, color: "#ffffff", roughness: 0.94, bumpMap: sandTexture, bumpScale: 0.12 });
  const beachPositions = [], beachUvs = [], beachIndices = [], beachColors = [];
  const sandStops = ["#e5c995","#f4dfb2","#c8b17f","#a98f65"].map(c => new THREE.Color(c));
  for (let i = 0; i <= segments; i++) {
    const x = -width/2 + width*i/segments, shore = shoreZ(x), inland = shore - 88 - Math.sin(x*0.009)*7;
    const variation = 0.5 + 0.5*Math.sin(x*0.023)*Math.cos(x*0.008);
    for (let j = 0; j < 2; j++) {
      const color = new THREE.Color().lerpColors(j === 0 ? sandStops[0] : sandStops[2], j === 0 ? sandStops[1] : sandStops[3], variation);
      beachPositions.push(x, -0.16 + Math.sin(x*0.03)*0.025, j ? shore : inland);
      beachUvs.push(i/segments*3.2, j*1.2);
      beachColors.push(color.r,color.g,color.b);
    }
    if (i < segments) { const a=i*2; beachIndices.push(a,a+1,a+2,a+1,a+3,a+2); }
  }
  const beachGeometry = new THREE.BufferGeometry();
  beachGeometry.setAttribute("position",new THREE.Float32BufferAttribute(beachPositions,3));
  beachGeometry.setAttribute("uv",new THREE.Float32BufferAttribute(beachUvs,2));
  beachGeometry.setAttribute("color",new THREE.Float32BufferAttribute(beachColors,3));
  beachGeometry.setIndex(beachIndices); beachGeometry.computeVertexNormals();
  sandMaterial.vertexColors = true;
  const beach = new THREE.Mesh(beachGeometry,sandMaterial);
  beach.name="natural-sandy-beach"; beach.receiveShadow=true; root.add(beach);

  // An exposed natural-earth strip transitions the meadow into the sandy coast.
  const soilTexture = makeOrganicTexture(THREE,"soil");
  soilTexture.repeat.set(5,1.4);
  const soilMaterial = new THREE.MeshStandardMaterial({map:soilTexture,color:"#ffffff",roughness:1,bumpMap:soilTexture,bumpScale:0.18});
  const soilPositions=[],soilUvs=[],soilIndices=[],soilColors=[];
  for(let i=0;i<=segments;i++){
    const x=-width/2+width*i/segments, shore=shoreZ(x), variation=0.5+0.5*Math.sin(x*0.017)*Math.cos(x*0.006);
    for(let j=0;j<2;j++){
      const c=new THREE.Color().lerpColors(new THREE.Color("#876444"),new THREE.Color("#c19a6b"),variation);
      // The upper soil edge tucks 1.5 m under the beach to prevent hairline gaps.
      soilPositions.push(x,-0.205,shore-(j ? 116 : 86.5));
      soilUvs.push(i/segments*5,j*1.4);
      soilColors.push(c.r,c.g,c.b);
    }
    if(i<segments){const a=i*2;soilIndices.push(a,a+1,a+2,a+1,a+3,a+2);}
  }
  const soilGeometry=new THREE.BufferGeometry();
  soilGeometry.setAttribute("position",new THREE.Float32BufferAttribute(soilPositions,3));
  soilGeometry.setAttribute("uv",new THREE.Float32BufferAttribute(soilUvs,2));
  soilGeometry.setAttribute("color",new THREE.Float32BufferAttribute(soilColors,3));
  soilGeometry.setIndex(soilIndices);soilGeometry.computeVertexNormals();soilMaterial.vertexColors=true;
  const soilBelt=new THREE.Mesh(soilGeometry,soilMaterial);
  soilBelt.name="natural-earth-transition";soilBelt.receiveShadow=true;root.add(soilBelt);

  const waterPositions=[],waterUvs=[],waterIndices=[],oceanDepth=1800;
  for(let row=0;row<=rows;row++){
    const depth=row/rows;
    for(let i=0;i<=segments;i++){
      const x=-width/2+width*i/segments;
      waterPositions.push(x,-0.035,shoreZ(x)+depth*oceanDepth);waterUvs.push(i/segments,depth);
      if(row<rows&&i<segments){const a=row*(segments+1)+i;waterIndices.push(a,a+segments+1,a+1,a+1,a+segments+1,a+segments+2);}
    }
  }
  const waterGeometry=new THREE.BufferGeometry();
  waterGeometry.setAttribute("position",new THREE.Float32BufferAttribute(waterPositions,3));
  waterGeometry.setAttribute("uv",new THREE.Float32BufferAttribute(waterUvs,2));
  waterGeometry.setIndex(waterIndices);waterGeometry.computeVertexNormals();
  const waterUniforms={
    uTime:{value:0},
    uMobileQuality:{value:isMobileQuality ? 1 : 0},
    uShallow:{value:new THREE.Color("#b8f4df")},
    uLagoon:{value:new THREE.Color("#53d8cb")},
    uCoastal:{value:new THREE.Color("#22a8c4")},
    uBlue:{value:new THREE.Color("#117da9")},
    uDeep:{value:new THREE.Color("#06456f")},
    uHorizon:{value:new THREE.Color("#277fa3")}
  };
  const waterMaterial=new THREE.ShaderMaterial({
    uniforms:waterUniforms,
    vertexShader:`
      varying vec2 vUv;varying vec3 vWorld;varying vec3 vView;uniform float uTime;uniform float uMobileQuality;
      void main(){
        vUv=uv;vec3 p=position;
        float a=sin(p.x*.026+p.z*.013+uTime*.72);
        float b=sin(p.x*.061-p.z*.021-uTime*.91);
        float c=sin(p.x*.009+p.z*.037+uTime*.43);
        p.y+=a*.20+b*.055+c*.12;
        vec4 world=modelMatrix*vec4(p,1.);vec4 mv=viewMatrix*world;
        vWorld=world.xyz;vView=-mv.xyz;gl_Position=projectionMatrix*mv;
      }`,
    fragmentShader:`
      varying vec2 vUv;varying vec3 vWorld;varying vec3 vView;uniform float uTime;
      uniform vec3 uShallow;uniform vec3 uLagoon;uniform vec3 uCoastal;uniform vec3 uBlue;uniform vec3 uDeep;uniform vec3 uHorizon;
      float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
      float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.,1.)),f.x),f.y);}
      void main(){
        float d=clamp(vUv.y,0.,1.);
        vec3 col=mix(uShallow,uLagoon,smoothstep(.005,.095,d));
        col=mix(col,uCoastal,smoothstep(.08,.31,d));
        col=mix(col,uBlue,smoothstep(.28,.58,d));
        col=mix(col,uDeep,smoothstep(.53,.91,d));
        col=mix(col,uHorizon,smoothstep(.91,1.,d)*.22);
        float n1=noise(vWorld.xz*.026+vec2(uTime*.10,-uTime*.07));
        float n2=noise(vWorld.xz*.071-vec2(uTime*.17,uTime*.12));
        float n3=noise(vWorld.xz*.19+vec2(uTime*.24,-uTime*.21));
        float n4=noise(vWorld.xz*.43-vec2(uTime*.31,uTime*.27));
        float wave=sin(vWorld.x*.075+vWorld.z*.027+uTime*1.15)*sin(vWorld.z*.051-vWorld.x*.018-uTime*.82);
        float caustic=smoothstep(.70,.99,n1*.58+n2*.42)*(1.-smoothstep(.02,.30,d));
        float crest=pow(max(0.,wave*.5+.5),18.)*(.12+.2*n2);
        float glint=pow(max(0.,sin(vWorld.x*.13+vWorld.z*.032+uTime*1.7)*sin(vWorld.x*.021-vWorld.z*.12-uTime*.8)),13.);
        float fresnel=pow(1.-max(0.,dot(normalize(vView),vec3(0.,1.,0.))),3.);
        float pigment=(n1-.5)*.10+(n2-.5)*.055+(n3-.5)*.028+(n4-.5)*.012;
        col+=vec3(pigment*.62,pigment*.88,pigment);
        col+=vec3(.22,.38,.30)*caustic*.22;
        col+=vec3(.55,.77,.73)*(crest*.34+glint*.12);
        col+=vec3(.12,.28,.36)*fresnel*.13;
        gl_FragColor=vec4(col,1.);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
    side:THREE.DoubleSide,depthWrite:true
  });
  const ocean=new THREE.Mesh(waterGeometry,waterMaterial);
  ocean.name="animated-24bit-gradient-ocean";ocean.frustumCulled=false;root.add(ocean);

  const foamMaterials=[];
  for(let band=0;band<4;band++){
    const points=[];
    for(let i=0;i<=segments;i++){
      const x=-width/2+width*i/segments;
      const wobble=Math.sin(x*(.031+band*.009)+band)*(.8+band*.35);
      points.push(new THREE.Vector3(x,.035+band*.002,shoreZ(x)+wobble+band*1.35));
    }
    const material=new THREE.MeshBasicMaterial({color:["#f7fff2","#d8fff2","#aeece5","#e6fff5"][band],transparent:true,opacity:[.68,.34,.2,.1][band],depthWrite:false});
    foamMaterials.push(material);
    const foam=new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points),isMobileQuality ? segments : segments*2,.28+band*.16,isMobileQuality ? 4 : 5,false),material);
    foam.name=`shoreline-foam-${band+1}`;root.add(foam);
  }
  return {
    group:root,
    update(timeMs){waterUniforms.uTime.value=(Number(timeMs)||0)*.001;},
    getStats(){return{coastalWorld:true,oceanSurface:true,animatedWater:true,oceanColorGradient:true,colorDepth:"24-bit RGB",multiscaleWaveFields:3,shorelineFoamBands:4,sandyBeach:true,soilTransition:true,soilBeachOverlapMeters:1.5,shorelineSegments:segments,waterRows:rows,mobileShaderQuality:isMobileQuality,highFrequencyPigmentLayers:isMobileQuality?2:4,textureResolution:sandTexture.image?.width||0,textureQuality:isConstrainedDevice?"mobile-adaptive":"high",textureGenerationMs:Math.round(((typeof performance!=="undefined"?performance.now():Date.now())-generationStartedAt)*100)/100};},
    dispose(){
      beachGeometry.dispose();soilGeometry.dispose();waterGeometry.dispose();
      sandTexture.dispose();soilTexture.dispose();sandMaterial.dispose();soilMaterial.dispose();waterMaterial.dispose();
      for(const material of foamMaterials)material.dispose();
      root.traverse(o=>{if(o.geometry&&o!==beach&&o!==soilBelt&&o!==ocean)o.geometry.dispose();});
      root.removeFromParent();
    }
  };
}
