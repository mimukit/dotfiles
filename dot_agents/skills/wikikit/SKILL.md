---
name: wikikit
description: >-
  Generate and maintain a project's reader-facing documentation in-repo (getting-started, how-to guides, architecture overview, runbooks), every command verified against the code, in four modes: init, update, audit, and an opt-in publish that mirrors the set to the GitHub wiki. Use when the user says "write docs for this project", "update the docs", "our docs are stale", or "sync the docs to the GitHub wiki". Not an agent handoff, and not the glossary or ADRs.
license: MIT
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
metadata:
  internal: false
---

# wikikit

The documentation a **reader** opens: how do I run this, how do I do the one task I came here for, how is it put together, and what do I do at 3am when it's down. wikikit generates that set from the codebase as it actually is, keeps it true as the code changes, and reports honestly when it has gone stale. **It is not the GitHub Wiki tab**, because everything it writes is in-repo Markdown, versioned with the code and reviewed in the same pull request. Mirroring that set out to the wiki tab is available as an opt-in [`publish`](modes/publish.md) mode, which never fires unless you ask for it by name.

A repo built by agents accumulates plans, reviews, QA docs, and decision records, and still ships a README that says `npm install` because that's what the scaffold wrote a year ago. The knowledge exists; it's just scattered across artifacts nobody outside the project will ever read. wikikit is the half that faces outward.

## What wikikit is not

- **Not the GitHub Wiki.** In-repo Markdown is the source of truth in every mode, versioned with the code and reviewed in the same PR. The wiki tab is at most a **derived, disposable mirror**, and only when [`publish`](modes/publish.md) is asked for by name. wikikit never reads the wiki as input and never treats it as canonical.
- **Not the domain model.** A glossary (`CONTEXT.md`) and decision records (`docs/adr/`) have one owner, which is **domainkit** when it's installed and the human otherwise. A page that needs a term **links** to the glossary instead of defining it; an architecture page that needs a rationale links the ADR by number instead of paraphrasing it. A term missing from the glossary is routed, never invented inline.
- **Not process artifacts.** Plans, QA plans, reviews, handoffs, and agent instruction files (`CLAUDE.md` and its equivalents) are written for a maintainer mid-flow, expire, and are never read as sources of truth for reader docs or written by this skill.
- **Not an API reference generator.** Where a generator exists (TypeDoc, Sphinx autodoc, an OpenAPI spec) wikikit links its output unchanged rather than hand-writing reference material that drifts within a week.

## When this fires

- **`init`.** "Write docs for this project", "document this repo", "we have no docs", "generate a getting-started guide". Bootstraps the set from the codebase.
- **`update`.** "Update the docs", "the docs are out of date after this change", or a docs pass right after a feature lands. Refreshes only what the change invalidated.
- **`audit`.** "Are our docs stale", "check the docs against the code", "what's undocumented". Read-only sweep. **Writes nothing, ever.**
- **`publish`.** **Explicit ask only.** "Publish the docs to the GitHub wiki", "sync `docs/wiki/` to the wiki tab", "set up the wiki action". Installs a workflow that mirrors the set to the wiki.

**If no mode is clear, ask.** `audit` is free and `init` writes a dozen files; never guess between them.

**`publish` is never inferred.** It is not part of the doc loop, no other mode routes into it, and "the docs are out of date" or "publish the docs" *alone* means [`update`](modes/update.md), not this. It fires only when the request names the GitHub wiki, the wiki tab, or the sync workflow itself. A repo that never asks for it never learns it exists.

## Locate the doc sets

Every mode opens the same way, so all three agree on where docs live before anything reads or writes. **Name every set found in the mode's first line of output**, because a missing set has to be visible immediately, not inferred from an empty result.

### Find existing sets

One `**/.wikimap.yaml` glob, scoped to the repo root plus the workspace globs (`pnpm-workspace.yaml`, `package.json` `workspaces`, `go.work`, a Cargo workspace), honoring `.gitignore` so a vendored tree can't inject a set. No root registry: the manifest travels with the set it describes, and a set added later is found automatically.

### Run the detection ladder for a repo with no set

Take the first rung that matches, and **say which rung matched before writing anything**:

