#!/usr/bin/env node
// seokit extractor: fetches pages and reports what is on them as JSON.
// It judges nothing; the verdicts belong to the agent reading the check catalog.
// Node 18+, no dependencies. Page scripts are read as text and never executed.
//
//   node extract.mjs extract <url>... [--origin <prod-url>] [--ua <s>] [--html <file> --base <url>]
//   node extract.mjs crawl <start-url> [--cap 100] [--depth 3] [--delay <ms>] [--local]
//                                      [--origin <prod-url>] [--out <file>] [--full]
//   node extract.mjs robots <url> [--agents a,b,c]

import { readFileSync, writeFileSync } from "node:fs";
import { gunzipSync } from "node:zlib";

const UA = "Mozilla/5.0 (compatible; seokit/1.0; +https://github.com/mimukit/skills)";
const TIMEOUT_MS = 20000;
const MAX_BYTES = 5 * 1024 * 1024;
const MAX_REDIRECTS = 10;
const LIST_CAP = { links: 300, images: 100, insecure: 50, headings: 100 };

const AGENTS = [
  "Googlebot", "Bingbot", "OAI-SearchBot", "ChatGPT-User", "GPTBot",
  "Claude-SearchBot", "Claude-User", "ClaudeBot", "PerplexityBot", "Perplexity-User",
  "Google-Extended", "Applebot-Extended", "CCBot",
];

// Dev-only markers: a hot-reload or live-reload client in the served HTML.
const DEV_MARKERS = [
  ["@vite/client", /\/@vite\/client/],
  ["react-refresh", /@react-refresh|react-refresh(?:-runtime)?(?:\.js)?/],
  ["webpack-hmr", /__webpack_hmr|webpack-hmr|webpack-dev-server/],
  ["next-dev-build-id", /"buildId"\s*:\s*"development"/],
  ["next-dev-chunks", /\/_next\/static\/chunks\/(?:webpack|main-app)\.js\?v=\d+/],
  ["next-devtools", /next-devtools/],
  ["hmr-client", /hmr-client/],
  ["livereload", /livereload\.js/],
  ["eleventy-reload", /\/\.11ty\/reload-client\.js/],
  ["astro-dev-toolbar", /astro-dev-toolbar|\/@id\/astro:/],
];

// ---------- arguments ----------

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) out[key] = true;
      else { out[key] = next; i++; }
    } else out._.push(a);
  }
  return out;
}

