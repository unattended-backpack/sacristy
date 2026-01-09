#!/bin/sh
# Derive Ethereum addresses and build premine JSON for genesis.
#
# Usage: derive-premine-json.sh <mnemonic> <count> <balances>
#   mnemonic: Seed mnemonic phrase.
#   count:    Number of accounts to derive.
#   balances: Semicolon-separated balance list ("4096ETH;2048ETH;16ETH").
#
# Output: JSON object mapping addresses to balances (to stdout).
#   {"0xaddr1": "4096ETH", "0xaddr2": "2048ETH", ...}
set -e

MNEMONIC="$1"
COUNT="$2"
BALANCES="$3"

if [ -z "$MNEMONIC" ] || [ -z "$COUNT" ] || [ -z "$BALANCES" ]; then
  echo "Usage: $0 <mnemonic> <count> <balances>" >&2
  exit 1
fi

# Suppress Foundry warnings.
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

# Build JSON output.
printf '{'

i=0
while [ "$i" -lt "$COUNT" ]; do
  ADDRESS=$(cast wallet address --mnemonic "$MNEMONIC" --mnemonic-index "$i")

  # Get balance for this index (field number i+1).
  FIELD=$((i + 1))
  BALANCE=$(echo "$BALANCES" | cut -d';' -f"$FIELD")

  if [ "$i" -gt 0 ]; then
    printf ', '
  fi
  printf '"%s": "%s"' "$ADDRESS" "$BALANCE"

  i=$((i + 1))
done

printf '}'
