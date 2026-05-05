# MariaDB Interview Q&A — Basic to Advanced

**Purpose:** Practical MariaDB knowledge for backend interviews. The focus is on what makes MariaDB different from MySQL — storage engines, Galera Cluster, sequences, dynamic columns, system-versioned tables, JSON, and operations. For shared SQL/MySQL fundamentals, see `mysql-interview-questions.md`.

---

## Table of Contents

1. MariaDB Basics
2. MariaDB vs MySQL — Differences
3. Storage Engines
4. Galera Cluster
5. Sequences
6. Dynamic Columns
7. System-Versioned (Temporal) Tables
8. JSON Support
9. Other MariaDB-Specific Features
10. Operations and Migration

---

## 1. MariaDB Basics

## Q1. What is MariaDB?

**Answer:**

MariaDB is a community-developed, open-source fork of MySQL. It was started in 2009 by the original MySQL authors after Oracle acquired Sun Microsystems. MariaDB was a drop-in replacement up through MySQL 5.7, but from MySQL 8.0 onward the two codebases have diverged significantly. The current major versions are 10.11 LTS and 11.x.

```sql
SELECT VERSION();
-- e.g., '10.11.6-MariaDB-log'
```

## Q2. Why was MariaDB created?

**Answer:**

The MySQL community feared Oracle would gradually close parts of MySQL's development or change its licensing. The MariaDB Foundation guarantees the project remains GPL and openly developed.

## Q3. Is MariaDB still a drop-in replacement for MySQL?

**Answer:**

Up to MySQL 5.7, mostly yes. From MySQL 8.0 onward they have diverged enough that you should treat them as related but distinct databases.

- Different default authentication plugins.
- MySQL 8 features (CHECK enforcement, descending indexes, hash joins) are implemented differently or are missing in MariaDB.
- MariaDB has features MySQL doesn't (sequences, system-versioned tables, dynamic columns, several extra storage engines).
- Replication wire protocol is not always compatible at higher versions.

## Q4. What is MariaDB's release model?

**Answer:**

MariaDB has both Stable and LTS designations. 10.11 is currently LTS (5-year support). 11.x is the current GA line. MariaDB skipped 6/7/8/9 to clearly separate from MySQL versioning. Don't assume similar version numbers between MySQL and MariaDB mean similar features.

---

## 2. MariaDB vs MySQL — Differences

## Q5. What are the high-level differences?

**Answer:**

| Feature | MySQL 8.0 | MariaDB 10.11 / 11.x |
|---------|-----------|----------------------|
| Owner | Oracle | MariaDB Foundation |
| License | GPLv2 + commercial | GPLv2 |
| Default auth | `caching_sha2_password` | `mysql_native_password` |
| Storage engines | InnoDB, MyISAM, Memory, NDB | + Aria, MyRocks, ColumnStore, Spider, Connect, S3, Sequence |
| Sequences | No | Yes |
| Dynamic columns | No | Yes |
| System-versioned tables | No | Yes |
| JSON | Native binary type | Alias for LONGTEXT + functions |
| Window functions / CTEs | 8.0+ | 10.2+ |
| Roles | 8.0+ | 10.0+ |
| Galera | Plug-in / Group Replication | Built-in |
| Default thread pool | Enterprise only | Community |

## Q6. JSON: native vs alias — does it matter?

**Answer:**

In MySQL, JSON is a true binary-stored type with validation and dedicated optimizations. In MariaDB, JSON is an alias for LONGTEXT with a CHECK constraint that enforces valid JSON. The functions (`JSON_EXTRACT`, `JSON_VALUE`, `JSON_TABLE`, `JSON_EXISTS`) work the same way, but storage is text — slightly less compact.

```sql
-- Same syntax both DBs
CREATE TABLE products (
  id   INT PRIMARY KEY,
  data JSON
);

INSERT INTO products VALUES (1, '{"color":"red","size":"M"}');

SELECT JSON_VALUE(data, '$.color') FROM products;
```

For heavy JSON workloads on MariaDB, prefer dynamic columns or generated columns plus indexes for performance.

## Q7. Are MySQL and MariaDB replication-compatible?

**Answer:**

MariaDB 10.x can replicate from MySQL 5.5/5.6/5.7 but not reliably from MySQL 8.0+ — GTID formats and some features differ. Don't plan on cross-replication for production HA.

MariaDB has its own GTID format (`<domain>-<server>-<sequence>`) and supports multi-source replication where one replica pulls from multiple primaries.

