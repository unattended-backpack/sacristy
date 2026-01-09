#!/bin/sh
# Create Lodestar proposer file with per-validator fee recipients and graffiti.
#
# Usage: generate_proposer_config.sh <mnemonic> <total_validators> <assignments>
# Required files: /addresses/addresses.txt (one address per line)
# Output: /tmp/output/proposer-config.yaml
#
# ASSIGNMENTS format: "account_index:start_index:count:account_name;..."
set -e

MNEMONIC="$1"
TOTAL_VALIDATORS="$2"
ASSIGNMENTS="$3"
if [ -z "$MNEMONIC" ] || [ -z "$TOTAL_VALIDATORS" ] || [ -z "$ASSIGNMENTS" ]; then
  echo "Usage: $0 <mnemonic> <total_validators> <assignments>" >&2
  exit 1
fi

# Find ethdo binary (may not be in PATH when running via sh).
if command -v ethdo >/dev/null 2>&1; then
    ETHDO="ethdo"
elif [ -x /app/ethdo ]; then
    ETHDO="/app/ethdo"
elif [ -x /usr/local/bin/ethdo ]; then
    ETHDO="/usr/local/bin/ethdo"
elif [ -x /usr/bin/ethdo ]; then
    ETHDO="/usr/bin/ethdo"
else
    echo "ERROR: Cannot find ethdo binary" >&2
    find / -name "ethdo" -type f 2>/dev/null | head -5 >&2
    exit 1
fi
echo "Using ethdo at: $ETHDO"

# Step 1: Derive all validator BLS pubkeys and save to file.
# EIP-2334 path for signing key: m/12381/3600/{index}/0/0
echo "Deriving $TOTAL_VALIDATORS validator pubkeys..."
PUBKEYS_FILE="/tmp/pubkeys.txt"
rm -f "$PUBKEYS_FILE"
i=0
while [ "$i" -lt "$TOTAL_VALIDATORS" ]; do
    OUTPUT=$($ETHDO account derive \
        --mnemonic="$MNEMONIC" \
        --path="m/12381/3600/$i/0/0" 2>&1)

    # Extract the public key (96 hex chars = 48 bytes BLS pubkey).
    # Use sed for portability (busybox grep may not have -oE).
    PUBKEY=$(echo "$OUTPUT" | sed -n 's/.*\(0x[0-9a-fA-F]\{96\}\).*/\1/p' | head -1)
    if [ -z "$PUBKEY" ]; then
        echo "ERROR: Failed to derive pubkey for validator $i" >&2
        echo "ethdo output: $OUTPUT" >&2
        exit 1
    fi
    echo "$PUBKEY" >> "$PUBKEYS_FILE"
    echo "  Validator $i: $(echo "$PUBKEY" | cut -c1-20)..."
    i=$((i + 1))
done

# Helper to get line N from a file (1-indexed).
get_line() {
    sed -n "${1}p" "$2"
}

# Step 2: Build the proposer config YAML.
mkdir -p /tmp/output
echo "Building proposer config YAML..."
{
    echo "proposer_config:"

    # Parse assignments and build config entries.
    REMAINING="$ASSIGNMENTS"
    while [ -n "$REMAINING" ]; do

        # Extract first assignment (before semicolon).
        ASSIGNMENT=$(echo "$REMAINING" | cut -d';' -f1)
        
        # Remove first assignment from remaining.
        if echo "$REMAINING" | grep -q ';'; then
            REMAINING=$(echo "$REMAINING" | cut -d';' -f2-)
        else
            REMAINING=""
        fi

        # Parse assignment: account_index:start_index:count:account_name.
        ACCOUNT_IDX=$(echo "$ASSIGNMENT" | cut -d':' -f1)
        START_IDX=$(echo "$ASSIGNMENT" | cut -d':' -f2)
        COUNT=$(echo "$ASSIGNMENT" | cut -d':' -f3)
        ACCOUNT_NAME=$(echo "$ASSIGNMENT" | cut -d':' -f4)

        # Get fee recipient address (line numbers are 1-indexed).
        LINE_NUM=$((ACCOUNT_IDX + 1))
        FEE_RECIPIENT=$(get_line "$LINE_NUM" /addresses/addresses.txt)

        # Add entries for each validator in this assignment.
        j=0
        while [ "$j" -lt "$COUNT" ]; do
            VAL_IDX=$((START_IDX + j))
            PUBKEY_LINE=$((VAL_IDX + 1))
            PUBKEY=$(get_line "$PUBKEY_LINE" "$PUBKEYS_FILE")

            echo "  \"$PUBKEY\":"
            echo "    graffiti: \"$ACCOUNT_NAME\""
            echo "    fee_recipient: \"$FEE_RECIPIENT\""

            j=$((j + 1))
        done
    done

    # Default config using first account with validators.
    FIRST_ASSIGNMENT=$(echo "$ASSIGNMENTS" | cut -d';' -f1)
    FIRST_ACCOUNT_IDX=$(echo "$FIRST_ASSIGNMENT" | cut -d':' -f1)
    FIRST_ACCOUNT_NAME=$(echo "$FIRST_ASSIGNMENT" | cut -d':' -f4)
    DEFAULT_LINE=$((FIRST_ACCOUNT_IDX + 1))
    DEFAULT_FEE_RECIPIENT=$(get_line "$DEFAULT_LINE" /addresses/addresses.txt)
    echo "default_config:"
    echo "  graffiti: \"$FIRST_ACCOUNT_NAME\""
    echo "  fee_recipient: \"$DEFAULT_FEE_RECIPIENT\""
} > /tmp/output/proposer-config.yaml
echo "Generated proposer config for $TOTAL_VALIDATORS validators:"
cat /tmp/output/proposer-config.yaml
