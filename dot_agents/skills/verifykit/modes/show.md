## Mode `show`: put the screen in front of the operator

The operator is present, so the output is an image path they can open now. Nothing is recorded for a later reader: no GIF, no bundle, no `notes.md`, no publish, no `.gitignore` edit.

### 1. Resolve the output directory

Take the first that resolves:

1. the system temporary directory: `mktemp -d` on POSIX, `%TEMP%` on Windows;
2. otherwise `docs/verify/show-<slug>-YYYY-MM-DD/` inside the repo, which sits under the `docs/verify/` line that `proof` mode adds to `.gitignore`.

Inside it, create one run directory named `show-<slug>-YYYY-MM-DD/` (the slug from the shared procedure, today's ISO date). Keep the date stable when re-running the same slug on the same day; later captures overwrite by file name.

### 2. Drive and screenshot

Walk each selected flow along its primary happy path as a user would. Write a **screenshot at every meaningful state** the change touches (initial, mid-flow, the error or empty state the change introduces, success) as `NN-<state>.png`, numbered from `01` in capture order, with a short kebab-case state name (`01-initial.png`, `02-validation-error.png`). Stop when every selected flow has a screenshot for each of its meaningful states.

### 3. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Nothing in the repo. Say so, and name the capture backend used and any auth boundary the run stopped at.

**Where it landed.** Print one line per screenshot: the absolute path, then the state it shows. Print every path, so the operator opens each one without a search.

**Next.** Return to the kit that was building the change, or to the user's next edit. When the operator wants the change proven for a PR, name verifykit `proof` on the same slug as the runner-up. Do not run it.
