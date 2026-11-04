/** Deterministic, lightweight procedural surface texture generator. */
export function createCitySurfaceTexture(THREE, renderer, base, fleck, seed, count, scale = 1) {
  
    const textureCanvas = document.createElement("canvas");
    textureCanvas.width = textureCanvas.height = 512;
    const g = textureCanvas.getContext("2d");
    g.fillStyle = base;
    g.fillRect(0, 0, 512, 512);
    let state = seed >>> 0;
    const random = () => {
      state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
      return state / 4294967296;
    };
    for (let i = 0; i < count; i++) {
      const size = 0.5 + random() * 3.0 * scale;
      g.globalAlpha = 0.07 + random() * 0.18;
      g.fillStyle = fleck;
      g.fillRect(random() * 512, random() * 512, size, size);
    }
    g.globalAlpha = 1;
    const texture = new THREE.CanvasTexture(textureCanvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
    texture.anisotropy = Math.min(renderer.capabilities.getMaxAnisotropy(), 4);
    return texture;
}
