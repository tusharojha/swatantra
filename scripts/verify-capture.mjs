#!/usr/bin/env node
/**
 * Recompute a 1-frame capture chain the same way the app does
 * (`app/lib/arkiv/hash.dart`, `bridge/src/hash.ts`).
 *
 *   h_0     = 32 zero bytes
 *   place   = sha256( utf8(district) || 0x00 || utf8(geo_cell) )
 *   frame   = sha256(file bytes)
 *   h_1     = sha256( h_0 || frame || uint64be(start_ms) || place )
 *
 * geo_cell is lat,lng rounded to 0.1° (e.g. 19.1,72.9). Precise GPS is never hashed.
 */
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";

const file = process.argv[2];
const ts = Number(process.argv[3] || 0);
const district = process.argv[4] ?? "";
const geoCell = process.argv[5] ?? "";
if (!file || !ts) {
  console.error("usage: node scripts/verify-capture.mjs <jpeg> <start_ms> <district> <geo_cell>");
  console.error(" e.g.: node scripts/verify-capture.mjs app/web/seed/s4.jpg 1700000000000 Pune 18.5,73.9");
  process.exit(1);
}

function sha256(data) {
  return createHash("sha256").update(data).digest();
}

function u64be(n) {
  const out = Buffer.alloc(8);
  out.writeBigUInt64BE(BigInt(n));
  return out;
}

const bytes = readFileSync(file);
const frame = sha256(bytes);
const place = sha256(Buffer.concat([Buffer.from(district, "utf8"), Buffer.from([0]), Buffer.from(geoCell, "utf8")]));
const cat = Buffer.concat([Buffer.alloc(32), frame, u64be(ts), place]);
if (cat.length !== 104) {
  console.error(`internal: concat length ${cat.length}, expected 104`);
  process.exit(1);
}
const root = "0x" + sha256(cat).toString("hex");
console.log(
  JSON.stringify(
    {
      file,
      start_ms: ts,
      district,
      geo_cell: geoCell,
      frameHash: "0x" + frame.toString("hex"),
      placeHash: "0x" + place.toString("hex"),
      root,
    },
    null,
    2,
  ),
);
