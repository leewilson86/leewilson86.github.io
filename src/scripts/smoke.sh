#!/usr/bin/env bash
# scripts/smoke.sh - end-to-end smoke test for leewilson.me
#
# Boots the static server in the pinned Node container, fetches a few key
# URLs, and asserts the response status, size, and content. Designed to be
# fast (a few seconds) and safe to run after every edit.
#
# Environment overrides:
#   NODE_IMAGE    - container image to use (default: node:24-alpine)
#   SMOKE_PORT    - host port to publish (default: 18080)
#   SERVE_SCRIPT  - path (relative to repo root) of the serve script
#                   (default: src/scripts/serve.mjs)

set -euo pipefail

NODE_IMAGE="${NODE_IMAGE:-node:24-alpine}"
SMOKE_PORT="${SMOKE_PORT:-18080}"
SERVE_SCRIPT="${SERVE_SCRIPT:-src/scripts/serve.mjs}"
NAME="lw-smoke-$$"
TMP_BODY="$(mktemp -t lw-smoke.XXXXXX)"

log() { printf '[smoke] %s\n' "$*"; }
fail() { printf '[smoke] x %s\n' "$*" >&2; exit 1; }

cleanup() {
  docker stop "$NAME" >/dev/null 2>&1 || true
  rm -f "$TMP_BODY"
}
trap cleanup EXIT INT TERM

log "starting $NODE_IMAGE on 127.0.0.1:${SMOKE_PORT}"
docker run -d --rm --name "$NAME" \
  -u "$(id -u):$(id -g)" \
  -v "$PWD":/app -w /app \
  -p "127.0.0.1:${SMOKE_PORT}:8080" \
  -e HOST=0.0.0.0 -e PORT=8080 \
  "$NODE_IMAGE" node "$SERVE_SCRIPT" >/dev/null

# Wait up to ~5s for the server to start responding.
ready=0
for _ in $(seq 1 25); do
  if curl -fsS -o /dev/null "http://127.0.0.1:${SMOKE_PORT}/"; then ready=1; break; fi
  sleep 0.2
done
[ "$ready" -eq 1 ] || fail "server did not become ready"

assert_url() {
  local path="$1" min_bytes="$2"
  local code size
  code=$(curl -s -o "$TMP_BODY" -w '%{http_code}' "http://127.0.0.1:${SMOKE_PORT}${path}")
  size=$(wc -c < "$TMP_BODY" | tr -d ' ')
  [ "$code" = "200" ] || fail "GET ${path} -> HTTP ${code} (expected 200)"
  [ "$size" -ge "$min_bytes" ] || fail "GET ${path} -> only ${size} bytes (expected >= ${min_bytes})"
  log "OK  GET ${path} -> HTTP ${code}, ${size} bytes"
}

assert_contains() {
  local needle="$1"
  grep -q -- "$needle" "$TMP_BODY" || fail "response is missing expected content: ${needle}"
}

assert_missing() {
  local needle="$1"
  ! grep -q -- "$needle" "$TMP_BODY" || fail "response unexpectedly contains: ${needle}"
}

# --- index.html ------------------------------------------------------------
assert_url "/" 2000
assert_contains "<title>Lee Wilson"
assert_contains "leewilson86"
assert_contains "maldini"
# Personal section is currently hidden in data/profile.json; assert it stays out.
assert_missing 'id="personal"'

# --- styles.css ------------------------------------------------------------
assert_url "/styles.css" 1000

# --- 404 path --------------------------------------------------------------
not_found=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${SMOKE_PORT}/does-not-exist")
[ "$not_found" = "404" ] || fail "GET /does-not-exist -> HTTP ${not_found} (expected 404)"
log "OK  GET /does-not-exist -> HTTP 404"

log "all smoke assertions passed"

