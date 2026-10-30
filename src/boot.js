import { preloadGameAssets } from "./asset-loader.js";

const panel = document.getElementById("assetLoader");
const bar = document.getElementById("assetProgress");
const label = document.getElementById("assetStatus");
const percentLabel = document.getElementById("assetPercent");
try {
  await preloadGameAssets(({ loaded, total, percent, name }) => {
    bar.style.width = percent + "%";
    label.textContent = `بارگذاری · ${loaded}/${total} · ${name}`;
    if (percentLabel) percentLabel.textContent = percent + "%";
  });
  label.textContent = "همه منابع آماده‌اند · بازی در حال اجراست";
  if (percentLabel) percentLabel.textContent = "100%";
} catch (error) {
  label.textContent = "بازی با تصاویر داخلی اجرا می‌شود";
  if (percentLabel) percentLabel.textContent = "آماده";
  console.warn("Mshin asset preload fallback:", error);
}
await import("./web-game.js");
panel.classList.add("loaded");
setTimeout(() => panel.remove(), 260);
