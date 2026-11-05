/** Original tileable city PBR materials for Three.js. */
export function createCityPbrSurfaces(THREE, renderer) {
function makePbrSurface(THREE, renderer, kind, base, seed) {
  const compactDevice = window.matchMedia?.("(max-width: 900px)").matches || (navigator.deviceMemory && navigator.deviceMemory <= 4);
  // Mobile builds use quarter-resolution maps: the six normal/roughness passes
  // otherwise process more than nine million texels synchronously at startup.
  const size = compactDevice ? 256 : 512;
  const makeCanvas = () => {
    const canvas = document.createElement("canvas");
    canvas.width = canvas.height = size;
    return canvas;
  };
  const albedoCanvas = makeCanvas();
  const heightCanvas = makeCanvas();
  const roughCanvas = makeCanvas();
  const albedo = albedoCanvas.getContext("2d");
  const heightMap = heightCanvas.getContext("2d");
  const rough = roughCanvas.getContext("2d");
  albedo.fillStyle = base;
  albedo.fillRect(0, 0, size, size);
  heightMap.fillStyle = "#808080";
  heightMap.fillRect(0, 0, size, size);
  rough.fillStyle = "#b8b8b8";
  rough.fillRect(0, 0, size, size);
  let state = seed >>> 0;
  const random = () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 4294967296;
  };
  const tileDot = (x, y, radius, color, elevation) => {
    const offsetsX = x < radius ? [-size, 0] : x > size - radius ? [0, size] : [0];
    const offsetsY = y < radius ? [-size, 0] : y > size - radius ? [0, size] : [0];
    for (const ox of offsetsX) for (const oy of offsetsY) {
      albedo.fillStyle = color;
      albedo.beginPath();
      albedo.arc(x + ox, y + oy, radius, 0, Math.PI * 2);
      albedo.fill();
      heightMap.fillStyle = elevation;
      heightMap.beginPath();
      heightMap.arc(x + ox, y + oy, radius, 0, Math.PI * 2);
      heightMap.fill();
    }
  };
  const tileLine = (x1, y1, x2, y2, color, width, elevation) => {
    for (const ox of [-size, 0, size]) for (const oy of [-size, 0, size]) {
      albedo.strokeStyle = color;
      albedo.lineWidth = width;
      albedo.beginPath();
      albedo.moveTo(x1 + ox, y1 + oy);
      albedo.lineTo(x2 + ox, y2 + oy);
      albedo.stroke();
      heightMap.strokeStyle = elevation;
      heightMap.lineWidth = width;
      heightMap.beginPath();
      heightMap.moveTo(x1 + ox, y1 + oy);
      heightMap.lineTo(x2 + ox, y2 + oy);
      heightMap.stroke();
    }
  };

  if (kind === "grass") {
    for (let i = 0; i < 1050; i++) {
      const x = random() * size, y = random() * size, r = 3 + random() * 22;
      tileDot(x, y, r, random() > 0.5 ? "rgba(151,177,92,.16)" : "rgba(24,57,35,.20)", "#898989");
    }
    for (let i = 0; i < 5200; i++) {
      const x = random() * size, y = random() * size, len = 2 + random() * 8;
      tileLine(x, y, x + (random() - .5) * 3, y - len, random() > .5 ? "rgba(188,202,120,.42)" : "rgba(25,63,36,.38)", .7, "#929292");
    }
  } else if (kind === "asphalt") {
    for (let i = 0; i < 12500; i++) {
      const v = Math.floor(75 + random() * 85);
      tileDot(random() * size, random() * size, .35 + random() * 1.5, "rgba(" + v + "," + (v + 5) + "," + (v + 8) + ",.42)", "#858585");
    }
    for (let i = 0; i < 18; i++) {
      const x = random() * size, y = random() * size;
      tileLine(x, y, x + 8 + random() * 26, y + (random() - .5) * 12, "rgba(25,29,31,.32)", .7, "#737373");
    }
  } else if (kind === "brick" || kind === "concrete") {
    if (kind === "brick") {
      for (let row = 0; row <= 12; row++) {
        const y = row * 42;
        tileLine(0, y, size, y, "rgba(226,211,190,.9)", 3, "#a0a0a0");
        const offset = row % 2 ? 32 : 0;
        for (let x = -64 + offset; x <= size + 64; x += 64) {
          tileLine(x, y, x, y + 42, "rgba(225,210,190,.82)", 2.2, "#a0a0a0");
          albedo.fillStyle = "rgba(54,35,26,.12)";
          albedo.fillRect(x + 2, y + 3, 59, 35);
        }
      }
      for (let i = 0; i < 2600; i++) tileDot(random() * size, random() * size, .4 + random() * 1.3, "rgba(65,42,31,.16)", "#858585");
    } else {
      for (let y = 0; y <= size; y += 128) tileLine(0, y, size, y, "rgba(48,53,52,.10)", 1, "#858585");
      for (let i = 0; i < 9000; i++) tileDot(random() * size, random() * size, .3 + random() * 1.4, "rgba(38,42,40,.16)", "#858585");
    }
  } else if (kind === "roof") {
    for (let row = 0; row <= 16; row++) {
      const y = row * 32;
      tileLine(0, y, size, y, "rgba(28,34,39,.72)", 2, "#696969");
      const offset = row % 2 ? 32 : 0;
      for (let x = -64 + offset; x <= size + 64; x += 64) {
        tileLine(x, y, x, y + 32, "rgba(33,39,44,.55)", 1.5, "#737373");
        tileLine(x + 3, y + 4, x + 58, y + 4, "rgba(231,220,202,.18)", 1, "#999999");
      }
    }
    for (let i = 0; i < 1600; i++) tileDot(random() * size, random() * size, .5 + random(), "rgba(28,31,34,.22)", "#7d7d7d");
  } else if (kind === "sidewalk") {
    for (let y = 0; y <= size; y += 128) tileLine(0, y, size, y, "rgba(45,48,47,.42)", 3, "#707070");
    for (let x = 0; x <= size; x += 128) tileLine(x, 0, x, size, "rgba(45,48,47,.42)", 3, "#707070");
    for (let i = 0; i < 5000; i++) tileDot(random() * size, random() * size, .3 + random() * 1.1, "rgba(55,58,56,.16)", "#858585");
  }
  const albedoTexture = new THREE.CanvasTexture(albedoCanvas);
  albedoTexture.colorSpace = THREE.SRGBColorSpace;
  const heightPixels = heightMap.getImageData(0, 0, size, size).data;
  const normalCanvas = makeCanvas();
  const normalContext = normalCanvas.getContext("2d");
  const normalPixels = normalContext.createImageData(size, size);
  const roughPixels = rough.getImageData(0, 0, size, size);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const index = (y * size + x) * 4;
    const left = heightPixels[(y * size + (x + size - 1) % size) * 4];
    const right = heightPixels[(y * size + (x + 1) % size) * 4];
    const up = heightPixels[((y + size - 1) % size * size + x) * 4];
    const down = heightPixels[((y + 1) % size * size + x) * 4];
    normalPixels.data[index] = Math.max(0, Math.min(255, 128 + (left - right) * 1.6));
    normalPixels.data[index + 1] = Math.max(0, Math.min(255, 128 + (up - down) * 1.6));
    normalPixels.data[index + 2] = 248;
    normalPixels.data[index + 3] = 255;
    const roughValue = Math.max(0, Math.min(255, 166 + (heightPixels[index] - 128) * .35));
    roughPixels.data[index] = roughValue;
    roughPixels.data[index + 1] = roughValue;
    roughPixels.data[index + 2] = roughValue;
    roughPixels.data[index + 3] = 255;
  }
  normalContext.putImageData(normalPixels, 0, 0);
  rough.putImageData(roughPixels, 0, 0);
  const normalTexture = new THREE.CanvasTexture(normalCanvas);
  const roughnessTexture = new THREE.CanvasTexture(roughCanvas);
  for (const texture of [albedoTexture, normalTexture, roughnessTexture]) {
    texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
    texture.anisotropy = Math.min(renderer.capabilities.getMaxAnisotropy(), compactDevice ? 4 : 8);
    texture.generateMipmaps = true;
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    texture.magFilter = THREE.LinearFilter;
  }
  return { map: albedoTexture, normalMap: normalTexture, roughnessMap: roughnessTexture };
}

// Original tileable, multi-map surface sets: albedo + generated tangent-space
// normal + roughness. No proprietary SimCity assets or remote texture hosts.
const grassSurface = makePbrSurface(THREE, renderer, "grass", "#536b3d", 741);
const asphaltSurface = makePbrSurface(THREE, renderer, "asphalt", "#343b40", 912);
const brickSurface = makePbrSurface(THREE, renderer, "brick", "#b07a5e", 1327);
const concreteSurface = makePbrSurface(THREE, renderer, "concrete", "#898b85", 1441);
const roofSurface = makePbrSurface(THREE, renderer, "roof", "#59616a", 1849);
const sidewalkSurface = makePbrSurface(THREE, renderer, "sidewalk", "#aaa69b", 2047);
const grassMap = grassSurface.map;
const roadMap = asphaltSurface.map;
const facadeMap = brickSurface.map;
const concreteMap = concreteSurface.map;
const roofMap = roofSurface.map;
const sidewalkMap = sidewalkSurface.map;
return { grassSurface, asphaltSurface, brickSurface, concreteSurface, roofSurface, sidewalkSurface };
}
