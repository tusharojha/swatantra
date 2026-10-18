/**
 * Swatantra Arkiv bridge — @arkiv-network/sdk 0.8.x
 *
 * Loaded as an IIFE on Flutter web (window.SwatantraArkiv) and used by the
 * Node seed script. Reads go through createPublicClient.select(). Writes go
 * through createWalletClient (createEntity / executeBatch / extendEntity).
 */

import {
  createPublicClient,
  createWalletClient,
  ExpirationTime,
  jsonToPayload,
} from "@arkiv-network/sdk";
import { addr, bool, bytes32, i32, key, str, u64, u256 } from "@arkiv-network/sdk/attr";
import { eq, gte, lte } from "@arkiv-network/sdk/query";
import { custom, http, parseEther, webSocket, type Hex } from "viem";
import { generatePrivateKey, privateKeyToAccount, type PrivateKeyAccount } from "viem/accounts";
import { BUNDLED_TEST_QR, verifyTestAnonAadhaar } from "./anon";
import { hashChain, hashSingleFile, type FrameSample } from "./hash";
import { getNetwork, setNetwork, isLocal } from "./network";

export { getNetwork, setNetwork, isLocal, LOCAL_DEV_KEY, LOCAL_DEV_ADDRESS } from "./network";

export const APP = "swatantra";
export let RPC = getNetwork().rpc;
export let WS = getNetwork().ws;
export let EXPLORER = getNetwork().explorer;
export let CHAIN_ID = getNetwork().chainId;

function syncNetworkExports() {
  const n = getNetwork();
  RPC = n.rpc;
  WS = n.ws;
  EXPLORER = n.explorer;
  CHAIN_ID = n.chainId;
}

export function applyNetwork(name?: string | null) {
  setNetwork(name);
  syncNetworkExports();
  return { network: getNetwork().name, rpc: RPC, chainId: CHAIN_ID, explorer: EXPLORER };
}

const SELECT = {
  key: true,
  owner: true,
  creator: true,
  createdAt: true,
  expiresAt: true,
  payload: true,
  attributes: true,
  contentType: true,
  creationFlags: true,
} as const;

export const EXPIRY = {
  journalist: () => ExpirationTime.fromDays(365),
  story: () => ExpirationTime.fromDays(180),
  capture: () => ExpirationTime.fromDays(365),
  tip: () => ExpirationTime.fromDays(365),
  takedown: () => ExpirationTime.fromDays(180),
  draft: () => ExpirationTime.fromDays(2),
  tip_request: () => ExpirationTime.fromDays(7),
  corroboration: () => ExpirationTime.fromDays(180),
};

let account: PrivateKeyAccount | undefined;
let injectedAddress: `0x${string}` | undefined;
let injectedEth: { request: (args: { method: string; params?: unknown[] }) => Promise<unknown> } | undefined;
let unwatch: (() => void) | undefined;

export function publicClient() {
  const n = getNetwork();
  return createPublicClient({ chain: n.chain, transport: http(n.rpc) });
}

export function publicWs() {
  const n = getNetwork();
  return createPublicClient({ chain: n.chain, transport: webSocket(n.ws) });
}

export function walletClient() {
  const n = getNetwork();
  if (injectedEth && injectedAddress) {
    return createWalletClient({
      account: injectedAddress,
      chain: n.chain,
      transport: custom(injectedEth),
    });
  }
  if (!account) throw new Error("no wallet unlocked");
  return createWalletClient({
    account,
    chain: n.chain,
    transport: http(n.rpc),
  });
}

function attrVal(entity: { attributes?: Record<string, { type: string; value: unknown }> }, name: string) {
  const a = entity.attributes?.[name];
  if (!a) return undefined;
  const v = a.value as unknown;
  if (typeof v === "bigint") return v.toString();
  return v;
}

