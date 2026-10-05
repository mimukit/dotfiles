## Mode: `update`

For a change that just landed. Resolve the target the same way a review does: **uncommitted working-tree changes first** (`git status --porcelain` non-empty → `git diff HEAD`, plus the untracked files `git diff` never shows), otherwise the **branch diff** against the base ref, from **gitkit** when it's installed, else the repo's default branch via `gh repo view --json defaultBranchRef`. Never assume `main`. Say which target you chose in one line.

### 1. Read the diff, not the whole repo

The diff is the input. Reading the repo instead is how a one-flag change turns into a six-page rewrite. The step is done when every changed path in the diff is listed.

### 2. Map changed code to affected pages

Through the manifest's `documents:` globs. **State which pages are affected and which are deliberately untouched, before editing rather than in the report afterward.** The untouched list is the load-bearing half; it's what tells the user the skill knew what it was leaving alone. The step is done when every changed path maps to a page or to "no page documents this".

### 3. Edit the affected pages, surgically and directly

A changed flag edits the flag. It does not regenerate the page. These edits need no gate: they are bounded by the restraint rule and land in a reviewable diff. An adopted (unstamped) page is edited **only for a claim the diff actually broke**, never restyled, never expanded. The step is done when every affected page has each broken claim fixed or reported as unverified.

**The discipline here is restraint.** A skill that rewrites six pages because one function moved is worse than no skill, because now the PR diff is unreviewable.

### 4. Flag the documentation-shaped gaps the diff created

A new command with no how-to, a new env var absent from getting-started, a new failure mode with no runbook. **New pages and deletions are consent-gated**, so propose, then write. That split is the whole write-mode policy: edits go straight in, creation and destruction ask. The step is done when every gap has a proposal and a verdict from the user.

### 5. Re-stamp and reconcile

Re-stamp a page only when this pass verified every claim on it, per [The provenance stamp](../SKILL.md#the-provenance-stamp). A page where you checked only the claims the diff moved keeps its old stamp, so `audit` still sees it as due. An adopted page never gets a stamp in `update`, because `update` edits only the claim the diff broke and never verifies the rest. On a feature branch, stamp nothing and list the fully verified pages as due a stamp after merge.

Update the manifest for every page created or removed. The step is done when each touched page is in one of three lists (re-stamped, kept its old stamp, due a stamp after merge) and every created or removed page has its manifest change.

### 6. Hand off

**What changed.** Report pages edited (one line each, naming the claim that moved), pages proposed and their verdict, and pages deliberately untouched. Give the three stamp lists from the re-stamp step.

**Where it landed.** Give the paths, and the manifest if it moved.

**Next.** Run **commitkit**, then **prkit** (otherwise `git commit` and `gh pr create`). Docs land in the same PR as the code that changed them; that's the whole point of in-repo docs.
