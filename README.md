# www.leewilson.me

A small, static personal hub linking out to my professional, personal, and music profiles.

- **Live (custom domain):** https://www.leewilson.me
- **Apex (redirects to www):** https://leewilson.me -> https://www.leewilson.me (301)
- **Origin (GitHub Pages):** https://leewilson86.github.io
- **DNS / edge:** Cloudflare -> GitHub Pages, with `CNAME` set to `www.leewilson.me`.

## Stack

Plain, modern web: HTML5, CSS3 (custom properties, CSS grid, `dvh` units), no runtime JS framework. A tiny Node build step renders the static `index.html` from a JSON data file and an HTML template so content edits stay in one place.

```
.
├── index.html                    # ← generated; committed for GitHub Pages
├── 404.html                      # ← generated; custom Pages error page (served on any 404)
├── sitemap.xml                   # ← generated; advertised in robots.txt
├── og-image.png                  # ← generated; 1200x630 social preview (rsvg-convert)
├── robots.txt                    # crawler policy + sitemap pointer
├── styles.css                    # hand-written, dark theme (black / white / soft blues / grays)
├── CNAME                         # custom domain for GitHub Pages
├── _config.yml                   # Jekyll/Pages config: excludes source/tooling files from publication
├── LICENSE.md                    # MIT
├── src/                          # ← all build sources live here, away from served files
│   ├── data/
│   │   └── profile.json          # ← edit me: name, tagline, sections, links, 404 copy
│   ├── templates/
│   │   ├── index.template.html   # HTML shell for the home page
│   │   ├── 404.template.html     # HTML shell for the custom 404 page
│   │   └── og-image.svg          # source for og-image.png (rendered via `make og-image`)
│   └── scripts/
│       ├── build.mjs             # renders templates + data → index.html, 404.html, sitemap.xml
│       ├── serve.mjs             # zero-dep static server used by `make serve`
│       ├── smoke.sh              # end-to-end smoke test (`make smoke`)
│       └── icons.mjs             # brand SVG path data (Simple Icons, CC0)
├── .github/
│   └── workflows/
│       └── ci.yml                # GitHub Actions: runs `make check` on push + PR
├── package.json                  # `npm run build` / `npm run serve`
├── Makefile                      # convenience automation (build, serve, check, release…)
├── Dockerfile                    # pinned Node 24 LTS Alpine image
├── .dockerignore                 # files excluded from the Docker build context
├── .editorconfig                 # cross-IDE indentation / EOL / charset rules
├── .gitattributes                # text/binary handling, LF normalisation, linguist hints
├── .nvmrc                        # Node version pin for host devs (`24`)
├── .gitignore                    # OS / IDE (JetBrains, VS Code) / build noise
├── AGENTS.md                     # contract for AI agents working in this repo
└── README.md                     # you are here
```

The repo root holds only files that GitHub Pages serves directly
(`index.html`, `404.html`, `sitemap.xml`, `og-image.png`, `robots.txt`,
`styles.css`, `CNAME`), the Jekyll exclusion config (`_config.yml`), and
conventional top-level project files (`LICENSE.md`, `Makefile`, `Dockerfile`,
`README.md`, `AGENTS.md`, `package.json`, dotfiles). Everything under
`src/` is build-time source.

## Develop

**The only required tool on the host is Docker.** All Node, npm and serving
work happens inside a pinned `node:24-alpine` container, so the host's Node
version (or lack of one) does not matter.

```bash
make build         # render index.html (inside Docker)
make preview       # build, serve, and open http://127.0.0.1:8080
make check         # validate JSON, HTML, dashes, and drift
make doctor        # report host + container tool versions
make pull          # refresh the pinned Node image
make shell         # interactive shell in the pinned image
```

The first run pulls the Node image (~50 MB compressed) and caches it.

### Without Docker (optional)

If you prefer to run on the host directly, install Node.js **24 LTS** (see
`.nvmrc` / `engines` in `package.json`) and use the npm scripts:

```bash
npm run build      # node src/scripts/build.mjs   -> writes index.html
npm run serve      # node src/scripts/serve.mjs   -> http://localhost:8080
```

`src/scripts/serve.mjs` is a tiny zero-dependency static server using Node built-ins
only; there is nothing to install with `npm install`.

### Node version pin

| Where         | Value |
|---            |---|
| Container     | `node:24-alpine` (configurable via `NODE_IMAGE`) |
| Host fallback | `engines.node = ">=24 <25"` in `package.json`, `.nvmrc` = `24` |

For digest-level reproducibility, pin the container by SHA:

```bash
make build NODE_IMAGE=node:24-alpine@sha256:<digest>
```

### Make targets

A `Makefile` wraps the common tasks; every target that touches Node runs
inside the pinned container. Run `make` to see the full list:

| Target | What it does |
|---|---|
| `make build` | Render `index.html` from `src/data/` + `src/templates/` + `src/scripts/` (in Docker) |
| `make rebuild` | `clean` then `build` |
| `make watch` | Rebuild on file changes (requires `fswatch` on host: `brew install fswatch`) |
| `make serve` | Serve the site from a container on `http://127.0.0.1:8080` |
| `make preview` | `build` + `serve` + open the browser |
| `make pull` | Pull / refresh the pinned `node:24-alpine` image |
| `make shell` | Open an interactive shell inside the pinned image |
| `make verify` | Fail if committed `index.html` drifts from a fresh build |
| `make validate-json` | Check `src/data/profile.json` is well-formed |
| `make validate-html` | Quick structural sanity-check of `index.html` |
| `make smoke` | Boot the server in Docker, fetch `/` and `/styles.css`, assert HTTP 200 and key content |
| `make check` | All of the above validation checks |
| `make linkcheck` | Verify every outbound link in `index.html` returns 2xx/3xx (needs network; not in `make check`) |
| `make og-image` | Re-render `og-image.png` from `src/templates/og-image.svg` via Alpine + rsvg-convert |
| `make clean` | Remove generated artefacts |
| `make doctor` | Print host + container tool versions |
| `make release` | `check`, build, and commit a regenerated `index.html` (opt-in; only on explicit request) |

