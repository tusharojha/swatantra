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
    journalist: "B",
    city: "New Delhi",
    state: "Delhi",
    district: "New Delhi",
    geoCell: "28.6,77.2",
    minutesAgo: 90,
    category: "protest",
    title: "Crowd held at the ITO barricades after the network dropped",
    body:
      "Phones fell to 2G around 11:20. The yellow police barricades were already across the carriageway; the sit-in behind them had been there for days.\n\n" +
      "Autorickshaws still ran on the open side. On the closed side, a tarpaulin line and a power-pylon. Nobody on this desk is named. The still is hashed on the phone; only the chain root is written.\n\n" +
      "Shop shutters on the far pavement were down. A few people stood well back of the fence. Data did not come back while this desk was there.\n\n" +
      "Platforms bury this as “unverified crowd footage”. The protected link is a query, not a tweet.",
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
    title: "Same underpass, from the shop-row — water at the lintel",
    body:
      "From the first-floor terrace the water was a sheet down the shop-row. Shutters stayed down. Wires hung in the brown water.\n\n" +
      "This is the second independent capture of the Sinhagad Road underpass this morning, same 0.1° cell, a different nullifier. No pump had arrived on this side either.\n\n" +
      "A parked two-wheeler was already gone under. The bus-stand roof was the only dry edge.\n\n" +
      "Three desks in one window is the corroboration. None of them named.",
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
    title: "Water through the gate at the underpass mouth",
    body:
      "The compound gate was a weir. Water came through at chest height and turned in the road. No one was in the frame on purpose.\n\n" +
      "A second desk, a second chain root, twelve minutes from the first still, still Pune district, still 18.5,73.9. The municipal tanker that residents said was “on the way” had not shown.\n\n" +
      "Palm and mango over the wall. The span of the underpass itself was not visible from this mouth — only the outflow.\n\n" +
      "Ground copy like this is the first thing that disappears from a feed. The hash stays on the device.",
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
    title: "Sinhagad Road underpass still chest-deep after the rain",
    body:
      "Autos turned back at the mouth. A motorcycle was already half under. Overnight rain had nowhere to go but the underpass.\n\n" +
      "This is the third independent capture within twenty minutes — Pune district, same 0.1° cell, a third nullifier. The pump had not arrived. Hazard lights on a stalled four-wheeler sat under the span, out of this frame.\n\n" +
      "Two-wheelers that tried the service road threw a wake and came back. Shopkeepers on the approach had put generators on crates.\n\n" +
      "Corroborated by three desks. None of them named. Media stays off Arkiv; the chain root does not.",
  },
  {
    file: "s5.jpg",
    journalist: "A",
    city: "Mandi",
    state: "Himachal Pradesh",
    district: "Mandi",
    geoCell: "31.7,76.9",
    minutesAgo: 6 * 60,
    category: "civic",
    title: "Slide over the Mandi–Kullu highway after the overnight rain",
    body:
      "Red earth and root-mat over the tarmac. The hill had come down onto the carriageway sometime after 2am. One lane was a wall of soil.\n\n" +
      "Trucks were already stacked on the shoulder a kilometre back. No faces in this still — the cut, the road edge, the moss on the remaining tree.\n\n" +
      "A JCB was said to be coming from Pandoh. At 7:40 it had not. Local buses had turned around.\n\n" +
      "Hill-road slides are taken down as “old video”. The capture is time-stamped and district-bound.",
  },
  {
    file: "s6.jpg",
    journalist: "B",
    city: "Bengaluru",
    state: "Karnataka",
    district: "Bengaluru Urban",
    geoCell: "13.0,77.6",
    minutesAgo: 14 * 60,
    category: "labour",
    title: "Delivery bikes parked out a dark kitchen in Marathahalli",
    body:
      "A row of two-wheelers, top-boxes still on, engines off. The kitchen behind them had gone dark around 9pm. No orders on the screen, riders said; they would not go on record.\n\n" +
      "This desk stood on the far pavement. The still is the parked line, not a face. Insulated bags sat on a few of the racks.\n\n" +
      "A strike call had gone out on the riders’ groups after another round of pay cuts. The platform app still showed “high demand”.\n\n" +
      "Labour footage is the first thing labelled “misleading”. The chain root is the record.",
  },
  {
    file: "s7.jpg",
    journalist: "A",
    city: "Yavatmal",
    state: "Maharashtra",
    district: "Yavatmal",
    geoCell: "20.4,78.1",
    minutesAgo: 20 * 60,
    category: "environment",
    title: "Unseasonal rain on the soy in Yavatmal — pods wet, soil a sheet",
    body:
      "The standing soy was still green this morning. The soil between the rows was a film of water. Last night’s rain was not in the forecast the mandi had been using.\n\n" +
      "No one is named. A blue tarp on the bund, a single tree, the field. Farmers on the next plot said the earlier sowing would lodge if the rain returned.\n\n" +
      "Vidarbha has had this twice in three seasons: a dry spell, then a dump that the crop cannot use. The district agriculture office had not put a loss survey on the board by noon.\n\n" +
      "Crop stills vanish as “not news”. District, cell, and time are on the chain.",
  },
  {
    file: "s8.jpg",
    journalist: "C",
    city: "Guwahati",
    state: "Assam",
    district: "Guwahati",
    geoCell: "26.1,91.7",
    minutesAgo: 28 * 60,
    category: "civic",
    title: "Dam release overnight — water over the fields at Palashbari",
    body:
      "From the air the Brahmaputra floodplain was a single sheet. Homesteads sat on the old levee like a spine. The release upstream had started after midnight.\n\n" +
      "Boats were already on the approach at Palashbari. This still has no faces — water, trees, the road that is now a causeway.\n\n" +
      "Relief camps from the last rise had not been folded. The district said the gates were opened because the reservoir had crossed the rule curve.\n\n" +
      "Flood video is labelled “last year”. The capture is this morning, this cell.",
  },
  {
    file: "s9.jpg",
    journalist: "B",
    city: "Ghaziabad",
    state: "Uttar Pradesh",
    district: "Ghaziabad",
    geoCell: "28.7,77.5",
    minutesAgo: 10 * 60,
    category: "environment",
    title: "Morning haze over the Ghaziabad flyover, AQI still maroon",
    body:
      "The sun was a white disc. From a terrace on the Ghaziabad side the NCR skyline was a set of blocks in brown air. Traffic on the flyover was a slow belt.\n\n" +
      "Schools had already gone online for the day. Construction tarpaulin on a tower two kilometres off was not visible. Nobody on this desk is named.\n\n" +
      "The public board at the metro still read “very poor”. Diesel gensets under the mall were running because the grid had dipped at dawn.\n\n" +
      "Air stills are called “seasonal”. The stamp is district and a 0.1° cell, not a weather meme.",
  },
  {
    file: "s10.jpg",
    journalist: "C",
    city: "Hyderabad",
    state: "Telangana",
    district: "Hyderabad",
    geoCell: "17.4,78.5",
    minutesAgo: 36 * 60,
    category: "civic",
    title: "Open pit on Old Mumbai Road — lights out, the slab gone",
    body:
      "Where the streetlight used to stand there is a hole. Rebar, a plastic bag, the broken cover. Last night the stretch was dark for four poles.\n\n" +
      "Two-wheelers were cutting around it. This still is the pit, not a face. Residents said they had called the ward office twice this week.\n\n" +
      "Potholes on the same kilometre were full of yesterday’s rain. No barricade, no cone.\n\n" +
      "Civic holes are “too local” until someone goes in. The chain is the date and the cell.",
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
      `Seeder ${seedAcc.address} has 0 GLM. Hub faucet always sends 10 GLM; the dispenser is often ~9.995. A 0.05 GLM top-up of this address is enough to seed. Fallback: ARKIV_NETWORK=local ./scripts/local-node.sh && npx tsx src/seed.ts`,
    );
  }

  // One funded seeder is enough: split GLM to journalist burners so $creator differs.
  // Writes are cheap; 0.05 GLM total covers three desks + the story/capture batch.
  unlock(seedKey);
  const hungry: { role: string; acc: ReturnType<typeof privateKeyToAccount> }[] = [];
  for (const [role, pk] of roles.slice(1)) {
    const acc = privateKeyToAccount(pk);
    const bal = await pub.getBalance({ address: acc.address });
    console.log(`${role}\t${acc.address}\t${formatEther(bal)} GLM`);
    if (bal < parseEther("0.008")) hungry.push({ role, acc });
  }
  if (hungry.length) {
    const have = await pub.getBalance({ address: seedAcc.address });
    const reserve = parseEther("0.008");
    if (have <= reserve) {
      throw new Error(`Seeder has ${formatEther(have)} GLM; need ≥0.05 GLM to top up ${hungry.length} desks.`);
    }
    const share = (have - reserve) / BigInt(hungry.length);
    if (share < parseEther("0.008")) {
      throw new Error(`Seeder has ${formatEther(have)} GLM; each desk would only get ${formatEther(share)}.`);
    }
    for (const h of hungry) {
      const tx = await walletClient().sendTransaction({ to: h.acc.address, value: share });
      await pub.waitForTransactionReceipt({ hash: tx });
      console.log(`  topped up ${h.acc.address} with ${formatEther(share)} GLM  ${EXPLORER}/tx/${tx}`);
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

  // A couple of tips. Keep amounts small so gas + value fit remaining seeder GLM.
  unlock(seedKey);
  const first = storyKeys[0];
  const second = storyKeys[1];
  const tipKeys: string[] = [];
  try {
    const remaining = await pub.getBalance({ address: seedAcc.address });
    const tipperPk = remaining > parseEther("0.005") ? seedKey : keys.A;
    unlock(tipperPk);
    const t1 = await createTip({
      storyKey: first.key,
      to: journalists[STORIES[0].journalist].address,
      amountEth: "0.001",
      note: "Reader tip — keep this desk reporting",
    });
    console.log("tip1", t1);
    if (t1.entityKey) tipKeys.push(t1.entityKey);
    const t2 = await createTip({
      storyKey: second.key,
      to: journalists[STORIES[1].journalist].address,
      amountEth: "0.001",
      note: "Reader tip — Pune underpass cluster",
    });
    console.log("tip2", t2);
    if (t2.entityKey) tipKeys.push(t2.entityKey);
  } catch (e) {
    console.warn("tips failed (fund seeder?)", e);
  }

  unlock(keys.B);
  const td = await createTakedown({
    platform: "X",
    dateMs: Date.parse("2026-09-15T00:00:00Z"),
    lawCited: "IT Act s.79",
    authorityNamed: false,
    storyKey: second.key,
    notes:
      "X removed the ITO barricade still within two hours of posting. The protected link still resolves the entity.",
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
    tips: tipKeys,
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
