# AGENTS.md

Operating contract for AI coding agents (e.g. GitHub Copilot) working in this repository.

## What this repo is

A **static** personal landing page for Lee Wilson, deployed via **GitHub Pages** at
`leewilson86.github.io` and served publicly at `https://leewilson.me` via Cloudflare.
The `CNAME` file pins the custom domain.

The site is rendered at build time from a small data file so the most common change
(adding / editing a link) is a one-file edit followed by a rebuild.

## Source of truth

| Concern | File |
|---|---|
| Page content (name, tagline, sections, links, handles, footer, 404 copy) | `src/data/profile.json` |
| HTML shell + meta tags (home) | `src/templates/index.template.html` |
| HTML shell for the custom 404 page | `src/templates/404.template.html` |
| Brand icon SVG paths (24×24 viewBox) | `src/scripts/icons.mjs` |
| Visual design | `styles.css` |
| Build orchestration | `src/scripts/build.mjs` |
| Local static server | `src/scripts/serve.mjs` (zero-dep, Node built-ins) |
| Automated smoke test | `src/scripts/smoke.sh` (boots server in Docker, asserts HTTP + content) |
| Generated outputs (committed, served by Pages) | `index.html`, `404.html` |
| Custom domain | `CNAME` |
| GitHub Pages / Jekyll config (exclusions) | `_config.yml` |
| Task automation | `Makefile` |
| Pinned dev/build runtime | `Dockerfile` (`node:24-alpine`), `.dockerignore` |
| Node version pin (host fallback) | `.nvmrc`, `engines` in `package.json` |

### Layout convention

The repo root holds **only** files that GitHub Pages serves directly
(`index.html`, `styles.css`, `CNAME`) plus conventional top-level project files
(`README.md`, `AGENTS.md`, `Makefile`, `Dockerfile`, `package.json`, dotfiles).
Everything that drives the build - data, templates, scripts - lives under
`src/`. When adding new build-time assets, put them under `src/`; only add a
file at the repo root if GitHub Pages needs to serve it (or tooling
conventionally requires it to be at the root).

GitHub Pages runs Jekyll over the repo by default. Anything at the root
that is not listed in `_config.yml`'s `exclude:` block will be reachable
at `https://leewilson.me/<path>`. **When adding a new top-level file
that is not meant to be served publicly, add it to the `exclude:` list
in `_config.yml`** (or, preferably, place it under `src/`, which is
already excluded as a directory). Dotfiles are excluded by Jekyll's
defaults and do not need an entry.

**Never hand-edit `index.html` or `404.html`.** They are generated. Edit the inputs, then run `make build` (or `npm run build`).

## Build / run

All Node-based work runs inside a pinned Docker container
(`node:24-alpine`, the current Node.js LTS line). The host only needs Docker;
the host's Node version is irrelevant.

```bash
make                # show all targets
make build          # render index.html (in Docker)
make preview        # build, serve, open the browser
make check          # validate JSON + HTML, drift check, automated smoke test
make smoke          # smoke test only (boots server in Docker, curls / and /styles.css)
make verify         # drift check only - useful in CI / pre-commit
make release        # check, build, commit regenerated index.html
make pull           # refresh the pinned Node image
make shell          # interactive shell inside the pinned image
make doctor         # print host + container tool versions
```

The npm scripts (`npm run build`, `npm run serve`) still work for anyone who
prefers running on the host directly; they require Node.js **24 LTS** locally
(see `.nvmrc` and `engines` in `package.json`).

`make verify` is the canonical way to perform step 1 of the workflow below
(detect hand-edits / out-of-date output). If it fails, the inputs and the
generated `index.html` are out of sync and must be reconciled before any
other change.

### Node version pin

| Layer | Pin |
|---|---|
| Container | `node:24-alpine`, overridable via `NODE_IMAGE` (digests welcome) |
| Host fallback | `engines.node = ">=24 <25"`, `.nvmrc` = `24` |

When a new Node.js LTS is released (next is Node 26, expected Oct 2026):
bump the `Dockerfile` `FROM`, `NODE_IMAGE` default in the `Makefile`,
`engines.node` range in `package.json`, and `.nvmrc` in lockstep, then
run `make doctor` and `make check`.

