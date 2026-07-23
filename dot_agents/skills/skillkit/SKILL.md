---
name: skillkit
description: >-
  Create a new AI agent skill from scratch — kit-convention naming, drafting, live testing, and publishing included. Use when the user wants to author, scaffold, or draft a new skill, runs "/skillkit", or says something like "help me make a skill for X". Interviews for intent, proposes on-brand kit names, drafts a conventions-compliant SKILL.md.
license: MIT
allowed-tools: Read, Edit, Write, Bash, AskUserQuestion, WebSearch, WebFetch
metadata:
  internal: false
---

# skillkit

Authoring skill for a personal skill collection. It turns a rough idea ("I want a skill that does X") into a lean, conventions-compliant `SKILL.md` in the host collection's skill layout, then hands the user a live-test loop to try it for real. Every skill is authored from scratch — never forked — and follows the conventions inlined below; skillkit exists so you don't re-derive those rules each time.

## Invocation

`/skillkit` — or any natural "create/author/scaffold a skill" request. If the user hasn't said what the skill should *do*, ask before anything else. Drive the procedure below one step at a time; don't jump ahead to drafting before intent, visibility, provenance, and name are settled.

## Procedure

### 1. Gather intent
Ask what the skill should do and *when it should trigger* (the real user phrasings). Optionally ask for example skill links; if given, skim them for structure ideas — non-blocking, and only if fetching is available. Capture: the job, the trigger conditions, and any hard constraints (tools it needs, things it must not do).

