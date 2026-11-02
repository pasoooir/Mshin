import { chromium } from "playwright";
import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";

async function captureScreenshot(page, path, { fullPage = false } = {}) {
  // Avoid Playwright's screenshot preflight (font/animation waits), which has
  // stalled on this WebGL-heavy page in GitHub Actions after fonts were ready.
  const session = await page.context().newCDPSession(page);
  try {
    await session.send("Page.enable");
    const metrics = await session.send("Page.getLayoutMetrics");
    const size = metrics.cssContentSize || metrics.contentSize;
    const params = { format: "png", fromSurface: true, captureBeyondViewport: fullPage };
    if (fullPage) {
      params.clip = {
        x: 0, y: 0,
        width: Math.max(1, Math.ceil(size.width)),
        height: Math.max(1, Math.ceil(size.height)),
        scale: 1
      };
    }
    const { data } = await session.send("Page.captureScreenshot", params);
    await writeFile(path, Buffer.from(data, "base64"));
  } finally {
    await session.detach();
  }
}


async function waitForGameBoot(page, label = "game") {
  await page.waitForFunction(() => {
    const stage = window.MshinBootStage;
    const ready = window.MshinBootReady === true || stage === "ready";
    return ready && window.MshinAssets?.ready === true && Boolean(document.querySelector("#home"));
  }, undefined, { timeout: 120000 }).catch(async error => {
    const state = await page.evaluate(() => ({
      stage: window.MshinBootStage,
      bootReady: window.MshinBootReady === true,
      bootError: window.MshinBootError || null,
      assetsReady: window.MshinAssets?.ready === true,
      progress: window.MshinPreloadProgress,
      failures: window.MshinAssets?.failures || [],
      homePresent: Boolean(document.querySelector("#home")),
      loaderPresent: Boolean(document.querySelector("#assetLoader"))
    }));
    throw new Error(label + " did not reach the game-ready state: " + JSON.stringify(state) + " | " + error.message);
  });
  const state = await page.evaluate(() => ({
    stage: window.MshinBootStage,
    bootReady: window.MshinBootReady === true,
    bootError: window.MshinBootError || null,
    assetsReady: window.MshinAssets?.ready === true,
    homePresent: Boolean(document.querySelector("#home"))
  }));
  assert.equal(state.bootError, null, label + " must not report a boot error: " + JSON.stringify(state));
  assert.equal(state.bootReady || state.stage === "ready", true, label + " must publish its final runtime-ready signal: " + JSON.stringify(state));
  assert.equal(state.assetsReady, true, label + " assets must be ready: " + JSON.stringify(state));
  assert.equal(state.homePresent, true, label + " must retain the home menu DOM");
  try {
    await page.locator("#home").waitFor({ state: "visible", timeout: 15000 });
  } catch (error) {
    const visibility = await page.evaluate(() => {
      const home = document.querySelector("#home");
      if (!home) return { present: false };
      const style = getComputedStyle(home);
      const rect = home.getBoundingClientRect();
      return {
        present: true,
        className: home.className,
        display: style.display,
        visibility: style.visibility,
        opacity: style.opacity,
        rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
        state: window.MshinGameState || null
      };
    });
    throw new Error(label + " booted but home menu did not become visible: " + JSON.stringify(visibility) + " | " + error.message);
  }
  return state;
}


