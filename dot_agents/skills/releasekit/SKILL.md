---
name: releasekit
description: >-
  Cut a release from the Conventional Commits a repo already writes: derive the semver bump and a changelog from the commit range, bump the manifest, tag it, and publish a GitHub release, all behind a mandatory preview. Use when the user says "cut a release", "tag a version", "release this", "what's the next version", "generate a changelog", "ship v2", or "/releasekit". It never publishes to a package registry and never moves a published tag.
license: MIT
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion, Skill
metadata:
  internal: false
---

# releasekit

A repo that writes [Conventional Commits](https://www.conventionalcommits.org) has already answered the two questions a release asks: what changed, and how much did it break. releasekit reads that answer back out. It resolves the commit range since the last release, derives the next semver version and a [Keep a Changelog](https://keepachangelog.com) section from the commits in it, and cuts the release: a `CHANGELOG.md` entry, a version bump in the ecosystem's manifest, an annotated tag, and a GitHub release.

Everything it does is previewed before anything mutates, because a version number is spent permanently. A tag that ships broken code cannot be reused, only superseded.

**releasekit stops at the tag.** It does not run `npm publish`, `twine upload`, or `cargo publish`. The tag it creates is precisely the trigger a publish workflow already listens for, and credentials plus irreversibility are two good reasons to leave that where it is.

## When this fires

The user wants to turn merged work into a released version: "cut a release", "release this", "tag a version", "what would the next version be", "generate the changelog", "ship v2", "/releasekit".

Three boundaries matter:

- **It does not write the commits it reads.** Authoring Conventional Commits belongs to the commit step; releasekit only ever parses what is already in the log.
- **It is not a publisher.** The registry upload is CI's job, triggered by the tag.
- **It is interactive only.** The confirmation below is a real gate with no exemption, so releasekit never runs inside an unattended pipeline. A run with nobody to answer stops at the preview rather than assuming a yes.

## Procedure

### 1. Preflight

Every check runs before anything mutates, and each failure names itself rather than falling through to a later one.

**Environment.** Confirm git, a remote, and a usable `gh`. Without `gh`, releasekit still writes the changelog and cuts the tag, so say once that the GitHub release and the CI check are both skipped, and why. Do not fail wholesale for a missing enrichment.

**Base ref.** Never assume `main`; repos default to `develop`, `trunk`, and `master` in the wild. When `gitkit` is installed, ask it, because it owns this answer. Otherwise resolve it directly:

```sh
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name
```

falling back to `git symbolic-ref --short refs/remotes/origin/HEAD`, and asking the user rather than guessing past that.

**Repo state.** Refuse, and say which one failed, when:

- the working tree is dirty, because a release must describe committed code;
- HEAD is not the base ref, because releasing a feature branch tags code nobody merged;
- the branch is behind its upstream, because the changelog would omit commits that are already public.

**Competing release tooling.** Look for `.changeset/`, `.releaserc*`, `release-please-config.json`, or a `semantic-release` dependency. Any of them owns versioning end to end, and a second writer corrupts its state. **Stop before mutating anything**, name the tool, and name its command instead. This is a refusal, not a warning.

**Workspaces.** Look for `workspaces` in `package.json`, a `pnpm-workspace.yaml`, or `[workspace]` in `Cargo.toml`. A marker alone is not a monorepo, because plenty of repos have a `packages/` directory and one published artifact. **Refuse only when a marker is present and more than one manifest carries a version**, and list every versioned manifest you found. A workspace where only the root is versioned has one version and releases normally.

**Branch protection.** Probe the base branch once:

```sh
gh api "repos/{owner}/{repo}/branches/$BASE/protection"
```

A 404 means unprotected and selects [the direct path](#the-direct-path). Any other answer means protected and selects [the release-PR path](#the-release-pr-path). Getting this wrong is not cosmetic: the direct path pushes a commit straight to the base, and a protected repo rejects it after the changelog has already been written.

**Phase.** On the release-PR path only, work out which half of the release this is **from the repo, never from state you keep**. A merged `chore(release): vX.Y.Z` commit on the base with no tag pointing at it means *finish*. Anything else means *prepare*.

### 2. Derive the version

**Resolve the last release.** Take the **nearest semver ancestor of HEAD**, not the highest version in the repo:

```sh
git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*'
```

Filtering to the semver shape stops a `nightly-2026-08-01` tag being mistaken for a release, and taking an ancestor rather than a maximum is what lets a repo running `v1.x` alongside `v2.x` read its own lineage. **Skip prereleases**, so a `v1.3.0-rc.1` tag is passed over and the commits it shipped still appear in the `v1.3.0` changelog. Cut them at the resolver, so nothing downstream has to know prereleases exist.

**Read the range** `<lasttag>..HEAD`, or the whole history when no tag exists. Parse each commit's **subject and body**, because a `BREAKING CHANGE:` footer lives in the body, so bodies cannot be skipped.

**Bump from what the range contains**, taking the highest that applies:

| in the range | bump on `1.x` and above | bump on `0.x` |
|---|---|---|
| a `!` marker or a `BREAKING CHANGE:` footer | major | **minor** |
| any `feat` | minor | **patch** |
| any `fix` or `perf` | patch | patch |
| only `docs`, `chore`, `style`, `test`, `build`, `ci`, `refactor` | none | none |

**The `0.x` column is not a typo, and it is the rule most likely to surprise someone.** Bumping major on a pre-1.0 repo takes `0.3.0` to `1.0.0`, which declares the API stable off the back of a single commit footer. This follows the release-please and Cargo convention instead. State the rule and its arithmetic in words in the preview, not just the resulting number.

**A first release asks.** With no tag in the repo, prompt once with `0.1.0` prefilled. This happens exactly once per repo and cannot be corrected afterwards, and `1.0.0` is a public declaration of API stability that must never be guessed on the user's behalf. **Skip the prompt when a manifest already carries a version**, because that version is the user's answer.

**The tag prefix is inherited, not chosen.** `v1.2.0` gives `v`, `1.2.0` gives none. Default to `v` on a first release.

**Two refusals come out of this step**, both with a named override so the refusal is discoverable rather than a dead end:

- **Nothing user-visible.** The range holds no commit that forces a bump. Say so concretely ("nothing user-visible since v1.2.0") and name `--allow-empty` for a user who has a reason. A patch bump for every CI tweak makes the version meaningless; a prompt every time trains people to dismiss it.
- **Nothing parses.** No commit in the range is a Conventional Commit, so any bump would be a guess. Refuse the same way.

**Commits that do not parse otherwise proceed.** Collect them for an **Other** section and count them in the preview. Squash-merge repos build subjects from PR titles, and any repo predating the convention has a mixed log, so refusing until every commit parses would make releasekit unusable on both. Nothing is silently dropped; the floor above is what stops the bump becoming fiction.

### 3. Render the changelog

Group the parsed commits into Keep a Changelog sections: **Added**, **Changed**, **Fixed**, **Removed**, plus **Other** for the unparsed.

- **Breaking changes come first, always in their own section**, carrying the migration note from the footer. A reader scanning a release wants the thing that will break them above the thing that delights them.
- **Keep the scope, drop the type.** Under an **Added** heading, `auth: add token refresh retry` reads better than `feat(auth): add token refresh retry`, because the heading already said `feat`.
- **Link each entry to its commit**, and to its PR when the merge commit names one.
- **Render exactly once.** The `CHANGELOG.md` section and the GitHub release body are the same string. Two renders are two texts that can disagree, and the disagreement always surfaces after the release is public.

### 4. Preview and confirm

The preview is mandatory and always renders. `releasekit preview` ends here having mutated nothing; a bare `releasekit` waits for a confirmation here and mutates nothing until it gets one.

Lead with the path, then the facts:

- **first line.** The path (direct or release-PR) and, on the release-PR path, the phase. A misdetected phase is the one failure that costs a duplicate release, so it has to be visible before it is actionable.
- the computed version, and the rule that produced it stated in words;
- the rendered changelog in full;
- the manifest file and its old → new version, or that no manifest was found;
- the tag name;
- the CI check rollup result on the base's head;
- the count of unparsed commits;
- every command about to run.

### 5. Cut the release

**Verify CI first, on either path.** Read the check rollup for the base's head commit and **refuse to tag a failing one**, because a tag on red code spends a version number on something nobody can use. `--allow-red` overrides it for a known-flaky required check. When `gh` is unusable there is no rollup, so **say the check was skipped**; never let a missing signal read as green.

#### The direct path

Unprotected base. In this order, because each step depends on the last landing:

1. Bump the detected manifest (`package.json`, `Cargo.toml`, `pyproject.toml`, a gemspec). No manifest found is fine and is not an error.
2. Prepend the rendered section to `CHANGELOG.md`, creating the file with a header when it does not exist.
3. Commit both together as `chore(release): v<version>`. One commit, because the bump and the changelog describe the same event.
4. Create an annotated tag whose message is the release title.
5. Push the commit and the tag.
6. Create the GitHub release with `gh release create`, using the rendered body.

#### The release-PR path

Protected base. Two invocations, and the phase resolved in [Preflight](#1-preflight) decides which one runs.

**Prepare.** Do the manifest bump, the changelog, and the commit on a `release-v<version>` branch. Push it and open a PR whose body is the rendered changelog. **Stop there.** The user reviews and merges it.

**Finish.** The merged, untagged `chore(release):` commit is the trigger. Verify the rollup, tag that commit, push the tag, and create the GitHub release. The changelog is already in the repo from the merge, so nothing is rewritten and nothing is committed.

**If any step on either path fails, stop at that step** and report exactly what landed and what did not. Never roll back a pushed tag; see the refusals in [Notes](#notes).

### 6. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

The hand-off differs by path, so report the one that ran.

**Direct path, and release-PR finish.** This is terminal.

- *What changed.* The version, the files bumped, and the commit created.
- *Where it landed.* The tag name, the release URL, and the branch pushed.
- *Next.* There is no next kit. Say that pushing the tag may have started a publish workflow, and that releasekit does not own or watch it. Name `gh release edit` for a typo in the notes.

**Release-PR path, prepare.** This is not terminal.

- *What changed.* The release branch, the commit on it, and the PR opened. Say plainly that no tag exists yet.
- *Where it landed.* The branch name and the PR URL.
- *Next.* Review and merge the PR. Use **mergekit** when it is installed, otherwise `gh pr merge`. Then run releasekit again to tag the merged commit.

## Notes

- **Four refusals, and each one is a refusal rather than a caution.** releasekit stands down when another release tool owns the repo. It refuses a workspace with several versioned packages. It refuses to tag a red base. It never moves or deletes a published tag, because re-tagging breaks every consumer that already resolved it. A bad release is fixed by cutting the next one.
- **Fixing a released typo is out of scope.** The notes on a published release are editable by nature, but adding an edit path would make a third entry point out of a skill with one procedure and two exits. Run `gh release edit` instead.
- **Prereleases are read, never written.** releasekit passes over an existing `-rc.N` tag so a repo already using them can still cut a stable release. It does not create one.
- **One version per repo.** Per-package versioning in a monorepo is a different skill with a different data model, and guessing at it silently is worse than refusing.
- **It never runs unattended.** The confirmation in [Preview and confirm](#4-preview-and-confirm) is a consent gate with no exemption. An orchestrator that reaches it with nobody to answer must stop and escalate, not proceed.
- **Follow the repo over these defaults.** A repo with its own changelog format, a `CHANGELOG` at a different path, or a documented release procedure gets that, and say you followed it.
- **`Skill` is declared for one call only**, which is asking `gitkit` for the base ref. releasekit invokes no other skill; naming mergekit in the hand-off is routing, not launching.
- No filesystem or shell (a browser-based agent, say)? Then you cannot read the log or cut anything. Instead print the derived version, the rendered changelog as a codeblock, and the exact `git tag` and `gh release create` commands for the user to run.
