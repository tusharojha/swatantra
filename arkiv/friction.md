# Friction report — building Swatantra on Arkiv

SDK `@arkiv-network/sdk` **0.8.1**. Network: Tiramisu `7738577`.  
HTTP `https://rpc.tiramisu.db-chain.testnet.arkiv.network`  
WS `wss://rpc.tiramisu.db-chain.testnet.arkiv.network`

Each note: expected → actual → versions → steps to reproduce → what would fix it.

## 1. npm 0.8.x versions (Docs / SDK)

**Expected:** `npm i @arkiv-network/sdk@0.8.4` as a typical patch, or at least a documented latest 0.8.  
**Actual:** 0.8.4 does not exist. Published 0.8 line is `0.8.0` and `0.8.1` (plus some `0.8.0-advanced.*` and `-dev.*` tags). Installing a guessed patch fails with `ETARGET`.  
**Versions:** npm registry, 18 Oct 2026.  
**Repro:** `npm view @arkiv-network/sdk versions --json` and `npm i @arkiv-network/sdk@0.8.4`.  
**Fix:** Pin the current 0.8.x in the Tiramisu docs table, or publish the patch people will guess.

## 2. Attribute types are part of the query (SDK / Querying data)

**Expected:** `created_at_ms > 0` just works.  
**Actual:** A predicate carries a type tag. `eq("type", "story")` may not match `str("story")` depending on how the value was stored. Docs are clear once you find them; the failure mode is an empty page, not a type error.  
**Versions:** SDK 0.8.1.  
**Repro:** Write `type: str("story")`, query `eq("type", i32(0))` or a bare mismatched constructor; `fetch()` returns `[]`.  
**Fix:** Optional query warning when zero rows and the attribute exists under another type (explorer hint).

## 3. No server-side orderBy (SDK / Query)

**Expected (us, coming from SQL):** `orderBy created_at_ms`.  
**Actual:** Newest-first by insertion, then we sort in JS/Dart. `limit(100)` is "100 newest matches", not "100 latest by attribute". Documented. We stored `created_at_ms` as `u64` and sort client-side. Fine for a feed; would hurt a large archive.  
**Repro:** `select().where(eq("app", str("swatantra")), eq("type", str("story"))).limit(10).fetch()` then inspect attribute order vs `created_at_ms`.  
**Fix:** Keep as is, or add optional order on one numeric attribute.

## 4. Lifetime Extension is a set, not an add (SDK / Mutating data)

**Expected:** `extendEntity(fromDays(30))` adds 30 days.  
**Actual:** It sets a new expiry counted from **now**. Documented; easy to get wrong in product copy. We labelled the button "Keep this story alive (180 days from today)" and used the words Entity Expiration / Lifetime Extension.  
**Repro:** Create with `fromDays(180)`, immediately `extendEntity({ expires: fromDays(30) })` — should revert (`ExpiryNotExtended`) because 30 < remaining 180.  
**Fix:** A sentence in the Hub create dialog: "Extension replaces the remaining life if and only if the new instant is later."

## 5. Faucet is a Hub UI with a cooldown (Hub / Faucet)

**Expected:** A scriptable faucet for seed wallets (`curl` an address, get GLM).  
**Actual:** https://hub.arkiv.network/faucet is a Next.js page: wallet connect, one claim per wallet per cooldown. No public JSON faucet documented. Funding three journalist burners plus a seeder means four captcha/wallet sessions.  
**Versions:** Hub, 18 Oct 2026.  
**Repro:** Open the faucet URL; there is no `POST /api/faucet {address}` in the public docs.  
**Fix:** A testnet faucet that accepts an address (rate-limited) so seed scripts can run in CI.

## 6. Public RPC is rate-limited (RPC / Access keys)

**Expected:** A hackathon demo on GitHub Pages can query freely.  
**Actual:** Docs say the public RPC is heavily rate limited; access keys from the Hub raise the limit but must not be shipped in a public JS bundle. Browser apps on Pages therefore share the public quota with everyone.  
**Repro:** Burst `arkiv_query` from a static site.  
**Fix:** A Pages-friendly public quota for Tiramisu during the judging window, or a headerless demo key locked to `*.github.io`.

## 7. watchEntityEvents: HTTP polls, WS is the real socket (SDK / Live events)

**Expected:** `watchEntityEvents` is always live.  
**Actual:** AGENTS.md is right: a real socket only with WebSocket transport and **no** `fromBlock`. Over `http()` it silently polls. The live-events page examples still show `http()`. Easy to ship polling by copying the first snippet.  
**Versions:** SDK 0.8.1, docs live-events page.  
**Repro:** `createPublicClient({ transport: http() }).watchEntityEvents(...)` vs `webSocket()`.  
**Fix:** Put the WS example first on the live-events page.

## 8. Flutter has no first-party Arkiv SDK (SDK)

