# MariaDB Interview Questions — Basic to Advanced

**Purpose:** Senior-level MariaDB knowledge for backend interviews. Focuses on what makes MariaDB different from MySQL — storage engines, Galera Cluster, sequences, dynamic columns, system-versioned tables, JSON, and operational choices. For shared SQL/MySQL fundamentals, see `mysql-interview-questions.md`.

---

## Table of Contents

1. [MariaDB Basics](#mariadb-basics)
2. [MariaDB vs MySQL — Differences](#mariadb-vs-mysql--differences)
3. [Storage Engines in MariaDB](#storage-engines-in-mariadb)
4. [Galera Cluster](#galera-cluster)
5. [Sequences](#sequences)
6. [Dynamic Columns](#dynamic-columns)
7. [System-Versioned (Temporal) Tables](#system-versioned-temporal-tables)
8. [JSON Support](#json-support)
9. [Other MariaDB-Specific Features](#other-mariadb-specific-features)
10. [Operations and Migration](#operations-and-migration)
11. [Real Interview Scenarios](#real-interview-scenarios)

---

## MariaDB Basics

### Q1. What is MariaDB?

A community-developed, open-source fork of MySQL, started in 2009 by the original MySQL authors after Oracle acquired Sun. Drop-in replacement up through MySQL 5.7; from MySQL 8.0 onward the codebases diverged significantly. Current major versions: 10.11 LTS and 11.x.

---

### Q2. Why was MariaDB created?

Concerns over Oracle's stewardship of MySQL — dual-licensing, slowing community contributions, possibly closing parts of the codebase. MariaDB Foundation guarantees BSL/GPL openness.

---

### Q3. Is MariaDB still a drop-in replacement for MySQL?

**Up to MySQL 5.7 — yes, mostly.** From MySQL 8.0 forward, divergence is significant:
- Different default authentication plugins.
- MySQL 8.0 features (`CHECK` enforcement, descending indexes, hash joins) — implemented differently or absent in MariaDB.
- MariaDB has features MySQL doesn't (sequences, system-versioned tables, dynamic columns, several storage engines).
- Replication wire protocol can be incompatible at higher versions.

**Treat them as related-but-distinct databases, not interchangeable.**

---

### Q4. Versioning and release model?

- MariaDB uses both **Stable** and **LTS** designations. **10.11 is LTS** (5-year support). 11.x is the current GA line.
- MariaDB skipped 6/7/8/9 and jumped to 10 to clearly differentiate from MySQL versioning.
- Don't deploy MariaDB versions matching MySQL version numbers expecting matching features.

---

## MariaDB vs MySQL — Differences

### Q5. High-level differences?

| Feature | MySQL 8.0 | MariaDB 10.11/11.x |
|---------|-----------|--------------------|
| Owner | Oracle | MariaDB Foundation |
| License | GPLv2 + commercial | GPLv2 |
| Default auth | `caching_sha2_password` | `mysql_native_password` (10.4+ also `ed25519`, `unix_socket`) |
| Storage engines | InnoDB, MyISAM, Memory, NDB | InnoDB (XtraDB earlier), Aria, MyRocks, ColumnStore, Spider, Connect, S3, Sequence |
| Sequences | No (only AUTO_INCREMENT) | Yes (`CREATE SEQUENCE`) |
| Dynamic columns | No | Yes |
| System-versioned tables | No (built-in) | Yes (`WITH SYSTEM VERSIONING`) |
| JSON | Native type, generated cols | Alias for `LONGTEXT` + check; functions |
| `CHECK` constraints | Enforced 8.0+ | Enforced 10.2+ |
| Window functions | 8.0+ | 10.2+ |
| CTEs | 8.0+ | 10.2+ |
| Roles | 8.0+ | 10.0+ |
| Invisible columns | 8.0+ | 10.3+ |
| Sequences | No | Yes |
| Galera | Plug-in (Oracle MySQL: Group Replication / InnoDB Cluster) | Built-in, well-integrated |
| Default thread pool | No (Enterprise only) | Yes (community) |
| Optimizer | Hash joins, histograms | Different optimizer, histograms, materialized derived tables |
| Encryption | InnoDB + binlog | Whole-table encryption, binlog encryption |

---

### Q6. JSON: native vs alias — does it matter?

In **MySQL**, `JSON` is a true binary-stored type with validation and dedicated optimizations.

In **MariaDB**, `JSON` is an **alias for `LONGTEXT`** with a CHECK constraint enforcing valid JSON. JSON functions (`JSON_EXTRACT`, `JSON_VALUE`, `JSON_TABLE`, `JSON_EXISTS`) work, but storage is text — slightly less compact and lookups parse the document.

**Implications:**
- MariaDB JSON columns are larger on disk than MySQL's binary JSON.
- Cross-database migration of JSON works at SQL level but storage-format differences mean pg_dump/mysqldump bytes won't match.
- For heavy JSON workloads on MariaDB, prefer **dynamic columns** or virtual generated columns + indexes.

---

### Q7. Replication compatibility?

MariaDB 10.0 - 10.x can replicate from MySQL 5.5/5.6/5.7 but **not reliably from MySQL 8.0+** — GTID formats differ, some features are incompatible. Don't plan on cross-replication for production HA.

MariaDB has its own GTID format (`<domain>-<server>-<sequence>`), supports multi-source replication (one replica, many primaries — useful for consolidation).

---

### Q8. Optimizer differences?

- MySQL 8.0 added **hash joins** (default for some equi-joins).
- MariaDB has long had **block nested loop**, **batched key access**, **multi-range read**, and **subquery materialization** with different defaults.
- MariaDB optimizer offers `optimizer_switch` flags differently named.
- Histograms exist in both but with different syntax and column-stat tables.

In production: don't assume the same query plans port between them. Profile after migration.

---

### Q9. When to choose MariaDB over MySQL?

- You want **truly open** (no commercial-edition gating).
- You need **Galera multi-master** out of the box.
- You need **system-versioned tables** for audit / temporal queries without app-level history tables.
- You need **sequences** (multiple independent sequences, custom increment).
- You're doing analytics inside the DB → **ColumnStore**.
- You're sharding across multiple backends → **Spider**.
- Many tools / distros default to MariaDB (Debian, RHEL).

---

### Q10. When to stick with MySQL?

- Heavy reliance on Oracle ecosystem (Enterprise tooling, MySQL Shell, MySQL Router, InnoDB Cluster).
- Workloads tuned for MySQL 8 optimizer (hash joins).
- AWS Aurora MySQL or vendor managed services biased to MySQL.
- Codebase / ORM tested only against MySQL 8.

---

## Storage Engines in MariaDB

### Q11. What storage engines does MariaDB ship with?

| Engine | Use case |
|--------|----------|
| **InnoDB** (default) | Transactional OLTP, foreign keys, row-level locking |
| **Aria** | Crash-safe MyISAM replacement; default for internal temporary tables |
| **MyISAM** | Legacy; non-transactional; small read-mostly tables |
| **MEMORY** | RAM-only, lost on restart |
| **MyRocks** | LSM-tree from Facebook; compression-heavy, write-heavy workloads |
| **ColumnStore** | Columnar storage for analytics (OLAP) |
| **Spider** | Sharding/federation across multiple MariaDB backends |
| **Connect** | Federated access to external sources (CSV, ODBC, MongoDB, JSON) |
| **S3** | Read-only tables stored in S3 (cold storage tier) |
| **Sequence** | Virtual engine that generates rows on demand |
| **CSV / Archive / BLACKHOLE** | Niche |

You can use multiple engines in the same database.

---

### Q12. What is Aria?

A crash-safe MyISAM successor. MariaDB uses Aria internally for system tables and temporary tables. Faster than MyISAM under crash recovery; not as feature-rich as InnoDB (no foreign keys, no MVCC). Niche outside system internals.

---

### Q13. What is MyRocks?

LSM-tree storage engine ported from Facebook's RocksDB. Optimized for **write-heavy** workloads with **excellent compression** (often 2-4x smaller than InnoDB). Trade-off: higher CPU on reads, no foreign keys, fewer locking primitives.

Use cases: massive event ingestion, time-series-like data, storage-cost-sensitive workloads.

---

### Q14. What is ColumnStore?

A massively parallel, distributed columnar engine for analytics inside MariaDB. Stores data column-wise with compression, optimized for full-table aggregations. Lets you run OLAP queries without exporting to a separate warehouse.

```sql
CREATE TABLE sales_facts (
  sale_id BIGINT,
  product_id INT,
  amount DECIMAL(10,2),
  sale_date DATE
) ENGINE=ColumnStore;
```

For OLTP + OLAP in one DB. Not a replacement for full warehouses (Snowflake, BigQuery) at very large scale, but excellent for "moderate analytics next to transactional data."

---

### Q15. What is the Spider engine?

A sharding / federation engine. A Spider table is a logical table that maps to multiple remote tables across MariaDB backends, partitioning data by key. Queries against the Spider table are decomposed and pushed to relevant shards.

```sql
CREATE TABLE orders_shard (
  id BIGINT,
  customer_id BIGINT,
  ...
) ENGINE=SPIDER PARTITION BY HASH(customer_id) (
  PARTITION p0 COMMENT='host "shard0", database "orders", table "orders"',
  PARTITION p1 COMMENT='host "shard1", database "orders", table "orders"'
);
```

Supports cross-shard joins and transactions (with caveats). For most modern applications, app-level sharding or Vitess is easier to operate; Spider remains useful for legacy-friendly DB-level sharding.

---

### Q16. What is the Connect engine?

Read/write tables backed by external sources: CSV, JSON, XML, ODBC drivers, MongoDB, REST APIs. SQL-as-API over heterogeneous data without ETL.

```sql
CREATE TABLE remote_orders ENGINE=CONNECT TABLE_TYPE=ODBC
CONNECTION='DSN=remote_db;UID=user;PWD=secret';
```

Niche but powerful for integration scenarios.

---

### Q17. What is the S3 engine?

Stores read-only tables in Amazon S3. You build the table on the server, then `ALTER TABLE ... ENGINE=S3` ships it to S3 — frees local storage. Ideal for cold partitions of large tables you want to keep queryable but not on hot disk.

---

### Q18. Sequence engine?

A virtual engine that produces ranges of integers on the fly — no storage. Useful for generating rows in queries:

```sql
SELECT * FROM seq_1_to_100;
SELECT seq FROM seq_1_to_31 WHERE seq BETWEEN 1 AND 7;
```

Like Postgres `generate_series()`. Saves you from creating numbers tables.

---

## Galera Cluster

### Q19. What is Galera?

Synchronous, multi-master replication for MariaDB / MySQL. **Every node accepts writes**, and writes are certified across the cluster before commit. Built into MariaDB Server (MariaDB Cluster); Codership maintains the upstream library.

**Architecture:**
- Minimum recommended size: **3 nodes** (quorum).
- Each node holds a full copy of the data.
- Writes go through certification (a kind of conflict-detection protocol) before commit.
- Reads are local, fast.

---

### Q20. Galera vs traditional replication?

| Aspect | Async (binlog) | Galera (synchronous) |
|--------|----------------|----------------------|
| Replication | Async or semi-sync | Virtually synchronous (certified) |
| Failover | Manual / Sentinel-style tools | Automatic — any node can serve writes |
| Data loss on failover | Possible (unreplicated commits) | Effectively zero |
| Write performance | Fast on primary | Slower (network round-trip per commit) |
| Read scaling | Replicas | Any node |
| Topology | Primary + replicas | All masters |

---

### Q21. Galera trade-offs?

- **Write performance**: every commit waits for cluster certification. Latency-sensitive over WAN.
- **Hot rows / hot tables**: certifications can fail under heavy contention → app sees `deadlock`-like errors and must retry.
- **Schema changes**: rolling schema upgrade (RSU) or total order isolation (TOI) — TOI blocks the whole cluster.
- **DDL**: care needed, especially with foreign keys.
- **Geo-distribution**: works but tricky over high-latency WANs (use multiple clusters with async between them, not stretched Galera).
- **Even node counts**: avoid; 3, 5, or 7 nodes for proper quorum.

---

### Q22. How does Galera handle a node rejoining?

- **IST (Incremental State Transfer)**: missing transactions sent from a donor (fast).
- **SST (State Snapshot Transfer)**: full data copy — used when too far behind. Methods: `mariabackup` (default, online), `rsync`, `xtrabackup`.

A donor node is busy during SST; in 3-node clusters, this leaves one node serving until SST completes. Larger clusters tolerate this better.

---

### Q23. What is split-brain in Galera?

If the cluster partitions and no half has a majority, both halves stop accepting writes (correct behavior). If a partition with majority continues alone and merges later, IST/SST resolves it.

For 2-data-center deployments, run **3 nodes per DC** plus a **Galera Arbitrator (`garbd`)** node in a third site for tie-breaking.

---

### Q24. Galera vs MySQL InnoDB Cluster / Group Replication?

InnoDB Cluster (Group Replication + MySQL Router + MySQL Shell) is Oracle's answer; ProxySQL/HAProxy + Galera is the MariaDB world. Both achieve multi-primary HA. Galera is older, broadly deployed, simpler to bootstrap.

---

## Sequences

### Q25. How do MariaDB sequences differ from AUTO_INCREMENT?

MariaDB supports SQL-standard sequences (10.3+). MySQL has only `AUTO_INCREMENT`.

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

-- Use as default
CREATE TABLE orders (
  id BIGINT DEFAULT NEXTVAL(order_seq) PRIMARY KEY,
  ...
);
```

Multiple independent sequences in one DB. Useful when you need IDs allocated outside of a single table (shared counters, reservation systems).

---

### Q26. When to use a sequence vs AUTO_INCREMENT?

Use **sequence** when:
- Multiple tables share the same ID space.
- You need to pre-allocate IDs before inserting.
- Custom increment / cache behavior.
- You want to skip ranges or seed gaps.

Use **AUTO_INCREMENT** for the typical "single-table primary key."

---

## Dynamic Columns

### Q27. What are Dynamic Columns?

A blob-encoded variable schema inside one column. Predates JSON support. Store key-value extension fields without schema migrations.

```sql
CREATE TABLE products (
  id INT PRIMARY KEY,
  name VARCHAR(100),
  attrs BLOB
);

INSERT INTO products VALUES (
  1, 'T-shirt',
  COLUMN_CREATE('color', 'red', 'size', 'M', 'weight', 200)
);

SELECT id, COLUMN_GET(attrs, 'color' AS CHAR) AS color FROM products;
SELECT id FROM products WHERE COLUMN_GET(attrs, 'color' AS CHAR) = 'red';
```

**Functions:** `COLUMN_CREATE`, `COLUMN_GET`, `COLUMN_ADD`, `COLUMN_DELETE`, `COLUMN_LIST`, `COLUMN_JSON`.

---

### Q28. Dynamic Columns vs JSON in MariaDB?

| Aspect | Dynamic Columns | JSON |
|--------|-----------------|------|
| Storage | Compact binary | Text |
| Speed | Faster lookups (single field) | Comparable; whole-doc parsing for some ops |
| Standard | MariaDB-specific | SQL standard |
| Indexing | Via virtual columns | Via virtual columns |
| Portability | Low (MariaDB only) | High |
| Tooling | Limited | Broad |

For new code, JSON is usually the right choice for portability. Dynamic Columns shine when you want the most compact storage for highly-variable extension fields.

---

## System-Versioned (Temporal) Tables

### Q29. What are system-versioned tables?

SQL:2011 standard feature. The database automatically tracks every row's history. You can query the table as of any past point in time.

```sql
CREATE TABLE accounts (
  id INT PRIMARY KEY,
  name VARCHAR(100),
  balance DECIMAL(10,2)
) WITH SYSTEM VERSIONING;

UPDATE accounts SET balance = 100 WHERE id = 1;
UPDATE accounts SET balance = 250 WHERE id = 1;

-- Current state
SELECT * FROM accounts WHERE id = 1;

-- Point-in-time
SELECT * FROM accounts FOR SYSTEM_TIME AS OF '2025-05-01 12:00:00' WHERE id = 1;

-- All historical versions
SELECT * FROM accounts FOR SYSTEM_TIME ALL WHERE id = 1;

-- Range
SELECT * FROM accounts FOR SYSTEM_TIME BETWEEN '2025-01-01' AND '2025-06-01';
```

---

### Q30. How does it work under the hood?

The engine adds two timestamp columns (`row_start`, `row_end`). Updates and deletes don't overwrite — they close the existing row (`row_end = now`) and insert a new version. Queries with `FOR SYSTEM_TIME` filter on the range.

---

### Q31. Use cases?

- Audit trails (compliance, finance) without app-level history tables.
- Effective-dating logic (accounts, contracts).
- Debugging "what did this row look like yesterday?"
- Time-travel queries for analytics.

---

### Q32. Trade-offs?

- Storage growth (every update keeps the prior row).
- Index size grows correspondingly.
- Schema changes on versioned tables require care.
- You can partition by `row_end` to drop old history cheaply (`PARTITIONING BY SYSTEM_TIME`).

```sql
CREATE TABLE accounts (
  ...
) WITH SYSTEM VERSIONING
PARTITION BY SYSTEM_TIME (
  PARTITION p_old HISTORY,
  PARTITION p_cur CURRENT
);
```

---

### Q33. Application-time vs system-time versioning?

- **System time**: when the row was stored (MariaDB built-in).
- **Application time** (effective period): when the fact was true in the real world (e.g., contract from 2024 to 2026). MariaDB 10.4+ also supports application-time periods (`PERIOD FOR ...`).

You can combine both — **bitemporal tables** — though it's rare.

---

## JSON Support

### Q34. JSON in MariaDB — features?

MariaDB JSON (alias for LONGTEXT) supports the SQL/JSON function set:

```sql
CREATE TABLE products (
  id INT PRIMARY KEY,
  data JSON,
  CHECK (JSON_VALID(data))
);

INSERT INTO products VALUES
  (1, '{"name":"shirt","attrs":{"color":"red","size":"M"}}');

SELECT JSON_VALUE(data, '$.name'),
       JSON_EXTRACT(data, '$.attrs.color')
FROM products;

SELECT * FROM products WHERE JSON_VALUE(data, '$.attrs.color') = 'red';

-- Modify
UPDATE products SET data = JSON_SET(data, '$.attrs.size', 'L') WHERE id = 1;
```

`JSON_TABLE` (10.6+) flattens JSON into rows.

---

### Q35. Indexing JSON?

Use a generated column + index:

```sql
ALTER TABLE products
  ADD COLUMN color VARCHAR(50) AS (JSON_VALUE(data, '$.attrs.color')) PERSISTENT,
  ADD INDEX idx_color (color);

SELECT * FROM products WHERE color = 'red';   -- uses index
```

`PERSISTENT` (stored) costs disk but avoids per-row computation. `VIRTUAL` is computed at read.

---

## Other MariaDB-Specific Features

### Q36. Invisible columns?

A column that exists but doesn't appear in `SELECT *` or `INSERT` without explicit listing. Useful for adding columns to legacy code without breaking queries.

```sql
ALTER TABLE users ADD COLUMN deleted_at DATETIME INVISIBLE;
SELECT * FROM users;                                 -- no deleted_at
SELECT id, name, deleted_at FROM users;              -- works
```

---

### Q37. Virtual / persistent generated columns?

Compute a value from other columns. `VIRTUAL` is on-the-fly; `PERSISTENT` is stored. Useful for indexing computed expressions (case-insensitive search, JSON paths).

```sql
ALTER TABLE users ADD COLUMN email_lower VARCHAR(255)
  AS (LOWER(email)) PERSISTENT,
  ADD UNIQUE INDEX idx_email_lower (email_lower);
```

---

### Q38. Per-table encryption?

MariaDB supports innodb_encrypt_tables (with key management plugins for AWS KMS, file, HashiCorp Vault). You can encrypt specific tables, redo log, binary log, and temp files.

```sql
CREATE TABLE secrets (
  ...
) ENCRYPTED=YES ENCRYPTION_KEY_ID=1;
```

---

### Q39. Thread pool by default?

MariaDB's thread pool is in the community edition (MySQL Enterprise Thread Pool is paid). It improves performance under high connection counts by serving connections via a fixed pool of worker threads.

```ini
thread_handling = pool-of-threads
thread_pool_size = 16
```

---

### Q40. Multi-source replication?

A MariaDB replica can pull from multiple primaries simultaneously, useful for consolidation:

```sql
CHANGE MASTER 'shard1' TO MASTER_HOST='shard1.example', ...;
CHANGE MASTER 'shard2' TO MASTER_HOST='shard2.example', ...;
START ALL SLAVES;
```

Each connection has its own state and GTID stream.

---

### Q41. Binary log encryption?

Binary log files can be encrypted on disk (10.1+). Important for compliance — replication and PITR data on disk has the same requirements as the primary tablespace.

```ini
encrypt_binlog = ON
encrypt_tmp_files = ON
```

---

### Q42. Optimizer trace and slow log filters?

```sql
SET optimizer_trace='enabled=on';
SELECT ... ;
SELECT * FROM information_schema.OPTIMIZER_TRACE;
```

Slow log includes admin and replication queries by default in MariaDB.

---

## Operations and Migration

### Q43. Migrating from MySQL to MariaDB — process?

For matching minor versions (e.g., MySQL 5.7 → MariaDB 10.5):
1. Backup with `mysqldump` or `mariabackup`.
2. Stop MySQL.
3. Install MariaDB.
4. Start MariaDB on the same data directory (compatible up to 5.7).
5. Run `mysql_upgrade` (or `mariadb-upgrade`).
6. Test and monitor.

For MySQL 8.0 → MariaDB: full logical export/import (`mysqldump`) recommended; in-place won't work due to data dictionary differences.

Watch for:
- Authentication plugin mismatch (`caching_sha2_password` users won't authenticate).
- Reserved word changes.
- JSON storage differences.
- Optimizer plan changes — re-test workloads.

---

### Q44. Migrating from MariaDB to MySQL — process?

Logical export/import. Be aware that MariaDB-only features (sequences, dynamic columns, system-versioned tables) won't translate. Plan replacements:
- Sequence → AUTO_INCREMENT or app-level allocator.
- System-versioned → manual history table or app-level audit.
- Dynamic columns → JSON.

---

### Q45. Backup tools?

| Tool | Notes |
|------|-------|
| `mysqldump` / `mariadb-dump` | Logical, slow on big DBs |
| `mariabackup` | Physical, online, fork of Percona XtraBackup |
| `mydumper` / `myloader` | Parallel logical backup/restore |
| Filesystem snapshots | Need clean state; use with `FLUSH TABLES WITH READ LOCK` |

`mariabackup` is the recommended physical-backup tool. Streams compressed backups to S3 with `--stream=mbstream`.

---

### Q46. Common monitoring tools?

- **MaxScale** — MariaDB's database proxy with monitoring, query routing, automatic failover, streaming CDC.
- **mysqld_exporter** for Prometheus + Grafana dashboards.
- **PMM (Percona Monitoring & Management)** — broad MySQL/MariaDB observability.
- **MariaDB Enterprise** offers a native cluster manager.

MaxScale is particularly nice — sits in front of Galera or replicated MariaDB, performs read/write split, can do binlog routing for CDC, and is GA proven.

---

### Q47. What is MaxScale?

A high-performance database proxy by MariaDB. Functions:
- Read/write split (route writes to primary, reads to replicas).
- Connection routing for Galera clusters.
- Automatic failover and replica promotion.
- Schemaless sharding.
- Binlog router (act as a binlog relay → simplify large fan-out).
- Change data capture (CDC) → Kafka.
- Query firewall, masking.

Often the right answer for "how do we route traffic in a Galera cluster."

---

## Real Interview Scenarios

### Scenario 1: "We need fully open-source HA without commercial licensing concerns."

**Recommendation:** MariaDB + Galera Cluster + MaxScale. Pure GPL stack. 3-node Galera in a single DC, plus async replication to a DR site. MaxScale handles read/write split and failover.

---

### Scenario 2: "We're hitting JSON write throughput limits in MySQL — switch to MariaDB?"

**Caution.** MariaDB JSON is text-stored — for write-heavy JSON, you may not gain. Investigate:
- Is the bottleneck JSON parsing or commit overhead?
- Could you use generated columns with proper indexes?
- Could you split frequently-updated keys out of JSON into real columns?

If switching, prototype on production-like data — don't assume MariaDB will be faster.

---

### Scenario 3: "We need a complete audit trail of every row change."

**Two paths:**
1. **System-versioned tables** — DB does it natively. Simple, transparent.
2. **App-level history tables** with triggers or app code.

System-versioned wins for compliance simplicity. Plan partitioning by `SYSTEM_TIME` to age out old history into cheaper storage (or drop after retention).

---

### Scenario 4: "Reporting queries are killing our OLTP cluster."

**Options:**
- Read replica dedicated to BI workload.
- ColumnStore engine for the reporting tables (fast aggregations, columnar compression).
- ETL to a separate analytics warehouse.
- Async replica feeding ColumnStore for HTAP-ish setup.

ColumnStore inside the same MariaDB makes integration easy, but for very large datasets (TB+), a real data warehouse is still better.

---

### Scenario 5: "We have 5 regional shards — can we query them as one logical table?"

**Spider engine.** Define a Spider table partitioned by region; queries are decomposed and executed remotely. Caveats: cross-shard joins are expensive, distributed transactions have limits. For modern apps, often easier to query each shard from app code or use a sharding-aware proxy.

---

### Scenario 6: "Galera cluster keeps deadlocking under load."

**Cause:** certification conflicts on hot rows. Galera certifies writes globally; concurrent updates to the same row from different nodes fail certification on one side.

**Fixes:**
- Route writes for hot rows to a single node (sticky routing in MaxScale).
- Reduce hot-row contention (split rows, use queues, batch writes).
- Application-level retries on the certification error.
- Avoid long transactions — they hold certification windows open.

---

### Scenario 7: "We need IDs unique across many tables."

**Solution:** sequences.

```sql
CREATE SEQUENCE global_id START WITH 1 CACHE 1000;

CREATE TABLE orders   ( id BIGINT DEFAULT NEXTVAL(global_id) PRIMARY KEY, ... );
CREATE TABLE invoices ( id BIGINT DEFAULT NEXTVAL(global_id) PRIMARY KEY, ... );
```

Cache value 1000 = each connection grabs 1000 IDs at a time → fewer round trips, but gaps on restart.

---

## Senior MariaDB Mantra

1. **MariaDB is no longer "MySQL but free." It's a related but distinct database.** Plan migrations seriously.
2. **InnoDB by default; use MyRocks/ColumnStore/Spider only when their trade-offs match your workload.**
3. **Galera is the simplest path to multi-primary HA — but understand certification conflicts and write latency.**
4. **System-versioned tables eliminate hand-rolled audit logging.**
5. **Sequences for cross-table ID allocation; AUTO_INCREMENT for the common case.**
6. **JSON in MariaDB is text-stored — use generated columns + indexes for performance.**
7. **MaxScale solves most production routing/failover problems for free.**
8. **Mariabackup for physical backups, mydumper for parallel logical backups.**
9. **Test optimizer plans after migrating from MySQL — they will differ.**
10. **For OLAP next to OLTP, ColumnStore beats exporting to a separate warehouse for moderate scales.**
