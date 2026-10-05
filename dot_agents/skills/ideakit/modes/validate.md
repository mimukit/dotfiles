## Mode: `validate`

Route to one slug, then pick a path. **validatekit is invocation-only: the model cannot start it, and only the user can.** So when it is installed, offer the user two paths and let them choose:

1. **Run validatekit yourself.** Give the exact line to type, with the absolute path of the idea's `IDEA.md`: `/validatekit <ideas repo>/topics/<slug>/IDEA.md`. validatekit answers inline. When the user comes back with the verdict in the conversation, offer to keep the write-up at `topics/<slug>/docs/validation/`.
2. **Run the short version here.** A short forcing-question set and a graded verdict, inline, and **say plainly that it is the short version**.

Without validatekit installed, run the short version and say so.

**Honor the side-project off-ramp rather than working around it.** It will fire often here, because most ideas in a personal ideas repo are not businesses, and an honest "this is a side project, not a company" is a real answer worth offering to write down.

Offer the verdict, the wedge, and the assignment as one `NOTES.md` entry, with the router status change when the verdict moves it.

**Done when** the user has chosen a path. On the validatekit path, the user has the line to run, and the mode ends until they bring the verdict back. On the short path, the user has seen the verdict and answered the save offer: on a yes, the verdict, the wedge, and the assignment are in `NOTES.md`, and the router status matches the verdict; on a no, the folder is untouched. Then go to [Hand off](../SKILL.md#hand-off).
