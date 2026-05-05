# PostgreSQL Interview Q&A — Basic to Advanced

**Purpose:** Practical PostgreSQL knowledge for interviews and daily work. Each topic has a clear question, a plain-language answer, and a runnable example.

---

## Table of Contents

1. PostgreSQL Basics
2. MVCC and Vacuum
3. Indexes — Postgres Specifics
4. JSON and JSONB
5. Transactions and Isolation
6. Query Optimization
7. Replication and HA
8. Advanced Features
9. Operational Concerns

---

## 1. PostgreSQL Basics

## Q1. What is PostgreSQL?

**Answer:**

PostgreSQL is an open-source object-relational database known for strong standards compliance, advanced features, and extensibility. It is fully ACID-compliant and ships with built-in support for JSONB, full-text search, GIS extensions, partitioning, foreign data wrappers, custom data types, and much more.

```sql
CREATE DATABASE shop;
\c shop

CREATE TABLE products (
  id    BIGSERIAL PRIMARY KEY,
  name  TEXT NOT NULL,
  price NUMERIC(10, 2) NOT NULL
);
```

## Q2. What's new in recent PostgreSQL versions?

**Answer:**

- 15: MERGE statement, more parallelism, logical replication improvements.
- 16: parallel hash join, logical replication from a standby, faster `pg_dump`.
- 17: improved VACUUM, MERGE supports more operations, JSON_TABLE function.

In an interview, mention you keep an eye on each major release because Postgres ships meaningful improvements yearly.

## Q3. What data types does PostgreSQL offer beyond the basics?

**Answer:**

PostgreSQL has the richest built-in type system of any major OLTP database.

| Type | Purpose |
|------|---------|
| `SERIAL` / `BIGSERIAL` | Auto-incrementing integer (modern code uses `IDENTITY`) |
| `UUID` | 16-byte globally unique IDs |
| `JSONB` | Binary JSON, indexable |
| `ARRAY` | Native arrays of any type |
| `HSTORE` | Key-value column |
| `INET` / `CIDR` | IP addresses |
| `TSVECTOR` / `TSQUERY` | Full-text search |
| `RANGE` (`int4range`, `tstzrange`) | Range of values |
| `INTERVAL` | Time intervals |
| `ENUM` | Enumerated type |
| `DOMAIN` | Constrained type |

```sql
CREATE TABLE bookings (
  id          BIGSERIAL PRIMARY KEY,
  guest_email TEXT NOT NULL,
  stay        TSTZRANGE NOT NULL,
  tags        TEXT[] DEFAULT '{}',
  metadata    JSONB DEFAULT '{}'::jsonb
);
```

## Q4. What is the difference between TIMESTAMP and TIMESTAMPTZ?

**Answer:**

- `TIMESTAMP` stores a date and time without any timezone information.
- `TIMESTAMPTZ` stores the value as UTC and converts it to the session's timezone when displayed.

Almost always use TIMESTAMPTZ. It avoids time-zone bugs in distributed systems.

```sql
CREATE TABLE events (
  id         BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Storing 2025-01-01 12:00:00+05:30 saves it as UTC internally
INSERT INTO events DEFAULT VALUES;
SELECT created_at AT TIME ZONE 'America/New_York' FROM events;
```

## Q5. What is the difference between SERIAL and IDENTITY?

**Answer:**

- `SERIAL` is the older syntax. It silently creates a sequence behind the column.
- `IDENTITY` (Postgres 10+) is the SQL-standard approach. It's cleaner and supports `GENERATED ALWAYS` to prevent manual inserts into the column.

```sql
-- Old style
CREATE TABLE old_users (
  id   SERIAL PRIMARY KEY,
  name TEXT
);

-- Modern style
CREATE TABLE users (
  id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT
);
```

---

## 2. MVCC and Vacuum

## Q6. What is MVCC in PostgreSQL?

**Answer:**

