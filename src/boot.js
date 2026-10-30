import { preloadGameAssets } from "./asset-loader.js";

const panel = document.getElementById("assetLoader");
const bar = document.getElementById("assetProgress");
const label = document.getElementById("assetStatus");
try {
  await preloadGameAssets(({ loaded, total, percent, name }) => {
    bar.style.width = percent + "%";
    label.textContent = `Preparing vector art · ${loaded}/${total} · ${name}`;
  });
  label.textContent = "All available art decoded · starting race control";
} catch (error) {
  label.textContent = "Starting with built-in vector fallback…";
  console.warn("Mshin asset preload fallback:", error);
}
await import("./web-game.js");
panel.classList.add("loaded");
setTimeout(() => panel.remove(), 260);
