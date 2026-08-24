---
name: skillkit
description: >-
  Create a new AI agent skill from scratch, with kit-convention naming, drafting, live testing, and publishing included. Use when the user wants to author, scaffold, or draft a new skill, runs "/skillkit", or says something like "help me make a skill for X". Interviews for intent, proposes on-brand kit names, drafts a conventions-compliant SKILL.md.
license: MIT
disable-model-invocation: true
allowed-tools: Read, Edit, Write, Bash, AskUserQuestion, WebSearch, WebFetch
metadata:
  internal: false
---

# skillkit

Authoring skill for a personal skill collection. It turns a rough idea ("I want a skill that does X") into a lean, conventions-compliant `SKILL.md` in the host collection's skill layout, then hands the user a live-test loop to try it for real. Every skill is authored from scratch, never forked, and follows the conventions inlined below; skillkit exists so you don't re-derive those rules each time.

## Invocation

`/skillkit`, or any natural "create/author/scaffold a skill" request. If the user hasn't said what the skill should *do*, ask before anything else. Drive the procedure below one step at a time; don't jump ahead to drafting before intent, visibility, provenance, and name are settled.

## Procedure

### 1. Gather intent
Ask what the skill should do and *when it should trigger* (the real user phrasings). Optionally ask for example skill links; if given, skim them for structure ideas, which is non-blocking and only worth doing if fetching is available. Capture the job, the trigger conditions, and any hard constraints (tools it needs, things it must not do).

Then check that a **new skill** is the right shape, because the collection's index is a human's to hold. A skill earns its own directory when a person genuinely wants to choose it: a distinct moment, a distinct decision they'd make deliberately. When the choice is one the agent should make from context instead, it belongs as a **mode inside an existing skill**, since a mode costs one branch in that skill's description where a new skill costs a permanent entry the user has to remember. Name the existing skill and let the user decide; don't refuse the request.

