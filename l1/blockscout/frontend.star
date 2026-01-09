# Blockscout frontend configuration defaults.
#
# These are tunable settings that can be customized without modifying the
# main blockscout.star file. Dynamic values (API host/port, chain ID, etc.)
# are computed at runtime and merged with these defaults.

CONFIG = {

    # Network details.
    "NEXT_PUBLIC_NETWORK_NAME": "Sacristy Testnet",
    "NEXT_PUBLIC_NETWORK_SHORT_NAME": "Sacristy",
    "NEXT_PUBLIC_NETWORK_CURRENCY_NAME": "Ether",
    "NEXT_PUBLIC_NETWORK_CURRENCY_SYMBOL": "ETH",
    "NEXT_PUBLIC_NETWORK_CURRENCY_DECIMALS": "18",
    "NEXT_PUBLIC_NETWORK_CURRENCY_WEI_NAME": "attoEther",
    "NEXT_PUBLIC_IS_TESTNET": "true",

    # Infrastructure configuration.
    "NEXT_PUBLIC_APP_HOST": "blockscout.sacristy.local",
    "NEXT_PUBLIC_APP_PORT": "80",
    "NEXT_PUBLIC_APP_PROTOCOL": "http",
    "NEXT_PUBLIC_API_PROTOCOL": "http",
    "NEXT_PUBLIC_API_WEBSOCKET_PROTOCOL": "ws",
    "NEXT_PUBLIC_USE_NEXT_JS_PROXY": "true",
    "NEXT_PUBLIC_API_SPEC_URL": "https://raw.githubusercontent.com/blockscout/blockscout-api-v2-swagger/main/swagger.yaml",

    # Features.
    "NEXT_PUBLIC_HOMEPAGE_STATS": "[\"total_blocks\",\"average_block_time\",\"total_txs\",\"wallet_addresses\"]",
    "NEXT_PUBLIC_HOMEPAGE_CHARTS": "[\"daily_txs\"]",
    # "NEXT_PUBLIC_HOMEPAGE_HERO_BANNER_CONFIG": "{ background: [] }"
    "NEXT_PUBLIC_PROMOTE_BLOCKSCOUT_IN_TITLE": "false",
    "NEXT_PUBLIC_OG_DESCRIPTION": "The Sacristy testnet explorer.",
    "NEXT_PUBLIC_OG_IMAGE_URL": "https://sigil.box/img/sigil_candlelight.png",
    "NEXT_PUBLIC_OG_ENHANCED_DATA_ENABLED": "true",
    "NEXT_PUBLIC_SEO_ENHANCED_DATA_ENABLED": "true",
    "NEXT_PUBLIC_GAS_TRACKER_ENABLED": "true",
    "NEXT_PUBLIC_GAS_TRACKER_UNITS": "['gwei']",
    "NEXT_PUBLIC_AD_BANNER_PROVIDER": "none",
    "NEXT_PUBLIC_AD_TEXT_PROVIDER": "none"
}
