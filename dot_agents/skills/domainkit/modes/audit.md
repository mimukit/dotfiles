## Mode: `audit`

Check whether `CONTEXT.md` still matches the code and the ADRs, list every place it disagrees, and apply the fixes the user accepts. It runs only when the user asks for it, often after statuskit flags drift. The writes follow [the consent rule](../SKILL.md#consent-every-mode), and every fix keeps [the CONTEXT.md format](../SKILL.md#the-contextmd-format).

### 1. Read the history

`git log` is the only shell command this mode runs. Find the last commit that touched the domain model, then the files changed since it:

```sh
git log -1 --format='%H %cs' -- CONTEXT.md CONTEXT-MAP.md
git log --name-only --format= <sha>..HEAD
```

Add each per-context file that `CONTEXT-MAP.md` names to the first command's paths. Read the second command's output as a set, because a file changed in several commits appears several times. With no git, no commit that touched the file, or a refused command, skip the history and compare against the current tree; say once that the audit had no history.

Done when you hold the list of files changed since the last domain-model commit, or the fallback is stated.

### 2. Read the model and the code

Read `CONTEXT.md`, or `CONTEXT-MAP.md` and every context file it names. Read the changed files from the history first, because drift lives there. Then read the entry points, the routes or CLI surface, the README, and every ADR in `docs/adr/` with its `Status` line.

Done when every one of those sources has been read or named as absent.

### 3. Find the drift

Check every overview capability, every glossary term, and every ADR a term depends on against what you read. Each finding is one of six types:

| Type | Finding |
|------|---------|
| `capability gone` | an overview capability the code no longer has |
| `capability missing` | a capability the code has that the overview omits |
| `term missing` | a domain term the code uses that the glossary lacks |
| `term unused` | a glossary term the code no longer uses |
| `term superseded` | a term defined against an ADR whose `Status` is `deprecated` or `superseded by ADR-NNNN` |
| `content rule` | a status, roadmap, metric, decision, or usage line that breaks the content rule |

Give each finding its evidence: a file and line, or the search that came back empty. A `term missing` must pass the glossary's content rule, so a general programming concept is never a finding. When the evidence leaves a finding unclear, for example a capability that moved rather than went, mark it `unsure` and say what would settle it.

Done when every capability, every term, and every linked ADR has been checked, and each finding has its type and its evidence.

### 4. Propose the fixes, then apply the accepted ones

With no findings, report **no drift** in one line and write nothing. Otherwise show every finding with its proposed edit, in one message, as one diff. Never invent a replacement for a gone capability or an unused term; propose to remove it, or ask the owner when the code alone cannot say. The user may accept all, accept some, or edit a proposal. Apply exactly what was accepted, and hold the overview to its length caps after the edit.

Done when every finding is accepted, edited, or declined, and every accepted edit is written.

### 5. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Give the count of findings by type, then the edits applied and the findings declined. Say "no drift" when there were no findings.

**Where it landed.** Give the exact path of each file edited.

**Next.** Commit the edits with commitkit when installed, or with a plain `git add` and `git commit`. When a finding stayed `unsure`, name it, and ask the owner to settle it. When the audit found no drift, say so and stop, because there is no next step.

Done when the report names each change, each path, and the next move, or says that none exists.
