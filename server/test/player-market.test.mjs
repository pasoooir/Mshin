import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createApp, signAccessToken } from "../src/index.mjs";

const secret = "test-only-secret-that-is-long-enough-123456";
async function fixture() {
  const directory = await mkdtemp(path.join(os.tmpdir(), "mshin-market-"));
  const server = createApp({
    dataDir: directory, authSecret: secret, devAuthEnabled: true,
    devIdentities: new Map([["admin", 100001], ["player2", 100002]])
  });
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  const base = "http://127.0.0.1:" + server.address().port;
  const token = id => signAccessToken(id, secret);
  const json = async (id, route, method = "GET", body) => {
    const response = await fetch(base + route, {
      method,
      headers: { authorization: "Bearer " + token(id), ...(body ? { "content-type": "application/json" } : {}) },
      body: body ? JSON.stringify(body) : undefined
    });
    return { status: response.status, body: await response.json() };
  };
  const seed = async (id, gameState) => {
    const current = await json(id, "/v1/profile");
    const response = await json(id, "/v1/profile", "PUT", {
      expected_revision: Number(current.body.revision || 0), game_state: gameState
    });
    assert.equal(response.status, 200);
  };
  return {
    directory, base, json, seed,
    close: async () => { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); await rm(directory, { recursive: true, force: true }); }
  };
}
const state = ({ coins, items, capacity = 50, level = 10 }) => ({
  game: { level, city_name: "Test City" },
  economy: { simoleons: coins, sim_cash: 25, golden_keys: 10 },
  storage: { capacity, items },
  economy_ledger: { transaction_sequence: 0, transaction_ledger: [] }
});

test("admin lists stock, player2 buys it, both wallets and inventories reconcile", async t => {
  const f = await fixture(); t.after(f.close);
  await f.seed(100001, state({ coins: 500, items: { metal: 8 } }));
  await f.seed(100002, state({ coins: 300, items: {} }));
  const listing = await f.json(100001, "/v1/market/list", "POST", { item_id: "metal", quantity: 5, unit_price: 12 });
  assert.equal(listing.status, 201);
  const listingId = listing.body.listing.listing_id;
  assert.equal(listing.body.listing.total_price, 60);
  const myShop = await f.json(100001, "/v1/market/mine");
  assert.equal(myShop.status, 200);
  assert.equal(myShop.body.listings.length, 1);
  assert.equal(myShop.body.listings[0].listing_id, listingId);
  assert.equal((await f.json(100001, "/v1/market")).body.listings.length, 0, "sellers must not see their own listing as purchasable stock");
  let admin = (await f.json(100001, "/v1/profile")).body.game_state;
  assert.equal(admin.storage.items.metal, 3, "listing must reserve seller goods");
  assert.equal(admin.economy.simoleons, 500, "listing must not pay seller before purchase");
  const adminProfile = await f.json(100001, "/v1/profile");
  const forgedSave = await f.json(100001, "/v1/profile", "PUT", {
    expected_revision: adminProfile.body.revision,
    game_state: state({ coins: 999999, items: { metal: 4 }, capacity: 50 })
  });
  assert.equal(forgedSave.status, 200);
  admin = (await f.json(100001, "/v1/profile")).body.game_state;
  assert.equal(admin.economy.simoleons, 500, "client saves must not overwrite authoritative market wallet");
  assert.equal(admin.storage.items.metal, 4, "normal inventory changes must still synchronize with the profile");
  const visible = await f.json(100002, "/v1/market");
  assert.equal(visible.status, 200);
  assert.equal(visible.body.listings.length, 1);
  const purchase = await f.json(100002, "/v1/market/" + listingId + "/buy", "POST", {});
  assert.equal(purchase.status, 200);
  assert.equal(purchase.body.total_paid, 60);
  admin = (await f.json(100001, "/v1/profile")).body.game_state;
  const player2 = (await f.json(100002, "/v1/profile")).body.game_state;
  assert.equal(admin.economy.simoleons, 560);
  assert.equal(admin.storage.items.metal, 4);
  assert.equal(player2.economy.simoleons, 240);
  assert.equal(player2.storage.items.metal, 5);
  assert.equal(admin.economy_ledger.transaction_ledger.at(-1).type, "player_market_sale");
  assert.equal(player2.economy_ledger.transaction_ledger.at(-1).type, "player_market_purchase");
  assert.equal((await f.json(100002, "/v1/market/" + listingId + "/buy", "POST", {})).status, 404, "a sold listing cannot be bought twice");
});