| # | Rung | Where docs go |
|---|---|---|
| 1 | **A configured docs engine**: `mkdocs.yml`, `docusaurus.config.*`, `.vitepress/`, `astro.config.*` with Starlight, `conf.py`, a Nextra config | that engine's configured content directory, with its nav/sidebar updated in the same pass |
| 2 | **An existing reader-doc tree**: a populated `docs/` that isn't only agent artifact directories, or `documentation/`, `website/docs/` | adopt it as-is; do not migrate |
| 3 | **Fallback** | `docs/wiki/`, created on first write |

`docs/wiki/` keeps reader docs quarantined from the agent artifact directories that share the `docs/` parent, so a reader never lands in a QA plan. But **an existing engine always wins**, because wikikit writes into the site the repo already runs, and never introduces MkDocs or Docusaurus into a repo that doesn't have one.

**In a workspace, the root set is always written; a package earns its own set only when it is independently published or independently runnable.** Run the ladder once for the root, then once per qualifying package (`packages/<x>/docs/`). State the split before writing anything: root-only makes an architecture page unusable past about four packages, and always-per-package is wrong for an app monorepo where the reader wants one getting-started.

### Reconcile the manifest against disk

A central manifest is the one map shape that can be wrong while looking right, so every mode pays this price up front, **before any work starts**:

- pages on disk with no manifest entry,
- entries whose page is gone,
- `documents:` globs matching nothing,
- a `home:` that no longer matches the ladder, usually a docs engine that arrived after `init`.

`init` and `update` repair on consent. `audit` reports drift as its own row and repairs nothing, because it writes nothing. **A migration is never implicit**: when rung 1 starts matching where rung 3 matched before, name both paths and offer the `git mv` plus nav update as one consented step. Declined, wikikit keeps writing where the manifest says and reports the divergence each run.

## The doc map

The doc map is the unit all three modes operate on. It lives at `<doc home>/.wikimap.yaml`, dotfile-prefixed so GitHub's folder view and every engine build skip it without a config edit, and carries one entry per page with its Diátaxis mode and the globs of code it documents:

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

`documents:` is what makes `update` cheap, giving a code-path → page lookup that doesn't read every page, and what gives `audit` its recency prefilter.

### The page vocabulary

| Page | Diátaxis mode | Documents |
|------|---------------|-----------|
| `index.md` | none | entry point and table of contents |
| `getting-started.md` | tutorial | install → run → first successful thing |
| `how-to/<task>.md` | how-to | one task per page, goal-shaped |
| `how-to/set-up-a-dev-environment.md` | how-to | the derivable half of contributor docs |
| `how-to/cut-a-release.md` | how-to | release steps that actually exist in the repo |
| `architecture.md` | explanation | components, boundaries, data flow, links to ADRs |
| `runbooks/<scenario>.md` | how-to (operator) | deploy, rollback, incident response, backup/restore |
| `reference.md` | reference | declared surface only: commands, flags, env vars, config keys |

**This table is the vocabulary, not a quota.** The map is derived from the repo: a library with no deployment gets no runbooks, a CLI gets a commands page, a repo with a TypeDoc build gets no `reference.md` at all.

Diátaxis governs internally and stays out of the reader's face, because the four modes are the rule that keeps doc types unmixed, not jargon to print on the page. A how-to must not drift into explanation; an architecture page must not turn into a tutorial.

Two boundaries the vocabulary encodes:

- **`CONTRIBUTING.md` is linked, never written.** Dev-environment setup and release steps are in the repo and verify like any other how-to. PR etiquette, a code of conduct, and review norms are a social contract that exists nowhere in code, so writing them would break the grounding rule on the repo's most visible contributor page. `index.md` links the file if it exists.
- **`reference.md` covers declared surface only**, meaning things declared in a single place and re-verifiable in a single grep: CLI commands, flags, env vars, config keys. Library symbols and hand-maintained HTTP endpoint tables are refused and routed to a generator. This narrow exception exists so a CLI with twenty flags and no docs tooling gets something rather than nothing.

### The provenance stamp

Every page wikikit authors ends with one line:

```markdown
_Verified against `main`@`a1b2c3d` on 2026-08-06._
```

Both halves earn their place. `audit` diffs from the SHA while it is still reachable, and falls back to the date when a rebase or squash-merge has orphaned it, so it is precise when it can be and degrades instead of lying when it can't.

**A page with no stamp is not stale, it is unverified.** That's how adopted pages are marked: a page found under rung 2 gets a manifest entry with `documents:` globs and `adopted: true`, and no stamp. wikikit can see it and route to it, and has never checked a claim on it. It earns its first stamp the first time a verification pass genuinely covers it. Adoption is a mapping act, not an authorship claim over prose a human wrote.

