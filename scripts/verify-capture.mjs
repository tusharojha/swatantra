#!/usr/bin/env node
/** Recompute a 1-frame capture chain the same way the app does. */
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";

const file = process.argv[2];
const ts = Number(process.argv[3] || 0);
if (!file || !ts) {
  console.error("usage: node scripts/verify-capture.mjs <jpeg> <start_ms>");
  process.exit(1);
}
const bytes = readFileSync(file);
const frame = createHash("sha256").update(bytes).digest();
const cat = Buffer.concat([Buffer.alloc(32), frame, Buffer.alloc(8)]);
cat.writeBigUInt64BE(BigInt(ts), 64);
const root = "0x" + createHash("sha256").update(cat).digest("hex");
console.log(JSON.stringify({ file, start_ms: ts, frameHash: "0x" + frame.toString("hex"), root }, null, 2));
