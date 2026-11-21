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


test("welcome reward is one-time and daily reward is idempotent per UTC day", async () => {
  const { coordinator, files, writes } = setup();
  const freshId = 100003;
  const first = await call(coordinator, freshId, "/v1/rewards/claim", "POST", {});
  assert.equal(first.status, 200);
  const firstBody = await first.json();
  assert.equal(firstBody.welcome.granted, true);
  assert.equal(firstBody.welcome.simoleons, 5000);
  assert.equal(firstBody.welcome.sim_cash, 10);
  assert.equal(firstBody.daily.granted, true);
  assert.equal(firstBody.daily.simoleons, 100);
  assert.deepEqual(firstBody.balances, { simoleons: 5100, sim_cash: 10 });

  const second = await call(coordinator, freshId, "/v1/rewards/claim", "POST", {});
  assert.equal(second.status, 200);
  const secondBody = await second.json();
  assert.equal(secondBody.welcome.granted, false);
  assert.equal(secondBody.daily.granted, false);
  assert.deepEqual(secondBody.balances, { simoleons: 5100, sim_cash: 10 });
  assert.equal(secondBody.revision, firstBody.revision, "a no-op retry must not advertise an unpersisted revision");
  assert.equal(files.get("players/100003.json").revision, firstBody.revision);
  assert.equal(files.get("players/100003.json").market_account.rewards.daily_last_claim_utc, firstBody.claimed_day_utc);
  assert.equal(writes.length, 1);

  const otherPlayer = await call(coordinator, 100005, "/v1/rewards/claim", "POST", {});
  assert.equal(otherPlayer.status, 200);
  const otherBody = await otherPlayer.json();
  assert.equal(otherBody.welcome.granted, true, "welcome eligibility must be isolated per player");
  assert.equal(otherBody.daily.granted, true, "daily eligibility must be isolated per player");
  assert.deepEqual(otherBody.balances, { simoleons: 5100, sim_cash: 10 });
});

test("daily rewards work for existing accounts without granting the welcome bonus", async () => {
  const { coordinator, files } = setup();
  const response = await call(coordinator, 100001, "/v1/rewards/claim", "POST", {});
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.welcome.granted, false);
  assert.equal(body.daily.granted, true);
  assert.equal(body.balances.simoleons, 200);
  assert.equal(body.balances.sim_cash, 0);
  assert.equal(files.get("players/100001.json").game_state.economy.sim_cash, 0);
});

test("normal profile saves cannot overwrite either server-owned currency", async () => {
  const { coordinator, files } = setup();
  const claim = await call(coordinator, 100001, "/v1/rewards/claim", "POST", {});
  assert.equal(claim.status, 200);
  const saved = await call(coordinator, 100001, "/v1/profile", "PUT", {
    expected_revision: files.get("players/100001.json").revision,
    game_state: { economy: { simoleons: 999999, sim_cash: 999999 }, storage: { capacity: 10, items: {} } }
  });
  assert.equal(saved.status, 200);
  const profile = files.get("players/100001.json");
  assert.equal(profile.market_account.simoleons, 200);
  assert.equal(profile.market_account.sim_cash, 0);
  assert.equal(profile.game_state.economy.simoleons, 200);
  assert.equal(profile.game_state.economy.sim_cash, 0);
});


test("first-login eligibility survives an initial profile save before reward claim", async () => {
  const { coordinator, files } = setup();
  const freshId = 100004;
  const initial = await call(coordinator, freshId, "/v1/profile");
  assert.equal(initial.status, 200);
  assert.deepEqual(files.get("players/100004.json"), {
    schema_version: 1,
    user_id: freshId,
    revision: 0,
    created_at: null,
    updated_at: null,
    market_account: null,
    game_state: null
  }, "first authenticated profile read must create the private player JSON file");
  const created = await call(coordinator, freshId, "/v1/profile", "PUT", {
    expected_revision: 0,
    game_state: { economy: { simoleons: 25000, sim_cash: 25 }, storage: { capacity: 30, items: {} } }
  });
  assert.equal(created.status, 200);
  assert.equal(files.get("players/100004.json").market_account.rewards.welcome_eligible, true);

  const claimed = await call(coordinator, freshId, "/v1/rewards/claim", "POST", {});
  assert.equal(claimed.status, 200);
  const body = await claimed.json();
  assert.equal(body.welcome.granted, true);
  assert.equal(body.balances.simoleons, 30100);
  assert.equal(body.balances.sim_cash, 35);
  assert.equal(files.get("players/100004.json").market_account.rewards.welcome_eligible, undefined);
});


test("simultaneous reward claims grant each reward once and keep the stored revision authoritative", async () => {
  const { coordinator, files, writes } = setup();
  const freshId = 100006;
  const responses = await Promise.all([
    call(coordinator, freshId, "/v1/rewards/claim", "POST", {}),
    call(coordinator, freshId, "/v1/rewards/claim", "POST", {})
  ]);
  assert.deepEqual(responses.map(response => response.status), [200, 200]);
  const bodies = await Promise.all(responses.map(response => response.json()));
  assert.equal(bodies.filter(body => body.welcome.granted).length, 1);
  assert.equal(bodies.filter(body => body.daily.granted).length, 1);
  assert.deepEqual(files.get("players/100006.json").market_account && {
    simoleons: files.get("players/100006.json").market_account.simoleons,
    sim_cash: files.get("players/100006.json").market_account.sim_cash
  }, { simoleons: 5100, sim_cash: 10 });
  assert.equal(bodies[0].revision, files.get("players/100006.json").revision);
  assert.equal(bodies[1].revision, files.get("players/100006.json").revision);
  assert.equal(writes.length, 1);
});
