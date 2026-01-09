#!/bin/bash
# Seed the testnet with a blob transaction.
# Required env vars: RPC_URL, MNEMONIC, MNEMONIC_INDEX, ACCOUNT_NAME
set -e

# Suppress Foundry nightly warning.
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

# Derive private key from mnemonic.
PRIVATE_KEY=$(cast wallet private-key --mnemonic "$MNEMONIC" --mnemonic-index "$MNEMONIC_INDEX")

# Convert account name to hex (0x + hex encoding of ASCII).
# Using od instead of xxd for better compatibility.
BLOB_DATA="0x$(printf '%s' "$ACCOUNT_NAME" | od -A n -t x1 | tr -d ' \n')"

echo "Waiting for chain to produce blocks..."
i=0
while [ "$i" -lt 30 ]; do
    BLOCK=$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    if [ "$BLOCK" != "0" ] && [ -n "$BLOCK" ]; then
        echo "Chain ready at block $BLOCK"
        break
    fi
    sleep 2
    i=$((i + 1))
done

# Write blob data to a temp file.
echo -n "$BLOB_DATA" > /tmp/blob-data.txt
echo "Sending blob transaction for $ACCOUNT_NAME with data: $BLOB_DATA"
cast send \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$RPC_URL" \
    --blob \
    --path /tmp/blob-data.txt \
    --async \
    0x0000000000000000000000000000000000000000
echo "Blob transaction submitted for $ACCOUNT_NAME (async)"
