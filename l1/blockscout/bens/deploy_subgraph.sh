#!/bin/bash
# Deploy ENS subgraph to graph-node.
#
# Usage: deploy_subgraph.sh <subgraph_name>
#
# Environment variables:
#   GRAPH_NODE_ADMIN - graph-node admin URL
#   IPFS_URL         - IPFS API URL
#
# Expected file structure:
#   /subgraph/        - subgraph source files
#   /contracts/       - compiled contract artifacts
set -e

SUBGRAPH_NAME="$1"

cd /subgraph
mkdir -p abis

# Extract ABIs from pre-compiled contract artifacts.
# Structure: /contracts/ContractName.sol/ContractName.json
node -e "console.log(JSON.stringify(require('/contracts/ENSRegistry.sol/ENSRegistry.json').abi))" > abis/ENSRegistry.json
node -e "console.log(JSON.stringify(require('/contracts/PublicResolver.sol/PublicResolver.json').abi))" > abis/PublicResolver.json
echo 'Extracted ABIs:'
ls -la abis/

# Build and deploy.
npm install
./node_modules/.bin/graph codegen
./node_modules/.bin/graph build
(./node_modules/.bin/graph create --node "$GRAPH_NODE_ADMIN" "$SUBGRAPH_NAME" || true)
./node_modules/.bin/graph deploy --node "$GRAPH_NODE_ADMIN" --ipfs "$IPFS_URL" -l v1 "$SUBGRAPH_NAME"
