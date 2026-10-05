# International checks

Read this when a page carries hreflang links, locale path prefixes (`/en/`, `/de/`), or locale subdomains. Add these rows to the evaluation; they follow the root's verdict and evidence rules. Fetch every hreflang target with `extract` to check its status, canonical, and return links.

| ID | Passes when | Gotcha |
|----|-------------|--------|
| `INTL-SELF` | The page lists itself in its own hreflang set | Without the self entry, Google ignores the whole set |
| `INTL-RECIP` | Every target links back to this page with its own hreflang | A one-way pair is dropped |
| `INTL-CODES` | Codes are ISO 639-1 language plus optional ISO 3166-1 region (`en`, `en-GB`, `pt-BR`) | `en-UK` is invalid; the region code is `GB` |
| `INTL-XDEFAULT` | One `x-default` points at the fallback page (a selector or the default locale) | Optional, but a missing fallback leaves unmatched users on a guess |
| `INTL-TARGETS` | Every target returns 200, is indexable, and is its own canonical | A target that redirects, 404s, or canonicals elsewhere invalidates its pair |
| `INTL-CANON` | Each locale page canonicals to itself, and that canonical appears in the hreflang set | A cross-locale canonical (French to English) removes the French page from the index; canonical beats hreflang in a conflict |
| `INTL-AGREE` | HTML `<link>`, HTTP `Link` headers, and sitemap `xhtml:link` entries agree, when more than one is used | Conflicting sources drop the pair |
| `INTL-CONTENT` | The main content is translated, not only the navigation | A page that translates only the chrome is a duplicate in another language |
| `INTL-ROUTING` | No redirect by IP address or `Accept-Language` | Googlebot crawls mostly from US addresses with no `Accept-Language`, so it never sees the other locales |

## Facts the checks rest on

- Three placements are equivalent: HTML `<link rel="alternate" hreflang>`, the HTTP `Link` header, and sitemap `<xhtml:link>`. For more than about ten locales, the sitemap keeps page weight down. A sitemap with `xhtml:link` needs the `xmlns:xhtml` namespace, and each `<url>` lists every locale including itself.
- Next.js `alternates.languages` does not add the current page's own entry; add it explicitly.
- Subdirectories (`/de/`) are the easiest structure to run; subdomains and country domains work; a `?lang=` parameter is the weakest choice.
- Bing treats hreflang as a weak signal and leans on `<html lang>` and `content-language`; set both.
- Thin locale pages weigh on the whole site. The fix is to not publish a locale you cannot make useful, rather than `noindex` or a cross-locale canonical.

In `local`, check the hreflang targets on the production origin path by path against the local server, the same way the root maps canonicals.