function serializeEntity(e: {
  key?: Hex;
  owner?: string;
  creator?: string;
  createdAt?: bigint;
  expiresAt?: bigint;
  contentType?: string;
  creationFlags?: { readonly?: boolean; permissionlessExtension?: boolean };
  attributes?: Record<string, { type: string; value: unknown }>;
  toJson?: () => unknown;
}): Record<string, unknown> {
  const attributes: Record<string, { type: string; value: unknown }> = {};
  for (const [k, v] of Object.entries(e.attributes ?? {})) {
    const value = typeof v.value === "bigint" ? v.value.toString() : v.value;
    attributes[k] = { type: v.type, value };
  }
  let payload: unknown = null;
  try {
    payload = e.toJson?.() ?? null;
  } catch {
    payload = null;
  }
  return {
    key: e.key,
    owner: e.owner,
    creator: e.creator,
    createdAt: e.createdAt?.toString(),
    expiresAt: e.expiresAt?.toString(),
    contentType: e.contentType,
    creationFlags: e.creationFlags,
    attributes,
    payload,
  };
}

export async function queryEntities(input: {
  type: string;
  extra?: Array<{ op: "eq" | "gte" | "lte"; name: string; kind: "str" | "u64" | "i32" | "bytes32" | "key" | "bool"; value: string | number | boolean }>;
  ownedBy?: string;
  createdBy?: string;
  cursor?: string;
  limit?: number;
}) {
  const pub = publicClient();
  let q = pub
    .select(SELECT)
    .where(eq("app", str(APP)), eq("type", str(input.type)))
    .limit(input.limit ?? 50);
  for (const p of input.extra ?? []) {
    if (p.op === "eq") {
      if (p.kind === "str") q = q.where(eq(p.name, str(String(p.value))));
      else if (p.kind === "u64") q = q.where(eq(p.name, u64(BigInt(p.value as number | string))));
      else if (p.kind === "i32") q = q.where(eq(p.name, i32(Number(p.value))));
      else if (p.kind === "bytes32") q = q.where(eq(p.name, bytes32(p.value as Hex)));
      else if (p.kind === "key") q = q.where(eq(p.name, key(p.value as Hex)));
      else if (p.kind === "bool") q = q.where(eq(p.name, bool(Boolean(p.value))));
    } else if (p.op === "gte" && p.kind === "u64") {
      q = q.where(gte(p.name, u64(BigInt(p.value as number | string))));
    } else if (p.op === "lte" && p.kind === "u64") {
      q = q.where(lte(p.name, u64(BigInt(p.value as number | string))));
    }
  }
  if (input.ownedBy) q = q.ownedBy(input.ownedBy as Hex);
  if (input.createdBy) q = q.createdBy(input.createdBy as Hex);
  if (input.cursor) q = q.cursor(input.cursor);
  const page = await q.fetch();
  return {
    entities: page.entities.map(serializeEntity),
    cursor: page.cursor ?? null,
    blockNumber: page.blockNumber.toString(),
    hasNext: page.hasNextPage(),
  };
}

export async function queryStories(filters: {
  state?: string;
  city?: string;
  category?: string;
  fromMs?: string;
  toMs?: string;
  createdBy?: string;
  ownedBy?: string;
  cursor?: string;
} = {}) {
  const extra: Parameters<typeof queryEntities>[0]["extra"] = [];
  if (filters.state) extra.push({ op: "eq", name: "state", kind: "str", value: filters.state });
  if (filters.city) extra.push({ op: "eq", name: "city", kind: "str", value: filters.city });
  if (filters.category) extra.push({ op: "eq", name: "category", kind: "str", value: filters.category });
  if (filters.fromMs) extra.push({ op: "gte", name: "created_at_ms", kind: "u64", value: filters.fromMs });
  if (filters.toMs) extra.push({ op: "lte", name: "created_at_ms", kind: "u64", value: filters.toMs });
  const page = await queryEntities({
    type: "story",
    extra,
    createdBy: filters.createdBy,
    ownedBy: filters.ownedBy,
    cursor: filters.cursor,
    limit: 100,
  });
  // No server-side orderBy. Sort by created_at_ms desc on the client.
  page.entities.sort((a, b) => {
    const av = Number((a.attributes as Record<string, { value: string }>)?.created_at_ms?.value ?? 0);
    const bv = Number((b.attributes as Record<string, { value: string }>)?.created_at_ms?.value ?? 0);
    return bv - av;
  });
  return page;
}

export async function getEntity(entityKey: string) {
  const entity = await publicClient().getEntity(entityKey as Hex);
  return serializeEntity(entity);
}

export function createBurner() {
  injectedEth = undefined;
  injectedAddress = undefined;
  const pk = generatePrivateKey();
  account = privateKeyToAccount(pk);
  return { address: account.address, privateKey: pk };
}

