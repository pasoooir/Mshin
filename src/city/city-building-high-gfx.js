/**
 * High-graphics procedural buildings for Mshin city (SimCity BuildIt inspired style).
 * Vibrant palettes, multi-style roofs, rich facades, roof props, and readable silhouettes
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
  const PALETTES = {
    home: [
      { wall: "#f2d6b3", side: "#e0c09a", roof: "#c45c4a", trim: "#fff6e8", accent: "#5a9e8a", door: "#6b4a3a" },
      { wall: "#e8c9a8", side: "#d4b48c", roof: "#5e7a8a", trim: "#f8efe0", accent: "#c4785a", door: "#4a3a32" },
      { wall: "#dce6d4", side: "#c4d0bc", roof: "#8b5e4a", trim: "#f4f7ef", accent: "#6a8f7a", door: "#5a4a3a" },
      { wall: "#f0e0c8", side: "#dcc8a8", roof: "#4a5a62", trim: "#fffaf0", accent: "#a87858", door: "#3a2e28" },
      { wall: "#e4d0b8", side: "#c8b498", roof: "#b85a4a", trim: "#faf4e8", accent: "#5a7a8a", door: "#5a4038" },
      { wall: "#c8d8e0", side: "#a8c0cc", roof: "#6a5a4a", trim: "#f0f6f8", accent: "#d48a5a", door: "#3a4850" }
    ],
    shop: [
      { wall: "#e8d4b8", side: "#d0bc9c", roof: "#4a5a62", trim: "#fff8ec", accent: "#e07050", door: "#3a3a3a" },
      { wall: "#d0e0e4", side: "#b0c8d0", roof: "#5a6a72", trim: "#f4fafc", accent: "#50a0b0", door: "#2a3a42" },
      { wall: "#f0dcc0", side: "#d8c4a0", roof: "#6a5a4e", trim: "#fffaf0", accent: "#c06040", door: "#4a3028" },
      { wall: "#d8e8d0", side: "#b8d0b0", roof: "#4a5a52", trim: "#f4faf0", accent: "#70a060", door: "#2a3a28" }
    ],
    industrial: [
      { wall: "#a8b0b4", side: "#889098", roof: "#3a444c", trim: "#d0d4d8", accent: "#e0a040", door: "#2a3038" },
      { wall: "#98a0a4", side: "#788088", roof: "#2e363c", trim: "#c8ccd0", accent: "#d08040", door: "#1e2428" },
      { wall: "#b0b8b4", side: "#909894", roof: "#3a4240", trim: "#d8dcd8", accent: "#60a0b0", door: "#282e2c" }
    ],
    administrative: [
      { wall: "#d8d0e0", side: "#b8b0c8", roof: "#4a4a5a", trim: "#f4f0f8", accent: "#8060b0", door: "#3a3048" },
      { wall: "#e0d8e8", side: "#c0b8d0", roof: "#5a5060", trim: "#faf6fc", accent: "#a070c0", door: "#403850" }
    ],
    service: [
      { wall: "#e0e4e8", side: "#c0c8d0", roof: "#4a5460", trim: "#f8fafc", accent: "#5080c0", door: "#2a3848" }
    ],
    power:  [{ wall: "#e8e0c8", side: "#d0c8a8", roof: "#4a4a3a", trim: "#f8f4e0", accent: "#e0c040", door: "#3a3a28" }],
    water:  [{ wall: "#c8dce8", side: "#a8c4d4", roof: "#3a5a6a", trim: "#f0f8fc", accent: "#40a0c0", door: "#284858" }],
    sewage: [{ wall: "#c8d0c0", side: "#a8b0a0", roof: "#4a5440", trim: "#f0f4e8", accent: "#80a060", door: "#384028" }],
    waste:  [{ wall: "#d0d0b8", side: "#b0b098", roof: "#4a4a3a", trim: "#f4f4e0", accent: "#a0a040", door: "#3a3a28" }],
    police: [{ wall: "#d0d8e8", side: "#b0bcd0", roof: "#3a4460", trim: "#f0f4fc", accent: "#4060c0", door: "#283848" }],
    fire:   [{ wall: "#e8d0c8", side: "#d0b0a8", roof: "#5a3a3a", trim: "#fcf0ec", accent: "#e05040", door: "#482828" }],
    health: [{ wall: "#e8dce0", side: "#d0c0c8", roof: "#5a4a52", trim: "#fcf4f6", accent: "#e07090", door: "#483040" }],
    education: [{ wall: "#e0d8c8", side: "#c8c0a8", roof: "#4a4a3a", trim: "#f8f4e8", accent: "#a08050", door: "#3a3028" }]
  };

  const serviceTypes = new Set(["power", "water", "sewage", "waste", "police", "fire", "health", "education", "service"]);
  const paletteKey = serviceTypes.has(type) ? (PALETTES[type] ? type : "service") : type;
  const paletteList = PALETTES[paletteKey] || PALETTES.home;
  const palette = paletteList[(seed + level) % paletteList.length];

  function mat(color, opts = {}) {
    return new THREE.MeshStandardMaterial({
      color,
      roughness: opts.roughness ?? 0.82,
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
    const winW = 0.22;
    const winH = 0.28;
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
    const lawn = mat("#5cb85a", { roughness: 1 });
    add(new THREE.BoxGeometry(1.78, 0.18, 1.78), lawn, 0, 0.2, 0, 0, false);
    add(new THREE.BoxGeometry(0.28, 0.04, 1.5), mat("#e8d8a8", { roughness: 0.95 }), 0.15, 0.3, 0, -0.25, false);
    if (trunkGeometry && canopyGeometry) {
      for (const [tx, tz] of [[-0.45, -0.35], [0.4, 0.3], [-0.2, 0.45]]) {
        const trunk = new THREE.Mesh(trunkGeometry, mat("#8b5b38", { roughness: 0.95 }));
        trunk.position.set(tx, 0.75, tz);
        trunk.scale.set(0.85, 0.9, 0.85);
        group.add(trunk);
        const crown = new THREE.Mesh(canopyGeometry, mat(pick(["#4aa85a", "#5cbc5c", "#6ac86a"]), { roughness: 1 }));
        crown.position.set(tx, 1.4, tz);
        group.add(crown);
        if (canopySmallGeometry) {
          const hi = new THREE.Mesh(canopySmallGeometry, mat("#7ad070", { roughness: 1 }));
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
      add(new THREE.SphereGeometry(0.06, 6, 5), mat(pick(["#e06080", "#e0c040", "#8060c0", "#40a0e0"])), fx, 0.38, fz, 0, false);
    }
    return group;
  }

  let height, bodyW, bodyD, floors, cols;
  if (type === "home") {
    height = 1.9 + level * 0.55;
    bodyW = 1.28 + (level > 2 ? 0.08 : 0);
    bodyD = 1.22 + (level > 2 ? 0.06 : 0);
    floors = Math.min(4, 1 + level);
    cols = level >= 3 ? 3 : 2;
  } else if (type === "shop") {
    height = 2.15 + level * 0.35;
    bodyW = 1.38;
    bodyD = 1.28;
    floors = Math.min(3, 1 + Math.floor(level / 2));
    cols = 3;
  } else if (type === "industrial") {
    height = 2.4 + level * 0.4;
    bodyW = 1.55;
    bodyD = 1.48;
    floors = 2 + Math.floor(level / 2);
    cols = 3;
  } else if (type === "administrative") {
    height = 2.6 + level * 0.45;
    bodyW = 1.42;
    bodyD = 1.36;
    floors = 2 + level;
    cols = 3;
  } else {
    height = 2.2 + level * 0.3;
    bodyW = 1.36;
    bodyD = 1.28;
    floors = 2;
    cols = 2;
  }

  const facadeSurf = (type === "industrial" || type === "administrative") ? (concreteSurface || {}) : (brickSurface || {});
  const wall = new THREE.MeshStandardMaterial({
    ...facadeSurf,
    color: palette.wall,
    roughness: 0.86,
    normalScale: facadeSurf.normalMap ? new THREE.Vector2(0.35, 0.35) : undefined
  });
  const sideWall = new THREE.MeshStandardMaterial({
    ...facadeSurf,
    color: palette.side,
    roughness: 0.88,
    normalScale: facadeSurf.normalMap ? new THREE.Vector2(0.3, 0.3) : undefined
  });
  const roofMat = new THREE.MeshStandardMaterial({
    ...(roofSurface || {}),
    color: palette.roof,
    roughness: 0.9,
    normalScale: roofSurface?.normalMap ? new THREE.Vector2(0.45, 0.45) : undefined
  });
  const trimMat = mat(palette.trim, { roughness: 0.65 });
  const accentMat = mat(palette.accent, { roughness: 0.7 });
  const doorMat = mat(palette.door, { roughness: 0.75 });
  const glassMat = mat("#c8eef4", {
    roughness: 0.22,
    metalness: 0.12,
    emissive: "#3a90a8",
    emissiveIntensity: 0.18,
    transparent: true,
    opacity: 0.85
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
    if (level >= 2) addBalcony(bodyW, bodyD, 1.15, trimMat, accentMat);
    if (level >= 3) addBalcony(bodyW, bodyD, 1.15 + 0.7, trimMat, accentMat);
    add(new THREE.BoxGeometry(0.9, 0.08, 0.22), mat("#4a9a4a", { roughness: 1 }), 0, 0.32, bodyD / 2 + 0.28, 0, false);
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

  add(new THREE.BoxGeometry(0.05, height * 0.75, 0.06), accentMat, -bodyW / 2 - 0.01, 0.35 + height * 0.45, bodyD / 2 + 0.02, 0, false);

  return group;
}