MVCC (Multi-Version Concurrency Control) lets readers and writers work without blocking each other. Each row has hidden columns `xmin` and `xmax` that track which transactions can see it. When you UPDATE a row, the old version stays in place (with `xmax` set), and a new version is inserted. Each transaction sees a consistent snapshot of the database.

The downside: dead row versions accumulate over time and must be cleaned up by VACUUM.

## Q7. What is VACUUM?

**Answer:**

VACUUM reclaims space from dead row versions and refreshes statistics. PostgreSQL runs an autovacuum daemon in the background that handles this for most tables, but you can also run it manually.

```sql
VACUUM;                  -- light, marks space reusable
VACUUM (ANALYZE) orders; -- + refresh planner stats
VACUUM FULL orders;      -- rewrites the table; takes an exclusive lock
```

`VACUUM FULL` is expensive and locks the table — avoid it on a live system. Use `pg_repack` or `CLUSTER` for online alternatives.

## Q8. What is bloat?

**Answer:**

Bloat is wasted space inside a table or index from accumulated dead row versions. Heavy UPDATE workloads, long-running transactions blocking VACUUM, or under-tuned autovacuum all cause bloat. Symptoms include tables that grow much faster than the actual data and queries that slow down over time.

```sql
-- Quick bloat check (approximation)
SELECT relname,
       pg_size_pretty(pg_relation_size(oid)) AS size,
       n_dead_tup, n_live_tup
FROM pg_class
JOIN pg_stat_user_tables ON oid = relid
ORDER BY n_dead_tup DESC
LIMIT 10;
```

Fixes include `pg_repack` (online), `VACUUM FULL` (offline), or `CLUSTER` (rewrites by index order).

## Q9. What is transaction wraparound?

**Answer:**

PostgreSQL uses 32-bit transaction IDs that eventually wrap around. The system avoids data loss by "freezing" old rows. If autovacuum cannot keep up, the database refuses new connections to protect data integrity.

You should never see this with healthy autovacuum. Monitor `age(datfrozenxid)` per database.

```sql
SELECT datname, age(datfrozenxid) AS xid_age
FROM pg_database
ORDER BY xid_age DESC;
```

## Q10. How do long-running transactions interact with VACUUM?

**Answer:**

A long-running transaction holds an old snapshot. VACUUM cannot remove dead row versions newer than that snapshot. Bloat accumulates while the transaction runs.

Avoid transactions that run for minutes or hours. Look for `idle in transaction` sessions:

```sql
SELECT pid, query, state, age(now(), xact_start) AS xact_age
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY xact_age DESC;
```

---

## 3. Indexes — Postgres Specifics

## Q11. What index types does PostgreSQL support?

**Answer:**

| Type | Use case |
|------|----------|
| B-tree (default) | Equality, range, sort |
| Hash | Equality only |
| GIN | Full-text, JSONB, arrays |
| GiST | Geometric, full-text, range types |
| SP-GiST | Specialized partition (quad-tree, etc.) |
| BRIN | Huge tables with naturally ordered data |
| Bloom | Multi-column equality (extension) |

```sql
CREATE INDEX idx_users_email ON users(email);                  -- B-tree
CREATE INDEX idx_orders_data ON orders USING GIN (data);       -- JSONB
CREATE INDEX idx_logs_time   ON logs USING BRIN (created_at);  -- BRIN
```

## Q12. When should you use GIN vs GiST?

**Answer:**

- GIN — faster reads, slower writes, larger size. Best for static or read-heavy data, full-text search, and JSONB.
- GiST — balanced, smaller index, slower reads. Best for geometric data and range types.

For JSONB and full-text on read-heavy tables, GIN is the default choice.

## Q13. What is BRIN and when do you use it?

**Answer:**

BRIN (Block Range Index) stores summary information (like min/max) for ranges of pages. It is tiny in size — sometimes a few kilobytes for a 100M-row table.

BRIN is great for huge tables where the indexed column is naturally ordered, such as time-series data with monotonically increasing `created_at`.

```sql
CREATE INDEX idx_events_brin ON events USING BRIN (created_at);
```

## Q14. What is a partial index?

**Answer:**

