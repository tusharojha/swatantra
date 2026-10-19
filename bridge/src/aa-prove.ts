/**
 * Real Anon Aadhaar TEST-MODE Groth16 prove + verify using @anon-aadhaar/core.
 *
 * Artifacts are the official hosted v2 set (wasm + zkey + vkey). The zkey is
 * ~612 MiB, so the first prove is slow. We never write QR bytes to Arkiv.
 */
import {
  ArtifactsOrigin,
  artifactUrls,
  generateArgs,
  init,
  prove,
  verify,
  type AnonAadhaarCore,
} from "@anon-aadhaar/core";
import { sha256, toHex } from "./hash";
import testQr from "./aa-test-qr.json";

/** App-wide nullifier seed so the same TEST identity maps to one nid. */
export const SWATANTRA_NULLIFIER_SEED = 7738577;

/** PSE test certificate (same PEM as @anon-aadhaar/react testCertificate). */
export const TEST_CERTIFICATE = `-----BEGIN CERTIFICATE-----
MIID6jCCAtKgAwIBAgIBATANBgkqhkiG9w0BAQsFADBpMRQwEgYDVQQDEwtleGFt
cGxlLm9yZzELMAkGA1UEBhMCVVMxETAPBgNVBAgTCFZpcmdpbmlhMRMwEQYDVQQH
EwpCbGFja3NidXJnMQ0wCwYDVQQKEwRUZXN0MQ0wCwYDVQQLEwRUZXN0MB4XDTI0
MDMwMTE2MTc0MFoXDTI1MDMwMTE2MTc0MFowaTEUMBIGA1UEAxMLZXhhbXBsZS5v
cmcxCzAJBgNVBAYTAlVTMREwDwYDVQQIEwhWaXJnaW5pYTETMBEGA1UEBxMKQmxh
Y2tzYnVyZzENMAsGA1UEChMEVGVzdDENMAsGA1UECxMEVGVzdDCCASIwDQYJKoZI
hvcNAQEBBQADggEPADCCAQoCggEBAJXoH3UGWVzCYq3c/d012AQFWyrfRtxxnFa1
ju4ZmZXvoaMlRxBiCseAHpdvROO+RU2w8ZDj99TjWYlyEXNE3lL894JvhJSIqVmn
s9Iett0DRRZi6og+7u/eiJoUmbmkf5UExfCWwmK5bSPRl1AzLZ6X62FB0mHel5lN
TEFjypy+PgdyIbRCU9z4FglCi2g1HuPptg0rNR/apu6MKKhFI5+X3nzA/l0UTkdI
E/tD7Fg/gbTuMowiFnM0iY0hC6AXom7GiUDwXfIr2cyGu8OkNUOSNy1WYWd2m3Nb
oSyjWA+RnBvYunDEwqsKzysJvC+umB88ApWm4enySPUAcwlP+vECAwEAAaOBnDCB
mTAMBgNVHRMEBTADAQH/MAsGA1UdDwQEAwIC9DA7BgNVHSUENDAyBggrBgEFBQcD
AQYIKwYBBQUHAwIGCCsGAQUFBwMDBggrBgEFBQcDBAYIKwYBBQUHAwgwEQYJYIZI
AYb4QgEBBAQDAgD3MCwGA1UdEQQlMCOGG2h0dHA6Ly9leGFtcGxlLm9yZy93ZWJp
ZCNtZYcEfwAAATANBgkqhkiG9w0BAQsFAAOCAQEAjDnIK8R7ruSiJpdUeZ2ZxaGI
ewf020sAc0ENw6x3jaKKFINNLnMqEKLntZzIg7WbjnKLhtUhb/SLHP59mfT2OJVS
YMW7uRmnajfEd0MzfrXIUKBwCeWTCyP/bcdlJOT4u24ngFnkUyWaEKnqH3YuI8cw
BKWQ26Lq7ODq6e6Otxf0KOtWTeVSzlCL66MGBvQ36LF1g8PLEZ9hvvX06ieaE99W
HDK9/pGSuobx6Fi7ufzqymirT/GOuxslquB4mleCu4ArCg2qAVC2wDjQymgvq8FS
bVukYnC6XdwqYhvIuTPnEys4gGdeirY+UPGQeqxMrNm+ZpKPTS0NwzxHwlhutw==
-----END CERTIFICATE-----`;

