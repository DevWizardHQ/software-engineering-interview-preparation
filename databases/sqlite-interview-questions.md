# SQLite Interview Q&A — Basic to Advanced

**Purpose:** Practical SQLite knowledge for backend, mobile, and full-stack interviews. Covers architecture, WAL, FTS5, JSON1, R*Tree, scaling patterns (Litestream, LiteFS, D1, Turso), and operations.

---

## Table of Contents

1. SQLite Basics
2. Architecture and File Format
3. Concurrency and WAL Mode
4. Data Types and Type Affinity
5. Indexes and Query Planning
6. Full-Text Search (FTS5)
7. JSON1 and JSONB
8. R*Tree (Geospatial)
9. Performance Tuning
10. Backups and Operations
11. Production at Scale
12. SQLite vs Other Databases

---

## 1. SQLite Basics

## Q1. What is SQLite?

**Answer:**

SQLite is a self-contained, serverless, zero-configuration, transactional SQL database engine. The entire database is a single file on disk. It is implemented as a C library that links into the host application — there is no separate server process.

It is the most-deployed database in the world: every iOS and Android device, every browser, macOS, Python, PHP, and countless apps embed it. The current major version is 3.x.

```sql
-- Open or create a database file
sqlite3 shop.db

-- Use it like any SQL database
CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT, price REAL);
INSERT INTO products(name, price) VALUES ('Coffee', 4.50);
SELECT * FROM products;
```

## Q2. When should you use SQLite?

**Answer:**

Great fit for:

- Mobile and desktop app local storage.
- Embedded devices (IoT, routers, set-top boxes).
- Browser local storage and offline queues.
- Single-server web apps with moderate traffic.
- Read-heavy websites.
- Test and development databases.
- Application file format (Apple, Adobe, and others use SQLite as a doc format).
- Edge / serverless databases (Cloudflare D1, Turso).

Bad fit for:

- High-concurrency write workloads (single-writer model).
- Multi-server clusters where many clients need to write simultaneously.
- Databases over slow network filesystems.
- Datasets that need to be partitioned across machines.

## Q3. Does SQLite scale?

**Answer:**

It scales surprisingly well for many real-world workloads. Reads are fast and parallel; writes are serialized (one at a time) but often complete in microseconds when the working set fits in cache. A modern server with SSD can sustain hundreds of writes per second and thousands of reads per second on a single SQLite database. It does not scale to multi-machine concurrent writes — for that, you use replication tools (Litestream, LiteFS) or a different database.

## Q4. What is the fundamental difference between SQLite and a server database?

**Answer:**

SQLite is serverless: the engine runs in-process. There is no listener, no protocol, no IPC overhead. Reading from SQLite is roughly as fast as reading from your own data structures. Server databases (PostgreSQL, MySQL, MongoDB) require a separate process and a network or socket round-trip per query, plus authentication and connection pooling. SQLite trades horizontal scaling for radical simplicity and speed at small scale.

## Q5. What ships with SQLite by default?

**Answer:**

Built-in (no separate extension needed):

- Standard SQL with most modern features (CTEs, window functions, UPSERT, RETURNING, partial indexes, generated columns).
- JSON1 (built in since 3.38).
- FTS5 full-text search.
- R*Tree multi-dimensional indexes.
- Geopoly for geographical polygons.
- Loadable extension API for custom C extensions.

---

## 2. Architecture and File Format

## Q6. What is the structure of an SQLite file?

**Answer:**

A database is one file divided into pages (default 4096 bytes; configurable up to 65536). Pages hold a header, B-tree pages for tables and indexes, overflow pages for large rows, and free pages. Tables and indexes are stored as B-trees keyed by `rowid` (or by the declared primary key for `WITHOUT ROWID` tables).

Useful inspection tools include `sqlite3_analyzer`, `sqldiff`, and the `dbstat` virtual table.

## Q7. What is `rowid`?

**Answer:**

Every regular SQLite table has an implicit 64-bit integer `rowid`. If you declare a column as `INTEGER PRIMARY KEY`, that column is an alias for the rowid. Otherwise, SQLite assigns a hidden rowid automatically.

Rowid lookups are the fastest path — a single B-tree descent.

```sql
-- id IS the rowid
CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);

-- A regular table; rowid is hidden but exists; uuid is in a separate index
CREATE TABLE users_uuid (uuid TEXT PRIMARY KEY, name TEXT);
```

