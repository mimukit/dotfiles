## Committing

Never commit on your own. Leave every change or new implementation as uncommitted files for the owner to review. The owner reviews first, and only then may they tell you to commit.

The only exception: if the owner's prompt explicitly asks you to commit (and/or push) as part of completing the task, do that. Absent that explicit instruction, do not run git commit or git push — stop after making the edits and let the owner review.

## Deleting files

Never delete files or directories. You have no permission for rm or rm -rf (or any other delete operation). Attempts will fail — do not retry them in different ways.

When a file or directory needs to be removed, do not attempt it yourself. Instead, collect the removals and hand them to the owner at the end as a manual task: list the exact rm commands to run, and mark them as a to-do for the owner to execute.
