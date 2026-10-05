# Production mode on the local machine

Read the one section that matches the project's framework, after the dev-server gate fires. The project's own `build`, `start`, `preview`, and `serve` scripts come first; this file fills the gaps and names the gotchas the scripts hide. Commands were checked against each framework's docs on 2026-10-04.

Use the package manager the lockfile names (`npm run`, `pnpm`, `yarn`, `bun`) for the build. When seokit starts the server itself, call the binary from `node_modules/.bin` with an explicit port, bound to `127.0.0.1`, so it never collides with the dev server: Next.js, Nuxt, React Router, adapter-node, and `serve` all default to port 3000.

| Framework | Build | Serve the build | Default port |
|-----------|-------|-----------------|--------------|
| Next.js | `next build` | `next start -H 127.0.0.1 -p <port>` | 3000 |
| Next.js, `output: "export"` | `next build` | `serve out -l <port>` | — |
| Vite (React, Vue, Svelte, Solid) | `vite build` | `vite preview --host 127.0.0.1 --port <port> --strictPort` | 4173 |
| Astro | `astro build` | `astro preview --host 127.0.0.1 --port <port>` | 4321 |
| Nuxt | `nuxt build` | `NUXT_PORT=<port> nuxt preview`, or `NODE_ENV=production PORT=<port> node .output/server/index.mjs` | 3000 |
| Nuxt, `nuxt generate` | `nuxt generate` | `serve .output/public -l <port>` | — |
| SvelteKit | `vite build` | `vite preview --port <port>`, or with adapter-node `PORT=<port> node --env-file=.env build` | 4173 / 3000 |
| React Router 7 | `react-router build` | `PORT=<port> react-router-serve ./build/server/index.js` | 3000 |
| Gatsby | `gatsby build` | `gatsby serve -p <port>` | 9000 |
| Angular | `ng build` | static: `serve -s dist/<app>/browser -l <port>`; SSR: `PORT=<port> node dist/<app>/server/server.mjs` | 4000 (SSR) |
| Create React App | `npm run build` | `serve -s build -l <port>` | 3000 |
| Hugo | `hugo --minify` | `serve public -l <port>` | — |
| Jekyll | `JEKYLL_ENV=production bundle exec jekyll build` | `serve _site -l <port>` | — |
| Eleventy | `npx @11ty/eleventy` | `serve _site -l <port>` | — |

`serve` is the `serve` package (`npx serve`); `-s` sends unknown paths to `index.html` for a single-page app, and `-l` sets the port. When it runs through `npx`, stopping the `npx` process may leave the server running, so confirm the port closed and stop its listener as the root's server lifecycle says.

## Next.js

- `next start` serves only a `next build` output; run the build first.
- With `output: "export"` in `next.config.*`, there is no server: the build writes static files to `out/`, and `next start` is the wrong command.
- `PORT` in `.env` is not read for the port; pass `-p`.
- Site-URL variables such as `NEXT_PUBLIC_SITE_URL` are inlined at build time, so set them for the build, not for `next start`.
- A canonical appears only when `alternates.canonical` is set in metadata; `metadataBase` alone resolves relative URLs and emits no canonical tag.

## Vite

- `vite preview` serves `dist/` and is not meant as a production server, which is fine for an audit.
- A Vite single-page app renders its content with JavaScript, so expect `CRAWL-RENDER` findings in raw HTML whatever the mode.

## Astro

- `astro preview` works for a fully static site and with the Node and Cloudflare adapters (Cloudflare runs it on `workerd`).
- The Vercel and Netlify adapters fail with "adapter does not support the preview command". For those, audit a preview deploy, or build a static variant.
- The standalone Node adapter can also run `node ./dist/server/entry.mjs`.

## Nuxt

- `nuxt preview` (alias `nuxt start`) loads `.env`; running `node .output/server/index.mjs` directly does not, so pass the variables yourself.
- The port comes from `NUXT_PORT`, `NITRO_PORT`, or `PORT`.

## SvelteKit

- `vite preview` runs in Node and skips adapter features such as `platform`.
- With adapter-node, `node build` does not load `.env`; use `node --env-file=.env build`.
- Without `paths.origin` in the config, the origin comes from the `Host` header, so canonicals built from `url.origin` show `localhost`. That is a `warn` under the local URL rules, with `paths.origin` as the fix.

## React Router 7 and Remix

- The server bundle path comes from the config; the framework template writes `build/server/index.js`. Check `react-router.config.*` when the path differs.

## Gatsby

- A site built with `pathPrefix` needs `gatsby build --prefix-paths` and `gatsby serve --prefix-paths`.

## Angular

- `ng serve` is the dev server; never audit it.
- A static build needs the `index.html` fallback (`serve -s`) for deep links.
- With SSR, the project usually has a `serve:ssr:<app>` script; prefer it.

## Create React App

- CRA is deprecated and renders on the client only; expect `CRAWL-RENDER` findings and recommend server or static rendering in the long-term plan.

## Hugo

- `hugo` builds for the `production` environment by default; `hugo server` runs `development`, with live reload.

## Jekyll

- `JEKYLL_ENV` defaults to `development`; without `production`, plugins and includes that check `jekyll.environment` (analytics, SEO tags) may not render.

## Eleventy

- `--serve` is the dev server with auto-refresh on port 8080; the build writes `_site/`.

## Backend frameworks

- **Django.** Set `DEBUG=False` and `ALLOWED_HOSTS` to include `localhost` and `127.0.0.1`, or every request is rejected. Run `collectstatic` and serve static files with WhiteNoise; `runserver --insecure` does not work with `ManifestStaticFilesStorage`. Then `python manage.py runserver 127.0.0.1:<port>`.
- **Rails.** `RAILS_ENV=production bin/rails assets:precompile`, then `RAILS_ENV=production bin/rails server -b 127.0.0.1 -p <port>`. It needs `SECRET_KEY_BASE` or `RAILS_MASTER_KEY`. The generated `production.rb` sets `force_ssl` and `assume_ssl`, so `http://localhost` redirects to HTTPS. Turning that off is a code change for the owner; offer to audit a preview deploy instead.
- **Laravel.** Set `APP_ENV=production` and `APP_DEBUG=false`, run `php artisan optimize`, then `php artisan serve --host=127.0.0.1 --port=<port>`. After `config:cache`, Laravel stops reading `.env`, so re-run `optimize` after any change to it.

A framework not listed here falls back to the project's own scripts and the framework's docs.