export function unlock(privateKey: string) {
  injectedEth = undefined;
  injectedAddress = undefined;
  const pk = (privateKey.startsWith("0x") ? privateKey : `0x${privateKey}`) as Hex;
  account = privateKeyToAccount(pk);
  return { address: account.address };
}

export function getAddress() {
  if (injectedAddress) return { address: injectedAddress, injected: true };
  return account ? { address: account.address } : { address: null };
}

export async function getBalance() {
  const addr = injectedAddress ?? account?.address;
  if (!addr) return { wei: "0" };
  const wei = await publicClient().getBalance({ address: addr });
  return { wei: wei.toString() };
}

type EthereumProvider = { request: (args: { method: string; params?: unknown[] }) => Promise<unknown> };

function browserEthereum(): EthereumProvider | undefined {
  const eth = (globalThis as { ethereum?: EthereumProvider }).ethereum;
  return eth;
}

export async function connectInjected() {
  const eth = browserEthereum();
  if (!eth) throw new Error("NO_INJECTED");
  const n = getNetwork();
  const chainHex = `0x${n.chainId.toString(16)}`;
  try {
    await eth.request({ method: "wallet_switchEthereumChain", params: [{ chainId: chainHex }] });
  } catch {
    await eth.request({
      method: "wallet_addEthereumChain",
      params: [
        {
          chainId: chainHex,
          chainName: n.name === "local" ? "Arkiv Local" : "Arkiv Tiramisu",
          nativeCurrency: { name: n.nativeToken, symbol: n.nativeToken, decimals: 18 },
          rpcUrls: [n.rpc],
          blockExplorerUrls: [n.explorer],
        },
      ],
    });
  }
  const accounts = (await eth.request({ method: "eth_requestAccounts" })) as string[];
  if (!accounts?.[0]) throw new Error("NO_INJECTED");
  account = undefined;
  injectedEth = eth;
  injectedAddress = accounts[0] as `0x${string}`;
  return { address: injectedAddress, injected: true, chainId: n.chainId };
}

export async function connectWalletConnect(projectId?: string) {
  const id =
    projectId ||
    (() => {
      try {
        return (globalThis as { process?: { env?: Record<string, string | undefined> } }).process?.env
          ?.WALLETCONNECT_PROJECT_ID;
      } catch {
        return undefined;
      }
    })();
  if (!id) throw new Error("NO_PROJECT_ID");
  // Reown AppKit is optional. Without a bundled provider we refuse rather than
  // ship a half-wired WalletConnect session. UI falls back to burner / injected.
  throw new Error("NO_PROJECT_ID");
}

type AaGlobal = {
  proveAndVerifyTestMode?: (opts: {
    qrData?: string;
    revealState?: boolean;
    onProgress?: (s: string) => void;
    localArtifacts?: { wasm: string; zkey: string; vkey: string };
  }) => Promise<{
    ok: boolean;
    groth16: boolean;
    testMode: boolean;
    nullifier: string;
    ageAbove18?: boolean;
    stateRevealed?: boolean;
    state?: string;
    proofHash?: string;
    note?: string;
  }>;
};

export async function verifyJournalist(qrData: string, revealState?: string) {
  const aa = (globalThis as unknown as { SwatantraAA?: AaGlobal }).SwatantraAA;
  if (aa?.proveAndVerifyTestMode) {
    const r = await aa.proveAndVerifyTestMode({
      qrData: qrData || "",
      revealState: Boolean(revealState),
    });
    return { ...r, indianResident: true as const, ageOver18: r.ageAbove18 !== false };
  }
  return verifyTestAnonAadhaar(qrData || BUNDLED_TEST_QR, revealState);
}

export async function findJournalistByNullifier(nullifier: string) {
  const page = await queryEntities({
    type: "journalist",
    extra: [{ op: "eq", name: "nid", kind: "bytes32", value: nullifier }],
    limit: 5,
  });
  return page.entities[0] ?? null;
}

