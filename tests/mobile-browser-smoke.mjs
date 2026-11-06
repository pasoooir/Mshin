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
  const viewportMeta = await mobile.locator('meta[name="viewport"]').getAttribute("content");
  assert.match(viewportMeta, /viewport-fit=cover/, "mobile layout must opt into the device safe-area viewport");
  const initialVisualViewport = await mobile.evaluate(() => ({
    supported: Boolean(window.visualViewport),
    width: window.visualViewport?.width,
    height: window.visualViewport?.height,
    scale: window.visualViewport?.scale
  }));
  assert.equal(initialVisualViewport.supported, true, "mobile browser must expose VisualViewport metrics");
  assert.ok(Math.abs(initialVisualViewport.width - 390) <= 1 && Math.abs(initialVisualViewport.height - 844) <= 1, "initial VisualViewport must match the visible phone area");
  assert.ok(initialVisualViewport.scale >= 1, "the game must not unexpectedly zoom the mobile visual viewport");
  await mobile.setViewportSize({ width: 360, height: 740 });
  await mobile.waitForFunction(() => Math.abs((window.MshinViewport?.visualViewportWidth || 0) - 360) <= 1
    && Math.abs((window.MshinViewport?.visualViewportHeight || 0) - 740) <= 1
    && window.MshinViewport.width === 740 && window.MshinViewport.height === 360, undefined, { timeout: 5000 });
  const compactVisualViewport = await mobile.evaluate(() => ({
    logicalWidth: window.MshinViewport.width,
    logicalHeight: window.MshinViewport.height,
    canvasWidth: document.querySelector("#game").width,
    canvasHeight: document.querySelector("#game").height
  }));
  assert.ok(compactVisualViewport.canvasWidth > compactVisualViewport.canvasHeight, "canvas must remain landscape after the browser's visible viewport shrinks");
  await mobile.setViewportSize({ width: 390, height: 844 });
  await mobile.waitForFunction(() => Math.abs((window.MshinViewport?.visualViewportWidth || 0) - 390) <= 1
    && Math.abs((window.MshinViewport?.visualViewportHeight || 0) - 844) <= 1, undefined, { timeout: 5000 });
  const safeAreaLayout = await mobile.evaluate(() => {
    const rect = selector => {
      const r = document.querySelector(selector).getBoundingClientRect();
      return { left: r.left, top: r.top, right: r.right, bottom: r.bottom };
    };
    return { width: innerWidth, height: innerHeight, topbar: rect(".topbar"), controls: rect(".controls"), nitro: rect(".nitroWrap") };
  });
  assert.ok(safeAreaLayout.topbar.left >= 0 && safeAreaLayout.topbar.right <= safeAreaLayout.width, "top HUD must remain inside the safe visible width");
  assert.ok(safeAreaLayout.topbar.top >= 0 && safeAreaLayout.controls.bottom <= safeAreaLayout.height && safeAreaLayout.nitro.bottom <= safeAreaLayout.height, "HUD and touch controls must remain inside the safe visible height");

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
  await mobile.waitForFunction(() => document.querySelector("#countdownOverlay").classList.contains("hidden"), undefined, { timeout: 15000 }).catch(async error => {
    const countdownState = await mobile.evaluate(() => ({
      overlayClass: document.querySelector("#countdownOverlay")?.className,
      countdownText: document.querySelector("#countdownValue")?.textContent,
      audioReady: window.MshinAudioReady ?? null,
      gameState: window.MshinGameState ?? null,
      orientationCalls: window.__orientationCalls
    }));
    throw new Error("mobile race countdown did not complete: " + JSON.stringify(countdownState) + " | " + error.message);
  });
  await mobile.waitForFunction(() => window.Mshin3DRenderer?.frames > 10 && window.Mshin3DRenderer?.quality?.mobile === true, undefined, { timeout: 12000 }).catch(async error => {
    const diagnostic = await mobile.evaluate(pageErrors => ({
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
      pageErrors,
    }), errors.slice(-12));
    throw new Error("mobile WebGL renderer did not reach a stable frame state: " + JSON.stringify(diagnostic) + " | " + error.message);
  });
  await mobile.waitForFunction(() => window.Mshin3DRenderer?.cameraTrackFollowing === true, undefined, { timeout: 5000 });
  const cameraFollowMetrics = await mobile.evaluate(() => ({
    following: window.Mshin3DRenderer?.cameraTrackFollowing,
    lookAheadT: window.Mshin3DRenderer?.cameraLookAheadT,
    behindT: window.Mshin3DRenderer?.cameraBehindT
  }));
  assert.equal(cameraFollowMetrics.following, true, "mobile race camera must follow the actual curved circuit");
  assert.ok(cameraFollowMetrics.lookAheadT > cameraFollowMetrics.behindT, "mobile chase camera must look ahead along the circuit, not along a straight tangent");
  await mobile.waitForFunction(() => window.Mshin3DRenderer?.trackBuildProgress === 1, undefined, { timeout: 20000 }).catch(async error => {
    const progress = await mobile.evaluate(() => ({ progress: window.Mshin3DRenderer?.trackBuildProgress, environment: window.Mshin3DRenderer?.environmentCounts, frames: window.Mshin3DRenderer?.frames }));
    throw new Error("mobile race terrain and environment did not finish building: " + JSON.stringify(progress) + " | " + error.message);
  });
  assert.equal(await mobile.evaluate(() => window.Mshin3DRenderer?.trackHalfWidth), 220, "mobile race must load the widened 440-unit circuit");
  await mobile.evaluate(() => { window.Mshin3DRenderer.captureNextFrameSample = true; });
  await mobile.waitForFunction(() => window.Mshin3DRenderer?.lastFramePixelSample?.context === true, undefined, { timeout: 5000 });
  const raceFrameSample = await mobile.evaluate(() => window.Mshin3DRenderer.lastFramePixelSample);
  await captureScreenshot(mobile, "artifacts/racing-mobile-track.png");
  assert.ok(raceFrameSample.visiblePixels > 1000, "mobile race scene must contain substantial visible rendered terrain/track pixels: " + JSON.stringify(raceFrameSample));
  assert.ok(raceFrameSample.roadLikePixels > 500, "mobile race scene must visibly render a broad neutral-asphalt track surface, not only the green terrain and cars: " + JSON.stringify(raceFrameSample));
  const trackMeshMetrics = await mobile.evaluate(() => ({ terrainBaseVertices: window.Mshin3DRenderer?.terrainBaseVertices, roadVertices: window.Mshin3DRenderer?.roadVertices }));
  assert.ok(trackMeshMetrics.terrainBaseVertices >= 6 && trackMeshMetrics.roadVertices >= 1000, "mobile renderer must upload separate terrain and full-width asphalt circuit meshes: " + JSON.stringify(trackMeshMetrics));
  assert.ok(raceFrameSample.drawCalls >= 8, "mobile race scene must submit terrain, road and environment meshes: " + JSON.stringify(raceFrameSample));
  assert.ok(raceFrameSample.triangles > 1000, "mobile race scene must render substantial track and environment geometry: " + JSON.stringify(raceFrameSample));
  assert.ok(raceFrameSample.uniqueColors >= 12, "mobile race scene must show multiple visible surface/material colors rather than only the clear color and cars: " + JSON.stringify(raceFrameSample));
  assert.equal(raceFrameSample.glError, 0, "mobile race scene pixel capture must not report a WebGL error: " + JSON.stringify(raceFrameSample));
  const trackScaleMetrics = await mobile.evaluate(() => window.MshinPerformance);
  assert.equal(trackScaleMetrics.trackLengthScale, 10, "mobile race runtime must use the tenfold circuit scale");
  assert.equal(trackScaleMetrics.trackRadiusX, 11800, "mobile race runtime must expose the extended horizontal circuit radius");
  assert.equal(trackScaleMetrics.trackRadiusY, 7600, "mobile race runtime must expose the extended vertical circuit radius");
  assert.equal(trackScaleMetrics.roadWidth, 360, "the tenfold track must preserve the original road width");
  const drawStageMetrics = await mobile.evaluate(() => ({
    uniforms: window.Mshin3DRenderer?.maxDrawUniformsMs,
    buffers: window.Mshin3DRenderer?.maxDrawBufferSetupMs,
    submit: window.Mshin3DRenderer?.maxDrawSubmitMs
  }));
  for (const [stage, duration] of Object.entries(drawStageMetrics)) {
    assert.ok(Number.isFinite(duration) && duration >= 0, "mobile WebGL must expose a valid " + stage + " timing: " + JSON.stringify(drawStageMetrics));
  }
  const mobileRenderQuality = await mobile.evaluate(() => window.Mshin3DRenderer.quality);
  assert.ok(mobileRenderQuality.pixelRatio <= 0.8 && mobileRenderQuality.width <= 700 && mobileRenderQuality.height <= 700, "mobile WebGL must use a reduced render resolution to protect frame pacing: " + JSON.stringify(mobileRenderQuality));
  assert.equal(await mobile.locator("#hud").isVisible(), true, "mobile race HUD should render");
  // Verify the opening nitro pickup is actually reachable on a touch-first race,
  // not merely present in the static track data.
  const gasBounds = await mobile.locator("#gas").boundingBox();
  await mobile.locator("#gas").dispatchEvent("pointerdown", { pointerId: 303, pointerType: "touch", clientX: gasBounds.x + gasBounds.width / 2, clientY: gasBounds.y + gasBounds.height / 2 });
  try {
    await mobile.waitForFunction(() => Number.parseFloat(document.querySelector("#nitroFill")?.style.width || "0") >= 50 && (window.MshinPerformance?.pickups || 0) >= 1, undefined, { timeout: 12000 });
  } catch (error) {
    const pickupState = await mobile.evaluate(() => ({ nitro: document.querySelector("#nitroFill")?.style.width, performance: window.MshinPerformance, traffic: window.MshinTrafficRoster }));
    throw new Error("mobile player could not collect the opening nitro pickup while accelerating: " + JSON.stringify(pickupState) + " | " + error.message);
  } finally {
    await mobile.locator("#gas").dispatchEvent("pointerup", { pointerId: 303, pointerType: "touch", clientX: gasBounds.x + gasBounds.width / 2, clientY: gasBounds.y + gasBounds.height / 2 });
  }

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
  const fourPointerState = await mobile.evaluate(() => {
    const element = id => document.querySelector("#" + id);
    const send = (target, type, pointerId, x, y) => target.dispatchEvent(new PointerEvent(type, {
      bubbles: true, cancelable: true, pointerId, pointerType: "touch",
      clientX: x, clientY: y, button: 0, buttons: type === "pointerup" ? 0 : 1
    }));
    const stick = element("stick"), gas = element("gas"), brake = element("brake"), nitro = element("nitro");
    const pad = stick.getBoundingClientRect(), center = { x: pad.x + pad.width / 2, y: pad.y + pad.height / 2 };
    const nitroBefore = Number.parseFloat(element("nitroFill").style.width || "0");
    send(stick, "pointerdown", 401, center.x, center.y);
    send(stick, "pointermove", 401, center.x, center.y + 38);
    const gasRect = gas.getBoundingClientRect(), brakeRect = brake.getBoundingClientRect(), nitroRect = nitro.getBoundingClientRect();
    send(gas, "pointerdown", 402, gasRect.x + gasRect.width / 2, gasRect.y + gasRect.height / 2);
    send(brake, "pointerdown", 403, brakeRect.x + brakeRect.width / 2, brakeRect.y + brakeRect.height / 2);
    send(nitro, "pointerdown", 404, nitroRect.x + nitroRect.width / 2, nitroRect.y + nitroRect.height / 2);
    return {
      steer: Number(stick.dataset.steer),
      gas: gas.getAttribute("aria-pressed"),
      brake: brake.getAttribute("aria-pressed"),
      nitroBefore,
      nitroAfter: Number.parseFloat(element("nitroFill").style.width || "0")
    };
  });
  assert.ok(Math.abs(fourPointerState.steer) > 0.1, "steering must remain active while three other independent touch controls are pressed");
  assert.equal(fourPointerState.gas, "true", "gas must retain its own pointer while the other controls are active");
  assert.equal(fourPointerState.brake, "true", "brake must retain its own pointer while the other controls are active");
  assert.ok(fourPointerState.nitroAfter < fourPointerState.nitroBefore, "nitro must activate independently during simultaneous steering, gas and brake input");

  await mobile.evaluate(() => {
    const element = id => document.querySelector("#" + id);
    const cancel = (target, pointerId) => target.dispatchEvent(new PointerEvent("pointercancel", { bubbles: true, cancelable: true, pointerId, pointerType: "touch" }));
    cancel(element("stick"), 401);
    window.dispatchEvent(new PointerEvent("pointercancel", { pointerId: 402, pointerType: "touch" }));
    window.dispatchEvent(new PointerEvent("pointercancel", { pointerId: 403, pointerType: "touch" }));
  });
  assert.equal(await mobile.locator("#gas").getAttribute("aria-pressed"), "false", "pointercancel must release gas without waiting for pointerup");
  assert.equal(await mobile.locator("#brake").getAttribute("aria-pressed"), "false", "pointercancel must release brake without waiting for pointerup");
  assert.equal(Number(await mobile.locator("#stick").getAttribute("data-steer")), 0, "pointercancel must neutralize steering");

  await mobile.evaluate(() => {
    const gas = document.querySelector("#gas"), stick = document.querySelector("#stick");
    const pad = stick.getBoundingClientRect(), gasRect = gas.getBoundingClientRect();
    gas.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, cancelable: true, pointerId: 405, pointerType: "touch", clientX: gasRect.x + gasRect.width / 2, clientY: gasRect.y + gasRect.height / 2 }));
    stick.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, cancelable: true, pointerId: 406, pointerType: "touch", clientX: pad.x + pad.width / 2, clientY: pad.y + pad.height / 2 }));
    gas.dispatchEvent(new PointerEvent("lostpointercapture", { bubbles: true, pointerId: 405, pointerType: "touch" }));
    stick.dispatchEvent(new PointerEvent("lostpointercapture", { bubbles: true, pointerId: 406, pointerType: "touch" }));
  });
  assert.equal(await mobile.locator("#gas").getAttribute("aria-pressed"), "false", "lost pointer capture must release gas");
  assert.equal(Number(await mobile.locator("#stick").getAttribute("data-steer")), 0, "lost pointer capture must release steering");

  await mobile.evaluate(() => {
    const gas = document.querySelector("#gas"), brake = document.querySelector("#brake"), stick = document.querySelector("#stick");
    const pad = stick.getBoundingClientRect(), gasRect = gas.getBoundingClientRect(), brakeRect = brake.getBoundingClientRect();
    gas.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, cancelable: true, pointerId: 407, pointerType: "touch", clientX: gasRect.x + gasRect.width / 2, clientY: gasRect.y + gasRect.height / 2 }));
    brake.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, cancelable: true, pointerId: 408, pointerType: "touch", clientX: brakeRect.x + brakeRect.width / 2, clientY: brakeRect.y + brakeRect.height / 2 }));
    stick.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, cancelable: true, pointerId: 409, pointerType: "touch", clientX: pad.x + pad.width / 2, clientY: pad.y + pad.height / 2 }));
    window.dispatchEvent(new Event("orientationchange"));
  });
  assert.equal(await mobile.locator("#gas").getAttribute("aria-pressed"), "false", "orientation changes must clear gas");
  assert.equal(await mobile.locator("#brake").getAttribute("aria-pressed"), "false", "orientation changes must clear brake");
  assert.equal(Number(await mobile.locator("#stick").getAttribute("data-steer")), 0, "orientation changes must neutralize steering");

  await mobile.evaluate(() => {
    const gas = document.querySelector("#gas"), stick = document.querySelector("#stick"), pad = stick.getBoundingClientRect(), rect = gas.getBoundingClientRect();
    gas.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, cancelable: true, pointerId: 410, pointerType: "touch", clientX: rect.x + rect.width / 2, clientY: rect.y + rect.height / 2 }));
    stick.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, cancelable: true, pointerId: 411, pointerType: "touch", clientX: pad.x + pad.width / 2, clientY: pad.y + pad.height / 2 }));
  });
  await mobile.locator("#pause").click();
  assert.equal(await mobile.locator("#gas").getAttribute("aria-pressed"), "false", "pause must release all held controls");
  assert.equal(Number(await mobile.locator("#stick").getAttribute("data-steer")), 0, "pause must neutralize steering");
  await mobile.locator("#retryRace").click();
  await mobile.waitForFunction(() => document.querySelector("#countdownOverlay").classList.contains("hidden"), undefined, { timeout: 15000 });
  assert.equal(await mobile.locator("#gas").getAttribute("aria-pressed"), "false", "retry must start with no stale throttle pointer");
  assert.equal(Number(await mobile.locator("#stick").getAttribute("data-steer")), 0, "retry must start with neutral steering");

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
