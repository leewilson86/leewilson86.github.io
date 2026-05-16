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
OUTPUT_404     := 404.html
OUTPUT_SITEMAP := sitemap.xml
HTML_OUTPUTS   := $(OUTPUT) $(OUTPUT_404)
OUTPUTS        := $(HTML_OUTPUTS) $(OUTPUT_SITEMAP)
SRC_DIR        := src
TEMPLATE       := $(SRC_DIR)/templates/index.template.html
TEMPLATE_404   := $(SRC_DIR)/templates/404.template.html
DATA           := $(SRC_DIR)/data/profile.json
ICONS          := $(SRC_DIR)/scripts/icons.mjs
BUILD_SCRIPT   := $(SRC_DIR)/scripts/build.mjs
SERVE_SCRIPT   := $(SRC_DIR)/scripts/serve.mjs
SMOKE_SCRIPT   := $(SRC_DIR)/scripts/smoke.sh
STYLES         := styles.css

SOURCES        := $(DATA) $(TEMPLATE) $(TEMPLATE_404) $(ICONS) $(BUILD_SCRIPT)

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
build: $(OUTPUTS) ## Render index.html + 404.html + sitemap.xml from data + templates (inside Docker)

$(OUTPUTS): $(SOURCES)
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
verify: ## Fail if any committed generated file drifts from a fresh build
	@for f in $(OUTPUTS); do cp "$$f" ".$$f.committed"; done
	@$(DOCKER_RUN) node $(BUILD_SCRIPT) >/dev/null
	@status=0; for f in $(OUTPUTS); do \
		if ! diff -q ".$$f.committed" "$$f" >/dev/null; then \
			echo "x $$f is out of date with its inputs."; \
			diff -u ".$$f.committed" "$$f" | sed -n '1,40p'; \
			mv ".$$f.committed" "$$f"; \
			status=1; \
		else \
			rm -f ".$$f.committed"; \
		fi; \
	done; \
	if [ $$status -eq 0 ]; then \
		echo "OK - generated files in sync with inputs."; \
	else \
		echo "  Run 'make build' and commit the result."; exit 1; \
	fi

.PHONY: validate-json
validate-json: ## Validate src/data/profile.json is well-formed JSON
	@$(DOCKER_RUN) node -e "JSON.parse(require('fs').readFileSync('$(DATA)','utf8')); console.log('OK - $(DATA) is valid JSON')"

.PHONY: validate-html
validate-html: build ## Quick sanity-check that generated HTML files look well-formed
	@for f in $(HTML_OUTPUTS); do \
		$(DOCKER_RUN) node -e "const h=require('fs').readFileSync('$$f','utf8'); \
			if(!/^<!doctype html>/i.test(h)) { console.error('x missing doctype in $$f'); process.exit(1); } \
			const opens=(h.match(/<section/g)||[]).length, closes=(h.match(/<\/section>/g)||[]).length; \
			if(opens!==closes){console.error('x <section> tags unbalanced in $$f ('+opens+' vs '+closes+')');process.exit(1);} \
			console.log('OK - $$f looks well-formed ('+opens+' sections)');"; \
	done

.PHONY: smoke
smoke: build ## End-to-end smoke test (boots the server in Docker and curls it)
	@NODE_IMAGE="$(NODE_IMAGE)" SERVE_SCRIPT="$(SERVE_SCRIPT)" bash $(SMOKE_SCRIPT)

.PHONY: check
check: validate-json validate-html verify smoke ## Run all checks (JSON, HTML, drift, smoke)

##@ Housekeeping

.PHONY: clean
clean: ## Remove generated artefacts
	@rm -f $(OUTPUTS) .index.html.committed .404.html.committed
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
release: check ## Verify, build, and commit any regenerated outputs
	@$(MAKE) --no-print-directory build
	@if git diff --quiet -- $(OUTPUTS); then \
		echo "OK - nothing to commit (generated files already up to date)"; \
	else \
		git add $(OUTPUTS) $(SOURCES) $(STYLES); \
		git commit -m "build: regenerate $(OUTPUT) + $(OUTPUT_404)"; \
		echo "OK - committed regenerated outputs"; \
	fi



