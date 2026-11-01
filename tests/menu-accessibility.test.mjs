import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/menu-accessibility.js", import.meta.url), "utf8");
const html = await readFile(new URL("../index.html", import.meta.url), "utf8");

test("race HQ tabs support directional, Home and End keyboard navigation", () => {
  assert.match(source, /ArrowDown/);
  assert.match(source, /ArrowUp/);
  assert.match(source, /ArrowRight/);
  assert.match(source, /ArrowLeft/);
  assert.match(source, /event\.key === "Home"/);
  assert.match(source, /event\.key === "End"/);
});

test("keyboard navigation reuses existing tab click behavior and skips disabled tabs", () => {
  assert.match(source, /tab\.click\(\)/);
  assert.match(source, /\[role='tab':not\(:disabled\)\]/);
  assert.match(source, /event\.preventDefault\(\)/);
});

test("only the selected menu tab remains in the tab sequence", () => {
  assert.match(source, /item\.tabIndex = item === tab \? 0 : -1/);
  assert.match(source, /aria-selected='true'/);
});

test("accessibility controller is loaded by the GitHub Pages entry point", () => {
  assert.match(html, /src="\.\/src\/menu-accessibility\.js"/);
});
