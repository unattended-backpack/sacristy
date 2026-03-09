#!/bin/sh
# Build L1 chain config JSON for kona-node.
#
# Usage: build_l1_chain_config.sh <l1_rpc_url> <l1_chain_id>
#
# Queries the L1 RPC for the chain config or constructs it from known parameters.
set -eu

L1_RPC_URL="$1"
L1_CHAIN_ID="$2"

# Try to get chain config from the L1 node via debug_chainConfig.
CHAIN_CONFIG=$(cast rpc debug_chainConfig --rpc-url "$L1_RPC_URL" 2>/dev/null || echo "")

if [ -n "$CHAIN_CONFIG" ] && echo "$CHAIN_CONFIG" | grep -q '"chainId"'; then
    echo "$CHAIN_CONFIG"
else
    cat <<EOF
{
  "chainId": ${L1_CHAIN_ID},
  "homesteadBlock": 0,
  "eip150Block": 0,
  "eip155Block": 0,
  "eip158Block": 0,
  "byzantiumBlock": 0,
  "constantinopleBlock": 0,
  "petersburgBlock": 0,
  "istanbulBlock": 0,
  "berlinBlock": 0,
  "londonBlock": 0,
  "shanghaiTime": 0,
  "cancunTime": 0,
  "terminalTotalDifficulty": 0,
  "terminalTotalDifficultyPassed": true
}
EOF
fi
