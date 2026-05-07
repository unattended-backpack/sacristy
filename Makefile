# Sacristy is Ethereum testnet infrastucture for Sigil development.
#
# Configuration is loaded from `.env.maintainer` and can be overridden by
# environment variables.
#
# Usage:
#   make l1        # Deploy L1.
#   make l2        # Deploy L2.
#   make clean     # Tear down everything.
#   make help      # Show all commands.

# Load configuration from `.env.maintainer` if it exists.
-include .env.maintainer

# Load configuration from `.env` if it exists.
-include .env

# Allow environment variable overrides with defaults.
ENCLAVE = sacristy
L2_ENCLAVE = sacristy-l2

# Docker bridge gateway — the host IP reachable from inside containers.
DOCKER_HOST_IP := $(shell docker run --rm alpine ip route 2>/dev/null | grep default | awk '{print $$3}')

# ---------------------------------------------------------------------------
# Gateway
# ---------------------------------------------------------------------------

.PHONY: gateway
gateway:
	@set -e; \
	echo "Starting gateway on port 80 (requires sudo) ..."; \
	L1_CTR=$$(docker ps -q --filter "name=^traefik--" 2>/dev/null | head -1); \
	L2_CTR=$$(docker ps -q --filter "name=^l2-traefik--" 2>/dev/null | head -1); \
	if [ -z "$$L1_CTR" ] && [ -z "$$L2_CTR" ]; then \
		echo "Error: No traefik containers found. Is the testnet running?"; \
		exit 1; \
	fi; \
	CONFDIR=/tmp/sacristy-gateway; mkdir -p $$CONFDIR; \
	cp $(CURDIR)/shared/gateway/traefik.yaml $$CONFDIR/traefik.yaml; \
	echo 'http:' > $$CONFDIR/dynamic.yaml; \
	echo '  routers:' >> $$CONFDIR/dynamic.yaml; \
	NETWORKS=""; \
	L1_URLS=""; \
	L2_URLS=""; \
	if [ -n "$$L2_CTR" ]; then \
		L2_IP=$$(docker inspect $$L2_CTR --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'); \
		L2_NET=$$(docker inspect $$L2_CTR --format '{{range $$k, $$v := .NetworkSettings.Networks}}{{$$k}}{{end}}'); \
		echo "  L2 traefik: $$L2_IP ($$L2_NET)"; \
		echo '    l2:' >> $$CONFDIR/dynamic.yaml; \
		echo '      rule: "HostRegexp(`^.+\\.l2\\.sacristy\\.local$$`)"' >> $$CONFDIR/dynamic.yaml; \
		echo '      service: l2' >> $$CONFDIR/dynamic.yaml; \
		echo '      priority: 100' >> $$CONFDIR/dynamic.yaml; \
		echo '      entryPoints:' >> $$CONFDIR/dynamic.yaml; \
		echo '        - web' >> $$CONFDIR/dynamic.yaml; \
		NETWORKS="$$L2_NET"; \
		L2_URLS="  http://rpc.l2.sacristy.local\n  http://blockscout.l2.sacristy.local"; \
	fi; \
	if [ -n "$$L1_CTR" ]; then \
		L1_IP=$$(docker inspect $$L1_CTR --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'); \
		L1_NET=$$(docker inspect $$L1_CTR --format '{{range $$k, $$v := .NetworkSettings.Networks}}{{$$k}}{{end}}'); \
		echo "  L1 traefik: $$L1_IP ($$L1_NET)"; \
		echo '    l1:' >> $$CONFDIR/dynamic.yaml; \
		echo '      rule: "HostRegexp(`^.+\\.sacristy\\.local$$`)"' >> $$CONFDIR/dynamic.yaml; \
		echo '      service: l1' >> $$CONFDIR/dynamic.yaml; \
		echo '      priority: 1' >> $$CONFDIR/dynamic.yaml; \
		echo '      entryPoints:' >> $$CONFDIR/dynamic.yaml; \
		echo '        - web' >> $$CONFDIR/dynamic.yaml; \
		if [ -z "$$NETWORKS" ]; then NETWORKS="$$L1_NET"; else NETWORKS="$$NETWORKS $$L1_NET"; fi; \
		L1_URLS="  http://rpc.sacristy.local\n  http://beacon.sacristy.local\n  http://blockscout.sacristy.local"; \
	fi; \
	echo '  services:' >> $$CONFDIR/dynamic.yaml; \
	if [ -n "$$L2_CTR" ]; then \
		echo '    l2:' >> $$CONFDIR/dynamic.yaml; \
		echo '      loadBalancer:' >> $$CONFDIR/dynamic.yaml; \
		echo '        servers:' >> $$CONFDIR/dynamic.yaml; \
		echo "          - url: \"http://$$L2_IP:80\"" >> $$CONFDIR/dynamic.yaml; \
	fi; \
	if [ -n "$$L1_CTR" ]; then \
		echo '    l1:' >> $$CONFDIR/dynamic.yaml; \
		echo '      loadBalancer:' >> $$CONFDIR/dynamic.yaml; \
		echo '        servers:' >> $$CONFDIR/dynamic.yaml; \
		echo "          - url: \"http://$$L1_IP:80\"" >> $$CONFDIR/dynamic.yaml; \
	fi; \
	docker rm -f sacristy-gateway 2>/dev/null || true; \
	FIRST_NET=$$(echo $$NETWORKS | awk '{print $$1}'); \
	docker run -d --name sacristy-gateway \
		--network $$FIRST_NET \
		-v $$CONFDIR:/etc/traefik:ro \
		-p 80:80 \
		traefik:v3.2 \
		--configFile=/etc/traefik/traefik.yaml; \
	for NET in $$NETWORKS; do \
		if [ "$$NET" != "$$FIRST_NET" ]; then \
			docker network connect $$NET sacristy-gateway; \
		fi; \
	done; \
	echo ""; \
	echo "Gateway ready!"; \
	if [ -n "$$L1_URLS" ]; then printf "$$L1_URLS\n"; fi; \
	if [ -n "$$L2_URLS" ]; then printf "$$L2_URLS\n"; fi; \
	echo ""; \
	echo "Make sure /etc/hosts contains:"; \
	echo "  127.0.0.1  rpc.sacristy.local beacon.sacristy.local prometheus.sacristy.local grafana.sacristy.local dora.sacristy.local blobscan.sacristy.local blockscout.sacristy.local api.blockscout.sacristy.local bens.sacristy.local rpc.l2.sacristy.local blockscout.l2.sacristy.local api.blockscout.l2.sacristy.local"