## Q8. How do the optimizers differ?

**Answer:**

- MySQL 8 added hash joins, which are now the default for some equi-joins.
- MariaDB has long had block nested loop, batched key access, multi-range read, and subquery materialization, with different defaults.
- Both have histograms, but with different syntax.

After migrating between them, profile your important queries — query plans will differ.

## Q9. When would you choose MariaDB over MySQL?

**Answer:**

- You want a fully open codebase with no commercial-edition gating.
- You need built-in Galera multi-master replication.
- You want system-versioned tables for audit and temporal queries.
- You need SQL-standard sequences (multiple independent sequences, custom increments).
- You want analytics inside the database via the ColumnStore engine.
- You want database-level sharding via the Spider engine.
- Your distribution defaults to MariaDB (Debian, RHEL, many Linux distros).

## Q10. When would you stick with MySQL?

**Answer:**

- You depend on Oracle's tooling (MySQL Shell, MySQL Router, InnoDB Cluster).
- Your workloads benefit from MySQL 8's hash join optimizer.
- You use AWS Aurora MySQL or another vendor-managed service biased toward MySQL.
- Your application has only been tested against MySQL 8.

---

## 3. Storage Engines

## Q11. What storage engines does MariaDB ship with?

**Answer:**

| Engine | Use case |
|--------|----------|
| InnoDB (default) | Transactional OLTP |
| Aria | Crash-safe MyISAM replacement; default for internal temp tables |
| MyISAM | Legacy; non-transactional |
| MEMORY | RAM-only; lost on restart |
| MyRocks | LSM-tree; write-heavy with strong compression |
| ColumnStore | Columnar engine for analytics |
| Spider | Sharding / federation across MariaDB backends |
| Connect | Federated access to external sources (CSV, ODBC, MongoDB) |
| S3 | Read-only tables stored in Amazon S3 |
| Sequence | Virtual engine producing rows on demand |

You can use multiple engines in one database.

```sql
CREATE TABLE orders   (...) ENGINE=InnoDB;
CREATE TABLE archive  (...) ENGINE=MyRocks;
CREATE TABLE reports  (...) ENGINE=ColumnStore;
```

## Q12. What is Aria?

**Answer:**

Aria is a crash-safe successor to MyISAM. MariaDB uses it internally for system tables and internal temporary tables. It is faster than MyISAM under crash recovery but lacks foreign keys and MVCC. Outside of internal use, it has limited application.

## Q13. What is MyRocks?

**Answer:**

MyRocks is an LSM-tree storage engine ported from Facebook's RocksDB. It is optimized for write-heavy workloads and offers excellent compression — often 2 to 4 times smaller than InnoDB. The trade-off is higher CPU cost on reads and missing features like foreign keys.

```sql
CREATE TABLE events (
  id        BIGINT PRIMARY KEY,
  payload   TEXT,
  created   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=RocksDB;
```

Common use cases: massive event ingestion, time-series-like data, storage-cost-sensitive workloads.

## Q14. What is ColumnStore?

**Answer:**

ColumnStore is a massively parallel, distributed columnar engine for analytics inside MariaDB. It stores data column-wise with compression and is optimized for full-table aggregations. You can run OLAP queries without exporting data to a separate warehouse.

```sql
CREATE TABLE sales_facts (
  sale_id    BIGINT,
  product_id INT,
  amount     DECIMAL(10,2),
  sale_date  DATE
) ENGINE=ColumnStore;

-- This benefits from columnar layout
SELECT sale_date, SUM(amount)
FROM sales_facts
GROUP BY sale_date;
```

## Q15. What is the Spider engine?

**Answer:**

Spider is a sharding and federation engine. A Spider table is a logical table that maps to multiple remote tables across MariaDB backends, partitioning data by key.

```sql
CREATE TABLE orders_shard (
  id          BIGINT,
  customer_id BIGINT,
  amount      DECIMAL(10,2)
) ENGINE=SPIDER PARTITION BY HASH(customer_id) (
  PARTITION p0 COMMENT='host "shard0", database "shop", table "orders"',
  PARTITION p1 COMMENT='host "shard1", database "shop", table "orders"'
);
```

Modern apps often prefer app-level sharding or Vitess; Spider remains useful for legacy-friendly DB-level sharding.

## Q16. What is the Connect engine?

**Answer:**

The Connect engine exposes external data as SQL tables. Sources include CSV, JSON, XML, ODBC drivers, MongoDB, and REST APIs.

