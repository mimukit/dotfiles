# Mode `tune`: find why a query is slow

`tune` finds why one named query is slow and proposes one change. The evidence is a plan from the database where the query is slow; code supplies the SQL and the N+1 patterns. `tune` edits no file.

### 1. Find the SQL

Run [Stack detection](../SKILL.md#stack-detection), then trace the named query to the code that builds it.

- **From the code.** Write out the SQL the ORM call or raw query produces, parameters as placeholders.
- **From query logging.** When the SQL stays hidden, run the code path with the ORM's query logging on, against a [cleared host](../SKILL.md#the-connection-guard) only.
- **Read N+1 from the code.** A query inside a loop, or a relation loaded once per row, is an N+1. A plan of one statement never shows it.

**Done when** the SQL is written out in full and each loop or per-row load on its path is named with `file:line`, or stated absent.

### 2. Get the plan

The main evidence is `EXPLAIN (ANALYZE, BUFFERS)` from the database where the query is slow, which the user pastes.

- **No pasted plan?** Give the exact `EXPLAIN (ANALYZE, BUFFERS)` command with the SQL from [Find the SQL](#1-find-the-sql) filled in, and say where to run it. Then stop.
- **A production-named script?** When the user asks dbkit to run `db:prod:query` or a similar script, refuse per the [connection guard](../SKILL.md#the-connection-guard) and give the `EXPLAIN` command for the user to run.
- **A local plan** counts as evidence only when the user states the production row counts and the plan's row counts on each large table fall within 10× of them. Otherwise it shows plan shape only, and the report says so.

**Done when** a pasted plan is in hand, or the exact `EXPLAIN` command is given and the mode has stopped.

### 3. Diagnose

Read the plan through the engine file's plan table (Postgres: [Reading a plan for tune](../engines/postgres.md#reading-a-plan-for-tune)). Compare estimated and actual rows first.

- Label every claim **from plan** or **from code**.
- Crown the cause that owns the most time or buffers. Name runners-up in one line each.

**Done when** every node that takes 10% or more of the total time is matched to a table row or stated unmatched, and one cause is crowned with its label.

### 4. Propose one change

Propose one change for the crowned cause, taken from the plan table or a batched load for an N+1.

When the change is an index:

- Write the index per [Indexes earn their write cost](../SKILL.md#indexes-earn-their-write-cost) and the engine's [index types](../engines/postgres.md#index-types).
- When the target has the `hypopg` extension, write a check for the user to run where the slow plan came from: `SELECT * FROM hypopg_create_index('CREATE INDEX ON …');`, then `EXPLAIN <query>;` without `ANALYZE`.
- The index ships through [migrate](migrate.md) **write**, with `CONCURRENTLY` and a `lock_timeout` per [Concurrent index builds](../engines/postgres.md#concurrent-index-builds). `tune` writes no migration.

**Done when** exactly one change is written in full, and an index change carries its user-run check or states that `hypopg` is absent.

### 5. Report in chat

```
Query: <SQL>  (from <file:line>)
Baseline plan: <the nodes that matter, quoted from the pasted plan>
Diagnosis: <cause> (from plan | from code)
Change: <the one change, in full>
Check: <the command the user runs, and the number that should drop>
```

The "after" plan comes from the user's run, never from dbkit.

**Done when** the report has all five fields and no file has changed.

### 6. Hand off

**What changed.** State "no file changed" and the evidence used: a production plan, a local plan (shape only), or code.

**Where it landed.** The report is in chat. Give `file:line` for the query.

**Next.** With no plan, run the `EXPLAIN` command and paste the output. Otherwise, ship the change; an index goes through `dbkit migrate` write. After the deploy, run the check again and compare with the baseline.