.PHONY: gateway-stop
gateway-stop:
	@echo "Stopping gateway ..."
	@docker rm -f sacristy-gateway 2>/dev/null || true

# ---------------------------------------------------------------------------
# L1
# ---------------------------------------------------------------------------

.PHONY: l1
l1:
	@echo "Deploying Sacristy L1 ..."
	@echo "  Enclave: $(ENCLAVE)"
	kurtosis run . --enclave $(ENCLAVE) '{"target": "l1"}'
	@$(MAKE) gateway

.PHONY: l1-bootstrap
l1-bootstrap:
	@echo "Running L1 bootstrap scripts against existing enclave ..."
	@echo "  Enclave: $(ENCLAVE)"
	kurtosis run . --enclave $(ENCLAVE) '{"target": "l1-bootstrap"}'

.PHONY: info-l1
info-l1:
	@echo "Sacristy L1 information:"
	kurtosis enclave inspect $(ENCLAVE)

.PHONY: logs-l1
logs-l1:
ifndef SVC
	@echo "Usage: make logs-l1 SVC=<service-name>"
	@echo "Available services:"
	@kurtosis enclave inspect $(ENCLAVE) 2>/dev/null | grep -E "^[a-z]" | awk '{print "  " $$1}' || echo "  (enclave not running)"
else
	kurtosis service logs $(ENCLAVE) $(SVC) --follow
endif

.PHONY: shell-l1
shell-l1:
ifndef SVC
	@echo "Usage: make shell-l1 SVC=<service-name>"
	@echo "Available services:"
	@kurtosis enclave inspect $(ENCLAVE) 2>/dev/null | grep -E "^[a-z]" | awk '{print "  " $$1}' || echo "  (enclave not running)"
