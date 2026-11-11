# dbkit: MySQL

Read this file once [Stack detection](../SKILL.md#stack-detection) finds MySQL or MariaDB. It holds the gotchas behind [the schema standard](../SKILL.md#the-schema-standard), not server tuning. Check each version limit against the detected server; MariaDB differs.

## Locks per DDL statement

- InnoDB runs online DDL as `INSTANT`, `INPLACE`, or `COPY`. Write `ALGORITHM=INSTANT` (or `ALGORITHM=INPLACE, LOCK=NONE`) on each `ALTER TABLE`, so the statement fails instead of silently falling back to a blocking table copy.
- When neither applies to a large table, use `gh-ost` or `pt-online-schema-change`.
- DDL is not transactional: a failed migration with several statements leaves a half-applied schema. Keep one DDL statement per migration where the tool allows it.

## Timeouts and the lock queue

Every DDL takes a metadata lock, even an `INSTANT` one. A DDL that waits behind one open transaction blocks every later query on the table. The default `lock_wait_timeout` is one year, so open each migration with `SET SESSION lock_wait_timeout = 5;` and retry on failure.

## Types and keys

- The primary key is the clustered index: every secondary index carries a copy of it, and inserts land in its order. Use a short, increasing key; a random UUIDv4 key fragments the table and bloats each index. Store a time-ordered UUID as `BINARY(16)`.
- Use `utf8mb4`. `utf8` is `utf8mb3`, which rejects emoji.
- `CHECK` is enforced from 8.0.16 only; earlier versions parse it and ignore it.
- `TIMESTAMP` stores UTC but ends in 2038; `DATETIME` has no zone. Store UTC in `DATETIME` and name the column for it.
- No partial index and no `NULLS NOT DISTINCT`; a unique index allows many `NULL`s.

## Catalog queries for audit

InnoDB indexes each foreign key itself, so that check is not a finding. Read `information_schema.STATISTICS` for redundant prefixes. Unused indexes (`sys.schema_unused_indexes`) are **needs production stats**.

## Reading a plan for tune

Use `EXPLAIN ANALYZE` on 8.0.18 and later, and `EXPLAIN FORMAT=JSON` before that. Take slow-query evidence from `performance_schema.events_statements_summary_by_digest`, ranked by `SUM_TIMER_WAIT`.
