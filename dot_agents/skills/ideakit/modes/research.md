## Mode: `research`

Route to one slug first, then classify the question before acting.

- **A tool, library, framework, or architecture question** goes to a research skill (**researchkit** when installed), answering inline. Offer to keep it at `topics/<slug>/docs/research/` afterwards.
- **A build-or-drop question** is not research. Redirect it to [`validate`](./validate.md).
- **A market, competitor, category, or customer-signal question** has no sibling owner, so ideakit runs it directly: who else does this, what the category is called, how incumbents price it, and what users publicly complain about. **Give every claim a source and a date.** Offer the result at `topics/<slug>/docs/research/research-<slug>-YYYY-MM-DD.md`.

Without a research skill installed, run the comparison against primary sources directly and **say plainly that it is the short version**.

**Done when** the user has seen the answer and answered the save offer. On a yes, the artifact exists, the `NOTES.md` entry names the question and the answer, and `IDEA.md` and the router row match. On a no, the folder is untouched. Then go to [Hand off](../SKILL.md#hand-off).
