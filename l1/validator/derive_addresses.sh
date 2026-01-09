#!/bin/sh
# Derive Ethereum addresses from a mnemonic using Foundry's cast.
#
# Usage: derive_addresses.sh <mnemonic> <count>
# Output: One address per line to stdout.
set -e

MNEMONIC="$1"
COUNT="$2"
if [ -z "$MNEMONIC" ] || [ -z "$COUNT" ]; then
  echo "Usage: $0 <mnemonic> <count>" >&2
  exit 1
fi

# Suppress Foundry warnings and derive addresses.
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1
i=0
while [ "$i" -lt "$COUNT" ]; do
  cast wallet address --mnemonic "$MNEMONIC" --mnemonic-index "$i" 2>/dev/null
  i=$((i + 1))
done
