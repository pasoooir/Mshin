/**
 * High-graphics procedural buildings for Mshin city (SimCity BuildIt inspired style).
 * Natural architectural palettes, multi-style roofs, rich facades, roof props, and readable silhouettes
 * from any orbit angle. Kept low-poly + instanced-friendly for mobile WebGL.
 */
export function createHighGfxBuilding(THREE, item, shared = {}) {
  const {
    trunkGeometry,
    canopyGeometry,
    canopySmallGeometry,
    brickSurface,
    concreteSurface,
    roofSurface,
    windowMaterials
  } = shared;

  const group = new THREE.Group();
  const x = (item.x - 15.5) * 2;
  const z = (item.y - 15.5) * 2;
  group.position.set(x, 0, z);
  group.userData = { buildingId: item.id, type: item.type, level: item.level || 1 };

  const type = item.type;
  const level = Math.max(1, Math.min(5, item.level || 1));
  const seed = ((item.id || 1) * 2654435761) >>> 0;

  const rand = (() => {
    let s = seed;
    return () => {
      s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
      return s / 4294967296;
    };
  })();

  const pick = (arr) => arr[Math.floor(rand() * arr.length) % arr.length];

  // ─── SimCity BuildIt inspired vibrant palettes ───────────────────────────
  // Restrained, natural architectural palettes: material identity comes from
  // masonry, timber, plaster, glass and metal rather than neon color blocking.
  const PALETTES = {
    home: [
      { wall:"#d8c8ad", side:"#aa9275", roof:"#555b60", trim:"#f1e8d8", accent:"#657d78", door:"#604638" },
      { wall:"#c9b79d", side:"#93816c", roof:"#6b5146", trim:"#eee5d5", accent:"#7d927f", door:"#49392f" },
      { wall:"#e2d9c8", side:"#b7a991", roof:"#454c54", trim:"#f7f1e7", accent:"#829a9a", door:"#57463b" },
      { wall:"#c7c0b1", side:"#928d81", roof:"#68645d", trim:"#eee9df", accent:"#8b9b91", door:"#514b43" },
      { wall:"#d4c2a5", side:"#a18b6e", roof:"#59605b", trim:"#f0e7d8", accent:"#9a8067", door:"#5a4032" }
    ],
    shop: [
      { wall:"#d6c8b2", side:"#a99478", roof:"#50575b", trim:"#f5eee2", accent:"#3f7778", door:"#4c4239" },
      { wall:"#c5c9c4", side:"#8e9a95", roof:"#48545a", trim:"#f0f1e9", accent:"#b17a4c", door:"#3d4d4b" },
      { wall:"#e0d2bd", side:"#b19b80", roof:"#66594d", trim:"#faf2e6", accent:"#687f8b", door:"#514236" },
      { wall:"#c9c0ad", side:"#958b78", roof:"#555b5c", trim:"#f0eadf", accent:"#8c6e59", door:"#49433b" }
    ],
    industrial: [
      { wall:"#aeb5b2", side:"#788581", roof:"#424b50", trim:"#e0e4df", accent:"#b47b48", door:"#3e4a4a" },
      { wall:"#c1c0b5", side:"#8c9189", roof:"#51585b", trim:"#ece9dd", accent:"#71858a", door:"#4c514b" },
      { wall:"#b7b9aa", side:"#858b79", roof:"#4a5150", trim:"#e9e8d9", accent:"#a36d4b", door:"#41483e" }
    ],
    administrative: [
      { wall:"#d7d3c8", side:"#aaa69b", roof:"#50575c", trim:"#f7f4ec", accent:"#758b8e", door:"#4a4e4c" },
      { wall:"#c8c7bf", side:"#96968f", roof:"#454f58", trim:"#f1efe7", accent:"#9b8063", door:"#454744" },
      { wall:"#ddd4c4", side:"#b1a38f", roof:"#5a5a55", trim:"#faf4e8", accent:"#71847e", door:"#51483d" }
    ],
    service: [
      { wall:"#d1d7d2", side:"#9aa7a1", roof:"#4c565b", trim:"#f2f4ed", accent:"#638b88", door:"#3e514e" },
      { wall:"#d7c9b2", side:"#a89579", roof:"#53575a", trim:"#f5ecdc", accent:"#a77c53", door:"#534438" },
      { wall:"#c5cfc6", side:"#8d9d92", roof:"#4a5552", trim:"#eff3e9", accent:"#718a9a", door:"#3f5047" }
    ],
    power: [
      { wall:"#c1c5c0", side:"#858e8a", roof:"#424a50", trim:"#e9ece5", accent:"#b27b43", door:"#414946" },
      { wall:"#b8c2c2", side:"#7f9292", roof:"#465258", trim:"#e7eeeb", accent:"#8a9a72", door:"#3b4c4d" }
    ],
    water: [
      { wall:"#c3d1d1", side:"#879f9f", roof:"#46575d", trim:"#edf4ef", accent:"#5e9295", door:"#3e565a" },
      { wall:"#c8d2c9", side:"#8fa39b", roof:"#4d5a5a", trim:"#eff3e9", accent:"#6b9b9b", door:"#43534e" }
    ],
    sewage: [
      { wall:"#bfc7bb", side:"#899681", roof:"#4e5650", trim:"#e9eee2", accent:"#9a8661", door:"#46503f" },
      { wall:"#c9c1b1", side:"#958c78", roof:"#555750", trim:"#f0eadc", accent:"#8b927b", door:"#4d473b" }
    ],
    waste: [
      { wall:"#c7c8b6", side:"#929780", roof:"#51574d", trim:"#eff0df", accent:"#a17c4f", door:"#4b503e" },
      { wall:"#c9bca8", side:"#9b8871", roof:"#55534d", trim:"#f0e7d8", accent:"#7f8c70", door:"#4e4237" }
    ],
    police: [
      { wall:"#c8d2d8", side:"#899ba9", roof:"#3e4c5c", trim:"#f0f4f3", accent:"#536f91", door:"#35465b" },
      { wall:"#c5cbd0", side:"#87949f", roof:"#46515e", trim:"#eef1ef", accent:"#9a835f", door:"#3c4852" }
    ],
    fire: [
      { wall:"#d1c4b5", side:"#a28c7a", roof:"#4b4d50", trim:"#f3e9db", accent:"#a94e3f", door:"#593c35" },
      { wall:"#d8c9b7", side:"#ad9279", roof:"#55575a", trim:"#f5ecdf", accent:"#b45c43", door:"#614237" }
    ],
    health: [
      { wall:"#e0ddd4", side:"#b5b2a8", roof:"#566168", trim:"#fbfaf3", accent:"#6b9b91", door:"#4b5b58" },
      { wall:"#d7d3c8", side:"#a8a69b", roof:"#505b61", trim:"#f7f4eb", accent:"#8b9f9b", door:"#485553" }
    ],
    education: [
      { wall:"#d5cbbb", side:"#a69781", roof:"#4d5960", trim:"#f5efe3", accent:"#7d8f8c", door:"#51463b" },
      { wall:"#d7d1c1", side:"#a69c88", roof:"#535a5e", trim:"#f4f0e5", accent:"#9c805e", door:"#51483e" }
    ]
  };

  const serviceTypes = new Set(["power", "water", "sewage", "waste", "police", "fire", "health", "education", "service"]);
  const paletteKey = serviceTypes.has(type) ? (PALETTES[type] ? type : "service") : type;
  const paletteList = PALETTES[paletteKey] || PALETTES.home;
  const palette = paletteList[(seed + level) % paletteList.length];

  function mat(color, opts = {}) {
    return new THREE.MeshStandardMaterial({
      color,
      roughness: opts.roughness ?? 0.70,
      metalness: opts.metalness ?? 0.02,
      emissive: opts.emissive ?? "#000000",
      emissiveIntensity: opts.emissiveIntensity ?? 0,
      transparent: opts.transparent ?? false,
      opacity: opts.opacity ?? 1,
      ...(opts.extra || {})
    });
  }

  function add(geometry, material, px, py, pz, ry = 0, cast = true) {
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(px, py, pz);
    mesh.rotation.y = ry;
    mesh.castShadow = cast;
    mesh.receiveShadow = true;
    group.add(mesh);
    return mesh;
  }

  function addGableRoof(w, d, ridgeH, roofMat, trimMat, baseY) {
    const geo = new THREE.BufferGeometry();
    const hw = w / 2, hd = d / 2;
    geo.setAttribute("position", new THREE.Float32BufferAttribute([
      -hw, 0, -hd,  0, ridgeH, -hd,  0, ridgeH,  hd,  -hw, 0,  hd,
       0, ridgeH, -hd,  hw, 0, -hd,  hw, 0,  hd,   0, ridgeH,  hd
    ], 3));
    geo.setIndex([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7]);
    geo.computeVertexNormals();
    const roof = new THREE.Mesh(geo, roofMat);
    roof.position.set(0, baseY, 0);
    roof.castShadow = true;
    roof.receiveShadow = true;
    group.add(roof);
    add(new THREE.BoxGeometry(0.08, 0.08, d + 0.06), trimMat, 0, baseY + ridgeH, 0, 0, false);
    add(new THREE.BoxGeometry(0.06, ridgeH * 0.92, d * 0.98), mat(palette.wall, { roughness: 0.88 }), -hw + 0.02, baseY + ridgeH * 0.46, 0, 0, false);
    add(new THREE.BoxGeometry(0.06, ridgeH * 0.92, d * 0.98), mat(palette.side, { roughness: 0.9 }), hw - 0.02, baseY + ridgeH * 0.46, 0, 0, false);
  }

  function addHipRoof(w, d, ridgeH, roofMat, baseY) {
    const geo = new THREE.BufferGeometry();
    const hw = w / 2, hd = d / 2;
    geo.setAttribute("position", new THREE.Float32BufferAttribute([
      -hw, 0, -hd,  hw, 0, -hd,  0, ridgeH, 0,
       hw, 0, -hd,  hw, 0,  hd,  0, ridgeH, 0,
       hw, 0,  hd, -hw, 0,  hd,  0, ridgeH, 0,
      -hw, 0,  hd, -hw, 0, -hd,  0, ridgeH, 0
    ], 3));
    geo.setIndex([0,1,2, 3,4,5, 6,7,8, 9,10,11]);
    geo.computeVertexNormals();
    const roof = new THREE.Mesh(geo, roofMat);
    roof.position.set(0, baseY, 0);
    roof.castShadow = true;
    roof.receiveShadow = true;
    group.add(roof);
  }

  function addFlatRoof(w, d, roofMat, trimMat, baseY, withParapet = true) {
    add(new THREE.BoxGeometry(w, 0.12, d), roofMat, 0, baseY + 0.06, 0, 0, true);
    if (withParapet) {
      const t = 0.07;
      add(new THREE.BoxGeometry(w + 0.08, 0.18, t), trimMat, 0, baseY + 0.18, d / 2, 0, false);
      add(new THREE.BoxGeometry(w + 0.08, 0.18, t), trimMat, 0, baseY + 0.18, -d / 2, 0, false);
      add(new THREE.BoxGeometry(t, 0.18, d), trimMat, w / 2, baseY + 0.18, 0, 0, false);
      add(new THREE.BoxGeometry(t, 0.18, d), trimMat, -w / 2, baseY + 0.18, 0, 0, false);
    }
  }

  function addWindows(bodyW, bodyD, height, glassMat, trimMat, floors, cols) {
    const winW = type === "home" ? 0.34 : 0.30;
    const winH = type === "home" ? 0.42 : 0.36;
    const winGeo = new THREE.BoxGeometry(winW, winH, 0.04);
    const frameGeo = new THREE.BoxGeometry(winW + 0.04, winH + 0.04, 0.03);
    const instances = floors * cols * 4;
    const windows = new THREE.InstancedMesh(winGeo, glassMat, instances);
    const frames = new THREE.InstancedMesh(frameGeo, trimMat, instances);
    const dummy = new THREE.Object3D();
    let idx = 0;
    const floorH = (height - 0.35) / Math.max(1, floors);
    for (let f = 0; f < floors; f++) {
      const y = 0.55 + f * floorH + floorH * 0.35;
      for (let c = 0; c < cols; c++) {
        const u = cols === 1 ? 0 : -0.32 + c * (0.64 / (cols - 1));
        for (const side of [1, -1]) {
          dummy.position.set(u, y, side * (bodyD / 2 + 0.025));
          dummy.rotation.set(0, side < 0 ? Math.PI : 0, 0);
          dummy.scale.set(1, 1, 1);
          dummy.updateMatrix();
          windows.setMatrixAt(idx, dummy.matrix);
          frames.setMatrixAt(idx, dummy.matrix);
          idx++;
        }
        for (const side of [1, -1]) {
          dummy.position.set(side * (bodyW / 2 + 0.025), y, u);
          dummy.rotation.set(0, side > 0 ? Math.PI / 2 : -Math.PI / 2, 0);
          dummy.scale.set(1, 1, 1);
          dummy.updateMatrix();
          windows.setMatrixAt(idx, dummy.matrix);
          frames.setMatrixAt(idx, dummy.matrix);
          idx++;
        }
      }
    }
    windows.count = idx;
    frames.count = idx;
    windows.instanceMatrix.needsUpdate = true;
    frames.instanceMatrix.needsUpdate = true;
    windows.castShadow = false;
    frames.castShadow = false;
    group.add(frames, windows);
  }

  function addDoor(bodyD, doorMat, trimMat) {
    add(new THREE.BoxGeometry(0.32, 0.62, 0.05), doorMat, 0, 0.52, bodyD / 2 + 0.03, 0, false);
    add(new THREE.BoxGeometry(0.38, 0.08, 0.04), trimMat, 0, 0.86, bodyD / 2 + 0.035, 0, false);
    add(new THREE.BoxGeometry(0.04, 0.04, 0.06), mat("#c0a060", { metalness: 0.4, roughness: 0.45 }), 0.1, 0.5, bodyD / 2 + 0.06, 0, false);
  }

  function addBalcony(bodyW, bodyD, y, trimMat, accentMat) {
    const plat = new THREE.BoxGeometry(0.55, 0.06, 0.32);
    const rail = new THREE.BoxGeometry(0.55, 0.05, 0.04);
    for (const face of [
      { x: 0, z: bodyD / 2 + 0.14, ry: 0 },
      { x: 0, z: -bodyD / 2 - 0.14, ry: Math.PI }
    ]) {
      add(plat, trimMat, face.x, y, face.z, face.ry, false);
      add(rail, accentMat, face.x, y + 0.12, face.z + (face.ry === 0 ? 0.14 : -0.14), face.ry, false);
    }
  }

  if (type === "park") {
    const lawn = mat("#39ed43", { roughness: 0.88, emissive: "#168d20", emissiveIntensity: 0.12 });
    add(new THREE.BoxGeometry(1.78, 0.18, 1.78), lawn, 0, 0.2, 0, 0, false);
    add(new THREE.BoxGeometry(0.28, 0.04, 1.5), mat("#ffe36a", { roughness: 0.78 }), 0.15, 0.3, 0, -0.25, false);
    if (trunkGeometry && canopyGeometry) {
      for (const [tx, tz] of [[-0.45, -0.35], [0.4, 0.3], [-0.2, 0.45]]) {
        const trunk = new THREE.Mesh(trunkGeometry, mat("#8b5b38", { roughness: 0.95 }));
        trunk.position.set(tx, 0.75, tz);
        trunk.scale.set(0.85, 0.9, 0.85);
        group.add(trunk);
        const crown = new THREE.Mesh(canopyGeometry, mat(pick(["#16e84a", "#42f52b", "#00c978", "#9bff24", "#00e8a8"]), { roughness: 1 }));
        crown.position.set(tx, 1.4, tz);
        group.add(crown);
        if (canopySmallGeometry) {
          const hi = new THREE.Mesh(canopySmallGeometry, mat("#b0ff38", { roughness: 0.86, emissive: "#38a51b", emissiveIntensity: 0.12 }));
          hi.position.set(tx - 0.15, 1.6, tz - 0.1);
          group.add(hi);
        }
      }
    }
    add(new THREE.BoxGeometry(0.5, 0.08, 0.16), mat("#a06a40", { roughness: 0.8 }), 0.35, 0.42, -0.45, 0.3, false);
    add(new THREE.BoxGeometry(0.08, 0.28, 0.08), mat("#8a5a30"), 0.18, 0.32, -0.45, 0, false);
    add(new THREE.BoxGeometry(0.08, 0.28, 0.08), mat("#8a5a30"), 0.52, 0.32, -0.45, 0, false);
    for (let i = 0; i < 5; i++) {
      const fx = -0.6 + rand() * 1.2;
      const fz = -0.55 + rand() * 0.4;
      add(new THREE.SphereGeometry(0.06, 6, 5), mat(pick(["#ff2f9b", "#ffe51f", "#a83dff", "#13dfff", "#ff6a18"])), fx, 0.38, fz, 0, false);
    }
    return group;
  }

  let height, bodyW, bodyD, floors, cols;
  if (type === "home") {
    height = 2.55 + level * 0.72;
    bodyW = 1.66;
    bodyD = 1.62;
    floors = Math.min(6, 2 + level);
    cols = 4;
  } else if (type === "shop") {
    height = 2.65 + level * 0.48;
    bodyW = 1.76;
    bodyD = 1.70;
    floors = Math.min(4, 2 + Math.floor(level / 2));
    cols = 4;
  } else if (type === "industrial") {
    height = 2.85 + level * 0.52;
    bodyW = 1.78;
    bodyD = 1.76;
    floors = 3 + Math.floor(level / 2);
    cols = 4;
  } else if (type === "administrative") {
    height = 3.0 + level * 0.62;
    bodyW = 1.72;
    bodyD = 1.68;
    floors = 3 + level;
    cols = 4;
  } else {
    // Civic and utility buildings use the same generous contemporary footprint.
    height = 2.65 + level * 0.45;
    bodyW = 1.68;
    bodyD = 1.62;
    floors = 3 + Math.floor(level / 2);
    cols = 4;
  }

  const facadeSurf = (type === "industrial" || type === "administrative") ? (concreteSurface || {}) : (brickSurface || {});
  const wall = new THREE.MeshStandardMaterial({
    ...facadeSurf,
    color: palette.wall,
    roughness: 0.70,
    normalScale: facadeSurf.normalMap ? new THREE.Vector2(0.35, 0.35) : undefined
  });
  const sideWall = new THREE.MeshStandardMaterial({
    ...facadeSurf,
    color: palette.side,
    roughness: 0.73,
    normalScale: facadeSurf.normalMap ? new THREE.Vector2(0.3, 0.3) : undefined
  });
  const roofMat = new THREE.MeshStandardMaterial({
    ...(roofSurface || {}),
    color: palette.roof,
    roughness: 0.68,
    normalScale: roofSurface?.normalMap ? new THREE.Vector2(0.45, 0.45) : undefined
  });
  const trimMat = mat(palette.trim, { roughness: 0.65 });
  const accentMat = mat(palette.accent, { roughness: 0.7 });
  const doorMat = mat(palette.door, { roughness: 0.75 });
  const glassMat = mat("#a8f8ff", {
    roughness: 0.12,
    metalness: 0.08,
    emissive: "#18cfff",
    emissiveIntensity: 0.42,
    transparent: true,
    opacity: 0.88
  });
  if (windowMaterials) windowMaterials.add(glassMat);

  add(new THREE.BoxGeometry(1.78, 0.18, 1.78), mat("#e8e0d0", { roughness: 0.95 }), 0, 0.2, 0, 0, false);

  const body = add(new THREE.BoxGeometry(bodyW, height, bodyD), wall, 0, 0.28 + height / 2, 0);
  body.material = [wall, sideWall, wall, wall, sideWall, sideWall];

  add(new THREE.BoxGeometry(bodyW + 0.12, 0.1, bodyD + 0.12), trimMat, 0, 0.28 + height, 0, 0, false);
  addDoor(bodyD, doorMat, trimMat);
  addWindows(bodyW, bodyD, height, glassMat, trimMat, floors, cols);

  const roofBaseY = 0.28 + height;

  if (type === "home") {
    if (seed % 3 === 0) {
      addHipRoof(bodyW + 0.32, bodyD + 0.32, 0.62 + level * 0.06, roofMat, roofBaseY);
    } else {
      addGableRoof(bodyW + 0.3, bodyD + 0.3, 0.7 + level * 0.08, roofMat, trimMat, roofBaseY);
    }
    const chimX = (seed % 2 === 0 ? 0.35 : -0.35);
    add(new THREE.BoxGeometry(0.18, 0.45, 0.18), mat("#8a7060"), chimX, roofBaseY + 0.85, -0.2);
    add(new THREE.BoxGeometry(0.22, 0.06, 0.22), trimMat, chimX, roofBaseY + 1.1, -0.2, 0, false);
    if (level >= 2) addBalcony(bodyW, bodyD, 0.55 + ((height - 0.35) / floors) * 1.1, trimMat, accentMat);
    if (level >= 3) addBalcony(bodyW, bodyD, 0.55 + ((height - 0.35) / floors) * 2.1, trimMat, accentMat);
    if (level >= 4) addBalcony(bodyW, bodyD, 0.55 + ((height - 0.35) / floors) * 3.1, trimMat, accentMat);
    add(new THREE.BoxGeometry(0.9, 0.08, 0.22), mat("#25e84b", { roughness: 0.82 }), 0, 0.32, bodyD / 2 + 0.28, 0, false);
    add(new THREE.BoxGeometry(0.5, 0.08, 0.22), mat("#d8d0c0"), 0, 0.3, bodyD / 2 + 0.18, 0, false);
  } else if (type === "shop") {
    addFlatRoof(bodyW + 0.2, bodyD + 0.2, roofMat, trimMat, roofBaseY, true);
    const awning = mat(palette.accent, { roughness: 0.75 });
    add(new THREE.BoxGeometry(bodyW * 0.95, 0.08, 0.55), awning, 0, 1.15, bodyD / 2 + 0.22, 0, false);
    for (let s = -2; s <= 2; s++) {
      add(new THREE.BoxGeometry(0.1, 0.09, 0.52), trimMat, s * 0.22, 1.15, bodyD / 2 + 0.22, 0, false);
    }
    add(new THREE.BoxGeometry(bodyW * 0.72, 0.7, 0.05), glassMat, 0, 0.85, bodyD / 2 + 0.04, 0, false);
    add(new THREE.BoxGeometry(bodyW * 0.7, 0.22, 0.08), accentMat, 0, 1.55, bodyD / 2 + 0.08, 0, false);
    add(new THREE.BoxGeometry(0.35, 0.22, 0.28), mat("#b0b8c0"), 0.35, roofBaseY + 0.28, -0.25);
    add(new THREE.CylinderGeometry(0.08, 0.08, 0.06, 8), mat("#9098a0"), 0.35, roofBaseY + 0.42, -0.25, 0, false);
  } else if (type === "industrial") {
    addFlatRoof(bodyW + 0.18, bodyD + 0.18, roofMat, trimMat, roofBaseY, true);
    add(new THREE.CylinderGeometry(0.12, 0.16, 1.35, 10), mat("#4a545c"), 0.5, roofBaseY + 0.7, -0.35);
    add(new THREE.CylinderGeometry(0.14, 0.14, 0.08, 10), mat("#6a747c"), 0.5, roofBaseY + 1.4, -0.35, 0, false);
    add(new THREE.CylinderGeometry(0.28, 0.28, 0.7, 12), mat("#8a9aa0"), -0.4, roofBaseY + 0.4, 0.25);
    add(new THREE.SphereGeometry(0.28, 10, 6, 0, Math.PI * 2, 0, Math.PI / 2), roofMat, -0.4, roofBaseY + 0.75, 0.25, 0, false);
    add(new THREE.BoxGeometry(0.7, 0.35, 0.25), mat("#6a7078"), 0, 0.45, bodyD / 2 + 0.12, 0, false);
  } else if (type === "administrative") {
    addFlatRoof(bodyW + 0.22, bodyD + 0.22, roofMat, trimMat, roofBaseY, true);
    for (const cx of [-0.42, -0.14, 0.14, 0.42]) {
      add(new THREE.CylinderGeometry(0.06, 0.07, height * 0.85, 8), trimMat, cx, 0.35 + height * 0.42, bodyD / 2 + 0.08);
    }
    add(new THREE.BoxGeometry(bodyW + 0.15, 0.18, 0.12), accentMat, 0, roofBaseY + 0.15, bodyD / 2 + 0.05, 0, false);
    add(new THREE.CylinderGeometry(0.025, 0.03, 1.1, 6), mat("#c0c0c0", { metalness: 0.5 }), 0.45, roofBaseY + 0.7, -0.3);
    add(new THREE.BoxGeometry(0.28, 0.16, 0.03), accentMat, 0.58, roofBaseY + 1.05, -0.3, 0, false);
  } else {
    addFlatRoof(bodyW + 0.18, bodyD + 0.18, roofMat, trimMat, roofBaseY, true);
    const roofY = roofBaseY + 0.2;
    if (type === "police") {
      add(new THREE.CylinderGeometry(0.1, 0.12, 0.18, 10), accentMat, 0, roofY + 0.1, 0);
      add(new THREE.SphereGeometry(0.12, 10, 8), mat("#e8f4ff", { emissive: "#4080ff", emissiveIntensity: 0.9 }), 0, roofY + 0.28, 0, 0, false);
      add(new THREE.CylinderGeometry(0.025, 0.03, 0.9, 6), trimMat, 0.4, roofY + 0.5, -0.3);
    } else if (type === "fire") {
      add(new THREE.BoxGeometry(0.32, 1.1, 0.32), accentMat, 0.4, roofY + 0.55, -0.3);
      add(new THREE.BoxGeometry(0.4, 0.1, 0.38), trimMat, 0.4, roofY + 1.15, -0.3, 0, false);
      add(new THREE.CylinderGeometry(0.05, 0.05, 0.7, 8), mat("#c0c0c0"), 0.4, roofY + 1.5, -0.3);
    } else if (type === "health") {
      add(new THREE.BoxGeometry(0.16, 0.7, 0.16), trimMat, 0, roofY + 0.4, 0, 0, false);
      add(new THREE.BoxGeometry(0.7, 0.16, 0.16), trimMat, 0, roofY + 0.4, 0, 0, false);
      add(new THREE.BoxGeometry(0.42, 0.08, 0.42), accentMat, 0, roofY + 0.05, 0, 0, false);
    } else if (type === "education") {
      add(new THREE.CylinderGeometry(0.26, 0.26, 0.12, 16), accentMat, 0, roofY + 0.15, 0);
      add(new THREE.BoxGeometry(0.03, 0.18, 0.03), trimMat, 0, roofY + 0.28, 0.06, 0, false);
      add(new THREE.CylinderGeometry(0.025, 0.03, 0.95, 6), trimMat, 0.4, roofY + 0.5, -0.3);
      add(new THREE.BoxGeometry(0.3, 0.18, 0.04), accentMat, 0.55, roofY + 0.8, -0.3, 0, false);
    } else if (type === "power") {
      for (const px of [-0.3, 0.3]) {
        add(new THREE.CylinderGeometry(0.07, 0.09, 0.4, 8), accentMat, px, roofY + 0.25, 0);
        add(new THREE.CylinderGeometry(0.11, 0.11, 0.07, 8), trimMat, px, roofY + 0.48, 0, 0, false);
      }
      add(new THREE.BoxGeometry(0.85, 0.06, 0.1), trimMat, 0, roofY + 0.55, 0, 0, false);
    } else if (type === "water") {
      add(new THREE.CylinderGeometry(0.32, 0.32, 0.55, 14), accentMat, 0, roofY + 0.3, 0);
      add(new THREE.SphereGeometry(0.32, 12, 7, 0, Math.PI * 2, 0, Math.PI / 2), trimMat, 0, roofY + 0.58, 0, 0, false);
      add(new THREE.CylinderGeometry(0.05, 0.05, 0.55, 8), mat("#60a0c0"), 0.38, roofY + 0.2, 0.3);
    } else if (type === "sewage") {
      for (const px of [-0.28, 0.28]) {
        add(new THREE.CylinderGeometry(0.1, 0.12, 0.5, 10), accentMat, px, roofY + 0.28, 0);
        add(new THREE.TorusGeometry(0.1, 0.03, 6, 12), trimMat, px, roofY + 0.55, 0, 0, false);
      }
    } else if (type === "waste") {
      for (const px of [-0.3, 0, 0.3]) {
        add(new THREE.BoxGeometry(0.2, 0.28, 0.22), accentMat, px, roofY + 0.18, 0);
        add(new THREE.BoxGeometry(0.22, 0.05, 0.24), trimMat, px, roofY + 0.34, 0, 0, false);
      }
    } else {
      add(new THREE.BoxGeometry(0.55, 0.35, 0.08), accentMat, 0, roofY + 0.2, bodyD / 2 + 0.05, 0, false);
    }
  }

  // Premium real-world inspired facade kit: full-height corner glazing,
  // deep horizontal floor bands, entrance canopy and rooftop equipment.
  if (type === "home" || type === "shop" || type === "administrative") {
    const bandY = 0.34 + height * 0.52;
    add(new THREE.BoxGeometry(bodyW + 0.10, 0.075, 0.075), trimMat, 0, bandY, bodyD / 2 + 0.035, 0, false);
    add(new THREE.BoxGeometry(0.075, height * 0.82, 0.075), accentMat, bodyW / 2 - 0.10, 0.36 + height * 0.43, bodyD / 2 + 0.04, 0, false);
    add(new THREE.BoxGeometry(0.075, height * 0.82, 0.075), accentMat, -bodyW / 2 + 0.10, 0.36 + height * 0.43, bodyD / 2 + 0.04, 0, false);
    // A broad, layered entrance canopy gives each building a deliberate street presence.
    add(new THREE.BoxGeometry(bodyW * 0.58, 0.10, 0.34), roofMat, 0, 1.12, bodyD / 2 + 0.20, 0, true);
    add(new THREE.BoxGeometry(bodyW * 0.58, 0.045, 0.36), trimMat, 0, 1.19, bodyD / 2 + 0.20, 0, false);
  }
  if (type === "home" && level >= 3) {
    // Modern villa roof terrace with a glass balustrade and rooftop garden.
    add(new THREE.BoxGeometry(bodyW * 0.76, 0.08, bodyD * 0.48), mat("#526b61", { roughness: 0.92 }), 0, roofBaseY + 0.16, 0, 0, false);
    add(new THREE.BoxGeometry(bodyW * 0.76, 0.045, 0.035), glassMat, 0, roofBaseY + 0.42, bodyD * 0.24, 0, false);
    add(new THREE.BoxGeometry(0.035, 0.045, bodyD * 0.48), glassMat, bodyW * 0.38, roofBaseY + 0.42, 0, 0, false);
    for (const gx of [-0.42, 0.42]) {
      add(new THREE.SphereGeometry(0.12, 8, 6), mat("#22ed63", { roughness: 0.82 }), gx, roofBaseY + 0.30, -0.30, 0, false);
    }
  }
  if (type === "shop") {
    // Wide, premium storefront glazing and a clean illuminated sign fascia.
    add(new THREE.BoxGeometry(bodyW * 0.78, 0.82, 0.045), glassMat, 0, 0.86, bodyD / 2 + 0.065, 0, false);
    add(new THREE.BoxGeometry(bodyW * 0.82, 0.10, 0.055), accentMat, 0, 1.48, bodyD / 2 + 0.09, 0, false);
  }
  add(new THREE.BoxGeometry(0.05, height * 0.75, 0.06), accentMat, -bodyW / 2 - 0.01, 0.35 + height * 0.45, bodyD / 2 + 0.02, 0, false);

  return group;
}
