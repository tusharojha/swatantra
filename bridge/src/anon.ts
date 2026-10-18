/**
 * Anon Aadhaar TEST MODE verifier.
 *
 * Full Groth16 proving with @anon-aadhaar/core is too heavy to ship inside
 * Flutter in this hackathon window. Per the product brief we verify a
 * test-mode identity with a minimal verifier and label it everywhere.
 *
 * What this does:
 * - Accepts Anon Aadhaar-style test QR data (a long numeric string) OR the
 *   bundled synthetic test identity.
 * - Derives a pseudonymous nullifier = SHA-256("swatantra-aa-v1" || qr).
 * - Returns only { nullifier, indianResident, ageOver18, optional state }.
 * - NEVER stores Aadhaar numbers, names, photos, or the QR payload on Arkiv.
 *
 * One nullifier = one journalist entity. The app queries `nid` before create.
 *
 * Test QR generator: https://documentation.anon-aadhaar.pse.dev/docs/quick-setup
 * Official project: https://github.com/anon-aadhaar/anon-aadhaar
 */

import { sha256, toHex } from "./hash";

export const ANON_TEST_MODE = true;
export const NULLIFIER_SEED = "swatantra-aa-v1";

/** Published-style synthetic test QR. Not a real Aadhaar. Numeric only. */
export const BUNDLED_TEST_QR =
  "99999999999999999999999999999999999999999999999999999999999999999999" +
  "000018MHTESTMODEONLYSYNTHETIC00000000000000000000000000000000000000";

export type AnonResult = {
  ok: boolean;
  testMode: true;
  nullifier: `0x${string}`;
  indianResident: true;
  ageOver18: true;
  state?: string;
  note: string;
};

export async function verifyTestAnonAadhaar(
  qrData: string,
  revealState?: string,
): Promise<AnonResult> {
  const qr = (qrData || "").trim() || BUNDLED_TEST_QR;
  if (qr.length < 32) {
    throw new Error("test QR too short — paste Anon Aadhaar TEST QR data, or use the bundled test identity");
  }
  // Do not keep the QR. Hash it and drop the input.
  const material = new TextEncoder().encode(`${NULLIFIER_SEED}|${qr}`);
  const digest = await sha256(material);
  const nullifier = toHex(digest);
  return {
    ok: true,
    testMode: true,
    nullifier,
    indianResident: true,
    ageOver18: true,
    state: revealState && revealState.length > 0 ? revealState : undefined,
    note: "Anon Aadhaar TEST MODE. Nullifier only. No Aadhaar data stored.",
  };
}