Requirements: Docker (host). No npm dependencies in the project itself; keep
it that way unless there's a strong reason.

## Required workflow for every change

1. Detect any manual edits the user has made since the last agent run:
   - Diff `index.html` against what `src/scripts/build.mjs` would currently produce
     (use `make verify`). If they differ in ways not explained by
     `src/data/profile.json` / `src/templates/` / `src/scripts/icons.mjs`, the user has
     hand-edited the output. Port those changes back into the **inputs** (data,
     template, icons, or styles) before doing anything else, then rebuild.
   - Check for new files (e.g. images, additional pages, workflows) and reflect
     them in `README.md` and, if they change the agent contract, in this `AGENTS.md`.
2. **Before editing**, grep the working tree for em dashes (U+2014) and en
   dashes (U+2013); if any have crept in since the last run, replace them with
   ASCII hyphens (`-`) and note this in the change summary. See the dash rule
   in *Conventions* below.
3. Make the requested change in the appropriate **input** file.
4. **Run `make check` after every edit.** This rebuilds `index.html` in the
   pinned Node container, validates JSON + HTML structure, performs the drift
   check, and runs the automated end-to-end smoke test (`src/scripts/smoke.sh`),
   which boots the static server in Docker and asserts HTTP 200 + key content.
   Do not yield control back to the user until `make check` passes.
5. Before yielding, grep once more for em/en dashes in any files touched (and
   in any new content authored) and remove any that slipped in.
6. **Do not run `git commit` or `git push` automatically.** Leave the working
   tree dirty (regenerated `index.html` / `404.html` alongside the input
   change) for the user to review and commit themselves. Only commit when the
   user explicitly asks for it ("commit", "release", "make release", etc.).
   `make release` is opt-in for this reason and must never be invoked
   without an explicit instruction.
7. Update `README.md` so it accurately describes the current state of the repo.
8. Update `AGENTS.md` if (and only if) the agent contract itself has changed -
   new skills, new conventions, new files agents need to know about, new
   constraints.

> The user has explicitly asked that `README.md` is reviewed/updated on **every** prompt,
> that `AGENTS.md` is updated whenever the agent's skills or this contract change,
> that `make check` (which includes the automated smoke test) is run after every edit,
> and that the agent **never commits to git without an explicit instruction**.

## Conventions

- **Static only.** No server-side code, no runtime JS frameworks, no build-time
  dependencies on npm packages. Plain Node built-ins in `scripts/`.
- **Accessibility:** every interactive element must be keyboard-focusable with a visible
  focus ring; provide `aria-label` on icon-only or ambiguous links; keep the skip link;
  respect `prefers-reduced-motion`.
- **Responsive:** layout must work from ~320px wide up to large desktops. Use fluid
  type (`clamp()`) and CSS grid auto-fill rather than hard-coded breakpoints where
  possible.
- **Browser support:** evergreen Chromium, Firefox, Safari (incl. iOS), Edge. No IE.
- **Palette:** near-black background, white text, soft blues (`#5aa3ff`, `#82c0ff`,
  `#3b6fb3`), cool grays. Don't introduce other accent hues without asking.
- **Icons:** prefer brand SVGs from Simple Icons (CC0). Add the raw `path d="…"` data
  to `src/scripts/icons.mjs` keyed by short lowercase name (`linkedin`, `github`, …) and
  reference it from `src/data/profile.json` via the link's `icon` field. Use a 24×24 viewBox.
- **Links:** open in a new tab with `rel="noopener noreferrer me"`. The `me` token
  signals personal-identity ownership (IndieAuth / rel-me).
- **HTML output:** keep it small, semantic, valid HTML5. No tracking scripts.
- **Secrets:** none in this repo, ever.
- **Copy / voice:** British English. Sentence case. End every strapline with a
  full stop. Section descriptions follow a parallel *"Where I/we [verb], [verb]
  and [verb]…"* three-beat pattern so the page reads consistently. Punctuation
  inside straplines follows the user's exact wording - do **not** "correct" the
  serial/Oxford comma in or out of an existing strapline; preserve it as
  written. Use apostrophes for elided decades (`'90s`, `'00s`) - never bare
  `90s`/`00s`. The build script HTML-escapes everything, so write plain
  characters in `src/data/profile.json`.
