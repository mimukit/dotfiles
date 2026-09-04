## Mode `list`: the morning dashboard

What is actually waiting on you, in one table:

```sh
gh pr list --state open --json number,title,headRefName,isDraft,statusCheckRollup,reviewDecision,author,updatedAt
```

Three facts that command cannot give you matter more than the ones it can, so gather them per PR:

- **Unresolved review threads.** REST does not expose thread resolution state at all; only GraphQL does, via a `reviewThreads` connection carrying `isResolved` and `isOutdated`. Query it with `gh api graphql`; if the shape has moved, check the current [GraphQL API docs](https://docs.github.com/en/graphql) rather than guessing. A PR with a bot review sitting unanswered is not ready for your time.
- **Behind the base branch.** Run `git fetch origin` once, then compare each head against `origin/<base>`, because a PR that is behind is one you would be reviewing in a state that will never exist.
- **A QA plan and proof.** Look for the artifacts your repo's conventions produce (a QA plan doc, a proof bundle, whatever the PR body links). Absence is a fact worth printing, not a silence.
- **Stack position.** A PR whose base is another feature branch is a layer, and that is the single most important thing to know before opening it: its diff is only its own slice, and merging it merges everything below it. Mark the layer and its depth (`layer 2 of 3`), and group a stack's PRs together in the table rather than scattering them by update time.

Print one table, most-ready first, with drafts and PRs authored by others clearly marked. **Do not crown a "next" PR**, because ranking work is a project-status job, and a reviewer's queue is theirs to order. Within a stack, print bottom layer first: that is merge order, and the bottom is the only layer that can land alone.

### Hand off

**What changed.** Nothing. `list` reads and prints only.

**Where it landed.** The table above.

**Next.** Pick a PR from the table and run `start <n>` to set it up for review.
