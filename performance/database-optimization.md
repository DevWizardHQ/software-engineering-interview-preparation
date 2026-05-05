# Database Optimization — Interview Q&A Guide

This guide covers database performance topics for backend interviews: query optimization, indexing, schema design, caching, partitioning, sharding, replication, and operating large tables. Each question pairs the explanation with code, configuration, or query plans.

---

## Query Optimization Fundamentals

## Q1. What is the first rule of database optimization?

**Answer:**

Measure first, then optimize. Use `EXPLAIN ANALYZE` (Postgres) or `EXPLAIN FORMAT=JSON` (MySQL) to see the actual cost. Adding an index without confirming the planner needs one is guesswork.

```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 42 AND status = 'shipped';
```

Output tells you whether it picked an index scan, sequential scan, or hash join, plus rows scanned vs returned. Optimization decisions follow the data, not intuition.

## Q2. What are typical latency budgets for a single query?

**Answer:**

A user-facing API endpoint should not exceed about 200 ms total DB time at p95. Breaking it down:

| Query type | Acceptable | Investigate | Critical |
| --- | --- | --- | --- |
| Primary key lookup | < 1 ms | > 5 ms | > 20 ms |
| Indexed read | < 5 ms | > 20 ms | > 100 ms |
| Aggregation (small) | < 50 ms | > 200 ms | > 1 s |
| Reporting query | < 5 s | > 30 s | move to OLAP |

If a PK lookup takes 50 ms, suspect connection latency, network, or cold cache, not the query itself.

## Q3. What are the most common reasons a query is slow?

**Answer:**

Most slow queries fall into a small set of patterns:

1. Missing or stale index
2. N+1 queries from the application
3. `SELECT *` on wide tables
4. Implicit type cast preventing index use
5. `LIKE '%term%'` (leading wildcard)
6. Function applied to a column without an expression index
7. Large `OFFSET` for pagination
8. Stale planner statistics
9. Lock contention
10. Buffer pool eviction (cold data)

Example of a hidden killer:

```sql
-- "id" is INTEGER but bound as string -> implicit cast -> seq scan
SELECT * FROM users WHERE id = '42';
```

## Q4. What is the difference between a logical query plan and a physical plan?

**Answer:**

The logical plan describes *what* the query computes (joins, projections, filters). The physical plan describes *how* the engine will execute it: index scan vs sequential scan, hash join vs nested loop, parallel workers, sort operations.

The optimizer picks the physical plan based on table statistics. After bulk loads, statistics get stale and plans become bad.

```sql
-- Postgres: refresh stats
ANALYZE orders;

-- MySQL
ANALYZE TABLE orders;
```

## Q5. Why does `SELECT *` hurt performance?

**Answer:**

`SELECT *` reads every column whether you need it or not. That means more bytes over the wire, more memory in result buffers, and you cannot use a covering index (the planner is forced to visit the heap).

```sql
-- BAD: pulls all columns
SELECT * FROM orders WHERE user_id = 42;

-- GOOD: only what the API actually returns
SELECT id, total_amount, status, created_at
FROM orders
WHERE user_id = 42;
```

For wide tables with TEXT or JSONB columns, the difference can be 10x in I/O and bandwidth.

---

## Indexes

## Q6. What does a B-tree index actually do?

**Answer:**

A B-tree is a balanced tree of sorted keys with pointers to rows. Lookups, range scans, and ordered scans are O(log n). The leaves are linked, so range scans walk leaves directly.

```sql
CREATE INDEX idx_users_email ON users(email);
```

A 100 million row table typically has a tree depth of 4 to 5 levels. With a warm cache, those reads are in memory, so a lookup costs microseconds.

## Q7. When is an index NOT used by the planner?

**Answer:**

Common cases where the index gets bypassed:

```sql
-- Function on column - index unusable
SELECT * FROM users WHERE LOWER(email) = 'me@x.com';

-- Fix with expression index
CREATE INDEX idx_users_lower_email ON users(LOWER(email));
```

```sql
-- Leading wildcard - cannot use B-tree
SELECT * FROM products WHERE name LIKE '%phone';

-- Type mismatch
SELECT * FROM users WHERE id = '42';   -- if id is INTEGER

-- Negation
SELECT * FROM orders WHERE status != 'paid';

-- OR across columns from different indexes
SELECT * FROM users WHERE email = ? OR phone = ?;
```

## Q8. What is a covering index?

**Answer:**

A covering index includes every column the query needs, so the engine never visits the heap. Postgres calls this an "index-only scan."

```sql
-- Postgres: include extra columns without making them part of key
CREATE INDEX idx_orders_user_status ON orders (user_id, status)
INCLUDE (total_amount);

-- MySQL: just put them in the index
CREATE INDEX idx_orders_user_status ON orders (user_id, status, total_amount);
```

Query that benefits:

```sql
SELECT total_amount FROM orders
WHERE user_id = 42 AND status = 'shipped';
```

The downside: bigger index, slower writes.

## Q9. What is a partial index?

**Answer:**

A partial index covers only a subset of rows that match a `WHERE` clause. Useful when most rows are inactive but queries always filter to the small active set.

```sql
-- Only index active orders (much smaller)
CREATE INDEX idx_active_orders ON orders (created_at)
WHERE status = 'active';

-- Soft delete pattern
CREATE INDEX idx_users_email ON users (email)
WHERE deleted_at IS NULL;
```

If only 5 percent of rows match, the partial index is 20x smaller, fits in cache, and scans faster.

## Q10. How do you choose composite index column order?

**Answer:**

Rule: equality columns first, range columns last, sort columns aligned with the order direction.

For this query:

```sql
SELECT * FROM events
WHERE tenant_id = 7
  AND type = 'click'
  AND created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;
```

The right index is:

```sql
CREATE INDEX idx_events_tenant_type_created
ON events (tenant_id, type, created_at DESC);
```

The planner seeks to `(7, 'click')`, then walks leaves backwards by `created_at`. No extra sort step.

## Q11. What is index bloat and how do you fix it?