else
	kurtosis service shell $(ENCLAVE) $(SVC)
endif

.PHONY: clean-l1
clean-l1:
	@echo "Tearing down Sacristy L1 ..."
	@$(MAKE) gateway-stop 2>/dev/null || true
	kurtosis enclave rm $(ENCLAVE) --force || true

# ---------------------------------------------------------------------------
# L2
# ---------------------------------------------------------------------------

# `genesis` produces the L2 `genesis.json` and prints the
# `GENESIS_OUTPUT_ROOT` the SigilVerifier deploy needs. Genesis must be
# pinned BEFORE `deploy-l2` because the contract is constructed with
# the output root as its `currentOutputRoot` seed; rebuilding genesis
# after deploy invalidates the chain. The target refuses to run if
# `genesis.json` already exists — delete it by hand if you really mean
# to fork.
#
# Non-sensitive deployment parameters (chain ids, gas limit, image
# tags) all come from `config.star`, so the kurtosis enclave and the
# host-side `make genesis` / `make deploy-l2` paths can't drift. Only
# secrets (private keys) and post-`make genesis` outputs
# (`GENESIS_OUTPUT_ROOT`) live in `.env`.
#
# The leading-whitespace anchor (`^[[:space:]]*`) skips the comment
# block at the top of `config.star` that mentions these keys in the
# usage example, and any future commented references.
config_star_int = $(shell awk '/^[[:space:]]*"$(1)"[[:space:]]*:[[:space:]]*[0-9]+/ { gsub(/[^0-9]/,"",$$2); print $$2; exit }' config.star)
config_star_str = $(shell awk -F'"' '/^[[:space:]]*"$(1)"[[:space:]]*:/ {print $$4; exit}' config.star)

L1_CHAIN_ID                 := $(call config_star_int,l1_chain_id)
L2_CHAIN_ID                 := $(call config_star_int,l2_chain_id)
L2_MINIMUM_BLOCK_GAS_LIMIT  := $(call config_star_int,l2_minimum_block_gas_limit)
L2_MINIMUM_TX_GAS_LIMIT     := $(call config_star_int,l2_minimum_tx_gas_limit)
L2_MINIMUM_CODE_SIZE        := $(call config_star_int,l2_minimum_code_size)
L2_MAXIMUM_CODE_SIZE        := $(call config_star_int,l2_maximum_code_size)
L2_MINIMUM_INITCODE_SIZE    := $(call config_star_int,l2_minimum_initcode_size)
L2_MAXIMUM_INITCODE_SIZE    := $(call config_star_int,l2_maximum_initcode_size)
L2_MAXIMUM_SEQUENCER_CALLDATA_SIZE := $(call config_star_int,l2_maximum_sequencer_calldata_size)
L2_NODE_IMAGE               := $(call config_star_str,l2_node_image)
GENESIS_ACCOUNTS_FILE       := $(CURDIR)/genesis.accounts.bin

# `-include .env` loads .env vars into make's scope but does NOT export
# them to recipe shells. `${VAR:?msg}` checks below run in the shell, so
# the values must be exported for those checks to see them. Same
# applies to the `config.star`-extracted values above.
export L2_NODE_IMAGE
export L1_CHAIN_ID
export L2_CHAIN_ID
export L2_MINIMUM_BLOCK_GAS_LIMIT
export L2_MINIMUM_TX_GAS_LIMIT
export L2_MINIMUM_CODE_SIZE
export L2_MAXIMUM_CODE_SIZE
export L2_MINIMUM_INITCODE_SIZE
export L2_MAXIMUM_INITCODE_SIZE
export L2_MAXIMUM_SEQUENCER_CALLDATA_SIZE
export PROVER_QUORUM
export SP1_VERIFIER
export SP1_VKEY
export GENESIS_OUTPUT_ROOT
export GENESIS_TIMESTAMP
export GENESIS_ACCOUNTS_FILE

