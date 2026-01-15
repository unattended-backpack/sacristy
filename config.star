# Configuration
#
# This is the primary Sacristy configuration for runtime images, feature flags,
# and other commonly-changed runtime details. It can be overriden via CLI like
# so: `kurtosis run ./kurtosis '{"l1_chain_id": 1}'`. Some unshared,
# component-specific configuration details live in various `templates/*.yaml`
# files instead of here.

CONFIG = {

    # These are the images needed and used for Sacristy.
    "foundry_image": "ghcr.io/foundry-rs/foundry:nightly",
    "genesis_generator_image": "ethpandaops/ethereum-genesis-generator:5.2.2",
    "l1_el_image": "ghcr.io/paradigmxyz/reth:latest",
    "l1_cl_image": "chainsafe/lodestar:latest",
    "ethdo_image": "wealdtech/ethdo:latest",
    "dora_image": "ethpandaops/dora:v1.19.7",
    "postgres_image": "postgres:16-alpine",
    "redis_image": "redis:7-alpine",
    "blobscan_api_image": "blossomlabs/blobscan-api:latest",
    "blobscan_indexer_image": "blossomlabs/blobscan-indexer:latest",
    "blobscan_web_image": "blossomlabs/blobscan-web:latest",
    "blockscout_image": "ghcr.io/blockscout/blockscout@sha256:c731c00c576a3f084ff5f7f72b4a901f6964e374a424215e0f2ed2aba36a85f0",
    "blockscout_frontend_image": "ghcr.io/blockscout/frontend@sha256:4b69f44148414b55c6b8550bc3270c63c9f99e923d54ef0b307e762af6bac90a",
    "blockscout_verifier_image": "ghcr.io/blockscout/smart-contract-verifier@sha256:7d895b6de54bff18576cfebafcbcff1c4c63c91505c0a324284a19166930bb8a",
    "blockscout_eth_bytecode_db_image": "ghcr.io/blockscout/eth-bytecode-db@sha256:fa7682022992384c348c375e8eba33b48ee5a7048fab4b3cabbbefbe5478c973",
    "blockscout_sig_provider_image": "ghcr.io/blockscout/sig-provider@sha256:a6100b6fbd2fa6c74b618cc9a427ac394a9834ce8c235ded118017a36c56f29a",
    "blockscout_stats_image": "ghcr.io/blockscout/stats@sha256:be9af651f8cc3967f41fe2f1010c1a53573adbde810df4c4713f537c8dfe14a6",
    "ipfs_image": "ipfs/kubo:latest",
    "graph_node_image": "graphprotocol/graph-node:latest",
    "node_image": "node:20",
    "bens_image": "ghcr.io/blockscout/bens:latest",
    "traefik_image": "traefik:v3.2",
    "prometheus_image": "prom/prometheus:latest",
    "grafana_image": "grafana/grafana:latest",

    # These flags are for enabling different pieces of optional infastructure.
    # Some flags have dependencies and cannot be enabled alone.
    # The L1 execution, consensus, and validator clients are always enabled.

    # Enable Prometheus and Grafana for collecting and displaying metrics.
    "monitoring_enabled": True,

    # Enable Dora, the beaconchain explorer.
    "dora_enabled": True,

    # Enable Blobscan, the blob content explorer.
    "blobscan_enabled": True,

    # These flags control Blockscout and its L1 microservices.
    # Enable Blockscout, the block explorer.
    "l1_blockscout_enabled": True,

    # Enable the contract verifier.
    "l1_blockscout_verifier_enabled": True,

    # Enable the bytecode dictionary.
    "l1_blockscout_bytecode_enabled": True,

    # Enable the transaction and event signature dictionary.
    "l1_blockscout_sig_enabled": True,

    # Enable ENS indexing support.
    "l1_blockscout_ens_enabled": True,

    # Enable tracking statistics.
    "l1_blockscout_stats_enabled": True,

    # Enable bootstrapping L1 ENS.
    "l1_bootstrap_ens_enabled": True,

    # Enable bootstrapping L1 blobs.
    "l1_bootstrap_blobs_enabled": True,

    # Enable bootstrapping L1 WETH.
    "l1_bootstrap_weth_enabled": True,

    # Enable bootstrapping L1 ERC-20 test token minting.
    "l1_bootstrap_erc20_enabled": True,

    # Enable bootstrapping L1 ERC-721 test NFT minting.
    "l1_bootstrap_erc721_enabled": True,

    # Enable bootstrapping L1 ERC-1155 test token minting.
    "l1_bootstrap_erc1155_enabled": True,

    # Enable testing the CreateX deterministic deployment factory.
    "l1_bootstrap_createx_enabled": True,

    # Enable verification of L1 bootstrap contracts.
    "l1_bootstrap_verify_enabled": True,

    # Enable the L2 stack.
    "l2_enabled": True,

    # L1 configuration.
    "l1_chain_id": 7357,
    "l1_seconds_per_slot": 12,

    # L2 configuration.
    "l2_chain_id": 51611,
    "l2_seconds_per_slot": 1,

    # The mnemonic used for prefunded genesis accounts and validators.
    "mnemonic": "faith faith faith faith faith faith faith grace grace grace grace grace",

    # Prefunded accounts derived from `mnemonic` (indices 0, 1, 2, ...).
    # Each account is funded at genesis with the specified balance and has
    # validators assigned using it as fee recipient. Validator indices are
    # assigned sequentially across accounts.
    "accounts": [

        # Virtues
        {"name": "chastity", "balance": "4096ETH", "validators": 4},
        {"name": "temperance", "balance": "2048ETH", "validators": 3},
        {"name": "charity", "balance": "16ETH", "validators": 1},
        {"name": "diligence", "balance": "4096ETH", "validators": 4},
        {"name": "kindness", "balance": "4096ETH", "validators": 4},
        {"name": "patience", "balance": "4096ETH", "validators": 4},
        {"name": "humility", "balance": "4096ETH", "validators": 4},

        # Sins
        {"name": "lust", "balance": "69ETH", "validators": 4},
        {"name": "gluttony", "balance": "32768ETH", "validators": 4},
        {"name": "greed", "balance": "8192ETH", "validators": 16},
        {"name": "sloth", "balance": "4096ETH", "validators": 4},
        {"name": "envy", "balance": "4096ETH", "validators": 4},
        {"name": "wrath", "balance": "4096ETH", "validators": 4},
        {"name": "pride", "balance": "4096ETH", "validators": 4},
    ],

    # The genesis contract deployments.
    # These map contract name to deployment address for genesis preloading.
    # Contract names must match compiled output: {name}.sol/{name}.json
    "genesis_contracts": {
        "MulticallDelegate": "0x0000000000000000000000000000000000007702",
        "Test20": "0x0000000000000000000000000000000000000020",
        "Test721": "0x0000000000000000000000000000000000000721",
        "Test1155": "0x0000000000000000000000000000000000001155",
        "CreateX": "0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed",
        "DeterministicDeploymentProxy": "0x4e59b44847b379578588920cA78FbF26c0B4956C",
        "Multicall3": "0xcA11bde05977b3631167028862bE2a173976CA11",
        "ENSRegistry": "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e",
        "PublicResolver": "0xF29100983E058B709F3D539b0c765937B804AC15",
        "UniversalResolver": "0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe",
        "WETH": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    },

    # Ports. These shouldn't need to change.
    # L1 execution layer.
    "port_el_rpc_http": 8545,
    "port_el_rpc_ws": 8546,
    "port_el_engine": 8551,
    "port_el_metrics": 9001,
    "port_el_p2p_tcp": 30303,
    "port_el_p2p_udp": 30303,

    # L1 consensus layer.
    "port_cl_http": 5052,
    "port_cl_metrics": 8008,
    "port_cl_p2p_tcp": 9000,
    "port_cl_p2p_udp": 9000,
    "port_validator_metrics": 5064,

    # Observation tools.
    "port_prometheus_http": 9090,
    "port_grafana_http": 3000,
    "port_dora_http": 8080,
    "port_blobscan_web": 3000,
    "port_blobscan_api": 3001,
    "port_blockscout_http": 4000,
    "port_blockscout_frontend": 3080,
    "port_blockscout_verifier": 8051,
    "port_blockscout_sig_provider": 8052,
    "port_blockscout_eth_bytecode_db": 8053,
    "port_graph_node_http": 8000,
    "port_graph_node_ws": 8001,
    "port_graph_node_admin": 8020,
    "port_graph_node_index": 8030,
    "port_bens_http": 8054,
    "port_blockscout_stats": 8050,

    # Infrastructure.
    "port_postgres": 5432,
    "port_redis": 6379,
    "port_ipfs_api": 5001,
    "port_ipfs_gateway": 8080,
    "port_traefik_http": 80,
    "port_traefik_dashboard": 8081,
}