```sql
CREATE TABLE remote_orders ENGINE=CONNECT TABLE_TYPE=ODBC
CONNECTION='DSN=remote_db;UID=user;PWD=secret';

SELECT * FROM remote_orders WHERE status = 'paid';
```

Niche but powerful for integration scenarios.

## Q17. What is the S3 engine?

**Answer:**

The S3 engine stores read-only tables in Amazon S3. You build the table on the server, then `ALTER TABLE ... ENGINE=S3` ships it to S3 — freeing local storage. Useful for cold partitions of large tables that should remain queryable but not on hot disk.

```sql
ALTER TABLE old_orders_2020 ENGINE=S3;
```

## Q18. What is the Sequence engine?

**Answer:**

A virtual engine that produces a range of integers on the fly without storing anything. It is similar to PostgreSQL's `generate_series()`.

```sql
SELECT * FROM seq_1_to_10;
SELECT seq FROM seq_2025_01_01_to_2025_01_31;

-- Generate calendar rows
SELECT seq AS day FROM seq_1_to_31;
```

---

## 4. Galera Cluster

## Q19. What is Galera?

**Answer:**

Galera is synchronous multi-master replication for MariaDB and MySQL. Every node accepts writes, and each write is "certified" across the cluster before commit. MariaDB ships Galera built in.

The minimum recommended cluster size is three nodes for quorum. Each node holds a full copy of the data; reads are local and fast; writes incur a network round trip for certification.

## Q20. How does Galera differ from traditional replication?

**Answer:**

| Aspect | Async (binlog) | Galera (synchronous) |
|--------|----------------|----------------------|
| Replication | Async or semi-sync | Virtually synchronous |
| Failover | Manual or external tooling | Automatic — any node accepts writes |
| Data loss on failover | Possible | Effectively zero |
| Write latency | Fast on primary | Slower (network round-trip per commit) |
| Read scaling | Replicas | Any node |

## Q21. What are the trade-offs of Galera?

**Answer:**

- Write latency increases because every commit waits for cluster certification.
- Hot rows or tables suffer from certification conflicts under contention; the application sees deadlock-like errors and must retry.
- Schema changes must use either rolling schema upgrade (RSU) or total order isolation (TOI). TOI blocks the cluster during the change.
- Geo-distribution works but is tricky over high-latency links — usually use multiple clusters with async replication between them rather than stretched Galera.
- Use odd node counts (3, 5, 7) for proper quorum.

## Q22. How does a node rejoin a Galera cluster?

**Answer:**

Two ways:

- IST (Incremental State Transfer) — only missing transactions are sent from a donor (fast).
- SST (State Snapshot Transfer) — a full data copy when the rejoiner is too far behind. Methods include `mariabackup` (default), `rsync`, and `xtrabackup`.

A donor node is busy during SST. In a three-node cluster this leaves only one node serving traffic until the rejoin completes.

## Q23. What is split-brain in Galera?

**Answer:**

If the cluster partitions and no half has a majority, both halves stop accepting writes — this is correct behavior. If a partition with majority continues alone and merges later, IST or SST resolves it.

For two-data-center deployments, run three nodes per DC and a Galera Arbitrator (`garbd`) in a third site for tie-breaking.

## Q24. Galera vs InnoDB Cluster?

**Answer:**

- InnoDB Cluster (Group Replication + MySQL Router + MySQL Shell) is Oracle's solution.
- Galera + MaxScale or HAProxy is the MariaDB community solution.

Both achieve multi-primary HA. Galera is older and more broadly deployed, with simpler bootstrap.

---

## 5. Sequences

## Q25. How do MariaDB sequences differ from AUTO_INCREMENT?

**Answer:**

MariaDB supports SQL-standard sequences (10.3+). MySQL has only AUTO_INCREMENT.

```sql
CREATE SEQUENCE order_seq
  START WITH 1000
  INCREMENT BY 1
  MINVALUE 1000
  MAXVALUE 9999999999
  CACHE 100
  NOCYCLE;

SELECT NEXTVAL(order_seq);
SELECT PREVVAL(order_seq);

CREATE TABLE orders (
  id  BIGINT DEFAULT NEXTVAL(order_seq) PRIMARY KEY,
  total DECIMAL(10, 2)
);
```

Multiple independent sequences in one database make this useful when several tables share an ID space.

## Q26. When should you use a sequence vs AUTO_INCREMENT?

**Answer:**

Use a sequence when:

- Several tables share the same ID space.
- You need to pre-allocate IDs before inserting.
- You need a custom increment or cache size.

Use AUTO_INCREMENT for the typical "single-table primary key" case.

---

## 6. Dynamic Columns

## Q27. What are Dynamic Columns?

**Answer:**

Dynamic columns store a variable-schema set of fields inside a single BLOB column. They predate MariaDB's JSON support and are useful for compact storage of optional or rare fields.

```sql
CREATE TABLE products (
  id    INT PRIMARY KEY,
  name  VARCHAR(100),
  attrs BLOB
);

INSERT INTO products VALUES (
  1, 'T-shirt',
  COLUMN_CREATE('color', 'red', 'size', 'M', 'weight', 200)
);

SELECT id,
       COLUMN_GET(attrs, 'color' AS CHAR) AS color,
       COLUMN_GET(attrs, 'size'  AS CHAR) AS size
FROM products;

SELECT id FROM products
WHERE COLUMN_GET(attrs, 'color' AS CHAR) = 'red';
```

Common functions: `COLUMN_CREATE`, `COLUMN_GET`, `COLUMN_ADD`, `COLUMN_DELETE`, `COLUMN_LIST`, `COLUMN_JSON`.

## Q28. Dynamic Columns vs JSON in MariaDB?

**Answer:**

| Aspect | Dynamic Columns | JSON |
|--------|-----------------|------|
| Storage | Compact binary | Text |
| Speed | Faster single-field lookup | Comparable |
| Standard | MariaDB-specific | SQL standard |
| Indexing | Via virtual columns | Via virtual columns |
| Portability | Low | High |
| Tooling | Limited | Broad |

For new code, JSON is usually the better choice for portability. Dynamic columns shine when you need maximum storage efficiency for highly variable extension fields.

---

## 7. System-Versioned (Temporal) Tables

## Q29. What is a system-versioned table?

**Answer:**

A SQL:2011 standard feature where the database automatically tracks every row's history. You can query the table as it appeared at any past point in time.

```sql
CREATE TABLE accounts (
  id      INT PRIMARY KEY,
  name    VARCHAR(100),
  balance DECIMAL(10, 2)
) WITH SYSTEM VERSIONING;

UPDATE accounts SET balance = 100 WHERE id = 1;
UPDATE accounts SET balance = 250 WHERE id = 1;

-- Current state
SELECT * FROM accounts WHERE id = 1;

-- State as of a past timestamp
SELECT * FROM accounts FOR SYSTEM_TIME AS OF '2025-05-01 12:00:00'
WHERE id = 1;

-- All historical versions
SELECT * FROM accounts FOR SYSTEM_TIME ALL WHERE id = 1;

-- Range
SELECT * FROM accounts FOR SYSTEM_TIME
  BETWEEN '2025-01-01' AND '2025-06-01';
```

## Q30. How does it work under the hood?

**Answer:**

MariaDB adds two timestamp columns (`row_start`, `row_end`). Updates and deletes do not overwrite — they close the existing row by setting `row_end = NOW()` and insert a new version. Queries with `FOR SYSTEM_TIME` filter on the range.

## Q31. What are the use cases for system-versioned tables?

**Answer:**

- Audit trails for compliance or finance, without app-level history tables.
- Effective-dating logic (accounts, contracts).
- Debugging "what did this row look like yesterday?"
- Time-travel analytics queries.

## Q32. What are the trade-offs?

**Answer:**

- Storage grows over time because every update keeps the prior version.
- Indexes grow correspondingly.
- Schema changes need care.
- You can partition by SYSTEM_TIME to drop old history cheaply:

```sql
CREATE TABLE accounts (
  id      INT PRIMARY KEY,
  balance DECIMAL(10, 2)
) WITH SYSTEM VERSIONING
PARTITION BY SYSTEM_TIME (
  PARTITION p_old HISTORY,
  PARTITION p_cur CURRENT
);
```

## Q33. Application-time vs system-time versioning?

**Answer:**

- System time records when the row was stored in the database.
- Application time (effective period) records when a fact was true in the real world (a contract from 2024 to 2026).

MariaDB 10.4+ supports application-time periods via `PERIOD FOR ...`. Combining both is called bitemporal modeling and is rare but powerful for audit-heavy systems.

---

## 8. JSON Support

## Q34. What JSON features does MariaDB offer?

**Answer:**

MariaDB JSON (LONGTEXT alias) supports the SQL/JSON function set.

