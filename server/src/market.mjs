import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import path from "node:path";
import { randomUUID } from "node:crypto";

const MAX_QUANTITY = 500;
const MAX_TOTAL = 2_000_000;
const ITEM_CATALOG = Object.freeze({
  dozer_wheel:{value:800,level:10}, dozer_blade:{value:800,level:10}, dozer_exhaust:{value:800,level:10},
  metal:{value:10,level:1}, wood:{value:20,level:2}, plastic:{value:25,level:5},
  seeds:{value:30,level:7}, minerals:{value:40,level:11}, chemicals:{value:60,level:13},
  textiles:{value:90,level:15}, sugar_spices:{value:110,level:17}, glass:{value:120,level:19},
  animal_feed:{value:140,level:23}, electrical:{value:160,level:29},
  coconut:{value:80,level:25}, snowberry:{value:95,level:30}, cactus_fruit:{value:110,level:35},
  herbs:{value:125,level:40}, olives:{value:140,level:45},
  nails:{value:80,level:1}, planks:{value:120,level:3}, bricks:{value:190,level:13},
  cement:{value:440,level:14}, glue:{value:440,level:15}, paint:{value:320,level:16},
  hammer:{value:90,level:4}, measuring_tape:{value:110,level:6}, shovel:{value:150,level:9},
  cooking_utensils:{value:250,level:17}, ladder:{value:420,level:20}, drill:{value:590,level:30},
  chair:{value:300,level:10}, home_textiles:{value:610,level:25}, cupboard:{value:900,level:26},
  couch:{value:1810,level:33}, table:{value:500,level:16}, vegetables:{value:160,level:8},
  flour_bag:{value:570,level:17}, cream:{value:440,level:23}, corn:{value:280,level:24},
  cheese:{value:660,level:26}, beef:{value:860,level:27}, fruit_berries:{value:730,level:18},
  bread_roll:{value:1840,level:24}, bbq_grill:{value:530,level:29}, microwave_oven:{value:480,level:42},
  pizza:{value:2560,level:28}, cheese_fries:{value:1050,level:33}, ice_cream_sandwich:{value:2560,level:25},
  burger:{value:3620,level:31}, lemonade_bottle:{value:1690,level:37}, popcorn:{value:1250,level:43},
  grass:{value:310,level:14}, tree_sapling:{value:420,level:16}, lawn_mower:{value:840,level:30},
  garden_furniture:{value:820,level:21}, fire_pit:{value:1740,level:28}, garden_gnome:{value:1600,level:34},
  donuts:{value:950,level:18}, green_smoothie:{value:1150,level:20}, cherry_cheesecake:{value:2240,level:27},
  frozen_yogurt:{value:1750,level:28}, coffee:{value:750,level:33}, cap:{value:600,level:19},
  shoes:{value:980,level:21}, watch:{value:580,level:22}, business_suit:{value:1170,level:32},
  refrigerator:{value:1060,level:35}, lighting_system:{value:890,level:36}, tv:{value:1280,level:38},
  ping_pong_table:{value:1245,level:55}, block_letters:{value:360,level:40}, game_console:{value:2240,level:58},
  forged_iron:{value:560,level:45}, carved_wood:{value:2800,level:54}, wool_shirt:{value:1700,level:50},
  picnic_basket:{value:6000,level:59}, apple_jam:{value:3700,level:73}, tiramisu:{value:1250,level:55},
  churros:{value:1750,level:63}, profiterole:{value:6550,level:71}, mochi:{value:3950,level:79},
  pavlova:{value:3470,level:87}, backpack:{value:430,level:34}, tennis_racket:{value:780,level:35},
  sports_drink:{value:270,level:39}, protein_bar:{value:1045,level:35}, cut_stone:{value:2300,level:59},
  stained_glass:{value:2300,level:76}
});

