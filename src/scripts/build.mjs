#!/usr/bin/env node
// Static site builder for leewilson.me
// Reads src/data/profile.json + src/templates/index.template.html and writes index.html.
// Run: `npm run build`

import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { icons } from './icons.mjs';

// This script lives at src/scripts/build.mjs; the repo root is two levels up.
const here = dirname(fileURLToPath(import.meta.url));
const srcDir = join(here, '..');
const root = join(srcDir, '..');
// Canonical site URL. Single source of truth for the host - injected into
// templates as {{SITE_URL}} so og:url, canonical, etc. all stay in sync.
// Trailing slash is significant (used as a base in templates).
const SITE_URL = 'https://leewilson.me/';

const escapeHtml = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));

const renderIcon = (name) => {
  const path = icons[name];
  if (!path) {
    console.warn(`[build] Missing icon: ${name}`);
    return '';
  }
  return `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="${path}"/></svg>`;
};

const renderLink = (link) => `
        <li>
          <a class="card" href="${escapeHtml(link.url)}" target="_blank" rel="noopener noreferrer me" aria-label="${escapeHtml(link.label)} - opens in new tab">
            <span class="card-icon" data-icon="${escapeHtml(link.icon)}">${renderIcon(link.icon)}</span>
            <span class="card-text">
              <span class="card-label">${escapeHtml(link.label)}</span>
              ${link.handle ? `<span class="card-handle">${escapeHtml(link.handle)}</span>` : ''}
            </span>
            <svg class="card-arrow" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M7 17 17 7M9 7h8v8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
          </a>
        </li>`;

const renderSection = (section) => `
    <section class="section" id="${escapeHtml(section.id)}" aria-labelledby="${escapeHtml(section.id)}-title">
      <div class="section-head">
        <h2 id="${escapeHtml(section.id)}-title">${escapeHtml(section.title)}</h2>
        ${section.description ? `<p>${escapeHtml(section.description)}</p>` : ''}
      </div>
      <ul class="grid-links" role="list">${section.links.map(renderLink).join('')}
      </ul>
    </section>`;

const build = async () => {
  const data = JSON.parse(await readFile(join(srcDir, 'data/profile.json'), 'utf8'));
  const indexTmpl = await readFile(join(srcDir, 'templates/index.template.html'), 'utf8');
  const nfTmpl    = await readFile(join(srcDir, 'templates/404.template.html'), 'utf8');

  const indexHtml = indexTmpl
    .replaceAll('{{SITE_URL}}', SITE_URL)
    .replaceAll('{{NAME}}', escapeHtml(data.name))
    .replaceAll('{{TAGLINE}}', escapeHtml(data.tagline))
    .replaceAll('{{INTRO}}', escapeHtml(data.intro))
    .replaceAll('{{FOOTER}}', escapeHtml(data.footer))
    .replace('{{SECTIONS}}', data.sections.filter((s) => !s.hidden).map(renderSection).join('\n'));

  const nf = data.notFound || {};
  const nfHtml = nfTmpl
    .replaceAll('{{NAME}}', escapeHtml(data.name))
    .replaceAll('{{FOOTER}}', escapeHtml(data.footer))
    .replaceAll('{{NF_CODE}}',    escapeHtml(nf.code    || '404'))
    .replaceAll('{{NF_TITLE}}',   escapeHtml(nf.title   || 'Page not found'))
    .replaceAll('{{NF_MESSAGE}}', escapeHtml(nf.message || "That URL doesn't lead anywhere on this site."))
    .replaceAll('{{NF_CTA}}',     escapeHtml(nf.cta     || 'Back to the homepage'));

  await writeFile(join(root, 'index.html'), indexHtml, 'utf8');
  await writeFile(join(root, '404.html'),   nfHtml,    'utf8');

  const visible = data.sections.filter((s) => !s.hidden);
  const hidden  = data.sections.length - visible.length;
  console.log(`[build] wrote index.html (${visible.length} sections${hidden ? `, ${hidden} hidden` : ''}, ${visible.reduce((n, s) => n + s.links.length, 0)} links)`);
  console.log(`[build] wrote 404.html  (custom GitHub Pages error page)`);
};

build().catch((err) => {
  console.error(err);
  process.exit(1);
});



