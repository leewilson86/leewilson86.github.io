#!/usr/bin/env node
// Tiny static file server using Node built-ins only.
// Used by `make serve` (in-container) and `npm run serve` (on host).
//
// Environment:
//   PORT  - port to bind (default 8080)
//   HOST  - interface to bind (default 127.0.0.1; container default is 0.0.0.0)

import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize, resolve, sep } from 'node:path';

const root = resolve(process.cwd());
const port = Number(process.env.PORT || 8080);
const host = process.env.HOST || '127.0.0.1';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
  '.js':   'text/javascript; charset=utf-8',
  '.mjs':  'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg':  'image/svg+xml',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico':  'image/x-icon',
  '.txt':  'text/plain; charset=utf-8',
  '.xml':  'application/xml; charset=utf-8',
  '.map':  'application/json; charset=utf-8',
};

const send = (res, status, body, headers = {}) => {
  res.writeHead(status, { 'Content-Type': 'text/plain; charset=utf-8', ...headers });
  res.end(body);
};

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    let pathname = decodeURIComponent(url.pathname);
    if (pathname.endsWith('/')) pathname += 'index.html';

    const filePath = resolve(join(root, normalize(pathname)));
    // Refuse anything trying to escape the document root.
    if (filePath !== root && !filePath.startsWith(root + sep)) {
      return send(res, 403, 'Forbidden');
    }

    const info = await stat(filePath).catch(() => null);
    if (!info || !info.isFile()) {
      // Mirror GitHub Pages behaviour: serve /404.html with status 404 on any
      // missing path, falling back to plain text if the custom page is absent.
      const nfPath = join(root, '404.html');
      const nfInfo = await stat(nfPath).catch(() => null);
      if (nfInfo && nfInfo.isFile()) {
        const body = await readFile(nfPath);
        res.writeHead(404, {
          'Content-Type': 'text/html; charset=utf-8',
          'Content-Length': body.length,
          'Cache-Control': 'no-cache',
          'X-Content-Type-Options': 'nosniff',
        });
        return res.end(body);
      }
      return send(res, 404, 'Not Found');
    }

    const body = await readFile(filePath);
    const type = MIME[extname(filePath).toLowerCase()] || 'application/octet-stream';
    res.writeHead(200, {
      'Content-Type': type,
      'Content-Length': body.length,
      'Cache-Control': 'no-cache',
      'X-Content-Type-Options': 'nosniff',
    });
    res.end(body);
  } catch (err) {
    console.error('[serve]', err);
    send(res, 500, 'Internal Server Error');
  }
});

server.listen(port, host, () => {
  console.log(`[serve] ${root}`);
  console.log(`[serve] http://${host === '0.0.0.0' ? '127.0.0.1' : host}:${port}/`);
});

const shutdown = (sig) => () => {
  console.log(`\n[serve] ${sig} received, shutting down`);
  server.close(() => process.exit(0));
};
process.on('SIGINT',  shutdown('SIGINT'));
process.on('SIGTERM', shutdown('SIGTERM'));