**Answer:**

In Postgres, dead tuples in indexes do not auto-shrink. After heavy update or delete cycles the index becomes 3 to 5 times larger than necessary, causing slower scans and memory pressure.

Detect:

```sql
SELECT schemaname, relname, indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;
```

Fix without downtime:

```sql
REINDEX INDEX CONCURRENTLY idx_users_email;
-- Or use pg_repack from the command line
```

In MySQL InnoDB, `OPTIMIZE TABLE users;` rebuilds and reclaims space.

## Q12. Hash index vs B-tree?

**Answer:**

| Aspect | B-tree | Hash |
| --- | --- | --- |
| Equality | Yes | Yes (slightly faster) |
| Range queries | Yes | No |
| Sorting (ORDER BY) | Yes | No |
| Real-world use | 99% of cases | Rare |

Default to B-tree. Hash indexes only help when the workload is purely equality on a high-cardinality column with no ordering needs.

## Q13. GIN vs GiST in Postgres?

**Answer:**

GIN (Generalized Inverted Index) is best for full-text search, JSONB key lookups, and array contains. Slower writes, fast reads.

GiST (Generalized Search Tree) is best for geospatial, range types, and fuzzy matching. Faster writes, slower reads than GIN.

```sql
-- JSONB key lookup
CREATE INDEX idx_payload_gin ON events USING GIN (payload);

-- Full-text
CREATE INDEX idx_doc_fts ON documents
USING GIN (to_tsvector('english', body));

-- Geospatial
CREATE INDEX idx_location ON places USING GIST (location);
```

## Q14. Why is having too many indexes bad?

**Answer:**

Every index must be updated on every insert, update (to indexed columns), and delete. Eight indexes on a hot write table can make inserts 3 to 5 times slower. They also consume disk and buffer pool memory.

Audit unused indexes:

```sql
SELECT schemaname, relname, indexrelname, idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
```

If an index has zero scans for a month under representative load, drop it.

---

## EXPLAIN and Query Plans

## Q15. How do you read a Postgres `EXPLAIN ANALYZE` output?

**Answer:**

Each line shows a plan node with its estimated cost, estimated rows, actual time, and actual rows. The interesting numbers are `actual time`, `actual rows`, and `Buffers`.

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE user_id = 42;
```

Sample output:

```
Index Scan using idx_orders_user on orders
  (cost=0.42..8.44 rows=10 width=64)
  (actual time=0.012..0.145 rows=12 loops=1)
  Buffers: shared hit=4
Planning Time: 0.123 ms
Execution Time: 0.180 ms
```

Watch for:

- A big gap between estimated and actual rows means stale stats. Run `ANALYZE`.
- `Seq Scan` on a large table means a missing index.
- `Sort` with `Disk:` means `work_mem` is too low.

## Q16. What are the common Postgres plan node types?

**Answer:**

| Node | When you see it |
| --- | --- |
| Seq Scan | Reads whole table — good for small tables, bad for large |
| Index Scan | Uses index, then reads heap |
| Index Only Scan | Best — needs covering index + visibility map |
| Bitmap Index Scan | Combines multiple indexes |
| Nested Loop | For each outer row, scan inner — good with small outer |
| Hash Join | Builds hash on one side — good for unsorted equi-join |
| Merge Join | Both sides sorted |
| Sort | Explicit sort — try to align index with `ORDER BY` |

## Q17. How do you read MySQL EXPLAIN output?

**Answer:**

Focus on the `type` column. From best to worst: `const` < `eq_ref` < `ref` < `range` < `index` < `ALL`. `ALL` means a full table scan.

```sql
EXPLAIN SELECT * FROM orders WHERE user_id = 42;
```

| id | type | key | rows | Extra |
| --- | --- | --- | --- | --- |
| 1 | ref | idx_user_id | 12 | Using where |

Goals:
- Avoid `type: ALL`
- Avoid `Extra: Using filesort` on large data
- Avoid `Extra: Using temporary`
- Prefer `Extra: Using index` (covering index)

For more detail, use `EXPLAIN FORMAT=JSON`.

---

## N+1 and JOIN Strategies

## Q18. What is the N+1 problem and how do you detect it?

**Answer:**

For each parent row, the ORM fires a separate child query. One parent query plus N child queries equals N+1 round trips.

Bad pattern:

```php
$users = User::all();              // 1 query
foreach ($users as $user) {
    echo $user->posts->count();    // N queries
}
```

Fix with eager loading:

```php
$users = User::withCount('posts')->get();  // 1 query
```

Detection:
- Laravel: enable `Model::preventLazyLoading()` in development
- Rails: use the `bullet` gem
- APM tools group similar repeated queries

## Q19. When should you use Nested Loop vs Hash Join vs Merge Join?

**Answer:**

| Strategy | Best when | Cost |
| --- | --- | --- |
| Nested Loop | Outer is small, inner has index | O(N × log M) |
| Hash Join | Both sides unsorted, equi-join | O(N + M), uses memory |
| Merge Join | Both sides pre-sorted | O(N + M) |

The planner picks based on stats. Force a different plan in MySQL with `STRAIGHT_JOIN`, in Postgres rewrite the query or use `pg_hint_plan`.

## Q20. When should you denormalize a join?

**Answer:**

Denormalize when:
- The join is on a hot read path with a strict latency budget (under 50 ms)
- Reference data changes rarely, like a copy of `user_name` on `orders`
- The join would otherwise span shards

Example: instead of joining `orders` and `users` on every read, copy `user_name` to `orders` at insert time.

```sql
-- Schema with denormalized name
CREATE TABLE orders (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT,
  user_name VARCHAR(100),  -- copied from users
  total NUMERIC(10,2),
  created_at TIMESTAMPTZ
);
```

The trade-off: writes must keep both copies in sync. Use a background reconciliation job to detect drift.

## Q21. EXISTS vs IN vs JOIN — when to use which?

**Answer:**

```sql
-- "Does the user have any orders?" -> EXISTS short-circuits
SELECT u.id FROM users u
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);