await mkdir("artifacts", { recursive: true });
const browser = await chromium.launch({ headless: true, args: process.env.CI === "true" ? ["--no-sandbox", "--disable-dev-shm-usage", "--disable-background-timer-throttling", "--disable-renderer-backgrounding", "--disable-backgrounding-occluded-windows", "--disable-features=CalculateNativeWinOcclusion", "--disable-frame-rate-limit", "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"] : [] });
const errors = [];
let activePhase = "mobile browser launch";
const progressHeartbeat = setInterval(() => console.log("[mobile-browser-smoke] still running; current phase: " + activePhase), 15000);
progressHeartbeat.unref();
try {
  activePhase = "mobile viewport and touch controls";
  const mobile = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  mobile.on("pageerror", error => errors.push(error.stack || error.message));
  mobile.setDefaultTimeout(60000);
  mobile.setDefaultNavigationTimeout(60000);
  await mobile.goto("http://127.0.0.1:4173/", { waitUntil: "domcontentloaded", timeout: 60000 });
  await waitForGameBoot(mobile, "mobile initial boot");
  const mobileMenuLayout = await mobile.locator("#select .gtMenu").evaluate(el => ({ display: getComputedStyle(el).display, tabsDirection: getComputedStyle(el.querySelector(".menuTabs")).flexDirection }));
  assert.equal(mobileMenuLayout.display, "grid", "mobile menu should retain the navigation rail layout");
  assert.equal(mobileMenuLayout.tabsDirection, "column", "mobile menu navigation should remain vertical");
  assert.equal(await mobile.locator("body").evaluate(el => getComputedStyle(el, "::before").content), "none", "portrait mode must not display a rotate-device prompt");
  await mobile.locator("#play").click();
  assert.equal(await mobile.locator("#select").isVisible(), true, "portrait mode must enter the menu through software landscape rotation");
  const softwareViewport = await mobile.evaluate(() => ({ ...window.MshinViewport, canvasWidth: document.querySelector("#game").width, canvasHeight: document.querySelector("#game").height }));
  assert.equal(softwareViewport.softwareLandscape, true, "portrait mode must activate the software landscape viewport");
  assert.ok(softwareViewport.width > softwareViewport.height && softwareViewport.canvasWidth > softwareViewport.canvasHeight, "canvas backing dimensions must use landscape coordinates");
  const rotatedMenuBounds = await mobile.locator("#select .gtMenu").boundingBox();
  assert.ok(rotatedMenuBounds && rotatedMenuBounds.height > rotatedMenuBounds.width, "rotated landscape menu must fill the portrait viewport while retaining landscape logical dimensions");
  const logicalMenuSize = await mobile.locator("#select .gtMenu").evaluate(el => ({ width: parseFloat(getComputedStyle(el).width), height: parseFloat(getComputedStyle(el).height) }));
  assert.ok(logicalMenuSize.width > logicalMenuSize.height, "menu layout itself must retain landscape width and height");
  assert.equal(await mobile.locator(".carChoice").count(),5,"mobile showroom should retain all five cars");
  const visibleMobileColumns = await mobile.locator("#select .gtMenu").evaluate(el => ({ tabs: el.querySelector(".menuTabs").getBoundingClientRect(), body: el.querySelector(".menuBody").getBoundingClientRect() }));
  assert.ok(visibleMobileColumns.tabs.width > 0 && visibleMobileColumns.body.width > 0, "mobile navigation and content columns must both remain visible after entering the menu");
  await mobile.locator("#tab-cars").click();
  assert.notEqual(await mobile.locator("#select .gtMenu").evaluate(el=>getComputedStyle(el).perspective),"none","mobile showroom should retain perspective depth");
  assert.equal(await mobile.locator("#showroomStage").isVisible(),true,"mobile garage should show the cinematic car studio");
  const mobileShowroom=await mobile.locator("#showroomVehicle").boundingBox();
  const showroomCenter = { x: mobileShowroom.x + mobileShowroom.width/2, y: mobileShowroom.y + mobileShowroom.height/2 };
  await mobile.locator("#showroomVehicle").dispatchEvent("pointerdown", { pointerId: 77, pointerType: "touch", clientX: showroomCenter.x, clientY: showroomCenter.y });
  const dragMovesBeforeForeignPointer = await mobile.evaluate(()=>window.MshinShowroom.dragMoves||0);
  await mobile.locator("#showroomVehicle").dispatchEvent("pointermove", { pointerId: 78, pointerType: "touch", clientX: showroomCenter.x + 40, clientY: showroomCenter.y + 35 });
  assert.equal(await mobile.evaluate(()=>window.MshinShowroom.dragMoves||0),dragMovesBeforeForeignPointer,"showroom must ignore movement from a different pointer");
  await mobile.locator("#showroomVehicle").dispatchEvent("pointermove", { pointerId: 77, pointerType: "touch", clientX: showroomCenter.x, clientY: showroomCenter.y + 35 });
  await mobile.locator("#showroomVehicle").dispatchEvent("pointerup", { pointerId: 77, pointerType: "touch", clientX: showroomCenter.x, clientY: showroomCenter.y + 35 });
  await mobile.waitForTimeout(60);
  const mobileDragState = await mobile.evaluate(()=>window.MshinShowroom);
  assert.ok(Math.abs(mobileDragState.angle)>0,"mobile drag should rotate the showroom vehicle: "+JSON.stringify(mobileDragState));
  const rail=await mobile.locator("#select .garage").evaluate(el=>({width:el.clientWidth,scrollWidth:el.scrollWidth,height:el.clientHeight}));
  assert.ok(rail.height>0 && rail.scrollWidth>=rail.width,"mobile showroom rail should remain horizontally scrollable");
  await mobile.locator("#tab-race").click();
  assert.equal(await mobile.locator(".stageCard").count(),5,"mobile race tab should retain five stages");
  await mobile.evaluate(() => {
    window.__orientationCalls = [];
    Object.defineProperty(document, "fullscreenElement", { configurable: true, get: () => window.__fakeFullscreen ? document.documentElement : null });
    document.documentElement.requestFullscreen = async () => { window.__orientationCalls.push("fullscreen"); window.__fakeFullscreen = true; };
    Object.defineProperty(screen.orientation, "lock", { configurable: true, value: async mode => { window.__orientationCalls.push("lock:" + mode); } });
  });
  await mobile.locator("#startRace").click();
  await mobile.waitForFunction(() => window.__orientationCalls?.includes("lock:landscape"), undefined, { timeout: 3000 });
  const orientationCalls = await mobile.evaluate(() => window.__orientationCalls);
  assert.deepEqual(orientationCalls, ["fullscreen", "lock:landscape"], "mobile race start must enter fullscreen before requesting native landscape lock");
  await mobile.waitForFunction(() => document.querySelector("#countdownOverlay").classList.contains("hidden"), undefined, { timeout: 6000 });
  await mobile.waitForFunction(() => window.Mshin3DRenderer?.frames > 10 && window.Mshin3DRenderer?.quality?.mobile === true, undefined, { timeout: 12000 }).catch(async error => {
    const diagnostic = await mobile.evaluate(() => ({
      renderer: window.Mshin3DRenderer ? {
        status: window.Mshin3DRenderer.status,
        error: window.Mshin3DRenderer.error,
        frames: window.Mshin3DRenderer.frames,
        quality: window.Mshin3DRenderer.quality,
        trackBuildProgress: window.Mshin3DRenderer.trackBuildProgress,
        environmentCounts: window.Mshin3DRenderer.environmentCounts
      } : null,
      canvas: { width: document.querySelector("#game3d")?.width, height: document.querySelector("#game3d")?.height },
      bodyClass: document.body.className,
    }));
    throw new Error("mobile WebGL renderer did not reach a stable frame state: " + JSON.stringify(diagnostic) + " | " + error.message);
  });
  const mobileRenderQuality = await mobile.evaluate(() => window.Mshin3DRenderer.quality);
  assert.ok(mobileRenderQuality.pixelRatio <= 0.8 && mobileRenderQuality.width <= 700 && mobileRenderQuality.height <= 700, "mobile WebGL must use a reduced render resolution to protect frame pacing: " + JSON.stringify(mobileRenderQuality));
  assert.equal(await mobile.locator("#hud").isVisible(), true, "mobile race HUD should render");
  assert.equal(await mobile.locator("#game3d").isVisible(), true, "portrait phones should display the rotated WebGL race canvas");
  const mobile3dBounds = await mobile.locator("#game3d").boundingBox();
  assert.ok(mobile3dBounds && Math.abs(mobile3dBounds.width - 390) <= 2 && Math.abs(mobile3dBounds.height - 845) <= 2, "rotated WebGL canvas should cover the complete portrait viewport: " + JSON.stringify(mobile3dBounds));
  await mobile.locator("#pause").click();
  const mobilePauseBounds = await mobile.locator("#pausePanel .pauseScreen").boundingBox();
  assert.ok(mobilePauseBounds && mobilePauseBounds.x >= -1 && mobilePauseBounds.y >= -1 && mobilePauseBounds.x + mobilePauseBounds.width <= 391 && mobilePauseBounds.y + mobilePauseBounds.height <= 845, "portrait software-landscape pause menu must fit the complete phone viewport");
  assert.equal(await mobile.locator("#pausePanel .pauseMenu > *").count(), 10, "mobile pause menu must show all ten actions without scrolling");
  assert.equal(await mobile.locator("#mostWantedList li").count(), 5, "mobile MOST WANTED panel must show five standings");
  await mobile.locator("#resume").click();
  const mobileStickBounds = await mobile.locator("#stick").boundingBox();
  assert.ok(Math.max(mobileStickBounds.width, mobileStickBounds.height) >= 160 && Math.min(mobileStickBounds.width, mobileStickBounds.height) >= 130, "rotated mobile steering pad should provide a larger 160×130 touch surface");
  const steerCenter = { x: mobileStickBounds.x + mobileStickBounds.width / 2, y: mobileStickBounds.y + mobileStickBounds.height / 2 };
  await mobile.locator("#stick").dispatchEvent("pointerdown", { pointerId: 201, pointerType: "touch", clientX: steerCenter.x, clientY: steerCenter.y });
  await mobile.locator("#stick").dispatchEvent("pointermove", { pointerId: 201, pointerType: "touch", clientX: steerCenter.x, clientY: steerCenter.y + 32 });
  const steerRight = Number(await mobile.locator("#stick").getAttribute("data-steer"));
  assert.ok(steerRight < 0, "dragging the joystick toward physical screen-right must command a right turn: " + steerRight);
  await mobile.locator("#stick").dispatchEvent("pointerup", { pointerId: 201, pointerType: "touch", clientX: steerCenter.x, clientY: steerCenter.y + 32 });
  await mobile.locator("#stick").dispatchEvent("pointerdown", { pointerId: 202, pointerType: "touch", clientX: steerCenter.x, clientY: steerCenter.y });
  await mobile.locator("#stick").dispatchEvent("pointermove", { pointerId: 202, pointerType: "touch", clientX: steerCenter.x, clientY: steerCenter.y - 32 });
  const steerLeft = Number(await mobile.locator("#stick").getAttribute("data-steer"));
  assert.ok(steerLeft > 0, "dragging the joystick toward physical screen-left must command a left turn: " + steerLeft);
  await mobile.locator("#stick").dispatchEvent("pointerup", { pointerId: 202, pointerType: "touch", clientX: steerCenter.x, clientY: steerCenter.y - 32 });
  const gyroBounds = await mobile.locator("#gyroToggle").boundingBox();
  assert.ok(gyroBounds.width >= 52 && gyroBounds.height >= 52, "gyro toggle must remain a large mobile touch target");
  assert.ok((await mobile.locator("#gas").boundingBox()).width >= 60, "mobile gas pedal should remain touch-sized");
  assert.equal(await mobile.locator("#gas img").getAttribute("alt"), "گاز", "gas pedal should use a CDN icon with accessible alternative text");
  assert.equal(await mobile.locator("#brake img").getAttribute("alt"), "ترمز", "brake pedal should use a CDN icon with accessible alternative text");
  assert.equal(await mobile.locator("#nitro img").getAttribute("alt"), "نیترو", "nitro control should use a CDN icon with accessible alternative text");
  assert.ok((await mobile.locator("#nitro").boundingBox()).width >= 60, "mobile nitro control should remain touch-sized");
  const mobileStatsBounds = await mobile.locator(".stats").boundingBox(), mobileSoundBounds = await mobile.locator("#soundToggle").boundingBox();
  const mobileHudOverlap = !(mobileStatsBounds.x + mobileStatsBounds.width <= mobileSoundBounds.x || mobileSoundBounds.x + mobileSoundBounds.width <= mobileStatsBounds.x || mobileStatsBounds.y + mobileStatsBounds.height <= mobileSoundBounds.y || mobileSoundBounds.y + mobileSoundBounds.height <= mobileStatsBounds.y);
  assert.equal(mobileHudOverlap, false, "compact mobile race stats should not overlap sound controls: " + JSON.stringify({mobileStatsBounds,mobileSoundBounds}));
  assert.ok(await mobile.locator("#pause").evaluate(el => el.getBoundingClientRect().right <= innerWidth), "mobile pause control should remain inside the viewport");

  // The desktop and mobile smoke pages keep their own requestAnimationFrame
  // loops alive. Leaving the WebGL race scene mounted while the long economy
  // simulation runs can retain GPU resources and continue background rendering
  // in Chromium, starving the economy page's main thread. The later PWA checks
  // only need the same browser context/origin, so release both scenes now.
  await mobile.close();
  assert.deepEqual(errors, [], "mobile page should not throw runtime exceptions");
  console.log("PASS: mobile-only browser smoke completed, including touch controls, mobile rendering, and race HUD.");
} finally {
  clearInterval(progressHeartbeat);
  await browser.close();
}
