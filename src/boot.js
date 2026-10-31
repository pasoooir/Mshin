const panel = document.getElementById("assetLoader");
const bar = document.getElementById("assetProgress");
const label = document.getElementById("assetStatus");
const percentLabel = document.getElementById("assetPercent");

// A module reload gets a fresh document, but explicitly clear every public
// boot marker so tests and diagnostics never observe a previous lifecycle.
window.MshinBootStage = "booting";
window.MshinBootError = null;
window.MshinBootReady = false;
window.MshinAssets = null;
window.MshinPreloadProgress = { loaded: 0, total: 0, percent: 0, name: "" };

try {
  const { preloadGameAssets } = await import("./asset-loader.js");

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

  // Allow the runtime's initial DOM updates and first paint to complete
  // before exposing the single authoritative ready signal.
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
    setTimeout(() => panel.remove(), 260);
  }
}
