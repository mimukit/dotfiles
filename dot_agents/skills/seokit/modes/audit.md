## Mode: `audit`

One page closely, plus the site files that govern it. Up to five URLs in one run. The root's guards, environment rules, catalog, and report skeleton all apply.

### 1. Find the URL and the environment

Take the URL the user gave. With none ("check SEO before I deploy"), read the repository's `dev`, `start`, and `preview` scripts and framework config for the port, probe that port, and ask for the URL only when nothing answers. Classify the environment from the host.

Inside the site's repository, note the framework and where its metadata lives (a layout file, a head component, an SEO plugin config), because every fix maps to a file. In `local`, run the production-origin lookup now and record its source.

Done when the URL, the environment, and (in `local`) the production origin with its source are recorded.

### 2. Run the dev-server gate

`local` only. Run `extract` on the URL first. When it reports `devMarkers`, run the root's [dev-server gate](../SKILL.md#the-dev-server-gate) before any other step, and under choice (a) follow the server lifecycle and restart this mode on the production URL.

Done when no marker was found, or the user picked (a) and the production URL answers, or the user picked (b), or a build failure was reported with its log tail.

### 3. Intake

Infer the site type, the audience, and two to five target queries from the page, and in `local` from the repository too (README, page copy, config). Ask only for what stays unknown, in one round of at most four questions: site type, goal and audience, target queries, and whether the owner can paste Search Console or Bing Webmaster Tools data. In `local`, the production origin joins the round only when its lookup found nothing. Label every inferred value *inferred* in the report.

Done when every intake item holds a stated or inferred value.

### 4. Gather evidence

Capture each item, or write it down as unavailable with its reason.

**`local`** (the usual case):

- `extract` on each URL, with `--origin <production-origin>`;
- the rendered DOM when a browser exists, analyzed with `extract --html`;
- `robots` on the URL, plus the sitemap and `/llms.txt` the server serves;
- Lighthouse on the production server when Chrome or Chromium exists (`npx -y lighthouse <url> --only-categories=performance,seo --output=json --output-path=<tmp-file> --chrome-flags="--headless=new"`), labelled "lab, local machine"; without a browser, `TECH-CWV` reads `unverified` and the install offer applies;
- the status of up to 20 internal links from the page.

Skip the host variants, the bot probes, PageSpeed, and the competitor comparison; their checks read `n/a`.

**`preview` and `production`**:

- `extract` on each URL, and the rendered DOM when a browser exists;
- `robots` on the URL, the sitemap, and `/llms.txt`;
- the `http`/`https` and `www`/bare host variants, with where each redirects;
- one bot probe per agent in the catalog's purpose table: `curl -s -o /dev/null -w '%{http_code}' -A "<agent>/1.0" <url>`;
- PageSpeed Insights (`https://www.googleapis.com/pagespeedonline/v5/runPagespeed?url=<encoded>&strategy=mobile&category=performance&category=seo`, plus `&key=` from `PAGESPEED_API_KEY` or a key the user pastes for this run; never write the key to disk). Field data sits in `loadingExperience.metrics`, falling back to `originLoadingExperience`; the CLS percentile is reported times 100. On HTTP 429 or no field data, use local Lighthouse, then `unverified` with the manual PageSpeed link;
- the status of up to 20 internal links;
- when a primary query exists: one web search for it, and the text of the top two results that are not the site.

In `preview`, apply the expected-block rule.

Done when every item listed for the environment holds a value or an unavailable note, and the evidence rung is recorded.

### 5. Evaluate every check

Give every catalog row except the `crawl` rows a verdict with quoted evidence: the observed title with its length, the robots rule that matched, the JSON-LD types found. Apply the environment rules before each pass rule. Add the `INTL-*` checks when the page carries hreflang or locale paths. With several URLs, compare titles and descriptions across them.

Done when every row has a verdict, every verdict quotes its evidence, no `fail` rests on a method that cannot see the thing, and every `unverified` names what would settle it.

### 6. Prioritize and plan

Rank the failed and warned checks by the root's severity, effort, and engine rules, and crown the top three to five. Make each fix specific to this page: the proposed title text, the exact `robots.txt` line, the JSON-LD block. Inside the site's repository, name the file and line that controls each one. Then write the root's [long-term plan](../SKILL.md#long-term-plan) from these findings and the site type's playbook.

Done when every finding carries severity, effort, engine, and a page-specific fix, and every plan item cites a finding ID or a playbook entry.

### 7. Write the report

Write it to the root's location with the root's name and skeleton. Look for an earlier report with the same slug, and add the delta section when one exists.

Done when the file exists, or prints as a code block with its filename, and each of the eight skeleton sections is present or marked not applicable.

### 8. Stop what seokit started

When seokit started a production server, stop it by its process ID now, and confirm its port no longer answers. The same stop runs after any failed step and on interrupt.

Done when no process seokit started is still running, or seokit started none.

### 9. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Give the headline line and the top three findings by ID. Name the checks that read `unverified` or `n/a`. State that no site file changed, and that any server seokit started is stopped.

**Where it landed.** Give the report path, or say it printed. Give the environment and the production origin used.

**Next.** Crown one move. Inside the site's repository, apply the *Fix now* items with **implementkit** when it is installed; otherwise make the fixes by hand from the findings table. Outside the repository, send the report to the person who owns the site code. Name these runners-up:

1. File each finding as an issue with **issuekit** when it is installed; otherwise use `gh issue create`.
2. In `local`, re-run `audit` on the same local URL after the fixes. Then run it once on the preview or production URL to clear the `n/a` checks.
3. On a public host, re-run `audit` after the deploy.

After choice (b) on a dev server, repeat the dev-server warning in one line. Give this project's production-mode commands, so the next run measures performance and checks the structure verdicts against the build.
