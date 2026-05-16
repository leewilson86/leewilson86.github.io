# Pinned to the current Node.js LTS line (24 "Jod") on Alpine.
# Updating policy: bump the major when a new LTS is released, then run
# `make doctor` and `make check` to confirm. For stricter reproducibility,
# pin by digest, e.g.  FROM node:24-alpine@sha256:<digest>
FROM node:24-alpine

# Static-site sanity defaults.
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=8080

WORKDIR /app

# This repo has zero npm runtime/build dependencies (Node built-ins only),
# so there is nothing to install. We just bake in a clean working directory.
# Sources are mounted in via a volume at run time so edits are picked up
# without rebuilding the image.

EXPOSE 8080

# Default command: serve the (already-built) site.
# Override in `docker run` for one-shot builds, e.g.:
#   docker run --rm -v "$PWD":/app -w /app leewilson-me node scripts/build.mjs
CMD ["node", "scripts/serve.mjs"]