export async function createJournalist(input: {
  nullifier: string;
  state?: string;
  displayName: string;
  bio?: string;
  groth16?: boolean;
  ageAbove18?: boolean;
  stateRevealed?: boolean;
  proofHash?: string;
}) {
  const existing = await findJournalistByNullifier(input.nullifier);
  if (existing) {
    return { already: true, entity: existing };
  }
  const created = await walletClient().createEntity({
    payload: jsonToPayload({
      displayName: input.displayName,
      bio: input.bio ?? "",
      testMode: true,
      groth16: input.groth16 === true,
      proofHash: input.proofHash ?? "",
      claims: {
        indianResident: true,
        ageOver18: input.ageAbove18 !== false,
        stateRevealed: input.stateRevealed === true,
      },
    }),
    contentType: "application/json",
    attributes: {
      app: str(APP),
      type: str("journalist"),
      nid: bytes32(input.nullifier as Hex),
      created_at_ms: u64(BigInt(Date.now())),
      ...(input.state ? { state: str(input.state) } : {}),
      test_mode: bool(true),
      groth16: bool(input.groth16 === true),
      age_over_18: bool(input.ageAbove18 !== false),
      state_revealed: bool(input.stateRevealed === true),
      ...(input.proofHash ? { proof_hash: bytes32(input.proofHash as Hex) } : {}),
    },
    expires: EXPIRY.journalist(),
    flags: { readonly: true, permissionlessExtension: true },
  });
  return {
    already: false,
    entityKey: created.entityKey,
    txHash: created.txHash,
    expiresAt: created.expiresAt.toString(),
  };
}

export async function createStory(input: {
  title: string;
  body: string;
  city: string;
  state: string;
  category: string;
  mediaUrl?: string;
  mediaHash?: string;
  captureKey?: string;
  captureRoot?: string;
  journalistKey?: string;
  district?: string;
  geoCell?: string;
  captureTsMs?: number;
}) {
  const now = Date.now();
  const created = await walletClient().createEntity({
    payload: jsonToPayload({
      title: input.title,
      body: input.body,
      mediaUrl: input.mediaUrl ?? "",
      mediaHash: input.mediaHash ?? "",
      captureRoot: input.captureRoot ?? "",
      synthetic: true,
    }),
    contentType: "application/json",
    attributes: {
      app: str(APP),
      type: str("story"),
      city: str(input.city),
      state: str(input.state),
      category: str(input.category),
      created_at_ms: u64(BigInt(now)),
      ...(input.district ? { district: str(input.district) } : {}),
      ...(input.geoCell ? { geo_cell: str(input.geoCell) } : {}),
      ...(input.captureTsMs ? { capture_ts_ms: u64(BigInt(input.captureTsMs)) } : {}),
      ...(input.captureKey ? { capture_key: key(input.captureKey as Hex) } : {}),
      ...(input.journalistKey ? { journalist_key: key(input.journalistKey as Hex) } : {}),
    },
    expires: EXPIRY.story(),
    flags: { readonly: true, permissionlessExtension: true },
  });
  return {
    entityKey: created.entityKey,
    txHash: created.txHash,
    expiresAt: created.expiresAt.toString(),
  };
}

export async function createCapture(input: {
  root: string;
  frameCount: number;
  fps: number;
  startMs: number;
  endMs: number;
  city: string;
  mediaUrl?: string;
  storyKey?: string;
  district?: string;
  geoCell?: string;
}) {
  const district = input.district ?? "";
  const geoCell = input.geoCell ?? "";
  const created = await walletClient().createEntity({
    payload: jsonToPayload({
      algo: "h_i = sha256(h_{i-1} || sha256(frame_i) || uint64be(ts_ms) || place); place = sha256(district || 0x00 || geo_cell); h_0 = 32 zero bytes",
      mediaUrl: input.mediaUrl ?? "",
      deviceTime: new Date(input.startMs).toISOString(),
      whyOffArkiv: "Media files stay off Arkiv because of size and cost (payload cap 128 KiB).",
      district,
      geoCell,
    }),
    contentType: "application/json",
    attributes: {
      app: str(APP),
      type: str("capture"),
      chain_root: bytes32(input.root as Hex),
      frame_count: i32(input.frameCount),
      fps: i32(input.fps),
      start_ms: u64(BigInt(input.startMs)),
      end_ms: u64(BigInt(input.endMs)),
      capture_ts_ms: u64(BigInt(input.startMs)),
      created_at_ms: u64(BigInt(Date.now())),
      city: str(input.city),
      ...(district ? { district: str(district) } : {}),
      ...(geoCell ? { geo_cell: str(geoCell) } : {}),
      ...(input.storyKey ? { story_key: key(input.storyKey as Hex) } : {}),
    },
    expires: EXPIRY.capture(),
    flags: { readonly: true, permissionlessExtension: true },
  });
  return {
    entityKey: created.entityKey,
    txHash: created.txHash,
    expiresAt: created.expiresAt.toString(),
  };
}

