import { chromium } from "playwright";
import assert from "node:assert/strict";

async function waitForGameBoot(page) {
  await page.waitForFunction(() =>
    (window.MshinBootReady === true || window.MshinBootStage === "ready") &&
    window.MshinAssets?.ready === true && Boolean(document.querySelector("#home")),
    undefined, { timeout: 120000 }
  );
  assert.equal(await page.evaluate(() => window.MshinBootError ?? null), null, "mobile game boot must not report an error");
  await page.locator("#home").waitFor({ state: "visible", timeout: 15000 });
}

const browser = await chromium.launch({
  headless: true,
  args: process.env.CI === "true"
    ? ["--no-sandbox", "--disable-dev-shm-usage", "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"]
    : []
});
const errors = [];
try {
  const mobile = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  mobile.on("pageerror", error => errors.push(error.message));
  mobile.on("console", message => { if (message.type() === "error") errors.push(message.text()); });
  mobile.setDefaultTimeout(60000);
  mobile.setDefaultNavigationTimeout(60000);
  await mobile.goto("http://127.0.0.1:4173/", { waitUntil: "domcontentloaded", timeout: 60000 });
  await waitForGameBoot(mobile);

  const menu = mobile.locator("#select .gtMenu");
  assert.equal(await menu.evaluate(el => getComputedStyle(el).display), "grid", "phone menu must retain its navigation rail");
  assert.equal(await menu.evaluate(el => getComputedStyle(el.querySelector(".menuTabs")).flexDirection), "column", "phone navigation must remain vertical");
  assert.equal(await mobile.locator("body").evaluate(el => getComputedStyle(el, "::before").content), "none", "portrait phones must not show a rotate-device prompt");

  await mobile.locator("#play").click();
  assert.equal(await mobile.locator("#select").isVisible(), true, "portrait mode must enter the menu using software landscape");
  const viewport = await mobile.evaluate(() => ({ ...window.MshinViewport, canvasWidth: document.querySelector("#game").width, canvasHeight: document.querySelector("#game").height }));
  assert.equal(viewport.softwareLandscape, true, "phone must activate software landscape");
  assert.ok(viewport.width > viewport.height && viewport.canvasWidth > viewport.canvasHeight, "game canvas must use landscape logical coordinates");
  const menuBounds = await menu.boundingBox();
  assert.ok(menuBounds && menuBounds.height > menuBounds.width, "landscape menu must fill the portrait phone viewport");
  assert.equal(await mobile.locator(".carChoice").count(), 5, "mobile garage must show all five cars");

  await mobile.locator("#tab-cars").click();
  assert.equal(await mobile.locator("#showroomStage").isVisible(), true, "mobile garage must show the 3D studio");
  const vehicle = await mobile.locator("#showroomVehicle").boundingBox();
  const center = { x: vehicle.x + vehicle.width / 2, y: vehicle.y + vehicle.height / 2 };
  await mobile.locator("#showroomVehicle").dispatchEvent("pointerdown", { pointerId: 77, pointerType: "touch", clientX: center.x, clientY: center.y });
  const moves = await mobile.evaluate(() => window.MshinShowroom.dragMoves || 0);
  await mobile.locator("#showroomVehicle").dispatchEvent("pointermove", { pointerId: 78, pointerType: "touch", clientX: center.x + 40, clientY: center.y + 35 });
  assert.equal(await mobile.evaluate(() => window.MshinShowroom.dragMoves || 0), moves, "showroom must ignore a foreign touch pointer");
  await mobile.locator("#showroomVehicle").dispatchEvent("pointermove", { pointerId: 77, pointerType: "touch", clientX: center.x, clientY: center.y + 35 });
  await mobile.locator("#showroomVehicle").dispatchEvent("pointerup", { pointerId: 77, pointerType: "touch", clientX: center.x, clientY: center.y + 35 });
  await mobile.waitForTimeout(60);
  assert.ok(Math.abs(await mobile.evaluate(() => window.MshinShowroom.angle)) > 0, "touch drag must rotate the showroom car");

  await mobile.locator("#tab-race").click();
  assert.equal(await mobile.locator(".stageCard").count(), 5, "mobile race menu must show five stages");
  await mobile.evaluate(() => {
    window.__orientationCalls = [];
    Object.defineProperty(document, "fullscreenElement", { configurable: true, get: () => window.__fakeFullscreen ? document.documentElement : null });
    document.documentElement.requestFullscreen = async () => { window.__orientationCalls.push("fullscreen"); window.__fakeFullscreen = true; };
    Object.defineProperty(screen.orientation, "lock", { configurable: true, value: async mode => { window.__orientationCalls.push("lock:" + mode); } });
  });
  await mobile.locator("#startRace").click();
  await mobile.waitForFunction(() => window.__orientationCalls?.includes("lock:landscape"), undefined, { timeout: 3000 });
  assert.deepEqual(await mobile.evaluate(() => window.__orientationCalls), ["fullscreen", "lock:landscape"], "phone race must request fullscreen before native landscape lock");
  await mobile.waitForFunction(() => document.querySelector("#countdownOverlay").classList.contains("hidden"), undefined, { timeout: 6000 });
  await mobile.waitForFunction(() => window.Mshin3DRenderer?.frames > 10 && window.Mshin3DRenderer?.quality?.mobile === true, undefined, { timeout: 20000 });
  const quality = await mobile.evaluate(() => window.Mshin3DRenderer.quality);
  assert.ok(quality.pixelRatio <= 0.8 && quality.width <= 700 && quality.height <= 700, "mobile WebGL must use bounded render resolution: " + JSON.stringify(quality));
  assert.equal(await mobile.locator("#hud").isVisible(), true, "mobile race HUD must render");
  assert.equal(await mobile.locator("#game3d").isVisible(), true, "portrait phone must display the rotated WebGL canvas");
  const canvasBounds = await mobile.locator("#game3d").boundingBox();
  assert.ok(canvasBounds && Math.abs(canvasBounds.width - 390) <= 2 && Math.abs(canvasBounds.height - 845) <= 2, "WebGL canvas must cover the complete phone viewport: " + JSON.stringify(canvasBounds));

  const standings = await mobile.evaluate(() => window.MshinRaceStandings ?? null);
  assert.ok(Array.isArray(standings) && standings.length === 5, "live mobile race must track the player and four rivals: " + JSON.stringify(standings));
  assert.deepEqual([...new Set(standings.map(row => row.rank))].sort(), [1, 2, 3, 4, 5], "mobile race must expose five distinct live ranks");
  assert.ok(standings.every(row => Number.isFinite(row.elapsed) && row.elapsed >= 0), "each mobile racer must expose an independent stopwatch");
  assert.equal(await mobile.locator("#racePositionOverlay").count(), 1, "mobile page must contain the per-car rank cloud overlay");

  await mobile.locator("#pause").click();
  const pauseBounds = await mobile.locator("#pausePanel .pauseScreen").boundingBox();
  assert.ok(pauseBounds && pauseBounds.x >= -1 && pauseBounds.y >= -1 && pauseBounds.x + pauseBounds.width <= 391 && pauseBounds.y + pauseBounds.height <= 845, "phone pause menu must fit the viewport");
  assert.equal(await mobile.locator("#pausePanel .pauseMenu > *").count(), 10, "mobile pause menu must show all ten actions");
  assert.equal(await mobile.locator("#mostWantedList li").count(), 5, "mobile standings panel must show all five racers");
  await mobile.locator("#resume").click();

  const stick = await mobile.locator("#stick").boundingBox();
  assert.ok(stick && Math.max(stick.width, stick.height) >= 120 && Math.min(stick.width, stick.height) >= 100, "mobile steering control must preserve a large touch target");
  assert.ok((await mobile.locator("#gas").boundingBox()).width >= 60, "mobile gas pedal must be touch-sized");
  assert.ok((await mobile.locator("#nitro").boundingBox()).width >= 60, "mobile nitro button must be touch-sized");
  assert.equal(await mobile.locator("#gas img").getAttribute("alt"), "گاز");
  assert.equal(await mobile.locator("#brake img").getAttribute("alt"), "ترمز");
  assert.equal(await mobile.locator("#nitro img").getAttribute("alt"), "نیترو");
  const stats = await mobile.locator(".stats").boundingBox();
  const sound = await mobile.locator("#soundToggle").boundingBox();
  const overlap = !(stats.x + stats.width <= sound.x || sound.x + sound.width <= stats.x || stats.y + stats.height <= sound.y || sound.y + sound.height <= stats.y);
  assert.equal(overlap, false, "mobile HUD stats must not overlap sound controls");
  assert.ok(await mobile.locator("#pause").evaluate(el => el.getBoundingClientRect().right <= innerWidth), "pause control must remain inside phone viewport");
  assert.deepEqual(errors, [], "mobile gameplay must not emit browser runtime errors");
  console.log("[mobile-smoke] PASS: phone boot, touch showroom, orientation, WebGL, race standings, HUD and touch controls");
  await mobile.close();
} finally {
  await browser.close();
}
