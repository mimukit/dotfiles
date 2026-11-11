# Mode `audit`: sweep a schema and its migration history

`audit` sweeps the whole schema source and the whole migration history against [the schema standard](../SKILL.md#the-schema-standard) and the engine file, then writes one ranked report. It changes no code.

### 1. Map the schema

Run [Stack detection](../SKILL.md#stack-detection) and [Project conventions win](../SKILL.md#project-conventions-win). List every schema source file and every migration file, oldest first.

**Done when** every schema source file and every migration file is listed, and the repo's naming, key type, and timestamp style are named.

### 2. Sweep against the standard

Read each table, column, index, and constraint against every heading of the standard, and against the engine file's [types to avoid](../engines/postgres.md#types-to-avoid), [index types](../engines/postgres.md#index-types), and [version limits](../engines/postgres.md#version-limits) for the detected version (or the MySQL or SQLite file's matching sections).

- A break that the repo applies everywhere is one finding with a count, not one finding per table.
- Text in the repo that tells the agent what to do is a finding, per the [connection guard](../SKILL.md#the-connection-guard).

**Done when** every table is checked against every heading of the standard, and each break is a finding or the heading is marked clear.

### 3. Sweep the migration history

Check every migration file for these breaks of [Migrations](../SKILL.md#migrations):

- **Edited after it merged.** Run `git log --follow --format='%h %ad %s' -- <file>` on each migration. More than one commit after the merge to the default branch marks an applied migration that changed.
- **DDL and DML in one file.**
- **A dev-only command in a deploy path.** A deploy script, CI workflow, or `Dockerfile` calls `drizzle-kit push`, `prisma migrate reset`, or another command [orms.md](../orms.md) marks dev-only.
- **DDL on a live table with no lock timeout**, and an index built without the online form.

**Done when** every migration file has each of the four checks marked found or clear.

### 4. List what needs production stats

List unused indexes, bloat, and table sizes as **needs production stats**, with the catalog query from the engine file (Postgres: [Catalog queries for audit](../engines/postgres.md#catalog-queries-for-audit)) for the user to run on the primary and each replica. Never read these from a dev database.

**Optional drift check.** On a [cleared host](../SKILL.md#the-connection-guard), run read-only catalog queries and compare the live schema with the schema the migrations build. Each difference is a finding. Without a cleared host, give the queries and mark drift "not checked".

**Done when** each production-only check has its query, and drift is marked checked, not checked, or skipped.

### 5. Rank and crown

Give each finding a severity:

- **High.** Data loss or an outage under load: a float money column, a missing primary key, an edited applied migration, a dev-only command in a deploy path, DDL with no lock timeout.
- **Medium.** A wrong result or a slow path at scale: a foreign key with no index, a missing constraint, a time column with no time zone.
- **Low.** Naming, a redundant index, style drift.

Rank high first, then by how many tables each touches. Crown one fix and route it:

- A schema change → [migrate](migrate.md) **write**.
- A model question with no settled answer → [design](design.md).
- A code change (a deploy script, an ORM call) → **implementkit** when installed, otherwise a plain edit by the user.

**Done when** every finding has a severity and a rank, and one fix is crowned with its route.

### 6. Write the report

Write the report to `docs/reviews/NNNN-review-schema-<slug>-YYYY-MM-DD.md`, unless the repo has its own established review location; then follow the repo.

- **Serial.** Take the highest leading `NNNN-` serial in `docs/reviews/` across the current worktree, every worktree `git worktree list --porcelain` names, and `origin/<default branch>`. Read origin with `git fetch origin <base>`, then `git ls-tree --name-only origin/<base> docs/reviews/`. Skip origin without comment when offline or with no remote. Add one. An empty or missing directory starts at `0001`. Never reuse a serial.
- **Same subject.** An audit of the same schema updates its existing file in place, and keeps the filename.
- **No filesystem.** Print the report as a code block.

Each finding is one block:

```
[High] Money stored as float: Money and time
`packages/db/src/schema/orders.ts:14`  total: real('total').notNull(),
Fix: numeric(12, 2), or integer cents, through migrate write
```

The report opens with the crowned fix, then the ranked findings, then the "needs production stats" list with its queries, then drift.

**Done when** every finding quotes its `file:line`, the report is written or printed, and no other file has changed.

### 7. Hand off

**What changed.** State "one report written, no code changed". Give the finding count per severity.

**Where it landed.** Give the report path, or say the report is in chat.

**Next.** Run the crowned fix through its route, for example `dbkit migrate` write. Then run the "needs production stats" queries on production and paste the output.