/** Atomic story + capture in one executeBatch, with predicted keys. */
export async function publishStoryWithCapture(input: {
  title: string;
  body: string;
  city: string;
  state: string;
  category: string;
  mediaUrl?: string;
  mediaHash?: string;
  journalistKey?: string;
  district?: string;
  geoCell?: string;
  capture: {
    root: string;
    frameCount: number;
    fps: number;
    startMs: number;
    endMs: number;
  };
}) {
  const owner = injectedAddress ?? account?.address;
  if (!owner) throw new Error("no wallet unlocked");
  const pub = publicClient();
  const [capPred, storyPred] = await pub.predictEntityKeys({ owner, count: 2 as const });
  const now = Date.now();
  const result = await walletClient().executeBatch({
    creates: [
      {
        payload: jsonToPayload({
          algo: "h_i = sha256(h_{i-1} || sha256(frame_i) || uint64be(ts_ms) || place); place = sha256(district || 0x00 || geo_cell); h_0 = 32 zero bytes",
          mediaUrl: input.mediaUrl ?? "",
          deviceTime: new Date(input.capture.startMs).toISOString(),
          whyOffArkiv: "Media files stay off Arkiv because of size and cost (payload cap 128 KiB).",
          district: input.district ?? "",
          geoCell: input.geoCell ?? "",
        }),
        contentType: "application/json",
        attributes: {
          app: str(APP),
          type: str("capture"),
          chain_root: bytes32(input.capture.root as Hex),
          frame_count: i32(input.capture.frameCount),
          fps: i32(input.capture.fps),
          start_ms: u64(BigInt(input.capture.startMs)),
          end_ms: u64(BigInt(input.capture.endMs)),
          capture_ts_ms: u64(BigInt(input.capture.startMs)),
          created_at_ms: u64(BigInt(now)),
          city: str(input.city),
          ...(input.district ? { district: str(input.district) } : {}),
          ...(input.geoCell ? { geo_cell: str(input.geoCell) } : {}),
          story_key: key(storyPred.key),
        },
        expires: EXPIRY.capture(),
        flags: { readonly: true, permissionlessExtension: true },
        salt: capPred.salt,
      },
      {
        payload: jsonToPayload({
          title: input.title,
          body: input.body,
          mediaUrl: input.mediaUrl ?? "",
          mediaHash: input.mediaHash ?? "",
          captureRoot: input.capture.root,
          synthetic: true,
        }),
        contentType: "application/json",
        attributes: {
          app: str(APP),
          type: str("story"),
          city: str(input.city),
          state: str(input.state),
          category: str(input.category),
          created_at_ms: u64(BigInt(now)),
          capture_key: key(capPred.key),
          ...(input.district ? { district: str(input.district) } : {}),
          ...(input.geoCell ? { geo_cell: str(input.geoCell) } : {}),
          capture_ts_ms: u64(BigInt(input.capture.startMs)),
          ...(input.journalistKey ? { journalist_key: key(input.journalistKey as Hex) } : {}),
        },
        expires: EXPIRY.story(),
        flags: { readonly: true, permissionlessExtension: true },
        salt: storyPred.salt,
      },
    ],
  });
  return {
    captureKey: capPred.key,
    storyKey: storyPred.key,
    createdEntities: result.createdEntities,
    txHash: result.txHash,
  };
}

export async function createTip(input: {
  storyKey: string;
  to: string;
  amountEth: string;
  note?: string;
}) {
  const w = walletClient();
  const value = parseEther(input.amountEth);
  const txHash = await w.sendTransaction({
    to: input.to as Hex,
    value,
  });
  const created = await w.createEntity({
    payload: jsonToPayload({ note: input.note ?? "", testnet: true, token: "GLM" }),
    contentType: "application/json",
    attributes: {
      app: str(APP),
      type: str("tip"),
      story_key: key(input.storyKey as Hex),
      amount_wei: u256(value),
      created_at_ms: u64(BigInt(Date.now())),
      to_addr: addr(input.to as Hex),
    },
    expires: EXPIRY.tip(),
    flags: { readonly: true },
  });
  return {
    transferTx: txHash,
    entityKey: created.entityKey,
    entityTx: created.txHash,
  };
}