-- "How many orders does each user have?" -> JOIN
SELECT u.id, COUNT(o.id)
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
GROUP BY u.id;

-- "Which users have ordered specific items?" -> IN or JOIN
SELECT * FROM users
WHERE id IN (SELECT user_id FROM orders WHERE product_id = 5);
```

Postgres rewrites most `IN (subquery)` into semi-joins, so performance is similar. MySQL historically prefers `EXISTS`.

## Q22. How do you optimize an OR query?

**Answer:**

`OR` across different indexed columns often forces a full scan because the planner cannot combine indexes well.

```sql
-- Slow
SELECT * FROM users WHERE email = ? OR phone = ?;

-- Fast: rewrite as UNION ALL
SELECT * FROM users WHERE email = ?
UNION ALL
SELECT * FROM users WHERE phone = ? AND email <> ?;
```

In Postgres the planner often handles this via Bitmap Or, so check the plan first before rewriting.

---

## Schema Optimization

## Q23. How do data types affect performance?

**Answer:**

Smaller types mean more rows fit per page, which means better cache hit rates.

| Type | Size | Notes |
| --- | --- | --- |
| INT | 4 bytes | Use unless you exceed 2 billion |
| BIGINT | 8 bytes | For massive ID ranges |
| UUID (binary) | 16 bytes | Better than 36-char string |
| VARCHAR(N) | length | In MySQL, can move off-page if very long |

Switching a 1-billion-row table from BIGINT to INT saves 4 GB per indexed column.

```sql
-- BAD: storing UUIDs as text in MySQL
user_id CHAR(36)

-- GOOD
user_id BINARY(16)
```

## Q24. What is the difference between wide rows and narrow rows?

**Answer:**

A row that exceeds the page size (8 KB Postgres, 16 KB InnoDB) gets split off-page (TOAST in Postgres). The main row stores a pointer, and reading the large field requires extra I/O.

Strategies:

```sql
-- BAD: large blobs inline with hot data
CREATE TABLE products (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(100),
  price NUMERIC(10,2),
  description TEXT,        -- can be 100 KB
  full_html TEXT           -- can be 1 MB
);

-- GOOD: split heavy fields
CREATE TABLE products (id, name, price);
CREATE TABLE product_content (
  product_id BIGINT PRIMARY KEY REFERENCES products(id),
  description TEXT,
  full_html TEXT
);
```

## Q25. UUID vs auto-increment IDs?

**Answer:**

| Aspect | INT/BIGINT auto | UUID v4 | UUID v7 |
| --- | --- | --- | --- |
| Insert speed | Fast (sequential) | Slow (random page splits) | Fast (sequential) |
| Index size | Small | Larger | Larger |
| Distributed-safe | No | Yes | Yes |
| Reveals counts | Yes | No | No |

For new systems, **UUID v7** (time-ordered) gives you distributed IDs without the random-insertion penalty.

```sql
-- Postgres extension for UUID v7 (Postgres 18+ has built-in)
CREATE EXTENSION pg_uuidv7;

CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  ...
);
```

## Q26. Composite primary key vs surrogate key?

**Answer:**

Use a composite PK when the natural key is short, immutable, and queries always use it. The classic example is a join table:

```sql
CREATE TABLE user_role (
  user_id BIGINT,
  role_id BIGINT,
  PRIMARY KEY (user_id, role_id)
);
```

Use a surrogate (auto-increment or UUID) when the natural key can change, when foreign keys would otherwise be wide, or when you need a single column for references.

---

## Write Optimization

## Q27. Why is one-row-at-a-time INSERT slow at scale?

**Answer:**

Each statement is a network round trip plus a separate transaction commit (with autocommit on). 10,000 inserts at 2 ms each is 20 seconds of pure latency.

Bad:

```php
foreach ($events as $event) {
    DB::table('events')->insert($event);   // 10,000 round trips
}
```

Good - batched insert:

```php
DB::table('events')->insert($events);   // 1 round trip
```

Even better, single transaction:

```sql
BEGIN;
INSERT INTO events (a, b) VALUES (1,2),(3,4),(5,6),...;
COMMIT;
```

Best for huge loads, bypass the SQL parser:

```sql
-- Postgres: 10-100x faster than INSERT
COPY events FROM '/tmp/events.csv' WITH (FORMAT CSV);

-- MySQL
LOAD DATA INFILE '/tmp/events.csv' INTO TABLE events;
```

## Q28. How do you bulk delete from a huge table safely?

**Answer:**

A single `DELETE FROM events WHERE created_at < ...` on 50 million rows holds long locks, bloats WAL, and may block replication.

Chunk the delete:

```sql
DO $$
DECLARE deleted INT;
BEGIN
  LOOP
    DELETE FROM events
    WHERE id IN (
      SELECT id FROM events
      WHERE created_at < NOW() - INTERVAL '1 year'
      LIMIT 5000
    );
    GET DIAGNOSTICS deleted = ROW_COUNT;
    EXIT WHEN deleted = 0;
    PERFORM pg_sleep(0.1);   -- breathing room
  END LOOP;
END $$;
```

For partitioned tables, dropping a partition is instant:

```sql
DROP TABLE events_2023_01;   -- removes 50M rows in milliseconds
```

## Q29. How does UPSERT perform and what are the pitfalls?

**Answer:**

```sql
-- Postgres
INSERT INTO counters (id, count) VALUES (1, 1)
ON CONFLICT (id) DO UPDATE
SET count = counters.count + 1;

