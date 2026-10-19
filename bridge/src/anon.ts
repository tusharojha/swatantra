/**
 * Anon Aadhaar SHA-256 nullifier (APK / seed / tests).
 *
 * The Groth16 path is `aa-prove.ts` (`prove()` + `verify()` from
 * `@anon-aadhaar/core`, bundled as `app/web/aa_prove.js`). This remains
 * for the Android APK, Node seed, and widget tests.
 *
 * nid = SHA-256("swatantra-aa-v1|" || testQR). Never a real Aadhaar.
 * Test QR generator: https://documentation.anon-aadhaar.pse.dev/docs/quick-setup
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
    throw new Error("QR too short — paste an Anon Aadhaar QR, or prove with the saved identity");
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
    note: "Anon Aadhaar proof. Nullifier only. No Aadhaar data stored.",
  };
}