export async function createTakedown(input: {
  platform: string;
  dateMs: number;
  lawCited: string;
  authorityNamed: boolean;
  storyKey?: string;
  notes?: string;
}) {
  const created = await walletClient().createEntity({
    payload: jsonToPayload({
      notes: input.notes ?? "",
      synthetic: true,
      disclaimer: "Synthetic or self-reported. Not legal advice.",
    }),
    contentType: "application/json",
    attributes: {
      app: str(APP),
      type: str("takedown"),
      platform: str(input.platform),
      notice_date_ms: u64(BigInt(input.dateMs)),
      law_cited: str(input.lawCited.slice(0, 120)),
      authority_named: bool(input.authorityNamed),
      created_at_ms: u64(BigInt(Date.now())),
      ...(input.storyKey ? { story_key: key(input.storyKey as Hex) } : {}),
    },
    expires: EXPIRY.takedown(),
    flags: { readonly: true, permissionlessExtension: true },
  });
  return { entityKey: created.entityKey, txHash: created.txHash };
}

export async function createDraft(input: { title: string; body: string }) {
  const created = await walletClient().createEntity({
    payload: jsonToPayload(input),
    contentType: "application/json",
    attributes: {
      app: str(APP),
      type: str("draft"),
      created_at_ms: u64(BigInt(Date.now())),
    },
    expires: EXPIRY.draft(),
  });
  return { entityKey: created.entityKey, txHash: created.txHash };
}

export async function extendStory(entityKey: string) {
  const { txHash, expiresAt } = await walletClient().extendEntity({
    entityKey: entityKey as Hex,
    expires: EXPIRY.story(),
  });
  return { txHash, expiresAt: expiresAt.toString() };
}

export async function queryTips(storyKey: string) {
  const page = await queryEntities({
    type: "tip",
    extra: [{ op: "eq", name: "story_key", kind: "key", value: storyKey }],
    limit: 200,
  });
  let total = 0n;
  for (const e of page.entities) {
    const v = (e.attributes as Record<string, { value: string }>)?.amount_wei?.value;
    if (v) total += BigInt(v);
  }
  return { ...page, totalWei: total.toString() };
}

export async function findCaptureByRoot(root: string) {
  const page = await queryEntities({
    type: "capture",
    extra: [{ op: "eq", name: "chain_root", kind: "bytes32", value: root }],
    limit: 5,
  });
  return page.entities[0] ?? null;
}

export async function hashFile(
  bytesB64: string,
  timestampMs: number,
  district = "",
  geoCell = "",
) {
  const bin = Uint8Array.from(atob(bytesB64), (c) => c.charCodeAt(0));
  return hashSingleFile(bin, timestampMs, district, geoCell);
}

export async function hashFrames(
  frames: { bytesB64: string; timestampMs: number }[],
  fps: number,
  district = "",
  geoCell = "",
) {
  const samples: FrameSample[] = frames.map((f) => ({
    bytes: Uint8Array.from(atob(f.bytesB64), (c) => c.charCodeAt(0)),
    timestampMs: f.timestampMs,
  }));
  return hashChain(samples, fps, district, geoCell);
}