-- MySQL
INSERT INTO counters (id, count) VALUES (1, 1)
ON DUPLICATE KEY UPDATE count = count + 1;
```

Pitfalls:
- Postgres creates a new row version on every UPDATE, which causes bloat. Vacuum frequently or use `fillfactor=80`.
- A hot key (e.g., a single counter incremented thousands of times per second) becomes a serialization bottleneck. Use sharded counters.

```sql
-- Sharded counter pattern
CREATE TABLE counters (
  bucket SMALLINT,
  count BIGINT,
  PRIMARY KEY (bucket)
);
-- 16 buckets; each writer picks a random bucket
```

---

## Read Optimization

## Q30. When and how do you use read replicas?

**Answer:**

Use a read replica when read traffic exceeds the primary's capacity, or when you want analytics off the OLTP path.

Application pattern:

```php
// Laravel
'mysql' => [
    'read' => ['host' => ['replica1', 'replica2']],
    'write' => ['host' => ['primary']],
    ...
]
```

Pitfalls:
- Replication lag means replicas can be seconds behind. After a write, a read may show stale data.
- Stick the user's session to the primary for a few seconds after their write to avoid stale reads.
- Long-running queries on the replica can pause replication.

## Q31. Where can queries be cached?

**Answer:**

| Layer | Hit speed | Invalidation |
| --- | --- | --- |
| Postgres `shared_buffers` | < 1 ms | Automatic LRU |
| InnoDB buffer pool | < 1 ms | Automatic LRU |
| App in-process LRU | < 0.1 ms | Manual / TTL |
| Redis / Memcached | 1-2 ms | Manual / TTL |
| CDN | edge RTT | Headers / purge |

The DB caches hot data automatically. The question is whether you can skip the DB entirely with a separate cache layer.

---

## Caching Strategies

## Q32. What is the cache-aside pattern?

**Answer:**

The most common cache pattern. The application reads from cache; on miss, reads from DB and populates the cache.

```python
def get_user(user_id):
    val = redis.get(f"user:{user_id}")
    if val:
        return json.loads(val)
    user = db.query("SELECT * FROM users WHERE id=%s", user_id)
    redis.setex(f"user:{user_id}", 300, json.dumps(user))
    return user

def update_user(user_id, data):
    db.execute("UPDATE users SET ... WHERE id=%s", user_id)
    redis.delete(f"user:{user_id}")  # invalidate
```

Simple, but writes can race: between the DB update and the cache delete, another reader may repopulate stale data.

## Q33. What is the difference between read-through, write-through, and write-back?

**Answer:**

| Pattern | Read path | Write path | Consistency |
| --- | --- | --- | --- |
| Cache-aside | App handles miss | App invalidates | Strong (with care) |
| Read-through | Cache fetches from DB | App writes to DB | Strong |
| Write-through | Cache fetches from DB | App writes both | Strong |
| Write-back | Cache fetches | Cache writes async to DB | Eventual |

Write-back is fastest but dangerous: a cache crash loses unflushed writes. Use only for non-critical data with replication.

## Q34. How do you invalidate the cache?

**Answer:**

There are several strategies, in increasing complexity:

```php
// 1. TTL only — eventual consistency
Cache::put("user:$id", $user, 300);

// 2. Explicit delete on write
DB::transaction(function() use ($user) {
    $user->save();
    Cache::forget("user:{$user->id}");
});

// 3. Versioned keys — bump version on write
Cache::put("user:$id:v" . $user->version, $user);

// 4. Tag-based purge
Cache::tags(["users", "user:$id"])->put($key, $val);
Cache::tags(["user:$id"])->flush();
```

Common bug: invalidating before the DB commit, so a reader caches stale data. Always invalidate after commit.

## Q35. How do you prevent a cache stampede?

**Answer:**

When a popular key expires, thousands of concurrent requests all hit the DB at once. Solutions:

```python
# Single-flight with a lock
def get_with_lock(key, ttl=300):
    val = redis.get(key)
    if val:
        return val
    if redis.set(f"lock:{key}", "1", nx=True, ex=10):
        try:
            val = db.query(...)
            redis.setex(key, ttl, val)
            return val
        finally:
            redis.delete(f"lock:{key}")
    else:
        time.sleep(0.1)
        return redis.get(key) or db.query(...)
```

Other patterns:
- Probabilistic early refresh: refresh slightly before expiry with rising probability
- Two-tier TTL: soft expiry triggers async refresh, hard expiry forces sync
- Stale-while-revalidate: serve stale, refresh in background

## Q36. How do you use a CDN as a query cache?

**Answer:**

For low-cardinality public read endpoints, set the HTTP cache headers and let the CDN serve almost all traffic:

```php
return response()->json($products)
    ->header('Cache-Control', 'public, max-age=60, stale-while-revalidate=300')
    ->header('Surrogate-Key', 'products');
```

The CDN serves 90 percent or more of requests with no DB hit. Use the `Surrogate-Key` header to purge by tag when products change. Do not cache personalized content at the CDN unless you partition by user.

---

## Connection Pooling

## Q37. Why is connection pooling critical?

**Answer:**

Each Postgres backend uses about 10 MB of RAM. 1000 raw connections is 10 GB just for connection overhead, plus context switching kills performance.

Pool sizing rule of thumb:

```
pool_size = (core_count * 2) + effective_spindle_count
```

For an 8-core SSD server, around 20 connections per app instance. Counterintuitively, more connections often means worse throughput because of contention.

```yaml
# pgbouncer.ini
[databases]
mydb = host=db port=5432

[pgbouncer]
pool_mode = transaction
default_pool_size = 20
max_client_conn = 1000
```

## Q38. PgBouncer pool modes — what are the trade-offs?

**Answer:**

| Mode | Description | Limits |
| --- | --- | --- |
| Session | Backend held for client's entire session | Same overhead as direct connections |
| Transaction | Backend held per transaction (default) | No session-level features (prepared statements pre-PG14, advisory locks across transactions) |
| Statement | Backend per statement | No multi-statement transactions |

Production default: transaction mode. Pool size matched to actual concurrent transactions, not concurrent users.

## Q39. What are the symptoms of pool exhaustion?

**Answer:**

- Latency spikes correlated with traffic spikes
- App logs show "timeout waiting for connection"
- DB CPU is low but the app is queueing
- A long-running transaction from a background job starves everyone

Detect:

```sql
-- Postgres: connections by state
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;