## Q8. What is a `WITHOUT ROWID` table?

**Answer:**

A table where the primary key directly addresses rows — no separate hidden rowid. Best for non-integer primary keys (UUIDs, strings) and narrow rows.

```sql
CREATE TABLE config (
  key   TEXT PRIMARY KEY,
  value TEXT
) WITHOUT ROWID;
```

Trade-off: large blob/text rows are less efficient because `WITHOUT ROWID` doesn't use overflow pages as effectively. Don't use for tables where row size dominates the primary-key size.

## Q9. What is a STRICT table?

**Answer:**

Since 3.37, you can enforce strict typing per table. Without STRICT, SQLite uses *type affinity* and will accept the string `"abc"` into an INTEGER column. STRICT rejects type mismatches.

```sql
CREATE TABLE users (
  id   INTEGER NOT NULL,
  name TEXT    NOT NULL,
  age  INT
) STRICT;

INSERT INTO users(id, name, age) VALUES (1, 'Alice', 'thirty');
-- Error: cannot store TEXT value in INT column
```

Always use STRICT for new schemas.

## Q10. How portable is the SQLite file?

**Answer:**

Extremely. The same file works on any operating system, any byte order, any 32- or 64-bit platform. The on-disk format is committed-stable — files written today will be readable in decades.

---

## 3. Concurrency and WAL Mode

## Q11. What is the default journal mode?

**Answer:**

DELETE (a rollback journal). It is simple but slow under concurrency. In production, use WAL.

```sql
PRAGMA journal_mode = WAL;
```

This is a one-time setting per database file (it persists in the header).

## Q12. How does WAL (Write-Ahead Logging) work?

**Answer:**

In WAL mode, writers append changes to a `-wal` file. Readers read from the main database plus uncheckpointed pages in the WAL. A `-shm` shared-memory file coordinates readers and writers. Periodically, a checkpoint copies WAL pages back to the main database and resets the log.

Benefits:

- Readers don't block writers, and writers don't block readers.
- Faster than the default mode (fewer fsyncs).
- Crash-safe.

Downsides:

- Three files instead of one (`.db`, `.db-wal`, `.db-shm`).
- The WAL file grows; it needs checkpoints.
- All readers/writers must be on the same machine — WAL uses shared memory.

## Q13. Why is there only one writer in SQLite?

**Answer:**

SQLite serializes writes globally. At any moment, only one writer holds the write lock. Readers proceed concurrently with the writer and with each other. This design choice keeps the engine simple, lock-free for readers, and crash-safe — and it is also the main scaling limit.

## Q14. What is `busy_timeout`?

**Answer:**

When a writer holds the lock and another connection tries to write, the second connection gets `SQLITE_BUSY`. Setting `busy_timeout` makes it wait instead of failing immediately.

```sql
PRAGMA busy_timeout = 5000;   -- milliseconds
```

Set this to a few seconds in production. Without it, you'll get spurious "database is locked" errors during contention.

## Q15. How do WAL checkpoints work?

**Answer:**

The WAL grows until checkpointed. SQLite auto-checkpoints when the WAL hits about 1000 pages (configurable via `wal_autocheckpoint`). Modes:

- PASSIVE — copy what we can without blocking writers (default).
- FULL — wait for in-progress transactions, then checkpoint.
- RESTART — like FULL, but block new writers until done.
- TRUNCATE — like RESTART, then reset the WAL file size.

```sql
PRAGMA wal_checkpoint(TRUNCATE);
```

Periodic TRUNCATE checkpoints during low-load windows keep the WAL small.

## Q16. Why do long readers block WAL truncation?

**Answer:**

The WAL cannot be checkpointed past the oldest active reader's snapshot. A long-running read transaction prevents WAL truncation, which causes the WAL to grow. Same effect as PostgreSQL's `idle in transaction`. Keep transactions short and avoid holding read transactions across user thinking time.

## Q17. What is SQLite's isolation level?

**Answer:**

Serializable. Every transaction sees a consistent snapshot, and concurrent transactions appear to execute in some serial order.

Begin variants:

- `BEGIN` (deferred) — acquires locks lazily on first use.
- `BEGIN IMMEDIATE` — acquires the write lock immediately. Avoids `SQLITE_BUSY` mid-transaction.
- `BEGIN EXCLUSIVE` — pre-acquires an exclusive lock (rarely needed in WAL mode).