/** Coarse district + 0.1° cell. Never returns raw lat/lng. */
export async function geoStamp(): Promise<{
  district: string;
  state: string;
  geo_cell: string;
  selfDeclared: boolean;
  source: string;
}> {
  const nav = (globalThis as { navigator?: { geolocation?: Geolocation } }).navigator;
  if (!nav?.geolocation) {
    return { district: "", state: "", geo_cell: "", selfDeclared: true, source: "unavailable" };
  }
  const pos = await new Promise<GeolocationPosition>((resolve, reject) => {
    nav.geolocation!.getCurrentPosition(resolve, reject, {
      enableHighAccuracy: false,
      timeout: 8000,
      maximumAge: 60_000,
    });
  });
  const lat = pos.coords.latitude;
  const lng = pos.coords.longitude;
  const cell = `${(Math.round(lat * 10) / 10).toFixed(1)},${(Math.round(lng * 10) / 10).toFixed(1)}`;
  const districts: Array<{ name: string; state: string; lat: number; lng: number }> = [
    { name: "Pune", state: "Maharashtra", lat: 18.5204, lng: 73.8567 },
    { name: "Mumbai", state: "Maharashtra", lat: 19.076, lng: 72.8777 },
    { name: "Central Delhi", state: "Delhi", lat: 28.6448, lng: 77.2167 },
    { name: "Chennai", state: "Tamil Nadu", lat: 13.0827, lng: 80.2707 },
    { name: "Bengaluru Urban", state: "Karnataka", lat: 12.9716, lng: 77.5946 },
    { name: "Hyderabad", state: "Telangana", lat: 17.385, lng: 78.4867 },
    { name: "Kolkata", state: "West Bengal", lat: 22.5726, lng: 88.3639 },
    { name: "Guwahati", state: "Assam", lat: 26.1445, lng: 91.7362 },
    { name: "Imphal West", state: "Manipur", lat: 24.817, lng: 93.9368 },
    { name: "Ranchi", state: "Jharkhand", lat: 23.3441, lng: 85.3096 },
    { name: "Ahmedabad", state: "Gujarat", lat: 23.0225, lng: 72.5714 },
  ];
  let best = districts[0];
  let bestD = Infinity;
  for (const d of districts) {
    const dy = d.lat - lat;
    const dx = (d.lng - lng) * 0.8;
    const dist = dy * dy + dx * dx;
    if (dist < bestD) {
      bestD = dist;
      best = d;
    }
  }
  return {
    district: best.name,
    state: best.state,
    geo_cell: cell,
    selfDeclared: false,
    source: "gps-coarse",
  };
}

const WINDOW_MS = 30 * 60 * 1000;

export async function queryCapturesInWindow(district: string, tsMs: number) {
  const from = tsMs - WINDOW_MS;
  const to = tsMs + WINDOW_MS;
  return queryEntities({
    type: "capture",
    extra: [
      { op: "eq", name: "district", kind: "str", value: district },
      { op: "gte", name: "capture_ts_ms", kind: "u64", value: from },
      { op: "lte", name: "capture_ts_ms", kind: "u64", value: to },
    ],
    limit: 100,
  });
}

export async function createCorroboration(input: {
  district: string;
  geoCell?: string;
  windowStartMs: number;
  windowEndMs: number;
  witnessCount: number;
  storyKey?: string;
  storyKeys?: string[];
  captureKeys?: string[];
  nids?: string[];
}) {
  const created = await walletClient().createEntity({
    payload: jsonToPayload({
      story_keys: input.storyKeys ?? [],
      capture_keys: input.captureKeys ?? [],
      nids: input.nids ?? [],
      synthetic: true,
    }),
    contentType: "application/json",
    attributes: {
      app: str(APP),
      type: str("corroboration"),
      district: str(input.district),
      ...(input.geoCell ? { geo_cell: str(input.geoCell) } : {}),
      window_start_ms: u64(BigInt(input.windowStartMs)),
      window_end_ms: u64(BigInt(input.windowEndMs)),
      witness_count: i32(input.witnessCount),
      created_at_ms: u64(BigInt(Date.now())),
      ...(input.storyKey ? { story_key: key(input.storyKey as Hex) } : {}),
    },
    expires: EXPIRY.corroboration(),
    flags: { readonly: true, permissionlessExtension: true },
  });
  return { entityKey: created.entityKey, txHash: created.txHash };
}

export function watchFeed(callbackName?: string) {
  unwatch?.();
  const ws = publicWs();
  unwatch = ws.watchEntityEvents({
    onEntityCreated: (ev) => {
      const payload = JSON.stringify({
        type: ev.type,
        entityKey: ev.entityKey,
        owner: ev.owner,
        blockNumber: ev.blockNumber.toString(),
        transactionHash: ev.transactionHash,
      });
      const w = globalThis as unknown as {
        SwatantraOnEvent?: (s: string) => void;
        flutter_inappwebview?: { callHandler?: (n: string, s: string) => void };
      };
      w.SwatantraOnEvent?.(payload);
      if (callbackName && typeof (globalThis as Record<string, unknown>)[callbackName] === "function") {
        (globalThis as Record<string, (s: string) => void>)[callbackName](payload);
      }
    },
    onError: (err) => console.warn("watchEntityEvents", err),
  });
  return { watching: true };
}

export function stopWatch() {
  unwatch?.();
  unwatch = undefined;
}

