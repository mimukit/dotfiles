---
name: testkit
description: >-
  Retrofit an automated test suite onto a working codebase that has none: rank the untested surface, crown a slice, stand up a runner, and write tests that were each watched to fail before they were kept. Use when the user says "write tests for this", "this project has no tests", "add test coverage", "retrofit tests onto this repo", "set up testing here", "what should I test first", "our test coverage is terrible", or "/testkit". It never fixes the bugs it finds and never restructures code to make it testable.
license: MIT
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, AskUserQuestion
metadata:
  internal: false
---

# testkit

The suite you build for code that already works. testkit reads a codebase with no tests, or a handful of stale ones, ranks what is worth covering, crowns one slice, and writes tests that have each been **observed to fail** before they were kept.

Two modes. `audit` ranks the untested surface and writes nothing but a ledger. `cover` writes the tests.

## The failure it exists to prevent

An agent asked to "write tests for this project" reliably produces **coverage theater**: a pile of tests that mirror the implementation line for line, assert that mocks were called, pass on the first run, and pin whatever the code does today, bugs included.

It looks exactly like a real suite. Same layout, same green checkmarks, same coverage number. It is worse than no suite, because it charges maintenance rent forever, detects nothing, and hands you a green checkmark that is now evidence in arguments it cannot support.

Two properties separate a real brownfield test from that pile, and both are **structurally absent** unless you force them:

1. **The test has been watched to fail.** Code written before the test means red-then-green never happens on its own. The failure has to be manufactured deliberately, or it does not happen at all.
2. **The expectation came from outside the implementation.** A test whose expected value was read off the function it tests is a photograph of current behaviour, not a claim about correct behaviour.

Every rule below exists to make those two mandatory rather than aspirational.

## When this fires

"Write tests for this", "this repo has no tests", "add test coverage", "set up testing", "what should I test first", "our coverage is terrible", "/testkit".

Boundaries against the kits that sit closest:

- **Not test-driven development on new work.** A build skill's TDD mode owns red-then-green for code that does not exist yet. testkit's entire premise is that the code is already there and already runs.
- **Not a manual QA plan.** A QA skill writes steps a human executes by hand. Nothing testkit produces is run by a person.
- **Not browser proof for a pull request.** A visual-verification skill drives a browser once and captures images. testkit writes specs that a test command reruns forever.
- **Not diagnosis.** A debugging skill chases one symptom to its cause and may produce one failing test as a reproduction. testkit builds a suite.

## It never fixes, and it never restructures

Two hard boundaries, both of which will feel wrong in the moment:

**Retrofitting tests uncovers bugs. testkit reports them and does not fix them.** When observed behaviour contradicts the external expectation, do not edit the source to match the test, and do not edit the test to match the source. Write the test asserting the **intended** behaviour, mark it skipped or expected-to-fail with a one-line pointer, and report it. A skill that finds a defect and also lands the cure has decided the question before writing the report.

**Some code cannot be tested without restructuring it. testkit does not restructure it.** No extracted interface, no injected dependency, no "small seam while I'm in here." Untestable code becomes a **testability blocker** in the ledger, routed onward. A refactoring skill's *untested coupling* pattern is precisely this finding with a proposal attached.