A partial index covers only the rows that satisfy a WHERE clause. It is smaller and faster than a full index when most queries filter the same way.

```sql
-- Index only active users
CREATE INDEX idx_users_email_active
  ON users(email)
  WHERE active = TRUE;

-- This query uses the partial index
SELECT * FROM users WHERE email = 'a@b.com' AND active = TRUE;
```

## Q15. What is an expression (functional) index?

**Answer:**

An expression index stores the result of an expression instead of a raw column value. This lets queries that use the same expression use the index.

```sql
-- Search by lowercase email
CREATE INDEX idx_users_email_lower ON users(LOWER(email));

-- Now this query can use the index
SELECT * FROM users WHERE LOWER(email) = LOWER('Alice@Example.com');
```

## Q16. What is `CREATE INDEX CONCURRENTLY`?

**Answer:**

A regular `CREATE INDEX` takes an exclusive lock on the table — fine in development, painful in production. `CREATE INDEX CONCURRENTLY` builds the index without blocking writes. It is slower (it scans the table multiple times) but always preferred for production.

```sql
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders(user_id);
```

## Q17. How do you find unused indexes?

**Answer:**

Query `pg_stat_user_indexes`. Indexes with zero scans over a long period are candidates for removal — but check first that they don't enforce a unique constraint.

```sql
SELECT schemaname, relname, indexrelname,
       idx_scan, idx_tup_read,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
```

---

## 4. JSON and JSONB

## Q18. What is the difference between JSON and JSONB?

**Answer:**

| JSON | JSONB |
|------|-------|
| Stored as text | Stored as binary |
| Preserves whitespace, key order, duplicates | Normalized |
| Slower to query | Faster to query |
| Cannot be GIN-indexed on contents | GIN-indexable |

Use JSONB unless you need to preserve the exact original text byte-for-byte.

```sql
CREATE TABLE products (
  id    BIGSERIAL PRIMARY KEY,
  attrs JSONB NOT NULL DEFAULT '{}'::jsonb
);
```

## Q19. What are the JSONB query operators?

**Answer:**

```sql
-- Get a key
SELECT data->'name' FROM users;       -- returns JSONB
SELECT data->>'name' FROM users;      -- returns TEXT

-- Get a deep path
SELECT data#>'{address,city}' FROM users;
SELECT data#>>'{address,city}' FROM users;  -- as text

-- Containment (uses GIN index)
SELECT * FROM products WHERE attrs @> '{"color":"red"}';

-- Existence of a key
SELECT * FROM products WHERE attrs ? 'discount';

-- Existence of any/all keys
SELECT * FROM products WHERE attrs ?| ARRAY['discount','sale'];
SELECT * FROM products WHERE attrs ?& ARRAY['size','color'];
```

## Q20. How do you index JSONB?

**Answer:**

A general GIN index supports `@>`, `?`, `?|`, and `?&`. For lookups on a specific path, an expression index is smaller and faster.

```sql
-- General — supports many operators
CREATE INDEX idx_products_attrs ON products USING GIN (attrs);

-- Specific path
CREATE INDEX idx_products_color ON products ((attrs->>'color'));

-- jsonb_path_ops — smaller, supports only @>
CREATE INDEX idx_products_attrs_path ON products USING GIN (attrs jsonb_path_ops);
```

## Q21. When should you NOT use JSONB?

**Answer:**

- The data has a consistent structure — use real columns instead.
- You need foreign keys.
- You need strong typing.
- You frequently update one nested field — every update rewrites the whole document.

JSONB is great for variable schemas (user preferences, product attributes, audit metadata). It is a poor substitute for proper relational design.

---

## 5. Transactions and Isolation

## Q22. What is the default isolation level?

**Answer:**

READ COMMITTED. Each statement sees a snapshot of committed data taken at statement start. You can switch to stricter levels per transaction.

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
-- ...
COMMIT;
```

## Q23. What is special about Postgres SERIALIZABLE?

**Answer:**

Postgres uses Serializable Snapshot Isolation (SSI). Instead of locking, the server tracks read/write dependencies and aborts a transaction if it would violate serializability. The application must be ready to retry on error 40001.

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
-- ...
COMMIT;
-- Possible error: ERROR: could not serialize access due to concurrent update
```

