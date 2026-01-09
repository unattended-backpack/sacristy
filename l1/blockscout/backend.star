# Blockscout backend configuration defaults.
#
# These are tunable settings that can be customized without modifying the
# main blockscout.star file. Dynamic values (database URLs, RPC endpoints,
# ports, etc.) are computed at runtime and merged with these defaults.

CONFIG = {

    # Network details.
    "NETWORK": "Sacristy",
    "SUBNETWORK": "Testnet",
    "LOGO": "/images/ethereum_logo.svg",
    "COIN": "ETH",
    "COIN_NAME": "Ether",
    "SHOW_TESTNET_LABEL": "true",
    "TESTNET_LABEL_TEXT": "testnet",
    "FOOTER_LOGO": "/images/ethereum_logo.svg",

    # Features.
    "INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER": "true",
    "DISABLE_EXCHANGE_RATES": "true",
    "DISABLE_KNOWN_TOKENS": "true",
    "SHOW_TXS_CHART": "true",
    "ENABLE_TXS_STATS": "true",
    "API_V2_ENABLED": "true",

    # Cache TTLs.
    "CACHE_TXS_COUNT_PERIOD": "60",
    "CACHE_BLOCK_COUNT_PERIOD": "60",
    "CACHE_ADDRESS_WITH_BALANCES_UPDATE_INTERVAL": "60",
    "CACHE_ADDRESS_TRANSACTIONS_COUNT_PERIOD": "60",
    "CACHE_ADDRESS_TOKENS_USD_SUM_PERIOD": "60",
    "CACHE_TOTAL_GAS_USAGE_PERIOD": "60",

    # Infrastructure configuration.
    "ETHEREUM_JSONRPC_VARIANT": "geth",
    "BLOCKSCOUT_HOST": "0.0.0.0",
    "ECTO_USE_SSL": "false",
    "POOL_SIZE": "10",
    "POOL_SIZE_API": "10",
    "SECRET_KEY_BASE": "sacristy-testnet-secret-key-base-at-least-64-bytes-long-for-phoenix",
}
