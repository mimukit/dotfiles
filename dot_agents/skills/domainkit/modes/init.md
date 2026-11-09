## Mode: `init`

Seed the domain model in one pass: read the repo, interview the owner once, and propose a whole `CONTEXT.md` with an overview and the first glossary terms. It runs only when the user asks for it. The write follows [the consent rule](../SKILL.md#consent-every-mode), and the file follows [the CONTEXT.md format](../SKILL.md#the-contextmd-format).

### 1. Read the repo

Look up every fact the code answers before asking anything. Read the manifests (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, and the like) and their declared scripts, the entry points, the routes or CLI surface, the README, and an existing `CONTEXT.md`, `CONTEXT-MAP.md`, and `docs/adr/`. In a workspace, read the root manifest and each package's manifest, because the package names often carry the domain's nouns. A repo with no code at all is **greenfield**: note it, and let the interview carry every overview part.

Done when every source on that list has been read or named as absent.

### 2. Draft the overview and the candidate terms

Draft each of the five overview parts from what the code shows, and tag each one `read from code` or `assumption`. A part the code leaves open stays an `assumption` with a recommended answer, never a blank. Then list the candidate glossary terms: the domain nouns that recur across type names, routes, commands, and UI labels, each with the file where it appears. Keep only terms that pass the glossary's content rule, so general programming concepts stay out however often they appear.

Done when each of the five parts holds a tagged draft, and each candidate term names the file it came from.

### 3. Interview the owner in one batch

Ask only about the parts tagged `assumption`, plus one question for the term list. That is at most 6 questions, each with your recommended answer first. Use `AskUserQuestion` when it is available; when it caps one call below the batch, send the rest in a second call at once, with no other work between them. Without it, ask the batch in one message. For the term list, show the candidates and ask which to keep, merge, or rename.

The owner may answer "does not matter" for any part. That drops the subsection from the file, except **What it is**, which is required: on that answer, keep the recommended draft. On a greenfield repo every part is an `assumption`, so the batch carries all five parts, and the term question asks for the words the owner already uses.

Done when every `assumption` part has an answer or has been dropped, and the term list is settled.

### 4. Merge with what exists

With no `CONTEXT.md`, the proposal is the whole new file. With one, merge **additively**: add the overview when it is missing, add each new term, and leave every existing entry exactly as it is. When a draft or an answer disagrees with an existing entry or overview line, do not rewrite it; list it as a conflict for `audit`. In a multi-context project, the overview goes in `CONTEXT-MAP.md`, and each new term goes in the context file it belongs to.

Done when the proposal holds every addition, and every conflict is listed with the line it disagrees with.

### 5. Show the proposal, then write on a yes

Show the full proposed file, or the diff against the existing one, in one message, with the conflict list below it. Hold every part to the overview's length caps before you show it. On a yes, write it. On a redirect, revise and show it again.

Done when the user has accepted and the file is written, or the user has declined and nothing is written.

### 6. Hand off

_Write this section in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Name the file written, the overview parts it holds, and the count of terms added. Name each part dropped as "does not matter". Say so when the user declined and nothing changed.

**Where it landed.** Give the exact path (`CONTEXT.md`, or `CONTEXT-MAP.md` and each context file).

**Next.** When the run listed conflicts, resolve them with `domainkit audit`. Otherwise commit the file with commitkit when installed, or with a plain `git add` and `git commit`. Name runners-up after the crowned move: route a contested term to grillkit, when installed, before you record it.

Done when the report names each change, each path, and the next move, or says that none exists.