**Expected:** We could call `createWalletClient` from Dart.  
**Actual:** Official surface is TS 0.8.x (or raw `execute` ABI at `0x4400…0044`). We bundled the TS SDK with esbuild into `arkiv_bridge.js` and called it from Flutter web via JS interop. Reads also go through `arkiv_query` JSON-RPC from Dart so the Android APK feed works without a browser.  
**Repro:** Search pub.dev for arkiv — nothing official.  
**Fix:** A small Dart client generated from the JSON-RPC + execute ABI, or a documented JS-bridge recipe.

## 9. Payload cap vs media (protocol)

**Expected:** Store a photo next to the story.  
**Actual:** 128 KiB payload. Correct product decision: hashes + URL on Arkiv, bytes on device / Pages `/seed`. We explain this in the UI.  
**Repro:** Try `createEntity` with a 200 KiB JPEG payload.  
**Fix:** None needed; a one-line "media pattern" in best practices would save a round trip.

## 10. `$createdAt` vs our `created_at_ms` (Docs)

**Expected:** One timestamp story.  
**Actual:** JSON-RPC querying-data lists `$createdAt` as filterable `u64`. AGENTS.md / the TS querying guide say `$createdAt` has no index. We did not rely on it: we write `created_at_ms` as `u64` and range on that.  
**Repro:** Compare the two pages.  
**Fix:** Make the system-attribute table identical in TS and JSON-RPC docs.

## 11. Hub faucet can accept a claim it cannot pay (Hub / Faucet)

**Expected:** A 202 `accepted` means 10 test GLM will arrive.  
**Actual:** SIWE + Cap.js PoW can succeed and Hub still records `status: failed`, `phase: transferring`, `error: insufficient funds for gas * price + value: have 9.995 GLM want 10`. The dispenser (`0x815Ad950ae49102952C10ceBB18901E9e28AC712`) was ~0.0046 GLM short on 18 Oct 2026. `amountGlm` on the POST body is ignored — it always tries to send 10. Seed entities therefore wait on a human top-up of the faucet, not on our script.  
**Repro:** Authenticated `POST /api/faucet` then `GET /api/faucet?recipient=0x…` while the dispenser balance is below 10 GLM.  
**Fix:** Refill the Tiramisu faucet, or send `min(10, balance - gas)` and expose a scriptable address-in faucet.

## 12. Anon Aadhaar Groth16 artifacts are huge (PSE / proving)

**Expected:** `@anon-aadhaar/core` `prove()` + `verify()` in the Flutter web app, using the hosted test artifacts, in a few seconds.  
**Actual:** Official v2 artifacts at `https://anon-aadhaar-artifacts.s3.eu-central-1.amazonaws.com/v2.0.0/` are **aadhaar-verifier.wasm 10.0 MiB** and **circuit_final.zkey 583.7 MiB (612,082,146 bytes)**. `generateArgs` on the PSE dummy TEST QR + test certificate succeeds immediately. `prove()` then `verify(pcd, true)` **does work** (Node, local artifacts, 18 Oct 2026: nullifier `0x06ffb52d…361f`, `ageAbove18=true`, `stateRevealed=true`). The first browser prove has to download that zkey into memory; snarkjs `fullProve` holds the whole buffer. APK does not ship the zkey — it keeps the SHA-256 stub and labels it. We do **not** write QR bytes, names, or photos to Arkiv: only `nid`, `age_over_18`, `state_revealed`, `proof_hash`, `groth16`, `test_mode`.  
**Versions:** `@anon-aadhaar/core` 2.4.3, artifacts v2.0.0, snarkjs 0.7.x.  
**Repro:** `NODE_OPTIONS=--max-old-space-size=8192 npx tsx src/aa-prove-cli.mjs` after downloading wasm/zkey/vkey to `/tmp/aa-artifacts`.  
**Fix:** A test-circuit zkey in the 10–50 MiB range, or chunked streaming that does not require 600 MiB RAM, so a phone browser can prove.

## 13. No first-party reverse-geocode (SDK / product)

**Expected:** A coarse “where was this captured” attribute without doxxing a reporter.  
**Actual:** Arkiv has no geo type. We round to 0.1° ourselves (`geo_cell`) and reverse to a bundled district centroid offline. Browser `navigator.geolocation` is the permission prompt on web; APK uses a labelled **self-declared** district picker so we did not add another Android plugin during the compileSdk 36 fight.  
**Repro:** Post → Use GPS (coarse) on web; Post → self-declared dropdown on APK.  
**Fix:** A documented `geohash` / `u64` cell convention in the querying guide would have saved the 0.1° bikeshed.

## What was smooth

- `createPublicClient` + `tiramisu` + `http()` with no URL uses the public RPC. First `eth_blockNumber` returned `0xb6e37` on 18 Oct 2026, chain id `0x7614d1` = 7738577.
- `jsonToPayload`, `ExpirationTime.fromDays`, typed `str` / `u64` / `bytes32` / `key` / `u256` constructors matched the docs.
- `predictEntityKeys({ owner, count: 2 })` + `executeBatch` for capture+story in one tx is exactly the "reference a sibling" story.
- `readonly` + `permissionlessExtension` maps cleanly onto "ground truth you cannot edit, community can keep alive".
- Explorer at https://tiramisu.explorer.arkiv.network accepts tx hashes from `createEntity`.
