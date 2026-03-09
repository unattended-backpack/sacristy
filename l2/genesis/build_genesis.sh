#!/bin/sh
# Build L2 genesis.json from alloc + config.
#
# Usage: build_genesis.sh <alloc_path> <chain_id> <timestamp>
#
# Takes the alloc JSON (from GenerateL2Genesis.s.sol) and wraps it with chain
# configuration to produce a complete genesis.json for op-reth.
set -eu

ALLOC_PATH="$1"
CHAIN_ID="$2"
TIMESTAMP="$3"

# Read the alloc JSON.
if [ -f "$ALLOC_PATH" ]; then
    ALLOC=$(cat "$ALLOC_PATH")
    # Handle forge dumpState format with "accounts" wrapper.
    # Simple check: if it starts with {"accounts": strip the wrapper.
    case "$ALLOC" in
        *'"accounts"'*)
            # Extract the accounts object: everything between first { after "accounts": and the matching }.
            # This is a rough extraction — works for forge dumpState output.
            ALLOC=$(echo "$ALLOC" | sed 's/^.*"accounts":\s*//' | sed 's/}$//')
            ;;
    esac
else
    ALLOC='{}'
fi

# Produce the genesis.json.
cat <<EOF
{
  "config": {
    "chainId": ${CHAIN_ID},
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "muirGlacierBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "arrowGlacierBlock": 0,
    "grayGlacierBlock": 0,
    "mergeNetsplitBlock": 0,
    "shanghaiTime": 0,
    "cancunTime": 0,
    "bedrockBlock": 0,
    "regolithTime": 0,
    "canyonTime": 0,
    "ecotoneTime": 0,
    "fjordTime": 0,
    "graniteTime": 0,
    "holoceneTime": 0,
    "isthmusTime": 0,
    "jovianTime": 0,
    "pragueTime": 0,
    "terminalTotalDifficulty": 0,
    "terminalTotalDifficultyPassed": true,
    "optimism": {
      "eip1559Elasticity": 6,
      "eip1559Denominator": 50,
      "eip1559DenominatorCanyon": 250
    }
  },
  "nonce": "0x0",
  "timestamp": "0x$(printf '%x' "$TIMESTAMP")",
  "extraData": "0x",
  "gasLimit": "0x1c9c380",
  "difficulty": "0x0",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "alloc": ${ALLOC}
}
EOF
