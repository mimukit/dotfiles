## Mode: `publish`

**Opt-in, explicit-ask-only.** Mirrors the doc set out to the repo's GitHub Wiki tab by installing a workflow that syncs on every push to the doc home. wikikit writes the workflow file; **GitHub Actions does the syncing**, so nothing here pushes to a wiki from your machine.

The in-repo set stays the source of truth. The wiki is a **derived, disposable mirror**: delete it and re-sync and you lose nothing, because nothing originates there.

### What you are agreeing to

Three properties of GitHub wikis make this sharper than it looks. Say all three out loud before writing anything, because a user who learns them from the aftermath will not thank you.

1. **The sync is destructive and one-way.** The action clears the wiki repo, copies the doc set in, and **force-pushes**. Any page created or edited in the wiki's web UI is **deleted on the next sync**, including on private repos, and including pages nobody in the doc set has ever heard of. The wiki becomes read-only in practice; the edit button stays there and lies. (This is true under both of the action's strategies, notwithstanding its own documentation, which describes force-push as `init`-only.)
2. **The page namespace is flat.** Wiki source files may sit in folders, but page URLs are built from the title alone, so `how-to/deploy.md` and `runbooks/deploy.md` both resolve to `/wiki/deploy` and one silently wins. The template below flattens path segments into the page name to make collisions impossible; the [collision scan](#2-scan-for-page-name-collisions) catches the residue before anything is installed.
3. **The wiki must be created by hand, once.** A repo's wiki has no git backend until a first page exists, and there is no API or `gh` command that creates one. The workflow will fail until a human clicks through the UI.

Editing permissions are **not** on this list. GitHub restricts public-repo wiki editing to collaborators by default, so the "strangers overwrite each other" hazard is gone, but note that property 1 makes collaborator edits just as doomed.

### 1. Preflight

Establish that publishing is even possible, and say which of these failed rather than installing a workflow that will go red on its first run:

```sh
gh repo view --json nameWithOwner,visibility,hasWikiEnabled
git ls-remote "$(gh repo view --json url -q .url).wiki.git" 2>&1 | head -1
```

| State | Do this |
|---|---|
| **Wiki feature disabled** | Stop. It's a repo setting (Settings → Features → Wikis); name the path and let the user flip it. |
| **Wiki enabled but never initialized**, where `ls-remote` errors or returns nothing | Stop before writing the workflow. Tell the user to open the wiki tab and save any page (the action's own docs call this the "dummy page"), then re-run. Do not install a workflow that is guaranteed to fail. |
| **Wiki already has pages wikikit didn't write** | **This is the dangerous case.** Those pages will be destroyed by the first sync. Offer the rescue below before anything else, and get an explicit yes on the destruction. |
| **No `gh`, or unauthenticated** | Print the workflow for the user to add by hand, and name the preflight checks they should run themselves. Never claim a wiki state you couldn't read. |

**The rescue for existing wiki content** pulls it into the repo first, so the mirror doesn't eat it:

```sh
git clone "$(gh repo view --json url -q .url).wiki.git" /tmp/wiki-rescue
```

Anything worth keeping becomes a page in the doc set (mapped in the manifest as `adopted: true`, no stamp, because a human wrote it). Anything not worth keeping is confirmed as deliberate loss. Only then continue.

### 2. Scan for page-name collisions

Flatten every page path in the doc set to its wiki page name, where path separators become `-` and `index.md` becomes `Home`, and check for duplicates **before** installing anything:

```
docs/wiki/index.md                    → Home
docs/wiki/getting-started.md          → getting-started
docs/wiki/how-to/deploy-to-staging.md → how-to-deploy-to-staging
docs/wiki/runbooks/rollback.md        → runbooks-rollback
```

Flattening makes a collision nearly impossible, since the source paths are already unique, but it isn't a proof (`how-to/deploy.md` and `how/to-deploy.md` both flatten to `how-to-deploy`). **Report any collision and stop.** Renaming a source page is the fix, and that's the user's call, not a silent tiebreak.

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
- **`concurrency`** without `cancel-in-progress`, because two force-pushes racing on one wiki repo is how a sync lands half-applied.
- **`permissions: contents: write`**, and nothing else. The built-in `GITHUB_TOKEN` is enough; a wiki sync never needs a PAT, and being asked for one is a signal something is wrong.

Pinning `@v5` follows the action's documented usage. For a repo that pins actions to commit SHAs, match that convention instead and say you did.

### 4. Hand off

**What changed.** Report the workflow written (or the preflight gate that stopped you), whether existing wiki pages were rescued or knowingly abandoned, and any collisions found.

**Where it landed.** Give the workflow path, the doc home it syncs, the branch that triggers it, and, stated plainly, that it is in **dry-run**, so nothing has been published yet.

**Next.** Push the workflow and run it once from the Actions tab (`workflow_dispatch`) to read the dry-run output. If it looks right, flip `dry-run` to `false`; that's the commit that makes the wiki live. Commit with **commitkit** when installed, otherwise `git add` and commit. If the preflight stopped you, the crowned move is the thing that unblocks it, meaning creating the first wiki page by hand, or enabling the wiki feature.
