# Devfolio form — draft answers

Use these on https://arkiv.devfolio.co. Do not paste private keys.

**Project name:** Swatantra  
**Tagline:** Ground truth, unerasable.  
**Tracks:** Best Indian Use Case; Censorship Resistance; Privacy  
**Live app URL:** https://tusharojha.github.io/swatantra/  
**Repo:** https://github.com/tusharojha/swatantra  
**Demo video:** *(record from the 3-minute script below)*  
**Does any team member hold Indian nationality?** Yes *(team declares on Devfolio)*  

## The problem it solves

Ground reporters in India watch their posts disappear: ~200,000 Sahyog portal removal orders Mar–Jul 2026; journalist accounts blocked Sept 2026; 200+ Delhi police takedowns and an unpublished 24h mobile shutdown around 10 Oct 2026; MeitY guidance on “manipulated or out-of-context” content. The two failures are **erasure** and **authenticity**. Swatantra publishes the story as an Arkiv entity (protected link `/s/<entityKey>`) and binds in-app camera samples to a hash chain that anyone can recompute.

## Challenges I ran into

Bundling `@arkiv-network/sdk` 0.8.1 into Flutter; Anon Aadhaar Groth16 not fitting in the remaining window (test-mode verifier instead); Hub faucet is not scriptable so seed wallets need a human claim; public RPC rate limits on a static GitHub Pages host; no server-side orderBy so the feed sorts `created_at_ms` in the client. Details: `/arkiv/friction.md`.

## Why Arkiv?

If this lived in Postgres or “our API”, a legal request or an outage takes the archive down with the app. IPFS can hold bytes but cannot query `state = Maharashtra AND category = protest AND created_at_ms >= …`. A subgraph still depends on an indexer we run. Arkiv gives queryable attributes, unforgeable `$creator`, Entity Expiration priced per type, and Lifetime Extension on readonly stories so a community can keep a dispatch alive without being able to edit it.

**Off Arkiv on purpose:** media files (128 KiB payload, cost), private keys, any Aadhaar or personal data (not even hashed).

## How do you use Arkiv?

| Feature | How / why | Code |
|---|---|---|
| Attributes vs payload | Filters (`type`, `state`, `city`, `category`, `created_at_ms`, `nid`, `chain_root`, `amount_wei`) in typed attributes. Titles, bodies, URLs, hash algorithm notes in payload. | `bridge/src/index.ts` `createStory` / `queryStories` |
| Queries | `select().where(eq app, eq type, optional eq/gte).ownedBy().createdBy().limit().cursor().fetch()` then sort client-side | `queryStories`, `app/lib/arkiv/rpc.dart` |
| Entity Expiration | 365d journalist/capture/tip, 180d story/takedown, 2d draft, 7d tip_request | `EXPIRY` in `bridge/src/index.ts`, `arkiv/schema.md` |
| Lifetime Extension | `extendEntity(fromDays(180))` on stories; permissionless so readers can renew | `extendStory` |
| Creation flags | Stories and captures `readonly` + `permissionlessExtension` | `createStory`, `publishStoryWithCapture` |
| `$creator` / `$owner` | Byline is `$creator`; feed filter `createdBy`; journalist uniqueness is `nid` not a spoofable name | story screen, `findJournalistByNullifier` |
| WebSocket events | `watchEntityEvents` on `webSocket()` with no `fromBlock` | `watchFeed` |
| Batch writes | Capture + story in one `executeBatch` with `predictEntityKeys` | `publishStoryWithCapture` |

## Friction report

https://github.com/tusharojha/swatantra/blob/main/arkiv/friction.md

## Wallet addresses that create Arkiv entities

See README and `arkiv/seed-result.json` (filled after seed). Roles: seeder/tipper, journalist A/B/C (synthetic).

## Schema

https://github.com/tusharojha/swatantra/blob/main/arkiv/schema.md

## How judges can reproduce

1. Open the live URL. The home feed is `arkiv_query` / SDK `select` for `app=swatantra AND type=story`.
2. Open a card → `/s/<key>` calls `getEntity`.
3. Run the curl in the README; compare keys.
4. Verify: capture entity `chain_root` vs hashing a seed JPEG with `start_ms` as the timestamp (`bridge/src/hash.ts`, `app/lib/arkiv/hash.dart`).
5. Explorer: creator addresses from the README.

## Pre-existing work you reused

**None.**

## Arkiv surfaces used

TypeScript SDK, Direct JSON-RPC, WebSocket events, Docs, Hub, Faucet, Block Explorer.

## How long after you started did you write your first Arkiv entity?

2 hours or less *(update after seed)*

## Which LLMs did you use?

Cursor Grok 4.6 (cloud agent) with the official Arkiv docs and `@arkiv-network/sdk` 0.8.1 types.

## What is the one thing Arkiv should improve first?

A scriptable Tiramisu faucet (address in, GLM out, rate-limited) and a first-class Dart/Flutter recipe or generated client for `execute` / `arkiv_query`. The Hub faucet plus a TS-only SDK cost us the most clock time on a mobile submission.

## Open to a 20-minute feedback call?

Yes.

## 3-minute demo video script

0:00–0:20 Title card: Swatantra logo, “Ground truth, unerasable.” One sentence: independent journalism in India after Sahyog-scale takedowns.  
0:20–0:50 **Feed, no wallet.** Scroll synthetic Mumbai/Delhi/Imphal stories. Show city/category filters. Open a story. Point at `$creator`, publish time, capture-proof badge.  
0:50–1:20 **Protected link.** Copy `/s/<entityKey>`. Paste in a new tab — it loads from Arkiv, not a platform. “This survives a takedown of the tweet.”  
1:20–1:50 **Capture + verify.** Show in-app still → chain root. Verify screen: pick the seed JPEG, match against the capture entity. “Bytes are off Arkiv; the root is on Arkiv.”  
1:50–2:20 **Journalist TEST MODE.** Anon Aadhaar test identity → nullifier → journalist entity. Repeat with same nullifier → rejected / already exists.  
2:20–2:45 **Tip (testnet GLM)** and **Lifetime Extension** on a story. Takedown tracker.  
2:45–3:00 Curl on screen, explorer address, “MIT, schema, friction in the repo.” End card with live URL and APK.

Record at 1080p, no music bed that drowns speech, keep synthetic disclaimers visible.
