/**
 * Seed synthetic journalists, stories, captures, tips and takedowns on Tiramisu.
 *
 * Usage:
 *   SEED_PRIVATE_KEY=0x... JOURNALIST_A_KEY=0x... npx tsx src/seed.ts
 *
 * Keys are read from the environment only. Never written to the repo.
 */
import { writeFileSync } from "node:fs";
import { createPublicClient } from "@arkiv-network/sdk";
import { tiramisu } from "@arkiv-network/sdk/chains";
import { http, formatEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import {
  APP,
  RPC,
  EXPLORER,
  unlock,
  createJournalist,
  createStory,
  createCapture,
  createTip,
  createTakedown,
  verifyJournalist,
  queryStories,
} from "./index";
import { hashSingleFile } from "./hash";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const SEED_DIR = resolve(import.meta.dirname, "../../app/web/seed");

type StorySeed = {
  file: string;
  title: string;
  body: string;
  city: string;
  state: string;
  category: string;
  journalist: "A" | "B" | "C";
};

const STORIES: StorySeed[] = [
  {
    file: "s1.jpg",
    journalist: "A",
    city: "Mumbai",
    state: "Maharashtra",
    category: "civic",
    title: "King tide at a western suburb jetty, 12 Oct 2026 (synthetic)",
    body:
      "SYNTHETIC DISPATCH — none of the people named here are real.\n\n" +
      "By 6:40am the water was already over the first step of the jetty. " +
      "Shopkeepers on the approach road had moved generators onto crates. " +
      "A municipal pump truck arrived, then left: the driver said the outfall was blocked with plastic.\n\n" +
      "This is a fictional ground report written for the Swatantra demo. " +
      "It stands in for the kind of civic footage that is routinely taken down as 'out of context'.",
  },
  {
    file: "s2.jpg",
    journalist: "B",
    city: "Delhi",
    state: "Delhi",
    category: "protest",
    title: "Phones on SOS after 9pm near ITO, 10 Oct 2026 (synthetic)",
    body:
      "SYNTHETIC DISPATCH — fictional names, composite scene.\n\n" +
      "Around 21:10, four of five handsets in a small press huddle showed SOS-only. " +
      "A printed order was not produced. A traffic constable shrugged and pointed at the sky.\n\n" +
      "This story exists so a reader can still open a protected Arkiv link if a platform later removes a similar post.",
  },
  {
    file: "s3.jpg",
    journalist: "A",
    city: "Chennai",
    state: "Tamil Nadu",
    category: "environment",
    title: "Ennore creek after overnight rain — sludge line (synthetic)",
    body:
      "SYNTHETIC DISPATCH.\n\n" +
      "A grey line of sludge sat on the mangrove edge at first light. " +
      "Fisherfolk (composite, unnamed) said the smell was diesel and tannery, not tide.\n\n" +
      "Capture proof is a SHA-256 chain of the demo still, not a claim about a real creek that morning.",
  },
  {
    file: "s4.jpg",
    journalist: "C",
    city: "Guwahati",
    state: "Assam",
    category: "environment",
    title: "Sandbags on a Brahmaputra ghat, October 2026 (synthetic)",
    body:
      "SYNTHETIC DISPATCH.\n\n" +
      "Sandbags two-high along a ghat that is usually a tea stall. " +
      "The stall owner in this copy is fictional. The point is the hash: the still can be checked against Arkiv.",
  },
  {
    file: "s5.jpg",
    journalist: "A",
    city: "Ranchi",
    state: "Jharkhand",
    category: "labour",
    title: "Night shift at a coal siding off Hazaribagh road (synthetic)",
    body:
      "SYNTHETIC DISPATCH.\n\n" +
      "Headlamps, a whistle, a wagon that did not move for forty minutes. " +
      "No real worker is identified. The journalist entity is a test-mode Anon Aadhaar nullifier.",
  },
  {
    file: "s6.jpg",
    journalist: "C",
    city: "Imphal",
    state: "Manipur",
    category: "civic",
    title: "NH-2 convoy wait, none of the names are real (synthetic)",
    body:
      "SYNTHETIC DISPATCH.\n\n" +
      "A line of trucks on the shoulder, engines off to save fuel. " +
      "This is not a report of a specific day's blockade. It is a placeholder for ground copy that platforms bury.",
  },
  {
    file: "s7.jpg",
    journalist: "B",
    city: "Hyderabad",
    state: "Telangana",
    category: "labour",
    title: "Gig kitchen riders after a platform outage, Gachibowli (synthetic)",
    body:
      "SYNTHETIC DISPATCH.\n\n" +
      "Riders sat on their bikes outside a dark cloud kitchen. " +
      "The app status in this copy is invented. Tips on this story are Tiramisu test GLM only.",
  },
  {
    file: "s8.jpg",
    journalist: "B",
    city: "Kolkata",
    state: "West Bengal",
    category: "civic",
    title: "Howrah approach waterlogging, municipal pump (synthetic)",
    body:
      "SYNTHETIC DISPATCH.\n\n" +
      "Knee-deep water at a flyover mouth, one pump, two men in reflective vests. " +
      "Fictional. The protected link should still resolve from Arkiv after a hypothetical takedown.",
  },
];

function mustKey(name: string): `0x${string}` {
  const v = process.env[name];
  if (!v || !v.startsWith("0x") || v.length < 66) {
    throw new Error(`Missing ${name}. Set it in the environment (never commit it).`);
  }
  return v as `0x${string}`;
}

async function main() {
  const started = Date.now();
  const seedKey = mustKey("SEED_PRIVATE_KEY");
  const keys = {
    A: process.env.JOURNALIST_A_KEY as `0x${string}` | undefined,
    B: process.env.JOURNALIST_B_KEY as `0x${string}` | undefined,
    C: process.env.JOURNALIST_C_KEY as `0x${string}` | undefined,
  };
  if (!keys.A || !keys.B || !keys.C) {
    throw new Error("JOURNALIST_A_KEY, JOURNALIST_B_KEY, JOURNALIST_C_KEY required");
  }

  const pub = createPublicClient({ chain: tiramisu, transport: http(RPC) });
  const roles = [
    ["seeder/reader", seedKey],
    ["journalist-A (Maharashtra, synthetic)", keys.A],
    ["journalist-B (Delhi, synthetic)", keys.B],
    ["journalist-C (Northeast, synthetic)", keys.C],
  ] as const;

  console.log("=== wallets (addresses only) ===");
  for (const [role, pk] of roles) {
    const acc = privateKeyToAccount(pk);
    const bal = await pub.getBalance({ address: acc.address });
    console.log(`${role}\t${acc.address}\t${formatEther(bal)} GLM`);
    if (bal === 0n) {
      console.warn(`  UNFUNDED — claim at https://hub.arkiv.network/faucet for ${acc.address}`);
    }
  }

  const journalists: Record<string, { key: string; address: string }> = {};
  const names = {
    A: { displayName: "Kiran M. (synthetic)", state: "Maharashtra", bio: "Civic reporter. Fictional byline." },
    B: { displayName: "R. Devi (synthetic)", state: "Delhi", bio: "Ground reporter. Fictional byline." },
    C: { displayName: "T. Sangma (synthetic)", state: "Meghalaya", bio: "Northeast desk. Fictional byline." },
  } as const;

  for (const id of ["A", "B", "C"] as const) {
    unlock(keys[id]);
    const qr = `TEST-${id}-SWATANTRA-SYNTHETIC-NOT-AADHAAR-${id.repeat(24)}`;
    const proof = await verifyJournalist(qr, names[id].state);
    const j = await createJournalist({
      nullifier: proof.nullifier,
      state: names[id].state,
      displayName: names[id].displayName,
      bio: names[id].bio,
    });
    const acc = privateKeyToAccount(keys[id]);
    const entityKey = "entityKey" in j && j.entityKey ? j.entityKey : (j.entity as { key: string }).key;
    journalists[id] = { key: entityKey as string, address: acc.address };
    console.log(`journalist ${id}`, j);
  }

  const storyKeys: { title: string; key: string; capture?: string; city: string }[] = [];
  const pagesBase = "https://tusharojha.github.io/swatantra/seed";

  for (const s of STORIES) {
    unlock(keys[s.journalist]);
    const bytes = new Uint8Array(readFileSync(resolve(SEED_DIR, s.file)));
    const ts = Date.now() - Math.floor(Math.random() * 86_400_000);
    const chain = await hashSingleFile(bytes, ts);
    const cap = await createCapture({
      root: chain.root,
      frameCount: chain.frameCount,
      fps: 1,
      startMs: chain.startMs,
      endMs: chain.endMs,
      city: s.city,
      mediaUrl: `${pagesBase}/${s.file}`,
    });
    const story = await createStory({
      title: s.title,
      body: s.body,
      city: s.city,
      state: s.state,
      category: s.category,
      mediaUrl: `${pagesBase}/${s.file}`,
      mediaHash: chain.frameHashes[0],
      captureKey: cap.entityKey,
      captureRoot: chain.root,
      journalistKey: journalists[s.journalist].key,
    });
    storyKeys.push({ title: s.title, key: story.entityKey, capture: cap.entityKey, city: s.city });
    console.log("story", s.city, story.entityKey, story.txHash);
  }

  // A couple of tips from the seeder (testnet GLM).
  unlock(seedKey);
  const first = storyKeys[0];
  const second = storyKeys[1];
  try {
    const t1 = await createTip({
      storyKey: first.key,
      to: journalists[STORIES[0].journalist].address,
      amountEth: "0.01",
      note: "testnet GLM tip — synthetic",
    });
    console.log("tip1", t1);
    const t2 = await createTip({
      storyKey: second.key,
      to: journalists[STORIES[1].journalist].address,
      amountEth: "0.02",
      note: "testnet GLM tip — synthetic",
    });
    console.log("tip2", t2);
  } catch (e) {
    console.warn("tips failed (fund seeder?)", e);
  }

  unlock(keys.B);
  const td = await createTakedown({
    platform: "X",
    dateMs: Date.parse("2026-09-15T00:00:00Z"),
    lawCited: "IT Act s.79 (synthetic citation)",
    authorityNamed: false,
    storyKey: second.key,
    notes: "Synthetic takedown log for the demo tracker. Not a real notice.",
  });
  console.log("takedown", td);

  const feed = await queryStories({});
  const out = {
    app: APP,
    explorer: EXPLORER,
    seededAt: new Date().toISOString(),
    elapsedMs: Date.now() - started,
    journalists,
    stories: storyKeys,
    feedCount: feed.entities.length,
    takedown: td.entityKey,
  };
  writeFileSync(resolve(import.meta.dirname, "../../arkiv/seed-result.json"), JSON.stringify(out, null, 2));
  console.log("wrote arkiv/seed-result.json");
  console.log(JSON.stringify(out, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
