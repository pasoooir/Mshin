import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/menu-accessibility.js", import.meta.url), "utf8");
const html = await readFile(new URL("../index.html", import.meta.url), "utf8");

test("race HQ tabs support vertical and horizontal arrows plus Home and End", () => {
  for (const key of ["ArrowDown", "ArrowUp", "ArrowRight", "ArrowLeft", "Home", "End"]) {
    assert.ok(source.includes(key), `missing keyboard navigation for ${key}`);
  }
  assert.ok(source.includes('nav.setAttribute("aria-orientation", "vertical")'));
});

test("keyboard navigation delegates activation to the existing game tab handler", () => {
  assert.ok(source.includes("tab.click()"));
  assert.ok(source.includes("event.preventDefault()"));
  assert.ok(source.includes("[role='tab']:not(:disabled)"));
});

test("disabled tabs are skipped and only the selected tab remains in the tab order", () => {
  assert.ok(source.includes("tab.tabIndex = tab === selected ? 0 : -1"));
  assert.ok(source.includes("if (!tab || tab.disabled)"));
});

test("keyboard accessibility module is loaded by the GitHub Pages entry point", () => {
  assert.ok(html.includes('src="./src/menu-accessibility.js"'));
});
