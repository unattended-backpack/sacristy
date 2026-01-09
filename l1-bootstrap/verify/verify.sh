#!/bin/sh
# Verify genesis and bootstrap contracts with eth-bytecode-db.
#
# Environment variables:
#   BYTECODE_DB_URL - URL of the eth-bytecode-db service
#   CONTRACTS_JSON  - JSON object mapping contract names to addresses
#
# This script reads compiled Forge output and submits verification requests
# to eth-bytecode-db using the Standard JSON Solidity verification endpoint.
# Standard JSON is required for contracts with import remappings (e.g., Solady).

set -e

echo "Contract Verification Script"
echo "  Bytecode DB: $BYTECODE_DB_URL"

# Create temp directory for intermediate files.
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Parse contracts from JSON. Format: {"ContractName": "0xAddr", ...}
# Extract just the contract names (keys).
CONTRACT_NAMES=$(echo "$CONTRACTS_JSON" | jq -r 'keys[]')

for CONTRACT_NAME in $CONTRACT_NAMES; do
  echo ""
  echo "Verifying: $CONTRACT_NAME"

  # Find the compiled output file.
  # Forge outputs to: out/<ContractName>.sol/<ContractName>.json
  COMPILED_FILE="/mnt/out/${CONTRACT_NAME}.sol/${CONTRACT_NAME}.json"

  if [ ! -f "$COMPILED_FILE" ]; then
    echo "  Warning: Compiled file not found at $COMPILED_FILE, skipping"
    continue
  fi

  # Extract deployed bytecode (runtime code).
  BYTECODE=$(jq -r '.deployedBytecode.object' "$COMPILED_FILE")
  if [ -z "$BYTECODE" ] || [ "$BYTECODE" = "null" ]; then
    echo "  Warning: No deployed bytecode found, skipping"
    continue
  fi

  # Extract metadata (contains compiler info, settings, and source references).
  jq '.metadata' "$COMPILED_FILE" > "$TMPDIR/metadata.json"

  # Parse compiler version from metadata.
  # Format in metadata: {"compiler":{"version":"0.8.33+commit.4893d34e"}, ...}
  COMPILER_VERSION=$(jq -r '.compiler.version' "$TMPDIR/metadata.json")
  COMPILER_VERSION="v${COMPILER_VERSION}"
  echo "  Compiler: $COMPILER_VERSION"

  # Extract settings from metadata (includes remappings, optimizer, evmVersion).
  jq '.settings' "$TMPDIR/metadata.json" > "$TMPDIR/settings.json"
  EVM_VERSION=$(jq -r '.evmVersion // "cancun"' "$TMPDIR/settings.json")
  OPTIMIZER_ENABLED=$(jq '.optimizer.enabled // false' "$TMPDIR/settings.json")
  OPTIMIZER_RUNS=$(jq '.optimizer.runs // 200' "$TMPDIR/settings.json")
  jq '.remappings // []' "$TMPDIR/settings.json" > "$TMPDIR/remappings.json"
  echo "  EVM: $EVM_VERSION, Optimizer: $OPTIMIZER_ENABLED ($OPTIMIZER_RUNS runs)"
  echo "  Remappings: $(jq 'length' "$TMPDIR/remappings.json") entries"

  # Build source files map from metadata sources.
  # Metadata contains: {"sources": {"src/Contract.sol": {"keccak256": "...", ...}}}
  # We need to read the actual source content from /mnt/src or /mnt/lib.
  SOURCE_PATHS=$(jq -r '.sources | keys[]' "$TMPDIR/metadata.json")

  # Build the sources JSON object for Standard JSON input.
  # Format: {"path": {"content": "source code..."}}
  # Use a temp file to avoid argument length limits.
  echo '{}' > "$TMPDIR/sources.json"
  for SOURCE_PATH in $SOURCE_PATHS; do
    ACTUAL_PATH=""

    # Try direct path under /mnt/src.
    if [ -f "/mnt/src/$SOURCE_PATH" ]; then
      ACTUAL_PATH="/mnt/src/$SOURCE_PATH"
    # Try stripping "src/" prefix if present.
    elif [ -f "/mnt/src/${SOURCE_PATH#src/}" ]; then
      ACTUAL_PATH="/mnt/src/${SOURCE_PATH#src/}"
    # Try under dependencies for forge-std, solady, etc.
    elif [ -f "/mnt/lib/$SOURCE_PATH" ]; then
      ACTUAL_PATH="/mnt/lib/$SOURCE_PATH"
    # Try stripping "dependencies/" prefix.
    elif [ -f "/mnt/lib/${SOURCE_PATH#dependencies/}" ]; then
      ACTUAL_PATH="/mnt/lib/${SOURCE_PATH#dependencies/}"
    fi

    if [ -n "$ACTUAL_PATH" ] && [ -f "$ACTUAL_PATH" ]; then
      # Read source and add to sources object with {"content": "..."} format.
      # Use jq with file input to avoid argument length limits.
      jq --arg path "$SOURCE_PATH" --rawfile content "$ACTUAL_PATH" \
        '. + {($path): {"content": $content}}' "$TMPDIR/sources.json" > "$TMPDIR/sources_new.json"
      mv "$TMPDIR/sources_new.json" "$TMPDIR/sources.json"
    else
      echo "  Warning: Source not found: $SOURCE_PATH"
    fi
  done

  # Count sources found.
  SOURCE_COUNT=$(jq 'keys | length' "$TMPDIR/sources.json")
  echo "  Sources: $SOURCE_COUNT files"

  # Build the Solidity Standard JSON input.
  # This includes sources, settings (with remappings), and output selection.
  jq -n \
    --arg language "Solidity" \
    --slurpfile sources "$TMPDIR/sources.json" \
    --slurpfile remappings "$TMPDIR/remappings.json" \
    --arg evmVersion "$EVM_VERSION" \
    --argjson optimizerEnabled "$OPTIMIZER_ENABLED" \
    --argjson optimizerRuns "$OPTIMIZER_RUNS" \
    '{
      "language": $language,
      "sources": $sources[0],
      "settings": {
        "remappings": $remappings[0],
        "evmVersion": $evmVersion,
        "optimizer": {
          "enabled": $optimizerEnabled,
          "runs": $optimizerRuns
        },
        "outputSelection": {
          "*": {
            "*": ["abi", "evm.bytecode", "evm.deployedBytecode"]
          }
        }
      }
    }' > "$TMPDIR/standard_json.json"

  # Build the verification request payload for Standard JSON endpoint.
  # The input field must be a JSON string containing the standard JSON.
  # Use --slurpfile and convert to string to avoid argument length limits.
  jq -n \
    --arg bytecode "$BYTECODE" \
    --arg compilerVersion "$COMPILER_VERSION" \
    --slurpfile input "$TMPDIR/standard_json.json" \
    '{
      "bytecode": $bytecode,
      "bytecodeType": "DEPLOYED_BYTECODE",
      "compilerVersion": $compilerVersion,
      "input": ($input[0] | tostring)
    }' > "$TMPDIR/payload.json"

  # Submit to eth-bytecode-db using Standard JSON endpoint.
  RESPONSE=$(curl -s -X POST \
    "${BYTECODE_DB_URL}/api/v2/verifier/solidity/sources:verify-standard-json" \
    -H "Content-Type: application/json" \
    -d @"$TMPDIR/payload.json")

  # Check response status.
  STATUS=$(echo "$RESPONSE" | jq -r '.status // .message // "unknown"')
  if echo "$RESPONSE" | jq -e '.source' > /dev/null 2>&1; then
    echo "  Result: Verified successfully"
  else
    echo "  Result: $STATUS"
    echo "  Response: $(echo "$RESPONSE" | jq -c '.')"
  fi
done

echo ""
echo "Contract verification complete!"
