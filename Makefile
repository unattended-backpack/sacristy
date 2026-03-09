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

.PHONY: deploy-l2
deploy-l2:
	@echo "Deploying L2 contracts to L1 ..."
	@cd contracts && \
		BATCHER_PRIVATE_KEY=$(BATCHER_PRIVATE_KEY) \
		SEQUENCER_PRIVATE_KEY=$(SEQUENCER_PRIVATE_KEY) \
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
	@echo "  # Set L1_RPC, ADMIN_PRIVATE_KEY, BATCHER_PRIVATE_KEY, SEQUENCER_PRIVATE_KEY in .env"
	@echo "  make deploy-l2  # Deploy L1 contracts."
	@echo "  # Update config.star with deployed addresses and keys."
	@echo "  make l2          # Deploy L2 services."
	@echo ""
	@echo "Configuration:"
	@echo "  Edit config.star for configuration."
	@echo "  Override with CLI args:"
	@echo "    kurtosis run . --enclave sacristy '{\"target\": \"l1\", \"l1_chain_id\": 1}'"
	@echo ""

.DEFAULT_GOAL := help
