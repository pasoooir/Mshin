import { preloadGameAssets } from "./asset-loader.js";

const panel = document.getElementById("assetLoader");
const bar = document.getElementById("assetProgress");
const label = document.getElementById("assetStatus");
const percentLabel = document.getElementById("assetPercent");

// Reset lifecycle markers on every document load. The ready flag is the
// stable contract for browser tests; the loader element is presentation only.
window.MshinBootStage = "booting";
window.MshinBootReady = false;
window.MshinBootError = null;

try {
  window.MshinBootStage = "preloading";
  await preloadGameAssets(({ loaded, total, percent, name }) => {
    window.MshinPreloadProgress = { loaded, total, percent, name };
    if (bar) bar.style.width = percent + "%";
    if (label) label.textContent = `بارگذاری · ${loaded}/${total} · ${name}`;
    if (percentLabel) percentLabel.textContent = percent + "%";
  });

  if (window.MshinAssets?.ready !== true) {
    throw new Error("Asset preload completed without publishing a ready asset manifest.");
  }

  if (label) {
    label.textContent = window.MshinAssets.failures.length
      ? `بارگذاری با ${window.MshinAssets.failures.length} منبع ناموفق؛ نسخه جایگزین فعال است`
      : "همه منابع آماده‌اند · بازی در حال اجراست";
  }
  if (percentLabel) percentLabel.textContent = "100%";

  window.MshinBootStage = "importing-runtime";
  await import("./web-game.js");

  // Wait for the runtime's initial DOM updates and a paint before publishing
  // readiness, so consumers never observe "ready" before #home exists.
  await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  if (!document.querySelector("#home")) {
    throw new Error("Game runtime imported, but the home menu DOM is missing.");
  }

  window.MshinBootStage = "ready";
  window.MshinBootReady = true;
} catch (error) {
  window.MshinBootError = String(error?.stack || error);
  window.MshinBootStage = "error";
  window.MshinBootReady = false;
  if (label) label.textContent = "خطا در آماده‌سازی بازی؛ لطفاً صفحه را تازه‌سازی کنید";
  if (percentLabel) percentLabel.textContent = "خطا";
  console.error("Mshin boot failed:", error);
} finally {
  if (panel) {
    panel.classList.add("loaded");
    // Keep the loader through a paint; its lifetime must not gate app readiness.
    requestAnimationFrame(() => requestAnimationFrame(() => {
      if (panel.isConnected) panel.remove();
    }));
  }
}