test("seller can cancel an active listing and receive the exact reserved stock back", async t => {
  const f = await fixture(); t.after(f.close);
  await f.seed(100001, state({ coins: 100, items: { wood: 6 }, capacity: 10 }));
  await f.seed(100002, state({ coins: 100, items: {} }));
  const listing = await f.json(100001, "/v1/market/list", "POST", { item_id: "wood", quantity: 4, unit_price: 20 });
  assert.equal(listing.status, 201);
  const id = listing.body.listing.listing_id;
  assert.equal((await f.json(100002, "/v1/market/" + id + "/cancel", "POST", {})).status, 403);
  const cancelled = await f.json(100001, "/v1/market/" + id + "/cancel", "POST", {});
  assert.equal(cancelled.status, 200);
  const admin = (await f.json(100001, "/v1/profile")).body.game_state;
  assert.equal(admin.storage.items.wood, 6);
  assert.equal(admin.economy.simoleons, 100);
  assert.equal((await f.json(100002, "/v1/market")).body.listings.length, 0);
});

test("market rejects insufficient funds, full warehouse, self purchase and locked goods without mutation", async t => {
  const f = await fixture(); t.after(f.close);
  await f.seed(100001, state({ coins: 100, items: { metal: 4, electrical: 2 } }));
  await f.seed(100002, state({ coins: 5, items: { wood: 5 }, capacity: 5, level: 10 }));
  const metal = await f.json(100001, "/v1/market/list", "POST", { item_id: "metal", quantity: 2, unit_price: 10 });
  assert.equal(metal.status, 201);
  const metalId = metal.body.listing.listing_id;
  assert.equal((await f.json(100001, "/v1/market/" + metalId + "/buy", "POST", {})).status, 409);
  assert.equal((await f.json(100002, "/v1/market/" + metalId + "/buy", "POST", {})).body.error, "insufficient_simoleons");
  let buyer = (await f.json(100002, "/v1/profile")).body.game_state;
  assert.equal(buyer.economy.simoleons, 5);
  assert.equal(buyer.storage.items.metal, undefined);
  assert.equal((await f.json(100001, "/v1/market/" + metalId + "/cancel", "POST", {})).status, 200);

  const g = await fixture(); t.after(g.close);
  await g.seed(100001, state({ coins: 100, items: { metal: 2, electrical: 2 } }));
  await g.seed(100002, state({ coins: 100, items: { wood: 5 }, capacity: 5 }));
  const second = await g.json(100001, "/v1/market/list", "POST", { item_id: "metal", quantity: 2, unit_price: 2 });
  assert.equal(second.status, 201);
  const secondId = second.body.listing.listing_id;
  assert.equal((await g.json(100002, "/v1/market/" + secondId + "/buy", "POST", {})).body.error, "warehouse_capacity");
  const buyerAfter = (await g.json(100002, "/v1/profile")).body.game_state;
  assert.equal(buyerAfter.economy.simoleons, 100);
  assert.equal(buyerAfter.storage.items.metal, undefined);
  const locked = await g.json(100001, "/v1/market/list", "POST", { item_id: "electrical", quantity: 1, unit_price: 100 });
  assert.equal(locked.status, 409);
});

test("two simultaneous buyers cannot purchase the same listing twice", async t => {
  const f = await fixture(); t.after(f.close);
  await f.seed(100001, state({ coins: 100, items: { metal: 3 } }));
  await f.seed(100002, state({ coins: 100, items: {} }));
  const listing = await f.json(100001, "/v1/market/list", "POST", { item_id: "metal", quantity: 3, unit_price: 10 });
  const id = listing.body.listing.listing_id;
  const results = await Promise.all([
    f.json(100002, "/v1/market/" + id + "/buy", "POST", {}),
    f.json(100002, "/v1/market/" + id + "/buy", "POST", {})
  ]);
  assert.deepEqual(results.map(x => x.status).sort(), [200, 404]);
  const buyer = (await f.json(100002, "/v1/profile")).body.game_state;
  const seller = (await f.json(100001, "/v1/profile")).body.game_state;
  assert.equal(buyer.economy.simoleons, 70);
  assert.equal(buyer.storage.items.metal, 3);
  assert.equal(seller.economy.simoleons, 130);
  assert.equal(seller.storage.items.metal, undefined);
});

test("listing validation rejects unknown goods, excessive price, quantity and unauthenticated calls", async t => {
  const f = await fixture(); t.after(f.close);
  await f.seed(100001, state({ coins: 1000, items: { metal: 5000 } }));
  const unknown = await f.json(100001, "/v1/market/list", "POST", { item_id: "fake_item", quantity: 1, unit_price: 1 });
  const price = await f.json(100001, "/v1/market/list", "POST", { item_id: "metal", quantity: 1, unit_price: 1000 });
  const quantity = await f.json(100001, "/v1/market/list", "POST", { item_id: "metal", quantity: 501, unit_price: 1 });
  assert.equal(unknown.status, 400);
  assert.equal(price.status, 400);
  assert.equal(quantity.status, 400);
  const response = await fetch(f.base + "/v1/market");
  assert.equal(response.status, 401);
});