Override defaults inline, e.g. `make serve PORT=9000`, `make preview OPEN=xdg-open`,
or `make build NODE_IMAGE=node:24-alpine@sha256:<digest>`.

### Adding or changing a link

1. Edit `src/data/profile.json`.
2. If you need a new brand icon, add its 24×24 SVG path to `src/scripts/icons.mjs` and reference it by key in the JSON.
3. Run `make build` (or `npm run build`).
4. Commit both the data change **and** the regenerated `index.html`.

### Sections

Driven by `src/data/profile.json`. A section with `"hidden": true` is kept in the data
file but skipped at render time - handy for staging changes or temporarily taking
a group of links offline without losing them.

- **Professional** - *Where I work, build and ship.* (LinkedIn, GitHub)
- **Personal** *(currently hidden)* - *Where I post, share, and switch off.* (Facebook, X, Instagram, SoundCloud, YouTube)
- **Music - Maldini** - *Where we plug in and play the classics - '90s, '00s, and a few hidden gems.* (Website, Instagram, YouTube)

## Design

- Dark theme; palette is near-black backgrounds, white text, soft blue accents (`#5aa3ff` / `#82c0ff`) and cool grays.
- Subtle grid + radial-glow background for a "tech" feel; mono-spaced tagline and handles nod to both code and liner-notes typography.
- Fully responsive (CSS grid auto-fill, fluid type via `clamp()`), works without JS, honours `prefers-reduced-motion`, has a skip link and proper focus styles.
- Favicon is an inline data-URI SVG monogram - no extra request.

## Hosting

GitHub Pages serves the repo root as a static site. Cloudflare proxies the
domain in front of GitHub Pages. The `CNAME` file pins the custom host to
`www.leewilson.me` on the GitHub Pages side.

### Canonical host and apex redirect

The forced default host is **`www.leewilson.me`**. The apex
(`leewilson.me`) should 301-redirect to it. There are two supported ways
to wire that up:

1. **At Cloudflare (recommended when proxied through Cloudflare):** add a
   *Bulk Redirect* or *Redirect Rule* matching `leewilson.me/*` ->
   `https://www.leewilson.me/$1` with status `301`.
2. **At GitHub Pages directly:** point the apex `leewilson.me` `A`
   records at GitHub Pages' four IPs (185.199.108.153 / .109.153 /
   .110.153 / .111.153). With those in place, GitHub Pages itself will
   issue a 301 from the apex to the `CNAME` host.

Either approach works; pick whichever fits your Cloudflare setup. The
repo itself only needs `CNAME` (already set) and the canonical URLs
emitted by the build to use `https://www.leewilson.me/` (they do).

### Custom 404 page

GitHub Pages serves `/404.html` at the repo root as the error body for any
missing URL. This site's `404.html` is generated by the same build pipeline
as `index.html` (template at `src/templates/404.template.html`, copy under
the `notFound` key of `src/data/profile.json`) and matches the home page's
styling. To preview locally, hit any nonexistent path on `make serve` (the
local server mirrors the Pages behaviour: `404.html` is returned with status
404 on missing files).

GitHub Pages does not support custom error pages for other status codes
(403, 5xx, etc.); those still receive GitHub's defaults.

### Keeping source files off the public site

GitHub Pages runs Jekyll over the repository by default. Without configuration,
every file at the repo root would be reachable at `https://www.leewilson.me/<path>`
(for example `/package.json` or `/Makefile`). The `_config.yml` at the repo
root tells Jekyll to drop the build sources and tooling files from the
published site:

```yaml
exclude:
  - AGENTS.md
  - README.md
  - Dockerfile
  - Makefile
  - package.json
  - src/
```

Dotfiles (`.gitignore`, `.dockerignore`, `.editorconfig`, `.gitattributes`,
`.nvmrc`, `.idea/`, `.github/` etc.) are excluded by Jekyll's own defaults
and do not need an entry. Publicly reachable URLs at `www.leewilson.me` are
limited to: `/`, `/404.html`, `/styles.css`, `/robots.txt`, `/sitemap.xml`,
`/og-image.png`. `CNAME` is consumed by Pages itself.

When adding a new top-level file that is **not** meant to be served publicly,
add it to `_config.yml`'s `exclude:` list - or, better, put it under `src/`,
which is already excluded as a directory.

## Discoverability

- **JSON-LD `Person` schema** is rendered into `index.html` from `profile.json`
  so search engines and identity-graph consumers can resolve the page to a
  single entity (name, tagline, image, `sameAs` profile links).
- **`og-image.png`** (1200×630) and `twitter:card = summary_large_image`
  make link previews on Slack / LinkedIn / iMessage / X look correct. The
  PNG is generated from `src/templates/og-image.svg` via `make og-image`.
- **`robots.txt`** + **`sitemap.xml`** advertise the canonical URL.

## Continuous integration

`.github/workflows/ci.yml` runs the full `make check` pipeline (Docker
build + JSON/HTML validation + drift check + smoke test) on every push and
pull request to `master`. Actions are pinned by commit SHA per the
security note in `AGENTS.md`.

## License

Code is MIT. Brand marks belong to their respective owners; SVG paths used for brand icons are sourced from [Simple Icons](https://simpleicons.org) (CC0 1.0).