.PHONY: genesis
genesis:
	@echo "Building L2 genesis..."
	@: $${L2_NODE_IMAGE:?could not extract from config.star}
	@: $${L1_CHAIN_ID:?could not extract from config.star}
	@: $${L2_CHAIN_ID:?must be set in .env}
	@: $${L2_MINIMUM_BLOCK_GAS_LIMIT:?must be set in .env}
	@: $${L2_MINIMUM_TX_GAS_LIMIT:?must be set in .env}
	@: $${L2_MINIMUM_CODE_SIZE:?must be set in .env}
	@: $${L2_MAXIMUM_CODE_SIZE:?must be set in .env}
	@: $${L2_MINIMUM_INITCODE_SIZE:?must be set in .env}
	@: $${L2_MAXIMUM_INITCODE_SIZE:?must be set in .env}
	@: $${L2_MAXIMUM_SEQUENCER_CALLDATA_SIZE:?must be set in .env}
	@if [ -f genesis.json ]; then \
		echo "Error: genesis.json already exists. Delete it to rebuild."; \
		exit 1; \
	fi
	@if [ ! -f genesis.accounts.json ]; then \
		echo "Error: genesis.accounts.json missing. Provide an accounts spec (see genesis.accounts.json.example)."; \
		exit 1; \
	fi
	@TIMESTAMP=$$(date +%s) && \
		echo "GENESIS_TIMESTAMP=$$TIMESTAMP (record this in .env for deploy-l2)" && \
		docker run --rm \
			--user $$(id -u):$$(id -g) \
			-v $(CURDIR):$(CURDIR) \
			-w $(CURDIR) \
			$(L2_NODE_IMAGE) \
			--log.file.max-files 0 \
			genesis \
				--accounts genesis.accounts.json \
				--out genesis.json \
				--accounts-out genesis.accounts.bin \
				--l1-chain-id $(L1_CHAIN_ID) \
				--l2-chain-id $(L2_CHAIN_ID) \
				--minimum-block-gas-limit $(L2_MINIMUM_BLOCK_GAS_LIMIT) \
				--minimum-tx-gas-limit $(L2_MINIMUM_TX_GAS_LIMIT) \
				--minimum-code-size $(L2_MINIMUM_CODE_SIZE) \
				--maximum-code-size $(L2_MAXIMUM_CODE_SIZE) \
				--minimum-initcode-size $(L2_MINIMUM_INITCODE_SIZE) \
				--maximum-initcode-size $(L2_MAXIMUM_INITCODE_SIZE) \
				--maximum-sequencer-calldata-size $(L2_MAXIMUM_SEQUENCER_CALLDATA_SIZE) \
				--timestamp $$TIMESTAMP