// ---------- fetching ----------

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function fetchRaw(url, ua) {
  const res = await fetch(url, {
    redirect: "manual",
    headers: { "user-agent": ua, accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" },
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  return res;
}

async function readBody(res) {
  const buf = Buffer.from(await res.arrayBuffer());
  return buf.length > MAX_BYTES ? buf.subarray(0, MAX_BYTES) : buf;
}

// Follow redirects by hand so every hop is recorded.
async function fetchPage(url, ua) {
  const chain = [];
  let current = url;
  const started = Date.now();
  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    const res = await fetchRaw(current, ua);
    if (res.status >= 300 && res.status < 400 && res.headers.get("location")) {
      const next = new URL(res.headers.get("location"), current).href;
      chain.push({ url: current, status: res.status, location: next });
      await res.arrayBuffer().catch(() => {});
      current = next;
      continue;
    }
    const body = await readBody(res);
    return { finalUrl: current, status: res.status, headers: res.headers, body, chain, ms: Date.now() - started };
  }
  throw new Error(`more than ${MAX_REDIRECTS} redirects`);
}

async function fetchText(url, ua) {
  try {
    const p = await fetchPage(url, ua);
    let buf = p.body;
    if (buf[0] === 0x1f && buf[1] === 0x8b) buf = gunzipSync(buf);
    return { status: p.status, finalUrl: p.finalUrl, text: buf.toString("utf8") };
  } catch (e) {
    return { status: 0, error: String(e.message || e), text: "" };
  }
}

// ---------- tolerant HTML scanning ----------

const ATTRS = String.raw`((?:\s+[^\s"'>\/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>\x60]+))?)*)\s*\/?`;

function openTagRe(name) {
  return new RegExp(`<(${name})\\b${ATTRS}>`, "gi");
}

function decode(s) {
  return String(s ?? "")
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => safeChar(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => safeChar(parseInt(d, 10)))
    .replace(/&nbsp;/g, " ")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&");
}

function safeChar(n) {
  try { return String.fromCodePoint(n); } catch { return ""; }
}

function parseAttrs(s) {
  const attrs = {};
  const re = /([^\s"'>\/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g;
  let m;
  while ((m = re.exec(s || ""))) {
    const key = m[1].toLowerCase();
    if (!(key in attrs)) attrs[key] = decode(m[2] ?? m[3] ?? m[4] ?? "");
  }
  return attrs;
}

function tags(html, name) {
  const out = [];
  const re = openTagRe(name);
  let m;
  while ((m = re.exec(html))) out.push({ name: m[1].toLowerCase(), attrs: parseAttrs(m[2]), index: m.index });
  return out;
}

// Elements with inner content. Assumes no nesting of the same element,
// which holds for a, title, h1-h6, and script.
function elements(html, name) {
  const out = [];
  const re = openTagRe(name);
  let m;
  while ((m = re.exec(html))) {
    const tag = m[1].toLowerCase();
    const start = m.index + m[0].length;
    const close = new RegExp(`</${tag}\\s*>`, "i");
    const rest = html.slice(start);
    const c = rest.search(close);
    const inner = c === -1 ? "" : rest.slice(0, c);
    out.push({ name: tag, attrs: parseAttrs(m[2]), inner, index: m.index });
    if (c !== -1) re.lastIndex = start + c;
  }
  return out;
}

function stripBlocks(html, names) {
  let out = html;
  for (const n of names) out = out.replace(new RegExp(`<${n}\\b[\\s\\S]*?</${n}\\s*>`, "gi"), " ");
  return out;
}

function textOf(html) {
  return decode(html.replace(/<[^>]+>/g, " ")).replace(/\s+/g, " ").trim();
}

function wordCount(text) {
  return text ? text.split(/\s+/).filter(Boolean).length : 0;
}

function collectTypes(node, out) {
  if (Array.isArray(node)) { node.forEach((n) => collectTypes(n, out)); return; }
  if (!node || typeof node !== "object") return;
  const t = node["@type"];
  if (t) (Array.isArray(t) ? t : [t]).forEach((x) => out.add(String(x)));
  for (const v of Object.values(node)) if (v && typeof v === "object") collectTypes(v, out);
}

function sameSite(a, b) {
  return a.replace(/^www\./, "") === b.replace(/^www\./, "");
}

// ---------- page extraction ----------

function analyze(html, baseUrl, opts = {}) {
  const base = new URL(baseUrl);
  const prodHost = opts.origin ? new URL(opts.origin).hostname : null;
  const noComments = html.replace(/<!--[\s\S]*?-->/g, " ");

  const scripts = elements(noComments, "script");
  const devMarkers = [];
  for (const [name, re] of DEV_MARKERS) {
    const m = html.match(re);
    if (m) devMarkers.push({ marker: name, evidence: m[0].slice(0, 120) });
  }

  const jsonLd = [];
  for (const s of scripts) {
    if (!/ld\+json/i.test(s.attrs.type || "")) continue;
    const raw = s.inner.replace(/^\s*(?:<!\[CDATA\[|<!--)/, "").replace(/(?:\]\]>|-->)\s*$/, "").trim();
    const block = { types: [], error: null, json: raw.length > 20000 ? raw.slice(0, 20000) + "…[truncated]" : raw };
    try {
      const types = new Set();
      collectTypes(JSON.parse(raw), types);
      block.types = [...types];
    } catch (e) { block.error = String(e.message); }
    jsonLd.push(block);
  }

  const clean = stripBlocks(noComments, ["script", "style", "template", "noscript"]);
  const headEnd = clean.search(/<\/head\s*>/i);
  const head = headEnd === -1 ? clean : clean.slice(0, headEnd);
  const bodyStart = clean.search(/<body\b/i);
  const bodyHtml = stripBlocks(bodyStart === -1 ? clean : clean.slice(bodyStart), ["svg"]);

  const titles = elements(head, "title").map((t) => textOf(t.inner));
  const metas = tags(clean, "meta").map((t) => t.attrs);
  const metaBy = (key, val) => metas.filter((m) => (m[key] || "").toLowerCase() === val);
  const description = metaBy("name", "description").map((m) => m.content ?? "");
  const robotsMeta = metas
    .filter((m) => /^(robots|googlebot|bingbot|googlebot-news)$/i.test(m.name || ""))
    .map((m) => ({ name: m.name.toLowerCase(), content: m.content ?? "" }));
  const og = {};
  const twitter = {};
  for (const m of metas) {
    const p = (m.property || m.name || "").toLowerCase();
    if (p.startsWith("og:")) og[p] = m.content ?? "";
    if (p.startsWith("twitter:")) twitter[p] = m.content ?? "";
  }

  const linkTags = tags(clean, "link").map((t) => t.attrs);
  const rel = (l) => (l.rel || "").toLowerCase().split(/\s+/);
  const canonicals = linkTags.filter((l) => rel(l).includes("canonical")).map((l) => abs(l.href, base));
  const hreflang = linkTags
    .filter((l) => rel(l).includes("alternate") && l.hreflang)
    .map((l) => ({ hreflang: l.hreflang, href: abs(l.href, base) }));
  const alternates = linkTags
    .filter((l) => rel(l).includes("alternate") && !l.hreflang && l.type)
    .map((l) => ({ type: l.type, href: abs(l.href, base) }));

  const htmlTag = tags(clean, "html")[0];
  const viewport = metaBy("name", "viewport").map((m) => m.content ?? "")[0] ?? null;

  const headings = elements(bodyHtml, "h[1-6]")
    .map((h) => ({ level: Number(h.name[1]), text: textOf(h.inner).slice(0, 200) }));

  const links = [];
  let jsOnlyLinks = 0;
  let fragmentLinks = 0;
  for (const a of elements(bodyHtml, "a")) {
    const href = a.attrs.href;
    // No href, `javascript:`, or a bare `#` only works through a script handler.
    if (href === undefined || /^\s*(javascript:|#\s*$)/i.test(href)) { jsOnlyLinks++; continue; }
    if (/^\s*#/.test(href)) { fragmentLinks++; continue; }
    if (/^\s*(mailto:|tel:|sms:|data:)/i.test(href)) continue;
    const url = abs(href, base);
    if (!url) continue;
    const u = new URL(url);
    let text = textOf(a.inner);
    if (!text) text = (tags(a.inner, "img")[0]?.attrs.alt || a.attrs["aria-label"] || a.attrs.title || "").trim();
    const internal = sameSite(u.hostname, base.hostname) || (prodHost && sameSite(u.hostname, prodHost));
    links.push({ href: url, text: text.slice(0, 120), internal: Boolean(internal), rel: a.attrs.rel || undefined });
  }

  const images = tags(bodyHtml, "img").map((t) => ({
    src: abs(t.attrs.src || t.attrs["data-src"] || "", base),
    alt: "alt" in t.attrs ? t.attrs.alt : null,
    width: t.attrs.width ?? null,
    height: t.attrs.height ?? null,
    loading: t.attrs.loading ?? null,
    fetchpriority: t.attrs.fetchpriority ?? null,
    srcset: Boolean(t.attrs.srcset),
  }));

  const insecure = [];
  if (base.protocol === "https:") {
    for (const [name, key] of [["img", "src"], ["script", "src"], ["iframe", "src"], ["link", "href"], ["source", "src"]]) {
      for (const t of tags(noComments, name)) {
        const v = t.attrs[key];
        if (v && /^http:\/\//i.test(v) && (name !== "link" || /stylesheet|preload|icon/i.test(t.attrs.rel || ""))) insecure.push(v);
      }
    }
  }

  const bodyText = textOf(bodyHtml);
  const appRootIds = tags(bodyHtml, "div")
    .map((t) => t.attrs.id)
    .filter((id) => id && /^(root|app|__next|__nuxt|svelte|q-app)$/i.test(id));

  return {
    lang: htmlTag?.attrs.lang ?? null,
    titles,
    description,
    robotsMeta,
    canonicals,
    viewport,
    og,
    twitter,
    hreflang,
    alternates,
    headings: headings.slice(0, LIST_CAP.headings),
    h1Count: headings.filter((h) => h.level === 1).length,
    jsonLd,
    microdataTypes: [...new Set(tags(bodyHtml, "[a-z0-9-]+").map((t) => t.attrs.itemtype).filter(Boolean))],
    links: links.slice(0, LIST_CAP.links),
    linkCounts: { internal: links.filter((l) => l.internal).length, external: links.filter((l) => !l.internal).length, jsOnly: jsOnlyLinks, fragment: fragmentLinks },
    images: images.slice(0, LIST_CAP.images),
    imageCount: images.length,
    insecureResources: insecure.slice(0, LIST_CAP.insecure),
    rawWordCount: wordCount(bodyText),
    textPreview: bodyText.slice(0, 400),
    appRootIds,
    devMarkers,
  };
}

function abs(href, base) {
  try {
    const u = new URL(String(href).trim(), base);
    if (!/^https?:$/.test(u.protocol)) return null;
    u.hash = "";
    return u.href;
  } catch { return null; }
}

const HEADER_KEYS = ["content-type", "x-robots-tag", "link", "cache-control", "strict-transport-security", "vary", "server", "content-language"];

async function extractUrl(url, opts) {
  const record = { requestedUrl: url };
  try {
    const p = await fetchPage(url, opts.ua || UA);
    record.finalUrl = p.finalUrl;
    record.status = p.status;
    record.redirectChain = p.chain;
    record.responseMs = p.ms;
    record.bytes = p.body.length;
    record.headers = {};
    for (const k of HEADER_KEYS) { const v = p.headers.get(k); if (v) record.headers[k] = v; }
    record.xRobotsTag = p.headers.get("x-robots-tag");
    const type = p.headers.get("content-type") || "";
    if (/html|xml/i.test(type) || !type) Object.assign(record, analyze(p.body.toString("utf8"), p.finalUrl, opts));
    else record.nonHtml = type;
  } catch (e) {
    record.status = 0;
    record.error = String(e.message || e);
  }
  return record;
}

// ---------- robots.txt (RFC 9309 matching) ----------

function parseRobots(text) {
  const groups = [];
  const sitemaps = [];
  let current = null;
  let lastWasAgent = false;
  for (const line of text.split(/\r?\n/)) {
    const clean = line.replace(/#.*$/, "").trim();
    const m = clean.match(/^([A-Za-z-]+)\s*:\s*(.*)$/);
    if (!m) continue;
    const key = m[1].toLowerCase();
    const val = m[2].trim();
    if (key === "user-agent") {
      if (!lastWasAgent) { current = { agents: [], rules: [] }; groups.push(current); }
      current.agents.push(val.toLowerCase());
      lastWasAgent = true;
    } else if (key === "allow" || key === "disallow") {
      if (current) current.rules.push({ allow: key === "allow", path: val });
      lastWasAgent = false;
    } else if (key === "sitemap") {
      sitemaps.push(val);
      lastWasAgent = false;
    } else lastWasAgent = false;
  }
  return { groups, sitemaps };
}

function ruleMatches(pattern, path) {
  if (!pattern) return false;
  const anchored = pattern.endsWith("$");
  const body = anchored ? pattern.slice(0, -1) : pattern;
  const re = new RegExp("^" + body.split("*").map((s) => s.replace(/[.+?^${}()|[\]\\]/g, "\\$&")).join(".*") + (anchored ? "$" : ""));
  return re.test(path);
}

function robotsVerdict(parsed, agent, path) {
  const token = agent.toLowerCase();
  let groups = parsed.groups.filter((g) => g.agents.includes(token));
  let matchedGroup = agent;
  if (!groups.length) { groups = parsed.groups.filter((g) => g.agents.includes("*")); matchedGroup = groups.length ? "*" : null; }
  let best = null;
  for (const g of groups) for (const r of g.rules) {
    if (!ruleMatches(r.path, path)) continue;
    const len = r.path.length;
    if (!best || len > best.path.length || (len === best.path.length && r.allow && !best.allow)) best = r;
  }
  return { agent, group: matchedGroup, allowed: best ? best.allow : true, rule: best ? `${best.allow ? "Allow" : "Disallow"}: ${best.path}` : null };
}

async function robotsFor(url, ua, agents) {
  const u = new URL(url);
  const robotsUrl = `${u.origin}/robots.txt`;
  const r = await fetchText(robotsUrl, ua);
  const exists = r.status >= 200 && r.status < 300;
  const parsed = parseRobots(exists ? r.text : "");
  const path = u.pathname + u.search;
  return {
    robotsUrl,
    status: r.status,
    error: r.error,
    exists,
    sitemaps: parsed.sitemaps,
    groups: parsed.groups.map((g) => ({ agents: g.agents, rules: g.rules.length })),
    path,
    agents: agents.map((a) => robotsVerdict(parsed, a, path)),
    text: exists ? r.text.slice(0, 8000) : null,
    parsed,
  };
}

// ---------- sitemaps ----------

async function collectSitemap(startUrls, ua, limits = { maps: 50, urls: 50000 }) {
  const queue = [...startUrls];
  const seen = new Set();
  const urls = new Set();
  const fetched = [];
  while (queue.length && seen.size < limits.maps) {
    const sm = queue.shift();
    if (seen.has(sm)) continue;
    seen.add(sm);
    const r = await fetchText(sm, ua);
    fetched.push({ url: sm, status: r.status, error: r.error });
    if (r.status !== 200) continue;
    const locs = [...r.text.matchAll(/<loc>\s*(?:<!\[CDATA\[)?\s*([\s\S]*?)\s*(?:\]\]>)?\s*<\/loc>/gi)].map((m) => decode(m[1]));
    if (/<sitemapindex\b/i.test(r.text)) queue.push(...locs);
    else for (const l of locs) { if (urls.size >= limits.urls) break; urls.add(l); }
  }
  return { sitemaps: fetched, urls: [...urls] };
}

// ---------- crawl ----------

const SKIP_EXT = /\.(?:png|jpe?g|gif|webp|avif|svg|ico|pdf|zip|gz|mp4|mp3|webm|woff2?|ttf|css|js|json|xml|txt)$/i;

function segmentOf(url) {
  const p = new URL(url).pathname.split("/").filter(Boolean);
  return p.length ? p[0] : "/";
}

function compact(rec) {
  const { links, images, jsonLd, headings, textPreview, ...rest } = rec;
  return {
    ...rest,
    jsonLdTypes: (jsonLd || []).flatMap((b) => b.types),
    jsonLdErrors: (jsonLd || []).filter((b) => b.error).length,
    headingOutline: (headings || []).slice(0, 12).map((h) => `h${h.level} ${h.text.slice(0, 60)}`),
  };
}

async function crawl(start, opts) {
  const startUrl = new URL(start);
  const origin = startUrl.origin;
  const local = Boolean(opts.local);
  const prod = opts.origin ? new URL(opts.origin) : null;
  const cap = Number(opts.cap || 100);
  const maxDepth = Number(opts.depth ?? 3);
  const delay = opts.delay !== undefined ? Number(opts.delay) : local ? 0 : 1000;
  const ua = opts.ua || UA;

  // Map a URL onto the crawl origin: production-origin URLs in a local run,
  // and www/apex variants of the same site.
  const toCrawl = (url) => {
    try {
      const u = new URL(url);
      if (prod && sameSite(u.hostname, prod.hostname)) return { url: origin + u.pathname + u.search, mapped: true };
      if (sameSite(u.hostname, startUrl.hostname)) return { url: origin + u.pathname + u.search, mapped: u.origin !== origin };
      return null;
    } catch { return null; }
  };

  const robots = await robotsFor(start, ua, ["seokit", ...AGENTS]);
  const smStart = robots.sitemaps.length ? robots.sitemaps.map((s) => toCrawl(s)?.url || s) : [`${origin}/sitemap.xml`];
  const sm = await collectSitemap(smStart, ua);
  const sitemapSet = new Set();
  let sitemapForeign = 0;
  for (const s of sm.urls) { const m = toCrawl(s); if (m) sitemapSet.add(m.url); else sitemapForeign++; }

  const known = new Map(); // url -> { depth, via, inlinks:Set }
  const add = (url, depth, via, from) => {
    let k = known.get(url);
    if (!k) { k = { depth, via, inlinks: new Set() }; known.set(url, k); }
    else if (depth !== null && (k.depth === null || depth < k.depth)) k.depth = depth;
    if (from) k.inlinks.add(from);
    return k;
  };
  add(startUrl.origin + startUrl.pathname + startUrl.search, 0, "start", null);
  for (const s of sitemapSet) add(s, null, "sitemap", null);

  const fetched = new Map();
  const blocked = [];
  const pickNext = () => {
    // Fair share by first path segment: the least-fetched segment goes next,
    // link-discovered and shallow URLs before sitemap-only ones.
    const perSeg = {};
    for (const u of fetched.keys()) perSeg[segmentOf(u)] = (perSeg[segmentOf(u)] || 0) + 1;
    let best = null;
    for (const [u, k] of known) {
      if (fetched.has(u) || k.skip) continue;
      if (k.depth !== null && k.depth > maxDepth && !sitemapSet.has(u)) continue;
      const score = [perSeg[segmentOf(u)] || 0, k.depth === null ? 99 : k.depth];
      if (!best || score[0] < best.score[0] || (score[0] === best.score[0] && score[1] < best.score[1])) best = { u, score };
    }
    return best?.u;
  };

  while (fetched.size < cap) {
    const next = pickNext();
    if (!next) break;
    const k = known.get(next);
    const path = new URL(next).pathname + new URL(next).search;
    const verdict = robotsVerdict(robots.parsed, "seokit", path);
    if (!verdict.allowed && !local) { blocked.push({ url: next, rule: verdict.rule }); k.skip = true; continue; }
    if (fetched.size > 0 && delay > 0) await sleep(delay);
    const rec = await extractUrl(next, { ua, origin: opts.origin });
    rec.robotsDisallowed = !verdict.allowed;
    fetched.set(next, rec);
    const depth = k.depth === null ? null : k.depth + 1;
    for (const l of rec.links || []) {
      if (!l.internal) continue;
      const m = toCrawl(l.href);
      if (!m || SKIP_EXT.test(new URL(m.url).pathname)) continue;
      add(m.url, depth, "link", next);
    }
  }

  const pages = [...fetched.entries()].map(([u, rec]) => {
    const k = known.get(u);
    const out = opts.full ? rec : compact(rec);
    return { ...out, crawlUrl: u, depth: k.depth, discoveredVia: k.via, inSitemap: sitemapSet.has(u), inlinks: k.inlinks.size, linkedFrom: [...k.inlinks].slice(0, 3) };
  });

  // Groupings for the site-level checks. Data only; the agent decides what fails.
  const group = (fn) => {
    const m = new Map();
    for (const p of pages) { const key = fn(p); if (key) { if (!m.has(key)) m.set(key, []); m.get(key).push(p.crawlUrl); } }
    return [...m.entries()].filter(([, v]) => v.length > 1).map(([key, urls]) => ({ key, count: urls.length, urls: urls.slice(0, 10) }));
  };
  const linked = new Set([...known.entries()].filter(([, k]) => k.inlinks.size > 0 || k.via === "start").map(([u]) => u));
  const canonTargets = new Map();
  for (const p of pages) {
    const c = (p.canonicals || [])[0];
    if (!c) continue;
    const m = toCrawl(c)?.url || c;
    if (m !== p.crawlUrl) { if (!canonTargets.has(m)) canonTargets.set(m, []); canonTargets.get(m).push(p.crawlUrl); }
  }
  const depthHistogram = {};
  for (const p of pages) { const d = p.depth === null ? "unlinked" : String(p.depth); depthHistogram[d] = (depthHistogram[d] || 0) + 1; }

  return {
    mode: local ? "local" : "public",
    start: start,
    origin,
    productionOrigin: prod?.origin ?? null,
    settings: { cap, maxDepth, delayMs: delay, userAgent: ua, obeysRobots: !local },
    coverage: { fetched: pages.length, knownUrls: known.size, sitemapUrls: sitemapSet.size, sitemapForeignHost: sitemapForeign, robotsBlocked: blocked.length },
    robots: { url: robots.robotsUrl, status: robots.status, sitemaps: robots.sitemaps, agents: robots.agents, text: robots.text },
    sitemaps: sm.sitemaps,
    aggregates: {
      duplicateTitles: group((p) => (p.titles || [])[0]?.trim()),
      duplicateDescriptions: group((p) => (p.description || [])[0]?.trim()),
      sitemapNotLinked: [...sitemapSet].filter((u) => !linked.has(u)).slice(0, 50),
      sitemapNotLinkedCount: [...sitemapSet].filter((u) => !linked.has(u)).length,
      linkedNotInSitemap: pages.filter((p) => p.status === 200 && p.discoveredVia !== "sitemap" && !p.inSitemap).map((p) => p.crawlUrl).slice(0, 50),
      canonicalClusters: [...canonTargets.entries()].map(([target, urls]) => ({ target, count: urls.length, urls: urls.slice(0, 10) })).sort((a, b) => b.count - a.count),
      depthHistogram,
      statusCounts: pages.reduce((acc, p) => { acc[p.status] = (acc[p.status] || 0) + 1; return acc; }, {}),
      devMarkerPages: pages.filter((p) => (p.devMarkers || []).length).length,
    },
    blocked,
    pages,
  };
}

// ---------- main ----------

const HELP = `seokit extractor (JSON out, no judgments)

  extract <url>...            page facts for each URL
      --origin <url>          production origin; its links count as internal
      --html <file> --base <url>  analyze saved HTML (e.g. a rendered DOM) instead of fetching
      --ua <string>           user agent (default: ${UA})
  crawl <start-url>           sitemap + links crawl with site groupings
      --cap <n>               max pages fetched (default 100)
      --depth <n>             max link depth (default 3)
      --delay <ms>            pause between requests (default 1000; 0 with --local)
      --local                 local server: no delay, robots.txt read but not obeyed
      --origin <url>          production origin; its sitemap and link URLs map to the local origin
      --out <file>            write JSON to a file and print a short summary
      --full                  keep full per-page records (links, images, JSON-LD)
  robots <url>                robots.txt verdict per crawler for this URL's path
      --agents a,b            override the crawler list
`;

async function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  const args = parseArgs(rest);
  if (!cmd || cmd === "--help" || cmd === "-h" || args.help) { process.stdout.write(HELP); return; }
  let result;
  if (cmd === "extract") {
    if (args.html) {
      if (!args.base) throw new Error("--html needs --base <url>");
      result = [{ source: args.html, finalUrl: args.base, ...analyze(readFileSync(args.html, "utf8"), args.base, { origin: args.origin }) }];
    } else {
      if (!args._.length) throw new Error("extract needs at least one URL");
      result = [];
      for (const u of args._) result.push(await extractUrl(u, { ua: args.ua, origin: args.origin }));
    }
  } else if (cmd === "crawl") {
    if (!args._[0]) throw new Error("crawl needs a start URL");
    result = await crawl(args._[0], args);
  } else if (cmd === "robots") {
    if (!args._[0]) throw new Error("robots needs a URL");
    const agents = typeof args.agents === "string" ? args.agents.split(",").map((s) => s.trim()) : AGENTS;
    const { parsed, ...r } = await robotsFor(args._[0], args.ua || UA, agents);
    result = r;
  } else throw new Error(`unknown command '${cmd}' (try --help)`);

  const json = JSON.stringify(result, null, 2);
  if (args.out) {
    writeFileSync(args.out, json);
    const s = result.coverage ? { out: args.out, coverage: result.coverage, statusCounts: result.aggregates?.statusCounts } : { out: args.out };
    process.stdout.write(JSON.stringify(s, null, 2) + "\n");
  } else process.stdout.write(json + "\n");
}

main().catch((e) => { process.stderr.write(`seokit extract: ${e.message}\n`); process.exit(1); });