For write transactions, `BEGIN IMMEDIATE` is usually correct — fail fast if another writer holds the lock.

## Q18. Can SQLite be used over a network filesystem?

**Answer:**

Strongly discouraged. Cross-process locking over NFS or SMB is notoriously buggy, and SQLite's documentation warns against it. WAL mode requires `-shm` to be on a real shared-memory filesystem. If you need network access to a single SQLite file, run a server in front (Turso, dqlite, rqlite, or a custom HTTP layer).

---

## 4. Data Types and Type Affinity

## Q19. What are SQLite's storage classes?

**Answer:**

There are five: `NULL`, `INTEGER` (1, 2, 3, 4, 6, or 8 bytes), `REAL` (8-byte IEEE float), `TEXT`, and `BLOB`. There is no separate BOOLEAN, DATE, TIME, or DECIMAL — those are stored as INTEGER, TEXT, or REAL.

## Q20. What is type affinity?

**Answer:**

Each column has an affinity (preferred type), but SQLite will store any storage class in any column unless you use STRICT. Affinity rules:

- `INT` / `INTEGER` → INTEGER
- `TEXT` / `CHAR` / `CLOB` → TEXT
- `BLOB` or no type → BLOB / NONE
- `REAL` / `FLOAT` / `DOUBLE` → REAL
- `NUMERIC` / `DECIMAL` → tries integer, falls back to real or text

```sql
CREATE TABLE non_strict (age INT);
INSERT INTO non_strict VALUES ('forty');   -- accepted in default tables
```

Use STRICT to prevent this.

## Q21. How do you store dates in SQLite?

**Answer:**

Three common conventions:

- TEXT as ISO 8601 (`'2025-05-05T12:00:00Z'`) — sortable and readable.
- INTEGER Unix timestamp (seconds or milliseconds) — compact, fast comparisons.
- REAL as Julian day numbers — supported by `julianday()`.

```sql
SELECT * FROM events
WHERE created_at > strftime('%s', '2025-01-01');
```

ISO-8601 TEXT is the most common modern choice. SQLite's date functions accept all three.

## Q22. How do you store booleans?

**Answer:**

As INTEGER 0 or 1. Modern SQLite recognizes the keywords `TRUE` and `FALSE`.

```sql
CREATE TABLE flags (
  id      INTEGER PRIMARY KEY,
  enabled INTEGER NOT NULL DEFAULT 0
);

INSERT INTO flags(enabled) VALUES (TRUE);
```

## Q23. How do generated columns work?

**Answer:**

A generated column's value is computed from other columns. `STORED` persists; `VIRTUAL` is computed on read.

```sql
CREATE TABLE users (
  id        INTEGER PRIMARY KEY,
  first     TEXT,
  last      TEXT,
  full_name TEXT GENERATED ALWAYS AS (first || ' ' || last) STORED
);
```

Useful for indexing computed expressions and JSON paths.

---

## 5. Indexes and Query Planning

## Q24. What index types does SQLite support?

**Answer:**

- B-tree (default) — single column or composite.
- UNIQUE — adds a uniqueness constraint.
- Partial — `WHERE` clause limits the indexed rows.
- Expression — index on `LOWER(email)` and similar.
- Covering — multiple columns; the query is satisfied entirely from the index.
- FTS5 virtual table — full-text search.
- R*Tree virtual table — multi-dimensional / geo.

```sql
CREATE INDEX idx_users_email_lower ON users(LOWER(email));

CREATE UNIQUE INDEX idx_users_active_email
  ON users(email)
  WHERE deleted = 0;
```

## Q25. How does SQLite plan queries?

**Answer:**

The planner uses statistics gathered by `ANALYZE`. After significant data changes, run `ANALYZE` to refresh `sqlite_stat1`. Inspect plans with `EXPLAIN QUERY PLAN`.

```sql
EXPLAIN QUERY PLAN
SELECT * FROM users WHERE email = ?;
```

Look for `SEARCH` (using an index) versus `SCAN` (full table). Aim for index-driven access on hot queries.

## Q26. What is an automatic index?

**Answer:**

If a query joins or filters and no usable index exists, SQLite may build a transient automatic index in memory for the duration of the query. EXPLAIN QUERY PLAN shows this as `AUTOMATIC`. It is convenient but a sign you should add a real index.

