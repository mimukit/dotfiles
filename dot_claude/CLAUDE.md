## Talking to me

Write every reply to me in ASD-STE100 Simplified Technical English:

- One term per thing, and keep it. Say "start", not "kick off" or "spin up".
- One instruction per sentence. Procedure: 20 words or fewer. Description: 25 or fewer.
- Active voice, present tense, named actor: "the hook kills the process".
- Keep the articles. Stack three nouns at most. Use a plain verb, not a gerund.
- No metaphor, idiom, slang, or humour with a second meaning.
- Six sentences or fewer per paragraph. Turn a longer one into a list.

This covers chat replies, summaries, explanations, and the procedural documents
you write for me: QA steps, handoffs, status snapshots, skill hand-offs. It does
not cover code, paths, command output, quoted text, or prose for a third-party
reader. Third-party prose follows the next section.

## Writing prose

Prose for a human reader (docs, READMEs, PR and issue bodies, commit bodies)
must not carry AI tells: no em or en dash as sentence punctuation, no puffery
("seamless", "crucial", "stands as a testament to"), no forced triads, no "not
only X but also Y", no signposting ("let's dive in"). Use plain verbs, concrete
detail, and uneven sentence length. For a full rewrite or a review pass, use the
`humankit` skill.

## Markdown files

Never hard-wrap Markdown. Write each paragraph and each list item as one continuous line, and let the editor soft-wrap it. Keep the line structure only where it carries meaning: code fences, tables, and YAML frontmatter. No setting on this machine wraps Markdown for you, so a wrapped file is your own doing. This rule covers every Markdown file you write or edit for me, including this one. If a repository states its own line rule, follow the repository instead.

## Committing

Never run `git commit` or `git push` on your own. Leave the work uncommitted for
me to review. Commit only when my prompt asks for it, or when the `afkkit` skill
runs.

## Background processes

Stop every background process you start before you end the turn. Keep one
running only when I ask for it.

## Deleting files

Run safe deletes yourself. The `rm-guard` hook checks every Bash delete: it
passes temp files and git-tracked files, it prompts me for risky targets, and it
blocks system roots. Do not refuse a delete in advance. Do not hand me an `rm`
to run by hand. If the guard denies a delete, tell me instead of trying another
way.

## Agent hooks

Our Claude Code and Codex hooks route through one dispatcher,
`~/.local/bin/agent-hook` (chezmoi: `private_dot_local/bin/executable_agent-hook`).
Change hook behaviour there, not in `~/.claude/settings.json` or
`~/.codex/hooks.json`. Orca, herdr and Paseo install and maintain their own
entries in those files. Leave those entries alone, and never wrap a vendor relay
inside the dispatcher.
