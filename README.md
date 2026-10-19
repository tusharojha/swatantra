<p align="center">
  <img src="assets/logo.png" width="180" alt="Swatantra logo — rangoli mandala with a camera-aperture centre in saffron, magenta and teal"/>
</p>

# Swatantra

**Ground truth, unerasable.**

A mobile (and web) app for independent journalism in India. Ground reporters publish stories as Arkiv entities on **Arkiv Tiramisu** (chain `7738577`) so a platform takedown does not erase the record. Readers need no wallet. Journalists prove they are an Indian adult with **Anon Aadhaar** and keep a burner wallet in local storage — never on Arkiv. We store only the nullifier, never QR data, never a name.

Entered in **Best Indian Use Case** (also relevant to Censorship Resistance & Privacy) at [Arkiv: Global Tour Stop](https://github.com/Arkiv-Network/global-tour-stop-pre-devcon).

**Brand:** launcher icon, splash, favicon and in-app header all use [`assets/logo.png`](assets/logo.png). Newspaper UI on white paper `#FFFFFF`. Accents sampled from the rangoli: magenta `#DC2460` (kickers, links, tip), teal `#089C9C`, saffron `#F47C20`. Headlines: Playfair Display (bundled); body: Source Serif 4 16.5px/1.5 + Noto Serif Devanagari; UI labels: Inter. Phone-first with a desktop newspaper front page ≥1024px.

**Pre-existing work: None.** Built 18 October 2026.

## Why India

India issued about **200,000 social-media removal orders** via the Sahyog portal between March and July 2026 ([Indian Express via RSF, 8 Oct 2026](https://rsf.org/)). Journalists’ accounts and posts were blocked in September 2026 (RSF). Delhi police issued 200+ takedown orders before the 10 October 2026 protest, and a 24-hour mobile internet shutdown whose order was not published (NDTV, Indian Express, The Hindu). On 8 October 2026 MeitY told platforms to act on “manipulated or out-of-context” content.

Ground reporters lose the post **and** the ability to show that the footage was captured when they said it was. Swatantra gives them:

1. **Corroboration** — two or more independent desks in the same district ±30 minutes (`CORROBORATED · N independent witnesses`). Precise GPS never hits Arkiv; only `district` + a 0.1° `geo_cell`.
2. A public feed queried from Arkiv (not our servers).
3. A **protected link** `/s/<entityKey>` that resolves the entity from Arkiv.
4. An in-app capture hash chain, district-bound, stored as a readonly `capture` entity.
5. GLM tips on Arkiv Tiramisu, recorded as `tip` entities.

Seed bylines are fictional desks (hackathon rule: no real personal data on Arkiv). The mechanism is real: queryable entities, `$creator`, Entity Expiration, Lifetime Extension.

## Why Arkiv

Postgres, IPFS, a subgraph or “our API” all have an operator who can drop a row, hide a CID, or halt the endpoint. Arkiv is the Web3 database. Swatantra uses:

- **Entity annotations** — typed, queryable attributes (`app`, `type`, `district`, `geo_cell`, `created_at_ms`, `nid`, …). The feed is a public `arkiv_query`, not a backend.
- **`$creator` trust** — the byline is the immutable creator address. Nobody can forge who wrote the entity. Distinct journalist `nid`s (via `$creator` → journalist entity) are how corroboration counts witnesses.
- **Entity Expiration** — priced per type (180 days for stories / corroboration / takedowns; 365 days for journalists, captures, tips; 2 days for drafts).
- **Lifetime Extension** — `extendEntity` on **readonly** stories (and journalist / capture / takedown / corroboration) with `permissionlessExtension`, so a community can keep a dispatch alive without being able to edit it.

**Kept off Arkiv on purpose:** media bytes (size/cost, 128 KiB payload cap), private keys, Anon Aadhaar QR / Aadhaar data (not even hashed). Only hashes, URLs, copy, and a nullifier-derived id.

## Live demo

- **Web:** https://tusharojha.github.io/swatantra/  
  Reads need no wallet. The feed, article, corroboration stamp, journalist desks and tracker are live `arkiv_query` results on Arkiv Tiramisu.
- **Android APK:** GitHub Release tag [`apk`](https://github.com/tusharojha/swatantra/releases/tag/apk), also committed under [`release/`](release/) if Actions did not finish in time.
- **Protected link shape:** `https://tusharojha.github.io/swatantra/s/<entityKey>`
- **Corroborated Pune cluster (3 desks, same district ±30 min):**  
  https://tusharojha.github.io/swatantra/s/0x698bd7bb49fbf40011ae55248c7ee9b4b80a5a86be112598d2bfb3593020363c

## Network

| | |
|---|---|
| Arkiv Tiramisu | chain id `7738577` |
| RPC | `https://rpc.tiramisu.db-chain.testnet.arkiv.network` |
| WS | `wss://rpc.tiramisu.db-chain.testnet.arkiv.network` |
| Explorer | https://tiramisu.explorer.arkiv.network |
| Faucet | https://hub.arkiv.network/faucet |
| SDK | `@arkiv-network/sdk` **0.8.1** |

## Seeded on Arkiv Tiramisu

Seeder: [`0x873f5856a0967549D60442481DB5aef270044Bd7`](https://tiramisu.explorer.arkiv.network/address/0x873f5856a0967549D60442481DB5aef270044Bd7)  
Seeded 19 Oct 2026. Full keys: [`arkiv/seed-result.json`](arkiv/seed-result.json). Private keys stay in local `.env` — never in git, never in Arkiv.

| Type | Count | Representative entity |
|---|---|---|
| `story` | 10 | [Sinhagad Road underpass (Pune, corroborated)](https://tiramisu.explorer.arkiv.network/entity/0x698bd7bb49fbf40011ae55248c7ee9b4b80a5a86be112598d2bfb3593020363c) |
| `journalist` | 3 | [Desk MH-A](https://tiramisu.explorer.arkiv.network/entity/0xb35a591e135f54965bbd61ac741f52c1b4f1b6025974727edfebebe696826e74) |
| `capture` | 10 | [Pune still, third desk](https://tiramisu.explorer.arkiv.network/entity/0x6f69bd8252453d0b1bfa0987c4b103384610b85d0089b2635883ca881f126338) |
| `corroboration` | 1 | [Pune cluster, 3 witnesses](https://tiramisu.explorer.arkiv.network/entity/0xe301bedac49db1fcc74558904d418edac4e62c14c757377664552ab860c6dc24) |
| `tip` | 2 | [Reader tip](https://tiramisu.explorer.arkiv.network/entity/0x16495bc3f0f7e459d767a6f9670ac5a17969127de28040b96eddc2303bafcad8) |
| `takedown` | 2 | [Tracker notice](https://tiramisu.explorer.arkiv.network/entity/0x21521904eb97ca3be8be0fe40c0e3c5ee7e5f1db44d256833d45ab0398b4f521) |

### Wallet addresses and roles

| Role | Address |
|---|---|
| Seeder / tipper | [`0x873f5856a0967549D60442481DB5aef270044Bd7`](https://tiramisu.explorer.arkiv.network/address/0x873f5856a0967549D60442481DB5aef270044Bd7) |
| Journalist A (Maharashtra desk) | [`0x2E1733523b5704Cf431378618Cc5E74bB1248997`](https://tiramisu.explorer.arkiv.network/address/0x2E1733523b5704Cf431378618Cc5E74bB1248997) |
| Journalist B (Delhi desk) | [`0xf96c7F67F72301038Ec538E422e0d52e7Dd81cCF`](https://tiramisu.explorer.arkiv.network/address/0xf96c7F67F72301038Ec538E422e0d52e7Dd81cCF) |
| Journalist C (Northeast desk) | [`0x68F0Ee5526e28e9072A9Fa398d91A5a867001645`](https://tiramisu.explorer.arkiv.network/address/0x68F0Ee5526e28e9072A9Fa398d91A5a867001645) |
| Reader burner (unused in seed) | `0x376B04bB89b6486d7f30C7B9a2251500cfae9ffF` |

### Corroborated Pune cluster

Three independent captures, Pune district, cell `18.5,73.9`, ±30 minutes, three distinct `$creator` / `nid`s:

| Desk | Story | Explorer |
|---|---|---|
| B | Same underpass, from the shop-row — water at the lintel | [entity](https://tiramisu.explorer.arkiv.network/entity/0xe7d68005ac47e1d168758a3886377772a19615b5d489f74e7e5b2730480bcb8e) |
| A | Water through the gate at the underpass mouth | [entity](https://tiramisu.explorer.arkiv.network/entity/0x568ee1f0ff1f0d85b9fa115446e829d193311b1dd2f63137b0bb5c8bd3008272) |
| C | Sinhagad Road underpass still chest-deep after the rain | [entity](https://tiramisu.explorer.arkiv.network/entity/0x698bd7bb49fbf40011ae55248c7ee9b4b80a5a86be112598d2bfb3593020363c) |

## Anon Aadhaar

**Web:** `@anon-aadhaar/core` 2.4.3. The bundled identity (or a pasted Anon Aadhaar QR) goes through `generateArgs` → `prove()` → `verify()` using [hosted v2 artifacts](https://anon-aadhaar-artifacts.s3.eu-central-1.amazonaws.com/v2.0.0/) (`artifactUrls.v2`). Arkiv stores only `nid` (nullifier as bytes32), `age_over_18`, `state_revealed`, `proof_hash`, `groth16`. QR bytes are dropped.

**APK:** Groth16 is not shipped (zkey is ~612 MiB). The SHA-256 nullifier in `app/lib/arkiv/anon.dart` is the APK path; the web build runs the full proof. Same `nid` uniqueness check.

Use Anon Aadhaar [sample QR / docs](https://documentation.anon-aadhaar.pse.dev/docs/quick-setup), never a real Aadhaar. One nullifier = one journalist.

Node check (after downloading wasm/zkey/vkey to `/tmp/aa-artifacts`):

```bash
cd bridge && NODE_OPTIONS=--max-old-space-size=8192 npx tsx src/aa-prove-cli.mjs
```

## Reproduce Arkiv usage

From any machine, no wallet:

```bash
curl -sS https://rpc.tiramisu.db-chain.testnet.arkiv.network \
  -H 'content-type: application/json' \
  -d '{
    "jsonrpc":"2.0","id":1,
    "method":"arkiv_query",
    "params":[
      "app = str('\''swatantra'\'') AND type = str('\''story'\'')",
      {"limit":"0x64","select":{"key":true,"creator":true,"owner":true,"payload":true,"attributes":true,"expiresAt":true}}
    ]
  }'
```

Exact SDK queries: [`arkiv/schema.md`](arkiv/schema.md). Code: `bridge/src/index.ts` (`queryStories`, `createEntity`, `executeBatch`, `extendEntity`, `watchEntityEvents` over WebSocket).

Other queries:

```
app = str('swatantra') AND type = str('journalist') AND nid = bytes32(0x…)
app = str('swatantra') AND type = str('tip') AND story_key = key(0x…)
app = str('swatantra') AND type = str('capture') AND chain_root = bytes32(0x…)
app = str('swatantra') AND type = str('takedown')
app = str('swatantra') AND type = str('corroboration')
```

Then sort `created_at_ms` **client-side**. There is no server `orderBy`.

## Setup / run

Need Flutter 3.24+ (CI uses stable), Node 22, an Arkiv Tiramisu-funded key for writes.

```bash
# JS bridge (official SDK)
cd bridge && npm install && npm run build && cd ..

# Web (judges)
cd app && flutter pub get && flutter run -d chrome
# or: flutter build web --release --base-href /swatantra/

# Android
flutter build apk --release
```

Re-seed (keys never committed):

```bash
cd bridge
cp ../.env.example ../.env   # fill funded keys
node src/gen-wallets.mjs     # or reuse keys; fund at the faucet
npx tsx src/seed.ts
```

## Capture chain

In-app stills (and sampled video frames at 1 fps when available). The chain is **district-bound**:

```
h_0     = 32 zero bytes
place   = sha256( utf8(district) || 0x00 || utf8(geo_cell) )
h_i     = sha256( h_{i-1} || sha256(frame_i) || uint64be(timestamp_ms) || place )
```

`geo_cell` is lat,lng rounded to **0.1°**. Precise GPS is never stored. Only `chain_root`, `district`, `geo_cell`, `capture_ts_ms`, counts go on Arkiv.

```bash
node scripts/verify-capture.mjs app/web/seed/s4.jpg 1700000000000 Pune 18.5,73.9
```

## Corroboration

Independent journalists who capture in the **same district** within **±30 minutes** count as witnesses. Distinct Anon Aadhaar nullifiers (`nid` via `$creator` → journalist entity). **N ≥ 2** shows `CORROBORATED · N independent witnesses · {district} district · {time}` on the feed and article. Also written as a `corroboration` entity for the Pune cluster.

## Local node

Optional: `./scripts/local-node.sh` then `ARKIV_NETWORK=local npx tsx src/seed.ts`. The live app and CI stay on **Arkiv Tiramisu**.

## Docs

- [`arkiv/schema.md`](arkiv/schema.md) — entity types, Entity Expiration, queries
- [`arkiv/friction.md`](arkiv/friction.md) — expected vs actual
- [`docs/devfolio-answers.md`](docs/devfolio-answers.md) — Devfolio form draft
- MIT [`LICENSE`](LICENSE)
