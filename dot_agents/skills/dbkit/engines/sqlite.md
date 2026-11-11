# dbkit: SQLite

Read this file once [Stack detection](../SKILL.md#stack-detection) finds SQLite, libSQL, Turso, or Cloudflare D1. It holds the gotchas behind [the schema standard](../SKILL.md#the-schema-standard), not performance tuning. D1 and Turso have their own migration runners (`wrangler d1 migrations`, the Turso CLI); use the project's runner.

## Locks per DDL statement

- SQLite has one writer at a time. Any DDL, `CREATE INDEX` included, holds the write lock until commit, so a large index build stops all writes.
- `ALTER TABLE` supports only `RENAME TABLE`, `RENAME COLUMN`, `ADD COLUMN`, and `DROP COLUMN` (3.35+, with limits). An added column cannot be `PRIMARY KEY` or `UNIQUE`, and a `NOT NULL` one needs a non-null default.
- Any other change (a type, a constraint, a foreign key) uses the documented table rebuild, inside one transaction:
  1. Run `PRAGMA foreign_keys=OFF` before the transaction starts; the pragma is a no-op inside one.
  2. Create `new_<table>` with the target shape.
  3. Copy the rows with `INSERT INTO new_<table> SELECT …`.
  4. Drop the old table, then rename `new_<table>` to its name.
  5. Recreate the table's indexes, triggers, and views.
  6. Run `PRAGMA foreign_key_check` and commit only on an empty result.
  7. Run `PRAGMA foreign_keys=ON`.

## Types and constraints

- `PRAGMA foreign_keys` is off by default on each connection, so nothing enforces foreign keys until the driver setup turns them on for each connection.
- Columns have type affinity, so a `TEXT` value fits in an `INTEGER` column. Use `STRICT` tables (3.37+) to reject it.
- There is no decimal or date type. Store money as integer minor units, and a moment as ISO-8601 UTC text or integer epoch.
- Use WAL mode (`PRAGMA journal_mode=WAL`) so reads continue during a write.

## Catalog queries for audit

SQLite does not index foreign keys. Compare `pragma_foreign_key_list('<table>')` with `pragma_index_list` and `pragma_index_info`.

## Reading a plan for tune

Use `EXPLAIN QUERY PLAN`. A `SCAN <table>` on a large table means no usable index; `USE TEMP B-TREE FOR ORDER BY` means the sort has no index.
