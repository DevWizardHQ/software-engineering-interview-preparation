# MySQL Interview Q&A — Basic to Advanced

**Purpose:** Practical MySQL knowledge for interviews and daily use. Each topic uses a clear question, a plain-language answer, and a runnable example.

---

## Table of Contents

1. MySQL Basics
2. Storage Engines
3. Indexes in MySQL
4. Transactions and Locking
5. Query Optimization
6. Replication
7. High Availability and Scaling
8. Backup and Recovery
9. MySQL vs Other Databases
10. Operational Topics

---

## 1. MySQL Basics

## Q1. What is MySQL?

**Answer:**

MySQL is an open-source relational database management system. It is owned by Oracle and uses a pluggable storage engine architecture. The default engine since version 5.5 has been InnoDB, which provides ACID transactions and row-level locking. MariaDB is a community fork created when Oracle acquired MySQL.

```sql
-- Create and use a database
CREATE DATABASE shop CHARACTER SET utf8mb4;
USE shop;

CREATE TABLE products (
  id    INT AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(100) NOT NULL,
  price DECIMAL(10, 2) NOT NULL
) ENGINE=InnoDB;
```

## Q2. What is new in MySQL 8?

**Answer:**

MySQL 8 brought many features that earlier versions lacked. The most useful ones for application developers are window functions and CTEs.

- Default character set is `utf8mb4` (full Unicode, including emoji).
- Window functions (ROW_NUMBER, RANK, LAG, LEAD, etc).
- Common Table Expressions (WITH ...) including recursive ones.
- JSON improvements and JSON_TABLE.
- Atomic DDL — schema changes don't leave the database in a half-changed state.
- Roles for granting permissions to groups of users.
- New default authentication plugin: `caching_sha2_password`.
- Better optimizer with histograms and hash joins.
- Replication terminology: `SHOW REPLICA STATUS` instead of `SHOW SLAVE STATUS`.

```sql
-- A window function — only available in 8.0+
SELECT id, total,
       RANK() OVER (ORDER BY total DESC) AS rnk
FROM orders;
```

## Q3. What are the differences between MySQL and MariaDB?

**Answer:**

MariaDB is a fork of MySQL maintained by the original founder. They are mostly compatible at the SQL level, but they have diverged in features.

| Feature | MySQL | MariaDB |
|---------|-------|---------|
| Owner | Oracle | MariaDB Foundation / Community |
| License | GPL + commercial | GPL only |
| Default storage engine | InnoDB | InnoDB (Aria for temp tables) |
| Threading | One thread per connection | Thread pool by default |
| Sequences | No | Yes |
| Window functions | 8.0+ | 10.2+ |
| System-versioned tables | No | Yes |

For new projects, pick one and stick with it — replication between them is no longer guaranteed compatible.

## Q4. What are the common MySQL data types?

**Answer:**

Choosing correct data types affects storage, indexing, and correctness.

| Type | Notes |
|------|-------|
| INT | 4 bytes, signed range about ±2 billion |
| BIGINT | 8 bytes, for large IDs |
| VARCHAR(N) | Up to N characters; storage variable |
| TEXT / MEDIUMTEXT / LONGTEXT | Large text columns |
| DECIMAL(M, D) | Exact decimal — use for money |
| FLOAT / DOUBLE | Approximate — never for money |
| DATETIME | 8 bytes, no timezone |
| TIMESTAMP | 4 bytes, stored as UTC, auto-converts |
| JSON | Native JSON since 5.7 |
| ENUM | Compact but rigid; avoid for evolving schemas |

```sql
CREATE TABLE invoices (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  amount      DECIMAL(12, 2) NOT NULL,    -- exact for money
  description VARCHAR(255),
  metadata    JSON,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
```

## Q5. What is the difference between CHAR and VARCHAR?

**Answer:**

`CHAR(N)` stores a fixed-length string and pads it with spaces to N characters. `VARCHAR(N)` stores a variable-length string up to N characters. Use CHAR when the data really has a fixed length (country codes, MD5 hashes); use VARCHAR for everything else.

```sql
CREATE TABLE addresses (
  country_code  CHAR(2),         -- always 2 chars: 'US', 'IN'
  street        VARCHAR(255)     -- variable length
);
```

---

## 2. Storage Engines

## Q6. What are the main MySQL storage engines?

**Answer:**