.PHONY: deploy-l2
deploy-l2:
	@echo "Deploying SigilVerifier to L1 ..."
	@: $${L2_CHAIN_ID:?must be set in .env}
	@: $${L1_CHAIN_ID:?must be set in .env}
	@: $${GENESIS_TIMESTAMP:?must be set in .env (printed by 'make genesis')}
	@: $${L2_MINIMUM_BLOCK_GAS_LIMIT:?must be set in .env}
	@: $${L2_MINIMUM_TX_GAS_LIMIT:?must be set in .env}
	@: $${L2_MINIMUM_CODE_SIZE:?must be set in .env}
	@: $${L2_MAXIMUM_CODE_SIZE:?must be set in .env}
	@: $${L2_MINIMUM_INITCODE_SIZE:?must be set in .env}
	@: $${L2_MAXIMUM_INITCODE_SIZE:?must be set in .env}
	@: $${L2_MAXIMUM_SEQUENCER_CALLDATA_SIZE:?must be set in .env}
	@: $${PROVER_QUORUM:?must be set in .env}
	@: $${SP1_VERIFIER:?must be set in .env (use 0x0000...0000 to disable on-chain verification)}
	@: $${SP1_VKEY:?must be set in .env}
	@: $${GENESIS_OUTPUT_ROOT:?must be set in .env}
	@if [ ! -f $(GENESIS_ACCOUNTS_FILE) ]; then \
		echo "Error: $(GENESIS_ACCOUNTS_FILE) missing. Run 'make genesis' first."; \
		exit 1; \
	fi
	@cd contracts && \
		L2_CHAIN_ID=$(L2_CHAIN_ID) \
		L1_CHAIN_ID=$(L1_CHAIN_ID) \
		GENESIS_TIMESTAMP=$(GENESIS_TIMESTAMP) \
		GENESIS_ACCOUNTS_FILE=$(GENESIS_ACCOUNTS_FILE) \
		L2_MINIMUM_BLOCK_GAS_LIMIT=$(L2_MINIMUM_BLOCK_GAS_LIMIT) \
		L2_MINIMUM_TX_GAS_LIMIT=$(L2_MINIMUM_TX_GAS_LIMIT) \
		L2_MINIMUM_CODE_SIZE=$(L2_MINIMUM_CODE_SIZE) \
		L2_MAXIMUM_CODE_SIZE=$(L2_MAXIMUM_CODE_SIZE) \
		L2_MINIMUM_INITCODE_SIZE=$(L2_MINIMUM_INITCODE_SIZE) \
		L2_MAXIMUM_INITCODE_SIZE=$(L2_MAXIMUM_INITCODE_SIZE) \
		L2_MAXIMUM_SEQUENCER_CALLDATA_SIZE=$(L2_MAXIMUM_SEQUENCER_CALLDATA_SIZE) \
		PROVER_QUORUM=$(PROVER_QUORUM) \
		SP1_VERIFIER=$(SP1_VERIFIER) \
		SP1_VKEY=$(SP1_VKEY) \
		GENESIS_OUTPUT_ROOT=$(GENESIS_OUTPUT_ROOT) \
		forge script script/DeployL2Contracts.s.sol \
		--rpc-url $(L1_RPC) \
		--private-key $(ADMIN_PRIVATE_KEY) \
		--broadcast --slow

.PHONY: l2
l2:
	@echo "Deploying Sacristy L2 ..."
	@echo "  Enclave: $(L2_ENCLAVE)"
	@L1_RPC=$$(kurtosis port print $(ENCLAVE) reth rpc-http 2>/dev/null | sed 's|http://127.0.0.1|http://$(DOCKER_HOST_IP)|') && \
	 L1_BEACON=$$(kurtosis port print $(ENCLAVE) lodestar http 2>/dev/null | sed 's|http://127.0.0.1|http://$(DOCKER_HOST_IP)|') && \
	 echo "  L1 RPC:    $$L1_RPC" && \
	 echo "  L1 Beacon: $$L1_BEACON" && \
	 kurtosis run . --enclave $(L2_ENCLAVE) \
		"{\"target\": \"l2\", \"l1_rpc_url\": \"$$L1_RPC\", \"l1_beacon_url\": \"$$L1_BEACON\", \"l2_sequencer_private_key\": \"$(SEQUENCER_PRIVATE_KEY)\", \"l2_batcher_private_key\": \"$(BATCHER_PRIVATE_KEY)\"}"
	@$(MAKE) gateway

.PHONY: info-l2
info-l2:
	@echo "Sacristy L2 information:"
	kurtosis enclave inspect $(L2_ENCLAVE)

.PHONY: logs-l2
logs-l2:
ifndef SVC
	@echo "Usage: make logs-l2 SVC=<service-name>"
	@echo "Available services:"
	@kurtosis enclave inspect $(L2_ENCLAVE) 2>/dev/null | grep -E "^[a-z]" | awk '{print "  " $$1}' || echo "  (enclave not running)"
else
	kurtosis service logs $(L2_ENCLAVE) $(SVC) --follow
endif

.PHONY: shell-l2
shell-l2:
ifndef SVC
	@echo "Usage: make shell-l2 SVC=<service-name>"
	@echo "Available services:"
	@kurtosis enclave inspect $(L2_ENCLAVE) 2>/dev/null | grep -E "^[a-z]" | awk '{print "  " $$1}' || echo "  (enclave not running)"
else
	kurtosis service shell $(L2_ENCLAVE) $(SVC)
endif

