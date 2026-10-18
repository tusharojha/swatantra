# Swatantra — Arkiv schema

App attribute on every entity: `app = str('swatantra')`.

Trust comes from `$creator` (immutable). `$owner` can change and is not used as identity.

Payload is **not queryable**. Anything the feed filters on lives in attributes. Media bytes are **not** stored on Arkiv (payload cap 128 KiB; video/photo cost). The payload holds titles, bodies, URLs and notes.

Ranges are only used on numeric attributes (`u64`, `i32`, `u256`).

There is **no server-side orderBy**. The app sorts on the client, usually by `created_at_ms` descending.

## Entity Expiration (not "TTL")

| type | lifetime | flags | why |
|---|---|---|---|
| `journalist` | 365 days | `readonly`, `permissionlessExtension` | Identity lease. `nid` uniqueness is the person; flags match stories so the desk cannot be edited and anyone can keep the lease alive. |
| `story` | 180 days | `readonly`, `permissionlessExtension` | Ground copy should not be edited after publish. Readers and the journalist can keep it alive. |
| `capture` | 365 days | `readonly`, `permissionlessExtension` | Integrity record outlives a single news cycle. Immutable once written. |
| `tip` | 365 days | `readonly` | Support history. Only the tipper's wallet (`$creator`) is evidence of who sent it. |
| `takedown` | 180 days | `readonly`, `permissionlessExtension` | Public tracker. Community can extend. |
| `corroboration` | 180 days | `readonly`, `permissionlessExtension` | Snapshot of a witness cluster so the badge is queryable without a live join. |
| `draft` | 2 days | — | Scratch copy. Cheap and short so abandoned drafts expire. |
| `tip_request` | 7 days | — | Short-lived ask. Not used in the first seed. |

Lifetime Extension: `extendEntity({ entityKey, expires: ExpirationTime.fromDays(180) })` on a story. The new expiry is counted **from now**, not added to the remainder. Stories set `permissionlessExtension` so a reader can keep a dispatch alive without being able to change it.

## Attribute dictionary

Names are snake_case, ≤ 32 chars. Types must match on write and query.

| name | type | on | purpose |
|---|---|---|---|
| `app` | str | all | `swatantra` |
| `type` | str | all | `journalist` `story` `capture` `tip` `takedown` `draft` `tip_request` `corroboration` |
| `created_at_ms` | u64 | all | Unix ms. Range filters. Client-side sort. |
| `nid` | bytes32 | journalist | Anon Aadhaar **test-mode** Groth16 nullifier (field element as 32-byte BE). One person ↔ one journalist. |
| `groth16` | bool | journalist | `true` when `nid` came from `@anon-aadhaar/core` `verify()`, not the SHA-256 stub. |
| `age_over_18` | bool | journalist | Selective-disclosure flag from the proof (`revealAgeAbove18`). |
| `state_revealed` | bool | journalist | Whether the proof revealed state. The state *string* is not copied from the QR. |
| `proof_hash` | bytes32 | journalist | SHA-256 of the Groth16 proof JSON. The proof itself stays off Arkiv. |
| `state` | str | journalist, story | Indian state / UT |
| `city` | str | story, capture | City, coarse |
| `category` | str | story | `civic` `protest` `environment` `labour` `conflict` `other` |
| `test_mode` | bool | journalist | Always true in this build |
| `journalist_key` | key | story | Journalist entity |
| `capture_key` | key | story | Capture entity |
| `chain_root` | bytes32 | capture | SHA-256 chain root |
| `frame_count` | i32 | capture | Sampled frames |
| `fps` | i32 | capture | Sampling rate |
| `start_ms` | u64 | capture | First sample |
| `end_ms` | u64 | capture | Last sample |
| `story_key` | key | capture, tip, takedown | Parent story |
| `amount_wei` | u256 | tip | Native test GLM, wei |
| `to_addr` | addr | tip | Journalist wallet that received the transfer |
| `platform` | str | takedown | `X` `Instagram` `YouTube` `Facebook` `WhatsApp` `other` |
| `notice_date_ms` | u64 | takedown | When the notice was dated |
| `law_cited` | str | takedown | Short citation (synthetic in demo) |
| `authority_named` | bool | takedown | Whether an authority was named on the notice |
| `district` | str | capture, story, corroboration | Coarse Indian district. Never a lat/lng. |
| `geo_cell` | str | capture, story, corroboration | `lat,lng` rounded to **0.1°** (~11 km). |
| `capture_ts_ms` | u64 | capture, story | Sample time used for the ±30 min corroboration window. |
| `window_start_ms` | u64 | corroboration | Inclusive window start |
| `window_end_ms` | u64 | corroboration | Inclusive window end |
| `witness_count` | i32 | corroboration | Distinct journalist nullifiers (`nid`) in the window |