## Grounding: verify before you write

**Every factual claim is verified against the repo before it ships.** Commands come from the actual `package.json`, `Makefile`, `pyproject.toml`, or `justfile`; paths exist; env vars are actually read somewhere; endpoints are actually routed. **A feature wikikit cannot find in code does not get documented.** This is the single rule that separates a doc set from plausible fiction, and it holds in all three modes.

Static reading is the default, and it proves a script is *declared*, not that it runs. So wikikit may also execute a **fixed allowlist of side-effect-free probes**, after **one consent ask per run**:

| Allowed | Never |
|---|---|
| `<command> --help`, `-h` | anything that installs (`npm install`, `pip install`, `brew`) |
| `<command> --version`, `-V` | anything that builds, compiles, or bundles |
| `make -n <target>`, `make help` | anything that migrates a database or seeds data |
| bare script listings (`npm run`, `pnpm run`, `yarn run`, `just --list`) | anything that deploys, publishes, or pushes |
| read-only git (`git log`, `git diff`, `git show`, `git rev-parse`) | anything that writes outside the doc set, or calls a live service |

The allowlist is written here and **never inferred**. A command that looks harmless but isn't on the list is not run, so report the claim as unverified instead. `audit`'s "read-only" means *it writes no files*, so probes are available there too; that is where they pay off most.

## The modes

The mode bodies live in one file each under `modes/`. Route with [When this fires](#when-this-fires), read that one file, and follow it. Everything above this line applies to every mode and is not restated in the mode files.

- Mode `init` → read [modes/init.md](modes/init.md), then follow it.
- Mode `update` → read [modes/update.md](modes/update.md), then follow it.
- Mode `audit` → read [modes/audit.md](modes/audit.md), then follow it.
- Mode `publish` → read [modes/publish.md](modes/publish.md), then follow it.

## Writing standards

The rules that separate documentation from generated filler, stated as bans:

- **No restating the code.** A page that narrates what a function does line by line is worse than the function.
- **No documenting the aspirational.** If it isn't in the repo, it isn't in the docs.
- **No unmixed modes.** A how-to answers one goal and does not explain the architecture; an explanation does not become a tutorial halfway down.
- **No ceremonial preamble.** Cut "This document provides an overview of…". Start at the first useful sentence.
- **Every command copy-pasteable and verified.** Real flags, real paths, real names.
- **Task-shaped how-to titles**, so "Deploy to staging", not "Deployment".

For general AI-writing tells (em-dash overuse, rule-of-three cadence, hedging, promotional puffery) offer a **humankit** pass when it's installed. wikikit does not re-carry that list.

## Notes

- **GitHub Wiki publishing is opt-in and fenced, not a default.** [`publish`](modes/publish.md) exists, and nothing routes into it: the loop never suggests it, and a request has to name the wiki to reach it. The fence is there because the mirror is destructive and one-way, so the wiki's edit button keeps working and every edit made through it dies at the next sync. A repo that treats its wiki as a place people *write* should not install this; a repo that treats it as a rendered view of `docs/wiki/` should.
- **The wiki is downstream, always.** wikikit never reads the wiki as a source of truth, never round-trips edits back into the repo automatically, and never runs `audit` against it. If the wiki and the doc set disagree, the doc set is right by definition.
- **Consent, by operation.** The `init` map, new pages, deletions, the README markers, a doc-home migration, and the probe run all ask. Edits to existing pages in `update` do not, because they're bounded by the restraint rule and land in a reviewable diff. `audit` asks for nothing except probes, because it changes nothing.
- **No mutating execution, ever.** The probe allowlist is fixed and side-effect-free. wikikit never installs, builds, migrates, or deploys to verify a claim, so an unverifiable claim is reported as unverified, not tested into existence.
- **No doc-site scaffolding.** wikikit writes content and updates nav for an engine that already exists. It never adds one.
- **No marketing copy, no translation.** Landing pages, feature blurbs, changelogs, and localization are all out.
- **Existing project convention wins.** A repo with its own docs location, page naming, or engine layout gets followed, not overridden, and wikikit says which convention it followed.
- **No filesystem** (e.g. a browser-based agent)? Print each page as a fenced block labeled with its path, print the manifest the same way, and name the probes the user should run themselves. Never report a page written that you could not write.