function gameState(profile) {
  if (!profile.game_state || typeof profile.game_state !== "object" || Array.isArray(profile.game_state)) {
    throw Object.assign(new Error("player_profile_not_initialized"), { status: 409 });
  }
  const state = profile.game_state;
  state.economy ??= {};
  state.storage ??= {};
  state.storage.items ??= {};
  state.storage.capacity = Math.max(0, Number(state.storage.capacity) || 0);
  if (profile.market_account && typeof profile.market_account === "object") {
    state.economy.simoleons = Number(profile.market_account.simoleons);
    state.storage = structuredClone(profile.market_account.storage);
  } else {
    profile.market_account = {
      simoleons: Number.isSafeInteger(Number(state.economy.simoleons)) && Number(state.economy.simoleons) >= 0 ? Number(state.economy.simoleons) : 0,
      storage: structuredClone(state.storage)
    };
  }
  return state;
}

function syncMarketAccount(profile, state) {
  profile.market_account = {
    simoleons: balance(state),
    storage: structuredClone(state.storage)
  };
}

function balance(state) {
  const value = Number(state.economy.simoleons);
  return Number.isSafeInteger(value) && value >= 0 ? value : 0;
}

function usedStorage(state) {
  return Object.values(state.storage.items).reduce((sum, value) => sum + Math.max(0, Number(value) || 0), 0);
}

function appendLedger(state, type, currency, amount, before, after, metadata) {
  state.economy_ledger ??= { transaction_sequence: 0, transaction_ledger: [] };
  const ledger = state.economy_ledger;
  ledger.transaction_sequence = Math.max(0, Number(ledger.transaction_sequence) || 0) + 1;
  ledger.transaction_ledger ??= [];
  ledger.transaction_ledger.push({
    id: "econ-" + ledger.transaction_sequence,
    timestamp_unix: Math.floor(Date.now() / 1000),
    type, currency, amount, balance_before: before, balance_after: after,
    inventory_before: {}, inventory_after: {}, metadata
  });
  if (ledger.transaction_ledger.length > 300) ledger.transaction_ledger.splice(0, ledger.transaction_ledger.length - 300);
}

async function readListings(file) {
  try {
    const parsed = JSON.parse(await readFile(file, "utf8"));
    return Array.isArray(parsed.listings) ? parsed : { schema_version: 1, listings: [] };
  } catch (error) {
    if (error.code === "ENOENT") return { schema_version: 1, listings: [] };
    throw error;
  }
}

async function writeAtomic(file, value) {
  await mkdir(path.dirname(file), { recursive: true });
  const temporary = file + "." + randomUUID() + ".tmp";
  await writeFile(temporary, JSON.stringify(value), { encoding: "utf8", flag: "wx", mode: 0o600 });
  await rename(temporary, file);
}

async function commitMutation({ profiles, marketFile, market, previousMarket, writeProfile }) {
  const originals = profiles.map(entry => ({ playerId: entry.playerId, profile: structuredClone(entry.original) }));
  try {
    for (const entry of profiles) await writeProfile(entry.playerId, entry.next);
    await writeAtomic(marketFile, market);
  } catch (error) {
    for (const entry of originals) {
      try { await writeProfile(entry.playerId, entry.profile); } catch {}
    }
    try { await writeAtomic(marketFile, previousMarket); } catch {}
    throw error;
  }
}

