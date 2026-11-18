import { GitHubJsonStore } from "./github-json-store.js";
import { handleMarketRequest } from "../../server/src/market.mjs";

const MAX_BODY_BYTES = 4 * 1024 * 1024;
function hasEmail(value) {
  if (Array.isArray(value)) return value.some(hasEmail);
  if (!value || typeof value !== "object") return false;
  return Object.entries(value).some(([key, child]) =>
    /^(email|email_address|google_email)$/i.test(key) || hasEmail(child)
  );
}
function jsonResponse(status, body, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", "x-content-type-options": "nosniff", ...headers }
  });
}
async function readBody(request) {
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > MAX_BODY_BYTES) throw Object.assign(new Error("payload_too_large"), { status: 413 });
  if (!text) return {};
  try {
    const value = JSON.parse(text);
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error();
    return value;
  } catch {
    throw Object.assign(new Error("invalid_json"), { status: 400 });
  }
}
function profileDefault(playerId) {
  return { schema_version: 1, user_id: playerId, revision: 0, created_at: null, updated_at: null, market_account: null, game_state: null };
}

export class MshinApiCoordinator {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.tail = Promise.resolve();
    this.store = null;
    this.ready = null;
  }
  async locked(operation) {
    const previous = this.tail;
    let release;
    this.tail = new Promise(resolve => { release = resolve; });
    await previous;
    try { return await operation(); } finally { release(); }
  }
  async getStore() {
    if (!this.store) {
      this.store = new GitHubJsonStore({
        repository: this.env.GITHUB_JSON_REPOSITORY,
        branch: this.env.GITHUB_JSON_BRANCH || "main",
        token: this.env.GITHUB_JSON_TOKEN
      });
    }
    if (!this.ready) this.ready = this.store.verifyPrivateRepository().catch(error => { this.ready = null; throw error; });
    await this.ready;
    return this.store;
  }
  async fetch(request) {
    return this.locked(async () => {
      const url = new URL(request.url);
      const playerId = Number(request.headers.get("x-mshin-player-id"));
      if (!Number.isSafeInteger(playerId) || playerId < 1) return jsonResponse(401, { error: "unauthorized" });
      let storage;
      try { storage = await this.getStore(); }
      catch (error) { return jsonResponse(503, { error: error.message || "json_storage_unavailable" }); }

      const readProfile = async id => {
        const profile = await storage.readJson("players/" + id + ".json");
        if (profile === null) return profileDefault(id);
        if (profile.user_id !== id || hasEmail(profile)) throw new Error("stored_profile_invalid");
        return profile;
      };
      const writeProfile = async (id, profile) => storage.writeMany([{ path: "players/" + id + ".json", value: profile }]);

      if (request.method === "GET" && url.pathname === "/healthz") {
        return jsonResponse(200, { ok: true, service: "mshin-cloudflare-json-api", storage: "github-private-json" });
      }

      if (url.pathname === "/v1/rewards/claim" && request.method === "POST") {
        try {
          const current = await readProfile(playerId);
          const now = new Date();
          const todayUtc = now.toISOString().slice(0, 10);
          const rewardLedgerPath = "rewards/claims.json";
          const rewardLedger = await storage.readJson(rewardLedgerPath) || { schema_version: 1, players: {} };
          rewardLedger.players ||= {};
          const ledgerEntry = rewardLedger.players[String(playerId)] || {};
          const isNewAccount = !current.market_account || typeof current.market_account !== "object";
          const account = isNewAccount
            ? { simoleons: 0, sim_cash: 0, rewards: {} }
            : structuredClone(current.market_account);
          account.simoleons = Number.isSafeInteger(account.simoleons) && account.simoleons >= 0 ? account.simoleons : 0;
          account.sim_cash = Number.isSafeInteger(account.sim_cash) && account.sim_cash >= 0
            ? account.sim_cash
            : Math.max(0, Number(current.game_state?.economy?.sim_cash) || 0);
          account.rewards = account.rewards && typeof account.rewards === "object" ? account.rewards : {};
          const welcomeGranted = !ledgerEntry.welcome_claimed_at && !account.rewards.welcome_claimed_at && isNewAccount;
          const dailyGranted = (ledgerEntry.daily_last_claim_utc || account.rewards.daily_last_claim_utc) !== todayUtc;
          const welcome = welcomeGranted ? { simoleons: 5000, sim_cash: 10 } : { simoleons: 0, sim_cash: 0 };
          const daily = dailyGranted ? { simoleons: 100, sim_cash: 0 } : { simoleons: 0, sim_cash: 0 };
          account.simoleons += welcome.simoleons + daily.simoleons;
          account.sim_cash += welcome.sim_cash + daily.sim_cash;
          if (welcomeGranted) account.rewards.welcome_claimed_at = now.toISOString();
          if (dailyGranted) account.rewards.daily_last_claim_utc = todayUtc;
          ledgerEntry.welcome_claimed_at ||= account.rewards.welcome_claimed_at || null;
          if (dailyGranted) ledgerEntry.daily_last_claim_utc = todayUtc;
          rewardLedger.players[String(playerId)] = ledgerEntry;
          const gameState = current.game_state && typeof current.game_state === "object"
            ? structuredClone(current.game_state)
            : { economy: {}, storage: { capacity: 30, items: {} } };
          gameState.economy ??= {};
          gameState.economy.simoleons = account.simoleons;
          gameState.economy.sim_cash = account.sim_cash;
          const next = {
            schema_version: 1, user_id: playerId, revision: current.revision + 1,
            created_at: current.created_at || now.toISOString(), updated_at: now.toISOString(),
            market_account: account, game_state: gameState
          };
          if (welcomeGranted || dailyGranted || isNewAccount) {
            await storage.writeMany([
              { path: "players/" + playerId + ".json", value: next },
              { path: rewardLedgerPath, value: rewardLedger }
            ]);
          }
          return jsonResponse(200, {
            ok: true, welcome: { granted: welcomeGranted, ...welcome },
            daily: { granted: dailyGranted, ...daily },
            balances: { simoleons: account.simoleons, sim_cash: account.sim_cash },
            revision: next.revision, game_state: gameState, claimed_day_utc: todayUtc
          });
        } catch {
          return jsonResponse(500, { error: "reward_claim_failed" });
        }
      }

      if (url.pathname === "/v1/profile" && (request.method === "GET" || request.method === "PUT")) {
        if (request.method === "GET") {
          try {
            const profile = await readProfile(playerId);
            return jsonResponse(200, profile, { etag: '"' + profile.revision + '"' });
          } catch { return jsonResponse(500, { error: "profile_read_failed" }); }
        }
        try {
          const body = await readBody(request);
          if (!Number.isSafeInteger(body.expected_revision) || body.expected_revision < 0) return jsonResponse(400, { error: "expected_revision_required" });
          if (!body.game_state || typeof body.game_state !== "object" || Array.isArray(body.game_state)) return jsonResponse(400, { error: "game_state_must_be_object" });
          if (hasEmail(body.game_state)) return jsonResponse(400, { error: "email_fields_are_forbidden" });
          const current = await readProfile(playerId);
          if (body.expected_revision !== current.revision) return jsonResponse(409, { error: "revision_conflict", revision: current.revision });
          const now = new Date().toISOString();
          const gameState = structuredClone(body.game_state);
          let marketAccount = current.market_account;
          if (marketAccount && typeof marketAccount === "object") {
            gameState.economy ??= {};
            gameState.economy.simoleons = marketAccount.simoleons;
            marketAccount.sim_cash = Number.isSafeInteger(marketAccount.sim_cash) && marketAccount.sim_cash >= 0
              ? marketAccount.sim_cash : Math.max(0, Number(gameState.economy.sim_cash) || 0);
            gameState.economy.sim_cash = marketAccount.sim_cash;
          } else {
            const initial = Number(gameState.economy?.simoleons);
            const initialCash = Number(gameState.economy?.sim_cash);
            marketAccount = {
              simoleons: Number.isSafeInteger(initial) && initial >= 0 ? initial : 0,
              sim_cash: Number.isSafeInteger(initialCash) && initialCash >= 0 ? initialCash : 0,
              rewards: {}
            };
          }
          const next = {
            schema_version: 1, user_id: playerId, revision: current.revision + 1,
            created_at: current.created_at || now, updated_at: now,
            market_account: marketAccount, game_state: gameState
          };
          await writeProfile(playerId, next);
          return jsonResponse(200, next, { etag: '"' + next.revision + '"' });
        } catch (error) {
          return jsonResponse(error.status || 500, { error: error.status ? error.message : "profile_write_failed" });
        }
      }

      if (url.pathname === "/v1/market" || url.pathname.startsWith("/v1/market/")) {
        let status = 200;
        let payload = {};
        const responseShim = {
          writeHead(code, headers = {}) { status = code; this.headers = headers; },
          end(body) { payload = body ? JSON.parse(body) : {}; }
        };
        const requestShim = { method: request.method };
        await handleMarketRequest({
          request: requestShim,
          response: responseShim,
          url,
          session: { playerId },
          storage,
          readProfile,
          writeProfile,
          withPlayerLock: async (_id, operation) => operation(),
          readJsonBody: () => readBody(request),
          send: (res, code, body) => { res.writeHead(code); res.end(JSON.stringify(body)); }
        });
        return jsonResponse(status, payload);
      }
      return jsonResponse(404, { error: "not_found" });
    });
  }
}
