import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/menu-accessibility.js", import.meta.url), "utf8");
const html = await readFile(new URL("../index.html", import.meta.url), "utf8");

test("race HQ tabs support vertical and horizontal arrows plus Home and End", () => {
  for (const key of ["ArrowDown", "ArrowUp", "ArrowRight", "ArrowLeft", "Home", "End"]) {
    assert.ok(source.includes(key), `missing keyboard navigation for ${key}`);
  }
  assert.match(source, /aria-orientation", "vertical"/);
});

test("keyboard navigation delegates activation to the existing game tab handler", () => {
  assert.match(source, /tab\.click\(\)/);
  assert.match(source, /event\.preventDefault\(\)/);
  assert.match(source, /\[role='tab'\]:not\(:disabled\)/);
});

test("disabled tabs are skipped and only the selected tab remains in the tab order", () => {
  assert.match(source, /tab\.tabIndex = tab === selected \? 0 : -1/);
  assert.match(source, /if \(!tab \|\| tab\.disabled\)/);
});

test("keyboard accessibility module is loaded by the GitHub Pages entry point", () => {
  assert.match(html, /src="\.\/src\/menu-accessibility\.js"/);
});