## Q24. How does `SELECT FOR UPDATE` work?

**Answer:**

It locks the matching rows so other transactions cannot modify them until your transaction ends. There are several variants for different lock strengths:

- `FOR UPDATE` — strongest; blocks UPDATE, DELETE, and FK writes.
- `FOR NO KEY UPDATE` — allows foreign key references.
- `FOR SHARE` — shared lock; readers OK, writers wait.
- `FOR KEY SHARE` — weakest; only blocks DELETE / key UPDATE.

```sql
BEGIN;
SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
COMMIT;
```

## Q25. What is an advisory lock?

**Answer:**

An application-defined lock keyed by an integer (or two integers). PostgreSQL doesn't enforce any meaning — your code decides what the key represents. Useful when you need to coordinate work across processes that don't share rows.

```sql
SELECT pg_advisory_lock(12345);            -- session lock
SELECT pg_advisory_xact_lock(12345);       -- released at commit
SELECT pg_try_advisory_lock(12345);        -- non-blocking
SELECT pg_advisory_unlock(12345);
```

Common uses include "only one cron job runs at a time" or "process this user record exclusively".

## Q26. How do you handle deadlocks?

**Answer:**

PostgreSQL detects deadlocks and aborts one transaction with error code `40P01`. The application must retry. Prevent them by acquiring locks in a deterministic order — for example, always update rows by primary key ascending.

---

## 6. Query Optimization

## Q27. What is the difference between EXPLAIN and EXPLAIN ANALYZE?

**Answer:**

- `EXPLAIN` shows the plan without running the query.
- `EXPLAIN ANALYZE` actually executes the query and reports real timings.
- `EXPLAIN (ANALYZE, BUFFERS)` also shows buffer cache hits and misses.

```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 123;
```

Output looks like:

```
Index Scan using idx_orders_user_id on orders
  (cost=0.43..8.45 rows=1 width=24)
  (actual time=0.045..0.046 rows=1 loops=1)
  Index Cond: (user_id = 123)
Planning Time: 0.150 ms
Execution Time: 0.073 ms
```

## Q28. How do you read a query plan?

**Answer:**

Look at the access methods and join algorithms.

- Seq Scan — full table scan; bad on large tables with selective filters.
- Index Scan — used an index, then fetched the row; usually good.
- Index Only Scan — best, no row lookup.
- Bitmap Heap Scan + Bitmap Index Scan — multiple matches batched together.
- Nested Loop — for small inner sides.
- Hash Join — builds a hash table on one side; good for medium-large sets.
- Merge Join — for sorted inputs.

If the actual row count differs hugely from the estimate, statistics are stale — run ANALYZE.

## Q29. What is `pg_stat_statements`?

**Answer:**

An extension that tracks aggregated execution statistics for every distinct query. It is the most important Postgres performance tool.