.PHONY: clean-l2
clean-l2:
	@echo "Tearing down Sacristy L2 ..."
	@$(MAKE) gateway-stop 2>/dev/null || true
	kurtosis enclave rm $(L2_ENCLAVE) --force || true

# ---------------------------------------------------------------------------
# Global
# ---------------------------------------------------------------------------

.PHONY: clean
clean:
	@echo "Tearing down Sacristy ..."
	@$(MAKE) gateway-stop 2>/dev/null || true
	kurtosis enclave rm $(ENCLAVE) --force || true
	kurtosis enclave rm $(L2_ENCLAVE) --force || true

.PHONY: clean-kurtosis
clean-kurtosis:
	@echo "Stopping Kurtosis engine ..."
	kurtosis engine stop || true
	@echo "Cleaning all Kurtosis resources ..."
	kurtosis clean -a || true
	@echo "Removing Kurtosis images ..."
	docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^kurtosistech/' | xargs -r docker rmi -f 2>/dev/null || true

.PHONY: status
status:
	@echo "Kurtosis enclave status:"
	kurtosis enclave ls

.PHONY: help
help:
	@echo "Sacristy"
	@echo ""
	@echo "  gateway          Start gateway (routes L1 + L2 on port 80)."
	@echo "  gateway-stop     Stop the gateway."
	@echo ""
	@echo "  l1               Deploy L1."
	@echo "  l1-bootstrap     Run L1 bootstrap scripts against existing enclave."
	@echo "  info-l1          Show L1 service information."
	@echo "  logs-l1 SVC=name Stream L1 service logs."
	@echo "  shell-l1 SVC=name Open shell in an L1 service."
	@echo "  clean-l1         Tear down L1 (also stops gateway)."
	@echo ""
	@echo "  genesis          Build L2 genesis.json + emit GENESIS_OUTPUT_ROOT."
	@echo "  deploy-l2        Deploy L2 rollup contracts to L1."
	@echo "  l2               Deploy L2 rollup (separate enclave)."
	@echo "  info-l2          Show L2 service information."
	@echo "  logs-l2 SVC=name Stream L2 service logs."
	@echo "  shell-l2 SVC=name Open shell in an L2 service."
	@echo "  clean-l2         Tear down L2 (also stops gateway)."
	@echo ""
	@echo "  clean            Tear down everything (L1 + L2 + gateway)."
	@echo "  clean-kurtosis   Stop Kurtosis engine and remove all resources."
	@echo "  status           Show all Kurtosis enclaves."
	@echo "  help             Show this help message."
	@echo ""
	@echo "L1 workflow:"
	@echo "  make l1            # Deploy L1."
	@echo "  make l1-bootstrap  # Run bootstrap (can retry if it fails)."
	@echo ""
	@echo "L2 rollup workflow:"
	@echo "  # Set in .env (or .env.maintainer):"
	@echo "  #   L1_RPC, ADMIN_PRIVATE_KEY"
	@echo "  #   L2_CHAIN_ID, L2_MINIMUM_BLOCK_GAS_LIMIT,"
	@echo "  #   L2_MINIMUM_TX_GAS_LIMIT, PROVER_QUORUM"
	@echo "  #   SP1_VERIFIER, SP1_VKEY"
	@echo "  #   BATCHER_PRIVATE_KEY, SEQUENCER_PRIVATE_KEY (used by 'make l2')"
	@echo "  # Provide an accounts spec at ./genesis.accounts.json"
	@echo "  # (see ./genesis.accounts.json.example)"
	@echo "  make genesis     # Build genesis.json; copy printed output_root into .env as GENESIS_OUTPUT_ROOT."
	@echo "  make deploy-l2   # Deploy SigilVerifier to L1."
	@echo "  # Update config.star with deployed verifier address."
	@echo "  make l2          # Deploy L2 services."
	@echo ""
	@echo "Configuration:"
	@echo "  Edit config.star for configuration."
	@echo "  Override with CLI args:"
	@echo "    kurtosis run . --enclave sacristy '{\"target\": \"l1\", \"l1_chain_id\": 1}'"
	@echo ""

.DEFAULT_GOAL := help
