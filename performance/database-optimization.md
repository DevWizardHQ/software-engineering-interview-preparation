# Database Optimization — Senior Engineer Guide

**Purpose:** Master database performance for senior backend interviews. Covers query optimization, indexing, schema design for scale, caching, partitioning, sharding, replication, server tuning, and operating tables with hundreds of millions of rows in production.

---

## Table of Contents

1. [Query Optimization Fundamentals](#query-optimization-fundamentals)
2. [Indexes — Deep Dive](#indexes--deep-dive)
3. [EXPLAIN and Query Plans](#explain-and-query-plans)
4. [Avoiding N+1 and JOIN Strategies](#avoiding-n1-and-join-strategies)
5. [Schema-Level Optimization](#schema-level-optimization)
6. [Write Optimization](#write-optimization)
7. [Read Optimization](#read-optimization)
8. [Caching Strategies](#caching-strategies)
9. [Connection Pooling](#connection-pooling)
10. [Transactions and Concurrency](#transactions-and-concurrency)
11. [Partitioning and Sharding](#partitioning-and-sharding)
12. [Handling 100M+ Row Tables](#handling-100m-row-tables)
13. [Replication and Read Scaling](#replication-and-read-scaling)
14. [Server Tuning (Postgres / MySQL)](#server-tuning-postgres--mysql)
15. [Monitoring and Slow Queries](#monitoring-and-slow-queries)
16. [OLTP vs OLAP](#oltp-vs-olap)
17. [Maintenance Impact](#maintenance-impact)
18. [Common Production Issues](#common-production-issues)

---

## Query Optimization Fundamentals

### Q1. What's the first rule of database optimization?

**Answer:** Measure first, then optimize. Use `EXPLAIN ANALYZE` (Postgres) or `EXPLAIN FORMAT=JSON` (MySQL) to find the actual cost. Don't guess.

A common mistake: adding indexes without confirming the query planner is doing a sequential scan. Sometimes a sequential scan on a small table is faster than an index scan.

---

### Q2. What are the typical latency budgets for a single query?

| Query type | Acceptable | Investigate | Critical |
|------------|-----------|-------------|----------|
| Primary key lookup | < 1 ms | > 5 ms | > 20 ms |
| Indexed read | < 5 ms | > 20 ms | > 100 ms |
| Aggregation (small) | < 50 ms | > 200 ms | > 1 s |
| Full table scan | depends on size | > 1 s | > 10 s |
| Reporting query | < 5 s | > 30 s | move to OLAP |

A user-facing API endpoint should not exceed ~200 ms total DB time at p95.

---

### Q3. Top 10 reasons a query is slow.

1. Missing or stale index
2. N+1 queries (in the application layer)
3. SELECT * on wide tables
4. Implicit type cast (`WHERE id = '42'` when `id` is int) preventing index use
5. `OR` across multiple columns instead of `UNION ALL`
6. `LIKE '%term%'` (leading wildcard, can't use B-tree)
7. Function applied to a column (`WHERE LOWER(email) = ...`) without expression index
8. Large `OFFSET` for pagination
9. Suboptimal join order chosen by planner due to bad statistics
10. Lock contention or buffer pool eviction

---

### Q4. What's the difference between a logical query plan and a physical plan?

- **Logical plan:** what the query says (relational algebra). Joins, projections, filters.
- **Physical plan:** how the engine will execute it — index scan vs seq scan, hash join vs nested loop, sort vs index-ordered, parallel workers.

The optimizer picks the physical plan based on statistics. Stale statistics produce bad plans. Run `ANALYZE` (Postgres) or `ANALYZE TABLE` (MySQL) after large data changes.

---

### Q5. Why does SELECT * hurt performance?

- Pulls more bytes over the wire
- Cannot use covering indexes (index-only scans)
- Breaks if column is added/removed
- Causes more memory in result buffers, more network I/O
- Forces TOAST/out-of-line storage reads in Postgres for large columns

Always select the columns you actually use.

---

## Indexes — Deep Dive

### Q6. What does a B-tree index actually do?

A B-tree is a balanced tree where each node holds sorted keys and pointers. Lookups, ranges, and ordered scans are O(log n). The leaves form a doubly linked list, which is why B-trees are great for `WHERE x BETWEEN ... AND ...` and `ORDER BY`.

Sizes:
- A typical index node holds ~100–300 keys.
- A 100 million row table has a tree depth of ~4–5 levels — which means 4–5 page reads to find a row.
- With buffer pool warm, those 4–5 reads are in memory.

---

### Q7. When is an index NOT used?

- Function applied to indexed column (`WHERE YEAR(created_at) = 2024`) — fix with expression index or rewrite to `WHERE created_at BETWEEN ...`
- Type mismatch (`WHERE varchar_id = 42`)
- Leading wildcard `LIKE '%foo'`
- Index has very low selectivity (planner thinks scan is cheaper)
- `OR` across columns from different indexes
- `IS NOT NULL` on a nullable column without partial index
- Negation (`!=`, `NOT IN`)
- Stale statistics after bulk load

---

### Q8. What's a covering index?

An index that includes all columns the query needs, allowing an index-only scan (no heap read).

```sql
-- Postgres
CREATE INDEX idx_orders_user_status_total
ON orders (user_id, status) INCLUDE (total_amount);

-- MySQL: just put them in the index
CREATE INDEX idx_orders_user_status_total
ON orders (user_id, status, total_amount);
```

Query that benefits:
```sql
SELECT total_amount FROM orders WHERE user_id = 42 AND status = 'shipped';
```

The downside: index gets larger, writes get slower.

---

### Q9. What is a partial index?

An index over a subset of rows.

```sql
CREATE INDEX idx_active_orders ON orders (created_at)
WHERE status = 'active';
```

Useful when:
- Most rows are "done/archived" but you query the small "active" set
- A column is sparsely populated (e.g., `deleted_at` for soft deletes — index `WHERE deleted_at IS NULL`)

Smaller index = faster scans, less memory.

---

### Q10. Composite index column order — how do you decide?

Rule of thumb: **equality columns first, range columns last, sort columns aligned with the order**.

For:
```sql
SELECT * FROM events
WHERE tenant_id = 7 AND type = 'click' AND created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;
```

Best index:
```sql
CREATE INDEX idx_events_tenant_type_created
ON events (tenant_id, type, created_at DESC);
```

Why: the planner can seek to `(7, 'click')` then walk the leaves backwards by `created_at` — no extra sort.

---

### Q11. What is index bloat and when does it matter?

In Postgres, dead tuples in indexes don't auto-shrink. After heavy update/delete cycles the index can be 3–5x larger than necessary, making scans slower and memory pressure higher.

Detect:
```sql
SELECT * FROM pg_stat_user_indexes;
-- And use pgstattuple extension for bloat estimates
```

Fix:
```sql
REINDEX INDEX CONCURRENTLY idx_name;
-- Or use pg_repack (no exclusive lock)
```

In MySQL InnoDB, index pages are merged on the fly more aggressively, but `OPTIMIZE TABLE` still helps after bulk deletes.

---

### Q12. Hash index vs B-tree?

| Aspect | B-tree | Hash |
|--------|--------|------|
| Equality | Yes | Yes (faster) |
| Range | Yes | No |
| Sorting | Yes | No |
| Storage | Slightly larger | Smaller |
| Postgres support | Default | Available (8.0+ persistent) |
| Real-world use | 99% of cases | Rare |

Use hash only for equality-only joins on large columns, otherwise default to B-tree.

---

### Q13. GIN vs GiST in Postgres?

- **GIN (Generalized Inverted Index):** full-text search, JSONB key lookups, array contains. Slower writes, fast reads.
- **GiST (Generalized Search Tree):** geospatial, range types, fuzzy matching. Faster writes, slower reads than GIN.

```sql
-- JSONB
CREATE INDEX idx_payload_gin ON events USING GIN (payload);

-- Full-text
CREATE INDEX idx_doc_fts ON documents USING GIN (to_tsvector('english', body));

-- Geospatial
CREATE INDEX idx_location ON places USING GIST (location);
```

---

### Q14. Why too many indexes is bad.

Each write must update every index. Eight indexes on a hot table can make inserts 5x slower. Also more disk, more buffer pool pressure, more vacuum/analyze cost.

**Audit unused indexes:**
```sql
-- Postgres
SELECT schemaname, relname, indexrelname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
```

If an index has zero scans for a month under representative load, drop it.

---

## EXPLAIN and Query Plans

### Q15. Reading a Postgres EXPLAIN ANALYZE output.

Key fields:
- **cost=...:** estimated cost (start..total) in arbitrary units
- **rows=...:** estimated row count
- **actual time=...:** real time (start..total) in ms
- **actual rows=...:** real row count
- **Buffers: shared hit=N read=M:** cache hits vs disk reads

Watch for:
- Big gap between estimated and actual rows → bad statistics → run `ANALYZE`
- `Seq Scan` on a large table → likely missing index
- `Hash Join` with small table built into hash → usually fine
- `Nested Loop` over many rows → may be a problem
- `Sort` with `Disk:` → `work_mem` too low

---

### Q16. Common Postgres plan node types.

| Node | When | Note |
|------|------|------|
| Seq Scan | Reads whole table | OK for small tables, bad for large |
| Index Scan | Uses index then heap | Most common indexed path |
| Index Only Scan | Uses index, skips heap | Best — needs covering index + visibility map |
| Bitmap Index Scan | Multiple indexes combined | Postgres-specific |
| Nested Loop | For each outer, scan inner | Good for small outer |
| Hash Join | Build hash on one side | Good for unsorted equi-join |
| Merge Join | Both sides sorted | Good with index-ordered input |
| Sort | Explicit sort | Avoid by aligning index with ORDER BY |
| Aggregate / HashAggregate | GROUP BY | HashAggregate is usually faster |

---

### Q17. MySQL EXPLAIN — what to focus on?

Key columns:
- **type:** `const` < `eq_ref` < `ref` < `range` < `index` < `ALL` (worst)
- **key:** which index was actually picked
- **rows:** estimated rows scanned
- **Extra:** `Using index` (covering), `Using filesort`, `Using temporary`

Goal: avoid `ALL`, avoid `Using filesort` on large data, avoid `Using temporary`.

```sql
EXPLAIN FORMAT=JSON SELECT ...;
```

The JSON output shows `cost_info` and `used_columns`.

---

## Avoiding N+1 and JOIN Strategies

### Q18. What is N+1 and how do you detect it?

For each parent row, the ORM fires a separate child query. 1 query for parents + N for children = N+1.

**Detection:**
- Application logs show repeated similar queries
- Laravel: `DB::listen()` count or Telescope
- Rails: `bullet` gem
- Node: enable Sequelize/Prisma logging
- APM: Datadog / New Relic group similar queries

**Fix:**
- Eager loading: `User.find(...).preload(:orders)` (Rails), `User::with('orders')` (Laravel), `include` (Prisma)
- Or a single JOIN with mapped result

---

### Q19. JOIN strategies — when to pick which?

| Strategy | Use when | Cost |
|----------|----------|------|
| Nested Loop | Outer is small, inner has index | O(N × log M) |
| Hash Join | Both unsorted, equi-join | O(N + M), needs memory |
| Merge Join | Both pre-sorted | O(N + M) |
| Broadcast Join (analytical) | One side fits in memory | Distributed only |

The planner picks based on stats. Force a different plan with hints (MySQL: `STRAIGHT_JOIN`, Postgres: `pg_hint_plan` extension or rewrite query).

---

### Q20. When should you denormalize joins?

When a join is on the hot path and:
- Reference data changes rarely (e.g., user name copied to order)
- The join would otherwise span shards
- Read latency budget is < 50 ms and join cost is significant

Trade-off: writes must update both copies. Use background reconciliation jobs to detect drift.

---

### Q21. EXISTS vs IN vs JOIN — when?

- `EXISTS` short-circuits on first match — best for "does any row exist"
- `IN (subquery)` — historically slower in MySQL but planner has improved; Postgres usually rewrites to semi-join
- `JOIN` — best when you need columns from the other table

```sql
-- "Has the user placed an order?"
SELECT u.* FROM users u
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);

-- "Get users with their order count"
SELECT u.id, COUNT(o.id) FROM users u
LEFT JOIN orders o ON o.user_id = u.id GROUP BY u.id;
```

---

### Q22. How do you optimize an OR query?

```sql
-- Slow — can't use indexes well
SELECT * FROM users WHERE email = ? OR phone = ?;

-- Fast — separate indexed scans then combine
SELECT * FROM users WHERE email = ?
UNION ALL
SELECT * FROM users WHERE phone = ? AND email <> ?;
```

In Postgres, the planner often handles OR via Bitmap Or — check the plan first.

---

## Schema-Level Optimization

### Q23. How do data types affect performance?

Smaller types = more rows per page = better cache hit rate.

- `INT` (4 bytes) vs `BIGINT` (8 bytes) — use BIGINT only when values exceed ~2 billion
- `BOOLEAN` (1 byte) vs `CHAR(1)` (1 byte but encoding overhead)
- `UUID` (16 bytes binary) vs string (36 chars) — store binary
- `TIMESTAMP` (8 bytes) vs `DATETIME` (8 bytes in MySQL 5.6.4+)
- `VARCHAR(N)` vs `TEXT` — practically identical in Postgres; in MySQL InnoDB, very long VARCHAR may become off-page

For a 1-billion-row table, switching from BIGINT to INT where appropriate saves ~4 GB.

---

### Q24. Wide rows vs narrow rows.

A row that exceeds the page size (8 KB Postgres, 16 KB InnoDB) gets split (TOAST in Postgres, off-page in InnoDB), causing extra I/O.

Strategies for wide rows:
- Move large text/blob columns to a separate table joined on the PK
- Compress JSONB / JSON columns where possible
- Store images as references (S3 URL), not in DB

---

### Q25. Should you use UUID or auto-increment IDs?

| Aspect | INT/BIGINT auto | UUID v4 | UUID v7 (time-ordered) |
|--------|----------------|---------|------------------------|
| Insert speed | Fast (sequential) | Slow (random, page splits) | Fast (sequential-ish) |
| Index size | Small | Larger | Larger |
| Distributed safe | No (need single coordinator) | Yes | Yes |
| Predictable | Yes (enumeration leak) | No | No |

For new systems, **UUID v7** or ULID is a great default. For high-write tables that must stay numeric, use BIGINT with sharded sequences.

---

### Q26. Composite primary keys vs surrogate keys.

Use a composite PK when the natural key is short, immutable, and the table is always accessed by it (e.g., `user_role(user_id, role_id)`).

Use a surrogate (auto-increment / UUID) when:
- The "natural key" can change
- Foreign keys would become wide
- You need a single column to reference

---

## Write Optimization

### Q27. INSERT, then INSERT, then INSERT — why is this slow at scale?

Each statement is a network round-trip and a separate transaction (with autocommit). With 10k inserts at 2 ms each, that's 20 seconds of pure latency.

Strategies:

**1. Batch inserts:**
```sql
INSERT INTO events (a, b) VALUES (1,2), (3,4), (5,6), ...;
-- Postgres allows up to 65535 parameters per statement
```

**2. Wrap in a single transaction:**
```sql
BEGIN;
INSERT ...; INSERT ...; ...;
COMMIT;
```
WAL / redo log syncs once at COMMIT.

**3. COPY (Postgres) / LOAD DATA INFILE (MySQL):**
```sql
COPY events FROM STDIN WITH (FORMAT CSV);
```
10–100x faster than INSERT — bypasses parser and uses bulk path.

**4. Disable indexes during massive load, rebuild after.**

**5. Increase `wal_writer_delay` / `commit_delay` for batch jobs only.**

---

### Q28. Bulk update / delete on huge tables — how to do it safely?

A single `DELETE FROM events WHERE created_at < ...` on 50M rows will:
- Hold long locks
- Bloat WAL
- Block replication
- Possibly OOM

**Chunked delete pattern:**
```sql
DO $$
DECLARE deleted INT;
BEGIN
  LOOP
    DELETE FROM events
    WHERE id IN (SELECT id FROM events WHERE created_at < NOW() - INTERVAL '1 year' LIMIT 5000);
    GET DIAGNOSTICS deleted = ROW_COUNT;
    EXIT WHEN deleted = 0;
    PERFORM pg_sleep(0.1);  -- breathing room
  END LOOP;
END $$;
```

For partitioned tables, `DROP PARTITION` is instant.

---

### Q29. UPSERT performance.

```sql
-- Postgres
INSERT INTO counters (id, count) VALUES (1, 1)
ON CONFLICT (id) DO UPDATE SET count = counters.count + 1;

-- MySQL
INSERT INTO counters (id, count) VALUES (1, 1)
ON DUPLICATE KEY UPDATE count = count + 1;
```

Both are atomic. Watch for:
- Bloat in Postgres (every update = new row version)
- Lock contention on hot keys (use sharding by hash, then aggregate)

---

## Read Optimization

### Q30. Read replicas — when, why, how?

**When:** read traffic exceeds primary's capacity, or you want geographic read locality.

**Patterns:**
- Route read queries to replicas, writes to primary
- Sticky session: route a user's read to primary for N seconds after their write (avoids stale reads after submit)
- Use replica for analytics dashboards / reports
- Use replica for backups (`pg_basebackup`, `xtrabackup`)

**Pitfalls:**
- Replication lag: replica is seconds behind under load
- Long transactions on replica can pause replication or cause `recovery_min_apply_delay` issues
- Connection pool exhaustion across replicas

---

### Q31. Query caching at the database vs application layer.

| Layer | Where | Hit speed | Invalidation |
|-------|-------|-----------|--------------|
| MySQL query cache | DB | < 1 ms | Auto on table write — but removed in MySQL 8 |
| InnoDB buffer pool | DB | < 1 ms | Automatic LRU |
| Postgres shared_buffers | DB | < 1 ms | Automatic |
| App in-process (LRU) | App | < 0.1 ms | Manual / TTL |
| Redis / Memcached | Network | 1–2 ms | Manual / TTL |
| CDN | Edge | < 50 ms RTT | Headers / purge |

The DB always caches hot data in its buffer pool; the question is whether you want to skip the DB entirely.

---

## Caching Strategies

### Q32. Cache-aside pattern.

```
1. Read from cache
2. If miss → read from DB → set in cache → return
3. On write → write DB → invalidate cache
```

```python
def get_user(id):
    val = redis.get(f"user:{id}")
    if val: return json.loads(val)
    user = db.query("SELECT * FROM users WHERE id=%s", id)
    redis.setex(f"user:{id}", 300, json.dumps(user))
    return user
```

Most common in production. Simple, but can have race conditions on update.

---

### Q33. Read-through, write-through, write-back.

| Pattern | Read path | Write path | Consistency | Use |
|---------|-----------|------------|-------------|-----|
| Read-through | Cache fetches from DB on miss | App writes to DB | Strong | Most common |
| Write-through | Same | App writes both | Strong | Hot reads after writes |
| Write-back | Same | App writes to cache, async to DB | Eventual | Counters, logs |

Write-back is dangerous: a cache crash loses writes. Use only for non-critical data with replication.

---

### Q34. Cache invalidation strategies.

There's a saying: "There are only two hard things in CS — cache invalidation and naming things."

**Approaches:**
1. **TTL only:** simple, eventual consistency. Fine if staleness < seconds is OK.
2. **Explicit invalidation on write:** delete the key in the same transaction (commit hook).
3. **Tag-based invalidation:** group keys by tag (`user:123:*`), purge tag.
4. **Versioned keys:** include a version in key (`user:123:v17`), bump on write — old entries die naturally.
5. **Pub/sub:** primary publishes invalidations, all caches listen.

**Common bug:** invalidate before commit → reader caches stale data between invalidate and commit.

**Fix:** invalidate after commit. Use commit hooks or transactional outbox.

---

### Q35. Cache stampede / thundering herd — prevention.

When a popular key expires, 1000 concurrent requests hit the DB at once.

**Solutions:**
- **Lock + single-flight:** first request gets a lock, others wait
  ```python
  if redis.set(f"lock:{key}", "1", nx=True, ex=10):
      val = db.query(...); redis.set(key, val, ex=300); redis.delete(f"lock:{key}")
  else:
      time.sleep(0.1); return cache.get(key) or db.query(...)
  ```
- **Probabilistic early refresh (XFetch):** refresh slightly before expiry with probability proportional to closeness
- **Two-tier TTL:** soft expiry triggers async refresh, hard expiry forces sync refresh
- **Stale-while-revalidate:** return stale and refresh in background

---

### Q36. CDN as a query cache.

For low-cardinality, public read endpoints (homepage, product list), set:
```
Cache-Control: public, max-age=60, stale-while-revalidate=300
```

CDN serves 90%+ of requests with no DB hit. Add `Surrogate-Key` headers for purge.

Don't cache personalized content at CDN unless you partition by user.

---

## Connection Pooling

### Q37. Why is connection pooling critical?

Each Postgres backend uses ~10 MB. 1000 raw connections = 10 GB just for connection overhead, plus context switching kills performance.

**Pool sizing rule of thumb:**
```
pool_size = ((core_count * 2) + effective_spindle_count)
```

For a typical 8-core SSD server, ~20 connections per app instance is plenty. More is usually worse.

---

### Q38. PgBouncer — modes and trade-offs.

| Mode | Description | Limits |
|------|-------------|--------|
| Session | Each client gets a backend until disconnect | Like raw connections |
| Transaction | Backend assigned per transaction | Most common; no session-level features (prepared stmts pre-PG14, advisory locks across txns) |
| Statement | Backend per statement | No multi-statement transactions |

Production default: **transaction mode**, pool size matched to actual concurrent transactions, not concurrent users.

---

### Q39. Common pool exhaustion symptoms.

- Latency spikes correlated with traffic spikes
- App logs show "timeout waiting for connection"
- DB CPU is low but app is queueing
- Long-running transactions (held by some background job) starve everyone else

**Detection:**
```sql
-- Postgres: connections by state
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;

-- Long-running queries
SELECT pid, now() - query_start AS dur, query
FROM pg_stat_activity WHERE state='active' ORDER BY dur DESC;
```

---

## Transactions and Concurrency

### Q40. How do transactions affect performance?

- Long transactions hold row/page locks → blocking other writers/readers (depending on isolation)
- In Postgres, long transactions prevent vacuum from cleaning up dead tuples — bloat grows
- In MySQL, long transactions in repeatable read keep undo logs around — history list grows

**Rule:** transactions should be short. Move I/O (HTTP, file) outside the transaction.

---

### Q41. Isolation levels and performance.

| Level | Read consistency | Write conflicts | Performance |
|-------|------------------|-----------------|-------------|
| Read Uncommitted | Sees uncommitted | Lots | Fastest, dirty reads |
| Read Committed | Per-statement | Some | Default Postgres |
| Repeatable Read | Per-transaction | Lock-based or snapshot | Default MySQL |
| Serializable | Strictest | Highest abort rate | Slowest |

In Postgres, Serializable uses SSI (no extra locks but transactions abort on conflict). In MySQL, Serializable adds gap locks → worse concurrency.

---

### Q42. SELECT FOR UPDATE — when and how.

```sql
BEGIN;
SELECT balance FROM accounts WHERE id=1 FOR UPDATE;  -- locks row
UPDATE accounts SET balance = balance - 50 WHERE id=1;
COMMIT;
```

Use for explicit pessimistic locking on mutually exclusive operations (transfers, inventory decrement).

For high contention: prefer optimistic locking with version column, or use UPDATE with conditional WHERE.

---

## Partitioning and Sharding

### Q43. Difference between partitioning and sharding.

| Aspect | Partitioning | Sharding |
|--------|--------------|----------|
| Where | Single DB instance | Multiple DB instances |
| Transparency | DB sees one logical table | App / proxy routes |
| Use case | Large tables, hot/cold data | Beyond single-server capacity |
| Cross-partition query | Native | Application or proxy |

Partitioning helps a single server. Sharding helps when one server isn't enough.

---

### Q44. Postgres partitioning strategies.

**Range:** by time (most common for events/logs)
```sql
CREATE TABLE events (id BIGSERIAL, created_at TIMESTAMPTZ, ...) PARTITION BY RANGE (created_at);
CREATE TABLE events_2025_01 PARTITION OF events FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
```

**List:** by category (tenant_id from a known set)

**Hash:** when no natural range, distribute uniformly
```sql
PARTITION BY HASH (user_id) WITH (modulus 16, remainder 0);
```

Benefits:
- Per-partition indexes (smaller, faster)
- Drop old partitions instantly (vs `DELETE` of 100M rows)
- Partition pruning: planner skips irrelevant partitions

Use `pg_partman` or `pgcron` to auto-create future partitions.

---

### Q45. Sharding key choice.

A bad shard key destroys you. Properties of a good shard key:
- High cardinality
- Even distribution (no hot shards)
- Aligned with most queries (so single-shard reads are common)
- Stable (doesn't change for a row)

**Examples:**
- User-data app: `user_id` — most queries are per-user
- Multi-tenant SaaS: `tenant_id` — but watch for one giant tenant
- Time-series: time + entity (composite) — avoid pure time (creates a hot shard)

**Anti-patterns:**
- Sequential ID — last shard becomes hot
- Country code — uneven (US dominates)
- Status / category — only a few values

---

### Q46. Consistent hashing — why?

When you add a shard with naive `hash(key) % N`, almost every key remaps. With consistent hashing, only `1/N` keys move.

Used by: Redis Cluster, Cassandra, DynamoDB, Vitess.

Often paired with virtual nodes (each physical node hosts many ring positions) for better balance.

---

### Q47. Cross-shard queries — how do you handle them?

Options:
1. **Avoid them:** design schema so 99% of queries hit one shard
2. **Scatter-gather:** query all shards, merge results (slow, fan-out)
3. **Materialized index:** denormalize into a separate "global" lookup
4. **Search engine alongside:** push searchable data to Elasticsearch / OpenSearch
5. **Analytics pipeline:** ETL all shards into a warehouse (Snowflake, BigQuery)

A scatter-gather across 100 shards = your latency = slowest shard. Use timeouts and partial results.

---

## Handling 100M+ Row Tables

### Q48. What changes when a table crosses ~50M rows?

- Full scans become unacceptable (minutes)
- Index size starts pressuring buffer pool
- ALTER TABLE rewrite becomes a major operation (hours)
- Backup time increases linearly
- Vacuum / optimize windows shrink
- Single-row latency stays fast IF indexes are right

**Operational changes:**
- Use `pg_repack` / `pt-online-schema-change` for online migrations
- Add columns with `DEFAULT` only if your DB supports instant default (PG 11+, MySQL 8 InnoDB instant ADD)
- Backfill in chunks
- Plan partitioning before you cross 100M

---

### Q49. Soft delete vs hard delete at scale.

**Soft delete (`deleted_at` column):**
- Easy recovery, audit-friendly
- Every query needs `WHERE deleted_at IS NULL`
- Indexes carry tombstones — bloat
- Use partial indexes: `WHERE deleted_at IS NULL`

**Hard delete:**
- Reclaims space
- Lose audit/recovery
- Watch FK cascade and orphan rows

**Production hybrid:**
- Soft delete for short retention (30 days)
- Background job hard-deletes after retention
- Move to archive table or cold storage for compliance

---

### Q50. Archiving strategy for old data.

```
hot table  ──nightly job──>  warm table (last 90d)
                          ──>  cold archive (S3 / object storage)
                          ──>  drop partition
```

**Implementation:**
- Time-based partitioning makes archiving trivial: `pg_dump` partition, then `DROP TABLE events_2023_01`
- Or use Postgres FDW to point to archived data on cheap storage
- Or move to a columnar warehouse (Redshift, BigQuery, ClickHouse) for analytics queries

---

### Q51. Schema migrations on huge tables.

**Don't:** `ALTER TABLE huge ADD COLUMN x INT NOT NULL DEFAULT 0;` — full rewrite, hours of locks.

**Do:**
1. `ALTER TABLE huge ADD COLUMN x INT;` — instant in modern Postgres/MySQL
2. Backfill in chunks: `UPDATE huge SET x = ... WHERE id BETWEEN ... AND ...; sleep 0.1;`
3. Add NOT NULL after backfill (also instant in PG12+)
4. Use a tool: `pg-osc`, `gh-ost` (MySQL), `pt-online-schema-change`

---

## Replication and Read Scaling

### Q52. Postgres replication modes.

| Mode | Latency | Durability | Use |
|------|---------|------------|-----|
| Async streaming | Low | Loss possible on primary failure | Default, most apps |
| Synchronous | Higher | Two-node durability | Financial / critical |
| Logical | Application-level | Selective tables | Heterogeneous, zero-downtime upgrades |

`synchronous_commit = on` with `synchronous_standby_names` ensures one replica acks before COMMIT returns.

---

### Q53. MySQL replication modes.

- **Statement-based:** small log, but non-deterministic statements (NOW(), UUID()) misbehave
- **Row-based:** larger log, exact, default since 5.7
- **Mixed:** statement when safe, row otherwise

For high write volume on replicas, watch for **single-threaded SQL apply** — use `slave_parallel_workers` (logical clock or LOGICAL_CLOCK based) to parallelize.

---

### Q54. Replication lag — what causes it and how to monitor?

**Causes:**
- Long transactions on primary (the whole transaction must replay)
- Slow queries on replica blocking apply
- Network bottleneck
- Single-thread apply on MySQL (older versions)
- `synchronous_commit=off` then catch-up after burst

**Monitor:**
```sql
-- Postgres on replica
SELECT now() - pg_last_xact_replay_timestamp() AS lag;

-- MySQL
SHOW SLAVE STATUS \G   -- Seconds_Behind_Master
```

Alert if lag > 5 seconds for OLTP or > 1 minute for analytics.

---

## Server Tuning (Postgres / MySQL)

### Q55. Key Postgres parameters to tune.

| Parameter | Description | Typical |
|-----------|-------------|---------|
| `shared_buffers` | Postgres internal cache | 25% RAM |
| `effective_cache_size` | Hint of total cache (OS+PG) | 50–75% RAM |
| `work_mem` | Per-operation sort/hash memory | 4–64 MB (per backend) |
| `maintenance_work_mem` | For VACUUM, CREATE INDEX | 256 MB – 2 GB |
| `wal_buffers` | WAL buffer | 16 MB |
| `max_wal_size` | Checkpoint trigger | 2–8 GB |
| `checkpoint_completion_target` | Spread checkpoint I/O | 0.9 |
| `random_page_cost` | SSD = 1.1, spinning = 4 | 1.1 (SSD) |
| `effective_io_concurrency` | Async I/O depth | 200 (SSD) |
| `max_connections` | Hard limit | Use PgBouncer instead |

---

### Q56. Postgres autovacuum and performance.

Autovacuum reclaims dead tuples, updates statistics, and prevents transaction ID wraparound.

**Tuning for high-write tables:**
```ini
autovacuum_vacuum_scale_factor = 0.05   # default 0.2 — too lazy for big tables
autovacuum_analyze_scale_factor = 0.02
autovacuum_vacuum_cost_limit = 2000     # default 200 — let it work harder
autovacuum_naptime = 30s
```

Per-table:
```sql
ALTER TABLE big_table SET (autovacuum_vacuum_scale_factor = 0.01, fillfactor = 90);
```

Symptoms of bad autovacuum:
- Bloat growing
- Wraparound warnings (`age(datfrozenxid)` near 200M)
- Slow queries due to dead tuples in indexes

---

### Q57. MySQL InnoDB tuning essentials.

| Parameter | Description | Typical |
|-----------|-------------|---------|
| `innodb_buffer_pool_size` | Cache for data+index | 50–75% RAM |
| `innodb_log_file_size` | Redo log size | 1–4 GB |
| `innodb_flush_log_at_trx_commit` | Durability | 1 (full ACID) or 2 (slight risk, faster) |
| `innodb_flush_method` | I/O method | O_DIRECT |
| `innodb_io_capacity` | Disk IOPS hint | 2000+ for SSD |
| `innodb_read_io_threads` | Read parallelism | 8–16 |
| `innodb_write_io_threads` | Write parallelism | 8–16 |
| `innodb_buffer_pool_instances` | For very large pools | 8 |
| `tmp_table_size` / `max_heap_table_size` | In-memory temp tables | 64 MB |

---

### Q58. work_mem — sizing.

`work_mem` is per-sort-or-hash-operation, per-backend. A query with 3 sorts uses `3 × work_mem` from one backend.

Total possible memory: `work_mem × max_connections × operations_per_query`.

For 1 GB RAM headroom, 100 connections, 3 ops/query → `work_mem = 3 MB`.

Better: keep `work_mem` modest (8–16 MB) globally, override for analytical sessions:
```sql
SET work_mem = '512MB';
```

---

### Q59. Parallelism in Postgres.

Postgres supports parallel sequential scan, parallel hash join, parallel aggregate.

Tune:
```ini
max_worker_processes = 16
max_parallel_workers = 8
max_parallel_workers_per_gather = 4
parallel_setup_cost = 1000
parallel_tuple_cost = 0.1
```

Parallel only triggers above a threshold (`min_parallel_table_scan_size = 8 MB`). Small tables won't go parallel.

---

## Monitoring and Slow Queries

### Q60. Slow query log — what to capture.

**Postgres:**
```ini
log_min_duration_statement = 200   # log queries > 200 ms
log_temp_files = 0                  # any spill to disk
log_lock_waits = on
log_checkpoints = on
auto_explain.log_min_duration = 500
```

**MySQL:**
```ini
slow_query_log = ON
long_query_time = 0.2
log_queries_not_using_indexes = ON
```

Aggregate with **pg_stat_statements** (Postgres) or **performance_schema.events_statements_summary_by_digest** (MySQL).

---

### Q61. pg_stat_statements — top queries.

```sql
SELECT
  query,
  calls,
  total_exec_time,
  mean_exec_time,
  rows,
  100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_pct
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

Focus on `total_exec_time` — that's where the wall-clock pain is. A 1 ms query called 10M times often beats a 1-second query called 100 times.

---

### Q62. Lock monitoring.

```sql
-- Postgres: who is blocking whom
SELECT blocked.pid AS blocked_pid, blocking.pid AS blocking_pid,
       blocked.query, blocking.query
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid));
```

Red flags:
- Long `idle in transaction` sessions — kill them, fix the app
- AccessExclusiveLock on a popular table — DDL during traffic

---

## OLTP vs OLAP

### Q63. Why mixing OLTP and OLAP on the same DB hurts.

OLTP = many small, quick transactions. OLAP = few huge analytical queries.

If both share buffer pool:
- OLAP query loads 100 GB into buffer → evicts OLTP hot data → user-facing latency spikes
- OLAP holds long-running transaction → vacuum stalls, bloat grows
- OLAP locks → OLTP blocks

**Solutions:**
- Read replica dedicated to analytics
- ETL to a warehouse (Snowflake, BigQuery, Redshift, ClickHouse, DuckDB)
- Materialized views refreshed hourly
- Use logical replication to a columnar store

---

### Q64. Materialized views — when and how.

```sql
CREATE MATERIALIZED VIEW daily_revenue AS
SELECT date_trunc('day', created_at) AS day, sum(total) FROM orders GROUP BY 1;

REFRESH MATERIALIZED VIEW CONCURRENTLY daily_revenue;
```

Use for expensive aggregations queried many times. `REFRESH CONCURRENTLY` requires a unique index but doesn't lock readers.

For continuous freshness: incremental refresh tools (`pg_ivm`) or rollup tables maintained by triggers / event handlers.

---

## Maintenance Impact

### Q65. Backup impact on a live primary.

`pg_dump` runs in a long transaction → blocks vacuum → bloat. For large DBs:
- Run `pg_basebackup` from a replica
- Or use `pg_dump --jobs=N --format=directory` with parallelism
- Or filesystem-level snapshots (`zfs snapshot`, EBS snapshot) — fastest, but require fsfreeze or PG `pg_start_backup`

For MySQL, use **xtrabackup** (online physical backup, no locks).

---

### Q66. Index rebuild without downtime.

```sql
-- Postgres (PG 12+)
REINDEX INDEX CONCURRENTLY idx_name;

-- Or pg_repack
pg_repack -t orders -j 4 mydb
```

**Anti-pattern:** dropping and recreating an index — your queries will degrade until the new one finishes.

---

## Common Production Issues

### Q67. "Suddenly all queries are slow."

Checklist (in order):
1. Recent deploy? Rollback or check new code paths
2. CPU / IO saturation? Check `iostat`, `top`
3. Connection pool exhausted? Check `pg_stat_activity`
4. Long-running query holding locks? Kill it
5. Vacuum / autovacuum running? Wait or increase resources
6. Disk full? Check `df`
7. Replica promoted / failover? Check current primary

---

### Q68. "Some queries are fast, then suddenly slow."

Likely **plan flip**: planner picked a different plan because:
- Statistics changed (`ANALYZE` ran, or auto-analyze fired after a bulk write)
- Parameter sniffing (Postgres prepared statements use generic plan after 5 executions)
- Different data shape — query for active user with 1M rows uses a different plan than one with 10

**Fix:**
- Disable generic plans: `SET plan_cache_mode = 'force_custom_plan';`
- Hint the planner via query rewrite
- Add a covering index that's optimal for both shapes

---

### Q69. "DB looks healthy but app is slow."

- App-side connection pool too small — request queueing in app
- Network latency between app and DB (cross-AZ, VPN)
- TLS handshake overhead — use connection pool with reuse
- DNS lookup on every connection — set hostname to IP or cache DNS
- App-side ORM doing N+1 even though DB sees fast queries

---

### Q70. Disk space exhaustion in Postgres.

Symptoms: WAL fills disk, replication breaks, primary refuses writes.

Causes:
- WAL retention (`wal_keep_size` too high, or replication slot held by dead replica)
- Disabled autovacuum → bloat grows forever
- Long-running transaction prevents WAL recycle
- Logical replication slot inactive → WAL accumulates

**Recovery:**
- `pg_drop_replication_slot()` for dead slots (carefully)
- Kill long transactions
- Move WAL to bigger disk via `archive_command`

---

### Q71. Hot row contention.

Counter-style updates on one row create a serialization point.

```sql
UPDATE counters SET count = count + 1 WHERE id = 1;
-- 10k req/s all hit one row → lock queue
```

**Solutions:**
1. **Sharded counter:** N rows per logical counter, write to a random one, sum on read
2. **Approximate counter:** increment in Redis, flush to DB every 5 seconds
3. **Append-only log:** insert rows, aggregate later
4. **Atomic op in cache:** `redis.incr(...)`, persist asynchronously

---

### Q72. JSON / JSONB — when and pitfalls.

**Use JSONB when:**
- Schema is genuinely flexible (custom fields, extensible event payload)
- Some query needs to read inside the document

**Pitfalls:**
- JSONB key extraction is slower than columns
- Indexing JSONB needs GIN, which is heavier
- TOAST'd JSONB causes extra reads
- ORM eager-loading JSON columns moves a lot of bytes

Best practice: extract frequently-queried keys to dedicated columns; keep tail data in JSONB.

---

### Q73. NULL — does it hurt performance?

NULL itself is cheap in storage. But:
- `WHERE col IS NULL` may not use index unless partial
- `NOT IN (subquery with NULL)` returns no rows — common bug
- NULL semantics in joins surprise people; test edge cases

If a column is "never null" semantically, declare `NOT NULL` — better stats, better plans.

---

### Q74. Common interview trap: "What does this query do?"

```sql
SELECT u.id FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE o.id IS NULL;
```

Answer: users with no orders. The `LEFT JOIN` + `IS NULL` is the anti-join idiom. Equivalent:
```sql
SELECT id FROM users u WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);
```

Postgres usually generates the same plan. MySQL historically prefers `NOT EXISTS`.

---

### Q75. Senior signal: "How would you scale this DB to 10x traffic?"

Don't jump to "shard everything." Walk through:

1. **Measure** current bottleneck (CPU, IO, connections, latency by query)
2. **Optimize** the top 5 slow queries (often 80% of load)
3. **Cache** hot reads (Redis, application cache)
4. **Read replicas** for read scaling
5. **Connection pool** (PgBouncer / ProxySQL)
6. **Vertical scale** (bigger box) — often cheapest first move
7. **Async** non-critical writes (queues)
8. **Partition** big tables
9. **Shard** only when one box can't keep up
10. **Move analytics off** to a warehouse

Each step buys time before the next, in increasing operational complexity.

---

## Appendix — Index Decision Cheat Sheet

| Query pattern | Recommended index |
|---------------|-------------------|
| `WHERE a = ?` | `(a)` |
| `WHERE a = ? AND b = ?` | `(a, b)` |
| `WHERE a = ? ORDER BY b` | `(a, b)` |
| `WHERE a = ? AND b > ? ORDER BY b` | `(a, b)` |
| `WHERE a IN (...)` | `(a)` |
| `WHERE a = ? AND b = ?` (`b` rarely filtered) | `(a)` only — don't bloat |
| `LIKE 'abc%'` | B-tree `(col text_pattern_ops)` in PG |
| `LIKE '%abc%'` | trigram (`pg_trgm`) GIN |
| JSONB key | GIN on `(jsonb_col)` or expression |
| Geospatial | GIST |
| Full-text | GIN on `tsvector` |
| Sorted hot/cold | partial index on the hot subset |

---

## Appendix — Latency Reference Numbers

| Operation | Time |
|-----------|------|
| L1 cache | 0.5 ns |
| L2 cache | 7 ns |
| Main memory | 100 ns |
| SSD random read | 100 µs |
| Same-AZ network round-trip | 0.5 ms |
| HDD random read | 10 ms |
| Cross-region round-trip | 100+ ms |
| HTTP API call | 50–500 ms |

If your DB is SSD + same-AZ, even a "cold" indexed lookup is < 1 ms. If a query takes 100 ms, something is doing many disk reads, scanning, or contending for a lock.
