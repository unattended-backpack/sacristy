# Sacristy is Ethereum testnet infrastucture for Sigil development.
#
# Usage:
#   make all       # Deploy testnet.
#   make clean     # Tear down testnet.
#   make logs      # View logs.
#   make help      # Show all commands.
ENCLAVE = sacristy

.PHONY: all
all: l1 l1-bootstrap
	@echo "Sacristy deployment complete!"

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

.PHONY: clean
clean:
	@echo "Tearing down Sacristy ..."
	@$(MAKE) gateway-stop 2>/dev/null || true
	kurtosis enclave rm $(ENCLAVE) --force || true

.PHONY: info
info:
	@echo "Sacristy information:"
	kurtosis enclave inspect $(ENCLAVE)

.PHONY: logs
logs:
ifndef SVC
	@echo "Usage: make logs SVC=<service-name>"
	@echo "Available services:"
	@kurtosis enclave inspect $(ENCLAVE) 2>/dev/null | grep -E "^[a-z]" | awk '{print "  " $$1}' || echo "  (enclave not running)"
else
	kurtosis service logs $(ENCLAVE) $(SVC) --follow
endif

.PHONY: shell
shell:
ifndef SVC
	@echo "Usage: make shell SVC=<service-name>"
	@echo "Available services:"
	@kurtosis enclave inspect $(ENCLAVE) 2>/dev/null | grep -E "^[a-z]" | awk '{print "  " $$1}' || echo "  (enclave not running)"
else
	kurtosis service shell $(ENCLAVE) $(SVC)
endif

.PHONY: gateway
gateway:
	@echo "Starting gateway on port 80 (requires sudo) ..."
	@TRAEFIK_CONTAINER=$$(docker ps -q --filter "name=^traefik--" 2>/dev/null | head -1); \
	if [ -z "$$TRAEFIK_CONTAINER" ]; then \
		echo "Error: Traefik container not found. Is the testnet running?"; \
		exit 1; \
	fi; \
	TRAEFIK_IP=$$(docker inspect $$TRAEFIK_CONTAINER --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'); \
	NETWORK=$$(docker inspect $$TRAEFIK_CONTAINER --format '{{range $$k, $$v := .NetworkSettings.Networks}}{{$$k}}{{end}}'); \
	echo "  Traefik IP: $$TRAEFIK_IP"; \
	echo "  Network: $$NETWORK"; \
	docker rm -f sacristy-gateway 2>/dev/null || true; \
	docker run -d --name sacristy-gateway \
		--network $$NETWORK \
		-p 80:80 \
		alpine/socat \
		TCP-LISTEN:80,fork,reuseaddr TCP-CONNECT:$$TRAEFIK_IP:80; \
	echo ""; \
	echo "Gateway ready! Access services at:"; \
	echo "  http://rpc.sacristy.local"; \
	echo "  http://beacon.sacristy.local"; \
	echo "  http://prometheus.sacristy.local"; \
	echo "  http://grafana.sacristy.local"; \
	echo "  http://dora.sacristy.local"; \
	echo "  http://blobscan.sacristy.local"; \
	echo "  http://blockscout.sacristy.local"; \
	echo "  http://bens.sacristy.local"; \
	echo "  ..."; \
	echo ""; \
	echo "Make sure /etc/hosts contains entries:"; \
	echo "  127.0.0.1  rpc.sacristy.local beacon.sacristy.local prometheus.sacristy.local grafana.sacristy.local dora.sacristy.local blobscan.sacristy.local blockscout.sacristy.local bens.sacristy.local"

.PHONY: gateway-stop
gateway-stop:
	@echo "Stopping gateway ..."
	@docker rm -f sacristy-gateway 2>/dev/null || true

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
	@echo "  all             Deploy full testnet (L1 + L1 bootstrap)."
	@echo "  l1              Deploy L1 only (no bootstrapping)."
	@echo "  l1-bootstrap    Run L1 bootstrap scripts against existing enclave."
	@echo "  clean           Tear down testnet (also stops gateway)."
	@echo "  clean-kurtosis  Stop Kurtosis engine and remove all resources."
	@echo ""
	@echo "  info            Show testnet service information."
	@echo "  logs SVC=name   Stream logs from a service."
	@echo "  shell SVC=name  Open shell in a service."
	@echo ""
	@echo "  gateway         Start port 80 gateway (if not running)."
	@echo "  gateway-stop    Stop the port 80 gateway."
	@echo ""
	@echo "  status          Show all Kurtosis enclaves."
	@echo "  help            Show this help message."
	@echo ""
	@echo "Split workflow for debugging bootstrap scripts:"
	@echo "  make l1            # Deploy L1 without bootstrapping."
	@echo "  make l1-bootstrap  # Run bootstrap (can retry if it fails)."
	@echo ""
	@echo "Configuration:"
	@echo "  Edit config.star for configuration."
	@echo "  Override with CLI args:"
	@echo "    kurtosis run . --enclave sacristy '{\"target\": \"l1\", \"l1_chain_id\": 1}'"
	@echo ""

.DEFAULT_GOAL := help
