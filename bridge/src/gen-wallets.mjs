import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import { writeFileSync } from "node:fs";

const roles = ["SEED_PRIVATE_KEY", "JOURNALIST_A_KEY", "JOURNALIST_B_KEY", "JOURNALIST_C_KEY", "READER_KEY"];
const envLines = ["# Local only. Do not commit."];
const publicRows = [];
for (const role of roles) {
  const pk = generatePrivateKey();
  const acc = privateKeyToAccount(pk);
  envLines.push(`${role}=${pk}`);
  publicRows.push({ role, address: acc.address });
  console.log(role, acc.address);
}
writeFileSync(new URL("../../wallets.local.json", import.meta.url), JSON.stringify({ warning: "PRIVATE KEYS — gitignored", env: envLines.join("\n"), publicRows }, null, 2));
writeFileSync(new URL("../../.env", import.meta.url), envLines.join("\n") + "\n");
console.log("wrote .env and wallets.local.json (gitignored)");