-- Long-running queries
SELECT pid, now() - query_start AS dur, state, query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY dur DESC;
```

Kill the rogue:

```sql
SELECT pg_terminate_backend(<pid>);
```

---

## Transactions and Concurrency

## Q40. How do transactions affect performance?

**Answer:**

Long transactions hold row and page locks, blocking other writers. In Postgres, they prevent vacuum from cleaning up dead tuples. In MySQL InnoDB they keep undo log entries around.

Bad pattern - HTTP call inside a transaction:

```php
DB::transaction(function () use ($order) {
    $order->save();
    Http::post('https://payment.example.com/charge', $payload);  // 2s
    $order->update(['status' => 'paid']);
});  // transaction held for 2+ seconds
```

Good - move I/O outside:

```php
DB::transaction(fn() => $order->save());
$response = Http::post('https://payment.example.com/charge', $payload);
DB::transaction(fn() => $order->update(['status' => 'paid']));
```

## Q41. What are the isolation levels and how do they affect performance?

**Answer:**

| Level | Read consistency | Write conflicts | Performance |
| --- | --- | --- | --- |
| Read Uncommitted | Sees uncommitted writes | Lots | Fastest, dirty reads |
| Read Committed | Per-statement snapshot | Some | Default Postgres |
| Repeatable Read | Per-transaction snapshot | Some | Default MySQL |
| Serializable | Full serial order | Highest abort rate | Slowest |

In Postgres, Serializable uses SSI and aborts conflicting transactions. In MySQL, Serializable adds gap locks, hurting concurrency further.

## Q42. When do you use SELECT FOR UPDATE?

**Answer:**

For pessimistic locking on mutually exclusive operations (transfers, inventory decrements):

```sql
BEGIN;
SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;  -- locks row
UPDATE accounts SET balance = balance - 50 WHERE id = 1;
COMMIT;
```

For high-contention scenarios, prefer optimistic locking:

```sql
UPDATE accounts
SET balance = balance - 50, version = version + 1
WHERE id = 1 AND version = 7;
-- If 0 rows updated, retry
```

---

## Partitioning and Sharding

## Q43. What is the difference between partitioning and sharding?

**Answer:**

| Aspect | Partitioning | Sharding |
| --- | --- | --- |
| Where | One DB instance | Multiple DB instances |
| Transparency | DB sees one logical table | App or proxy routes |
| Use case | Large tables, hot/cold data | Beyond single-server capacity |

Partitioning helps a single server. Sharding helps when one server is not enough.

## Q44. How do you partition tables in Postgres?

**Answer:**

Three strategies: range, list, and hash.

```sql
-- Range partitioning by time (most common)
CREATE TABLE events (
  id BIGSERIAL,
  created_at TIMESTAMPTZ NOT NULL,
  payload JSONB
) PARTITION BY RANGE (created_at);

CREATE TABLE events_2025_01 PARTITION OF events
  FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE events_2025_02 PARTITION OF events
  FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- Hash partitioning
CREATE TABLE users (...) PARTITION BY HASH (user_id);
CREATE TABLE users_p0 PARTITION OF users
  FOR VALUES WITH (modulus 16, remainder 0);
```

Benefits:
- Per-partition indexes (smaller, faster)
- Drop old partitions instantly instead of deleting 100M rows
- Partition pruning skips irrelevant partitions

Use `pg_partman` to auto-create future partitions.

## Q45. How do you choose a shard key?

**Answer:**

A bad shard key destroys you. Properties of a good shard key:

- High cardinality
- Even distribution (no hot shards)
- Aligned with most queries (so single-shard reads are common)
- Stable (does not change for a row)

| App type | Good shard key | Why |
| --- | --- | --- |
| User-data app | `user_id` | Most queries are per-user |
| Multi-tenant SaaS | `tenant_id` | Watch for one giant tenant |
| Time-series | composite (entity, time) | Pure time creates a hot shard |

Anti-patterns: sequential ID (last shard is always hot), country code (US dominates), status (only a few values).

## Q46. What is consistent hashing and why does it matter?

**Answer:**

With naive `hash(key) % N` sharding, adding a shard remaps almost every key. With consistent hashing, only `1/N` keys move.

```
Ring (0..2^32):
  Shard A: positions 100, 5000, 8000, ...
  Shard B: positions 800, 3000, 9000, ...
  Key K   hashes to 4500 -> belongs to Shard A's 5000 position
```

Used by: Redis Cluster, Cassandra, DynamoDB, Vitess. Pair with virtual nodes (each physical shard owns many ring positions) for better balance.

## Q47. How do you handle cross-shard queries?

**Answer:**

Options in order of preference:

1. **Avoid them**: design schema so 99 percent of queries hit one shard.
2. **Scatter-gather**: query all shards and merge results. Latency equals the slowest shard.
3. **Materialized index**: denormalize into a separate "global" lookup table.
4. **Search engine alongside**: push searchable data to Elasticsearch.
5. **Analytics pipeline**: ETL all shards into a warehouse like Snowflake or ClickHouse.

```python
# Scatter-gather example
async def get_orders_for_user(user_id):
    shards = [shard1, shard2, shard3, shard4]
    results = await asyncio.gather(*[
        s.query("SELECT * FROM orders WHERE user_id = %s", user_id)
        for s in shards
    ])
    return [row for shard in results for row in shard]
```

---

## 100M+ Row Tables

## Q48. What changes when a table crosses 50 million rows?

**Answer:**

- Full scans become unacceptable (minutes to hours)
- Index size starts pressuring buffer pool
- `ALTER TABLE` rewrites become a major operation (hours)
- Backup time grows linearly
- Single-row latency stays fast IF indexes are right

Operational changes:
- Use `pg_repack` or `pt-online-schema-change` for online migrations
- Add columns with default only on engines that support instant default (Postgres 11+, MySQL 8 InnoDB)
- Backfill in chunks
- Plan partitioning before crossing 100M

## Q49. Soft delete vs hard delete at scale.

**Answer:**

Soft delete (`deleted_at` column) is easy to recover from but every query must filter, and the index carries tombstones.

```sql
-- Bad: every query filters, full index includes deleted rows
SELECT * FROM users WHERE deleted_at IS NULL AND email = ?;
CREATE INDEX idx_users_email ON users(email);