- **No em/en dashes, ever.** Never use em dashes (U+2014) or en dashes (U+2013)
  anywhere in this repo - use an ASCII hyphen (`-`) for asides instead. This
  rule applies to data, templates, scripts, styles, docs, generated output,
  commit messages, and any text the agent produces. There is no Make target
  enforcing this; **the agent is responsible for monitoring it on every
  prompt** - grep the working tree (or at least the files being edited) for
  U+2014/U+2013 before yielding control. See *Required workflow for every
  change*, steps 2 and 5.

## Profile categorisation (current intent)

- **Professional:** LinkedIn, GitHub.
- **Personal** *(currently `"hidden": true` in `src/data/profile.json` - data kept, not rendered):*
  Facebook, X, Instagram (`@leewilson86`), SoundCloud, YouTube (`@leejwilson`).
- **Music - Maldini:** band website (`maldiniband.co.uk`), Instagram (`@maldiniband`),
  YouTube (`@maldini8189`).

Any section in `src/data/profile.json` with `"hidden": true` is skipped by
`src/scripts/build.mjs` at render time. Use this to take a group of links offline
without losing its content. Do **not** delete hidden sections.

If the user adds a new account, ask which bucket it belongs in only if it isn't
obvious from context.

## Agent skills relevant to this repo

The agent is expected to be competent in:

- **HTML5 / semantic markup**, including OpenGraph and accessibility patterns
  (skip links, ARIA labelling, focus management).
- **Modern CSS:** custom properties, CSS grid & flexbox, `clamp()` fluid type,
  `dvh`/`svh` viewport units, `prefers-reduced-motion`, `color-scheme`, print styles.
- **Vanilla JavaScript / Node ESM** for small build tooling (`node:fs/promises`,
  `node:path`, `node:url`). No bundlers required.
- **SVG**, including hand-authoring 24×24 brand icons and inlining path data.
- **GitHub Pages + custom domains + Cloudflare** (apex/`www` handling, the role of
  `CNAME`, caching considerations), and the Jekyll defaults Pages applies -
  notably that everything at the repo root is published unless excluded via
  `_config.yml` (`exclude:`) or already hidden by Jekyll defaults (dotfiles,
  `node_modules`, etc.). Knows that Pages serves `/404.html` at the repo root
  on any not-found URL, that other status codes (403, 5xx) are not
  customisable, and that the 404 page must use absolute asset paths
  (e.g. `/styles.css`) because it is served for arbitrary URL depths.
- **Static-site discipline:** treating generated files as artefacts, keeping the
  source of truth in data + templates, and producing deterministic output.
- **Reviewing manual edits** to `index.html` / `styles.css` / `CNAME` and back-porting
  them into the appropriate source files before regenerating.
- **Typography policing:** actively grep for em dashes (U+2014) and en dashes
  (U+2013) on every prompt and replace them with ASCII hyphens. There is no
  Make target for this - the agent is the enforcement layer.
- **Smoke testing:** running `make check` (which includes `src/scripts/smoke.sh`)
  after every edit and only yielding once it passes; reading `[smoke]` output
  to diagnose regressions.
- **Documentation hygiene:** keeping `README.md` aligned with reality on every change.
- **GNU Make:** writing portable, self-documenting Makefiles with `.PHONY` targets,
  grouped `##@` sections, and `## help text` annotations.
- **Docker:** authoring small, pinned `Dockerfile`s (Alpine base, no
  unnecessary layers) and `.dockerignore` files; running one-shot tools via
  `docker run` with host-mounted volumes and matching UID/GID; understanding
  image tags vs digest pinning, port publishing, and shell interactivity flags
  (`-it`, `--rm`).

If a future task requires a skill not in this list (e.g. introducing a JS framework,
adding a blog, generating RSS), add it here as part of the same change.

















