import test from "node:test";
import assert from "node:assert/strict";
import { createInitialCity } from "../src/city/city-view.js";
import { stepCityTraffic } from "../src/city/city-traffic.js";

test("new city starts with one fixed highway access tile and otherwise empty plots", () => {
  const city = createInitialCity(12345);
  const roads = city.grid.flatMap((row, y) => row.flatMap((cell, x) => cell === "road" ? [{ x, y }] : []));
  assert.deepEqual(roads, [{ x: 13, y: 0 }]);
  assert.equal(city.buildings.length, 0);
  assert.equal(city.zones.length, 0);
});

test("highway gateway spawns inbound traffic when a player road connects to it", () => {
  const city = createInitialCity(12345);
  city.grid[1][13] = "road";
  city.tick = 8;
  stepCityTraffic(city, 1);
  assert.equal(city.traffic.length, 1);
  const vehicle = city.traffic[0];
  assert.equal(vehicle.x, 13);
  assert.equal(vehicle.y, 0);
  assert.equal(vehicle.previousY, -1);
  assert.equal(vehicle.targetX, 13);
  assert.equal(vehicle.targetY, 1);
});

test("city traffic exits at the highway gateway instead of reversing into the city", () => {
  const city = createInitialCity(12345);
  city.grid[1][13] = "road";
  city.grid[2][13] = "road";
  city.tick = 1;
  city.traffic = [{
    id: 1, x: 13, y: 1, previousX: 13, previousY: 2,
    targetX: 13, targetY: 0, headingX: 0, headingY: -1,
    heading: -Math.PI / 2, routeStep: 1, speed: 1, color: "#f2bd4d"
  }];
  stepCityTraffic(city, 1);
  assert.equal(city.traffic[0].x, 13);
  assert.equal(city.traffic[0].y, 0);
  assert.equal(city.traffic[0].targetX, null);
  stepCityTraffic(city, 1);
  assert.equal(city.traffic.length, 0);
});