```sql
CREATE EXTENSION pg_stat_statements;

-- Top 10 queries by total time spent
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

A frequently-run "fast" query may use more total time than a single slow one.

## Q30. How do you tune `work_mem`?

**Answer:**

`work_mem` is the memory available per query operation (sort, hash). The default is 4 MB, often too small for analytical queries.

```sql
-- Per session, just for this query
SET work_mem = '256MB';
SELECT ...;
```

Don't set it globally too high — every connection times every operation can multiply memory use.

## Q31. How do you tune `shared_buffers`?

**Answer:**

`shared_buffers` is the memory PostgreSQL uses for caching data pages. The common starting point is 25% of system RAM. Postgres relies on the OS page cache too, so setting `shared_buffers` very large isn't always better.

```ini
shared_buffers = 4GB    # on a 16 GB machine
```

## Q32. What is `effective_cache_size`?

**Answer:**

A planner hint — an estimate of how much memory is available across PostgreSQL's `shared_buffers` plus the OS file cache. It does not allocate memory; it influences whether the planner picks an index scan vs a sequential scan.

A common setting is 50% to 70% of total RAM.

```ini
effective_cache_size = 12GB
```

---

## 7. Replication and HA

## Q33. What replication types does PostgreSQL support?

**Answer:**

| Type | Description |
|------|-------------|
| Streaming (physical) | Primary streams its WAL; replica is a byte-identical copy. |
| Logical | Stream specific tables; schema can differ. |
| Synchronous | Primary waits for replica acknowledgment before commit. |
| Asynchronous | Default; lower latency, replica may lag. |
| Cascading | Replica replicates from another replica. |

## Q34. How do you set up streaming replication?

**Answer:**

On the primary:

```ini
wal_level = replica
max_wal_senders = 10
```

On the replica:

```ini
primary_conninfo = 'host=primary user=replication'
```

Use `pg_basebackup` to clone the primary to the replica:

```bash
pg_basebackup -h primary -D /var/lib/postgresql/17/main -U replication -W -P -R
```

For automatic failover, use Patroni, repmgr, or a managed service (RDS, Aurora, Cloud SQL).

## Q35. What is logical replication?

**Answer:**

Logical replication streams row-level changes for selected tables, allowing the replica to have a different schema or even a different version of Postgres. It is excellent for zero-downtime upgrades and partial replication.

```sql
-- On the primary
CREATE PUBLICATION my_pub FOR TABLE users, orders;

-- On the replica
CREATE SUBSCRIPTION my_sub
  CONNECTION 'host=primary dbname=shop user=replicator'
  PUBLICATION my_pub;
```

## Q36. How do you fail over to a replica?

**Answer:**

1. Promote the replica with `pg_ctl promote` or `SELECT pg_promote();`.
2. Repoint application traffic to the new primary.
3. The old primary must be re-synced (or rebuilt) to follow the new primary.

Tools like Patroni, Stolon, or repmgr automate this. Cloud-managed services do it transparently.

## Q37. How do you measure replication lag?

**Answer:**

```sql
-- On the replica, time-based lag
SELECT now() - pg_last_xact_replay_timestamp() AS lag;

-- Byte-based lag (on the primary)
SELECT client_addr,
       pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_bytes
FROM pg_stat_replication;
```

Alert if lag exceeds your tolerance (often a few seconds).

---

## 8. Advanced Features

## Q38. What is partitioning?

**Answer:**

Partitioning splits one logical table into many physical partitions. Queries that filter on the partition key only scan relevant partitions, and old partitions can be dropped instantly.

```sql
CREATE TABLE events (
  id         BIGSERIAL,
  created_at TIMESTAMPTZ NOT NULL,
  data       JSONB
) PARTITION BY RANGE (created_at);

CREATE TABLE events_2025_01 PARTITION OF events
  FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE TABLE events_2025_02 PARTITION OF events
  FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Drop an old partition in milliseconds
DROP TABLE events_2025_01;
```

Strategies: RANGE (by date or numeric range), LIST (by discrete values), HASH (even distribution).

## Q39. What is a materialized view?

**Answer:**

A view whose result is stored on disk. Reads are fast, but the data is only fresh as of the last refresh.

```sql
CREATE MATERIALIZED VIEW daily_revenue AS
SELECT DATE(created_at) AS day, SUM(amount) AS revenue
FROM orders
GROUP BY DATE(created_at);

-- Refresh
REFRESH MATERIALIZED VIEW daily_revenue;

-- Refresh without locking readers (needs a unique index)
REFRESH MATERIALIZED VIEW CONCURRENTLY daily_revenue;
```

## Q40. What is a Foreign Data Wrapper (FDW)?

**Answer:**

An FDW lets PostgreSQL query external data sources as if they were local tables.

```sql
CREATE EXTENSION postgres_fdw;

CREATE SERVER remote_db FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host 'other-host', dbname 'shop');

CREATE USER MAPPING FOR current_user SERVER remote_db
  OPTIONS (user 'app', password 'secret');

