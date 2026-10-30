import { chromium } from "playwright";
import assert from "node:assert/strict";

const browser = await chromium.launch({ headless: true });
const errors = [];
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  page.on("pageerror", error => errors.push(error.message));
  await page.goto("http://127.0.0.1:4173/", { waitUntil: "networkidle" });
  await page.locator("#play").click();
  assert.equal(await page.locator(".world").count(), 10, "all 10 worlds should be selectable");
  await page.getByRole("button", { name: /Neon City/ }).click();
  assert.equal(await page.locator(".stage").count(), 5, "each world should expose five stages");
  await page.getByRole("button", { name: /STAGE 05.*Neon Finale/ }).click();
  await page.locator("#startRace").click();
  assert.equal(await page.locator("#soundToggle").getAttribute("aria-pressed"), "true", "sound should start enabled");
  await page.locator("#soundToggle").click();
  assert.equal(await page.locator("#soundToggle").getAttribute("aria-pressed"), "false", "sound toggle should mute audio");
  await page.locator("#soundToggle").click();
  assert.equal(await page.locator("#soundToggle").getAttribute("aria-pressed"), "true", "sound toggle should restore audio");
  assert.equal(await page.locator("#hud").isVisible(), true, "race HUD should become visible");
  assert.match(await page.locator("#stageName").textContent(), /WORLD 05.*STAGE 05/);
  await page.keyboard.down("ArrowUp");
  await page.waitForTimeout(900);
  await page.keyboard.up("ArrowUp");
  assert.ok(Number(await page.locator("#speed").textContent()) > 0, "accelerator should increase speed");
  await page.locator("#pause").click();
  assert.equal(await page.locator("#pausePanel").isVisible(), true, "pause panel should open");
  await page.locator("#resume").click();
  assert.equal(await page.locator("#pausePanel").isVisible(), false, "resume should close pause panel");
  await page.locator("#pause").click();
  await page.locator("#quitRace").click();
  assert.equal(await page.locator("#select").isVisible(), true, "exit should return to stage selection");
  assert.deepEqual(errors, [], "page should not throw runtime exceptions");
  const mobile = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  mobile.on("pageerror", error => errors.push(error.message));
  await mobile.goto("http://127.0.0.1:4173/", { waitUntil: "networkidle" });
  await mobile.locator("#play").click();
  await mobile.locator("#startRace").click();
  assert.equal(await mobile.locator("#hud").isVisible(), true, "mobile race HUD should render");
  assert.ok((await mobile.locator("#stick").boundingBox()).width >= 90, "mobile joystick should remain touch-sized");
  assert.ok((await mobile.locator("#gas").boundingBox()).width >= 60, "mobile gas pedal should remain touch-sized");
  assert.deepEqual(errors, [], "desktop and mobile pages should not throw runtime exceptions");
  process.stdout.write("Browser smoke passed: 10 worlds, 5 stages/world, race start, acceleration, pause/resume, stage exit, and mobile layout.
");
} finally {
  await browser.close();
}