## Q27. Does collation matter for indexes?

**Answer:**

Yes. SQLite's collations are `BINARY` (default), `NOCASE`, and `RTRIM`. Indexes are tied to a specific collation — `WHERE email = ? COLLATE NOCASE` won't use an index that wasn't built with `COLLATE NOCASE`.

```sql
CREATE INDEX idx_users_email_nocase
  ON users(email COLLATE NOCASE);
```

---

## 6. Full-Text Search (FTS5)

## Q28. What is FTS5?

**Answer:**

A full-text search virtual table module — the recommended FTS engine (FTS3/4 are legacy).

```sql
CREATE VIRTUAL TABLE docs_fts USING fts5(
  title, body,
  tokenize='porter unicode61'
);

INSERT INTO docs_fts(title, body)
VALUES ('SQLite Tutorial', 'Learn SQLite quickly...');

-- Phrase, boolean, prefix
SELECT * FROM docs_fts WHERE docs_fts MATCH 'sqlite NEAR/3 tutorial';

-- Snippet with highlighting
SELECT title, snippet(docs_fts, 1, '<b>', '</b>', '...', 16)
FROM docs_fts WHERE docs_fts MATCH 'tutorial';

-- BM25 ranking
SELECT title, bm25(docs_fts) AS score
FROM docs_fts
WHERE docs_fts MATCH 'sqlite'
ORDER BY score;
```

Features include tokenizers (`porter`, `unicode61`, `ascii`, custom), BM25 ranking, phrase queries, boolean operators, prefix search, NEAR, snippet extraction, and external-content tables.

## Q29. What is an external-content FTS5 table?

**Answer:**

Best practice for production. Keep base data in a normal table; FTS5 holds only the index, pointing back to the source. This avoids data duplication.

```sql
CREATE TABLE docs (
  id    INTEGER PRIMARY KEY,
  title TEXT,
  body  TEXT
);

CREATE VIRTUAL TABLE docs_fts USING fts5(
  title, body,
  content='docs',
  content_rowid='id'
);

-- Triggers to keep FTS in sync
CREATE TRIGGER docs_ai AFTER INSERT ON docs BEGIN
  INSERT INTO docs_fts(rowid, title, body)
  VALUES (new.id, new.title, new.body);
END;

CREATE TRIGGER docs_ad AFTER DELETE ON docs BEGIN
  INSERT INTO docs_fts(docs_fts, rowid, title, body)
  VALUES ('delete', old.id, old.title, old.body);
END;

CREATE TRIGGER docs_au AFTER UPDATE ON docs BEGIN
  INSERT INTO docs_fts(docs_fts, rowid, title, body)
  VALUES ('delete', old.id, old.title, old.body);
  INSERT INTO docs_fts(rowid, title, body)
  VALUES (new.id, new.title, new.body);
END;
```

## Q30. How do you weight columns in ranking?

**Answer:**

`bm25()` accepts column weights — useful when title matches matter more than body matches.

```sql
SELECT title FROM docs_fts WHERE docs_fts MATCH 'sqlite'
ORDER BY bm25(docs_fts, 5.0, 1.0);   -- title weighted 5x body
```

## Q31. FTS5 vs Lucene/Elasticsearch?

**Answer:**

For embedded, single-machine full-text search FTS5 is excellent. For distributed search at scale, fuzzy matching, advanced analyzers, autocomplete suggestions, and multi-language stemming, Elasticsearch / OpenSearch / Meilisearch / Atlas Search are still ahead. Pick FTS5 when search is part of the app rather than its core.

---

## 7. JSON1 and JSONB

## Q32. What does JSON1 give you?

**Answer:**

JSON manipulation built into SQLite (since 3.38, no extension needed).

```sql
CREATE TABLE products (id INTEGER PRIMARY KEY, data TEXT);
INSERT INTO products(data) VALUES
  ('{"name":"shirt","attrs":{"color":"red","sizes":["S","M","L"]}}');

-- Extract values
SELECT json_extract(data, '$.name') FROM products;
SELECT data ->> '$.name' FROM products;          -- shorthand
SELECT data ->  '$.attrs' FROM products;          -- returns JSON

-- Filter
SELECT * FROM products
WHERE json_extract(data, '$.attrs.color') = 'red';

-- Iterate over arrays
SELECT value FROM json_each(json_extract(data, '$.attrs.sizes'));
```

