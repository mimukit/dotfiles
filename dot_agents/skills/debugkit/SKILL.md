---
name: debugkit
description: >-
  Chase a symptom to its true cause — reproduce it, shrink it, write falsifiable hypotheses, and prove the cause by toggling the symptom on and off — then hand over a failing reproduction instead of a fix. Use when the user says "debug this", "why is this failing", "find the root cause", "what's causing this bug", "this test is flaky", "it broke after the upgrade", "it worked yesterday", "this got slower", or "/debugkit". It diagnoses and never applies the fix.
license: MIT
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, WebSearch, WebFetch, AskUserQuestion
metadata:
  internal: false
---

# debugkit

The skill you reach for when something is broken and nobody knows why. Every other build skill takes *intent* as its input — a plan, an issue, a diff, a settled decision. debugkit takes a **symptom**, and its whole job is to turn that symptom into a cause somebody can act on.

It is a single procedure. There are no modes: the ritual runs the same way on every bug, and the branches inside it are decided by what the evidence allows rather than by what the user asked for.

## It diagnoses, it never fixes

**debugkit mutates the repo freely to learn, and reverts every one of those mutations.** Log lines, bisects, config probes, commented-out branches — all fair game, none of them survive the run. What survives is the cause, a failing reproduction, and a fix *described* rather than applied.

This boundary is not modesty, it is what makes the report trustworthy. A skill that finds the cause and also lands the cure has already committed to an answer, so what you read afterwards is a rationalization of an edit that already happened. Keeping the diagnosis and the change in separate hands means there is a moment in between where you can disagree.

`Edit` is present in this skill's tools precisely *because* probes edit tracked files. That makes [the probe ledger](#the-probe-ledger) load-bearing rather than decorative — it is the only thing standing between a debugging session and somebody's uncommitted work.

## When this fires

"Debug this", "why is this failing", "find the root cause", "what's actually causing this", "this test is flaky", "it broke after the upgrade", "it worked yesterday and now it doesn't", "this endpoint got slower", "/debugkit".

Five boundaries, one line each:

- **Not a code review** — a review reads a *diff* for defects in work somebody just wrote. debugkit chases a symptom in code that already ran and misbehaved. A symptom in a diff nobody has executed is a review job, not a debugging one.
- **Not a test plan** — planning how to verify a feature happens *before* the bug exists. debugkit starts after something has already gone wrong.
- **Not a prototype** — a throwaway spike answers an *unsettled intent* ("would this design hold up?"). debugkit probes to explain an *observed failure*. The tools look similar; the question is the opposite.
- **Not a feature request** — see [the intake bar](#the-intake-bar). Behaviour nobody ever built is missing, not broken.
- **Not optimization.** A performance *regression* is in scope: "it used to be fast" has a change to bisect and a clean before-and-after, so the ritual runs unmodified. "Make this faster" is not: it has no cause to find, only a profile to read, and every gate below presumes a working state that stopped working.

## The intake bar

Before the ritual starts, you need three facts. **Ask once if any is missing, then stop until you have them.**

| Fact | Why it is required |
|---|---|
| **Expected** | what should have happened |
| **Actual** | what happened instead |
| **Where** | which environment, branch, or machine you saw it on |

Expected-versus-actual *is* the symptom. Handed only "it's broken," an agent invents the expectation it then debugs against — and that invented expectation is the root of every confident fix to the wrong thing. "Where" costs nothing to answer and immediately sorts the run onto the reproduce path or into [evidence-only mode](#the-three-terminal-states).

The bar is deliberately answerable in one sentence, because a bar that takes ten minutes to clear is a bar that gets skipped.

**One bounce.** When "expected" turns out to be behaviour nobody ever built, this is a feature request rather than a bug. Say so and route to a planning skill — **plankit** when it is installed, otherwise plainly: this needs a plan, not a diagnosis.

## The three terminal states

Every run ends in exactly one of these. There is no fourth, and inventing one is the failure this whole skill exists to prevent.

| Outcome | What it means | Where it goes |
|---|---|---|
| **Proven cause** | the on/off test passed — you can switch the symptom on and off at will | a build skill, with the failing reproduction |
| **Reproduced, not explained** | the bug reproduces reliably and every hypothesis died | back to the user, with the shrunk reproduction and the eliminated candidates |
| **Instrumentation plan** | the bug could not be reproduced at all | back to the user, with ranked hypotheses and the measurement that would discriminate each |

**The fourth state is a plausible theory that was never tested, and it is a failure even when it happens to be right.** It reads exactly like a real diagnosis — same confidence, same vocabulary, same shape — which is what makes it dangerous rather than merely unhelpful.

Only the first outcome hands off to a build step. The other two hand back to the user, because nothing was proven and there is therefore nothing to implement. Reporting an honest non-result is a success here, not a shortfall.

## The ritual

### 1. Reproduce

Find a command that makes it fail, every time, that anybody can run.

**The gate: no reproduction, no diagnosis.** An unreproduced bug yields a theory that is indistinguishable from a finding, and you have no way to tell which one you wrote.

This gate carries more traffic than it appears to. Every production-only bug lands here, and so does every cause that cannot be safely toggled — because [the proof gate](#4-prove) runs against the reproduction and nothing else. If the only place the symptom exists is a live system, you never had a safe place to prove anything, and that is a reproduce failure rather than a proof failure.

When reproduction genuinely fails, **say so out loud with a stated confidence** and drop to the instrumentation-plan branch. Never let it become a quiet fallback; a degraded run that does not announce itself is read as a full one.

### 2. Isolate

Shrink the reproduction until nothing can be removed without the symptom disappearing. The output is the smallest failing case.

**Force determinism while you shrink.** Pin the seed, serialize the concurrency, freeze the clock, fix the fixture ordering. A bug that fails one run in twenty cannot be toggled on and off, so determinism is not a nicety here — it is the precondition for the gate that follows.

Bisect over whatever axis the bug actually has: commits, inputs, config values, dependency versions, the delta between two environments.

**Run any commit bisect in a throwaway worktree, never in the user's tree.** `git bisect` moves `HEAD` and wants a clean tree, so running it in place either refuses outright or walks over both the user's uncommitted work and your own probe ledger:

```sh
git worktree add --detach <scratch-path> <known-good-ref>   # bisect lives here
git worktree remove <scratch-path>                          # before the run ends
```

A worktree skill owns this lifecycle when one is installed — **gitkit**, in this ecosystem. Without it the two commands above are the whole story. Either way the worktree is removed before the run ends, or named by absolute path in the hand-off if removal failed.

**When forcing determinism makes the bug vanish entirely**, that is itself a finding — the timing *is* the mechanism. Say so, keep the non-deterministic reproduction, and carry it into the statistical form of the proof gate rather than pretending you shrank it.

### 3. Hypothesize

**Write the candidate causes down before testing any of them.** Each one carries a **prediction that could fail** — something you expect to observe that you would not observe if the hypothesis were wrong.

A hypothesis with no falsifiable prediction is a guess wearing a label. It cannot be eliminated, so it survives the entire run and is still standing at the end, which is exactly how it ends up in the report.

Writing them first is not ceremony either. Hypotheses written *after* probing are reverse-engineered from whatever you happened to observe, which makes every one of them fit and none of them discriminating.

**Test the cheapest discriminating hypothesis first** — the one that eliminates the most candidates, not the one that is easiest to type. Halving the space beats confirming your favourite.

**Prefer a probe that changes nothing.** Calling the unit directly, running it in a fresh process, printing an intermediate value from the outside — these often discriminate just as sharply as an edit, and a probe that writes nothing needs no revert and can lose nobody's work. Reach for [the ledger](#the-probe-ledger) when the question genuinely requires changing the code, not by default.

**Stop when you can no longer write a new hypothesis carrying a falsifiable prediction.** That is the termination condition, and it needs no arbitrary count: an agent that wants to keep hunting has to produce a real prediction to justify the next round. When you hit it with the bug still reproducing, the run ends in **reproduced, not explained** — which is a real outcome, not a defeat.

### 4. Prove

**The on/off test, and nothing weaker.** You have the cause only when you can toggle the symptom by toggling the cause:

1. Cause present → it fails.
2. Cause removed → it passes.
3. Cause restored → it fails again.

Anything short of all three is correlation. This is the single gate that separates a diagnosis from "I changed something and it stopped."

**Quote the evidence** for each of the three steps. A gate whose output is the word "confirmed" has not been run in any way a reader can check.

**One change at a time.** Two changes at once teaches you nothing about either, and it is the exact mechanic behind the failure this skill exists to prevent.

**Never toggle against production, against real data, or against any system the user did not point at.** The test runs in the reproduction. This needs no unsafe-case exception, because the reproduce gate already filtered for one — a cause too dangerous to toggle belongs in the instrumentation-plan branch. An escape hatch here would be a door marked *skip the proof*, sitting in exactly the situation that most tempts an agent to walk through it.

**When determinism could not be forced**, the toggle takes a statistical form: N runs with the cause and N without, reporting both failure rates. One rule makes this honest instead of a loophole — **declare N before running, never after.** The loophole was never statistics; it was running until the numbers looked convincing. State N, state both rates, and state that the fallback was used.

### 5. Report

Name the terminal state, then give it what it needs.

**Proven cause** — the cause in one sentence, the on/off evidence, the failing reproduction (a command or a red test), and the fix **described rather than applied**. That package is exactly what a build skill's fix-round input expects, so it needs no translation.

**Reproduced, not explained** — the shrunk reproduction, every hypothesis you eliminated, and the evidence that killed each one. This is the most valuable thing an unexplained bug can produce: the next attempt starts from a much smaller box instead of from zero.

**Instrumentation plan** — ranked hypotheses, each paired with the specific experiment or log line that would discriminate it. The deliverable answers *what to measure next*, never *what is wrong*. **A confidence percentage on an untested theory is exactly what the reproduce gate exists to prevent, wearing a number** — do not attach one.

## The probe ledger

The safety property that makes free mutation acceptable. **Assume the user had uncommitted work when debugging started**, because they usually did, and reverting a probe must never revert that.

**Take a baseline before the first probe.**

```sh
git stash create        # writes an unreferenced commit; touches no ref, no file, no index
```

It costs nothing and changes nothing, which is what makes it worth doing unconditionally.

**Record every probe as its own patch.** Before your first edit to a file, copy that file's current content somewhere **outside the working tree** — so the copy never shows up in `git status`. After the edit, diff the copy against the file. That patch is your change alone, cleanly separated from whatever the user had already edited in the same file.

```sh
cp <path> <ledger>/<name>.pre                       # before the first edit
diff -u <ledger>/<name>.pre <path> > <ledger>/probe-NN.patch    # after it
```

Keep a ledger row per probe: the path, the patch, and why you made it.

**Revert by reverse-applying your recorded patches, in reverse order. Never restore a file.**

```sh
patch -R -s <path> < <ledger>/probe-NN.patch   # correct
git checkout -- <path>                         # banned, without exception
```

**Use `patch -R`, not `git apply -R`.** `git apply` resolves the paths written in the patch header against the repository root, and a patch produced from an out-of-tree snapshot carries paths that do not resolve — it fails with `invalid path` rather than applying. `patch -R` applies against the file you name and ignores the header, which is exactly the property you need here.

`git checkout -- <path>` is the reflex move and the one that silently destroys a pre-existing uncommitted edit. The ban has no exceptions, including for files that looked clean at baseline — a prohibition you have to reason about is one you will talk yourself out of at the wrong moment.

**When reverse-apply conflicts, stop and report.** Do not force it, and do not fall back to a restore. Name the file, the probe, and the patch location, and let the user resolve it.

**Finish by verifying the tree matches the baseline.** Report by absolute path anything deliberately left in place, and never touch a file the run did not modify.

**Print the baseline in the hand-off, every run:**

```
baseline snapshot: <sha> · recover with git stash apply <sha>
```

An object nobody can find is not a safety net — an unreferenced commit is invisible without `git fsck`. Say plainly that git prunes unreachable objects on its own schedule, so this is a short-term net rather than an archive. Write no ref: a ref would outlive the run.

## Web lookup decodes, it never diagnoses

Looking things up is allowed and often necessary. The boundary is what you use the answer for.

- **In bounds** — translating an opaque error string, a vendor status code, a stack frame from a library you do not know, a changelog entry for the version you just bisected to. Decoding a signal you already observed.
- **Out of bounds** — sourcing a hypothesis from a blog post, or applying a fix an issue thread says worked. That is somebody else's diagnosis of somebody else's bug.

In the reproducible branch this enforces itself: the on/off test is mandatory whatever the origin of an idea, so an untested suggestion cannot reach the report no matter where it came from.

**In the instrumentation-plan branch nothing is tested**, so the enforcement is instead that **every entry names its discriminating experiment or is dropped**. A fix lifted from an issue thread has no experiment attached — it says *do this*, not *measure this* — so the requirement filters it structurally, with no rule about sources for anyone to remember.

## The artifact

Keyed on the outcome, not on how hard the hunt was.

| Outcome | File? |
|---|---|
| Reproduced, not explained | **always** |
| Instrumentation plan | **always** |
| Proven cause, cause outside the code — environment, config, data, a dependency version | **always** |
| Proven cause, cause in the code | **no** — report inline |

The rule states its own reason: **the file exists for what the commit history will not capture.** A proven in-code cause is fully recorded by the fix and its test, so a document would duplicate them. A stale environment variable and a list of dead hypotheses are recorded nowhere else, and they are exactly what nobody remembers next month.

Write it to `docs/debug/debug-<slug>-YYYY-MM-DD.md` — a lowercase type prefix, a short lowercase kebab-case subject slug, and the ISO creation date at the end. Keep that creation date stable when the file is edited, and update the same file in place when you return to the same bug rather than spawning a dated copy. **When the repo already has an established home or naming scheme for postmortems, that convention wins** — say that you followed it.

The file is **durable and committable**: a postmortem is meant to be read later and belongs in version control, not in a scratch directory. debugkit still never commits it.

**No writable filesystem** (a browser-based agent) → print the artifact as a codeblock under its canonical path and skip the write. **Writing no file is a legal outcome** and needs no apology.

## Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed** — name the terminal state. List every probe you made and confirm you reverted it. State that you applied no fix. Name any file you deliberately left in place, by absolute path. Name any bisect worktree you failed to remove, by absolute path.

**Where it landed** — give the artifact path, or say that the outcome needed no file. Print the baseline line every run:

```
baseline snapshot: <sha> · recover with git stash apply <sha>
```

**Next** — crown one move, and match it to the outcome:

- **Proven cause** → hand the failing reproduction and the described fix to a build skill. Name **implementkit** when it is installed: it accepts this as a fix round and starts from your red test. Otherwise say plainly that the next step is to write the fix and make the reproduction pass.
- **Reproduced, not explained** → tell the user what evidence would restart the hunt. Do not route to a build skill. Nothing is proven yet.
- **Instrumentation plan** → tell the user to deploy the measurements you listed. Say that they should run debugkit again when the evidence arrives.

Do not start the next step yourself.

## Notes

- **Never apply the fix.** Not conditionally, not for one-liners, not when it is obvious. The one-line fix is where this rule earns its keep, because that is when skipping it feels harmless.
- **Never green-wash a gate.** An unproven cause is reported as unproven. A run that skipped the on/off test did not find a cause, whatever it found.
- **Route, don't launch.** Name the next skill and its one-line invocation; do not invoke it. Whether to act on a diagnosis is the user's call.
- **Route, don't require.** Every recommendation here degrades to a plain action when the named skill is absent. debugkit is useful in a bare repo with nothing but git.
- **Follow the repo over these defaults.** An established postmortem location, a documented convention, or a stated policy in the repo's agent-guide file (`CLAUDE.md` or an equivalent) wins — say that you followed it.
