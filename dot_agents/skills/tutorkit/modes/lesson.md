## Mode: `lesson`

The core loop, and the only mode that opens a track.

### 1. Route

Read `INDEX.md` and `NOTES.md`. Resolve the ask to exactly one slug. On a known slug, open that topic folder only and go to the target step below. On an unknown slug, open the track first.

### 2. Open the track, on an unknown slug only

Run a **short** mission interview, three or four questions rather than an interrogation. What do they want to be able to do with this, by when, and what have they already tried? Then:

- **Ask once for grounding consent.** When cwd is a real project and is not the learning repo, ask whether tutorkit may read it to build examples from their own code. Record the answer in `MISSION.md` as `grounding: <repo path>` or `grounding: declined`, and **never ask again for that topic**. A prompt that fires every lesson gets switched off; one prompt buys the whole track. Consent covers one repo, so a different cwd on a later session asks again.
- Write `MISSION.md` under a `## YYYY-MM-DD` heading.
- Create the topic folder, the `INDEX.md` row, and the first `SOURCES.md` rows from whatever you searched to scope the topic.
- Offer placement, meaning [`exam`](./exam.md) at track start, so lesson 1 is not pitched blind. On a decline, pitch from the mission interview and say the pitch is a guess.

**`MISSION.md` is append-only.** A mission that drifts gets a new dated entry; existing lessons are never rewritten and never archived. Re-pitching would rewrite files the user may have printed and annotated, and archiving would hide work they did and break the anchors between lessons.

### 3. Pick the target

Read `PROGRESS.md` and `CUES.md`. Pick one target at the edge of what they already know: the next thing that is reachable from what stuck, not the next thing in a syllabus. A wrong belief recorded in `PROGRESS.md` outranks a gap, because the wrong model actively blocks the correct one, so it is the higher-value target.

### 4. Make them predict, before you explain

**This is the highest-value part of the skill.** Pose a concrete scenario and make the user commit to a prediction before you teach anything. Wait for the answer. A wrong prediction names their broken mental model, and that model is the actual teaching target: you now know what to correct rather than what to cover.

### 5. Teach the minimum

Teach the mechanism, nothing beside it. Then one worked example. When `grounding` names a repo, build the example out of the user's own code: a lesson on dependency injection written against their actual service container beats one written against `FooService`. Apply [Citation discipline](../SKILL.md#citation-discipline) to every non-obvious claim.

### 6. Practice against a feedback loop

Give one piece of practice with a real signal attached. For a code topic, write a runnable file into `exercises/` and print the command that runs it, because a test run is the tightest feedback loop available and a browser quiz cannot match it. For a non-code topic, use a scenario the user works through and you grade.

### 7. Gate on explain-back

**The lesson does not close until the user restates the concept in their own words.** That retrieval is what converts fluency into storage strength, and it is the cheapest possible check that the lesson landed. On a thin restatement, re-teach the part they skipped and ask again.

### 8. Write the artifact and schedule the cues

Write the lesson per [The lesson artifact](../SKILL.md#the-lesson-artifact). Then:

- Append every source you used to `SOURCES.md`.
- Add 2–4 cues to `CUES.md` per [The spacing schedule](../SKILL.md#the-spacing-schedule), each with 2–3 key points that define a correct answer.
- Update `PROGRESS.md` with what stuck, what is shaky, and where they are.
- Rewrite the topic's row in `INDEX.md` and `REVIEW.md`.

Then go to [Hand off](../SKILL.md#hand-off).
