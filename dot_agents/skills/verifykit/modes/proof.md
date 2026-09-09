## Mode `proof`: capture and publish evidence for the PR

A PR reader is not present, so the output is a bundle with a GIF and a ready-to-embed `proof.md`, published to a hidden git ref. Form the bundle name as `verify-<slug>-YYYY-MM-DD`, using the run's ISO creation date at the end. Everything for the run is grouped under it.

### 1. Drive and capture

Walk each selected flow along its primary happy path as a user would. Capture a **screenshot at every meaningful state** (initial, mid-flow, error/empty states the change introduces, success), and a **short animated GIF** of the whole flow. Keep the GIF proof-grade, not cinema: a few frames per second, modest width, a short clip. When stitching frames into a GIF, `ffmpeg` works well if present:

```sh
ffmpeg -y -framerate 2 -i frame-%02d.png -vf "scale=800:-1" flow.gif
```

Cap the frame rate and width so the GIF stays small (a proof GIF is typically a few hundred KB; screenshots ~100 KB).

### 2. Write the bundle

Save the captures to `docs/verify/verify-<slug>-YYYY-MM-DD/` (for example, `docs/verify/verify-login-throttle-2026-07-23/`): the screenshots, the GIF, and a fixed `notes.md` recording the flows driven, the capture backend used, per-step pass/fail, the environment, and any auth boundary the run stopped at. Keep the creation date stable when updating the same bundle. For a genuine same-day collision between distinct runs, make the slug more specific; only as a last resort insert a sequence immediately before the date (`verify-login-throttle-02-2026-07-23`). This directory is **ephemeral**, because the assets get published to a hidden git ref (below) rather than committed to the branch, so add `docs/verify/` to `.gitignore`.

### 3. Publish so a PR can embed the proof

GitHub can't inline media from `gh`, and committing proof GIFs to the branch bloats the repo's history for every clone forever. Instead, publish to a **hidden git ref** (`refs/verify-assets/<slug>`). The assets live in the repo but a normal `git clone` never fetches that namespace, so there's zero clone bloat, and they render inline in a PR body via SHA-pinned `raw.githubusercontent.com` URLs. This needs a **public** repo (GitHub's image proxy can't authenticate into a private one).

The fragile git plumbing lives in the bundled [`verify-assets.sh`](../verify-assets.sh) in the skill's root directory. Resolve the installed skill directory and call the script there; the current working directory is the target project, not the skill directory. Don't hand-run the plumbing:

```sh
VERIFY_ASSETS="<path-to-this-skill>/verify-assets.sh"

if bash "$VERIFY_ASSETS" check; then
  # publish the bundle; prints the commit SHA to embed
  SHA=$(bash "$VERIFY_ASSETS" publish <slug> docs/verify/verify-<slug>-YYYY-MM-DD/*)

  # resolve the inline-rendering URL for each file
  bash "$VERIFY_ASSETS" url <slug> "$SHA" flow.gif
else
  # private repo: skip publishing and write proof.md with local paths
  echo "private repo: link the local bundle in proof.md for manual attachment"
fi
```

The script also offers `list` (show all `refs/verify-assets/*`) and `delete <slug>` (remove a ref after its PR merges). Old refs accumulate on the remote but never in anyone's clone, so prune them with `delete` once a PR merges.

Then write the ready-to-embed proof into the bundle's fixed **`proof.md`** (`docs/verify/verify-<slug>-YYYY-MM-DD/proof.md`), a Markdown fragment embedding the GIF and screenshots by their SHA-pinned raw URLs, captioned per flow. This file is the hand-off contract: the PR step reads it and splices it straight into the pull request body, so it never re-runs the publish. On a private repo (publish skipped), write `proof.md` with the local file paths and a note that they need manual attachment, so the PR step can still surface them.

### 4. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Report the flows verified with pass/fail, the capture backend used, the `.gitignore` line added or already present, and, when published, the commit SHA and the ready-to-embed raw URLs. On a private repo, say that publish was skipped.

**Where it landed.** Print the bundle path. Print one line per screenshot and for the GIF: the absolute path, then the state or flow it shows.

**Next.** Open the PR with **prkit** when installed, otherwise `gh pr create`. The artifacts are ready for a pull request's **Proof** section. Do not open the PR from here.
