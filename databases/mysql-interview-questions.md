# MySQL Interview Questions — Basic to Advanced

**Purpose:** Senior-level MySQL knowledge for interviews. Covers engines, replication, transactions, indexes, performance tuning, and operations.

---

## Table of Contents

1. [MySQL Basics](#mysql-basics)
2. [Storage Engines](#storage-engines)
3. [Indexes in MySQL](#indexes-in-mysql)
4. [Transactions and Locking](#transactions-and-locking)
5. [Query Optimization](#query-optimization)
6. [Replication](#replication)
7. [High Availability and Scaling](#high-availability-and-scaling)
8. [Backup and Recovery](#backup-and-recovery)
9. [MySQL vs Other Databases](#mysql-vs-other-databases)
10. [Operational Topics](#operational-topics)

---

## MySQL Basics

### Q1. What is MySQL?

Open-source relational database management system. Originally by MySQL AB, now owned by Oracle. Pluggable storage engine architecture (InnoDB default since 5.5). MariaDB is a community fork.

---

### Q2. What's new in MySQL 8?

- Default character set: `utf8mb4` (full unicode)
- Window functions
- CTEs and recursive CTEs
- JSON improvements
- Atomic DDL
- Roles for permissions
- Default authentication: `caching_sha2_password`
- Better optimizer (histograms, hash joins)
- No more `SHOW SLAVE STATUS` → use `SHOW REPLICA STATUS`

---

### Q3. Differences between MySQL and MariaDB?

| Feature | MySQL | MariaDB |
|---------|-------|---------|
| Owner | Oracle | Community |
| License | GPL + commercial | GPL |
| Default storage engine | InnoDB | InnoDB (Aria for tmp) |
| JSON | Native + functions | Native + JSON_TABLE earlier |
| Threading | One-thread-per-connection | Same + thread pool by default |
| Sequences | No | Yes |
| Window functions | 8.0+ | 10.2+ |

In most projects, they're swappable. Pick one and stick with it.

---

### Q4. Common MySQL data types and gotchas?

| Type | Notes |
|------|-------|
| `INT` | 4 bytes, signed range ±2B |
| `BIGINT` | 8 bytes, for large IDs |
| `VARCHAR(N)` | Up to N characters; storage variable |
| `TEXT` | Up to 64KB |
| `MEDIUMTEXT/LONGTEXT` | Larger but slower |
| `DECIMAL(M,D)` | Exact, for money |
| `FLOAT/DOUBLE` | NEVER for money |
| `DATETIME` | 8 bytes, no timezone |
| `TIMESTAMP` | 4 bytes, stored as UTC, auto-converts |
| `JSON` | Native JSON since 5.7 |
| `ENUM` | Compact but rigid; avoid for evolving schemas |

**Gotcha:** `VARCHAR(255)` is a habit, but real columns should use the right size. UTF8MB4 takes 4 bytes per char.

---

### Q5. What is the difference between CHAR and VARCHAR?

- `CHAR(N)` — fixed length, padded with spaces
- `VARCHAR(N)` — variable length, max N

Use CHAR for truly fixed-length data (country codes, MD5 hashes). Use VARCHAR for variable text.

---

## Storage Engines

### Q6. What are the main MySQL storage engines?

| Engine | Use case |
|--------|----------|
| InnoDB (default) | OLTP, transactions, row-level locks, foreign keys |
| MyISAM | Legacy, no transactions, table-level locks, smaller |
| MEMORY | In-RAM, fast, lost on restart |
| Archive | Insert-only, compressed |
| CSV | Plaintext storage |
| BLACKHOLE | /dev/null, used for replication routing |

**99% of modern apps use InnoDB.**

---

### Q7. Why InnoDB over MyISAM?

- ACID transactions
- Row-level locking (vs MyISAM's table-level)
- Foreign keys
- Crash recovery via WAL
- Better performance under concurrent writes
- Online DDL (mostly)

MyISAM is faster for read-only / bulk-insert workloads but has no concurrency guarantees.

---

### Q8. What is the InnoDB buffer pool?

Memory area where InnoDB caches table and index data. Most important MySQL performance setting:

```
innodb_buffer_pool_size = 70-80% of RAM (on dedicated DB server)
```

If your dataset fits in the buffer pool, queries are cached in RAM. If not, disk reads dominate.

---

### Q9. What is the InnoDB redo log?

A circular write-ahead log. Every change is written there first, then to the actual data files. On crash, MySQL replays the redo log to recover.

```
innodb_log_file_size  -- size of each redo log file
innodb_log_files_in_group -- count
```

Larger redo log → less frequent flushes → better write throughput, slower recovery.

---

### Q10. What is the undo log?

Stores old versions of changed rows. Used for:
- Rollback
- MVCC (consistent reads see old version while another transaction modifies)

Long-running transactions can bloat the undo log, slow down the system.

---

## Indexes in MySQL

### Q11. What index types does MySQL support?

- B-tree (default in InnoDB)
- Hash (in MEMORY engine, and adaptive hash inside InnoDB)
- Spatial (R-tree)
- Full-text

---

### Q12. What is a clustered index?

In InnoDB, the table itself is stored as a B-tree on the **primary key**. The data IS the index leaves.

Effects:
- Lookups by primary key are fastest
- Secondary indexes store the primary key (not row pointer); two lookups for non-PK queries
- Random insert order on PK = fragmentation; use sequential PKs (auto-increment, ULID-with-time)

---

### Q13. Should I use AUTO_INCREMENT or UUID for primary keys?

| AUTO_INCREMENT (BIGINT) | UUID |
|-------------------------|------|
| Compact (8 bytes) | Larger (16 bytes binary, 36 chars text) |
| Sequential (good for clustered index) | Random (page splits, fragmentation) |
| Predictable (security concern for public IDs) | Hard to guess |
| Single-DB (replication-safe with care) | Globally unique |

**Compromise:** UUID v7 / ULID — time-ordered UUIDs that combine sequential benefits with globally unique IDs.

For most internal IDs: BIGINT auto-increment. For public-facing IDs (URLs, API): UUID/ULID.

---

### Q14. What's a covering index in MySQL?

Index containing all columns the query needs.

```sql
SELECT id, status FROM orders WHERE user_id = ?;

-- Covering composite index
CREATE INDEX idx_orders_user_status ON orders (user_id, status, id);
```

`EXPLAIN` shows `Using index` (no row lookup needed). Very fast.

---

### Q15. Can I have too many indexes?

Yes. Every index:
- Adds storage
- Slows INSERT/UPDATE/DELETE (must update each index)
- Adds optimizer overhead

Balance: index what's needed for read patterns, drop what's unused. Check `sys.schema_unused_indexes`.

---

## Transactions and Locking

### Q16. Default isolation level in MySQL InnoDB?

**REPEATABLE READ.**

This is stricter than Postgres's default (READ COMMITTED). With REPEATABLE READ + InnoDB's MVCC + gap locks, you get behavior close to serializable for many cases.

---

### Q17. What is a gap lock?

InnoDB locks not just the row but the gap between rows. Prevents phantom inserts.

```sql
-- TX1
SELECT * FROM users WHERE age > 30 FOR UPDATE;

-- TX2 (blocked even though no specific row matches)
INSERT INTO users (age) VALUES (35);
```

Gap locks can cause unexpected blocking. Tune isolation level if it's a problem.

---

### Q18. What's the difference between SHARE MODE and FOR UPDATE?

```sql
SELECT * FROM accounts WHERE id = 1 LOCK IN SHARE MODE;  -- shared lock (others can read but not write)
SELECT * FROM accounts WHERE id = 1 FOR UPDATE;          -- exclusive lock (others wait)
```

Use `FOR UPDATE` for read-then-modify patterns. Use `SHARE MODE` to ensure data doesn't change during read.

---

### Q19. How does MySQL handle deadlocks?

InnoDB detects deadlocks automatically and aborts one transaction with `ERROR 1213`. App must retry.

```js
async function withDeadlockRetry(fn, maxAttempts = 3) {
  for (let i = 0; i < maxAttempts; i++) {
    try {
      return await fn();
    } catch (e) {
      if (e.errno === 1213 && i < maxAttempts - 1) continue;
      throw e;
    }
  }
}
```

**Prevention:** acquire locks in deterministic order; keep transactions short.

---

### Q20. What is auto-commit in MySQL?

By default, every statement is its own transaction (auto-commit ON).

To group statements:
```sql
BEGIN;
  -- multiple statements
COMMIT;
-- or
ROLLBACK;
```

Or set `autocommit = 0` and use explicit COMMIT.

---

## Query Optimization

### Q21. What does EXPLAIN show in MySQL?

```sql
EXPLAIN SELECT * FROM orders WHERE user_id = 123;
```

Key columns:
- `type` — `const`, `eq_ref`, `ref`, `range`, `index`, `ALL` (worst). Aim for `range` or better.
- `key` — index used (or NULL)
- `rows` — estimated rows examined
- `filtered` — % of rows that satisfy WHERE after filtering
- `Extra` — `Using index` (covering, good), `Using filesort` (sort, bad if large), `Using temporary` (intermediate table, often bad)

`EXPLAIN ANALYZE` (8.0+) actually runs the query and shows real timings.

---

### Q22. Common slow query patterns in MySQL?

| Pattern | Issue | Fix |
|---------|-------|-----|
| `WHERE column LIKE '%abc'` | No index use | Reverse column or full-text |
| `WHERE func(column) = ?` | Index ignored | Functional index (8.0+) or normalize |
| `WHERE str_col = 123` | Implicit cast, index may be ignored | Match types |
| `OR` across columns | May seq scan | UNION with separate indexed queries |
| `LIMIT N OFFSET M` for big M | Reads all M+N | Cursor-based pagination |
| `SELECT *` | Always reads all columns | Select what you need |

---

### Q23. What is the slow query log?

```ini
slow_query_log = 1
long_query_time = 1.0   -- log queries > 1s
log_queries_not_using_indexes = 1
```

Analyze with `pt-query-digest` (Percona Toolkit). Find top offenders by total time, not single-query time.

---

### Q24. How do you analyze a real slow query?

1. Run `EXPLAIN` to see the plan
2. Run `EXPLAIN ANALYZE` (8.0+) for actual timings
3. Check if expected indexes are used
4. Look at `Extra` column — `Using filesort`, `Using temporary` are warning signs
5. Profile session-level: `SET SESSION optimizer_trace = 'enabled=on';` and inspect `INFORMATION_SCHEMA.OPTIMIZER_TRACE`
6. Consider rewriting (subquery → JOIN, EXISTS instead of IN, etc.)

---

### Q25. What is index hint in MySQL?

Force the optimizer to use (or avoid) a specific index:

```sql
SELECT * FROM orders FORCE INDEX (idx_user_id) WHERE user_id = 123;
SELECT * FROM orders IGNORE INDEX (idx_status) WHERE status = 'pending';
```

Use sparingly; the optimizer usually knows best. Hints become technical debt as data shape changes.

---

### Q26. What is query cache and why was it removed?

Older MySQL had a query cache that cached full result sets. Removed in 8.0 because:
- Single mutex bottleneck under concurrency
- Invalidation was too aggressive (any write to table cleared cache)
- Modern app-level caching (Redis, memcached) is much better

---

## Replication

### Q27. How does MySQL replication work?

Primary writes to **binary log** (binlog). Replicas have an I/O thread that pulls binlog events, and a SQL thread that replays them locally.

```
Primary [binlog] → I/O thread → [relay log] → SQL thread → Replica DB
```

---

### Q28. Replication formats?

- **STATEMENT-based:** logs the SQL statements. Smaller, but non-deterministic statements (NOW(), UUID()) are unsafe.
- **ROW-based:** logs the actual row changes. Deterministic but larger.
- **MIXED:** statement when safe, row otherwise. Default since 5.7.

For modern setups, ROW is most common.

---

### Q29. What is GTID (Global Transaction Identifier)?

A unique ID per transaction across the cluster. Replaces the older binlog file/position tracking.

Benefits:
- Failover is simpler (replica knows what it has applied via GTID set)
- Replicas can be re-pointed to a new primary easily

```ini
gtid_mode = ON
enforce_gtid_consistency = ON
```

---

### Q30. Synchronous vs Asynchronous vs Semi-synchronous replication?

| Type | Behavior |
|------|----------|
| Async (default) | Primary commits immediately, replica catches up later (may lose data on crash) |
| Semi-sync | Primary waits for at least one replica to acknowledge receipt before committing |
| Group replication | Synchronous-ish, multi-primary capable, uses Paxos-like protocol |

Semi-sync gives durability across replicas at modest latency cost. Group replication for HA clusters.

---

### Q31. How do you handle replica lag?

- **Detect:** monitor `Seconds_Behind_Source` in `SHOW REPLICA STATUS`. Tools: pt-heartbeat (more accurate).
- **Causes:** primary write spike, single-threaded replication, replica resource contention, big transactions.
- **Mitigate:**
  - Multi-threaded replication (`replica_parallel_workers`)
  - Resize replicas
  - Avoid huge transactions
  - Skip read traffic to lagged replica until caught up

---

## High Availability and Scaling

### Q32. How do you achieve high availability with MySQL?

**Common patterns:**

1. **Primary + replicas + automatic failover:** orchestrators like MHA (deprecated), Orchestrator, ProxySQL/MaxScale.
2. **Group Replication:** built-in multi-primary with consensus.
3. **InnoDB Cluster:** combines Group Replication + MySQL Router + MySQL Shell for full HA.
4. **Galera Cluster (MariaDB):** synchronous multi-master.
5. **Cloud-managed:** RDS, Aurora — they handle failover.

---

### Q33. How do you scale reads?

Add read replicas. Route read queries to replicas, writes to primary.

**Considerations:**
- Replica lag may serve stale data
- Some queries need primary (read-after-write)
- Connection routing logic in app or via proxy

---

### Q34. How do you scale writes beyond a single primary?

- **Vertical:** bigger machine
- **Sharding:** split data across multiple DBs by user_id or some key
- **Functional split:** separate DBs per service
- **Group Replication multi-primary:** limited use, conflict resolution required

Sharding is the most powerful and most complex.

---

### Q35. What is connection pooling for MySQL?

Application maintains a pool of pre-opened connections. Common in Node.js (`mysql2/promise`), PHP (PDO with persistent), Java (HikariCP).

For very high concurrency: use a dedicated proxy like ProxySQL — it pools at network layer, multiplexes app connections to fewer backend connections.

---

## Backup and Recovery

### Q36. How do you back up MySQL?

| Tool | Type | Notes |
|------|------|-------|
| `mysqldump` | Logical | Smaller dataset, slow for big DB |
| `mysqlpump` | Logical | Multi-threaded |
| Percona XtraBackup | Physical | Hot backup, no lock for InnoDB |
| Filesystem snapshot (LVM, EBS) | Physical | Requires brief lock |

For production: physical backups (XtraBackup) + binlogs for point-in-time recovery.

---

### Q37. Point-in-time recovery (PITR)?

1. Restore latest full backup
2. Apply binlogs up to a specific time

```bash
mysqlbinlog --start-datetime="2025-01-01 00:00:00" \
            --stop-datetime="2025-01-01 14:30:00" \
            mysql-bin.* | mysql
```

Allows recovering to a moment just before a bad operation (DELETE without WHERE, etc.).

---

### Q38. How do you test backups?

**The golden rule:** A backup you have not restored is hope, not a backup.

- Automate weekly restore tests in a non-prod environment
- Verify row counts, recent data, app functionality
- Time the restore (you need to know recovery time)

---

## MySQL vs Other Databases

### Q39. MySQL vs PostgreSQL?

| Feature | MySQL | PostgreSQL |
|---------|-------|------------|
| Default isolation | REPEATABLE READ | READ COMMITTED |
| JSON | Good | Excellent (JSONB indexes) |
| Window functions | 8.0+ | Always |
| Materialized views | No | Yes |
| Procedural language | SQL/PSM | PL/pgSQL, PL/Python, etc. |
| Full-text search | Built-in | Built-in |
| Foreign keys | InnoDB only | Yes |
| Geospatial | OK | Excellent (PostGIS) |
| Replication | Mature | Mature, more flexible |
| Performance for simple OLTP | Excellent | Excellent |

**Modern senior take:** Postgres is generally the more "feature-complete" choice for new projects. MySQL still dominates in many shops due to ecosystem and operational familiarity.

---

### Q40. When would you choose MySQL?

- Existing MySQL infra and team expertise
- Very high read throughput on simple queries
- Vitess for sharding at YouTube scale
- WordPress / PHP ecosystem
- AWS Aurora MySQL for managed scale

---

## Operational Topics

### Q41. What is `mysqldump` and its limitations?

```bash
mysqldump -u root -p mydb > dump.sql
mysqldump --single-transaction mydb > dump.sql  -- consistent snapshot for InnoDB
```

Limitations:
- Slow for large databases
- Exports are SQL — restoring is slow
- May lock tables for MyISAM

For TB-size databases, use XtraBackup.

---

### Q42. How do you change a column on a huge table without locking?

**Options:**

1. **Online DDL** (8.0): many DDL operations are non-blocking
   ```sql
   ALTER TABLE orders ADD COLUMN status VARCHAR(20), ALGORITHM=INPLACE, LOCK=NONE;
   ```
2. **`pt-online-schema-change`** (Percona): creates a copy, syncs via triggers, swaps
3. **`gh-ost`** (GitHub's tool): similar but uses binlog instead of triggers

For 100M+ row tables, use gh-ost or pt-osc. They take longer but don't block.

---

### Q43. How do you find unused indexes?

```sql
SELECT *
FROM sys.schema_unused_indexes;
```

Or check `performance_schema.table_io_waits_summary_by_index_usage` for indexes with 0 reads.

Drop unused indexes to speed up writes and reduce storage.

---

### Q44. How do you monitor MySQL?

| Metric | Why |
|--------|-----|
| Connections | Spikes indicate app issues |
| Slow queries | Performance regressions |
| Replica lag | Data freshness |
| Buffer pool hit rate | If <99%, increase buffer pool |
| Innodb row lock waits | Concurrency issues |
| Disk I/O | Bottleneck indicator |
| Query rate (QPS) | Baseline vs anomaly |
| Error rate | Auth failures, deadlocks |

Tools: Percona Monitoring (PMM), Datadog, Prometheus + mysqld_exporter, AWS RDS Performance Insights.

---

### Q45. What's `SHOW PROCESSLIST` for?

Shows currently running queries:

```sql
SHOW FULL PROCESSLIST;
```

Or `SELECT * FROM performance_schema.processlist;` for more detail.

Useful when:
- Debugging hung queries
- Spotting long-running transactions
- Finding blocking queries

```sql
KILL <process_id>;  -- terminate a query
```

---

### Q46. Best practices for production MySQL?

- **InnoDB everywhere.**
- **Buffer pool 70-80% of RAM** on dedicated DB.
- **Enable slow query log**, review weekly.
- **Use parameterized queries.** No string concatenation.
- **Always have backups** — full + binlog.
- **Test restores quarterly.**
- **Monitor replica lag.**
- **Avoid MyISAM, query cache (gone in 8), `SELECT COUNT(*)` on huge InnoDB tables.**
- **Set proper character set:** `utf8mb4`.
- **Connection pool** at the app or proxy level.
- **Don't store files in DB** — use object storage.

---

### Q47. What is `innodb_flush_log_at_trx_commit`?

Controls durability vs performance:

| Value | Behavior |
|-------|----------|
| 1 (default) | Flush + sync to disk on every commit. ACID-compliant. |
| 2 | Flush to OS cache on commit, sync once per second. May lose ~1s on OS crash. |
| 0 | Sync once per second. May lose ~1s on MySQL or OS crash. |

Production: keep at 1 unless you've verified durability is not critical.

---

### Q48. What's the difference between `OPTIMIZE TABLE` and `ANALYZE TABLE`?

- `ANALYZE TABLE` — updates index statistics (cheap, safe to run regularly)
- `OPTIMIZE TABLE` — rebuilds the table to reclaim space and defragment (expensive, locks the table on older versions; uses online DDL on newer)

Run `ANALYZE` after big data changes. Run `OPTIMIZE` rarely, only when you know fragmentation is a problem.

---

## Real Interview Scenarios

### Scenario 1: "We just got hit with a slow query, the app is timing out."

**Senior approach:**
1. `SHOW PROCESSLIST` — find the slow query
2. `KILL` it if blocking everything else
3. `EXPLAIN` the query — find missing index
4. Add the index (online if possible)
5. Long-term: slow query log alerts so this doesn't happen silently next time

---

### Scenario 2: "Replica lag is 5 hours."

**Senior approach:**
1. Check `SHOW REPLICA STATUS` for what's replaying
2. Common cause: huge UPDATE or ALTER TABLE on primary
3. If replica is read-routed, fail back reads to primary temporarily
4. Wait for catchup, or rebuild replica from snapshot if catastrophic

---

### Scenario 3: "We need to delete 1B rows but can't lock the table."

**Senior approach:**
- Don't run a single `DELETE FROM ... WHERE ...`
- Batch: delete 10,000 rows at a time, sleep between batches
- Use a tool like pt-archiver
- Or partition the table and `DROP PARTITION`

```sql
-- Batched delete loop (pseudocode)
DO {
  DELETE FROM logs WHERE created_at < '2024-01-01' LIMIT 10000;
  SLEEP 1;
} WHILE (rows_affected > 0);
```

---

## Memorize

When asked any MySQL question, hit these notes if relevant:
1. **InnoDB.** Always.
2. **Indexes match query patterns.**
3. **EXPLAIN before optimizing.**
4. **Transactions for multi-step changes.**
5. **Replica for read scaling.**
6. **XtraBackup for production backups.**
7. **Monitor: slow query log, replica lag, buffer pool hit rate.**