-- Good: partial index excludes deleted rows
CREATE INDEX idx_users_email ON users(email)
WHERE deleted_at IS NULL;
```

Production hybrid:
- Soft delete with a 30-day retention
- Background job hard-deletes after retention
- Move expired data to an archive table or cold storage

## Q50. What is a good archiving strategy for old data?

**Answer:**

```
hot table (last 90d) -> warm table -> cold archive (S3) -> drop partition
```

Time-based partitioning makes archiving trivial:

```sql
-- Export a partition, then drop it
COPY events_2023_01 TO '/archive/events_2023_01.csv';
DROP TABLE events_2023_01;
```

For analytics, replicate to a columnar warehouse like ClickHouse, Redshift, or BigQuery.

## Q51. How do you do schema migrations on huge tables?

**Answer:**

Don't:

```sql
-- Full rewrite, hours of locks on large tables
ALTER TABLE huge ADD COLUMN x INT NOT NULL DEFAULT 0;
```

Do (Postgres 11+):

```sql
-- 1. Instant: add nullable column
ALTER TABLE huge ADD COLUMN x INT;

-- 2. Backfill in chunks
DO $$
DECLARE last_id BIGINT := 0;
BEGIN
  LOOP
    UPDATE huge SET x = 0
    WHERE id > last_id AND id <= last_id + 10000;
    EXIT WHEN NOT FOUND;
    last_id := last_id + 10000;
    PERFORM pg_sleep(0.05);
  END LOOP;
END $$;

-- 3. Add NOT NULL (instant in PG12+)
ALTER TABLE huge ALTER COLUMN x SET NOT NULL;
```

For complex changes, use `pg-osc`, `gh-ost` (MySQL), or `pt-online-schema-change`.

---

## Replication

## Q52. What are the Postgres replication modes?

**Answer:**

| Mode | Latency | Durability | Use |
| --- | --- | --- | --- |
| Async streaming | Low | Loss possible on primary failure | Default |
| Synchronous | Higher | Two-node durability | Financial / critical |
| Logical | Per-table | Selective | Heterogeneous, zero-downtime upgrades |

Synchronous replication waits for at least one replica to acknowledge before commit returns:

```ini
# postgresql.conf on primary
synchronous_commit = on
synchronous_standby_names = 'replica1,replica2'
```

This adds 1-2 ms per commit but guarantees no data loss on primary failure.

## Q53. What are the MySQL replication modes?

**Answer:**

- **Statement-based**: small log, but non-deterministic statements like `NOW()` or `UUID()` misbehave.
- **Row-based**: larger log, exact, default since 5.7.
- **Mixed**: statement when safe, row otherwise.

For replicas falling behind, parallelize the apply:

```ini
# my.cnf on replica
slave_parallel_workers = 8
slave_parallel_type = LOGICAL_CLOCK
```

## Q54. What causes replication lag and how do you monitor it?

**Answer:**

Causes:
- Long transactions on primary (replica must replay each one)
- Slow queries on replica blocking apply
- Network bottleneck
- Single-thread apply on older MySQL

Monitor:

```sql
-- Postgres on replica
SELECT now() - pg_last_xact_replay_timestamp() AS lag;

-- MySQL
SHOW SLAVE STATUS \G
-- Watch Seconds_Behind_Master
```

Alert if lag exceeds 5 seconds for OLTP traffic.

---

## Server Tuning

## Q55. What are the key Postgres tuning parameters?

**Answer:**

| Parameter | Description | Typical |
| --- | --- | --- |
| `shared_buffers` | Postgres internal cache | 25% of RAM |
| `effective_cache_size` | Hint of total cache (OS+PG) | 50-75% of RAM |
| `work_mem` | Per-operation sort/hash memory | 4-64 MB |
| `maintenance_work_mem` | For VACUUM, CREATE INDEX | 256 MB - 2 GB |
| `wal_buffers` | WAL buffer | 16 MB |
| `random_page_cost` | SSD = 1.1, spinning = 4 | 1.1 (SSD) |
| `effective_io_concurrency` | Async I/O depth | 200 (SSD) |

Example for a 32 GB server:

```ini
shared_buffers = 8GB
effective_cache_size = 24GB
work_mem = 32MB
maintenance_work_mem = 2GB
random_page_cost = 1.1
effective_io_concurrency = 200
```

## Q56. How do you tune autovacuum on high-write tables?

**Answer:**

Default autovacuum is too lazy for big, high-write tables. Bloat grows.

Global tuning:

```ini
autovacuum_vacuum_scale_factor = 0.05    # default 0.2
autovacuum_analyze_scale_factor = 0.02
autovacuum_vacuum_cost_limit = 2000      # default 200
autovacuum_naptime = 30s
```

Per-table:

```sql
ALTER TABLE big_table SET (
  autovacuum_vacuum_scale_factor = 0.01,
  fillfactor = 90
);
```

Symptoms of bad autovacuum:
- Bloat growing over time
- Wraparound warnings (`age(datfrozenxid)` near 200M)
- Query plans degrading

## Q57. What are the key MySQL InnoDB tuning parameters?

**Answer:**

| Parameter | Description | Typical |
| --- | --- | --- |
| `innodb_buffer_pool_size` | Cache for data and index | 50-75% of RAM |
| `innodb_log_file_size` | Redo log size | 1-4 GB |
| `innodb_flush_log_at_trx_commit` | 1 = full ACID; 2 = slight risk, faster | 1 |
| `innodb_flush_method` | I/O method | O_DIRECT |
| `innodb_io_capacity` | Disk IOPS hint | 2000+ for SSD |
| `innodb_buffer_pool_instances` | For very large pools | 8 |

Example for a 32 GB server:

```ini
innodb_buffer_pool_size = 24G
innodb_log_file_size = 2G
innodb_flush_log_at_trx_commit = 1
innodb_flush_method = O_DIRECT
innodb_io_capacity = 4000
```

## Q58. How do you size `work_mem` in Postgres?

**Answer:**

`work_mem` is per-sort-or-hash, per-backend. A query with three sorts uses three times `work_mem`. Total possible memory is `work_mem × max_connections × ops_per_query`.

For 1 GB headroom, 100 connections, 3 ops per query: `work_mem = 3 MB`.

Better: keep `work_mem` modest (8-16 MB) globally and override for analytical sessions:

```sql
-- Per-session boost for a heavy report
SET work_mem = '512MB';
SELECT ... GROUP BY ... ORDER BY ...;
```

## Q59. How does parallelism work in Postgres?

**Answer:**

Postgres supports parallel sequential scan, parallel hash join, and parallel aggregate.

```ini
max_worker_processes = 16
max_parallel_workers = 8
max_parallel_workers_per_gather = 4
parallel_setup_cost = 1000
parallel_tuple_cost = 0.1
min_parallel_table_scan_size = 8MB
```

Parallel only triggers above the table size threshold. Small tables stay serial. Inspect with `EXPLAIN`:

```
Gather  (cost=... rows=...)
  Workers Planned: 4
  ->  Parallel Seq Scan on big_table
