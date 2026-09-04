## Mode: `init`

For a repo with no doc set, or a partial one.

### 1. Ground it

The research pass, and the bulk of the work. Read the manifests and their declared commands, entry points, CLI surface, routes, env vars, config, `Dockerfile`/compose, CI workflows, deploy config, the existing README, and `CONTEXT.md`/`docs/adr/` when they exist. Ask once for probe consent and use it to confirm the commands that will end up in `getting-started.md`, because a getting-started whose first command doesn't exist is worse than no getting-started.

### 2. Adopt what's already there

Pages found under rung 2 get manifest entries with `documents:` globs, `adopted: true`, and no stamp. wikikit does not rewrite them and does not claim them.

### 3. Propose the map

Consent-gated, and this is the gate that matters. Show the page list with a one-line scope each, which entries are newly authored versus adopted, and **what wikikit could not determine from code**. The user accepts, trims, or redirects before a single file is written.

### 4. Write the accepted pages

Each grounded per [Grounding: verify before you write](../SKILL.md#grounding-verify-before-you-write), each held to the [Writing standards](../SKILL.md#writing-standards), each stamped with `<ref>@<sha>` and the date.

### 5. Rewrite the README front door

wikikit owns exactly one zone of the README: **what this is, the quickstart, and the links into the doc set**. It does not touch badges, license, acknowledgments, or anything else. The README is the most-read page in any repo; leaving it out of the maintained set is how it ends up lying about the install command.

The zone is delimited by marker comments. The first run infers the boundary positionally, shows the **exact** proposed boundary, and writes the markers on consent:

```markdown
<!-- wikikit:front-door:start -->
...
<!-- wikikit:front-door:end -->
```

Every later run is exact rather than positional. Refuse the markers and wikikit writes nothing to the README at all, and says so.

### 6. Write the manifest and update the nav

Write `<doc home>/.wikimap.yaml`, then update the docs engine's nav or sidebar config when one was detected. A page an engine can't reach is a page nobody reads.

### 7. Hand off

_Write every hand-off in this skill in the procedural register: one instruction per sentence, active voice, present tense, no metaphor._

**What changed.** Report pages authored, pages adopted (mapped, not stamped), the README zone written or declined, and what could not be determined from code.

**Where it landed.** Give the doc home, which ladder rung chose it, the manifest path, and the engine config touched.

**Next.** Read the set. It is new prose about your project and it is the one thing here a human should actually check. Then commit it with **commitkit** when installed, otherwise a plain `git add` and commit. If a term surfaced that belongs in the glossary, route to **domainkit** rather than defining it on a page.
