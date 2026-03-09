#!/bin/sh
# Build rollup_config.json for kona-node.
#
# Usage: build_rollup_config.sh <l1_rpc_url> <l2_genesis_path> <config_args...>
#
# Queries the L1 RPC for the current head block and assembles the rollup config.
set -eu

L1_RPC_URL="$1"
L2_GENESIS_PATH="$2"
L1_CHAIN_ID="$3"
L2_CHAIN_ID="$4"
SYSTEM_CONFIG_ADDR="$5"
PORTAL_ADDR="$6"
BATCH_INBOX_ADDR="$7"
BATCHER_ADDR="$8"

# Get L1 block fields individually via cast.
L1_BLOCK_HASH=$(cast block latest -f hash --rpc-url "$L1_RPC_URL")
L1_BLOCK_NUM=$(cast block latest -f number --rpc-url "$L1_RPC_URL")
L1_TIMESTAMP=$(cast block latest -f timestamp --rpc-url "$L1_RPC_URL")

# L2 genesis hash — passed as $2 (queried from op-reth after init).
L2_GENESIS_HASH="$2"

cat <<EOF
{
  "genesis": {
    "l1": {
      "hash": "${L1_BLOCK_HASH}",
      "number": ${L1_BLOCK_NUM}
    },
    "l2": {
      "hash": "${L2_GENESIS_HASH}",
      "number": 0
    },
    "l2_time": ${L1_TIMESTAMP},
    "system_config": {
      "batcherAddr": "${BATCHER_ADDR}",
      "overhead": "0x0000000000000000000000000000000000000000000000000000000000000000",
      "scalar": "0x00000000000000000000000000000000000000000000000000000a000000000a",
      "gasLimit": 30000000
    }
  },
  "block_time": 1,
  "max_sequencer_drift": 600,
  "seq_window_size": 3600,
  "channel_timeout": 300,
  "l1_chain_id": ${L1_CHAIN_ID},
  "l2_chain_id": ${L2_CHAIN_ID},
  "batch_inbox_address": "${BATCH_INBOX_ADDR}",
  "deposit_contract_address": "${PORTAL_ADDR}",
  "l1_system_config_address": "${SYSTEM_CONFIG_ADDR}",
  "protocol_versions_address": "0x0000000000000000000000000000000000000000",
  "regolith_time": 0,
  "canyon_time": 0,
  "delta_time": 0,
  "ecotone_time": 0,
  "fjord_time": 0,
  "granite_time": 0,
  "holocene_time": 0,
  "isthmus_time": 0,
  "jovian_time": 0
}
EOF