const methods: Record<string, (args: Record<string, unknown>) => Promise<unknown> | unknown> = {
  queryStories: (a) => queryStories(a),
  queryEntities: (a) => queryEntities(a as Parameters<typeof queryEntities>[0]),
  getEntity: (a) => getEntity(String(a.entityKey ?? a.key)),
  createBurner: () => createBurner(),
  unlock: (a) => unlock(String(a.privateKey)),
  getAddress: () => getAddress(),
  getBalance: () => getBalance(),
  connectInjected: () => connectInjected(),
  connectWalletConnect: (a) => connectWalletConnect(a.projectId != null ? String(a.projectId) : undefined),
  verifyJournalist: (a) => verifyJournalist(String(a.qrData ?? ""), a.state as string | undefined),
  findJournalistByNullifier: (a) => findJournalistByNullifier(String(a.nullifier)),
  createJournalist: (a) => createJournalist(a as Parameters<typeof createJournalist>[0]),
  createStory: (a) => createStory(a as Parameters<typeof createStory>[0]),
  createCapture: (a) => createCapture(a as Parameters<typeof createCapture>[0]),
  publishStoryWithCapture: (a) =>
    publishStoryWithCapture(a as Parameters<typeof publishStoryWithCapture>[0]),
  createTip: (a) => createTip(a as Parameters<typeof createTip>[0]),
  createTakedown: (a) => createTakedown(a as Parameters<typeof createTakedown>[0]),
  createDraft: (a) => createDraft(a as Parameters<typeof createDraft>[0]),
  extendStory: (a) => extendStory(String(a.entityKey)),
  queryTips: (a) => queryTips(String(a.storyKey)),
  findCaptureByRoot: (a) => findCaptureByRoot(String(a.root)),
  hashFile: (a) =>
    hashFile(String(a.bytesB64), Number(a.timestampMs), String(a.district ?? ""), String(a.geoCell ?? a.geo_cell ?? "")),
  hashFrames: (a) =>
    hashFrames(
      a.frames as { bytesB64: string; timestampMs: number }[],
      Number(a.fps ?? 1),
      String(a.district ?? ""),
      String(a.geoCell ?? a.geo_cell ?? ""),
    ),
  geoStamp: () => geoStamp(),
  queryCapturesInWindow: (a) =>
    queryCapturesInWindow(String(a.district), Number(a.tsMs ?? a.capture_ts_ms)),
  createCorroboration: (a) => createCorroboration(a as Parameters<typeof createCorroboration>[0]),
  watchFeed: () => watchFeed(),
  stopWatch: () => stopWatch(),
  setNetwork: (a) => applyNetwork(a.network != null ? String(a.network) : String(a.name ?? "")),
  getNetwork: () => {
    const n = getNetwork();
    return { name: n.name, rpc: n.rpc, ws: n.ws, explorer: n.explorer, chainId: n.chainId, local: isLocal() };
  },
};

export async function call(method: string, argsJson = "{}"): Promise<string> {
  const fn = methods[method];
  if (!fn) throw new Error(`unknown method ${method}`);
  const args = argsJson ? (JSON.parse(argsJson) as Record<string, unknown>) : {};
  const result = await fn(args);
  return JSON.stringify(result ?? null, (_k, v) => (typeof v === "bigint" ? v.toString() : v));
}

const api = {
  call,
  queryStories,
  queryEntities,
  getEntity,
  createBurner,
  unlock,
  getAddress,
  getBalance,
  connectInjected,
  connectWalletConnect,
  verifyJournalist,
  findJournalistByNullifier,
  createJournalist,
  createStory,
  createCapture,
  publishStoryWithCapture,
  createTip,
  createTakedown,
  createDraft,
  extendStory,
  queryTips,
  findCaptureByRoot,
  hashFile,
  hashFrames,
  geoStamp,
  queryCapturesInWindow,
  createCorroboration,
  watchFeed,
  stopWatch,
  setNetwork: applyNetwork,
  getNetwork,
  isLocal,
  APP,
  get RPC() {
    return RPC;
  },
  get EXPLORER() {
    return EXPLORER;
  },
  BUNDLED_TEST_QR,
};

export type SwatantraArkivApi = typeof api;
(globalThis as unknown as { SwatantraArkiv: typeof api }).SwatantraArkiv = api;
export default api;
