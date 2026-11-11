# Mode `migrate`: write or check a migration

Migrate makes a schema change safe on a live database, where one lock can block every write. It judges each statement by its lock before its table's size.

### 1. Pick the branch

- **write**: the ask states a change ("write a migration to rename `email`"), or `tune` or `design` passed an index or a change here.
- **check**: the ask names an existing migration or a diff with one.

An ask with both a change and a safety question runs **write**. Run [Stack detection](../SKILL.md#stack-detection) and [Project conventions win](../SKILL.md#project-conventions-win) first. For MySQL or SQLite, the selected engine file replaces the Postgres links below.

**Done when** the branch is named and the stack and convention lines are stated.

## Branch: write

### 2. Split the change per deploy

Break the change into one step per deploy under [Migrations](../SKILL.md#migrations). An index from `tune` is one step, built under [Concurrent index builds](../engines/postgres.md#concurrent-index-builds).

Write only the steps safe for the current deploy. **Never write a migration that must wait for a later deploy into the migrations directory.** Hold the contract step for the hand-off, with its trigger condition ("after deploy N is live and no code reads `old_col`").

**Done when** every step has a deploy number, and every later step is held outside the migrations directory with its trigger condition.

### 3. Run the data-integrity pre-checks

Before a step tightens a constraint, count the rows that break it under [Constraints](../SKILL.md#constraints): `NULL`s before `NOT NULL`, duplicates before `UNIQUE`, orphans before a foreign key. Run each count as a `SELECT` through `DB_CMD` on a cleared host under [the connection guard](../SKILL.md#the-connection-guard), or give the query to the user. A nonzero count puts a data fix before the tightening step.

**Done when** every tightening step has a count or a query handed to the user, and every nonzero count has a data-fix step.

### 4. Write the files

Read [orms.md](../orms.md), then write each current-deploy file through the project's generator under [the disposable target](../SKILL.md#the-disposable-target) rule, or by hand in the tool's layout.

- Put DDL and DML in separate files; a backfill follows [Batched backfill](../engines/postgres.md#batched-backfill).
- Open each file that touches a live table with [Timeouts and the lock queue](../engines/postgres.md#timeouts-and-the-lock-queue).
- Take each statement's safe path from [Locks per DDL statement](../engines/postgres.md#locks-per-ddl-statement).
- Give each concurrent statement its own file, or the tool's no-transaction form.

**Done when** every current-deploy step has a file, and no file mixes DDL with DML.

### 5. Check the written files

Run the [check branch](#branch-check) on every written file. Fix each statement with a verdict other than safe, then check again.

**Done when** every statement is safe, or has a stated reason for the user to decide.

### 6. Write the deploy order and rollback

List the steps in deploy order: the deploy number, the file or held step, and a rollback line. A rollback is a new forward migration under [Migrations](../SKILL.md#migrations).

When a plan file for this change exists, write the held steps and rollback lines into its `Migration and rollback` section, in the shape the check branch uses.

**Done when** every step has a deploy number and a rollback line, and the plan section is written when a plan exists.

## Branch: check

### 7. Build the risk table

Read the migration, or the SQL its tool prints (`sqlmigrate`). Take each statement's lock and cost from [Locks per DDL statement](../engines/postgres.md#locks-per-ddl-statement), against [Version limits](../engines/postgres.md#version-limits) for the detected version. Decide the verdict in this order:

1. **Lock class first.** A statement that takes `ACCESS EXCLUSIVE` or rewrites the table needs a lock timeout at any table size. Without one, it is unsafe.
2. **Size second.** Only scan or rewrite time takes a size condition, stated as "unsafe above N rows".

The verdict is **safe**, **safe with a change** (name the change), or **unsafe** (name the safe path).

```
| # | Statement | Lock | Table | Verdict |
| --- | --- | --- | --- | --- |
| 1 | CREATE INDEX orders_customer_id_idx ON orders (customer_id) | SHARE | orders | unsafe: blocks writes during the build; use CONCURRENTLY |
```

**Done when** every statement has a row with its lock, its table, and a verdict.

### 8. Check the file as a whole

Add a finding for each of these:

- An edited applied migration: `git log --follow` shows a change after the file merged to the default branch.
- DDL and DML in one file.
- A dev-only command in a deploy path, per orms.md.
- A live-table statement with no lock timeout before it.
- `CONCURRENTLY` inside a migrator that wraps the file in a transaction, per orms.md.

Then write a rollback section in the plan's `Migration and rollback` shape: how existing data moves, in which deploy, and how to undo it.

**Done when** each of the five checks has a finding or a stated pass, and the rollback section is written.

### 9. Hand off

**What changed.** For write, name each migration file and state that no migration was applied. For check, state that no file changed. Name the `--help` or docs you read.

**Where it landed.** Give each file path, and the plan path when its `Migration and rollback` section changed.

**Held steps.** List each held step with its trigger condition. With no plan file, file it with **issuekit** when installed. Otherwise, add a TODO.

**Next.** For write, apply the current deploy's migration on the dev database with the project's command, for example `pnpm db:migrate`. For check with an unsafe row, fix the first one with `migrate` write: "rewrite this migration safely". When every row is safe, state that the migration passes and stop.