```

---

## Monitoring and Slow Queries

## Q60. What should the slow query log capture?

**Answer:**

Postgres:

```ini
log_min_duration_statement = 200    # log queries > 200 ms
log_temp_files = 0                  # any spill to disk
log_lock_waits = on
log_checkpoints = on

# Auto-explain logs the plan automatically
shared_preload_libraries = 'auto_explain'
auto_explain.log_min_duration = 500
auto_explain.log_analyze = on
```

MySQL:

```ini
slow_query_log = ON
long_query_time = 0.2
log_queries_not_using_indexes = ON
```

Aggregate with `pg_stat_statements` (Postgres) or `performance_schema` (MySQL).

## Q61. How do you find your top slow queries with `pg_stat_statements`?

**Answer:**

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

Focus on `total_exec_time`. A 1 ms query called 10 million times causes more pain than a 1-second query called 100 times.

## Q62. How do you find lock contention?

**Answer:**

```sql
-- Postgres: who is blocking whom
SELECT
  blocked.pid AS blocked_pid,
  blocked.usename AS blocked_user,
  blocking.pid AS blocking_pid,
  blocking.usename AS blocking_user,
  blocked.query AS blocked_query,
  blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking
  ON blocking.pid = ANY(pg_blocking_pids(blocked.pid));
```

Red flags:
- Long `idle in transaction` sessions — investigate the app code
- `AccessExclusiveLock` on a popular table — DDL during traffic

---

## OLTP vs OLAP

## Q63. Why does mixing OLTP and OLAP on the same DB hurt?

**Answer:**

OLTP is many small, fast transactions. OLAP is few huge analytical queries. If they share a buffer pool:

- OLAP loads 100 GB into the buffer, evicting OLTP hot data, causing user-facing latency spikes
- OLAP holds long transactions, preventing vacuum, causing bloat
- OLAP locks block OLTP

Solutions:
- Dedicated read replica for analytics
- ETL to a warehouse (Snowflake, BigQuery, ClickHouse, DuckDB)
- Materialized views refreshed periodically

## Q64. When and how do you use materialized views?

**Answer:**

Use for expensive aggregations queried many times.

```sql
CREATE MATERIALIZED VIEW daily_revenue AS
SELECT date_trunc('day', created_at) AS day,
       SUM(total) AS revenue
FROM orders
GROUP BY 1;

CREATE UNIQUE INDEX ON daily_revenue (day);

-- Refresh without locking readers
REFRESH MATERIALIZED VIEW CONCURRENTLY daily_revenue;
```

For continuous freshness, use incremental refresh tools like `pg_ivm`, or maintain a rollup table via triggers.

---

## Maintenance

## Q65. How does backup affect a live primary?

**Answer:**

`pg_dump` runs in a long transaction, blocking vacuum and causing bloat. For large DBs:

- Run `pg_basebackup` from a replica, not the primary
- Or `pg_dump --jobs=N --format=directory` for parallelism
- Or filesystem-level snapshots (ZFS, EBS) — fastest, but need `pg_start_backup`/`pg_stop_backup`

For MySQL, use `xtrabackup` for online physical backups without locks.

## Q66. How do you rebuild an index without downtime?

**Answer:**

```sql
-- Postgres 12+
REINDEX INDEX CONCURRENTLY idx_orders_user;

-- Or pg_repack from the command line
pg_repack -t orders -j 4 mydb
```

Anti-pattern: dropping and recreating an index during traffic. Queries that used the old index will degrade until the rebuild finishes.

---

## Production Issues

## Q67. "Suddenly all queries are slow" — what do you check?

**Answer:**

Checklist in order:

1. Recent deploy? Roll back or check new code paths
2. CPU or I/O saturation? Check `iostat`, `top`
3. Connection pool exhausted? Check `pg_stat_activity`
4. Long-running query holding locks? Kill it
5. Vacuum or autovacuum running? Wait or raise resources
6. Disk full? Check `df -h`
7. Replica promoted unexpectedly? Check current primary

```sql
-- Quick health check
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
SELECT pg_size_pretty(pg_database_size(current_database()));
```

## Q68. "Some queries are fast, then suddenly slow" — what's happening?

**Answer:**

This is usually a plan flip. The planner picked a different plan because:

- Statistics changed (auto-analyze ran after a bulk write)
- Prepared statement parameter sniffing (Postgres uses generic plan after 5 executions)
- Different data shape — querying a user with 1M rows uses a different plan than one with 10

Fix:

```sql
-- Force custom plans every time
SET plan_cache_mode = 'force_custom_plan';

-- Refresh stats
ANALYZE big_table;