```sql
CREATE TABLE products (
  id    INT PRIMARY KEY,
  data  JSON,
  CHECK (JSON_VALID(data))
);

INSERT INTO products VALUES
  (1, '{"name":"shirt","attrs":{"color":"red","size":"M"}}');

SELECT JSON_VALUE(data,   '$.name'),
       JSON_EXTRACT(data, '$.attrs.color')
FROM products;

SELECT * FROM products
WHERE JSON_VALUE(data, '$.attrs.color') = 'red';

UPDATE products
SET data = JSON_SET(data, '$.attrs.size', 'L')
WHERE id = 1;
```

`JSON_TABLE` (10.6+) flattens JSON arrays into rows.

## Q35. How do you index JSON?

**Answer:**

Index a generated column that extracts the field you want to filter on.

```sql
ALTER TABLE products
  ADD COLUMN color VARCHAR(50)
    AS (JSON_VALUE(data, '$.attrs.color')) PERSISTENT,
  ADD INDEX idx_products_color (color);

SELECT * FROM products WHERE color = 'red';   -- uses idx_products_color
```

`PERSISTENT` (stored) costs disk but avoids per-row computation. `VIRTUAL` is computed on read.

---

## 9. Other MariaDB-Specific Features

## Q36. What are invisible columns?

**Answer:**

A column that exists but does not appear in `SELECT *` or implicit `INSERT` lists. Useful for adding columns to legacy code without breaking existing queries.

```sql
ALTER TABLE users ADD COLUMN deleted_at DATETIME INVISIBLE;

SELECT * FROM users;                          -- no deleted_at
SELECT id, name, deleted_at FROM users;       -- works when explicit
```

## Q37. What are virtual and persistent generated columns?

**Answer:**

A generated column's value is computed from other columns. `VIRTUAL` is computed on the fly; `PERSISTENT` is stored on disk and can be indexed efficiently. Common use: indexing a computed expression.

```sql
ALTER TABLE users
  ADD COLUMN email_lower VARCHAR(255)
    AS (LOWER(email)) PERSISTENT,
  ADD UNIQUE INDEX idx_users_email_lower (email_lower);

-- Now case-insensitive lookups use the index
SELECT * FROM users WHERE email_lower = 'alice@example.com';
```

## Q38. How does per-table encryption work?

**Answer:**

MariaDB supports table-level encryption via `innodb_encrypt_tables` and pluggable key management (file, AWS KMS, HashiCorp Vault). You can also encrypt the redo log, binary log, and temp files.

```sql
CREATE TABLE secrets (
  id    INT PRIMARY KEY,
  value TEXT
) ENCRYPTED=YES ENCRYPTION_KEY_ID=1;
```

## Q39. Does MariaDB have a thread pool by default?

**Answer:**

