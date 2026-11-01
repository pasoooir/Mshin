import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const html = await readFile(new URL("../index.html", import.meta.url), "utf8");

test("race HQ navigation uses a dedicated vertical control rail and content bay", () => {
  assert.match(html, /Motorsport race-control \/ garage-first navigation/);
  assert.match(html, /#select \.menuTabs\{grid-column:1;grid-row:2;display:flex;flex-direction:column/);
  assert.match(html, /#select \.menuBody\{grid-column:2;grid-row:2/);
});

test("worlds, stages, garage and workshop use responsive card grids rather than forced horizontal rails", () => {
  assert.match(html, /#select \.visualRail\{[\s\S]*?display:grid!important/);
  assert.match(html, /grid-template-columns:repeat\(5,minmax\(0,1fr\)\)/);
  assert.match(html, /#select \.garage\{grid-template-columns:repeat\(3,minmax\(0,1fr\)\)\}/);
  assert.match(html, /@media\(max-width:620px\)[\s\S]*?#select \.visualRail\{grid-template-columns:repeat\(2,minmax\(0,1fr\)\)/);
});

test("home screen becomes a motorsport-themed split hero with mobile stacking", () => {
  assert.match(html, /#home \.panel\.narrow\{[\s\S]*?grid-template-columns:minmax\(0,1\.08fr\) minmax\(280px,\.92fr\)/);
  assert.match(html, /@media\(max-width:620px\)[\s\S]*?#home \.panel\.narrow\{[\s\S]*?grid-template-columns:1fr/);
});