CREATE FOREIGN TABLE remote_users (
  id    BIGINT,
  email TEXT
) SERVER remote_db OPTIONS (table_name 'users');

SELECT * FROM remote_users WHERE id = 123;
```

Other FDWs include `file_fdw`, `mongodb_fdw`, and `mysql_fdw`.

## Q41. What is Row Level Security (RLS)?

**Answer:**

RLS automatically filters rows based on the connected user. It is a clean way to implement multi-tenant isolation.

```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY orders_user_isolation ON orders
  FOR ALL
  TO app_user
  USING (user_id = current_setting('app.current_user_id')::INT);

-- Application sets the variable on each connection
SET app.current_user_id = '42';

-- Now this query only returns user 42's orders
SELECT * FROM orders;
```

## Q42. What is `LISTEN/NOTIFY`?

**Answer:**

A built-in publish/subscribe mechanism. Useful for cache invalidation and lightweight notifications. Not durable — for guaranteed delivery, use a real queue.

```sql
-- Listener (in psql or any client)
LISTEN order_created;

-- Sender
NOTIFY order_created, '{"id": 123}';
```

## Q43. How do CTEs behave in modern Postgres?

**Answer:**

Before version 12, CTEs were always materialized — the optimizer could not push predicates into them. Since 12, non-recursive CTEs are inlined by default. You can override with hints.

```sql
WITH cheap AS NOT MATERIALIZED (
  SELECT * FROM products WHERE price < 50
)
SELECT * FROM cheap WHERE name LIKE 'A%';

WITH expensive AS MATERIALIZED (
  SELECT * FROM big_table
)
SELECT * FROM expensive;
```

## Q44. What is `INSERT ... ON CONFLICT` (UPSERT)?

**Answer:**

Insert a row, but if a unique constraint conflicts, update the existing row (or do nothing). Essential for idempotent ingestion.

```sql
INSERT INTO users (email, name)
VALUES ('a@a.com', 'Alice')
ON CONFLICT (email) DO UPDATE
SET name = EXCLUDED.name;

-- Or skip on conflict
INSERT INTO users (email, name)
VALUES ('a@a.com', 'Alice')
ON CONFLICT (email) DO NOTHING;
```

`EXCLUDED` references the row that would have been inserted.

## Q45. What does the RETURNING clause do?

**Answer:**

It returns data from a modifying statement in a single round trip — no separate SELECT needed.

```sql
INSERT INTO users (email) VALUES ('a@a.com')
RETURNING id, created_at;

UPDATE orders SET status = 'shipped' WHERE id = 5
RETURNING *;

DELETE FROM logs WHERE created_at < '2024-01-01'
RETURNING id;
```

---

## 9. Operational Concerns

## Q46. How do you back up PostgreSQL?

**Answer:**

| Tool | Type | Notes |
|------|------|-------|
| `pg_dump` | Logical, single DB | Portable; slow on large DBs |
| `pg_dumpall` | Logical, all DBs + roles | Includes globals |
| `pg_basebackup` | Physical, base for replication | Whole-cluster |
| WAL archiving + base backup | Physical, supports PITR | Production-grade |
| Cloud snapshots | Physical, fast | Provider-managed |

```bash
pg_dump -Fc -h host -U user shop > shop.dump
pg_restore -d shop shop.dump
```

For point-in-time recovery, use `pg_basebackup` plus continuous WAL archiving via tools like `pgBackRest` or `WAL-G`.

## Q47. What metrics should you monitor?

**Answer:**

- Active connections vs `max_connections`.
- Long-running queries.
- Replication lag.
- Cache hit ratio (`pg_stat_database`).
- Bloat in tables and indexes.
- Autovacuum activity.
- Disk usage and WAL accumulation.
- Top queries from `pg_stat_statements`.
- Lock waits (`pg_locks`, `pg_stat_activity`).

## Q48. What does `pg_stat_activity` show?

**Answer:**

It is a snapshot of every backend session — the current query, state, and timing. Useful for diagnosing live problems.

```sql
-- Long-running active queries
SELECT pid, query, state, age(now(), query_start) AS runtime
FROM pg_stat_activity
WHERE state = 'active'
  AND query_start < now() - interval '1 minute'
