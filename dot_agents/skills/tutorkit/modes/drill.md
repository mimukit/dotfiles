## Mode: `drill`

Retrieval practice across topics. This is the reason one parent repo exists rather than one repo per topic.

### 1. Build the queue

Read `REVIEW.md`. Open the `CUES.md` of due topics only, never their lessons, never a glob. Collect every cue whose `due` is today or earlier. Due topics are the rows with at least one date on or before today. Rewrite each opened topic's `REVIEW.md` row from its `CUES.md` as you go. Done when every due cue in the opened files is in the queue.

### 2. Cap it at 12

Sort by `due` ascending, then by `misses` descending. Fill the 12 slots from `active` topics first and let `learned` topics take what is left. **Print what you left behind**, as in `12 of 41 · 29 still due`.

An uncapped queue is the failure mode that ends every spaced-repetition habit: forty cues on return trains the user to stop opening it. Hiding the backlog is only a nicer way to lose it. **The overflow keeps its original `due`**, so it stays first in line tomorrow rather than having its debt quietly rescheduled. Done when the queue holds at most 12 cues and the left-behind count is printed.

### 3. Interleave and ask

Mix cues from different topics rather than running one topic to exhaustion. Ask **one at a time, with no answer visible**, because a cue printed beside its answer tests nothing. Show `last seen` on the line when it is far in the past, so the user can judge their own miss with the fact in view. Done when every cue in the queue has been asked or the user stops the run.

### 4. Grade, offer the override, then reschedule

Grade the free-text answer against the cue's stored key points per [Grading a free-text answer](../SKILL.md#grading-a-free-text-answer), **offer the override on every grade**, then write the new `due`, `step`, `misses`, and `last seen`. On `missed`, re-teach the cue inline in two or three sentences before moving on.

Update `REVIEW.md` and `PROGRESS.md` when the run ends. Done when every answered cue has a new `due`, `step`, `misses`, and `last seen`, and each opened topic's `REVIEW.md` row lists the new due dates. Then go to [Hand off](../SKILL.md#hand-off).
