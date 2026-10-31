import { preloadGameAssets } from "./asset-loader.js";

const panel = document.getElementById("assetLoader");
const bar = document.getElementById("assetProgress");
const label = document.getElementById("assetStatus");
const percentLabel = document.getElementById("assetPercent");
window.MshinBootStage = "preloading";
try {
  await preloadGameAssets(({ loaded, total, percent, name }) => {
    window.MshinPreloadProgress = { loaded, total, percent, name };
    bar.style.width = percent + "%";
    label.textContent = `بارگذاری · ${loaded}/${total} · ${name}`;
    if (percentLabel) percentLabel.textContent = percent + "%";
  });
  if (!window.MshinAssets.ready) throw new Error("Required audio assets failed to preload: " + window.MshinAssets.requiredFailures.map(item => item.asset).join(", "));
  label.textContent = window.MshinAssets.failures.length ? `بارگذاری با ${window.MshinAssets.failures.length} منبع اختیاری ناموفق؛ نسخه جایگزین فعال است` : "همه منابع آماده‌اند · بازی در حال اجراست";
  if (percentLabel) percentLabel.textContent = "100%";
  window.MshinBootStage = "importing-runtime";
  await import("./web-game.js");
  window.MshinBootStage = "ready";
} catch (error) {
  window.MshinBootError = String(error?.stack || error);
  label.textContent = "خطا در آماده‌سازی بازی؛ لطفاً صفحه را تازه‌سازی کنید";
  if (percentLabel) percentLabel.textContent = "خطا";
  console.error("Mshin boot failed:", error);
} finally {
  panel.classList.add("loaded");
  setTimeout(() => panel.remove(), 260);
}
