# dbkit: Postgres

It gives the Postgres facts behind [the schema standard](../SKILL.md#the-schema-standard); check each version limit against the detected major version.

## Locks per DDL statement

The lock decides the risk first, and table size decides it second. `ACCESS EXCLUSIVE` blocks every read and write on the table; `SHARE` blocks writes and allows reads; `SHARE UPDATE EXCLUSIVE` allows both.

| Statement | Lock | Cost | Safe path |
| --- | --- | --- | --- |
| `ADD COLUMN`, nullable, no default | `ACCESS EXCLUSIVE` | Catalog only, instant | Safe with a lock timeout |
| `ADD COLUMN … DEFAULT <constant>` | `ACCESS EXCLUSIVE` | Instant on PG 11+; rewrite before 11 | Safe with a lock timeout on 11+ |
| `ADD COLUMN … DEFAULT <volatile>` (`gen_random_uuid()`, `random()`, `clock_timestamp()`) | `ACCESS EXCLUSIVE` | Rewrites the table | Add nullable, set the default for new rows, backfill in batches |
| `ADD COLUMN … NOT NULL`, no default | `ACCESS EXCLUSIVE` | Fails on a table with rows | Add nullable or with a constant default |
| `ALTER COLUMN … SET NOT NULL` | `ACCESS EXCLUSIVE` | Scans the table under the lock | `ADD CONSTRAINT c CHECK (col IS NOT NULL) NOT VALID`, `VALIDATE CONSTRAINT c`, `SET NOT NULL` (PG 12+ skips the scan), drop `c` |
| `ADD CONSTRAINT … FOREIGN KEY` | `SHARE ROW EXCLUSIVE` on both tables | Scans the referencing table | Add it `NOT VALID`, then `VALIDATE CONSTRAINT` in a separate migration |
| `ADD CONSTRAINT … CHECK` | `ACCESS EXCLUSIVE` | Scans the table | Add it `NOT VALID`, then `VALIDATE CONSTRAINT` |
| `VALIDATE CONSTRAINT` | `SHARE UPDATE EXCLUSIVE` | Scans; reads and writes continue | Safe |
| `CREATE INDEX` | `SHARE` | Blocks writes for the whole build | `CREATE INDEX CONCURRENTLY` |
| `CREATE INDEX CONCURRENTLY` | `SHARE UPDATE EXCLUSIVE` | Two scans; waits for open transactions | Safe; see [Concurrent index builds](#concurrent-index-builds) |
| `DROP INDEX` | `ACCESS EXCLUSIVE` | Instant once the lock is held | `DROP INDEX CONCURRENTLY` |
| `ADD UNIQUE` or `ADD PRIMARY KEY` | `ACCESS EXCLUSIVE` | Builds an index under the lock | `CREATE UNIQUE INDEX CONCURRENTLY idx …`, then `ADD CONSTRAINT name UNIQUE USING INDEX idx` (or `PRIMARY KEY USING INDEX`) |
| `DROP COLUMN` | `ACCESS EXCLUSIVE` | Catalog only | Ship code that no longer reads the column first (contract step) |
| `RENAME COLUMN` or `RENAME TO` | `ACCESS EXCLUSIVE` | Catalog only; breaks running code | Expand, migrate, contract |
| `ALTER COLUMN … TYPE` | `ACCESS EXCLUSIVE` | Rewrites table and indexes, except `varchar(n)` to a larger `n` or `text` | New column, backfill, switch reads, drop the old one |
| `SET DEFAULT` or `DROP DEFAULT` | `ACCESS EXCLUSIVE` | Catalog only | Safe with a lock timeout |
| `ALTER TYPE … ADD VALUE` (enum) | `ACCESS EXCLUSIVE` on the type | Catalog only; the new value is unusable in the same transaction | Its own migration |

## Timeouts and the lock queue

Locks queue in order. An `ACCESS EXCLUSIVE` request that waits behind one long query blocks every later read and write on the table, so an instant `ADD COLUMN` becomes an outage as long as the slowest open transaction.

Open each migration that touches a live table with:

```sql
SET lock_timeout = '5s';
SET statement_timeout = '15min';
```

Inside a transaction, use `SET LOCAL`. A migration that hits the lock timeout fails cleanly and holds nothing; retry it a few times with a pause, and never raise the timeout instead. A concurrent index build can run long, so give that statement a `statement_timeout` of `0` or one that fits the build.

## Concurrent index builds

- `CREATE INDEX CONCURRENTLY`, `DROP INDEX CONCURRENTLY`, and `REINDEX … CONCURRENTLY` cannot run inside a transaction block. A migration tool that wraps each file in a transaction, or runs a multi-statement file as one implicit transaction, makes them fail; [orms.md](../orms.md) says how each tool runs one alone.
- A failed or cancelled concurrent build leaves an `INVALID` index. It serves no reads, still costs every write, and a rerun with `IF NOT EXISTS` skips it because the name exists. Find them with:

```sql
SELECT c.relname AS index_name, t.relname AS table_name
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
JOIN pg_class t ON t.oid = i.indrelid
WHERE NOT i.indisvalid;
```

- Recover with `DROP INDEX CONCURRENTLY name;` and build it again, or with `REINDEX INDEX CONCURRENTLY name;` on PG 12+.

## Batched backfill

Backfill after the schema change ships, one short transaction per range of primary keys:

```sql
UPDATE orders
SET total_cents = round(total * 100)
WHERE id >= :start AND id < :start + 5000
  AND total_cents IS NULL;
```

The runner steps `:start` across the id range, commits each batch, and pauses so replicas keep up. Where concurrent workers claim rows, pick each batch's ids with `FOR UPDATE SKIP LOCKED`. A migrator that runs a file in one transaction defeats batching, so a large backfill runs as a script outside it.

## Version limits

| Version | What it adds |
| --- | --- |
| PG 11 | Instant `ADD COLUMN` with a non-volatile default; foreign keys from a partitioned table; `COMMIT` inside a procedure |
| PG 12 | `REINDEX CONCURRENTLY`; `SET NOT NULL` skips its scan when a valid `CHECK (col IS NOT NULL)` exists; foreign keys that reference a partitioned table; `ALTER TYPE … ADD VALUE` inside a transaction block |
| PG 13 | `gen_random_uuid()` built in, with no extension |
| PG 14 | `DETACH PARTITION … CONCURRENTLY` |
| PG 15 | `UNIQUE NULLS NOT DISTINCT`, which allows one `NULL` |
| PG 18 | `uuidv7()` built in |

## Types to avoid

| Avoid | Use | Reason |
| --- | --- | --- |
| `timestamp` (without time zone) | `timestamptz` | Stores a wall-clock time with no zone |
| `timestamptz(0)` or any precision | `timestamptz` | Rounds; events can swap order |
| `timetz` | `timestamptz` | A zone without a date is meaningless |
| `money` | `numeric(p, s)` or integer minor units | Output follows `lc_monetary` |
| `char(n)`, `varchar(n)` | `text` with a `CHECK` on length | Same storage; shrinking `n` rewrites |
| `serial`, `bigserial` | `bigint GENERATED ALWAYS AS IDENTITY` | Standard; the column owns the sequence |
| `json` | `jsonb` | No GIN index; keeps raw text |

## Index types

Take the first row that fits the query:

| The query | Index |
| --- | --- |
| `=`, `<`, `>`, `BETWEEN`, `ORDER BY`, prefix `LIKE 'abc%'` | B-tree (the default) |
| Filters one hot subset (`WHERE status = 'active'`) | Partial B-tree with that `WHERE` |
| Filters on an expression (`lower(email)`) | Expression index; the query must use the same expression |
| Reads a few extra columns after the filter | Covering B-tree, `INCLUDE (col, …)`, for an index-only scan |
| `jsonb` containment, arrays, full-text search | GIN |
| Ranges, geometry, `EXCLUDE` constraints (no overlapping bookings) | GiST |
| A very large table in natural insert order (time series) | BRIN |

## Partitioning

- Partition only a table past about 100 million rows whose queries filter on one key, or whose retention drops data by that key. Below that, partitions add planning cost and gain nothing.
- `RANGE` suits time, `LIST` suits a small set of discrete values, `HASH` spreads a table with no natural key. Use declarative partitioning, never table inheritance.
- A query that does not filter on the partition key scans every partition.
- A primary key or unique constraint must include the partition key; no constraint is unique across partitions.
- Drop old data with `DETACH PARTITION` (concurrently on PG 14+) and `DROP TABLE`, never with a bulk `DELETE`.

## Catalog queries for audit

Foreign keys with no index whose leading columns cover them:

```sql
SELECT c.conrelid::regclass AS table_name, c.conname AS foreign_key
FROM pg_constraint c
WHERE c.contype = 'f'
  AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.conrelid
      AND (string_to_array(i.indkey::text, ' ')::int2[])[1:cardinality(c.conkey)] @> c.conkey
  );
```

Indexes with the same definition on one table:

```sql
SELECT indrelid::regclass AS table_name, array_agg(indexrelid::regclass) AS indexes
FROM pg_index
GROUP BY indrelid, indkey::text, indclass::text,
         coalesce(indexprs::text, ''), coalesce(indpred::text, '')
HAVING count(*) > 1;
```

Invalid indexes: the query in [Concurrent index builds](#concurrent-index-builds).

Unused indexes are **needs production stats**: dev counters say nothing about production, and each replica keeps its own. Give this query for the user to run on the primary and each replica:

```sql
SELECT s.relname AS table_name, s.indexrelname AS index_name, s.idx_scan,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size
FROM pg_stat_user_indexes s
JOIN pg_index i ON i.indexrelid = s.indexrelid
WHERE s.idx_scan = 0 AND NOT i.indisunique
ORDER BY pg_relation_size(s.indexrelid) DESC;
```

Table sizes and bloat are **needs production stats** the same way.

## Reading a plan for tune

Compare each node's estimated `rows` with its actual `rows` and `loops` first; most bad plans start with a bad estimate.

| Symptom in the plan | Likely cause | Change to propose |
| --- | --- | --- |
| `Seq Scan` on a large table with a high `Rows Removed by Filter` | No index the filter can use: none exists, the column is wrapped in a function, the types differ, or a `LIKE` starts with `%` | An index that matches the filter as written, or a query that matches the index |
| Estimated rows off from actual by 10× or more | Stale statistics, or correlated columns | `ANALYZE` the table; `CREATE STATISTICS` for the correlated columns |
| `Nested Loop` with a large `loops` count on the inner side | The inner join key has no index, or the outer estimate is low | An index on the inner join key; fix the estimate first |
| `Index Scan` followed by a large `Rows Removed by Filter` | The index covers only part of the filter | A composite index with the remaining equality column |
| `Sort Method: external merge`, or `Hash` with `Batches` above 1 | The operation spills to disk | An index in the `ORDER BY` order; else name `work_mem` as the cause for the operator |
| `Buffers: shared read` far above `shared hit` | The query touches more pages than the cache holds | A covering or narrower index; fewer columns selected |
| `Index Only Scan` with a high `Heap Fetches` | The visibility map lags | A vacuum on the table, named for the operator |
| A large `OFFSET` with most rows discarded | Offset pagination | Keyset pagination on an indexed column |

Server settings (`work_mem`, `shared_buffers`) are a cause to name, never a change dbkit proposes.