Functions: `json`, `json_array`, `json_object`, `json_extract`, `json_set`, `json_remove`, `json_patch`, `json_valid`, `json_type`, `json_each`, `json_tree`.

## Q33. What is JSONB in SQLite?

**Answer:**

SQLite 3.45 (2024) introduced JSONB — a binary JSON storage format that is faster to parse repeatedly and slightly more compact for many shapes. All `json_*` functions accept JSONB.

```sql
CREATE TABLE products (id INTEGER PRIMARY KEY, data BLOB);

INSERT INTO products(data) VALUES (jsonb('{"a":1,"b":[2,3]}'));
SELECT json_extract(data, '$.a') FROM products;
```

For new schemas with frequent JSON access, prefer JSONB.

## Q34. How do you index JSON fields?

**Answer:**

Use a generated column or an index on a JSON expression.

```sql
-- Expression index
CREATE INDEX idx_products_color
  ON products(json_extract(data, '$.attrs.color'));

-- Or: generated column + index
ALTER TABLE products ADD COLUMN color TEXT
  GENERATED ALWAYS AS (json_extract(data, '$.attrs.color')) STORED;
CREATE INDEX idx_products_color2 ON products(color);
```

---

## 8. R*Tree (Geospatial)

## Q35. What is the R*Tree module?

**Answer:**

A built-in virtual table for indexing N-dimensional rectangles. It is used for spatial and range queries.

```sql
CREATE VIRTUAL TABLE places_idx USING rtree(
  id,
  min_lon, max_lon,
  min_lat, max_lat
);

-- Points use min == max
INSERT INTO places_idx VALUES (1, -73.98, -73.98, 40.75, 40.75);

-- Bounding-box query
SELECT id FROM places_idx
WHERE min_lon >= -74 AND max_lon <= -73
  AND min_lat >=  40 AND max_lat <=  41;
```

Combined with the Geopoly module for polygon containment, you get a respectable geo stack inside SQLite. For full GIS (projections, CRS conversion), use the SpatiaLite extension.

---

## 9. Performance Tuning

## Q36. What are the most important PRAGMA settings?

**Answer:**

```sql
PRAGMA journal_mode = WAL;            -- concurrency
PRAGMA synchronous   = NORMAL;        -- safe + fast
PRAGMA temp_store    = MEMORY;        -- temp tables in RAM
PRAGMA mmap_size     = 268435456;     -- 256 MB memory-mapped I/O
PRAGMA cache_size    = -64000;        -- 64 MB page cache (negative = KB)
PRAGMA foreign_keys  = ON;            -- off by default!
PRAGMA busy_timeout  = 5000;          -- wait on lock contention
```

