## Mode: `crawl`

A whole site broadly: template bugs and structural gaps one page cannot show. The root's guards, environment rules, catalog, and report skeleton all apply. `crawl` needs Node 18 or later for the extractor; without it, stop and say so.

### 1. Find the start URL, the environment, and the cap

Take the start URL (the home page when the user named the site or a sitemap). Classify the environment. In `local`, run the production-origin lookup and record its source. State the cap of 100 pages, and accept a higher one when the user asks; at one request per second on a public host, 100 pages take about two minutes.

Done when the start URL, the environment, the cap, and (in `local`) the production origin are recorded.

### 2. Run the dev-server gate

`local` only. Run `extract` on the start URL. When it reports `devMarkers`, run the root's [dev-server gate](../SKILL.md#the-dev-server-gate) before discovery: a crawl of a dev server repeats the problem on every URL. Under choice (a), follow the server lifecycle and restart this mode on the production URL.

Done when no marker was found, or the user picked (a) and the production URL answers, or the user picked (b), or a build failure was reported with its log tail.

### 3. Intake

The same rule as `audit`: infer the site type, audience, and target queries, and ask only for the gaps in one round of at most four questions. Label inferred values.

Done when every intake item holds a stated or inferred value.

### 4. Discover and extract

Run `crawl` with `--out` to a file in the system temp directory:

- public host: `crawl <start-url> --cap <n> --out <file>`. It identifies as `seokit/1.0`, obeys the `*` and `seokit` groups in `robots.txt`, and waits one second between requests. Record robots-blocked URLs under `CRAWL-ROBOTS`.
- `local`: `crawl <start-url> --local --origin <production-origin> --cap <n> --out <file>`. It sends no delay, maps production-origin sitemap and link URLs to the local server, and reads `robots.txt` without obeying it; a `Disallow` rule feeds the expected-block rule.

Read the summary, then read the file in parts. Never paste the whole file into the conversation.

Done when the crawl file exists, the fetched count is within the cap, and the coverage block (fetched, known, sitemap URLs, blocked) is recorded.

### 5. Tier 1 on every URL

Read each page's mechanical fields against the Tier 1 rows (`CRAWL-STATUS`, `CRAWL-NOINDEX`, `CRAWL-CANON`, `CRAWL-RENDER`, `PAGE-TITLE`, `PAGE-DESC`, `PAGE-HEAD`, `DATA-PRESENT`), with the environment rules first. Aggregate by check ID: fail count, warn count, and up to five example URLs.

Done when every fetched URL has a Tier 1 result and every Tier 1 row has its counts.

### 6. Site checks

Compute the six `SITE-*` rows from the crawl's `aggregates`: duplicate titles and descriptions among indexable 200 pages, sitemap URLs no crawled page links, linked indexable pages missing from the sitemap, the depth histogram, and canonical clusters. State each result as measured within the cap.

Done when all six `SITE-*` rows have a verdict with counts and example URLs.

### 7. Tier 2 on the samples

Group URLs by first path segment, with the home page as its own group. Pick one sample per group, at most five, favoring the groups with the most Tier 1 failures. Run the site-level file checks once (`CRAWL-ROBOTS`, `CRAWL-SITEMAP`, `AEO-BOTS`, `AEO-WAF`, `TECH-HTTPS`, `TECH-HOST`, with the `local` `n/a` set applied), then the full catalog on each sample with `extract`, the rendered DOM when a browser exists, and Lighthouse or PageSpeed on the samples only. `CONT-DEPTH` reads `unverified` with "run `audit` on this page" as its settling step, since `crawl` skips the competitor comparison.

Done when every sample has a verdict on every catalog row except the `crawl` rows.

### 8. Prioritize, plan, and write the report

Rank with the root's rules, weighting template-level fixes, since one template change clears many URLs. Name the template or file behind each aggregated finding when inside the site's repository. Write the root's long-term plan and the report, with one row per check ID carrying its fail count and example URLs, and the per-URL table in the appendix. Add the delta section when an earlier report for this host exists.

Done when every finding carries severity, effort, engine, and a fix, every plan item cites a finding ID or playbook entry, and the report holds all eight skeleton sections or marks them not applicable.

### 9. Stop what seokit started

When seokit started a production server, stop it by its process ID now and confirm its port no longer answers. The same stop runs after any failed step and on interrupt. Delete the crawl file from the temp directory.

Done when no process seokit started is still running, or seokit started none.

### 10. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Give the headline line, the pages crawled against the cap, and the top three template-level findings by ID with their counts. Name the checks that read `unverified` or `n/a`. State that no site file changed, and that any server seokit started is stopped.

**Where it landed.** Give the report path, or say it printed. Give the environment, the production origin, and whether the crawl obeyed `robots.txt`.

**Next.** Crown one move. Inside the site's repository, fix the top template-level finding with **implementkit** when it is installed; otherwise fix that template by hand. Outside the repository, send the report to the site's developer. Name these runners-up:

1. Run `audit` on the worst sample page for the content and competitor verdicts the crawl skipped.
2. File each finding as an issue with **issuekit** when it is installed; otherwise use `gh issue create`.

After choice (b) on a dev server, repeat the dev-server warning in one line. Give this project's production-mode commands.
