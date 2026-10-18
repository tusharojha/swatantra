# Devfolio form — submission-ready draft

Paste into https://arkiv.devfolio.co. **Never paste private keys.**

Canonical rules: [Arkiv-Network/global-tour-stop-pre-devcon](https://github.com/Arkiv-Network/global-tour-stop-pre-devcon) (`docs/submission-checklist.md`, `docs/scoring-rubric.md`). Frozen 9 October 2026.

Fields marked **[FILL AFTER SEED]** wait on seeder `0x873f5856a0967549D60442481DB5aef270044Bd7` getting ≥0.2 Tiramisu GLM. Until then the live app still reads (empty query → labelled synthetic demo) and writes from an in-app burner.

---

## Standard Devfolio fields

**Project name:** Swatantra

**Tagline:** Ground truth, unerasable.

**Project description / The problem it solves \*:**

Ground reporters in India watch posts vanish: ~200,000 Sahyog portal removal orders Mar–Jul 2026 (RSF / Indian Express); journalist accounts blocked Sept 2026; 200+ Delhi police takedowns and an unpublished 24h mobile shutdown around 10 Oct 2026; MeitY guidance on “manipulated or out-of-context” content. Two failures: **erasure** and **authenticity**.

Swatantra publishes the story as an Arkiv entity. The protected link `/s/<entityKey>` is a query, not a tweet. In-app camera samples bind to a SHA-256 hash chain stored as a readonly `capture` entity. Readers need no wallet. Journalists keep a burner in local storage and prove “Indian resident, 18+” with Anon Aadhaar **TEST MODE** (Groth16 on web; labelled SHA-256 stub on APK). Media, private keys and Aadhaar data stay off Arkiv.

All seed people, bylines and dispatches are **synthetic**.

**Challenges I ran into \*:**

Bundling `@arkiv-network/sdk` 0.8.1 into Flutter (web JS interop + a Dart `execute` path for APK). Anon Aadhaar `@anon-aadhaar/core` 2.4.3 `prove()`+`verify()` works, but the official v2 zkey is **~612 MiB** so the first browser prove is a large download and the APK keeps a labelled stub. Hub faucet is not scriptable **and on 18 Oct 2026 the dispenser `0x815Ad950ae49102952C10ceBB18901E9e28AC712` held 9.995 GLM while every claim tries to send 10**, so seed wallets sat at 0. Public RPC rate limits on GitHub Pages. No server-side `orderBy` — the feed sorts `created_at_ms` in the client. Details: `/arkiv/friction.md`.

**Tracks:** Best Indian Use Case; Censorship Resistance; Privacy  
(One prize per team; Best Indian Use Case is the intended win.)

**Project links**

- Repo: https://github.com/tusharojha/swatantra
- Live app: https://tusharojha.github.io/swatantra/
- Demo video: *(record from the 3-minute script below; ≤3:00)*
- APK: https://github.com/tusharojha/swatantra/releases/tag/apk

**Builders:** declare Indian nationality on the form. KYC for Best Indian Use Case is done with that person.

**Licence:** MIT (see `/LICENSE`).

---

## Arkiv questions (private to organizers / judges)

### 1. Live app URL \*

https://tusharojha.github.io/swatantra/

Reads use `arkiv_query` / SDK `select` — **no wallet**. Writes use an in-app burner (Me → CREATE BURNER), funded at https://hub.arkiv.network/faucet.

**[FILL AFTER PAGES]** Repo currently has `has_pages: false` (deploy-pages returns HTTP 404 until a repo admin sets **Settings → Pages → Source: GitHub Actions**). Same build is always the `swatantra-web` Actions artifact and does not block the APK. The workflow tries `POST /pages` with `build_type=workflow` on every main push.

### 2. Does any team member hold Indian nationality? \*

Yes. *(team declares the person on Devfolio; that person completes KYC if we win.)*

### 3. Why Arkiv? \*

If this lived in Postgres or “our API”, a legal request or an outage takes the archive down with the app. IPFS can hold bytes but cannot query `state = Maharashtra AND category = protest AND created_at_ms >= …`. A subgraph still depends on an indexer we run.

Arkiv is the only stack that gives, in one place:

- typed, queryable attributes (the feed is a public `arkiv_query`, not a backend);
- unforgeable `$creator` (the byline);
- Entity Expiration priced per type (180d stories, 365d journalists/captures/tips, 2d drafts);
- Lifetime Extension on **readonly** stories so a community can keep a dispatch alive without being able to edit it (`permissionlessExtension`).

**Off Arkiv on purpose:** media files (128 KiB payload, cost), private keys, any Aadhaar or personal data (not even hashed). Only hashes, URLs, synthetic copy, and a nullifier-derived `nid`.

### 3b. Why India? (Best Indian Use Case · 25 pts)

**Who:** independent and freelance ground reporters in Indian cities — Mumbai, Delhi, Chennai, Guwahati, Ranchi, Imphal, Hyderabad, Kolkata — plus the readers who still need the dispatch after a platform removal.

**What breaks today:** Sahyog-scale takedowns, account blocks, unpublished local internet shutdowns, and “out of context” notices. The reporter loses the URL **and** any proof that the still was captured when they said it was.

**What changes from day one:** open https://tusharojha.github.io/swatantra/ with no wallet. The feed is an Arkiv query. Open `/s/<entityKey>` — that link is the entity. Camera stills hash in-app; only the chain root is on chain. Hindi/Devanagari renders in the masthead (`स्वतंत्र`) so a desk that writes in Hindi is not locked to Latin type.

The seed copy is synthetic on purpose (hackathon rule: no real personal data on Arkiv). The **mechanism** is real: queryable entities, `$creator`, expiration, permissionless extension.

### 3c. Why this pillar? (CROPS tracks)

**Censorship Resistance.** Someone outside the team can read and query every story from Tiramisu (`arkiv_query` in the README) without our backend. GitHub Pages is a static host; if it dies, the curl still works. Protected links survive a tweet takedown because they are entity keys, not platform URLs.

**Privacy.** Explorer-visible attributes are `app`, `type`, `city`, `state`, `category`, timestamps, hashes, a Groth16 nullifier (`nid`). No names from Aadhaar, no QR, no photos on chain. Anon Aadhaar TEST MODE proves 18+ / optional state without revealing the person. Payload is synthetic copy + media URLs.

### 4. How do you use Arkiv? \*

We judge how and why, not how many. Every row below is in the running app.

| Feature | How / why | Code |
|---|---|---|
| Attributes vs payload | Filters live in typed attributes (`type`, `state`, `city`, `category`, `created_at_ms`, `nid`, `chain_root`, `amount_wei`). Titles, bodies, URLs, hash-algo notes live in payload. | `bridge/src/index.ts` `createStory` / `queryStories`; `arkiv/schema.md` |
| Queries | `select().where(eq app, eq type, optional eq/gte).ownedBy().createdBy().limit().cursor().fetch()` then sort `created_at_ms` client-side. Feed, story, verify, tracker, Me all hit this. | `queryStories`, `app/lib/arkiv/rpc.dart` |
| Entity Expiration | 365d journalist / capture / tip; 180d story / takedown; 2d draft; 7d tip_request. Product logic: identity lasts longer than a dispatch; drafts are cheap and short. | `EXPIRY` in `bridge/src/index.ts` |
| Lifetime Extension | `extendEntity(fromDays(180))` on stories. Sets a new 180-day life from now (does not add). UI: “Keep this story alive”. | `extendStory` / `extendStoryDart` |
| Creation flags | Stories, captures, takedowns: `readonly` + `permissionlessExtension`. Journalist: `readonly` without permissionless (identity should not be silently extended by strangers). | `createStory`, `publishStoryWithCapture` |
| `$creator` / `$owner` | Byline is `$creator`. Me-screen “Stories I created” is `createdBy`. Journalist uniqueness is `nid`, not a spoofable name. | story screen, `findJournalistByNullifier` |
| WebSocket events | `watchEntityEvents` on `webSocket()` with **no** `fromBlock`. | `watchFeed` in `bridge/src/index.ts`, started from `main.dart` |
| Batch writes | Capture + story in one `executeBatch` with `predictEntityKeys` so each can point at the other. | `publishStoryWithCapture` |

### 5. Friction report: link to `/arkiv/friction.md` \*

https://github.com/tusharojha/swatantra/blob/main/arkiv/friction.md

### 6. Wallet addresses that create your Arkiv entities \*

| Role | Address |
|---|---|
| Seeder / tipper | `0x873f5856a0967549D60442481DB5aef270044Bd7` |
| Journalist A (Maharashtra, synthetic) | `0x2E1733523b5704Cf431378618Cc5E74bB1248997` |
| Journalist B (Delhi, synthetic) | `0xf96c7F67F72301038Ec538E422e0d52e7Dd81cCF` |
| Journalist C (Northeast, synthetic) | `0x68F0Ee5526e28e9072A9Fa398d91A5a867001645` |
| Reader burner (unused in seed) | `0x376B04bB89b6486d7f30C7B9a2251500cfae9ffF` |

**[FILL AFTER SEED]** entity keys + explorer tx links: [`arkiv/seed-result.json`](https://github.com/tusharojha/swatantra/blob/main/arkiv/seed-result.json). Until the seeder has ≥0.2 GLM the JSON records `status: pending_faucet` and the Hub dispenser shortfall (9.995 GLM vs a 10 GLM drip).

Judges can still **write** from the in-app burner (Me) and **read** the empty query / synthetic demo.

### 7. Link to `/arkiv/schema.md` \*

https://github.com/tusharojha/swatantra/blob/main/arkiv/schema.md

### 8. How can judges reproduce your Arkiv usage? \*

1. Open https://tusharojha.github.io/swatantra/ — no wallet. Home feed is `arkiv_query` / SDK `select` for `app=swatantra AND type=story`. If the result is empty you will see a **SYNTHETIC DEMO** banner; that list is dropped the moment entities exist.
2. Open a card → `/s/<key>` calls `getEntity`. Copy the protected link, paste in a new tab.
3. Run the curl in the README; compare keys to the UI and to the explorer (`$creator` = journalist burner).
4. Verify: capture entity `chain_root` vs hashing a seed JPEG with `start_ms` as the timestamp (`bridge/src/hash.ts`, `app/lib/arkiv/hash.dart`).
5. Me → CREATE BURNER → fund on the Hub faucet → Post a synthetic story (optional camera still) → tip / extend on the article page. Tracker writes a `takedown` entity.
6. Web only: Me → journalist onboarding → bundled PSE TEST QR → Groth16 prove/verify → “Proof verified ✓ (TEST MODE)” → journalist entity with `nid` uniqueness.
7. Explorer: creator addresses in the table above. **[FILL AFTER SEED]** creation txs from `arkiv/seed-result.json`.

### 9. Pre-existing work you reused \*

**None.** Built 18 October 2026 during the challenge. Third-party libraries only: Flutter, `@arkiv-network/sdk` 0.8.1, `@anon-aadhaar/core` 2.4.3, Google Fonts.

### 10. Arkiv surfaces you used \*

TypeScript SDK, Direct JSON-RPC, WebSocket events, Docs, Hub, Faucet, Block Explorer.

### 11. If you selected Other, name it

*(leave blank)*

### 12. How long after you started did you write your first Arkiv entity? \*

2 hours or less **[FILL AFTER SEED — confirm once `seed-result.json` has entity keys; the seeder write is blocked only by the insolvent 10 GLM faucet drip]**. In-app burner writes are live now and do not wait on the seeder.

### 13. Which LLMs did you use? \*

Cursor Grok 4.6 (cloud agent) with the official Arkiv docs, `@arkiv-network/sdk` 0.8.1 types, and the frozen rules repo.

### 14. What is the one thing Arkiv should improve first? \*

A scriptable Tiramisu faucet that can send `min(10, balance − gas)` instead of reverting a 10 GLM drip when the dispenser is 0.005 GLM short — plus a first-class Dart/Flutter recipe for `execute` / `arkiv_query`. The Hub faucet plus a TS-only SDK cost us the most clock time on a mobile submission.

### 15. Open to a 20-minute feedback call with the Arkiv team? \*

Yes.

### 16. This is our team's work, built between 9 and 18 October. Any pre-existing or third-party work is disclosed. \*

Yes.

### 17. Our repo is public under the MIT licence, and every link is accessible to judges. \*

Yes.

### 18. I plan to attend Devcon 8 in Mumbai (optional)

*(builder fills on Devfolio; not required to win.)*

---

## Gates checklist (must pass before scoring)

| Gate | Status |
|---|---|
| Public deployment, no access request | Live URL above; APK on GitHub Release `apk` |
| Reproducible Arkiv usage | README curl + this doc §8 |
| Public MIT repo | `/LICENSE` |
| `/arkiv/schema.md` | present |
| `/arkiv/friction.md` | present |
| Tiramisu creator wallets | table in §6 |
| Demo video ≤ 3 min | script below; **record before 22:59 UTC 18 Oct** |
| Every required form question | this file |
| ≥1 track | Best Indian Use Case + CR + Privacy |
| Built 9–18 Oct 2026 | yes; pre-existing = None |
| No secrets / real PII on Arkiv | synthetic seed; nid is a TEST MODE nullifier |
| Deployment kept up until 23 Oct | Pages + Release tag |

---

## Tech stack (for project media / judges)

Flutter (web + Android APK), Dart JSON-RPC + `execute` writes, `@arkiv-network/sdk` 0.8.1 (web bundle), `@anon-aadhaar/core` 2.4.3 TEST MODE, GitHub Pages, Tiramisu chain `7738577`.

---

## 3-minute demo video — shot list and timestamps

Record 1080p, spoken English, **no music bed**. Keep **SYNTHETIC DEMO** / **TEST MODE** banners visible. Hard cut at 2:55.

| Time | Shot | What to say / show |
|---|---|---|
| 0:00–0:12 | Title card: rangoli logo + **Swatantra / स्वतंत्र**. Live URL on screen. | “Ground truth, unerasable. Independent journalism in India after Sahyog-scale takedowns.” |
| 0:12–0:28 | Browser, **no wallet**. Masthead Hindi dateline. | “Judges can read without a wallet. The paper is an Arkiv query.” |
| 0:28–0:50 | Feed. Scroll lead + list. Filter State = Delhi, Category = protest. | “City and category are typed attributes. If the chain is empty you see a labelled synthetic demo — it switches off the moment entities exist.” |
| 0:50–1:10 | Open lead story. Standfirst, byline `$creator`, verification block. | “Byline is `$creator`, not a field anyone can type.” |
| 1:10–1:28 | Copy protected link `/s/<key>`. New tab. | “This survives a takedown of the tweet. It is the entity key.” |
| 1:28–1:50 | Post: camera or gallery still → chain root. Publish (or show the hash if unfunded). | “In-app capture. Bytes stay off Arkiv; the SHA-256 chain root is on Arkiv.” |
| 1:50–2:10 | Verify: paste `chain_root`, pick the seed JPEG with stored `start_ms`. MATCH. | “Anyone can recompute. No media on chain — 128 KiB payload cap.” |
| 2:10–2:32 | Me → journalist. Bundled PSE TEST QR. **Proof verified ✓ (TEST MODE)** + nullifier. Create entity. Repeat → already exists. | “Groth16 in TEST MODE. We store nid, age, state-reveal, proof hash — never the QR. APK is a labelled stub because the zkey is 612 MiB.” |
| 2:32–2:48 | Article: tip 0.01 GLM; Extend on Arkiv. Tracker list. | “Testnet tip is a transfer plus a tip entity. Lifetime Extension is permissionless on readonly stories. Tracker is `type=takedown`.” |
| 2:48–3:00 | Terminal curl `arkiv_query`. Explorer address. End card: live URL, repo, APK, MIT. | “Schema and friction in the repo. Thank you.” |

If the seeder is still unfunded, **do not hide the SYNTHETIC DEMO banner** — show it, then Post one live story from a funded burner so at least one real entity is on camera. **[FILL AFTER SEED]** swap the feed shot to live keys and flash `seed-result.json` explorer links for 3 seconds at 2:50.
