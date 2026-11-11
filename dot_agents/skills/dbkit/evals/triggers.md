# dbkit trigger cases

Run each prompt in a fresh session and record whether dbkit fired, and which mode. A near-miss that fires means the description is too broad; a should-fire case that stays quiet means a branch has no trigger.

## Should fire

**design**

- "Design the schema for invoices and their line items"
- "How should I model these tables for a multi-tenant app?"

**migrate, write**

- "Write a migration to rename `email` to `email_address`"
- "Add a `status` column to orders and make sure the migration is safe"

**migrate, check**

- "Check this migration"
- "Is this migration safe to run on production?"

**tune**

- "This query is slow"
- "Explain this query plan" (with a pasted `EXPLAIN` output)
- "Add an index for this query"

**audit**

- "Audit our database schema"
- "Review our migrations history for problems"

## Should not fire

**Near tune**

- "This page got slow" (symptom with an unknown cause: debugkit)
- "This endpoint got slower after the upgrade" (symptom with an unknown cause: debugkit)

**Near migrate, check**

- "Write a QA plan for this migration" (behavior tests after the change: qakit)
- "Review my changes before I open the PR" (code review of the whole diff: reviewkit)

**Near design**

- "Which database should we use, Postgres or MySQL?" (technical decision: researchkit)
- "Plan the billing feature" (feature plan: plankit)

**Near any mode**

- "Set up this worktree's database" (worktree dev database: gitkit `prepare`)
- "This test that writes to the database is flaky" (symptom with an unknown cause: debugkit)