### 2. Visibility (internal or public?)
Ask whether this is an **internal** repo-only skill or a **public** publishable one — it changes the rules for everything downstream.
- **internal**: a maintenance/meta skill for the host repo. Repo coupling is fine — it may reference the repo's conventions doc, build tooling, and use repo-relative links. Stamp `metadata.internal: true`. skills.sh hides it from discovery.
- **public**: a shareable skill. It **must** follow [Portability](#portability-public-skills-only) below and stamp `metadata.internal: false`. It gets discovered and listed on skills.sh automatically once pushed to a public collection repo.

### 3. Provenance (original vs. "my version of")
Ask: is this **original**, or **your version of an upstream skill**? Either way it's authored from scratch here; the answer just informs how much you lean on the upstream for structure ideas ([Gather intent](#1-gather-intent)).

### 4. Propose names
Follow the host collection's naming convention when it has one. Otherwise suggest **3–5 `kit` names** and recommend one: one lowercase word, the **functional term leads** so it stays searchable (people search `commit`, not `kit`), `kit` appended, and shorten an awkward root rather than force a clumsy join (`humanize` → `humankit`, not `humanizekit`). Avoid collisions with well-known tools (`speckit`, `shipkit`, anything already popular): when network access exists, search the candidate on the web and in the skills.sh directory; when offline, state that the popularity check was skipped. Let the user pick. The chosen name **must** equal the directory name.

### 5. Draft
Create the skill in the host collection's documented layout from the [Frontmatter template](#frontmatter-template) below, applying the **Quality bar**, and stamp `metadata.internal` from [Visibility](#2-visibility-internal-or-public). In a collection repo this is commonly `skills/<name>/SKILL.md`; standalone, use the agent's discovered skills directory such as `.claude/skills/<name>/SKILL.md`. Keep it lean — prefer one file.
- If **public**, apply the **Portability** checklist below as a hard gate — the skill must stand alone once installed.

### 6. Review loop
Show the draft. Take edits and iterate until the user explicitly approves. Don't proceed to testing on a draft the user hasn't signed off.

### 7. Live test
Don't install the skill yourself — hand the user the commands to drive the live trial. If the collection provides dev-link tooling (check its README or Makefile for a link/unlink target), tell them to inject the skill with that; otherwise have them symlink or copy `skills/<name>` into their agent's skills directory (e.g. `~/.claude/skills/<name>`). Then test in a **fresh session** — the skill list loads at startup, so a running session won't see the new skill. No scratch test-plan file; testing here is done live and directly. Suggest they exercise it against reality:
- fire it with a few varied, realistic phrasings that *should* trigger it, plus a near-miss or two that should *not* (guards against overtriggering);
- confirm the real run follows the drafted procedure end to end and produces the artifact or outcome the skill promises.

When done testing, they remove the dev link the same way it was added (the collection's unlink command, or deleting the symlink/copy).

### 8. Finish
- Run the collection's skill lint if it has one; fix any errors and address warnings before handing off. Without one, self-check the draft against the [Conventions](#conventions), **Quality bar**, and (for public skills) **Portability** sections.
- Update whatever the collection uses to list its skills — typically a README skills table, and for public skills a `skills.sh.json` directory-grouping file if the repo has one.
- Hand off: surface a suggested conventional commit message (e.g. `feat(<name>): add <name> skill`) for the user to run. **Do not commit automatically** — committing is the user's call.

## Conventions

### Frontmatter template

```yaml
---
name: <matches directory>
description: >-
  <what it does>. Use when <explicit English trigger>.
license: MIT
allowed-tools: <only if the skill needs a restricted set>
metadata:
  internal: true   # true = repo-only meta skill; false = public/publishable
---
```

### Prose formatting
**No hard wrapping.** Write each paragraph and list item as one continuous line; let the editor and renderer soft-wrap. Fixed-width line breaks mid-sentence buy nothing — the agent reads the text regardless of newlines, and every Markdown renderer soft-wraps anyway. Keep line structure only where it is meaningful: code fences, tables, and YAML frontmatter (a folded `description: >-` scalar is fine).

### Documentation artifact naming
When a skill creates a durable Markdown artifact under `docs/`, follow the host collection's convention when it has one. Otherwise use `<type>-<slug>-YYYY-MM-DD.md`: a lowercase type prefix, a short lowercase kebab-case subject slug, and the artifact's ISO creation date at the end (for example, `docs/plans/plan-sso-login-2026-07-23.md`). Keep that creation date stable when the file is edited. Update the same artifact in place; for a genuine same-day collision, make the slug more specific and only then insert a sequence immediately before the date (`research-auth-providers-02-2026-07-23.md`). ADRs retain their sequence as `docs/adr/adr-NNNN-<slug>-YYYY-MM-DD.md`. Multi-file artifacts put the convention on their bundle directory, such as `docs/verify/verify-<slug>-YYYY-MM-DD/`, while structural child names remain fixed. Inline the applicable rule in every public skill that creates such an artifact so the installed skill remains self-contained.

### Cross-referencing steps
**Never reference a step by its number** (a bare "see step N" citation). A bare number binds to a step's *position*, so inserting or reordering steps silently makes it point at the wrong one. Reference the step's *identity* instead: for a step with a heading, link to it by name with a GitHub anchor (`[Gather intent](#1-gather-intent)` — GitHub builds the anchor from the full heading text: lowercase, punctuation dropped, spaces → hyphens); for a list item with no heading, name the action in prose rather than citing its ordinal.

## Quality bar

Apply these while drafting; they are the difference between a skill that triggers and reads well and one that doesn't:

- **Front-load the leading word** — the first words of `name` and `description` do the invocation work; put the functional term there.
- **"Use when" trigger** — `description` starts with what it does, then a plain-English "Use when …" clause, phrased slightly pushy to fight undertriggering (name the phrasings/commands that should fire it).
- **Skills are for what the model can't already do** — a skill only fires for tasks the base model can't handle directly. If the guidance is obvious, it won't trigger no matter how you word it.
- **Stay lean; progressive disclosure** — prefer one `SKILL.md`. Add a satellite file (`references/…`) only when content is *large* **and** needed *only sometimes*; guidance needed on every run belongs inline.
- **Intent over incantation** — a skill says *what to accomplish and why*, and lets the agent work out the exact invocation. Pin an exact command **only** when it's a stable public contract (`git commit`, `gh pr create`, `grep`, `jq`) where re-deriving it every run just burns tokens and invites variance — and even then, make it self-correcting ("run `gh pr create …`; if a flag is rejected, check `gh pr create --help`"). Never hardcode a volatile or vendor tool's syntax, and never encode a tool's *internal* behavior as if it were contract (output-format parsing, help-text scraping, default-shape assumptions) — that's the brittle stuff that breaks on a tool update; describe the goal and let the agent read the docs. The failure mode to avoid on both ends: pinning brittle syntax that breaks loudly, or over-abstracting a frozen command into "figure it out" that taxes every run quietly.
- **One meaning, one place** — no duplication. For internal skills, point to the host repo's conventions doc instead of restating it; for public skills, inline what they need (see Portability).
- **Prune no-ops** — test every line for relevance; delete weak sentences rather than trimming them. Explain the *why* behind a rule when it isn't obvious.
- **No hard-wrapping** — per [Prose formatting](#prose-formatting).
- **Durable docs artifacts** — when the skill writes Markdown under `docs/`, apply [Documentation artifact naming](#documentation-artifact-naming) and inline the applicable convention in a public skill.
- **kit naming + frontmatter** — obey the naming rules in [Propose names](#4-propose-names) and the [Frontmatter template](#frontmatter-template) exactly; `name` must match the directory; declare `metadata.internal`.

## Portability (public skills only)

A public skill is installed on its own into arbitrary environments — only its own directory travels, so it must stand alone:

- **Self-contained** — inline the conventions it relies on. No repo-relative links (`../…`), and no hard dependency on the host repo's Makefile, conventions doc, or helper tooling. If it needs a helper script, bundle it inside the skill's own directory.
- **Machine/OS-agnostic** — no absolute paths, no platform-specific assumptions; prefer instructions that work on any shell or none.
- **Environment-degrading output** — when a filesystem and shell are available, write/edit files directly; when they aren't (e.g. a browser-based agent), print the finished artifact as a codeblock for the user to save, and skip repo-only steps like dev-linking and linting.

Internal skills are exempt — they live and die in their repo and may use its machinery freely.

## Notes

- skillkit itself is **public** (`metadata.internal: false`) — inside its home collection it can lean on the repo's link/lint tooling, but everything it needs to author a skill is inlined here, so it works standalone wherever it's installed.
- Add scripts or satellite files to a *new* skill only when it genuinely needs one — never speculatively. Per-skill scripts live in the skill's own directory, not in any repo-root location.
