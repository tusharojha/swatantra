#!/usr/bin/env bash
# Poll the Tiramisu seeder. When it has ≥0.05 GLM, run the real seed.
# Safe to leave running. Never prints private keys.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RPC="https://rpc.tiramisu.db-chain.testnet.arkiv.network"
SEEDER="0x873f5856a0967549D60442481DB5aef270044Bd7"
NEED_WEI=50000000000000000  # 0.05 GLM

wei() {
  curl -sS "$RPC" -H 'content-type: application/json' -H 'user-agent: swatantra-poll/1' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getBalance\",\"params\":[\"$SEEDER\",\"latest\"]}" \
    | python3 -c 'import json,sys; print(int(json.load(sys.stdin)["result"],16))'
}

if [[ -f "$ROOT/arkiv/seed-result.json" ]] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get("entities") or d.get("stories") else 1)' "$ROOT/arkiv/seed-result.json"; then
  echo "Tiramisu already seeded ($(date -u +%FT%TZ))"
  exit 0
fi

echo "polling Tiramisu seeder $SEEDER every 30s (seed at ≥0.05 GLM)"
while true; do
  BAL="$(wei || echo 0)"
  echo "$(date -u +%FT%TZ) seeder_wei=$BAL"
  if [[ "$BAL" -ge "$NEED_WEI" ]]; then
    echo "≥0.05 GLM — seeding Tiramisu"
    cd "$ROOT/bridge"
    set -a
    # shellcheck disable=SC1091
    source "$ROOT/.env"
    set +a
    ARKIV_NETWORK=tiramisu npx tsx src/seed.ts
    exit 0
  fi
  sleep 30
done