export const OFFICIAL_TEST_QR = testQr.testQRData;

export function nidFromField(nullifier: string): `0x${string}` {
  const hex = BigInt(nullifier).toString(16).padStart(64, "0");
  if (hex.length > 64) throw new Error("nullifier does not fit in bytes32");
  return `0x${hex}`;
}

export type Groth16JournalistProof = {
  ok: true;
  groth16: true;
  testMode: true;
  nullifier: `0x${string}`;
  nullifierField: string;
  ageAbove18: boolean;
  stateRevealed: boolean;
  state?: string;
  proofHash: `0x${string}`;
  pubkeyHash: string;
  timestamp: string;
  note: string;
};

let inited = false;

export async function proveAndVerifyTestMode(opts: {
  qrData?: string;
  revealState?: boolean;
  onProgress?: (s: string) => void;
  /** Node-only: local wasm/zkey/vkey paths instead of the 612 MiB S3 fetch. */
  localArtifacts?: { wasm: string; zkey: string; vkey: string };
}): Promise<Groth16JournalistProof> {
  const progress = opts.onProgress ?? (() => undefined);
  const qr = (opts.qrData || "").trim() || OFFICIAL_TEST_QR;
  if (!/^\d{64,}$/.test(qr)) {
    throw new Error("TEST QR must be a long numeric string from the Anon Aadhaar QR generator (or the bundled PSE test QR).");
  }

  progress("Building circuit inputs from TEST QR (no Aadhaar data kept)…");
  const args = await generateArgs({
    qrData: qr,
    certificateFile: TEST_CERTIFICATE,
    nullifierSeed: SWATANTRA_NULLIFIER_SEED,
    fieldsToRevealArray: opts.revealState
      ? ["revealAgeAbove18", "revealState"]
      : ["revealAgeAbove18"],
  });

  if (!inited || opts.localArtifacts) {
    progress("init() with official v2 artifacts…");
    if (opts.localArtifacts) {
      await init({
        wasmURL: opts.localArtifacts.wasm,
        zkeyURL: opts.localArtifacts.zkey,
        vkeyURL: opts.localArtifacts.vkey,
        artifactsOrigin: ArtifactsOrigin.local,
      });
    } else {
      await init({
        wasmURL: artifactUrls.v2.wasm,
        zkeyURL: artifactUrls.v2.zkey,
        vkeyURL: artifactUrls.v2.vk,
        artifactsOrigin: ArtifactsOrigin.server,
      });
    }
    inited = !opts.localArtifacts;
  }

  progress("Groth16 prove() — first run fetches ~10 MiB wasm + ~612 MiB zkey from PSE…");
  const pcd: AnonAadhaarCore = await prove(args, (st) => progress(`prover: ${st}`));

  progress("verify() on the Groth16 proof (TEST public key)…");
  const ok = await verify(pcd, true);
  if (!ok) throw new Error("Anon Aadhaar verify() returned false");

  const proofJson = JSON.stringify(pcd.proof.groth16Proof);
  const proofHash = toHex(await sha256(new TextEncoder().encode(proofJson)));
  const ageAbove18 = pcd.claim.ageAbove18 === true || pcd.proof.ageAbove18 === "1";
  const state = pcd.claim.state ?? undefined;

  return {
    ok: true,
    groth16: true,
    testMode: true,
    nullifier: nidFromField(pcd.proof.nullifier),
    nullifierField: pcd.proof.nullifier,
    ageAbove18,
    stateRevealed: Boolean(state),
    state,
    proofHash,
    pubkeyHash: pcd.proof.pubkeyHash,
    timestamp: pcd.proof.timestamp,
    note: "Proof verified ✓. Only the nullifier, reveal booleans, and a proof hash are kept. QR data is dropped.",
  };
}

const g = globalThis as unknown as { SwatantraAA?: Record<string, unknown> };
g.SwatantraAA = {
  proveAndVerifyTestMode,
  OFFICIAL_TEST_QR,
  SWATANTRA_NULLIFIER_SEED,
};
