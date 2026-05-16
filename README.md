# leewilson.me

A small, static personal hub linking out to my professional, personal, and music profiles.

- **Live (custom domain):** https://leewilson.me
- **Origin (GitHub Pages):** https://leewilson86.github.io
- **DNS / edge:** Cloudflare → GitHub Pages, with `CNAME` set to `www.leewilson.me`.

## Stack

Plain, modern web: HTML5, CSS3 (custom properties, CSS grid, `dvh` units), no runtime JS framework. A tiny Node build step renders the static `index.html` from a JSON data file and an HTML template so content edits stay in one place.

```
.
├── index.html                 # ← generated; committed for GitHub Pages
├── styles.css                 # hand-written, dark theme (black / white / soft blues / grays)
├── CNAME                      # custom domain for GitHub Pages
├── data/
│   └── profile.json           # ← edit me: name, tagline, sections, links
├── templates/
│   └── index.template.html    # HTML shell with {{PLACEHOLDERS}}
├── scripts/
│   ├── build.mjs              # renders template + data → index.html
│   ├── serve.mjs              # zero-dep static server used by `make serve`
│   ├── smoke.sh               # end-to-end smoke test (`make smoke`)
│   └── icons.mjs              # brand SVG path data (Simple Icons, CC0)
├── package.json               # `npm run build` / `npm run serve`
├── Makefile                   # convenience automation (build, serve, check, release…)
├── Dockerfile                 # pinned Node 24 LTS Alpine image
├── .dockerignore              # files excluded from the Docker build context
├── .nvmrc                     # Node version pin for host devs (`24`)
├── .gitignore                 # OS / IDE (JetBrains, VS Code) / build noise
├── AGENTS.md                  # contract for AI agents working in this repo
└── README.md                  # you are here
```

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
npm run build      # node scripts/build.mjs   -> writes index.html
npm run serve      # node scripts/serve.mjs   -> http://localhost:8080
```

`scripts/serve.mjs` is a tiny zero-dependency static server using Node built-ins
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
| `make build` | Render `index.html` from `data/` + `templates/` + `scripts/` (in Docker) |
| `make rebuild` | `clean` then `build` |
| `make watch` | Rebuild on file changes (requires `fswatch` on host: `brew install fswatch`) |
| `make serve` | Serve the site from a container on `http://127.0.0.1:8080` |
| `make preview` | `build` + `serve` + open the browser |
| `make pull` | Pull / refresh the pinned `node:24-alpine` image |
| `make shell` | Open an interactive shell inside the pinned image |
| `make verify` | Fail if committed `index.html` drifts from a fresh build |
| `make validate-json` | Check `data/profile.json` is well-formed |
| `make validate-html` | Quick structural sanity-check of `index.html` |
| `make smoke` | Boot the server in Docker, fetch `/` and `/styles.css`, assert HTTP 200 and key content |
| `make check` | All of the above validation checks |
| `make clean` | Remove generated artefacts |
| `make doctor` | Print host + container tool versions |
| `make release` | `check`, build, and commit a regenerated `index.html` |

Override defaults inline, e.g. `make serve PORT=9000`, `make preview OPEN=xdg-open`,
or `make build NODE_IMAGE=node:24-alpine@sha256:<digest>`.

### Adding or changing a link

1. Edit `data/profile.json`.
2. If you need a new brand icon, add its 24×24 SVG path to `scripts/icons.mjs` and reference it by key in the JSON.
3. Run `npm run build`.
4. Commit both the data change **and** the regenerated `index.html`.

### Sections

Driven by `data/profile.json`. A section with `"hidden": true` is kept in the data
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

GitHub Pages serves the repo root as a static site. Cloudflare proxies `leewilson.me` → `leewilson86.github.io`. The `CNAME` file pins the custom domain on the GitHub Pages side.

## License

Code is MIT. Brand marks belong to their respective owners; SVG paths used for brand icons are sourced from [Simple Icons](https://simpleicons.org) (CC0 1.0).