The defaults are conservative for embedded use. Server and web apps benefit from larger cache, mmap, WAL, and `foreign_keys = ON` (it's off per connection by default).

## Q37. What are the synchronous levels?

**Answer:**

| Level | Behavior |
|-------|----------|
| `OFF` | No fsync. Crash means corruption. Don't use. |
| `NORMAL` | fsync at WAL checkpoint, not every commit. With WAL, crash-safe. |
| `FULL` (default) | fsync after every commit. |
| `EXTRA` | Additional fsync on the directory. |

For WAL plus server workloads, NORMAL is the sweet spot — durable up to OS crash and much faster than FULL.

## Q38. Why is `synchronous=NORMAL` safe with WAL?

**Answer:**

A power loss between commit and the next checkpoint may lose the last few committed transactions, but the database itself stays consistent. Single-machine apps usually accept this. If absolutely no committed-write loss is acceptable, use FULL.

## Q39. What are bulk insert best practices?

**Answer:**

Wrap inserts in a single transaction — this is often more than 100x faster than auto-commit.

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous  = NORMAL;

BEGIN;
-- repeat insert (preferably with a prepared statement)
INSERT INTO t VALUES (?, ?, ?);
INSERT INTO t VALUES (?, ?, ?);
-- ...
COMMIT;
```

For massive imports, use `.import` in the `sqlite3` shell or `INSERT ... SELECT` from an attached temporary database.

## Q40. Why use prepared statements?

**Answer:**

Compiling SQL is non-trivial; prepared statements amortize parsing and planning across many executions. They also prevent SQL injection through parameter binding.

```python
stmt = conn.prepare("INSERT INTO t VALUES (?, ?)")
for row in rows:
    stmt.execute(row)
```

## Q41. Should you use one connection per thread?

**Answer:**

SQLite connections are not safe to share across threads by default. The recommendation is one connection per thread or per worker, with each connection setting its own pragmas. For high-concurrency reads, multiple read connections plus one write connection works well — but always remember the single-writer rule.

## Q42. When should you VACUUM?

**Answer:**

`VACUUM` rebuilds the database file, reclaiming free space and defragmenting. It is useful after bulk deletes.

```sql
VACUUM;                                   -- full rebuild; locks the DB

-- Or incremental
PRAGMA auto_vacuum = INCREMENTAL;
PRAGMA incremental_vacuum(1000);          -- reclaim 1000 pages
```

For long-lived production databases with churn, schedule VACUUM during maintenance windows.

## Q43. When should you ANALYZE?

**Answer:**

After significant data changes, run `ANALYZE` so the planner has fresh statistics:

```sql
ANALYZE;

-- Smarter, cheaper alternative (3.18+) — runs ANALYZE only on tables that need it
PRAGMA optimize;
```

Run `PRAGMA optimize` periodically (e.g., on connection close) — it is very lightweight.

---

## 10. Backups and Operations

## Q44. How do you back up SQLite safely?

**Answer:**

Several options:

1. The online backup API (`.backup` in the CLI, `sqlite3_backup_*` in C). Copies a live database safely.
2. `VACUUM INTO` — atomic copy.
3. File copy — only with the database shut down (and including WAL files). Unsafe on a live database.
4. Litestream — streams WAL changes to remote storage continuously.

```sh
# Online backup via the CLI
sqlite3 mydb.db ".backup 'backup.db'"
```

```sql
-- Or, atomic copy from inside SQL
VACUUM INTO 'backup.db';
```

## Q45. What is Litestream?

**Answer:**

A standalone tool that watches a SQLite file's WAL and streams changes to remote storage (S3, GCS, SFTP) in near real time. It provides continuous backup and point-in-time restore (down to seconds), all without app changes — it runs as a sidecar.

```yaml
# litestream.yml
dbs:
  - path: /data/shop.db
    replicas:
      - url: s3://my-bucket/shop
```

```sh
litestream replicate -config litestream.yml
```

## Q46. What is LiteFS?

**Answer:**

A FUSE filesystem that distributes SQLite database files across machines. One node is the primary and accepts writes; other nodes follow the LTX (Litestream Transaction) stream. The application reads locally for low latency; writes are forwarded to the primary. Useful for global edge applications that want SQLite's simplicity with multi-region read latency.

## Q47. What is `dbstat`?

**Answer:**

A built-in virtual table that exposes per-page statistics. Useful for understanding storage layout, fragmentation, and bloat.

```sql
SELECT name, SUM(payload) AS bytes
FROM dbstat
GROUP BY name
ORDER BY bytes DESC;
```

## Q48. How do you handle schema migrations?

**Answer:**

SQLite supports a useful subset of `ALTER TABLE`:

- Rename table.
- Rename column (3.25+).
- Add column.
- Drop column (3.35+).

For more invasive changes (changing a column type, adding a CHECK to an existing column), use the 12-step recipe:

1. `BEGIN`.
2. Create a new table with the desired schema.
3. Copy data: `INSERT INTO new SELECT ... FROM old`.
4. Drop the old table.
5. Rename the new table to the old name.
6. Recreate indexes, triggers, and views.
7. `COMMIT`.

Most modern frameworks (sqlx, Diesel, Prisma, Rails, Django) automate this.

---

## 11. Production at Scale

## Q49. What is Cloudflare D1, Turso, and rqlite?

**Answer:**

- Cloudflare D1 — managed SQLite at the edge. Each database is a standard SQLite file replicated globally; writes go to a primary region.
- Turso — managed libSQL (a fork of SQLite). Adds replication, embedded replicas, and multi-region writes (with caveats).
- rqlite — distributed SQLite via Raft consensus. Good for HA but trades some single-node speed.
- dqlite — Canonical's distributed SQLite using Raft. Used by LXD.

The pattern: SQLite for the hot path, replication for durability and geographic distribution.

## Q50. What is libSQL?

**Answer:**

A Turso-led fork of SQLite that adds:

- Native server mode (HTTP / SQL protocol).
- Embedded replicas (read locally, replicate from a remote primary).
- WebAssembly user-defined functions.
- Native HTTP and gRPC interfaces.
- Bottomless storage (S3 backing).

It is drop-in compatible with SQLite at the SQL level and adds remote-friendly surfaces SQLite proper does not have.

## Q51. When does single-node SQLite stop scaling?

**Answer:**

Practical breakpoints:

- Sustained writes above a few thousand per second — WAL contention or fsync latency dominates. Use a faster SSD, batch writes, or scale out.
- Multi-server deployment — SQLite is single-machine. Consider Litestream + read replicas, LiteFS, libSQL embedded replicas, or migrate to PostgreSQL or MySQL.
- TB-scale data — still works but maintenance (backup, vacuum) gets painful. Consider partitioning across multiple SQLite files or moving to a clustered DB.

For many web apps, single-node SQLite is enough up to a few hundred RPS sustained, with millions of users.

---

## 12. SQLite vs Other Databases

## Q52. SQLite vs PostgreSQL for a small web app?

**Answer:**

| Concern | SQLite | PostgreSQL |
|---------|--------|------------|
| Setup | Zero | Service to manage |
| Reads | Extremely fast (no network) | Fast (with network round-trip) |
| Writes | Single-writer, ~1k/s on SSD | Multi-writer, much higher concurrent throughput |
| Scaling | Single machine | Multi-server, replicas, partitioning |
| Operations | Backups via Litestream; trivial restore | Mature ops, well-known tooling |
| Cost | None | Server + ops |
| Best fit | Single-server apps, edge, embedded | Multi-server apps, complex queries, big data |

For a small or moderate-traffic app, SQLite + Litestream is a legitimate choice.

## Q53. SQLite vs MySQL?

**Answer:**

Same shape as the PostgreSQL comparison. MySQL has a larger surface (replication, partitioning, multiple engines) and more operational overhead. SQLite shines for single-tenant, single-server use.

## Q54. SQLite vs DuckDB?

**Answer:**

Both are single-file embedded databases, but DuckDB is OLAP and SQLite is OLTP. DuckDB stores data column-wise, vectorizes queries, and is excellent for analytics workloads. SQLite handles transactional row-shaped work much better. A common pattern is SQLite for the application's transactional data and DuckDB for ad-hoc analytics on Parquet exports.

## Q55. SQLite vs Redis for a local cache?

**Answer:**

SQLite gives you SQL queries, persistence, and transactions. Redis is faster for raw key-value operations, has rich data structures, pub/sub, and TTL. For a desktop app's local cache, SQLite usually wins. For a high-throughput shared cache across processes, Redis wins.

## Q56. Comparison table

**Answer:**

| Feature | SQLite | PostgreSQL | MySQL | MongoDB |
|---------|--------|------------|-------|---------|
| Type | Embedded SQL | Server SQL | Server SQL | Server NoSQL |
| Concurrency | Single writer | Multi-writer | Multi-writer | Multi-writer |
| Setup | None | Moderate | Moderate | Moderate |
| Replication | Litestream / LiteFS | Streaming, logical | Async, semi-sync, group | Replica sets |
| Sharding | Per-machine only | Citus / app-level | Vitess / app-level | Native |
| Best fit | Local, embedded, single-server | General-purpose RDBMS | General-purpose RDBMS | Document, scale-out |

## Q57. What do you do when SQLITE_BUSY happens under load?

**Answer:**

The default journal mode and missing `busy_timeout` are the usual culprits. Apply the production baseline:

```sql
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
```

Use `BEGIN IMMEDIATE` for writes to fail fast on contention rather than mid-transaction. Keep transactions short and avoid mixing big read and write work in one transaction.

## Q58. How do you migrate from SQLite to PostgreSQL?

**Answer:**

1. Map types (SQLite affinity to PostgreSQL strict types).
2. Export with `sqlite3 .dump` or a row-by-row script.
3. Use a tool like `pgloader`, which handles SQLite-to-PostgreSQL in one command.
4. Test queries — the PostgreSQL planner differs.
5. Plan a cutover (dual-write or scheduled downtime).

```sh
pgloader sqlite:///path/to/shop.db postgresql://user@host/shop
```
