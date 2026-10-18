/**
 * Network switch: Tiramisu (default) or a local Arkiv/Golem Base --dev node.
 *
 *   ARKIV_NETWORK=tiramisu   public testnet (judges, CI, GitHub Pages)
 *   ARKIV_NETWORK=local      http://127.0.0.1:8545  chain id 1337
 *
 * Browser: SwatantraArkiv.setNetwork('local') or ?network=local
 * Never bake local RPC into the production default.
 */
import { localhost, tiramisu } from "@arkiv-network/sdk/chains";

export type NetworkName = "tiramisu" | "local";

export type Network = {
  name: NetworkName;
  chain: typeof tiramisu | typeof localhost;
  rpc: string;
  ws: string;
  explorer: string;
  chainId: number;
  nativeToken: string;
};

export const TIRAMISU: Network = {
  name: "tiramisu",
  chain: tiramisu,
  rpc: "https://rpc.tiramisu.db-chain.testnet.arkiv.network",
  ws: "wss://rpc.tiramisu.db-chain.testnet.arkiv.network",
  explorer: "https://tiramisu.explorer.arkiv.network",
  chainId: 7738577,
  nativeToken: "GLM",
};

export const LOCAL: Network = {
  name: "local",
  chain: localhost,
  rpc: "http://127.0.0.1:8545",
  ws: "ws://127.0.0.1:8546",
  explorer: "http://127.0.0.1:8545",
  chainId: 1337,
  nativeToken: "ETH",
};

/** Printed by `geth --dev`. Local-only, never a Tiramisu key. */
export const LOCAL_DEV_KEY =
  "0xb71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291" as const;
export const LOCAL_DEV_ADDRESS = "0x71562b71999873DB5b286DF957af199Ec94617F7" as const;

let current: Network = TIRAMISU;

function readEnvNetwork(): string | undefined {
  try {
    const p = (globalThis as { process?: { env?: Record<string, string | undefined> } }).process;
    return p?.env?.ARKIV_NETWORK;
  } catch {
    return undefined;
  }
}

function readQueryNetwork(): string | undefined {
  try {
    const loc = (globalThis as { location?: { search?: string } }).location;
    if (!loc?.search) return undefined;
    return new URLSearchParams(loc.search).get("network") ?? undefined;
  } catch {
    return undefined;
  }
}

export function parseNetwork(name?: string | null): NetworkName {
  const n = (name ?? "").trim().toLowerCase();
  if (n === "local" || n === "localhost" || n === "dev") return "local";
  return "tiramisu";
}

export function setNetwork(name?: string | null): Network {
  current = parseNetwork(name) === "local" ? LOCAL : TIRAMISU;
  return current;
}

export function getNetwork(): Network {
  return current;
}

export function isLocal(): boolean {
  return current.name === "local";
}

setNetwork(readQueryNetwork() ?? readEnvNetwork() ?? "tiramisu");
