---
name: wikikit
description: >-
  Generate and maintain a project's reader-facing documentation in-repo — getting-started, how-to guides, architecture overview, runbooks — with every command verified against the code, in four modes: init, update, audit, and an opt-in publish that mirrors the set to the GitHub wiki. Use when the user says "write docs for this project", "document this repo", "update the docs", "our docs are stale", "write a runbook", "write a getting-started guide", "architecture overview", "sync the docs to the GitHub wiki", or "/wikikit". Not an agent handoff, and not the glossary or ADRs.
license: MIT
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
metadata:
  internal: false
---

# wikikit

The documentation a **reader** opens: how do I run this, how do I do the one task I came here for, how is it put together, and what do I do at 3am when it's down. wikikit generates that set from the codebase as it actually is, keeps it true as the code changes, and reports honestly when it has gone stale. **It is not the GitHub Wiki tab** — everything it writes is in-repo Markdown, versioned with the code and reviewed in the same pull request. Mirroring that set out to the wiki tab is available as an opt-in [`publish`](#mode-publish) mode, which never fires unless you ask for it by name.

A repo built by agents accumulates plans, reviews, QA docs, and decision records, and still ships a README that says `npm install` because that's what the scaffold wrote a year ago. The knowledge exists; it's just scattered across artifacts nobody outside the project will ever read. wikikit is the half that faces outward.

## What wikikit is not

