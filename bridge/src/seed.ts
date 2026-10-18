/**
 * Seed synthetic journalists, stories, captures, tips and takedowns.
 *
 * Usage:
 *   ARKIV_NETWORK=tiramisu SEED_PRIVATE_KEY=0x... npx tsx src/seed.ts
 *   ARKIV_NETWORK=local                         npx tsx src/seed.ts
 *
 * Keys are read from the environment only. Never written to the repo.
 * Local uses the geth --dev coinbase to fund burners, then writes
 * arkiv/seed-result.local.json. Tiramisu writes arkiv/seed-result.json.
 */
import { writeFileSync } from "node:fs";
import { formatEther, parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import {
  APP,
  EXPLORER,
  unlock,
  walletClient,
  publicClient,
  createJournalist,
  createStory,
  createCapture,
  createTip,
  createTakedown,
  createCorroboration,
  verifyJournalist,
  queryStories,
  applyNetwork,
  isLocal,
  LOCAL_DEV_KEY,
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
    title: "King tide over the jetty steps, western suburbs",
    body:
      "By 6:40am the water was already over the first step of the jetty. " +
      "Shopkeepers on the approach road had moved generators onto crates. " +
      "A municipal pump truck arrived, then left: the driver said the outfall was blocked with plastic.\n\n" +
      "This is the kind of civic footage that is routinely taken down as “out of context”. " +
      "The still is hashed in-app; only the chain root sits on Arkiv.",
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
    title: "Burst main, south kerb of FC Road",
    body:
      "Water over the road in a sheet. Bikes had been pushed onto the divider. " +
      "Shop awnings dripped onto a lane that was no longer a lane.\n\n" +
      "Three desks sampled the same Pune junction within twenty minutes — that is the corroboration. " +
      "Independent witnesses, same district, same 0.1° cell.",
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
    title: "Same flood, from the west flyover",
    body:
      "From the flyover the water made a sheet as far as the bus depot. " +
      "A second capture, a second nullifier, the same district cell, twelve minutes from the first still.\n\n" +
      "No one on this desk is named. The byline is a verified journalist entity.",
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
    title: "Water still over the kerb at FC Road",
    body:
      "A third journalist, a third chain root, still Pune district, still the same 0.1° cell. " +
      "Autos had given up the inner lane. The pump had not arrived.\n\n" +
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
    title: "Night shift waiting on a coal siding",
    body:
      "Headlamps, a whistle, a wagon that did not move for forty minutes. " +
      "Sodium lamps on gravel. Nobody here is identified.\n\n" +
      "The journalist entity is a test-mode Anon Aadhaar nullifier. The capture is a still hashed on device.",
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
    title: "Trucks on the NH-2 shoulder, engines off",
    body:
      "A line of trucks on the shoulder, engines off to save fuel. " +
      "Hills behind the tarmac, late light.\n\n" +
      "Ground copy like this is the first thing platforms bury. The protected link is a query, not a tweet.",
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
    title: "Riders outside a dark kitchen in Gachibowli",
    body:
      "Riders sat on their bikes outside a dark cloud kitchen. Insulated bags, screens still open, no orders.\n\n" +
      "Tips on this story are Tiramisu test GLM only.",
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
    title: "Knee-deep at the Howrah flyover mouth",
    body:
      "Knee-deep water at a flyover mouth, one pump, two men in reflective vests. " +
      "The protected link should still resolve from Arkiv after a hypothetical takedown.",
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
  applyNetwork(process.env.ARKIV_NETWORK);
  const local = isLocal();
  console.log(`network=${local ? "local" : "tiramisu"} rpc=${(await import("./network")).getNetwork().rpc}`);

  const seedKey = (process.env.SEED_PRIVATE_KEY && process.env.SEED_PRIVATE_KEY.startsWith("0x")
    ? process.env.SEED_PRIVATE_KEY
    : local
      ? LOCAL_DEV_KEY
      : mustKey("SEED_PRIVATE_KEY")) as `0x${string}`;
  const keys = {
    A: process.env.JOURNALIST_A_KEY as `0x${string}` | undefined,
    B: process.env.JOURNALIST_B_KEY as `0x${string}` | undefined,
    C: process.env.JOURNALIST_C_KEY as `0x${string}` | undefined,
  };
  if (!keys.A || !keys.B || !keys.C) {
    throw new Error("JOURNALIST_A_KEY, JOURNALIST_B_KEY, JOURNALIST_C_KEY required");
  }

  const pub = publicClient();
  const roles = [
    ["seeder/reader", seedKey],
    ["journalist-A (Maharashtra, synthetic)", keys.A],
    ["journalist-B (Delhi, synthetic)", keys.B],
    ["journalist-C (Northeast, synthetic)", keys.C],
  ] as const;

  console.log("=== wallets (addresses only) ===");
  const seedAcc = privateKeyToAccount(seedKey);
  let seedBal = await pub.getBalance({ address: seedAcc.address });
  console.log(`seeder/reader\t${seedAcc.address}\t${formatEther(seedBal)} ${local ? "ETH" : "GLM"}`);
  if (local && seedBal === 0n) {
    const faucet = privateKeyToAccount(LOCAL_DEV_KEY);
    const faucetBal = await pub.getBalance({ address: faucet.address });
    console.log(`local --dev coinbase\t${faucet.address}\t${formatEther(faucetBal)}`);
    if (faucetBal === 0n) {
      throw new Error("Local node coinbase has 0. Is geth --dev running on :8545?");
    }
    unlock(LOCAL_DEV_KEY);
    const tx = await walletClient().sendTransaction({ to: seedAcc.address, value: parseEther("50") });
    await pub.waitForTransactionReceipt({ hash: tx });
    seedBal = await pub.getBalance({ address: seedAcc.address });
    console.log(`funded seeder from --dev coinbase  ${formatEther(seedBal)}`);
  }
  if (seedBal === 0n) {
    throw new Error(
      `Seeder ${seedAcc.address} has 0 GLM. Hub faucet always sends 10 GLM; the dispenser is often ~9.995. A 0.2 GLM top-up of this address is enough to seed. Fallback: ARKIV_NETWORK=local ./scripts/local-node.sh && npx tsx src/seed.ts`,
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
    A: { displayName: "Desk MH-A", state: "Maharashtra", bio: "Civic desk. Anon byline." },
    B: { displayName: "Desk DL-B", state: "Delhi", bio: "Ground desk. Anon byline." },
    C: { displayName: "Desk ML-C", state: "Meghalaya", bio: "Northeast desk. Anon byline." },
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
  const outName = local ? "seed-result.local.json" : "seed-result.json";
  const payload = {
    ...out,
    network: local ? "local" : "tiramisu",
    chainId: local ? 1337 : 7738577,
  };
  writeFileSync(resolve(import.meta.dirname, `../../arkiv/${outName}`), JSON.stringify(payload, null, 2));
  console.log(`wrote arkiv/${outName}`);
  console.log(JSON.stringify(payload, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
