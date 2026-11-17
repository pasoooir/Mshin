import test from "node:test";
import assert from "node:assert/strict";
import { MshinApiCoordinator } from "../src/api.js";

function profile(userId, simoleons, items) {
  return {
    schema_version: 1, user_id: userId, revision: 0,
    created_at: null, updated_at: null,
    market_account: { simoleons },
    game_state: {
      game: { level: 10 },
      economy: { simoleons },
      storage: { capacity: 100, items: { ...items } }
    }
  };
}

function setup() {
  const files = new Map([
    ["players/100001.json", profile(100001, 100, { metal: 10 })],
    ["players/100002.json", profile(100002, 1000, {})],
    ["market/listings.json", { schema_version: 1, listings: [] }]
  ]);
  const writes = [];
  const store = {
    async verifyPrivateRepository() { return { private: true, branch: "main" }; },
    async readJson(path) { return files.has(path) ? structuredClone(files.get(path)) : null; },
    async writeMany(entries) {
      for (const entry of entries) files.set(entry.path, structuredClone(entry.value));
      writes.push(entries.map(entry => entry.path));
      return { commit_sha: "test", files: entries.map(entry => entry.path) };
    }
  };
  const coordinator = new MshinApiCoordinator({}, {
    GITHUB_JSON_REPOSITORY: "pasoooir/mshin-player-data",
    GITHUB_JSON_BRANCH: "main",
    GITHUB_JSON_TOKEN: "test-token"
  });
  coordinator.store = store;
  coordinator.ready = Promise.resolve();
  return { coordinator, files, writes };
}

async function call(coordinator, playerId, path, method = "GET", body) {
  return coordinator.fetch(new Request("https://api.example" + path, {
    method,
    headers: {
      "x-mshin-player-id": String(playerId),
      ...(body === undefined ? {} : { "content-type": "application/json" })
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) })
  }));
}

test("serializes and commits a complete two-player marketplace purchase", async () => {
  const { coordinator, files, writes } = setup();
  const listed = await call(coordinator, 100001, "/v1/market/list", "POST", {
    item_id: "metal", quantity: 5, unit_price: 10, request_id: "seller-request-0001"
  });
  assert.equal(listed.status, 201);
  const offer = (await listed.json()).listing;
  assert.equal(offer.seller_id, 100001);

  const purchased = await call(coordinator, 100002, "/v1/market/" + offer.listing_id + "/buy", "POST", {});
  assert.equal(purchased.status, 200);

  const seller = files.get("players/100001.json");
  const buyer = files.get("players/100002.json");
  const market = files.get("market/listings.json");
  assert.equal(seller.market_account.simoleons, 150);
  assert.equal(buyer.market_account.simoleons, 950);
  assert.equal(seller.game_state.storage.items.metal, 5);
  assert.equal(buyer.game_state.storage.items.metal, 5);
  assert.equal(market.listings[0].status, "sold");
  assert.deepEqual(writes.at(-1).sort(), [
    "market/listings.json", "players/100001.json", "players/100002.json"
  ]);
});

test("profile writes reject email fields and enforce revision checks", async () => {
  const { coordinator, files } = setup();
  const rejected = await call(coordinator, 100001, "/v1/profile", "PUT", {
    expected_revision: 0,
    game_state: { account: { email: "private@example.test" } }
  });
  assert.equal(rejected.status, 400);
  assert.equal((await rejected.json()).error, "email_fields_are_forbidden");

  const saved = await call(coordinator, 100001, "/v1/profile", "PUT", {
    expected_revision: 0,
    game_state: { economy: { simoleons: 200 }, storage: { capacity: 10, items: {} } }
  });
  assert.equal(saved.status, 200);
  assert.equal(files.get("players/100001.json").revision, 1);

  const conflict = await call(coordinator, 100001, "/v1/profile", "PUT", {
    expected_revision: 0,
    game_state: { economy: { simoleons: 300 } }
  });
  assert.equal(conflict.status, 409);
  assert.equal((await conflict.json()).error, "revision_conflict");
});