The only source edits testkit ever makes are the temporary mutations of [The failure gate](#the-failure-gate), and every one is reverted.

## Mode selection

Take the first tier that answers:

1. **The user said a mode**, as in `/testkit audit` or `/testkit cover src/billing`. Explicit always wins.
2. **A ledger exists** → `cover`. **No ledger** → `audit`.

A `cover` request against a repo with no ledger **does not bounce.** Run the ranking inline, crown a slice, say which path the run took, and proceed. Refusing to write a test until a survey document exists is bureaucracy, and it is the kind that gets a skill uninstalled.

An optional scope argument narrows what gets ranked in either mode. It never changes what gets written.

## The ledger

One file per repository: `docs/tests/testplan-<repo>-YYYY-MM-DD.md`, where the date is its **creation** date and stays fixed forever. `audit` creates it. Every run after that updates it in place. A scoped run appends under a scoped heading in the same file, and it never spawns a second one.

One file is what makes run N+1 cheap. A brownfield retrofit does not finish in one session, and a skill that writes a fresh dated survey per slice leaves a pile of surveys and no resumable state at all.

It carries:

- the ranked untested surface, stamped `ranked against <sha> on <date>`;
- what each run covered, with its date and its declared-versus-actual count;
- what was deferred, and why;
- **testability blockers**, meaning code that cannot be tested without restructuring;
- **unproven tests**, meaning pre-existing tests that survived a mutation they should have caught.

Durable and committable. testkit never commits it.

**When the repo already has a home or naming scheme for test-planning documents, that convention wins**, so say that you followed it. No writable filesystem (a browser-based agent) means printing the ledger as a codeblock under its canonical path instead.

## Mode: `audit`

Read-only. It writes the ledger and nothing else: no test file, no source edit.

### 1. Derive the untested surface

Find what source exists, what tests exist, and what those tests actually reach. **Read a coverage report only if one is already on disk. Never generate one, and never install a tool to produce evidence**, because probing for an analysis tool and parsing its output couples the skill to a format that changes on a minor release.

Exclude before ranking, not after: generated code, vendored trees, thin configuration, and pure delegation. They inflate a count and prove nothing.

### 2. Rank

One read of the history gives both signals at once: `git log --format= --name-only --since=<about a year>` yields how often each file changes and which files keep changing *together*.

Rank on four signals:

- **Churn.** How often it changes. Code nobody touches breaks nobody.
- **Fan-in.** How many modules depend on it. A break here is a break everywhere.
- **Failure cost.** Money, authentication, data loss, migrations, anything irreversible.
- **Testability cost.** Divide by this. A behaviour that needs three services standing up costs more than its rank suggests.

**No git history**, meaning a shallow clone or not a repository, means no ranking. Scan by structure instead and say plainly that the prioritisation was skipped, so nobody reads the coverage claim as more than it is.

### 3. Crown one slice

Group the top of the ranking into coherent slices along the co-change clusters, then crown **exactly one**, with runners-up in order. Crown a slice rather than a file: a coherent behaviour rarely lives in one file, and a file is not a unit of meaning.

Crowning one is the work. A list of five equal-looking candidates is the state the user was already in.

### 4. Write the ledger

Every run carries a **coverage line**, in the terminal and in the file: *"ranked 1,240 files, read the top 40 across 3 slices."* A cap nobody can see reads as completeness.

**An audit that finds no meaningful untested surface writes no file and says so.** A survey obliged to produce findings will manufacture them, and manufactured advice about what to test reads exactly like the real thing.

## Mode: `cover`

Writes the tests.

### 1. Take the slice, and check the ranking is still true

Take it from the ledger, from the user, or from an inline ranking when neither exists, and **say which**.

The ledger's ranking is stamped with the commit it was computed against. Compare `HEAD`. **Re-rank when the commits since that sha touched files in the ledger's top slice.** Otherwise trust it *out loud*, naming the sha you trusted. A durable ranking outlives the code it ranked, so an August ordering will happily drive a November run at whatever used to be hot.

### 2. Stand up a runner, if there is none

Skip this when the repo already has one.

- **Inherit the ecosystem's default.** A project with no tests has no opinion to honour, so the choice least likely to be relitigated is whatever the language's own documentation reaches for. When the choice is genuinely contested, route to a research skill rather than deciding it here.
- **Wire it into the repo's existing entry point**, such as `npm test`, `make test`, or `pytest`, so the suite is reachable by the command someone would already try. A suite reachable only by an incantation in a chat log is not a suite.
- **Test-file placement follows the same rule.** Where an ecosystem carries two live conventions (colocated specs versus a `tests/` tree), follow whatever the repo's existing layout already implies rather than importing a preference.
- **Ask once before installing a dependency.** A dev dependency is a durable change to somebody else's project.
- **Land one green smoke test before writing anything real.** A retrofit that opens with forty tests against an unproven harness debugs the harness through the tests.

**When no standard runner can be wired up**, because the language, build system, or dependency situation defeats it, report the specific obstacle and stop. **Never improvise a harness.** A hand-rolled test loop is something nobody else can run, maintain, or replace, and it would be the most durable thing this skill ever left behind.

### 3. Declare the size before writing anything

State it before the first test file exists: **"N behaviours in this slice, this run covers M."**

You pick the numbers. They go on the record in advance, and the hand-off reports actual against declared. A run that wants to exceed its declaration **stops and says so** rather than drifting.

Nothing else bounds a run. Three tests and thirty both read as compliant afterwards, and the failure gate's cost scales linearly with a number nobody wrote down. A fixed cap would be wrong for both a 200-line utility and a payments module; a question every run would make an unattended run impossible.

### 4. Write the tests

**Source every expectation from outside the implementation**, meaning the docstring, the README, the issue, the type signature, the caller's actual usage, or the domain. Where nothing outside speaks, the test is a **characterization test**: a change-detector that locks current behaviour and makes no claim about correctness.

**Every test carries a one-line provenance comment, whichever kind it is:**

```
// per README: "amounts are stored in cents"
// characterization: no docstring, no issue, no caller assertion
```

Making both sides cost the same is the entire mechanism. A free label gets stamped on everything until the distinction means nothing. A label that costs more than the alternative pushes you to invent an external expectation to dodge it, which is the exact dishonesty the rule exists to catch. A citation on both sides removes the dodge in both directions.

**Fake only at the process boundary**, meaning network, clock, randomness, filesystem, or third-party service, and only where the real thing is unavailable or nondeterministic. Never fake a collaborator that lives inside the boundary. **Never assert that a call happened.** A test whose only assertion is a call count or a spy argument is checking that the implementation is the implementation.

**One behaviour per test, named for the behaviour** rather than for the function it happens to enter through.

**A contradiction becomes a skipped test plus a report**, never a source edit, never a weakened assertion. See [It never fixes, and it never restructures](#it-never-fixes-and-it-never-restructures).

### 5. Verify every target before running against it

**Nothing runs against a datastore or service testkit has not verified as disposable.**

Qualifying targets: `localhost`, a container testkit or the user started, or an explicitly named test URL. **A value inherited from an ambient `.env` never qualifies, however the file is named.** A config called *test* is a claim, not a fact, and trusting it is exactly the assumption that destroys somebody's data.

Where no disposable target exists, **ask once** to scaffold one. If the answer is no, defer the integration work to the ledger as a blocker and carry on with the unit tier.

This is the one rule here whose failure is unrecoverable, which is why it is written as a refusal rather than a caution.

### 6. The e2e tier, when it applies

Opt-in and narrow. It runs only when the app already launches non-interactively **and** a driver is installed or the user approves installing one. Cap it at a handful of critical-path specs, such as the sign-in and the one transaction that matters, never a mirror of the UI.

**testkit never opens a browser as a session action.** It authors the spec; the only thing that ever drives a browser is the repo's own test command executing that spec. The failure gate therefore applies to an e2e spec exactly as it does to a unit test, through the runner, with no exemption for the tier most likely to be written wrong.

That is the seam against a visual-verification skill, and it is stated as *who invokes the driver* rather than as artifact lifetime, because both skills legitimately want the same launch command, the same fixtures, and the same driver config, and only the first framing survives that overlap.

## The failure gate

**Every test testkit keeps has been observed red.** A test never watched to fail has demonstrated nothing about whether it is connected to the code at all.

The code already exists, so red-then-green is unavailable. The substitute: break the behaviour, run the test, watch it fail, restore.

**A valid break is a semantic mutation, never a deletion.** Change a returned value, flip a comparison, drop a branch, skip a write. Deleting the function or the file makes *everything* fail, including a test that asserts nothing, so it proves the import path resolves and nothing else. Use the smallest edit that changes the behaviour the test claims to check.

**Run the narrowest selection the runner supports.** The target test plus the others in its file. Never the full suite. Confirm the expected one goes red **and its neighbours stay green**, because that second half is free, and it catches an assertion that reaches too far. Where the runner cannot select a file or a pattern, lower the declared behaviour count and say why.

**The gate is never skipped for slowness.** A slow suite is the condition that makes the gate valuable, so an exemption would open in precisely the situation that most tempts you through it. Full-suite runs happen exactly twice, at the done-gate, and nowhere else.

**A test testkit wrote this run that stays green under its mutation is deleted**, and the deletion is reported.

**A pre-existing test that stays green is recorded, not deleted.** Log it in the ledger as *unproven*, with the mutation that missed it, and route it to the user. The delete rule is scoped to tests testkit authored this run. Deleting somebody else's test on evidence from a mutation aimed at something else is a scope this skill has not earned, and it converts a helpful signal into an unrecoverable one.

## The mutation ledger

Mutations are edits to tracked source. **The user may have had uncommitted work when the run started, and reverting a mutation must never revert it.**

- **Snapshot first.** Take `git stash create` before the first mutation. It writes an unreferenced commit object and touches no ref and no file, which is what makes it free, and also what makes it invisible, so print the SHA and its `git stash apply <sha>` recovery line in the hand-off on every run. Git prunes unreachable objects on its own schedule; say so rather than overselling the net.
- **Record every mutation**, meaning the file, the diff, and the behaviour it was testing.
- **Revert by reverse-applying the recorded diff. Never restore a file.** `git checkout -- <file>` is the reflex move and the one that silently destroys a pre-existing uncommitted edit. The ban has **no exception** for files that looked clean at baseline, because a ban with exceptions to reason about is not a ban.
- **On a reverse-apply conflict, stop the run and report.** Do not force. Do not fall back to a restore.
- **Verify the tree matches the baseline** before declaring done. Name by path anything deliberately left in place.
- **Never revert, stash, or discard a change testkit did not make.**

## The done-gate

"Done" means green, twice, shuffled, and clean. Discover the commands from the repo itself (`package.json` scripts, `Makefile`, `pyproject.toml`, `justfile`, CI config) rather than guessing.

- The new suite **passes**.
- Every kept test was **observed red**, against a named mutation.
- The suite **runs twice in a row and passes both times**, in randomised order where the runner supports it. Order dependence is the signature flakiness of a retrofitted suite, because tests written against existing shared state inherit that state.
- The repo's own **build/typecheck** still passes.
- The source tree carries **no leftover mutation**.

If the gate fails, fix your own output and re-run, **bounded to roughly three attempts**. Then stop. Never declare done on a failing gate, and never loop. The tempting fix here is to weaken the assertion; that is not a fix.

## Coverage numbers

**Never a goal, never a stopping condition.** Report a percentage only as a before-and-after fact, and only when the toolchain already produces one.

The stopping condition is the declared count. A target percentage is the most reliable way to manufacture exactly the pile this skill exists to prevent, because every rule above is expensive and a number can be reached without any of them.

## Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**After `audit`.** Report the coverage line, the crowned slice, and the runners-up in order. Give the ledger path. Name the testability blockers and the unproven pre-existing tests, if the run found any. Say there is no test code yet. Then crown one next move: run `cover` on the crowned slice. When the audit wrote no file, say the surface is already covered and state that there is no next step.

**After `cover`.** Report:

- the **mode** and where the slice came from, whether the ledger, the user, or an inline ranking;
- **declared against actual**, as in "declared 8 behaviours, covered 8";
- the **files** created and changed, including the runner wiring;
- the **gate result**, meaning the commands that ran, that every kept test was observed red, and that the suite passed two consecutive runs;
- **deletions**, meaning tests testkit wrote and then removed because they stayed green;
- **unproven** pre-existing tests, by path;
- the **baseline snapshot**: `baseline snapshot: <sha> · recover with git stash apply <sha>`;
- **tree state**, meaning the source is clean of mutations, or the paths that still carry one.

Leave every change **unstaged**. Do not `git add`. Do not commit. Do not draft a commit message.

Then crown one next move:

- **Deferred work remains in the ledger** → run `cover` again on the next slice.
- **The run found a contradiction** → route it to a debugging skill when one is installed, otherwise say plainly that somebody must decide whether the behaviour or the expectation is wrong.
- **The run found testability blockers** → route them to a refactoring skill when one is installed, otherwise say the code needs a seam before it can be tested.
- **Nothing remains** → say the slice is done and name committing as the next move. Suggest a message such as `test(<area>): cover <slice>` for the user to run. Never commit automatically.

## Notes

- **Never green-wash.** A declared "done" always means the gate actually passed. Red after the bounded fixes is reported as red.
- **Zero permanent source mutation.** Test files, the runner wiring, and the ledger are the entire write surface. Every mutation is temporary and reverted.
- **Read-only analysis.** Git history, file reads, greps. Never install or run an analysis tool to generate evidence. Read an artifact that is already on disk; never produce one.
- **Route, don't launch.** Name the next kit and its one-line invocation; do not invoke it.
- **Route, don't require.** Every recommendation degrades to a plain action when the named kit is not installed. testkit is useful in a bare repository with nothing but git.
- **Follow the repo over these defaults.** An established test layout, a documented convention, or a stated policy in the repo's agent-guide file (`CLAUDE.md` or an equivalent) wins, so say that you followed it.
- **No filesystem or shell?** You cannot write files, run a gate, or mutate anything, so the failure gate cannot run, and no test may be presented as verified. Print the proposed tests as fenced blocks with their paths, print the ledger as a codeblock under its canonical path, and list the gate commands the user must run themselves.
