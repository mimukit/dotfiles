## Mode `show`: put the screen in front of the operator

The operator is present, so the output is an image path they can open now. Nothing is recorded for a later reader: no GIF, no bundle, no `notes.md`, no publish, no `.gitignore` edit. Screenshots go to the system temporary directory, so the repo stays untouched.

### 1. Resolve the output directory

Take the first that resolves:

1. the system temporary directory: `mktemp -d` on POSIX, `%TEMP%` on Windows;
2. otherwise `docs/verify/` inside the repo. This writes files into the working tree. Check `git check-ignore -q docs/verify/x`: when the path is not ignored, the screenshots appear as untracked files, and the hand-off must say so.

Inside it, create one run directory named `show-<slug>-YYYY-MM-DD/` (the slug from the shared procedure, today's ISO date). Under `docs/verify/`, prefix it with the next serial, `NNNN-show-<slug>-YYYY-MM-DD/`: list `docs/verify/`, take the highest leading four-digit serial, and add one, starting at `0001`. Keep the name stable when re-running the same slug on the same day; later captures overwrite by file name. This step is done when the run directory exists and you know whether it sits in the repo.

### 2. Drive and screenshot

Walk each selected flow along its primary happy path as a user would. Write a **screenshot at every meaningful state** the change touches (initial, mid-flow, the error or empty state the change introduces, success) as `NN-<state>.png`, numbered from `01` in capture order, with a short kebab-case state name (`01-initial.png`, `02-validation-error.png`). Stop when every selected flow has a screenshot for each of its meaningful states.

### 3. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Say "nothing in the repo" when the screenshots went to the temporary directory. When they went to `docs/verify/`, say that the run wrote screenshots into the working tree, and say whether git ignores them or shows them as untracked. Name the capture backend used and any auth or action boundary the run stopped at.

**Where it landed.** Print one line per screenshot: the absolute path, then the state it shows. Print every path, so the operator opens each one without a search.

**Next.** Return to the kit that was building the change, or to the user's next edit. When the operator wants the change proven for a PR, name verifykit `proof` on the same slug as the runner-up. Do not run it.