Yes. The thread pool is in the community edition (in MySQL it's an enterprise-only feature). It improves performance under high connection counts by serving connections via a fixed pool of worker threads.

```ini
thread_handling = pool-of-threads
thread_pool_size = 16
```

## Q40. What is multi-source replication?

**Answer:**

A MariaDB replica can pull from multiple primaries simultaneously — useful for consolidating data from many shards into one analytics node.

```sql
CHANGE MASTER 'shard1' TO MASTER_HOST='shard1.example', ...;
CHANGE MASTER 'shard2' TO MASTER_HOST='shard2.example', ...;
START ALL SLAVES;
```

Each connection has its own state and GTID stream.

## Q41. What about binary log encryption?

**Answer:**

Binary logs can be encrypted on disk (10.1+). Important for compliance — replication and PITR data on disk needs the same protection as the primary data files.

```ini
encrypt_binlog    = ON
encrypt_tmp_files = ON
```

## Q42. How do you enable optimizer trace?

**Answer:**

Helpful for diagnosing why the optimizer chose a particular plan.

```sql
SET optimizer_trace = 'enabled=on';
SELECT ... ;
SELECT * FROM information_schema.OPTIMIZER_TRACE;
```

---

## 10. Operations and Migration

## Q43. What does migrating from MySQL to MariaDB look like?

**Answer:**

For matching minor versions (MySQL 5.7 to MariaDB 10.5):

1. Take a backup with `mysqldump` or `mariabackup`.
2. Stop MySQL.
3. Install MariaDB.
4. Start MariaDB on the same data directory (compatible up to 5.7).
5. Run `mysql_upgrade` (or `mariadb-upgrade`).
6. Test and monitor.

For MySQL 8.0 to MariaDB, use a logical export and import (`mysqldump`) — in-place migration won't work because the data dictionary differs.

Watch for:

- Authentication plugin mismatch (`caching_sha2_password` users won't work without changes).
- Reserved word changes.
- JSON storage format differences.
- Optimizer plan changes — re-test important queries.

## Q44. What does migrating from MariaDB to MySQL look like?

**Answer:**

Use logical export and import. Be aware that MariaDB-only features won't translate. Plan replacements:

- Sequences → AUTO_INCREMENT or app-level allocator.
- System-versioned tables → manual history tables or app-level audit.
- Dynamic columns → JSON.

## Q45. What backup tools are available?

**Answer:**

| Tool | Notes |
|------|-------|
| `mysqldump` / `mariadb-dump` | Logical, slow on big DBs |
| `mariabackup` | Physical, online; fork of Percona XtraBackup |
| `mydumper` / `myloader` | Parallel logical backup/restore |
| Filesystem snapshots | Need clean state; use `FLUSH TABLES WITH READ LOCK` |

`mariabackup` is the recommended physical backup tool.

```bash
mariabackup --backup --target-dir=/backup/today \
  --user=root --password=*** --stream=mbstream | \
  gzip > /backup/today.mbstream.gz
```

## Q46. What monitoring tools do people use?

**Answer:**

- MaxScale — MariaDB's database proxy with monitoring, query routing, automatic failover, and CDC streaming.
- `mysqld_exporter` for Prometheus + Grafana dashboards.
- Percona Monitoring and Management (PMM) — broad MySQL/MariaDB observability.
- MariaDB Enterprise has a native cluster manager.

## Q47. What is MaxScale?

**Answer:**

MaxScale is a high-performance database proxy by MariaDB. It performs:

- Read/write split (writes to the primary, reads to replicas).
- Connection routing for Galera clusters.
- Automatic failover and replica promotion.
- Schemaless sharding.
- Binlog routing for large fan-out and CDC pipelines.
- Query firewall and data masking.

It is often the right answer for "how do we route traffic in a Galera cluster".

## Q48. How would you set up an open-source HA stack?

**Answer:**

A common pure-GPL stack:

- MariaDB + Galera Cluster of three nodes for HA.
- MaxScale in front for read/write split and failover.
- Async replication to a DR site.

```
[ App ] -> [ MaxScale ] -> [ Galera node 1, 2, 3 ]
                                |
                          (async replication)
                                v
                      [ DR replica ]
```

## Q49. How do you do an audit trail in MariaDB?

**Answer:**

Two practical paths:

1. System-versioned tables — the database does it natively.
2. App-level history tables driven by triggers or application code.

System-versioned wins for compliance simplicity. Use partitioning by `SYSTEM_TIME` to age out old history into cheaper storage.

```sql
CREATE TABLE customer_events (
  id INT PRIMARY KEY, ...
) WITH SYSTEM VERSIONING
PARTITION BY SYSTEM_TIME (
  PARTITION p_old HISTORY,
  PARTITION p_cur CURRENT
);
```

## Q50. Reporting queries are slowing your OLTP cluster — what can you do?

**Answer:**

- Add a read replica dedicated to BI workload.
- Move reporting tables to the ColumnStore engine for fast aggregations.
- ETL into a dedicated analytics warehouse.
- Async-replicate to a node running ColumnStore for an HTAP-style setup.

ColumnStore inside the same MariaDB simplifies integration; for very large datasets a real warehouse remains better.

## Q51. How do you handle Galera deadlocks under load?

**Answer:**

Galera certifies writes globally, so concurrent updates to the same row from different nodes can fail certification on one side. Practical fixes:

- Route writes for hot rows to a single node (sticky routing in MaxScale).
- Reduce hot-row contention — split rows, batch writes, or queue writes.
- Implement application-level retries on the certification error.
- Avoid long transactions, which hold certification windows open.

## Q52. How do you allocate IDs unique across many tables?

**Answer:**

Use a shared sequence.

```sql
CREATE SEQUENCE global_id START WITH 1 CACHE 1000;

CREATE TABLE orders   (
  id BIGINT DEFAULT NEXTVAL(global_id) PRIMARY KEY,
  -- ...
);
CREATE TABLE invoices (
  id BIGINT DEFAULT NEXTVAL(global_id) PRIMARY KEY,
  -- ...
);
```

A larger CACHE value (1000 here) means each connection grabs a block of IDs at once — fewer round trips, but expect gaps if the server restarts.
