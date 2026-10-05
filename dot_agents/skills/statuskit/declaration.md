# The declaration offer

This file assumes [SKILL.md](SKILL.md) is loaded. It fires only on an empty-array **unknown** reading from [Resolving the tracker](SKILL.md#resolving-the-tracker), with a user there to answer.

Offer to append one sentence to the repo's agent-guide file, so the next run resolves at the agent-guide rung instead:

> `This project tracks work in Linear, not GitHub Issues.` or `This project manages work in GitHub Issues.`

Four bounds hold it inside statuskit's [write rules](SKILL.md#write-rules):

- **Preview it and wait for an OK**, like any outward-facing change, even though this one is local.
- **Write only to an agent-guide file that already exists**, preferring `CLAUDE.md` and otherwise whichever equivalent the repo keeps. **Never create one**, because a repo without such a file has deliberately not got one, and a status check is the wrong tool to invent it. With no such file, print the line for the user to place.
- **Offer it once per run, as a runner-up**, never as the crowned move. A repeated prompt on the tool people run to orient is a nag, and it would outrank work they could actually finish.
- **Skip it entirely in an unattended run.** There is nobody to approve it, and a declaration guessed at is worse than the ambiguity it replaces.

The offer is done when the sentence is written on approval, printed for the user to place, or declined. The snapshot's runner-up for it carries the key `declare-tracker`.
