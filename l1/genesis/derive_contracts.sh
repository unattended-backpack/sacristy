#!/bin/sh
# Build preloaded contracts JSON for genesis from compiled artifacts.
#
# Usage: derive_contracts.sh <contracts_dir> <mapping_file>
#   contracts_dir: Directory containing compiled contract JSON files.
#   mapping_file:  JSON file mapping contract names to deployment addresses.
#                  Format: {"ContractName": "0xaddress", ...}
#
# Output: JSON object for genesis preloaded contracts (to stdout).
#   {"0xaddr": {"balance": "0", "code": "0x..."}, ...}
#
# Note: This script avoids jq dependency by using grep/sed/awk for JSON parsing.
# It assumes simple flat JSON structures matching the expected formats.
set -e

CONTRACTS_DIR="$1"
MAPPING_FILE="$2"

if [ -z "$CONTRACTS_DIR" ] || [ -z "$MAPPING_FILE" ]; then
  echo "Usage: $0 <contracts_dir> <mapping_file>" >&2
  exit 1
fi

# Extract bytecode from compiled contract JSON.
# Expects forge output format with deployedBytecode.object field.
get_bytecode() {
  contract_json="$1"
  # Remove whitespace/newlines, then extract the object field from deployedBytecode
  tr -d '\n\r\t ' < "$contract_json" | \
    sed 's/.*"deployedBytecode":{"object":"\([^"]*\)".*/\1/'
}

# Build output JSON by iterating over each contract in the mapping.
# Parse mapping.json: extract "Name":"Address" pairs
# Remove braces and split on comma to get individual pairs
mapping_content=$(cat "$MAPPING_FILE" | tr -d '{}' | tr ',' '\n')

# Write to temp file to avoid subshell issues with the while loop
tmpfile=$(mktemp)
trap "rm -f $tmpfile" EXIT

first=true
printf '{' > "$tmpfile"

# Use here-string to avoid subshell
while IFS= read -r pair; do
  # Skip empty lines
  [ -z "$pair" ] && continue

  # Extract name and address from "Name":"Address"
  name=$(echo "$pair" | sed 's/"\([^"]*\)":.*/\1/')
  address=$(echo "$pair" | sed 's/.*:"\([^"]*\)".*/\1/')

  # Get bytecode from compiled contract
  contract_file="$CONTRACTS_DIR/$name.sol/$name.json"
  if [ ! -f "$contract_file" ]; then
    echo "Error: Contract file not found: $contract_file" >&2
    exit 1
  fi
  bytecode=$(get_bytecode "$contract_file")

  if [ "$first" = true ]; then
    first=false
  else
    printf ', ' >> "$tmpfile"
  fi

  printf '"%s": {"balance": "0", "code": "%s"}' "$address" "$bytecode" >> "$tmpfile"
done << EOF
$mapping_content
EOF

printf '}' >> "$tmpfile"
cat "$tmpfile"
