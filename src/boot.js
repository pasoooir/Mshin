import { preloadGameAssets } from "./asset-loader.js";

const panel = document.getElementById("assetLoader");
const bar = document.getElementById("assetProgress");
const label = document.getElementById("assetStatus");
const percentLabel = document.getElementById("assetPercent");
try {
  await preloadGameAssets(({ loaded, total, percent, name }) => {
    bar.style.width = percent + "%";
    label.textContent = `LOADING · ${loaded}/${total} · ${name.toUpperCase()}`;
    if (percentLabel) percentLabel.textContent = percent + "%";
  });
  label.textContent = "ALL ASSETS READY · STARTING GAME";
  if (percentLabel) percentLabel.textContent = "100%";
} catch (error) {
  label.textContent = "STARTING WITH BUILT-IN ART";
  if (percentLabel) percentLabel.textContent = "READY";
  console.warn("Mshin asset preload fallback:", error);
}
await import("./web-game.js");
panel.classList.add("loaded");
setTimeout(() => panel.remove(), 260);
