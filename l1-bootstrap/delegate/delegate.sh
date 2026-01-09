#!/bin/sh
# Sets up EIP-7702 delegation for accounts.
#
# Environment variables:
#   MNEMONIC     - Seed mnemonic for deriving accounts.
#   DELEGATE     - Address of delegated contract.
#   RPC          - RPC URL for the chain.
#   NUM_ACCOUNTS - Number of accounts to delegate.
#
# Usage:
#   MNEMONIC="..." DELEGATE="0x..." RPC="http://..." ./delegate.sh
#
# For debugging a single account:
#   MNEMONIC="..." DELEGATE="0x..." RPC="http://..." ./delegate.sh 0
set -e
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1
echo "EIP-7702 Delegation Setup"
echo "  Delegate: $DELEGATE"
echo "  Accounts: $NUM_ACCOUNTS"
echo ""

# Setup delegation for one account.
setup() {
  idx=$1
  pk=$(cast wallet derive-private-key "$MNEMONIC" $idx 2>/dev/null | tail -1)
  addr=$(cast wallet address --private-key "$pk")
  echo "[$idx] Setting up delegation for $addr"
  cast send "$(cast az)" --auth "$DELEGATE" --private-key "$pk" --rpc-url "$RPC"
}

# If an argument is provided, delegate only that account index.
if [ -n "$1" ]; then
  setup "$1"
  exit 0
fi

# Otherwise, delegate all accounts in parallel.
i=0
while [ "$i" -lt "$NUM_ACCOUNTS" ]; do
  setup "$i" &
  i=$((i + 1))
done
wait
echo ""
echo "All $NUM_ACCOUNTS delegation transactions submitted!"
