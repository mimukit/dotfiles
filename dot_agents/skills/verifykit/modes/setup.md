## Mode `setup`: ready one machine and one repo

`setup` prepares the capture backend on this machine and the publish path in this repo. **Every item checks first and installs only on a miss.** A machine with every item present gets the report and no prompt. `setup` never touches the project's own code, data, or dependencies.

### 1. Check the machine half

Run each check and record its state as present or missing. Do not install anything yet.

| Item | Check | Install on miss |
|------|-------|-----------------|
| Node 18 or newer | `node --version` | Print the Node download URL and stop the machine half; `setup` does not manage Node |
| `playwright-cli` on `PATH` | `command -v playwright-cli` | `npm install -g @playwright/cli@latest` |
| Driver workspace | `playwright-cli --version` succeeds | `playwright-cli install` |
| A browser | System Chrome, else a driver-installed browser | `playwright-cli install-browser` |

The npm package is `@playwright/cli`. The unscoped `playwright-cli` package is deprecated; never install it. Install globally, because the capture modes probe `PATH` with `command -v`, and a project-local install is invisible to that probe.

### 2. Confirm and install the misses

When at least one item is missing, list every miss and its install command in **one** `AskUserQuestion`, and run the installs only on a yes. A global npm install and a browser download change the machine, and this skill runs on machines that are not the author's. On a no, report the misses as skipped and continue to the repo half.

Then ask once whether to install the driver's bundled agent skills with `playwright-cli install --skills -g`. Recommend no, and give the reason: a second skill on the same browser verbs double-triggers with verifykit. Record the answer in the report.

### 3. Prove the machine half

Take one screenshot of `about:blank` into the system temporary directory (`mktemp -d` on POSIX, `%TEMP%` on Windows) with the driver. The checklist proves each binary exists; only this screenshot proves the browser launches. Record the absolute path. When the screenshot fails, report the machine half as failed with the driver's error and continue to the repo half.

### 4. Check the repo half

Run each check and record its state. Skip this half when the current directory is not a git repository, and say so.

| Item | Check | On miss |
|------|-------|---------|
| `gh` authenticated | `gh auth status` | Report skipped, point to `gh auth login` |
| Origin is public | `bash <path-to-this-skill>/verify-assets.sh check` | Report skipped with the reason: `proof` will skip publish and carry local paths. Never offer to change visibility |
| `docs/verify/` ignored | `git check-ignore -q docs/verify/x` | Append `docs/verify/` to `.gitignore` |
| Push access to `refs/verify-assets/*` | `git push --dry-run origin HEAD:refs/verify-assets/setup-probe` | Report skipped with the push error |

The dry run leaves no ref behind on the remote or locally. The `.gitignore` line is the one repo mutation `setup` makes, and the capture modes need it before their first `proof` run.

### 5. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Print the checklist: one line per item, each marked present, installed, or skipped, with the reason on every skipped line. Name the bundled-skills answer. Name the `.gitignore` edit when it happened.

**Where it landed.** Print the absolute path of the `about:blank` screenshot. Print the path of the edited `.gitignore` when it changed.

**Next.** Run verifykit `show` on the change in hand. When a machine item stays skipped, the capture modes degrade to the manual recipe until it is installed; say so.