ORDER BY runtime DESC;

-- Idle-in-transaction sessions (a common cause of bloat)
SELECT pid, query, age(now(), xact_start) AS xact_age
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY xact_age DESC;
```

## Q49. How do you cancel or kill a query?

**Answer:**

```sql
-- Cancel a running query (keeps the connection)
SELECT pg_cancel_backend(12345);

-- Force terminate (closes the connection)
SELECT pg_terminate_backend(12345);
```

## Q50. How does connection pooling work for PostgreSQL?

**Answer:**

Postgres has noticeable per-connection overhead, so a pooler is recommended once you go past around 100 concurrent connections.

- PgBouncer — lightweight; transaction-pooling mode is the most efficient.
- Pgpool-II — more features but more complex.
- Application-level pools (pg-pool, HikariCP, pgx) — fine for small scale.

```ini
# pgbouncer.ini
[databases]
shop = host=localhost port=5432 dbname=shop

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
```

## Q51. What is a PostgreSQL extension?

**Answer:**

An extension adds functionality. Many features Postgres is famous for ship as extensions you load with `CREATE EXTENSION`.

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_trgm;        -- trigram fuzzy text matching
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";    -- UUID generation
CREATE EXTENSION IF NOT EXISTS postgis;        -- geospatial
CREATE EXTENSION IF NOT EXISTS pgcrypto;       -- crypto functions
CREATE EXTENSION IF NOT EXISTS timescaledb;    -- time-series
```

## Q52. How do you do fuzzy text search?

**Answer:**

Use the `pg_trgm` extension with a GIN trigram index. This makes `LIKE '%foo%'` and similarity searches fast.

```sql
CREATE EXTENSION pg_trgm;

CREATE INDEX idx_products_name_trgm
ON products USING GIN (name gin_trgm_ops);

-- Fast LIKE with leading wildcard
SELECT * FROM products WHERE name ILIKE '%coffee%';

-- Similarity search
SELECT name, similarity(name, 'cofee') AS sim
FROM products
WHERE name % 'cofee'
ORDER BY sim DESC
LIMIT 10;
```

## Q53. How do you do full-text search?

**Answer:**

Use `tsvector` and `tsquery` with a GIN index.

```sql
ALTER TABLE articles ADD COLUMN search TSVECTOR
  GENERATED ALWAYS AS (to_tsvector('english', title || ' ' || body)) STORED;

CREATE INDEX idx_articles_search ON articles USING GIN (search);

SELECT id, title
FROM articles
WHERE search @@ plainto_tsquery('english', 'machine learning');
```

## Q54. How do you safely add a NOT NULL column to a huge table?

**Answer:**

`ALTER TABLE big ADD COLUMN x TEXT NOT NULL DEFAULT 'foo'` rewrites the table on older versions. Modern Postgres handles a constant default without rewrite, but for safety on huge tables split it into steps:

```sql
-- 1. Add the column nullable
ALTER TABLE big ADD COLUMN new_col TEXT;

-- 2. Backfill in batches (loop in your app code)
UPDATE big SET new_col = '...' WHERE id BETWEEN 1 AND 10000;

-- 3. Once backfill is complete, enforce NOT NULL
ALTER TABLE big ALTER COLUMN new_col SET NOT NULL;
```

## Q55. How do you free up disk used by WAL?

**Answer:**

Disk fills up when WAL accumulates because a replica or replication slot is behind or inactive. Investigate replication slots:

```sql
SELECT slot_name, active,
       pg_size_pretty(
         pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
       ) AS retained
FROM pg_replication_slots;
```

If a slot is inactive and not needed, drop it:

```sql
SELECT pg_drop_replication_slot('old_slot');
```

If the slot belongs to a real replica that is behind, the right fix is to repair or rebuild the replica.
