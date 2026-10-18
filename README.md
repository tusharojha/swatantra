<p align="center">
  <img src="assets/logo.png" width="180" alt="Swatantra logo — rangoli mandala with a camera-aperture centre in saffron, magenta and teal"/>
</p>

# Swatantra

**Ground truth, unerasable.**

A mobile (and web) app for independent journalism in India. Ground reporters publish stories as Arkiv entities on the Tiramisu testnet so a platform takedown does not erase the record. Readers need no wallet. Journalists prove “Indian resident, 18+” with **Anon Aadhaar in TEST MODE** and keep a burner wallet in local storage — never on Arkiv.

Entered in **Best Indian Use Case** (also relevant to Censorship Resistance & Privacy) at [Arkiv: Global Tour Stop](https://github.com/Arkiv-Network/global-tour-stop-pre-devcon).

**Brand:** launcher icon, splash, favicon and in-app header all use [`assets/logo.png`](assets/logo.png). Accents sampled from the rangoli: magenta `#DC2460`, teal `#089C9C`, saffron `#F47C20`, paper `#FFFBFA`.

**Pre-existing work: None.** Built 18 October 2026.

## Why India

India issued about **200,000 social-media removal orders** via the Sahyog portal between March and July 2026 ([Indian Express via RSF, 8 Oct 2026](https://rsf.org/)). Journalists’ accounts and posts were blocked in September 2026 (RSF). Delhi police issued 200+ takedown orders before the 10 October 2026 protest, and a 24-hour mobile internet shutdown whose order was not published (NDTV, Indian Express, The Hindu). On 8 October 2026 MeitY told platforms to act on “manipulated or out-of-context” content.

Ground reporters lose the post **and** the ability to show that the footage was captured when they said it was. Swatantra gives them:

1. A public feed queried from Arkiv (not our servers).
2. A **protected link** `/s/<entityKey>` that resolves the entity from Arkiv.
3. An in-app capture hash chain so a still or sampled video can be checked against a readonly `capture` entity.
4. Testnet tips in GLM, recorded as `tip` entities.

All people, bylines and dispatches in the seed are **synthetic / fictional**.

## Why Arkiv

Postgres, IPFS, a subgraph or “our API” all have an operator who can drop a row, hide a CID, or halt the endpoint. Arkiv is the Web3 database: queryable attributes, `$creator` that nobody can forge, Entity Expiration per type, Lifetime Extension so a story can be kept alive without being edited (`readonly` + `permissionlessExtension`).

**Kept off Arkiv on purpose:** media bytes (size/cost, 128 KiB payload cap), private keys, Anon Aadhaar QR / Aadhaar data (not even hashed). Only hashes, URLs, synthetic copy, and a nullifier-derived id.

## Live demo

- **Web:** https://tusharojha.github.io/swatantra/  
  If that 404s: **Settings → Pages → Source: GitHub Actions**, then re-run **Build web + APK**. The workflow also uploads a `swatantra-web` artifact.
- **Android APK:** GitHub Release tag [`apk`](https://github.com/tusharojha/swatantra/releases/tag/apk), also committed under [`release/`](release/) if Actions did not finish in time.
- **Protected link shape:** `https://tusharojha.github.io/swatantra/s/<entityKey>`

## Network

| | |
|---|---|
| Tiramisu | chain id `7738577` |
| RPC | `https://rpc.tiramisu.db-chain.testnet.arkiv.network` |
| WS | `wss://rpc.tiramisu.db-chain.testnet.arkiv.network` |
| Explorer | https://tiramisu.explorer.arkiv.network |
| Faucet | https://hub.arkiv.network/faucet |
| SDK | `@arkiv-network/sdk` **0.8.1** |

## Wallet addresses and roles

| Role | Address |
|---|---|
| Seeder / testnet tipper | `0x873f5856a0967549D60442481DB5aef270044Bd7` |
| Journalist A (Maharashtra, synthetic) | `0x2E1733523b5704Cf431378618Cc5E74bB1248997` |
| Journalist B (Delhi, synthetic) | `0xf96c7F67F72301038Ec538E422e0d52e7Dd81cCF` |
| Journalist C (Northeast, synthetic) | `0x68F0Ee5526e28e9072A9Fa398d91A5a867001645` |
| Reader burner (unused in seed) | `0x376B04bB89b6486d7f30C7B9a2251500cfae9ffF` |

**Before the deadline:** fund the first four at [Hub faucet](https://hub.arkiv.network/faucet) (10 GLM / 1 hour cooldown, Cap PoW captcha). Then `cd bridge && npx tsx src/seed.ts`. Entity keys land in [`arkiv/seed-result.json`](arkiv/seed-result.json). Private keys stay in local `.env` — never in git, never in Arkiv.

## Anon Aadhaar — TEST MODE

Full Groth16 proving does not run inside Flutter in this build. A **minimal test-mode verifier** in `bridge/src/anon.ts` derives `nid = SHA-256("swatantra-aa-v1" \|\| testQR)` and stores **only** that bytes32 on a `journalist` entity. UI and this README say TEST MODE. Use Anon Aadhaar [test QR / test data](https://documentation.anon-aadhaar.pse.dev/docs/quick-setup), never a real Aadhaar. One nullifier = one journalist (`nid` uniqueness check before create).

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
```

Then sort `created_at_ms` **client-side**. There is no server `orderBy`.

## Setup / run

Need Flutter 3.24+ (CI uses stable), Node 22, a Tiramisu-funded key for writes.

```bash
# JS bridge (official SDK)
cd bridge && npm install && npm run build && cd ..

# Web (judges)
cd app && flutter pub get && flutter run -d chrome
# or: flutter build web --release --base-href /swatantra/

# Android
flutter build apk --release
```

Seed synthetic stories (keys never committed):

```bash
cd bridge
cp ../.env.example ../.env   # fill funded keys
node src/gen-wallets.mjs     # or reuse keys; fund at the faucet
npx tsx src/seed.ts
```

## Capture chain

In-app stills (and sampled video frames at 1 fps when available):

```
h_0 = 32 zero bytes
h_i = sha256(h_{i-1} || sha256(frame_i) || uint64be(timestamp_ms))
```

Only `chain_root`, counts and timestamps go on Arkiv. Verify screen recomputes from a file.

## Docs

- [`arkiv/schema.md`](arkiv/schema.md) — entity types, expiration, queries
- [`arkiv/friction.md`](arkiv/friction.md) — expected vs actual
- [`docs/devfolio-answers.md`](docs/devfolio-answers.md) — Devfolio form draft
- MIT [`LICENSE`](LICENSE)
