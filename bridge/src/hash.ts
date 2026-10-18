/**
 * In-app capture integrity chain (district-bound).
 *
 * h_0     = 32 zero bytes
 * place   = SHA-256( utf8(district) || 0x00 || utf8(geo_cell) )
 * frame_i = SHA-256(frame bytes)
 * h_i     = SHA-256( h_{i-1} || frame_i || uint64be(ts_ms) || place )
 * root    = h_n
 *
 * Precise GPS is never hashed or stored — only a district name and a 0.1° cell.
 */

export function toHex(bytes: Uint8Array): `0x${string}` {
  return `0x${[...bytes].map((b) => b.toString(16).padStart(2, "0")).join("")}` as `0x${string}`;
}

export function fromHex(hex: string): Uint8Array {
  const h = hex.startsWith("0x") ? hex.slice(2) : hex;
  const out = new Uint8Array(h.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(h.slice(i * 2, i * 2 + 2), 16);
  return out;
}

function u64be(n: number | bigint): Uint8Array {
  const v = BigInt(n);
  const out = new Uint8Array(8);
  let x = v;
  for (let i = 7; i >= 0; i--) {
    out[i] = Number(x & 0xffn);
    x >>= 8n;
  }
  return out;
}

export async function sha256(data: Uint8Array): Promise<Uint8Array> {
  const digest = await globalThis.crypto.subtle.digest("SHA-256", data as BufferSource);
  return new Uint8Array(digest);
}

export async function placeHash(district: string, geoCell: string): Promise<Uint8Array> {
  const enc = new TextEncoder();
  const a = enc.encode(district);
  const b = enc.encode(geoCell);
  const cat = new Uint8Array(a.length + 1 + b.length);
  cat.set(a, 0);
  cat[a.length] = 0;
  cat.set(b, a.length + 1);
  return sha256(cat);
}

export type FrameSample = { bytes: Uint8Array; timestampMs: number };

export type CaptureChain = {
  root: `0x${string}`;
  frameCount: number;
  fps: number;
  startMs: number;
  endMs: number;
  frameHashes: `0x${string}`[];
  district: string;
  geoCell: string;
};

export async function hashChain(
  frames: FrameSample[],
  fps: number,
  district = "",
  geoCell = "",
): Promise<CaptureChain> {
  if (frames.length === 0) throw new Error("need at least one sampled frame");
  const place = await placeHash(district, geoCell);
  let h = new Uint8Array(32);
  const frameHashes: `0x${string}`[] = [];
  for (const frame of frames) {
    const fh = await sha256(frame.bytes);
    frameHashes.push(toHex(fh));
    const cat = new Uint8Array(104);
    cat.set(h, 0);
    cat.set(fh, 32);
    cat.set(u64be(frame.timestampMs), 64);
    cat.set(place, 72);
    h = await sha256(cat);
  }
  return {
    root: toHex(h),
    frameCount: frames.length,
    fps,
    startMs: frames[0].timestampMs,
    endMs: frames[frames.length - 1].timestampMs,
    frameHashes,
    district,
    geoCell,
  };
}

export async function hashSingleFile(
  bytes: Uint8Array,
  timestampMs: number,
  district = "",
  geoCell = "",
): Promise<CaptureChain> {
  return hashChain([{ bytes, timestampMs }], 1, district, geoCell);
}