-- Add an index that's optimal for both shapes
CREATE INDEX idx_x_y ON t (x, y);
```

## Q69. "DB looks healthy but the app is slow" — where do you look?

**Answer:**

The DB is fast but the app sees latency:

- App-side connection pool too small — request queueing in the app
- Network latency between app and DB (cross-AZ, VPN)
- TLS handshake on every connection — use connection pooling and persistent connections
- DNS lookup on every connection — cache or use IP
- ORM is doing N+1 even though each query is fast
- Slow JSON serialization on the app side

```php
// Bad: opens a new connection per request
foreach ($items as $item) {
    DB::connection('reports')->select(...);  // reconnects often
}
```

## Q70. How do you handle disk space exhaustion in Postgres?

**Answer:**

Symptoms: WAL fills disk, replication breaks, primary refuses writes.

Common causes:
- WAL retention too high or replication slot held by a dead replica
- Disabled autovacuum so bloat grows forever
- Long-running transaction prevents WAL recycle
- Logical replication slot inactive, accumulating WAL

Recovery:

```sql
-- Find inactive slots
SELECT slot_name, active, restart_lsn
FROM pg_replication_slots WHERE NOT active;

-- Drop a dead slot (be careful)
SELECT pg_drop_replication_slot('dead_replica');

-- Find long transactions
SELECT pid, now() - xact_start AS dur, query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY dur DESC;
```

## Q71. How do you handle hot row contention?

**Answer:**

Counter-style updates on one row create a serialization point.

Bad:

```sql
-- 10k req/s all hitting the same row -> lock queue
UPDATE counters SET count = count + 1 WHERE id = 1;
```

Sharded counter:

```sql
CREATE TABLE counters (
  bucket SMALLINT,
  count BIGINT,
  PRIMARY KEY (bucket)
);

-- Writer picks a random bucket
UPDATE counters SET count = count + 1
WHERE bucket = floor(random() * 16);

-- Reader sums all buckets
SELECT SUM(count) FROM counters;
```

Or use Redis for the increment and persist asynchronously:

```php
$total = Redis::incr("post:$id:views");
if ($total % 100 === 0) {
    Posts::where('id', $id)->update(['views' => $total]);
}
```

## Q72. When do you use JSONB and what are the pitfalls?

**Answer:**

Use JSONB when the schema is genuinely flexible (custom user fields, extensible event payload), or when some query reads inside the document.

```sql
CREATE TABLE events (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL,
  event_type TEXT NOT NULL,
  payload JSONB
);

-- GIN index for key existence and contains queries
CREATE INDEX idx_events_payload ON events USING GIN (payload);

-- Query
SELECT * FROM events WHERE payload @> '{"button": "checkout"}';
```

Pitfalls:
- JSONB key extraction is slower than dedicated columns
- GIN indexes are heavier than B-tree
- TOAST'd JSONB causes extra reads
- ORM eager-loading JSON fields can blow up bandwidth

Best practice: extract frequently queried keys to dedicated columns, keep tail data in JSONB.

## Q73. Does NULL hurt performance?

**Answer:**

NULL itself is cheap to store. But:

- `WHERE col IS NULL` may not use an index unless it's a partial index
- `NOT IN (subquery with NULL)` returns no rows, a common bug
- NULL semantics in joins surprise people

```sql
-- Common bug: returns no rows if any user_id is NULL
SELECT * FROM products
WHERE user_id NOT IN (SELECT user_id FROM blocked_users);

-- Correct
SELECT * FROM products p
WHERE NOT EXISTS (
  SELECT 1 FROM blocked_users b WHERE b.user_id = p.user_id
);
```

If a column is semantically never null, declare `NOT NULL` for better stats and plans.

## Q74. What does this query do? (Common interview trap)

**Answer:**

```sql
SELECT u.id FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE o.id IS NULL;
```

It returns users with no orders. The `LEFT JOIN` plus `IS NULL` is the classic anti-join idiom. Equivalent:

```sql
SELECT id FROM users u
WHERE NOT EXISTS (
  SELECT 1 FROM orders o WHERE o.user_id = u.id
);
```

Postgres usually generates the same plan for both. MySQL historically prefers `NOT EXISTS`.

## Q75. How would you scale a database to 10x traffic?

**Answer:**

Walk through the steps in order, from cheapest to most complex:

1. Measure current bottleneck (CPU, I/O, connections, latency by query)
2. Optimize the top 5 slow queries (often 80% of load)
3. Cache hot reads (Redis, application cache)
4. Add read replicas for read scaling
5. Add a connection pooler (PgBouncer, ProxySQL)
6. Vertical scale (bigger box)
7. Async non-critical writes (queues)
8. Partition huge tables
9. Shard only when one box cannot keep up
10. Move analytics off to a warehouse

Each step buys time before the next, in increasing operational complexity.

---

## Appendix — Index Decision Cheat Sheet

| Query pattern | Recommended index |
| --- | --- |
| `WHERE a = ?` | `(a)` |
| `WHERE a = ? AND b = ?` | `(a, b)` |
| `WHERE a = ? ORDER BY b` | `(a, b)` |
| `WHERE a = ? AND b > ? ORDER BY b` | `(a, b)` |
| `WHERE a IN (...)` | `(a)` |
| `LIKE 'abc%'` | B-tree `(col text_pattern_ops)` in PG |
| `LIKE '%abc%'` | trigram (`pg_trgm`) GIN |
| JSONB key | GIN on `(jsonb_col)` |
| Geospatial | GiST |
| Full-text | GIN on `tsvector` |

---

## Appendix — Latency Reference Numbers

| Operation | Time |
| --- | --- |
| L1 cache | 0.5 ns |
| L2 cache | 7 ns |
| Main memory | 100 ns |
| SSD random read | 100 µs |
| Same-AZ network round-trip | 0.5 ms |
| HDD random read | 10 ms |
| Cross-region round-trip | 100+ ms |
| HTTP API call | 50-500 ms |

If your DB is on SSD in the same AZ, even a "cold" indexed lookup is under 1 ms. If a query takes 100 ms, something is doing many disk reads, scanning large data, or contending for a lock.
