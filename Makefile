# Makefile for leewilson.me
# All Node-based work runs inside a pinned Docker container, so the host
# only needs Docker. Use `make` to see all targets.

# ---- Config ---------------------------------------------------------------

SHELL          := /usr/bin/env bash
.SHELLFLAGS    := -eu -o pipefail -c
.DEFAULT_GOAL  := help

DOCKER         ?= docker
# Pinned Node.js LTS line. Bump on the next LTS; for digest-level pinning,
# use: NODE_IMAGE=node:24-alpine@sha256:<digest>
NODE_IMAGE     ?= node:24-alpine

PORT           ?= 8080
HOST           ?= 127.0.0.1
# macOS default; override on Linux: `make preview OPEN=xdg-open`
OPEN           ?= open

OUTPUT         := index.html
SRC_DIR        := src
TEMPLATE       := $(SRC_DIR)/templates/index.template.html
DATA           := $(SRC_DIR)/data/profile.json
ICONS          := $(SRC_DIR)/scripts/icons.mjs
BUILD_SCRIPT   := $(SRC_DIR)/scripts/build.mjs
SERVE_SCRIPT   := $(SRC_DIR)/scripts/serve.mjs
SMOKE_SCRIPT   := $(SRC_DIR)/scripts/smoke.sh
STYLES         := styles.css

SOURCES        := $(DATA) $(TEMPLATE) $(ICONS) $(BUILD_SCRIPT)

# Run a one-shot node command in the pinned image with the project mounted.
# Uses the host UID/GID so generated files are not owned by root.
DOCKER_RUN     = $(DOCKER) run --rm \
                   -u $$(id -u):$$(id -g) \
                   -v "$(CURDIR)":/app \
                   -w /app \
                   $(NODE_IMAGE)

# Serve variant: publishes the port and binds to 0.0.0.0 inside the container.
DOCKER_SERVE   = $(DOCKER) run --rm -it \
                   -u $$(id -u):$$(id -g) \
                   -v "$(CURDIR)":/app \
                   -w /app \
                   -p $(HOST):$(PORT):$(PORT) \
                   -e PORT=$(PORT) \
                   -e HOST=0.0.0.0 \
                   $(NODE_IMAGE)

# ---- Meta -----------------------------------------------------------------

.PHONY: help
help: ## Show this help
	@awk 'BEGIN { FS = ":.*##"; printf "\nleewilson.me - make targets\n\n" } \
		/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
	@echo
	@echo "Node image: $(NODE_IMAGE)"
	@echo

##@ Build

.PHONY: build
build: $(OUTPUT) ## Render index.html from data + template (inside Docker)

$(OUTPUT): $(SOURCES)
	@$(DOCKER_RUN) node $(BUILD_SCRIPT)

.PHONY: rebuild
rebuild: clean build ## Clean + build from scratch

.PHONY: watch
watch: ## Rebuild on changes to inputs (requires fswatch on host)
	@command -v fswatch >/dev/null || { echo "fswatch not found. Install: brew install fswatch"; exit 1; }
	@echo "Watching for changes... (Ctrl-C to stop)"
	@$(MAKE) --no-print-directory build || true
	@fswatch -o $(SOURCES) $(STYLES) | while read -r _; do \
		echo "> change detected, rebuilding"; \
		$(MAKE) --no-print-directory build || true; \
	done

##@ Serve

.PHONY: serve
serve: build ## Serve the site (from a container) on $(HOST):$(PORT)
	@echo "Serving http://$(HOST):$(PORT) via $(NODE_IMAGE)  (Ctrl-C to stop)"
	@$(DOCKER_SERVE) node $(SERVE_SCRIPT)

.PHONY: preview
preview: build ## Build, serve, and open the browser
	@( sleep 1 && $(OPEN) "http://$(HOST):$(PORT)/" ) &
	@$(MAKE) --no-print-directory serve

##@ Docker

.PHONY: pull
pull: ## Pull / refresh the pinned Node image
	@$(DOCKER) pull $(NODE_IMAGE)

.PHONY: shell
shell: ## Open an interactive shell inside the pinned Node image
	@$(DOCKER) run --rm -it \
		-u $$(id -u):$$(id -g) \
		-v "$(CURDIR)":/app -w /app \
		$(NODE_IMAGE) sh

##@ Quality

.PHONY: verify
verify: ## Fail if committed index.html differs from a fresh build (drift check)
	@cp $(OUTPUT) .index.html.committed
	@$(DOCKER_RUN) node $(BUILD_SCRIPT) >/dev/null
	@if ! diff -q .index.html.committed $(OUTPUT) >/dev/null; then \
		echo "x index.html is out of date with its inputs."; \
		echo "  Run 'make build' and commit the result."; \
		diff -u .index.html.committed $(OUTPUT) | sed -n '1,40p'; \
		mv .index.html.committed $(OUTPUT); \
		exit 1; \
	else \
		rm -f .index.html.committed; \
		echo "OK - index.html is in sync with inputs."; \
	fi

.PHONY: validate-json
validate-json: ## Validate src/data/profile.json is well-formed JSON
	@$(DOCKER_RUN) node -e "JSON.parse(require('fs').readFileSync('$(DATA)','utf8')); console.log('OK - $(DATA) is valid JSON')"

.PHONY: validate-html
validate-html: build ## Quick sanity-check that index.html looks well-formed
	@$(DOCKER_RUN) node -e "const h=require('fs').readFileSync('$(OUTPUT)','utf8'); \
		if(!/^<!doctype html>/i.test(h)) { console.error('x missing doctype'); process.exit(1); } \
		const opens=(h.match(/<section/g)||[]).length, closes=(h.match(/<\/section>/g)||[]).length; \
		if(opens!==closes){console.error('x <section> tags unbalanced ('+opens+' vs '+closes+')');process.exit(1);} \
		console.log('OK - $(OUTPUT) looks well-formed ('+opens+' sections)');"

.PHONY: smoke
smoke: build ## End-to-end smoke test (boots the server in Docker and curls it)
	@NODE_IMAGE="$(NODE_IMAGE)" SERVE_SCRIPT="$(SERVE_SCRIPT)" bash $(SMOKE_SCRIPT)

.PHONY: check
check: validate-json validate-html verify smoke ## Run all checks (JSON, HTML, drift, smoke)

##@ Housekeeping

.PHONY: clean
clean: ## Remove generated artefacts
	@rm -f $(OUTPUT) .index.html.committed
	@echo "OK - cleaned"

.PHONY: doctor
doctor: ## Print tool versions and environment info
	@echo "host"
	@echo "  shell : $$SHELL"
	@echo "  cwd   : $$(pwd)"
	@echo "  docker: $$($(DOCKER) --version 2>/dev/null || echo 'missing')"
	@echo "  make  : $$($(MAKE) --version 2>/dev/null | head -n1 || echo 'missing')"
	@echo "container ($(NODE_IMAGE))"
	@$(DOCKER_RUN) node -e "console.log('  node  : '+process.version); console.log('  v8    : '+process.versions.v8);"

##@ Release

.PHONY: release
release: check ## Verify, build, and commit any regenerated index.html
	@$(MAKE) --no-print-directory build
	@if git diff --quiet -- $(OUTPUT); then \
		echo "OK - nothing to commit ($(OUTPUT) already up to date)"; \
	else \
		git add $(OUTPUT) $(SOURCES) $(STYLES); \
		git commit -m "build: regenerate $(OUTPUT)"; \
		echo "OK - committed regenerated $(OUTPUT)"; \
	fi



