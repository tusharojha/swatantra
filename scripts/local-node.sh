#!/usr/bin/env bash
# Start a local Arkiv/Golem Base --dev node (official op-geth).
# Usage: ./scripts/local-node.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${GOLEMBASE_OP_GETH:-/tmp/golembase-op-geth}"
IMAGE="golembase-op-geth:local"

DOCKER=(docker)
if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required. Install Docker Desktop / docker.io." >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
fi

if [[ ! -f "$SRC/Dockerfile" ]]; then
  echo "cloning Golem-Base/golembase-op-geth → $SRC"
  git clone --depth 1 https://github.com/Golem-Base/golembase-op-geth.git "$SRC"
fi

if ! "${DOCKER[@]}" image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "building $IMAGE from $SRC (first run compiles geth)"
  "${DOCKER[@]}" build -t "$IMAGE" "$SRC"
fi

"${DOCKER[@]}" rm -f arkiv-local-geth >/dev/null 2>&1 || true
"${DOCKER[@]}" run -d --name arkiv-local-geth --network host \
  "$IMAGE" \
  --dev \
  --http --http.api 'eth,web3,net,debug,arkiv,golembase' \
  --http.addr 0.0.0.0 --http.port 8545 \
  --http.corsdomain '*' --http.vhosts '*' \
  --ws --ws.addr 0.0.0.0 --ws.port 8546 --ws.origins '*' \
  --verbosity 3

echo "waiting for http://127.0.0.1:8545"
for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8545 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' >/dev/null; then
    echo "local Arkiv node is up (chain 1337). Prefunded account is in docker logs:"
    "${DOCKER[@]}" logs arkiv-local-geth 2>&1 | grep -A2 'Account' | head -8 || true
    echo "Seed: ARKIV_NETWORK=local npx tsx src/seed.ts"
    echo "App:  flutter run -d web-server --dart-define=ARKIV_NETWORK=local"
    echo "      or open http://127.0.0.1:8080/?network=local"
    exit 0
  fi
  sleep 1
done
echo "node did not become ready" >&2
"${DOCKER[@]}" logs arkiv-local-geth 2>&1 | tail -40
exit 1