### Payload (not indexed)

- **journalist:** `{ displayName, bio, testMode, groth16, proofHash, claims }` — synthetic display names only. Never QR data, names, or photos from Aadhaar.
- **story:** `{ title, body, mediaUrl, mediaHash, captureRoot, synthetic }`
- **capture:** `{ algo, mediaUrl, deviceTime, whyOffArkiv, district, geoCell }`
- **corroboration:** `{ story_keys, capture_keys, nids, synthetic }`
- **tip:** `{ note, testnet, token: "GLM" }`
- **takedown:** `{ notes, synthetic, disclaimer }`

Never: private keys, Aadhaar data, real names of living private individuals, emails, phones, hashes of those.

## Capture chain

District-bound. Precise GPS is **never** hashed or stored.

```
h_0      = 32 zero bytes
place    = SHA-256( utf8(district) || 0x00 || utf8(geo_cell) )
frame_i  = SHA-256(frame bytes)
h_i      = SHA-256( h_{i-1} || frame_i || uint64be(timestamp_ms) || place )
root     = h_n
```

`geo_cell` is lat,lng rounded to 0.1°. Photos are a 1-frame chain. Video samples JPEG frames at 1 fps in-app.

## Corroboration

For a capture at time `t` in district `X`:

```
app = str('swatantra') AND type = str('capture')
  AND district = str('X')
  AND capture_ts_ms >= u64(t - 30min)
  AND capture_ts_ms <= u64(t + 30min)
```

Then count **distinct** journalist `nid` values by looking up `type=journalist` createdBy each capture `$creator`. **N ≥ 2** ⇒ badge `CORROBORATED · N independent witnesses · {district} district · {time}`.

Optionally write `type=corroboration` with `district`, `geo_cell`, `window_*`, `witness_count`, `story_key` so the cluster is itself an Arkiv entity.

## Queries the app runs

All through `@arkiv-network/sdk` 0.8.x:

```ts
client.select({ key, owner, creator, createdAt, expiresAt, payload, attributes, contentType, creationFlags })
  .where(eq("app", str("swatantra")), eq("type", str("story")))
  // optional:
  .where(eq("state", str(state)))
  .where(eq("city", str(city)))
  .where(eq("category", str(category)))
  .where(gte("created_at_ms", u64(fromMs)))
  .where(lte("created_at_ms", u64(toMs)))
  .ownedBy(address)      // "my stories" as owner
  .createdBy(address)    // authorship — this is the trust signal
  .limit(100)
  .cursor(saved)
  .fetch()
```

Reproduce from any machine (no wallet):

```bash
curl -sS https://rpc.tiramisu.db-chain.testnet.arkiv.network \
  -H 'content-type: application/json' \
  -d '{
    "jsonrpc":"2.0","id":1,
    "method":"arkiv_query",
    "params":[
      "app = str('\''swatantra'\'') AND type = str('\''story'\'')",
      {"limit":"0x64","select":{"key":true,"creator":true,"payload":true,"attributes":true,"owner":true,"expiresAt":true}}
    ]
  }'
```

Other queries:

| intent | expression |
|---|---|
| One journalist by nullifier | `app = str('swatantra') AND type = str('journalist') AND nid = bytes32(0x…)` |
| Tips for a story | `app = str('swatantra') AND type = str('tip') AND story_key = key(0x…)` |
| Capture by chain root | `app = str('swatantra') AND type = str('capture') AND chain_root = bytes32(0x…)` |
| Takedown tracker | `app = str('swatantra') AND type = str('takedown')` |
| Witnesses in a district window | `app = str('swatantra') AND type = str('capture') AND district = str('Pune') AND capture_ts_ms >= u64(…) AND capture_ts_ms <= u64(…)` |
| Stored cluster | `app = str('swatantra') AND type = str('corroboration') AND district = str('Pune')` |
| Stories by a wallet | same story query + `.createdBy(0x…)` |
| Protected link | `getEntity(entityKey)` |

Client then sorts stories by `created_at_ms` desc and sums `amount_wei` for tips.

## Live updates

`watchEntityEvents` on a **WebSocket** transport (`wss://rpc.tiramisu.db-chain.testnet.arkiv.network`) with **no** `fromBlock`, so it opens a real socket instead of polling. The feed refreshes on `EntityCreated`.