| Engine | Use case |
|--------|----------|
| InnoDB (default) | OLTP, transactions, row-level locks, foreign keys |
| MyISAM | Legacy, no transactions, table-level locks |
| MEMORY | In-RAM, fast, lost on restart |
| Archive | Insert-only, compressed |
| CSV | Plaintext storage |
| BLACKHOLE | Discards writes, used for replication routing |

Almost every modern application uses InnoDB.

```sql
CREATE TABLE orders (
  id INT AUTO_INCREMENT PRIMARY KEY
) ENGINE=InnoDB;
```

## Q7. Why InnoDB over MyISAM?

**Answer:**

InnoDB supports the features modern applications need.

- ACID transactions.
- Row-level locking (vs MyISAM's table-level locking).
- Foreign keys.
- Crash recovery via the redo log.
- Better performance under concurrent writes.
- Online DDL for many schema changes.

MyISAM is faster for very specific read-only or bulk-insert workloads but offers no concurrency or crash safety.

## Q8. What is the InnoDB buffer pool?

**Answer:**

The buffer pool is a region of memory where InnoDB caches table and index pages. It is the most important MySQL setting for performance. If your hot working set fits inside it, queries are served from memory; if not, MySQL reads from disk on every miss.

```ini
# my.cnf
innodb_buffer_pool_size = 16G   # set to 70-80% of RAM on a dedicated DB server
```

```sql
-- Check current size
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';

-- Hit ratio (aim for >99%)
SHOW STATUS LIKE 'Innodb_buffer_pool_read%';
```

## Q9. What is the InnoDB redo log?

**Answer:**

The redo log is a circular write-ahead log. Every change is written to the redo log first, then later flushed to the actual data files. After a crash, MySQL replays the redo log to recover. A larger redo log allows more changes to accumulate before they need to be flushed, improving write throughput at the cost of slower recovery.

```ini
innodb_log_file_size = 1G
innodb_log_files_in_group = 2
```

## Q10. What is the InnoDB undo log?

**Answer:**

The undo log stores old versions of rows so that:

- Transactions can be rolled back.
- MVCC consistent reads can see the old version of a row while another transaction modifies the new one.

Long-running transactions force the undo log to grow because old versions cannot be purged until no transaction needs them.

---

## 3. Indexes in MySQL

## Q11. What index types does MySQL support?

**Answer:**

- B-tree — default in InnoDB, used for equality and range queries.
- Hash — used inside the MEMORY engine and InnoDB's adaptive hash index.
- R-tree — for spatial data.
- Full-text — for natural-language text search.

```sql
CREATE INDEX idx_users_email ON users(email);                -- B-tree
CREATE FULLTEXT INDEX idx_articles_body ON articles(body);   -- full-text
CREATE SPATIAL INDEX idx_locations_geo ON locations(geo);    -- R-tree
```

## Q12. What is a clustered index in InnoDB?

**Answer:**

In InnoDB, the table is physically stored as a B-tree on the primary key. The data lives in the leaf nodes of that tree — the table *is* the primary key index.

Practical consequences:

- Lookups by the primary key are the fastest.
- Secondary indexes store the primary key (not a row pointer), so a secondary lookup costs two index walks.
- Random primary keys (like UUID v4) cause page splits and fragmentation. Sequential keys (auto-increment, UUID v7) are friendlier to the clustered index.

## Q13. Should you use AUTO_INCREMENT or UUID for primary keys?

**Answer:**

| Option | Pros | Cons |
|--------|------|------|
| AUTO_INCREMENT BIGINT | Compact (8 bytes), sequential, fast clustered insert | Predictable (don't expose publicly), single-database |
| UUID v4 | Globally unique, hard to guess | 16 bytes binary / 36 chars text, random — page splits |
| UUID v7 / ULID | Globally unique + time-ordered | Slightly larger than BIGINT |

A common pattern is to use BIGINT auto-increment internally and UUID/ULID for public-facing identifiers in URLs and APIs.

```sql
CREATE TABLE users (
  id          BIGINT       AUTO_INCREMENT PRIMARY KEY,
  public_id   CHAR(26)     NOT NULL UNIQUE,    -- ULID exposed to clients
  email       VARCHAR(255) NOT NULL UNIQUE
);
```

## Q14. What is a covering index?

**Answer:**

A covering index includes every column the query needs, so MySQL can answer the query from the index alone without reading the table. EXPLAIN shows `Using index` when this happens.

```sql
-- Query
SELECT id, status FROM orders WHERE user_id = 5;

-- Covering composite index
CREATE INDEX idx_orders_user_status ON orders(user_id, status, id);
```

## Q15. Can you have too many indexes?

**Answer:**

Yes. Every index adds storage cost, slows down INSERT, UPDATE, and DELETE (because each index must be updated), and adds work for the optimizer. Periodically check for unused indexes and drop them.

```sql
-- Unused indexes (sys schema)
SELECT * FROM sys.schema_unused_indexes;
```

---

## 4. Transactions and Locking

## Q16. What is the default isolation level in InnoDB?

**Answer:**

REPEATABLE READ. Combined with InnoDB's MVCC and gap locks, it produces behavior close to SERIALIZABLE for many cases. PostgreSQL's default is READ COMMITTED, which is one level weaker.

```sql
-- Inspect your session's isolation level
SELECT @@transaction_isolation;
```

## Q17. What is a gap lock?

**Answer:**

InnoDB locks not just the rows that match a range query but also the gaps between them. This prevents another transaction from inserting rows into the locked range — protecting against phantom reads.

```sql
-- Session 1
BEGIN;
SELECT * FROM users WHERE age > 30 FOR UPDATE;

-- Session 2 — blocks even though no current row is being modified
INSERT INTO users (age) VALUES (35);
```

Gap locks can cause unexpected blocking under load. Switching to READ COMMITTED disables gap locking for some statements.

## Q18. What is the difference between LOCK IN SHARE MODE and FOR UPDATE?

**Answer:**

Both lock matching rows but with different sharing rules.

- `LOCK IN SHARE MODE` (or `FOR SHARE` in 8.0) — shared lock; other transactions can read but not modify.
- `FOR UPDATE` — exclusive lock; other transactions wait if they try to read with a lock or modify the row.

```sql
-- Read a balance and ensure nobody changes it during this transaction
BEGIN;
SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
COMMIT;
```

## Q19. How does MySQL handle deadlocks?

**Answer:**

InnoDB automatically detects deadlocks and aborts one transaction with `ERROR 1213 (40001)`. The application must retry. Prevent them by acquiring locks in a consistent order (for example, always lock rows by primary key ascending) and by keeping transactions short.

```js
async function withDeadlockRetry(fn, attempts = 3) {
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (e) {
      if (e.errno === 1213 && i < attempts - 1) continue;
      throw e;
    }
  }
}
```

## Q20. What is auto-commit?

**Answer:**

By default each statement runs inside its own transaction and commits immediately. To group statements into one transaction, use BEGIN ... COMMIT, or set `autocommit = 0`.

```sql
SET autocommit = 0;

START TRANSACTION;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;
```

---

## 5. Query Optimization

## Q21. What does EXPLAIN show in MySQL?

**Answer:**

EXPLAIN displays the execution plan the optimizer chose for a query. The most useful columns are:

- `type` — access method. From best to worst: `system`, `const`, `eq_ref`, `ref`, `range`, `index`, `ALL`. Aim for `range` or better.
- `key` — index used.
- `rows` — estimated number of rows examined.
- `filtered` — percentage of rows passing additional WHERE filtering.
- `Extra` — flags such as `Using index` (covering — good), `Using filesort` (sort step), `Using temporary` (intermediate table).

```sql
EXPLAIN SELECT * FROM orders WHERE user_id = 123;

-- Run and time the actual query (8.0+)
EXPLAIN ANALYZE SELECT * FROM orders WHERE user_id = 123;
```

## Q22. What are common slow query patterns in MySQL?

**Answer:**

| Pattern | Issue | Fix |
|---------|-------|-----|
| `WHERE column LIKE '%abc'` | Leading wildcard — no B-tree use | Reverse the column or use FULLTEXT |
| `WHERE func(column) = ?` | Index on `column` is ignored | Functional index (8.0+) or store normalized form |
| `WHERE str_col = 123` | Implicit type cast | Match types: `WHERE str_col = '123'` |
| `OR` across indexed columns | Often turns into a scan | Rewrite as UNION |
| `LIMIT N OFFSET M` for big M | Reads M+N rows | Cursor / keyset pagination |
| `SELECT *` | Fetches every column | Select only what is needed |

```sql
-- Slow: function on column
SELECT * FROM users WHERE LOWER(email) = 'a@b.com';

-- Fast (8.0+ functional index)
CREATE INDEX idx_users_email_lower ON users((LOWER(email)));
```

## Q23. What is the slow query log?

**Answer:**

A log file that records queries running longer than a configured threshold. It is the first place to look when a database is slow.

```ini
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1.0                 # log queries > 1 second
log_queries_not_using_indexes = 1
```

Use `pt-query-digest` from Percona Toolkit to summarize the log and find queries with the highest total time impact.

## Q24. How do you analyze a slow query?

**Answer:**

A pragmatic checklist:

1. Run `EXPLAIN` to see the planned access pattern.
2. Run `EXPLAIN ANALYZE` (8.0+) to see real timings per stage.
3. Check whether expected indexes are used.
4. Inspect `Extra` for warning signs like `Using filesort` or `Using temporary`.
5. Try rewriting (subquery to JOIN, IN to EXISTS, etc.).
6. For deep cases, enable optimizer trace.

```sql
SET optimizer_trace = 'enabled=on';
SELECT * FROM orders WHERE user_id = 5;
SELECT trace FROM information_schema.optimizer_trace;
```

## Q25. What are index hints?

**Answer:**

Index hints force the optimizer to use or avoid specific indexes. Use them sparingly — they become technical debt as data shape changes.

```sql
SELECT * FROM orders FORCE INDEX (idx_user_id) WHERE user_id = 123;
SELECT * FROM orders IGNORE INDEX (idx_status)  WHERE status = 'pending';
```

## Q26. What was the query cache and why was it removed?

**Answer:**

Older MySQL versions had a server-side cache that stored full result sets keyed by the exact query text. It was removed in 8.0 because:

- A single global mutex serialized all access.
- Any write to a table invalidated all cached queries on that table.
- Application-level caching (Redis, Memcached) is far more flexible.

---

## 6. Replication

## Q27. How does MySQL replication work?

**Answer:**

The primary writes a binary log of every change. Each replica runs an I/O thread that pulls binlog events into a local relay log, and a SQL thread that replays them.

```
Primary [binlog] → I/O thread → [relay log] → SQL thread → Replica DB
```

```sql
-- On replica (8.0+)
SHOW REPLICA STATUS\G
```

## Q28. What are the replication formats?

**Answer:**

- STATEMENT-based — logs the SQL text. Compact but unsafe for non-deterministic statements like `NOW()` or `UUID()`.
- ROW-based — logs the actual changed rows. Deterministic but larger.
- MIXED — uses STATEMENT when safe, ROW otherwise.

ROW-based replication is the modern default and is the safest choice.

```ini
binlog_format = ROW
```

## Q29. What is GTID?

**Answer:**

GTID (Global Transaction Identifier) gives each transaction a cluster-wide unique ID. Replicas track which GTIDs they have applied, which makes failover and re-pointing replicas to a new primary much simpler than the older filename + position scheme.

```ini
gtid_mode = ON
enforce_gtid_consistency = ON
```

## Q30. What is the difference between synchronous, asynchronous, and semi-synchronous replication?

**Answer:**

| Type | Behavior |
|------|----------|
| Async (default) | Primary commits immediately; replicas catch up. Risk: lost data on primary crash. |
| Semi-sync | Primary waits for at least one replica to acknowledge receipt before commit returns. |
| Group Replication | Synchronous-style with consensus (Paxos-like); supports multi-primary. |

Semi-sync gives durability across replicas at modest latency cost. Group Replication is used in InnoDB Cluster setups.

## Q31. How do you handle replica lag?

**Answer:**

- Detect: monitor `Seconds_Behind_Source` from `SHOW REPLICA STATUS`. For better accuracy, use `pt-heartbeat`.
- Common causes: write spikes on the primary, single-threaded replication, replica resource limits, very large transactions.
- Fixes: enable parallel apply (`replica_parallel_workers`), upgrade replica hardware, break up huge transactions, route reads to the primary while a lagged replica catches up.

```ini
replica_parallel_workers = 8
replica_parallel_type    = LOGICAL_CLOCK
```

---

## 7. High Availability and Scaling

## Q32. How do you achieve high availability with MySQL?

**Answer:**

Common patterns:

1. Primary plus replicas plus an orchestrator (Orchestrator, ProxySQL, MaxScale) for failover.
2. Group Replication with built-in consensus.
3. InnoDB Cluster (Group Replication + MySQL Router + MySQL Shell).
4. Galera Cluster (used heavily in MariaDB).
5. Cloud-managed services like Amazon RDS or Aurora.

## Q33. How do you scale reads?

**Answer:**

Add read replicas and route read queries to them while writes go to the primary. Keep three things in mind:

- Replica lag means reads may be slightly stale.
- Read-after-write paths usually need to read from the primary.
- The application or a proxy must do the routing.

```js
// pseudo-code routing
const dbForRead  = pickReplica();
const dbForWrite = primary;
```

## Q34. How do you scale writes beyond a single primary?

**Answer:**

- Vertical scaling — bigger machines, more memory and CPU.
- Sharding — split the data across multiple databases by user_id, region, or another key.
- Functional split — different services own different databases.
- Group Replication multi-primary — limited use because of conflict handling.

Sharding is the most powerful and the most complex. Tools like Vitess automate it for MySQL at large scale.

## Q35. How does connection pooling work for MySQL?

**Answer:**

The application keeps a small pool of long-lived MySQL connections that requests borrow and return. This avoids the cost of opening a connection per request. For very high concurrency, a network-layer proxy like ProxySQL pools connections from many app servers and multiplexes them onto fewer backend connections.

```js
// mysql2/promise pool
const pool = mysql.createPool({
  host: 'db', user: 'app', database: 'shop',
  connectionLimit: 20,
  waitForConnections: true,
  queueLimit: 0,
});
```

---

## 8. Backup and Recovery

## Q36. How do you back up MySQL?

**Answer:**

| Tool | Type | Notes |
|------|------|-------|
| `mysqldump` | Logical | Simple, portable, slow on large databases |
| `mysqlpump` | Logical | Multi-threaded |
| Percona XtraBackup | Physical | Hot backup, no lock for InnoDB |
| Filesystem snapshot (LVM, EBS) | Physical | Requires brief lock |

For production, use physical backups (XtraBackup) plus binlogs for point-in-time recovery.

```bash
# Logical dump with consistent snapshot for InnoDB
mysqldump --single-transaction --quick --triggers --routines \
  -u root -p shop > shop.sql
```

## Q37. What is point-in-time recovery (PITR)?

**Answer:**

PITR restores the database to a specific moment, usually just before a bad operation. Steps:

1. Restore the most recent full backup.
2. Apply binlogs up to the desired timestamp.

```bash
mysqlbinlog --start-datetime="2025-01-01 00:00:00" \
            --stop-datetime="2025-01-01 14:30:00" \
            mysql-bin.* | mysql -u root -p
```

## Q38. How do you test backups?

**Answer:**

By restoring them. A backup that has never been restored is hope, not a backup. Set up automated weekly or monthly restores in a non-production environment, verify row counts and recent records, and time the restore so you know your real recovery time.

---

## 9. MySQL vs Other Databases

## Q39. How does MySQL compare to PostgreSQL?

**Answer:**

| Feature | MySQL | PostgreSQL |
|---------|-------|------------|
| Default isolation | REPEATABLE READ | READ COMMITTED |
| JSON | Good | Excellent (JSONB indexes) |
| Window functions | 8.0+ | Always |
| Materialized views | No | Yes |
| Procedural languages | SQL/PSM | PL/pgSQL, PL/Python, etc. |
| Foreign keys | InnoDB only | Always |
| Geospatial | OK | Excellent (PostGIS) |
| Replication | Mature | Mature, more flexible |

PostgreSQL is more feature-complete for new projects. MySQL still dominates many ecosystems because of operational familiarity and tooling.

## Q40. When would you choose MySQL?

**Answer:**

- Existing MySQL infrastructure and team expertise.
- Very high read throughput on simple OLTP queries.
- WordPress, Drupal, and the broader PHP ecosystem.
- Vitess for horizontal sharding at very large scale.
- Amazon Aurora MySQL for managed scale.

---

## 10. Operational Topics

## Q41. What is `mysqldump` and what are its limitations?

**Answer:**

`mysqldump` is a built-in tool that exports a database as SQL statements. It is simple and widely supported but slow for large databases.

```bash
# Single-database dump (consistent for InnoDB)
mysqldump --single-transaction shop > shop.sql

# Restore
mysql shop < shop.sql
```

Limitations:

- Slow for very large databases.
- Restore is also slow because it replays SQL.
- Without `--single-transaction`, MyISAM tables get table-locked.

## Q42. How do you change a column on a huge table without locking?

**Answer:**

Three common options:

1. Online DDL (8.0+):
   ```sql
   ALTER TABLE orders
   ADD COLUMN status VARCHAR(20),
   ALGORITHM=INPLACE, LOCK=NONE;
   ```
2. `pt-online-schema-change` from Percona Toolkit — copies the table while syncing via triggers, then swaps.
3. `gh-ost` from GitHub — similar but uses the binlog instead of triggers.

For tables with hundreds of millions of rows, gh-ost or pt-osc are usually the safest options.

## Q43. How do you find unused indexes?

**Answer:**

Use the sys schema views. Drop unused indexes to speed up writes and free up disk space.

```sql
SELECT * FROM sys.schema_unused_indexes;

SELECT * FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE index_name IS NOT NULL
  AND count_star = 0;
```

## Q44. How do you monitor MySQL?

**Answer:**

| Metric | Why it matters |
|--------|----------------|
| Connections | Spikes indicate application issues |
| Slow queries | Find performance regressions |
| Replica lag | Data freshness |
| Buffer pool hit rate | If under 99% on busy DB, increase buffer pool |
| InnoDB row lock waits | Concurrency hot spots |
| Disk I/O | Bottleneck indicator |
| Query rate (QPS) | Baseline vs anomaly |

Tools include Percona Monitoring (PMM), Datadog, Prometheus with `mysqld_exporter`, and Amazon RDS Performance Insights.

## Q45. What does `SHOW PROCESSLIST` do?

**Answer:**

It lists currently running queries. Use it to find hung queries, long-running transactions, or blockers.

```sql
SHOW FULL PROCESSLIST;

-- Or, with more detail:
SELECT * FROM performance_schema.processlist;

-- Kill a runaway query
KILL 12345;
```

## Q46. What are best practices for production MySQL?

**Answer:**

- Use InnoDB everywhere.
- Set the buffer pool to 70-80% of RAM on a dedicated DB server.
- Enable the slow query log and review it regularly.
- Use parameterized queries — never concatenate user input.
- Maintain full backups plus binlogs.
- Test restores on a schedule.
- Use `utf8mb4` for character set.
- Use a connection pool at the application or proxy layer.
- Don't store large files in the database — use object storage.

## Q47. What is `innodb_flush_log_at_trx_commit`?

**Answer:**

It controls how aggressively InnoDB flushes the redo log. The default value 1 is fully durable.

| Value | Behavior |
|-------|----------|
| 1 (default) | Flush and `fsync` to disk on every commit. ACID-compliant. |
| 2 | Flush to OS cache on commit; sync once per second. May lose ~1 second on OS crash. |
| 0 | Sync once per second. May lose ~1 second on MySQL or OS crash. |

Keep it at 1 in production unless you have specific reasons to relax durability (for example, a development or analytics replica).

## Q48. What is the difference between OPTIMIZE TABLE and ANALYZE TABLE?

**Answer:**

- `ANALYZE TABLE` — refreshes index statistics so the optimizer makes better choices. Cheap; safe to run regularly.
- `OPTIMIZE TABLE` — rebuilds the table to reclaim space and reduce fragmentation. Expensive; use only when fragmentation is a real problem.

```sql
ANALYZE TABLE orders;
OPTIMIZE TABLE orders;
```

## Q49. How do you batch a large DELETE without blocking the table?

**Answer:**

Don't run a single huge DELETE — it holds locks for too long and bloats the undo log. Instead, delete in small batches and let the system breathe between batches.

```sql
-- Pseudocode loop in your application
DO {
  DELETE FROM logs WHERE created_at < '2024-01-01' LIMIT 10000;
  -- sleep 200ms in app code
} WHILE (rows_affected > 0);
```

For very large purges, partition the table by date and `ALTER TABLE ... DROP PARTITION` — this is essentially instant.

## Q50. How do you change a primary key on a live table safely?

**Answer:**

Avoid `ALTER TABLE ... DROP PRIMARY KEY, ADD PRIMARY KEY (...)` on a busy table; it rebuilds the entire clustered index. Safer approaches:

1. Use a tool like gh-ost or pt-online-schema-change to copy the table to a new structure with the desired primary key.
2. Stage the change behind a feature flag — write to both old and new tables, then switch reads.

```bash
gh-ost \
  --host=primary --user=admin --password=*** \
  --database=shop --table=orders \
  --alter="DROP PRIMARY KEY, ADD PRIMARY KEY (tenant_id, id)" \
  --execute
```