### 2. Visibility (internal or public?)
Ask whether this is an **internal** repo-only skill or a **public** publishable one, because it changes the rules for everything downstream.
- **internal**: a maintenance/meta skill for the host repo. Repo coupling is fine, so it may reference the repo's conventions doc, build tooling, and use repo-relative links. Stamp `metadata.internal: true`. skills.sh hides it from discovery.
- **public**: a shareable skill. It **must** follow [Portability](#portability-public-skills-only) below and stamp `metadata.internal: false`. It gets discovered and listed on skills.sh automatically once pushed to a public collection repo.

### 3. Provenance (original vs. "my version of")
Ask: is this **original**, or **your version of an upstream skill**? Either way it's authored from scratch here; the answer just informs how much you lean on the upstream for structure ideas ([Gather intent](#1-gather-intent)).

### 4. Propose names
Follow the host collection's naming convention when it has one. Otherwise suggest **3–5 `kit` names** and recommend one: one lowercase word, the **functional term leads** so it stays searchable (people search `commit`, not `kit`), `kit` appended, and shorten an awkward root rather than force a clumsy join (`humanize` → `humankit`, not `humanizekit`). Avoid collisions with well-known tools (`speckit`, `shipkit`, anything already popular): when network access exists, search the candidate on the web and in the skills.sh directory; when offline, state that the popularity check was skipped. Let the user pick. The chosen name **must** equal the directory name.

### 5. Draft
Create the skill in the host collection's documented layout from the [Frontmatter template](#frontmatter-template) below, applying the **Quality bar**, and stamp `metadata.internal` from [Visibility](#2-visibility-internal-or-public). In a collection repo this is commonly `skills/<name>/SKILL.md`; standalone, use the agent's discovered skills directory such as `.claude/skills/<name>/SKILL.md`. Keep it lean, and prefer one file.
- If **public**, apply the **Portability** checklist below as a hard gate: the skill must stand alone once installed.

### 6. Review loop
Show the draft. Take edits and iterate until the user explicitly approves. Don't proceed to testing on a draft the user hasn't signed off.

### 7. Live test
Don't install the skill yourself. Hand the user the commands to drive the live trial. If the collection provides dev-link tooling (check its README or Makefile for a link/unlink target), tell them to inject the skill with that; otherwise have them symlink or copy `skills/<name>` into their agent's skills directory (e.g. `~/.claude/skills/<name>`). Then test in a **fresh session**, because the skill list loads at startup, so a running session won't see the new skill. No scratch test-plan file; testing here is done live and directly. Suggest they exercise it against reality:
- fire it with a few varied, realistic phrasings that *should* trigger it, plus a near-miss or two that should *not* (guards against overtriggering);
- confirm the real run follows the drafted procedure end to end and produces the artifact or outcome the skill promises;
- settle any line you suspect is a **no-op** by running it, not by arguing. A no-op is an instruction the model already obeys by default, so the test is model-relative: delete the suspect line, run the same phrasing again, and keep the line only when the behavior changes.

When done testing, they remove the dev link the same way it was added (the collection's unlink command, or deleting the symlink/copy).

### 8. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

First finish the mechanical tail: run the collection's skill lint if it has one (fix errors and address warnings; without one, self-check against the [Conventions](#conventions), **Quality bar**, and, for public skills, **Portability**), and update whatever the collection uses to list its skills (typically a README skills table, and a `skills.sh.json` directory-grouping file if the repo has one). Then close:

**What changed.** Report the skill created (name, visibility, file count), the listing surfaces updated, and the lint or self-check result.

**Where it landed.** Give the skill's directory path, and whether a dev link from [Live test](#7-live-test) is still in place (it should be removed by now; say so if it isn't).

**Next.** The work is uncommitted, so the move is to commit it: suggest a conventional message (e.g. `feat(<name>): add <name> skill`) for the user to run. **Never commit automatically**, because committing is the user's call.

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

### Information hierarchy
A skill is built from **steps** (the ordered actions the agent performs) and **reference** (definitions, rules, and facts consulted on demand). The two mix freely: all steps, all reference, or both. What you decide for each piece is where it sits on a ladder ranked by how immediately the agent needs it. An **in-file step** is the primary tier; **in-file reference** is consulted on demand, and a flat peer-set of rules on one rung is a fine arrangement rather than a smell; **disclosed reference** is pushed into a satellite file inside the skill's own directory and loaded only when its pointer fires.

**Disclose by branch, not by size.** Inline what every branch needs, and push behind a pointer what only some branches reach, where a mode-filtered catalog that each run reads a third of is the clean case. Push too much down and you hide material the agent needs; push too little and the top bloats. Neither direction is the safe default.

**Co-locate a concept**: keep a definition, its rules, and its caveats under one heading rather than scattered through the file. Scattering is not duplication, since duplication repeats one meaning in two places while scattering fragments one meaning across many, and it fails differently, because the agent reads one part and never meets the rest.

**Sprawl** is the failure mode: a skill simply too long, even when every line is live and unique. Attention thins across the excess. The cure is the ladder, not a trim pass.

### Completion criteria
**Every step ends on a completion criterion, the condition that tells the agent the work is done.** A step without one ends when the agent feels finished, which is the largest single source of run-to-run variance. Two properties make it a lever. **Clarity**: can the agent tell done from not-done? A vague bound ("understanding reached", "keep it lean") invites **premature completion**, where the step ends early because attention has already slipped to the steps still visible ahead of it. **Demand**: how much the wording requires. "Every modified model accounted for" forces real digging where "produce a change list" does not, so prefer the exhaustive form to the productive one. Demand is not step-bound; "every rule applied" binds a body of flat reference the same way, which is how an all-reference skill still carries a bar. The strongest criteria are both checkable and exhaustive.

**Sharpen a rushed step's bound first**, because that edit is local and cheap. Split the sequence only when the bound is irreducibly fuzzy *and* you have watched the rush happen, and note that splitting works only across a real context boundary, meaning a hand-off document or a subagent dispatch. An inline call leaves the later steps in context and hides nothing.

### Prose formatting
**No hard wrapping.** Write each paragraph and list item as one continuous line; let the editor and renderer soft-wrap. Fixed-width line breaks mid-sentence buy nothing, because the agent reads the text regardless of newlines, and every Markdown renderer soft-wraps anyway. Keep line structure only where it is meaningful: code fences, tables, and YAML frontmatter (a folded `description: >-` scalar is fine).

### Prose register
**A skill writes for two different readers, and they need opposite prose.** Text a skill writes back to *its own operator* (QA steps, handoff documents, status snapshots, `Hand off` sections, next-move lines, preview-and-confirm lines) is procedural: write it in ASD-STE100 Simplified Technical English. One instruction per sentence. Procedural sentences 20 words or fewer, descriptive sentences 25 or fewer. Active voice, present tense, name the actor. No metaphor, idiom, or second meaning. Pick one term per concept and keep it *within a single document*; the rule never reaches across documents. Text a person reads *to form an opinion* (plan context, research recommendations, ADR rationale, review verdicts) is explanatory and keeps uneven rhythm and a stated position; do not apply STE to it. Machine-read or format-bound text is exempt: commit subjects, issue titles, prompts, design tokens, code, paths, commands, and quoted source. **Content the skill produces for a third-party audience is out of scope entirely**, including project documentation, published prose, and UI copy, because that is production writing for readers outside the session and needs room to explain a concept. Precedence: an explicit user instruction, then the target repository's documented convention, then the register. Inline this rule in a public skill rather than linking it.

### Documentation artifact naming
When a skill creates a durable Markdown artifact under `docs/`, follow the host collection's convention when it has one. Otherwise use `<type>-<slug>-YYYY-MM-DD.md`: a lowercase type prefix, a short lowercase kebab-case subject slug, and the artifact's ISO creation date at the end (for example, `docs/plans/plan-sso-login-2026-07-23.md`). Keep that creation date stable when the file is edited. Update the same artifact in place; for a genuine same-day collision, make the slug more specific and only then insert a sequence immediately before the date (`research-auth-providers-02-2026-07-23.md`). ADRs retain their sequence as `docs/adr/adr-NNNN-<slug>-YYYY-MM-DD.md`. Multi-file artifacts put the convention on their bundle directory, such as `docs/verify/verify-<slug>-YYYY-MM-DD/`, while structural child names remain fixed. Inline the applicable rule in every public skill that creates such an artifact so the installed skill remains self-contained.

### Cross-referencing steps
**Never reference a step by its number** (a bare "see step N" citation). A bare number binds to a step's *position*, so inserting or reordering steps silently makes it point at the wrong one. Reference the step's *identity* instead: for a step with a heading, link to it by name with a GitHub anchor (`[Gather intent](#1-gather-intent)`, since GitHub builds the anchor from the full heading text by lowercasing it, dropping punctuation, and turning spaces into hyphens); for a list item with no heading, name the action in prose rather than citing its ordinal.

### Closing hand-off
**Every skill ends by reporting what it did and naming what comes next**, in a closing section titled `## Hand off` (or `### N. Hand off` inside a numbered procedure; a mode-per-section skill gets one per mode). A skill that goes quiet at the end leaves the user to reconstruct what changed on disk and what the next move is, which is exactly the work skills exist to remove. Three beats, in order. **What changed**: the mutations, concretely, including the ones that didn't happen. **Where it landed**: paths, branches, URLs, so nothing has to be hunted for. **Next**: the single best move, crowned, not a menu of equals. Route, don't launch: name the follow-up and its one-line invocation without invoking it, name a sibling skill only when it's installed, and always give the plain fallback ("open a PR with a PR skill, otherwise `gh pr create`"). A terminal skill says plainly there is no next step rather than inventing one; a read-only skill may drop a genuinely empty beat, never pad it.

## Quality bar

Apply these while drafting; they are the difference between a skill that triggers and reads well and one that doesn't:

- **Front-load the leading word.** A leading word is the compact term that names what the skill does, and the first words of `name` and `description` do the invocation work, so put it there. It works twice over when it's a word the model already knows (`commit`, `review`, `slop`, `ledger`): a pretrained word anchors a region of behavior for free, where a coined one charges you definition tokens for the same anchor. Repeat it as a *token* through the body; never restate it as a sentence.
- **"Use when" trigger.** The `description` starts with what it does, then a plain-English "Use when …" clause, phrased slightly pushy to fight undertriggering (name the phrasings/commands that should fire it). A description is a **context pointer**, and it loads on every turn whether or not the skill fires, so spend it on **one trigger per branch, not per synonym**: cover every mode, and collapse the phrasings that rename a single one. Cut identity the body already carries, because a pointer says what the material is and when to reach it, never the skill's rules or scope disclaimers. Prune synonyms, never coverage; a branch with no trigger silently never fires.
- **Skills are for what the model can't already do.** A skill only fires for tasks the base model can't handle directly. If the guidance is obvious, it won't trigger no matter how you word it.
- **Stay lean; disclose by branch.** Prefer one `SKILL.md`, and apply [Information hierarchy](#information-hierarchy): inline what every branch needs, push into a satellite file inside the skill's own directory what only some branches reach, and co-locate each concept under one heading. Watch for sprawl, which a trim pass can't fix.
- **Every step ends on a completion criterion**, per [Completion criteria](#completion-criteria). Write the bound so the agent can tell done from not-done, and prefer the exhaustive form ("every X accounted for") to the productive one ("produce a list of X"). A step that ends on a feeling is where run-to-run variance comes from.
- **Intent over incantation.** A skill says *what to accomplish and why*, and lets the agent work out the exact invocation. Pin an exact command **only** when it's a stable public contract (`git commit`, `gh pr create`, `grep`, `jq`) where re-deriving it every run just burns tokens and invites variance, and even then, make it self-correcting ("run `gh pr create …`; if a flag is rejected, check `gh pr create --help`"). Never hardcode a volatile or vendor tool's syntax, and never encode a tool's *internal* behavior as if it were contract (output-format parsing, help-text scraping, default-shape assumptions), because that's the brittle stuff that breaks on a tool update; describe the goal and let the agent read the docs. The failure mode to avoid on both ends: pinning brittle syntax that breaks loudly, or over-abstracting a frozen command into "figure it out" that taxes every run quietly.
- **One meaning, one place.** No duplication. For internal skills, point to the host repo's conventions doc instead of restating it; for public skills, inline what they need (see Portability). The **environment** is a source of truth too (`package.json` scripts, a `Makefile`, a config file, `--help` output), so a skill that restates one is a cache, and a cache earns its load only when the lookup is expensive. Cache the unwritten convention and the reason behind a choice; leave the one-command lookups where they cannot go stale.
- **Prompt the positive.** Steering by prohibition drags the forbidden behavior into context and makes it *more* available, not less. State the target behavior instead ("write one-line comments" beats "don't write long comments"). A prohibition earns its place only as a hard guardrail you cannot phrase positively, and even then it gets a positive target beside it.
- **Prune no-ops.** A no-op is an instruction the model already obeys by default, paying load to say nothing. The test is model-relative rather than reader-relative: two people disagreeing about a no-op disagree about the *default*, so settle it by running the skill during [Live test](#7-live-test), not by arguing. Delete the whole sentence rather than trimming its words. Explain the *why* behind a rule when it isn't obvious.
- **No hard-wrapping**, per [Prose formatting](#prose-formatting).
- **Classify the output's register**, per [Prose register](#prose-register). Text the skill writes back to its operator is procedural and follows STE; text a reader weighs an opinion against is explanatory; content produced for a third-party audience is out of scope and keeps its own standards. Getting this wrong flattens a verdict or bloats a runbook.
- **Close with a hand-off.** End on a `Hand off` section per [Closing hand-off](#closing-hand-off): what changed, where it landed, one crowned next move, written in the procedural register.
- **Durable docs artifacts.** When the skill writes Markdown under `docs/`, apply [Documentation artifact naming](#documentation-artifact-naming) and inline the applicable convention in a public skill.
- **kit naming + frontmatter.** Obey the naming rules in [Propose names](#4-propose-names) and the [Frontmatter template](#frontmatter-template) exactly; `name` must match the directory; declare `metadata.internal`.

## Portability (public skills only)

A public skill is installed on its own into arbitrary environments. Only its own directory travels, so it must stand alone:

- **Self-contained.** Inline the conventions it relies on. No repo-relative links (`../…`), and no hard dependency on the host repo's Makefile, conventions doc, or helper tooling. If it needs a helper script, bundle it inside the skill's own directory.
- **Machine/OS-agnostic.** No absolute paths, no platform-specific assumptions; prefer instructions that work on any shell or none.
- **Environment-degrading output.** When a filesystem and shell are available, write/edit files directly; when they aren't (e.g. a browser-based agent), print the finished artifact as a codeblock for the user to save, and skip repo-only steps like dev-linking and linting.

Internal skills are exempt, because they live and die in their repo and may use its machinery freely.

## Notes

- skillkit itself is **public** (`metadata.internal: false`). Inside its home collection it can lean on the repo's link/lint tooling, but everything it needs to author a skill is inlined here, so it works standalone wherever it's installed.
- Add scripts or satellite files to a *new* skill only when it genuinely needs one, never speculatively. Per-skill scripts live in the skill's own directory, not in any repo-root location.
