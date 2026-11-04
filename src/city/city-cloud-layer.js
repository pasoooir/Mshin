/**
 * Lightweight procedural cloud shell for the Mshin city sky.
 * Multi-octave noise creates broad cumulus-like fields and wispy edges;
 * the shell follows the camera and uses no external texture or network fetch.
 */
export function createCityCloudLayer(THREE, { scene, camera }) {
  const geometry = new THREE.SphereGeometry(875, 48, 32);
  const material = new THREE.ShaderMaterial({
    uniforms: {
      uTime: { value: 0 },
      uCoverage: { value: 0.48 },
      uOpacity: { value: 0.72 },
      uSunDirection: { value: new THREE.Vector3(-0.35, 0.75, -0.55).normalize() },
      uSunColor: { value: new THREE.Color("#fff0d5") },
      uNight: { value: 0 }
    },
    vertexShader: `
      varying vec3 vDirection;
      void main() {
        vec4 worldPosition = modelMatrix * vec4(position, 1.0);
        vDirection = normalize(worldPosition.xyz - cameraPosition);
        gl_Position = projectionMatrix * viewMatrix * worldPosition;
      }
    `,
    fragmentShader: `
      uniform float uTime;
      uniform float uCoverage;
      uniform float uOpacity;
      uniform vec3 uSunDirection;
      uniform vec3 uSunColor;
      uniform float uNight;
      varying vec3 vDirection;
      float hash31(vec3 p) {
        p = fract(p * 0.1031);
        p += dot(p, p.yxz + 33.33);
        return fract((p.x + p.y) * p.z);
      }
      float noise3(vec3 p) {
        vec3 i = floor(p), f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(mix(mix(hash31(i), hash31(i + vec3(1,0,0)), f.x),
                       mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
                   mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x),
                       mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y), f.z);
      }
      float fbm(vec3 p) {
        float value = 0.0, amplitude = 0.52;
        for (int octave = 0; octave < 5; octave++) {
          value += noise3(p) * amplitude;
          p *= 2.03;
          amplitude *= 0.5;
        }
        return value;
      }
      void main() {
        vec3 direction = normalize(vDirection);
        float altitude = direction.y;
        if (altitude < -0.015 || altitude > 0.72) discard;
        vec3 cloudPoint = direction * 5.2 + vec3(uTime * 0.006, 0.0, uTime * 0.002);
        float broad = fbm(cloudPoint);
        float detail = fbm(cloudPoint * 2.7 + 8.3);
        float density = broad * 0.78 + detail * 0.22;
        float horizonFade = smoothstep(-0.02, 0.12, altitude) * (1.0 - smoothstep(0.58, 0.74, altitude));
        float cloud = smoothstep(0.49 - uCoverage * 0.16, 0.72 - uCoverage * 0.12, density) * horizonFade;
        if (cloud < 0.012) discard;
        float sunLight = max(dot(normalize(uSunDirection), normalize(vec3(direction.x, max(direction.y, 0.12), direction.z))), 0.0);
        vec3 base = mix(vec3(0.34, 0.39, 0.46), vec3(0.92, 0.95, 0.98), 0.52 + sunLight * 0.42);
        base = mix(base, vec3(0.19, 0.23, 0.31), uNight * 0.76);
        vec3 lit = mix(base, uSunColor, (1.0 - uNight) * sunLight * 0.18);
        gl_FragColor = vec4(lit, cloud * uOpacity);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }
    `,
    side: THREE.BackSide,
    transparent: true,
    depthWrite: false,
    depthTest: false,
    toneMapped: true
  });
  const shell = new THREE.Mesh(geometry, material);
  shell.name = "MshinProceduralCloudShell";
  shell.frustumCulled = false;
  shell.renderOrder = -990;
  scene.add(shell);

  return {
    update(city, atmosphere) {
      const now = (typeof performance !== "undefined" ? performance.now() : Date.now()) / 1000;
      material.uniforms.uTime.value = now;
      const weather = atmosphere?.weather?.weather || "clear";
      const intensity = Number(atmosphere?.weather?.intensity) || 0;
      const minute = Number(city?.minuteOfDay) || 720;
      const daylight = Math.max(0, Math.min(1, Math.sin(minute / 1440 * Math.PI * 2 - Math.PI / 2)));
      const coverage = weather === "rain" ? 0.92 : weather === "snow" || weather === "frost" ? 0.78
        : weather === "wind" ? 0.56 : weather === "heat" ? 0.18 : 0.34 + intensity * 0.18;
      material.uniforms.uCoverage.value = coverage;
      material.uniforms.uOpacity.value = weather === "clear" ? 0.54 : 0.78;
      material.uniforms.uNight.value = 1 - daylight;
      material.uniforms.uSunDirection.value.set(Math.cos(minute / 1440 * Math.PI * 2 - Math.PI / 2), Math.sin(minute / 1440 * Math.PI * 2 - Math.PI / 2), -0.34).normalize();
      material.uniforms.uSunColor.value.set(atmosphere?.lighting?.sunlightColor || "#fff0d5");
      camera.getWorldPosition(shell.position);
      shell.visible = true;
    },
    dispose() {
      scene.remove(shell);
      geometry.dispose();
      material.dispose();
    }
  };
}