export async function handleMarketRequest({
  request, response, url, session, dataDir, readProfile, writeProfile, withPlayerLock, readJsonBody, send
}) {
  const listingsFile = path.join(dataDir, "market", "listings.json");
  const route = url.pathname;
  const method = request.method;

  if (method === "GET" && route === "/v1/market") {
    try {
      const data = await readListings(listingsFile);
      send(response, 200, { listings: data.listings.filter(x => x.status === "active" && x.seller_id !== session.playerId).map(x => ({
        listing_id: x.listing_id, seller_id: x.seller_id, item_id: x.item_id,
        quantity: x.quantity, unit_price: x.unit_price, total_price: x.quantity * x.unit_price,
        created_at: x.created_at
      })) });
    } catch {
      send(response, 500, { error: "market_read_failed" });
    }
    return true;
  }

  if (method === "GET" && route === "/v1/market/mine") {
    try {
      const data = await readListings(listingsFile);
      send(response, 200, { listings: data.listings.filter(x => x.seller_id === session.playerId) });
    } catch {
      send(response, 500, { error: "market_read_failed" });
    }
    return true;
  }

  if (method === "POST" && route === "/v1/market/list") {
    try {
      const body = await readJsonBody(request);
      const itemId = String(body.item_id || "");
      const quantity = Number(body.quantity);
      const unitPrice = Number(body.unit_price);
      const item = ITEM_CATALOG[itemId];
      if (!item || !Number.isSafeInteger(quantity) || quantity < 1 || quantity > MAX_QUANTITY ||
          !Number.isSafeInteger(unitPrice) || unitPrice < 1 || unitPrice > item.value * 10 ||
          quantity * unitPrice > MAX_TOTAL) {
        send(response, 400, { error: "invalid_listing" });
        return true;
      }
      const result = await withPlayerLock(0, async () => {
        const profile = await readProfile(session.playerId);
        const originalProfile = structuredClone(profile);
        const state = gameState(profile);
        if (Number(state.game?.level || 1) < item.level) return { status: 409, error: "item_locked" };
        const items = state.storage.items;
        if (!Number.isSafeInteger(Number(items[itemId])) || Number(items[itemId]) < quantity) return { status: 409, error: "insufficient_inventory" };
        const inventoryBefore = { ...items };
        const cost = quantity * unitPrice;
        items[itemId] -= quantity;
        if (items[itemId] === 0) delete items[itemId];
        const market = await readListings(listingsFile);
        const originalMarket = structuredClone(market);
        const activeCount = market.listings.filter(x => x.seller_id === session.playerId && x.status === "active").length;
        if (activeCount >= 20) return { status: 409, error: "seller_listing_limit" };
        const listing = {
          listing_id: randomUUID(), seller_id: session.playerId, item_id: itemId,
          quantity, unit_price: unitPrice, status: "active",
          created_at: new Date().toISOString()
        };
        market.listings.push(listing);
        appendLedger(state, "player_market_listing_reserved", "items", quantity, balance(state), balance(state), {
          listing_id: listing.listing_id, item_id: itemId, quantity, unit_price: unitPrice,
          inventory_before: inventoryBefore, inventory_after: { ...items }
        });
        syncMarketAccount(profile, state);
        syncMarketAccount(profile, state);
        profile.revision += 1;
        profile.updated_at = new Date().toISOString();
        await commitMutation({
          profiles: [{ playerId: session.playerId, original: originalProfile, next: profile }],
          marketFile: listingsFile, market, previousMarket: originalMarket, writeProfile
        });
        return { status: 201, listing: { ...listing, total_price: cost }, revision: profile.revision };
      });
      send(response, result.status, result);
    } catch (error) {
      send(response, error.status || 500, { error: error.status ? error.message : "listing_create_failed" });
    }
    return true;
  }

  const buyMatch = route.match(/^\/v1\/market\/([^/]+)\/buy$/);
  if (method === "POST" && buyMatch) {
    try {
      const listingId = decodeURIComponent(buyMatch[1]);
      const result = await withPlayerLock(0, async () => {
        const market = await readListings(listingsFile);
        const listing = market.listings.find(x => x.listing_id === listingId && x.status === "active");
        if (!listing) return { status: 404, error: "listing_not_available" };
        if (listing.seller_id === session.playerId) return { status: 409, error: "cannot_buy_own_listing" };
        const seller = await readProfile(listing.seller_id);
        const buyer = await readProfile(session.playerId);
        const originalSeller = structuredClone(seller);
        const originalBuyer = structuredClone(buyer);
        const originalMarket = structuredClone(market);
        const sellerState = gameState(seller);
        const buyerState = gameState(buyer);
        const item = ITEM_CATALOG[listing.item_id];
        if (!item || Number(buyerState.game?.level || 1) < item.level) return { status: 409, error: "item_locked" };
        const total = listing.quantity * listing.unit_price;
        const buyerBalance = balance(buyerState);
        const sellerBalance = balance(sellerState);
        if (buyerBalance < total) return { status: 409, error: "insufficient_simoleons" };
        if (!Number.isSafeInteger(sellerBalance + total)) return { status: 409, error: "seller_balance_limit" };
        if (usedStorage(buyerState) + listing.quantity > buyerState.storage.capacity) return { status: 409, error: "warehouse_capacity" };
        const sellerBefore = sellerBalance;
        const buyerBefore = buyerBalance;
        buyerState.economy.simoleons = buyerBalance - total;
        sellerState.economy.simoleons = sellerBalance + total;
        buyerState.storage.items[listing.item_id] = Number(buyerState.storage.items[listing.item_id] || 0) + listing.quantity;
        appendLedger(buyerState, "player_market_purchase", "simoleons", total, buyerBefore, buyerState.economy.simoleons, {
          listing_id: listingId, seller_id: listing.seller_id, item_id: listing.item_id, quantity: listing.quantity
        });
        appendLedger(sellerState, "player_market_sale", "simoleons", total, sellerBefore, sellerState.economy.simoleons, {
          listing_id: listingId, buyer_id: session.playerId, item_id: listing.item_id, quantity: listing.quantity
        });
        listing.status = "sold";
        listing.buyer_id = session.playerId;
        listing.sold_at = new Date().toISOString();
        syncMarketAccount(seller, sellerState);
        syncMarketAccount(buyer, buyerState);
        seller.revision += 1;
        buyer.revision += 1;
        const now = new Date().toISOString();
        seller.updated_at = now; buyer.updated_at = now;
        await commitMutation({
          profiles: [
            { playerId: listing.seller_id, original: originalSeller, next: seller },
            { playerId: session.playerId, original: originalBuyer, next: buyer }
          ],
          marketFile: listingsFile, market, previousMarket: originalMarket, writeProfile
        });
        return { status: 200, listing_id: listingId, item_id: listing.item_id, quantity: listing.quantity, total_paid: total, buyer_balance: buyerState.economy.simoleons, seller_balance: sellerState.economy.simoleons };
      });
      send(response, result.status, result);
    } catch (error) {
      send(response, error.status || 500, { error: error.status ? error.message : "purchase_failed" });
    }
    return true;
  }

  const cancelMatch = route.match(/^\/v1\/market\/([^/]+)\/cancel$/);
  if (method === "POST" && cancelMatch) {
    try {
      const listingId = decodeURIComponent(cancelMatch[1]);
      const result = await withPlayerLock(0, async () => {
        const market = await readListings(listingsFile);
        const listing = market.listings.find(x => x.listing_id === listingId && x.status === "active");
        if (!listing) return { status: 404, error: "listing_not_available" };
        if (listing.seller_id !== session.playerId) return { status: 403, error: "not_listing_owner" };
        const profile = await readProfile(session.playerId);
        const originalProfile = structuredClone(profile);
        const originalMarket = structuredClone(market);
        const state = gameState(profile);
        if (usedStorage(state) + listing.quantity > state.storage.capacity) return { status: 409, error: "warehouse_capacity" };
        state.storage.items[listing.item_id] = Number(state.storage.items[listing.item_id] || 0) + listing.quantity;
        appendLedger(state, "player_market_listing_cancelled", "items", listing.quantity, balance(state), balance(state), {
          listing_id: listingId, item_id: listing.item_id, quantity: listing.quantity
        });
        listing.status = "cancelled";
        listing.cancelled_at = new Date().toISOString();
        profile.revision += 1;
        profile.updated_at = new Date().toISOString();
        await commitMutation({
          profiles: [{ playerId: session.playerId, original: originalProfile, next: profile }],
          marketFile: listingsFile, market, previousMarket: originalMarket, writeProfile
        });
        return { status: 200, listing_id: listingId, returned_item_id: listing.item_id, returned_quantity: listing.quantity, revision: profile.revision };
      });
      send(response, result.status, result);
    } catch (error) {
      send(response, error.status || 500, { error: error.status ? error.message : "listing_cancel_failed" });
    }
    return true;
  }

  send(response, 404, { error: "not_found" });
  return true;
}
