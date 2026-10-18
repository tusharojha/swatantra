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
import { http, formatEther, parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import {
  APP,
  RPC,
  EXPLORER,
  unlock,
  walletClient,
  createJournalist,
  createStory,
  createCapture,
  createTip,
  createTakedown,
  createCorroboration,
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
  district: string;
  geoCell: string;
  minutesAgo: number;
};

const STORIES: StorySeed[] = [
  {
    file: "s1.jpg",
    journalist: "A",
    city: "Mumbai",
    state: "Maharashtra",
    district: "Mumbai",
    geoCell: "19.1,72.9",
    minutesAgo: 180,
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
    city: "Pune",
    state: "Maharashtra",
    district: "Pune",
    geoCell: "18.5,73.9",
    minutesAgo: 15,
    category: "civic",
    title: "FC Road after a burst main, from the south kerb (synthetic)",
    body:
      "SYNTHETIC DISPATCH — fictional names, composite scene.\n\n" +
      "Water over the tramlines of memory: a burst main, bikes pushed onto the divider. " +
      "Three desks sampled the same Pune junction within twenty minutes — that is the corroboration.\n\n" +
      "Not a report of a specific pipe. The point is independent witnesses on Arkiv.",
  },
  {
    file: "s3.jpg",
    journalist: "A",
    city: "Pune",
    state: "Maharashtra",
    district: "Pune",
    geoCell: "18.5,73.9",
    minutesAgo: 22,
    category: "civic",
    title: "Same FC Road flood, west flyover (synthetic)",
    body:
      "SYNTHETIC DISPATCH.\n\n" +
      "From the flyover the water made a sheet as far as the bus depot. " +
      "A second capture, a second nullifier, the same district cell, twelve minutes from the first still.",
  },
  {
    file: "s4.jpg",
    journalist: "C",
    city: "Pune",
    state: "Maharashtra",
    district: "Pune",
    geoCell: "18.5,73.9",
    minutesAgo: 8,
    category: "civic",
    title: "Third desk, same Pune junction, eight minutes on (synthetic)",
    body:
      "SYNTHETIC DISPATCH.\n\n" +
      "A third journalist, a third chain root, still Pune district, still the same 0.1° cell. " +
      "Corroborated by 3 independent witnesses — none of them named.",
  },
  {
    file: "s5.jpg",
    journalist: "A",
    city: "Ranchi",
    state: "Jharkhand",
    district: "Ranchi",
    geoCell: "23.3,85.3",
    minutesAgo: 28 * 60,
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
    district: "Imphal West",
    geoCell: "24.8,93.9",
    minutesAgo: 36 * 60,
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
    district: "Hyderabad",
    geoCell: "17.4,78.5",
    minutesAgo: 44 * 60,
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
    district: "Howrah",
    geoCell: "22.6,88.3",
    minutesAgo: 52 * 60,
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
  const seedAcc = privateKeyToAccount(seedKey);
  const seedBal = await pub.getBalance({ address: seedAcc.address });
  console.log(`seeder/reader\t${seedAcc.address}\t${formatEther(seedBal)} GLM`);
  if (seedBal === 0n) {
    throw new Error(
      `Seeder ${seedAcc.address} has 0 GLM. Hub faucet always sends 10 GLM; the dispenser is often ~9.995. A 0.2 GLM top-up of this address is enough to seed.`,
    );
  }

  // One funded seeder is enough: split GLM to journalist burners so $creator differs.
  // Entity writes are cheap; 0.04 GLM each covers createJournalist + several stories.
  unlock(seedKey);
  const topUp = parseEther("0.04");
  for (const [role, pk] of roles.slice(1)) {
    const acc = privateKeyToAccount(pk);
    const bal = await pub.getBalance({ address: acc.address });
    console.log(`${role}\t${acc.address}\t${formatEther(bal)} GLM`);
    if (bal < parseEther("0.02")) {
      const have = await pub.getBalance({ address: seedAcc.address });
      if (have < topUp + parseEther("0.01")) {
        throw new Error(
          `Seeder has ${formatEther(have)} GLM; need ~0.04 more to top up ${acc.address}.`,
        );
      }
      const tx = await walletClient().sendTransaction({
        to: acc.address,
        value: topUp,
      });
      await pub.waitForTransactionReceipt({ hash: tx });
      console.log(`  topped up ${acc.address} with 0.04 GLM  ${EXPLORER}/tx/${tx}`);
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
    const ts = Date.now() - s.minutesAgo * 60_000;
    const chain = await hashSingleFile(bytes, ts, s.district, s.geoCell);
    const cap = await createCapture({
      root: chain.root,
      frameCount: chain.frameCount,
      fps: 1,
      startMs: chain.startMs,
      endMs: chain.endMs,
      city: s.city,
      mediaUrl: `${pagesBase}/${s.file}`,
      district: s.district,
      geoCell: s.geoCell,
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
      district: s.district,
      geoCell: s.geoCell,
      captureTsMs: ts,
    });
    storyKeys.push({ title: s.title, key: story.entityKey, capture: cap.entityKey, city: s.city });
    console.log("story", s.city, story.entityKey, story.txHash);
  }

  const pune = storyKeys.filter((s) => s.city === "Pune");
  let corroborationKey = "";
  if (pune.length >= 2) {
    unlock(keys.A);
    const now = Date.now();
    const cr = await createCorroboration({
      district: "Pune",
      geoCell: "18.5,73.9",
      windowStartMs: now - 30 * 60_000,
      windowEndMs: now + 5 * 60_000,
      witnessCount: 3,
      storyKey: pune[0].key,
      storyKeys: pune.map((s) => s.key),
      captureKeys: pune.map((s) => s.capture ?? ""),
    });
    corroborationKey = cr.entityKey;
    console.log("corroboration", cr);
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
    corroboration: corroborationKey,
  };
  writeFileSync(resolve(import.meta.dirname, "../../arkiv/seed-result.json"), JSON.stringify(out, null, 2));
  console.log("wrote arkiv/seed-result.json");
  console.log(JSON.stringify(out, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