- **Not the GitHub Wiki.** In-repo Markdown is the source of truth in every mode — versioned with the code, reviewed in the same PR. The wiki tab is at most a **derived, disposable mirror**, and only when [`publish`](#mode-publish) is asked for by name. wikikit never reads the wiki as input and never treats it as canonical.
- **Not the domain model.** A glossary (`CONTEXT.md`) and decision records (`docs/adr/`) have one owner — **domainkit** when it's installed, the human otherwise. A page that needs a term **links** to the glossary instead of defining it; an architecture page that needs a rationale links the ADR by number instead of paraphrasing it. A term missing from the glossary is routed, never invented inline.
- **Not process artifacts.** Plans, QA plans, reviews, handoffs, and agent instruction files (`CLAUDE.md` and its equivalents) are written for a maintainer mid-flow, expire, and are never read as sources of truth for reader docs or written by this skill.
- **Not an API reference generator.** Where a generator exists — TypeDoc, Sphinx autodoc, an OpenAPI spec — wikikit links its output unchanged rather than hand-writing reference material that drifts within a week.

## When this fires

- **`init`** — "write docs for this project", "document this repo", "we have no docs", "generate a getting-started guide". Bootstraps the set from the codebase.
- **`update`** — "update the docs", "the docs are out of date after this change", or a docs pass right after a feature lands. Refreshes only what the change invalidated.
- **`audit`** — "are our docs stale", "check the docs against the code", "what's undocumented". Read-only sweep. **Writes nothing, ever.**
- **`publish`** — **explicit ask only.** "publish the docs to the GitHub wiki", "sync `docs/wiki/` to the wiki tab", "set up the wiki action". Installs a workflow that mirrors the set to the wiki.

**If no mode is clear, ask.** `audit` is free and `init` writes a dozen files; never guess between them.

**`publish` is never inferred.** It is not part of the doc loop, no other mode routes into it, and "the docs are out of date" or "publish the docs" *alone* means [`update`](#mode-update), not this. It fires only when the request names the GitHub wiki, the wiki tab, or the sync workflow itself. A repo that never asks for it never learns it exists.

## Locate the doc sets

Every mode opens the same way, so all three agree on where docs live before anything reads or writes. **Name every set found in the mode's first line of output** — a missing set has to be visible immediately, not inferred from an empty result.

### Find existing sets

One `**/.wikimap.yaml` glob, scoped to the repo root plus the workspace globs (`pnpm-workspace.yaml`, `package.json` `workspaces`, `go.work`, a Cargo workspace), honoring `.gitignore` so a vendored tree can't inject a set. No root registry: the manifest travels with the set it describes, and a set added later is found automatically.

### Run the detection ladder for a repo with no set

Take the first rung that matches, and **say which rung matched before writing anything**:

| # | Rung | Where docs go |
|---|---|---|
| 1 | **A configured docs engine** — `mkdocs.yml`, `docusaurus.config.*`, `.vitepress/`, `astro.config.*` with Starlight, `conf.py`, a Nextra config | that engine's configured content directory, with its nav/sidebar updated in the same pass |
| 2 | **An existing reader-doc tree** — a populated `docs/` that isn't only agent artifact directories, or `documentation/`, `website/docs/` | adopt it as-is; do not migrate |
| 3 | **Fallback** | `docs/wiki/`, created on first write |

`docs/wiki/` keeps reader docs quarantined from the agent artifact directories that share the `docs/` parent, so a reader never lands in a QA plan. But **an existing engine always wins** — wikikit writes into the site the repo already runs, and never introduces MkDocs or Docusaurus into a repo that doesn't have one.

**In a workspace, the root set is always written; a package earns its own set only when it is independently published or independently runnable.** Run the ladder once for the root, then once per qualifying package (`packages/<x>/docs/`). State the split before writing anything: root-only makes an architecture page unusable past about four packages, and always-per-package is wrong for an app monorepo where the reader wants one getting-started.

### Reconcile the manifest against disk

A central manifest is the one map shape that can be wrong while looking right, so every mode pays this price up front, **before any work starts**:

- pages on disk with no manifest entry,
- entries whose page is gone,
- `documents:` globs matching nothing,
- a `home:` that no longer matches the ladder — usually a docs engine that arrived after `init`.

`init` and `update` repair on consent. `audit` reports drift as its own row and repairs nothing, because it writes nothing. **A migration is never implicit**: when rung 1 starts matching where rung 3 matched before, name both paths and offer the `git mv` plus nav update as one consented step. Declined, wikikit keeps writing where the manifest says and reports the divergence each run.

## The doc map

The doc map is the unit all three modes operate on. It lives at `<doc home>/.wikimap.yaml` — dotfile-prefixed so GitHub's folder view and every engine build skip it without a config edit — and carries one entry per page with its Diátaxis mode and the globs of code it documents:

```yaml
home: docs/wiki
engine: none                    # or mkdocs | docusaurus | vitepress | starlight | sphinx | nextra
pages:
  - path: getting-started.md
    mode: tutorial
    documents: [package.json, src/index.ts, .env.example]
  - path: how-to/deploy-to-staging.md
    mode: how-to
    documents: [.github/workflows/deploy.yml, infra/**]
  - path: architecture.md
    mode: explanation
    adopted: true               # a human wrote it; wikikit maps it, never claims it
    documents: [src/**]
```

`documents:` is what makes `update` cheap — a code-path → page lookup that doesn't read every page — and what gives `audit` its recency prefilter.

### The page vocabulary

| Page | Diátaxis mode | Documents |
|------|---------------|-----------|
| `index.md` | — | entry point and table of contents |
| `getting-started.md` | tutorial | install → run → first successful thing |
| `how-to/<task>.md` | how-to | one task per page, goal-shaped |
| `how-to/set-up-a-dev-environment.md` | how-to | the derivable half of contributor docs |
| `how-to/cut-a-release.md` | how-to | release steps that actually exist in the repo |
| `architecture.md` | explanation | components, boundaries, data flow, links to ADRs |
| `runbooks/<scenario>.md` | how-to (operator) | deploy, rollback, incident response, backup/restore |
| `reference.md` | reference | declared surface only — commands, flags, env vars, config keys |

**This table is the vocabulary, not a quota.** The map is derived from the repo: a library with no deployment gets no runbooks, a CLI gets a commands page, a repo with a TypeDoc build gets no `reference.md` at all.

Diátaxis governs internally and stays out of the reader's face — the four modes are the rule that keeps doc types unmixed, not jargon to print on the page. A how-to must not drift into explanation; an architecture page must not turn into a tutorial.

Two boundaries the vocabulary encodes:

- **`CONTRIBUTING.md` is linked, never written.** Dev-environment setup and release steps are in the repo and verify like any other how-to. PR etiquette, a code of conduct, and review norms are a social contract that exists nowhere in code — writing them would break the grounding rule on the repo's most visible contributor page. `index.md` links the file if it exists.
- **`reference.md` covers declared surface only** — things declared in a single place and re-verifiable in a single grep: CLI commands, flags, env vars, config keys. Library symbols and hand-maintained HTTP endpoint tables are refused and routed to a generator. This narrow exception exists so a CLI with twenty flags and no docs tooling gets something rather than nothing.

### The provenance stamp

Every page wikikit authors ends with one line:

```markdown
_Verified against `main`@`a1b2c3d` on 2026-08-06._
```

Both halves earn their place. `audit` diffs from the SHA while it is still reachable, and falls back to the date when a rebase or squash-merge has orphaned it — precise when it can be, degrading instead of lying when it can't.

**A page with no stamp is not stale, it is unverified.** That's how adopted pages are marked: a page found under rung 2 gets a manifest entry with `documents:` globs and `adopted: true`, and no stamp. wikikit can see it and route to it, and has never checked a claim on it. It earns its first stamp the first time a verification pass genuinely covers it. Adoption is a mapping act, not an authorship claim over prose a human wrote.

## Grounding: verify before you write

**Every factual claim is verified against the repo before it ships.** Commands come from the actual `package.json`, `Makefile`, `pyproject.toml`, or `justfile`; paths exist; env vars are actually read somewhere; endpoints are actually routed. **A feature wikikit cannot find in code does not get documented.** This is the single rule that separates a doc set from plausible fiction, and it holds in all three modes.

Static reading is the default, and it proves a script is *declared*, not that it runs. So wikikit may also execute a **fixed allowlist of side-effect-free probes**, after **one consent ask per run**:

| Allowed | Never |
|---|---|
| `<command> --help`, `-h` | anything that installs (`npm install`, `pip install`, `brew`) |
| `<command> --version`, `-V` | anything that builds, compiles, or bundles |
| `make -n <target>`, `make help` | anything that migrates a database or seeds data |
| bare script listings — `npm run`, `pnpm run`, `yarn run`, `just --list` | anything that deploys, publishes, or pushes |
| read-only git — `git log`, `git diff`, `git show`, `git rev-parse` | anything that writes outside the doc set, or calls a live service |

The allowlist is written here and **never inferred**. A command that looks harmless but isn't on the list is not run — report the claim as unverified instead. `audit`'s "read-only" means *it writes no files*, so probes are available there too; that is where they pay off most.

## Mode: `init`

For a repo with no doc set, or a partial one.

### 1. Ground it

The research pass, and the bulk of the work. Read the manifests and their declared commands, entry points, CLI surface, routes, env vars, config, `Dockerfile`/compose, CI workflows, deploy config, the existing README, and `CONTEXT.md`/`docs/adr/` when they exist. Ask once for probe consent and use it to confirm the commands that will end up in `getting-started.md` — a getting-started whose first command doesn't exist is worse than no getting-started.

### 2. Adopt what's already there

Pages found under rung 2 get manifest entries with `documents:` globs, `adopted: true`, and no stamp. wikikit does not rewrite them and does not claim them.

### 3. Propose the map

Consent-gated, and this is the gate that matters. Show the page list with a one-line scope each, which entries are newly authored versus adopted, and **what wikikit could not determine from code**. The user accepts, trims, or redirects before a single file is written.

### 4. Write the accepted pages

Each grounded per [Grounding: verify before you write](#grounding-verify-before-you-write), each held to the [Writing standards](#writing-standards), each stamped with `<ref>@<sha>` and the date.

### 5. Rewrite the README front door

wikikit owns exactly one zone of the README — **what this is, the quickstart, and the links into the doc set**. It does not touch badges, license, acknowledgments, or anything else. The README is the most-read page in any repo; leaving it out of the maintained set is how it ends up lying about the install command.

The zone is delimited by marker comments. The first run infers the boundary positionally, shows the **exact** proposed boundary, and writes the markers on consent:

```markdown
<!-- wikikit:front-door:start -->
...
<!-- wikikit:front-door:end -->
```

Every later run is exact rather than positional. Refuse the markers and wikikit writes nothing to the README at all, and says so.

### 6. Write the manifest and update the nav

Write `<doc home>/.wikimap.yaml`, then update the docs engine's nav or sidebar config when one was detected. A page an engine can't reach is a page nobody reads.

### 7. Hand off

**What changed** — pages authored, pages adopted (mapped, not stamped), the README zone written or declined, and what could not be determined from code.

**Where it landed** — the doc home, which ladder rung chose it, the manifest path, and the engine config touched.

**Next** — read the set. It is new prose about your project and it is the one thing here a human should actually check. Then commit it with **commitkit** when installed, otherwise a plain `git add` and commit. If a term surfaced that belongs in the glossary, route to **domainkit** rather than defining it on a page.

## Mode: `update`

For a change that just landed. Resolve the target the same way a review does: **uncommitted working-tree changes first** (`git status --porcelain` non-empty → `git diff HEAD`, plus the untracked files `git diff` never shows), otherwise the **branch diff** against the base ref — from **gitkit** when it's installed, else the repo's default branch via `gh repo view --json defaultBranchRef`. Never assume `main`. Say which target you chose in one line.

### 1. Read the diff, not the whole repo

The diff is the input. Reading the repo instead is how a one-flag change turns into a six-page rewrite.

### 2. Map changed code to affected pages

Through the manifest's `documents:` globs. **State which pages are affected and which are deliberately untouched — before editing, not in the report afterward.** The untouched list is the load-bearing half; it's what tells the user the skill knew what it was leaving alone.

### 3. Edit the affected pages, surgically and directly

A changed flag edits the flag. It does not regenerate the page. These edits need no gate: they are bounded by the restraint rule and land in a reviewable diff. An adopted (unstamped) page is edited **only for a claim the diff actually broke** — never restyled, never expanded.

**The discipline here is restraint.** A skill that rewrites six pages because one function moved is worse than no skill, because now the PR diff is unreviewable.

### 4. Flag the documentation-shaped gaps the diff created

A new command with no how-to, a new env var absent from getting-started, a new failure mode with no runbook. **New pages and deletions are consent-gated** — propose, then write. That split is the whole write-mode policy: edits go straight in, creation and destruction ask.

### 5. Re-stamp and reconcile

Re-stamp every page touched, and update the manifest for anything created or removed.

### 6. Hand off

**What changed** — pages edited (one line each, naming the claim that moved), pages proposed and their verdict, pages deliberately untouched.

**Where it landed** — the paths, and the manifest if it moved.

**Next** — **commitkit**, then **prkit** (otherwise `git commit` and `gh pr create`). Docs land in the same PR as the code that changed them; that's the whole point of in-repo docs.

## Mode: `audit`

**Read-only. Writes nothing, ever.** It reports, and routes to [`update`](#mode-update) or [`init`](#mode-init) for the fixing. Reporting a problem and fixing it are separate invocations, deliberately.

Three checks per page, cheapest first:

- **Recency** — the page's stamp against the commits touching the code it documents, diffing from the stamped SHA while it is reachable and falling back to the date when it isn't. Grep-cheap, so it runs over **every** page. It is a prefilter, not a verdict: a stale stamp on an unchanged concept is fine.
- **Claim verification** — the load-bearing one. Every command, path, env var, flag, and endpoint on the page checked against the repo, with the allowlisted probes available on consent. A command that no longer exists is **broken**; a described behavior that changed is **stale**. This pass is budgeted and spends **highest-risk-first**, ordered by the recency prefilter.
- **Coverage** — documentable surface with no page at all: an undocumented CLI command, a deploy path with no runbook, a public entry point missing from the architecture page.

### The report

A table per page with a verdict, plus quoted evidence for anything that isn't `current`:

| Verdict | Means |
|---|---|
| `current` | claims check out against the code |
| `stale` | a described behavior changed |
| `broken` | a command, path, or var on the page no longer exists |
| `unverified` | an adopted page wikikit has never claim-checked — **distinct from stale** |
| `missing` | documentable surface with no page |

Add a **manifest-drift row** from the reconcile pass, and crown one next move.

Every report **opens** with a mandatory coverage line, because an audit that silently covered 12% reads exactly like a clean bill of health:

```
Recency: 312/312 · Claims verified: 40/312 (highest-risk first) · Not claim-checked: 272 (listed below)
```

The not-claim-checked pages are listed, not summarized as a count. A scope argument (`audit how-to/`) narrows the run explicitly; the coverage line reports the narrowing either way.

### Hand off

**What changed** — nothing. Say that outright; `audit` is read-only and a reader should never have to wonder.

**Where it landed** — inline in this reply. Offer to save it only if asked; there is no audit artifact by default.

**Next** — crown the single most-broken page and route it to [`update`](#mode-update), or to [`init`](#mode-init) when the gap is a missing page rather than a wrong one. **Nothing to fix is a valid, stated result** — say the set is current and stop.

## Mode: `publish`

**Opt-in, explicit-ask-only.** Mirrors the doc set out to the repo's GitHub Wiki tab by installing a workflow that syncs on every push to the doc home. wikikit writes the workflow file; **GitHub Actions does the syncing**, so nothing here pushes to a wiki from your machine.

The in-repo set stays the source of truth. The wiki is a **derived, disposable mirror**: delete it and re-sync and you lose nothing, because nothing originates there.

### What you are agreeing to

Three properties of GitHub wikis make this sharper than it looks. Say all three out loud before writing anything — a user who learns them from the aftermath will not thank you.

1. **The sync is destructive and one-way.** The action clears the wiki repo, copies the doc set in, and **force-pushes**. Any page created or edited in the wiki's web UI is **deleted on the next sync** — including on private repos, and including pages nobody in the doc set has ever heard of. The wiki becomes read-only in practice; the edit button stays there and lies. (This is true under both of the action's strategies, notwithstanding its own documentation, which describes force-push as `init`-only.)
2. **The page namespace is flat.** Wiki source files may sit in folders, but page URLs are built from the title alone, so `how-to/deploy.md` and `runbooks/deploy.md` both resolve to `/wiki/deploy` and one silently wins. The template below flattens path segments into the page name to make collisions impossible; the [collision scan](#2-scan-for-page-name-collisions) catches the residue before anything is installed.
3. **The wiki must be created by hand, once.** A repo's wiki has no git backend until a first page exists, and there is no API or `gh` command that creates one. The workflow will fail until a human clicks through the UI.

Editing permissions are **not** on this list. GitHub restricts public-repo wiki editing to collaborators by default, so the "strangers overwrite each other" hazard is gone — but note that property 1 makes collaborator edits just as doomed.

### 1. Preflight

Establish that publishing is even possible, and say which of these failed rather than installing a workflow that will go red on its first run:

```sh
gh repo view --json nameWithOwner,visibility,hasWikiEnabled
git ls-remote "$(gh repo view --json url -q .url).wiki.git" 2>&1 | head -1
```

| State | Do this |
|---|---|
| **Wiki feature disabled** | Stop. It's a repo setting (Settings → Features → Wikis); name the path and let the user flip it. |
| **Wiki enabled but never initialized** — `ls-remote` errors or returns nothing | Stop before writing the workflow. Tell the user to open the wiki tab and save any page (the action's own docs call this the "dummy page"), then re-run. Do not install a workflow that is guaranteed to fail. |
| **Wiki already has pages wikikit didn't write** | **This is the dangerous case.** Those pages will be destroyed by the first sync. Offer the rescue below before anything else, and get an explicit yes on the destruction. |
| **No `gh`, or unauthenticated** | Print the workflow for the user to add by hand, and name the preflight checks they should run themselves. Never claim a wiki state you couldn't read. |

**The rescue for existing wiki content** — pull it into the repo first, so the mirror doesn't eat it:

```sh
git clone "$(gh repo view --json url -q .url).wiki.git" /tmp/wiki-rescue
```

Anything worth keeping becomes a page in the doc set (mapped in the manifest as `adopted: true`, no stamp — a human wrote it). Anything not worth keeping is confirmed as deliberate loss. Only then continue.

### 2. Scan for page-name collisions

Flatten every page path in the doc set to its wiki page name — path separators become `-`, `index.md` becomes `Home` — and check for duplicates **before** installing anything:

```
docs/wiki/index.md                    → Home
docs/wiki/getting-started.md          → getting-started
docs/wiki/how-to/deploy-to-staging.md → how-to-deploy-to-staging
docs/wiki/runbooks/rollback.md        → runbooks-rollback
```

Flattening makes a collision nearly impossible, since the source paths are already unique — but it isn't a proof (`how-to/deploy.md` and `how/to-deploy.md` both flatten to `how-to-deploy`). **Report any collision and stop.** Renaming a source page is the fix, and that's the user's call, not a silent tiebreak.

### 3. Write the workflow, on consent

Show the file, name its path, and write it only on a yes. Default target `.github/workflows/publish-wiki.yml`; adapt `docs/wiki` to the doc home the ladder actually resolved, and the branch to the repo's real default.

```yaml
name: Publish wiki

on:
  push:
    branches: [main]
    paths:
      - 'docs/wiki/**'
      - '.github/workflows/publish-wiki.yml'
  workflow_dispatch:

permissions:
  contents: write

concurrency:
  group: publish-wiki
  cancel-in-progress: false

jobs:
  publish-wiki:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      # The wiki page namespace is flat: docs/wiki/how-to/deploy.md and
      # docs/wiki/runbooks/deploy.md would both land on /wiki/deploy. Flatten
      # each path into a unique page name and rewrite in-repo links to match.
      - name: Flatten the doc set into wiki page names
        run: |
          set -euo pipefail
          src=docs/wiki
          out=.wiki-build
          mkdir -p "$out"
          find "$out" -mindepth 1 -delete   # scoped to the staging dir only

          find "$src" -name '*.md' -type f | while read -r f; do
            rel="${f#"$src"/}"
            page="${rel%.md}"
            flat="${page//\//-}"
            if [ "$page" = "index" ]; then flat="Home"; fi
            dir="$(dirname "$rel")"
            if [ "$dir" = "." ]; then dir=""; fi

            # [Deploy](how-to/deploy.md) -> [Deploy](how-to-deploy), resolving
            # ../ against the page's own directory first. Anchors are kept;
            # absolute URLs and links to non-page files are left alone.
            WIKI_DIR="$dir" perl -pe '
              s{\]\(([^):#]+?)\.md(#[^)]*)?\)}{
                my ($p, $anchor) = ($1, $2 // "");
                $p = "$ENV{WIKI_DIR}/$p" if $ENV{WIKI_DIR} ne "";
                $p =~ s{^\./}{};
                $p =~ s{/\./}{/}g;
                1 while $p =~ s{[^/]+/\.\./}{};
                $p = ($p eq "index") ? "Home" : do { $p =~ s{/}{-}g; $p };
                "]($p$anchor)"
              }ge
            ' "$f" > "$out/$flat.md"
          done

      - uses: Andrew-Chen-Wang/github-wiki-action@v5
        with:
          path: .wiki-build
          # The flatten step above owns page naming and link rewriting, so the
          # action's own preprocessing would fight it.
          preprocess: false
          disable-empty-commits: true
          # Start safe: prints what it would push without touching the wiki.
          # Flip to false once the first run's output looks right.
          dry-run: true
```

Four choices in there are load-bearing, so don't quietly drop them:

- **`dry-run: true` on install.** The first run is a rehearsal. A destructive force-push should never be something the user discovers happening. Say clearly that publishing is not live until they flip it.
- **`preprocess: false`.** The action's own link rewriting assumes wiki paths mirror source paths, which is exactly what the flatten step breaks. One owner for the transformation.
- **`concurrency`** without `cancel-in-progress` — two force-pushes racing on one wiki repo is how a sync lands half-applied.
- **`permissions: contents: write`**, and nothing else. The built-in `GITHUB_TOKEN` is enough; a wiki sync never needs a PAT, and being asked for one is a signal something is wrong.

Pinning `@v5` follows the action's documented usage. For a repo that pins actions to commit SHAs, match that convention instead and say you did.

### 4. Hand off

**What changed** — the workflow written (or the preflight gate that stopped you), whether existing wiki pages were rescued or knowingly abandoned, and any collisions found.

**Where it landed** — the workflow path, the doc home it syncs, the branch that triggers it, and — stated plainly — that it is in **dry-run**, so nothing has been published yet.

**Next** — push the workflow and run it once from the Actions tab (`workflow_dispatch`) to read the dry-run output. If it looks right, flip `dry-run` to `false`; that's the commit that makes the wiki live. Commit with **commitkit** when installed, otherwise `git add` and commit. If the preflight stopped you, the crowned move is the thing that unblocks it — creating the first wiki page by hand, or enabling the wiki feature.

## Writing standards

The rules that separate documentation from generated filler, stated as bans:

- **No restating the code.** A page that narrates what a function does line by line is worse than the function.
- **No documenting the aspirational.** If it isn't in the repo, it isn't in the docs.
- **No unmixed modes.** A how-to answers one goal and does not explain the architecture; an explanation does not become a tutorial halfway down.
- **No ceremonial preamble.** "This document provides an overview of…" — cut it. Start at the first useful sentence.
- **Every command copy-pasteable and verified.** Real flags, real paths, real names.
- **Task-shaped how-to titles** — "Deploy to staging", not "Deployment".

For general AI-writing tells — em-dash overuse, rule-of-three cadence, hedging, promotional puffery — offer a **humankit** pass when it's installed. wikikit does not re-carry that list.

## Notes

- **GitHub Wiki publishing is opt-in and fenced, not a default.** [`publish`](#mode-publish) exists, and nothing routes into it: the loop never suggests it, and a request has to name the wiki to reach it. The fence is there because the mirror is destructive and one-way — the wiki's edit button keeps working and every edit made through it dies at the next sync. A repo that treats its wiki as a place people *write* should not install this; a repo that treats it as a rendered view of `docs/wiki/` should.
- **The wiki is downstream, always.** wikikit never reads the wiki as a source of truth, never round-trips edits back into the repo automatically, and never runs `audit` against it. If the wiki and the doc set disagree, the doc set is right by definition.
- **Consent, by operation.** The `init` map, new pages, deletions, the README markers, a doc-home migration, and the probe run all ask. Edits to existing pages in `update` do not — they're bounded by the restraint rule and land in a reviewable diff. `audit` asks for nothing except probes, because it changes nothing.
- **No mutating execution, ever.** The probe allowlist is fixed and side-effect-free. wikikit never installs, builds, migrates, or deploys to verify a claim — an unverifiable claim is reported as unverified, not tested into existence.
- **No doc-site scaffolding.** wikikit writes content and updates nav for an engine that already exists. It never adds one.
- **No marketing copy, no translation.** Landing pages, feature blurbs, changelogs, and localization are all out.
- **Existing project convention wins.** A repo with its own docs location, page naming, or engine layout gets followed, not overridden — and wikikit says which convention it followed.
- **No filesystem** (e.g. a browser-based agent)? Print each page as a fenced block labeled with its path, print the manifest the same way, and name the probes the user should run themselves. Never report a page written that you could not write.
