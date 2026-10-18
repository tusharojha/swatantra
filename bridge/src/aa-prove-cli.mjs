import { proveAndVerifyTestMode } from "./aa-prove.ts";

const r = await proveAndVerifyTestMode({
  revealState: true,
  onProgress: (s) => console.log("[aa]", s),
  localArtifacts: {
    wasm: "/tmp/aa-artifacts/aadhaar-verifier.wasm",
    zkey: "/tmp/aa-artifacts/circuit_final.zkey",
    vkey: "/tmp/aa-artifacts/vkey.json",
  },
});
console.log(
  "RESULT",
  JSON.stringify(
    {
      ok: r.ok,
      groth16: r.groth16,
      nullifier: r.nullifier,
      ageAbove18: r.ageAbove18,
      stateRevealed: r.stateRevealed,
      state: r.state,
      proofHash: r.proofHash,
      note: r.note,
    },
    null,
    2,
  ),
);
process.exit(0);
