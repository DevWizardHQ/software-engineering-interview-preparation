# SQLite Interview Questions — Basic to Advanced

**Purpose:** Senior-level SQLite knowledge for backend / mobile / full-stack interviews. SQLite is the world's most-deployed database — it's worth understanding deeply. Covers architecture, WAL, FTS5, JSON1, R*Tree, scaling patterns (Litestream, LiteFS, D1, Turso), and operations.

---

## Table of Contents

1. [SQLite Basics](#sqlite-basics)
2. [Architecture and File Format](#architecture-and-file-format)
3. [Concurrency and WAL Mode](#concurrency-and-wal-mode)
4. [Data Types and Type Affinity](#data-types-and-type-affinity)
5. [Indexes and Query Planning](#indexes-and-query-planning)
6. [Full-Text Search (FTS5)](#full-text-search-fts5)
7. [JSON1 Extension](#json1-extension)
8. [R*Tree (Geospatial)](#rtree-geospatial)
9. [Performance Tuning](#performance-tuning)
10. [Backups and Operations](#backups-and-operations)
11. [Production at Scale](#production-at-scale)
12. [SQLite vs Other Databases](#sqlite-vs-other-databases)
13. [Real Interview Scenarios](#real-interview-scenarios)

---

## SQLite Basics

### Q1. What is SQLite?

A self-contained, serverless, zero-configuration, transactional SQL database engine. The entire database is a single file on disk. Public domain. Implemented as a C library that's linked into the host application — there's no separate server process.

Most-deployed database in the world by a wide margin: every iOS / Android device, every browser, every macOS app, embedded into Python, PHP, Firefox, Chrome, and countless apps. Current major version: 3.x (3.46+ as of 2024).

---

### Q2. When should you use SQLite?

**Great fit for:**
- Mobile and desktop apps (local storage).
- Embedded devices (IoT, routers, set-top boxes).
- Browser storage (local cache, offline queue).
- Single-server web apps with moderate traffic.
- Read-heavy websites (most blogs, dashboards).
- Tests and development databases.
- Application file format (Apple, Adobe, Dropbox use SQLite as a doc format).
- Edge / serverless databases (Cloudflare D1, Turso).

**Bad fit for:**
- High-concurrency write workloads (single-writer model).
- Multi-server clusters where many clients need to write simultaneously.
- Network-accessed databases over slow links (no native client/server protocol — the file is the API).
- Massive datasets requiring partitioning across machines.

---

### Q3. "SQLite doesn't scale" — what's the truth?

It scales surprisingly well for many real-world workloads:
- **Reads** are very fast and parallel; multiple readers don't block each other.
- **Writes** are serialized to one writer at a time, but writes are typically fast (microseconds) when the working set fits in cache.
- A modern server with SSD can sustain **hundreds of writes/sec and thousands of reads/sec** on a single SQLite database.
- Many production sites (HN-class traffic) are happily on SQLite.

It doesn't scale to multi-machine concurrent writes. For that, you need a different architecture (read replicas via Litestream/LiteFS, or a different database).

---

### Q4. SQLite vs server databases — fundamental difference?

SQLite is **serverless**: the database engine runs in-process. There is no listener, no protocol, no IPC overhead. Reading from SQLite is roughly as fast as reading from your own struct.

Server databases (Postgres, MySQL, Mongo) require:
- A separate process.
- A network or socket round-trip per query.
- Authentication, connection pooling, etc.

SQLite trades horizontal scaling for radical simplicity and speed at small scale.

---

### Q5. What ships in SQLite by default?

Built-in (no extension needed):
- Standard SQL with most modern features (CTEs, window functions, UPSERT, RETURNING, partial indexes, generated columns).
- **JSON1** (built-in since 3.38).
- **FTS3/4/5** (full-text search, built-in).
- **R*Tree** (multi-dimensional index, built-in).
- **Geopoly** (geographical polygons).
- Loadable extensions (you can add custom C extensions).

---

## Architecture and File Format

### Q6. Anatomy of an SQLite file?

The database is a single file divided into **pages** (default 4096 bytes; configurable up to 65536). Pages hold:
- A header.
- B-tree pages for tables and indexes.
- Overflow pages for large rows.
- Free pages.

Tables and indexes are stored as B-trees keyed by `rowid` (or the declared primary key for `WITHOUT ROWID` tables). The first page contains the file header.

Useful inspection tools: `sqlite3_analyzer`, `sqldiff`, `dbstat` virtual table.

---

### Q7. What is `rowid`?

Every regular SQLite table has an implicit 64-bit integer `rowid`. If you declare an `INTEGER PRIMARY KEY`, that column **is** the rowid (alias). Otherwise SQLite assigns one automatically.

Rowid lookups are the fastest path: a single B-tree descent. Indexes that don't cover the query do a rowid lookup back into the table.

```sql
CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
-- id is the rowid alias

CREATE TABLE users_uuid (uuid TEXT PRIMARY KEY, name TEXT);
-- regular table; rowid is hidden but exists; primary-key index is separate
```

---

### Q8. What are `WITHOUT ROWID` tables?

```sql
CREATE TABLE config (
  key TEXT PRIMARY KEY,
  value TEXT
) WITHOUT ROWID;
```

The primary key directly addresses rows — no separate hidden rowid index. Wins for:
- Non-integer primary keys (UUIDs, strings).
- Wide rows where the index-then-fetch indirection costs.

Trade-offs: blob/large-text rows are less efficient (`WITHOUT ROWID` doesn't use overflow as effectively). Don't use for tables where the row size dominates the primary-key size.

---

### Q9. STRICT tables?

Since 3.37 (2021), you can declare strict typing per table:

```sql
CREATE TABLE users (
  id INTEGER NOT NULL,
  name TEXT NOT NULL,
  age INT
) STRICT;
```

Without STRICT, SQLite has type **affinity** — it accepts string `"abc"` into an `INTEGER` column. STRICT enforces the declared types and rejects mismatches. Always use STRICT for new schemas where possible.

---

### Q10. How portable is the SQLite file?

Extremely. Same file works on any OS, any byte order, any 32/64-bit platform. The on-disk format is committed-stable and frozen — SQLite version 3 files written today will be readable in decades.

Backward compatibility: SQLite reads all 3.x files. Forward compatibility: new files use only legacy features unless you opt in (e.g., `PRAGMA journal_mode=wal`).

---

## Concurrency and WAL Mode

### Q11. What's the default journal mode?

`DELETE` — uses a rollback journal. Simple, slow under any concurrency. **Use WAL in production.**

```sql
PRAGMA journal_mode = WAL;
```

This is a one-time setting per database file (persists in the header).

---

### Q12. How does WAL (Write-Ahead Logging) work?

Default mode: SQLite copies pages to a journal file, modifies the DB, then deletes the journal. Writers block readers and vice versa.

**WAL mode:**
- Writers append changes to a `-wal` file (write-ahead log).
- Readers read from the main DB plus uncheckpointed pages in the WAL.
- A `-shm` shared-memory file coordinates readers/writers.
- Periodically a **checkpoint** copies WAL pages back to the main DB and resets the log.

**Benefits:**
- Readers don't block writers; writers don't block readers (for separate connections).
- Faster (fewer fsyncs).
- Crash-safe.

**Downsides:**
- Three files instead of one (`.db`, `.db-wal`, `.db-shm`).
- The WAL file grows; needs checkpoints.
- All readers/writers must be on the same machine (WAL uses shared memory — doesn't work over many network filesystems).

---

### Q13. WAL — single writer? Why?

SQLite serializes writes globally on a database. At any moment, **only one writer holds the write lock**. Readers proceed concurrently with the writer and with each other.

This is a fundamental design choice — keeps the engine simple, lock-free for readers, and safe under crashes. It's also the main scaling limit.

---

### Q14. What is `busy_timeout`?

When a writer holds the lock and another connection tries to write, the second connection gets `SQLITE_BUSY`. To wait instead of failing immediately:

```sql
PRAGMA busy_timeout = 5000;   -- ms
```

Set to a few seconds in production. Without it, you'll get spurious `database is locked` errors during contention.

---

### Q15. WAL checkpoints — how do they work?

WAL grows until checkpointed. SQLite auto-checkpoints when the WAL hits ~1000 pages (configurable: `wal_autocheckpoint`). Modes:

- `PASSIVE` — copy what we can without blocking writers (default).
- `FULL` — wait for any in-progress transactions, then checkpoint.
- `RESTART` — like FULL but block new writers until done.
- `TRUNCATE` — like RESTART, then reset the WAL file size.

```sql
PRAGMA wal_checkpoint(TRUNCATE);
```

Automate periodic `TRUNCATE` checkpoints under low load to keep the WAL small.

---

### Q16. WAL gotcha — what if a long reader holds an old snapshot?

The WAL can't be checkpointed past the oldest active reader's snapshot. A long-running read transaction blocks WAL truncation, causing the WAL to grow. Same effect as Postgres `idle in transaction`.

Mitigation: keep transactions short. Don't hold read transactions across user thinking time.

---

### Q17. Isolation levels in SQLite?

SQLite is **serializable** by default. Every transaction sees a consistent snapshot, and concurrent transactions appear to execute in some serial order.

Begin variants:
- `BEGIN` (deferred) — acquires locks lazily on first use.
- `BEGIN IMMEDIATE` — acquires write lock immediately. Avoids `SQLITE_BUSY` mid-transaction.
- `BEGIN EXCLUSIVE` — pre-acquires exclusive lock (rarely needed in WAL).

For write transactions, `BEGIN IMMEDIATE` is usually correct — fail-fast if another writer holds the lock.

---

### Q18. Can SQLite be used over a network filesystem (NFS, SMB)?

**Strongly discouraged.** Cross-process locks over network filesystems are notoriously buggy. SQLite's docs explicitly warn against it. Even WAL mode requires the `-shm` file to be on a real shared-memory filesystem.

If you need network access to a single SQLite file, run a small server in front of it (e.g., Turso, dqlite, rqlite, or a custom HTTP layer).

---

## Data Types and Type Affinity

### Q19. What are SQLite's storage classes?

- `NULL`
- `INTEGER` (1, 2, 3, 4, 6, or 8 bytes depending on value)
- `REAL` (8-byte IEEE float)
- `TEXT` (UTF-8/16)
- `BLOB`

Just five. There's no separate `BOOLEAN`, `DATE`, `TIME`, `DECIMAL` — they're stored as INTEGER, TEXT, or REAL.

---

### Q20. What is type affinity?

Each column has an *affinity* (preferred type), but SQLite will store any storage class in any column. Affinity rules:

- Column declared `INT` / `INTEGER` → INTEGER affinity.
- `TEXT` / `CHAR` / `CLOB` → TEXT.
- `BLOB` or no type → BLOB / NONE.
- `REAL` / `FLOAT` / `DOUBLE` → REAL.
- `NUMERIC` (default for `DECIMAL`, etc.) → tries integer, falls back to real or text.

Result: `INSERT INTO users(age) VALUES('forty')` succeeds in default tables. **Use STRICT tables to prevent this.**

---

### Q21. How do you store dates?

Three common conventions:
- **TEXT** as ISO 8601 (`'2025-05-05T12:00:00Z'`) — sortable, readable, Unicode-collation friendly.
- **INTEGER** Unix timestamp (seconds or millis) — compact, fast comparisons.
- **REAL** Julian day numbers — supported by `julianday()` built-in.

```sql
SELECT * FROM events WHERE created_at > strftime('%s', '2025-01-01');
```

ISO-8601 TEXT is the most common modern choice. SQLite's date functions accept all three.

---

### Q22. Booleans?

Stored as INTEGER 0 or 1. Modern SQLite recognizes `TRUE` and `FALSE` keywords.

```sql
CREATE TABLE flags (
  id INTEGER PRIMARY KEY,
  enabled INTEGER NOT NULL DEFAULT 0   -- or use BOOLEAN affinity
);
```

---

### Q23. Generated columns?

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  first TEXT,
  last TEXT,
  full_name TEXT GENERATED ALWAYS AS (first || ' ' || last) STORED
);
```

`STORED` (persists) or `VIRTUAL` (computed at read). Useful for indexed expressions and JSON paths.

---

## Indexes and Query Planning

### Q24. Index types in SQLite?

- **B-tree** (default) — single-column or composite.
- **UNIQUE** — adds uniqueness constraint.
- **Partial** — `WHERE` clause limits indexed rows.
- **Expression** — index on `LOWER(email)`, etc.
- **Covering** — multiple columns; query satisfied entirely from the index.
- **FTS5** virtual table — full-text search.
- **R*Tree** virtual table — multi-dimensional / geo.

```sql
CREATE INDEX idx_users_email_lower ON users(LOWER(email));
CREATE UNIQUE INDEX idx_users_active_email ON users(email) WHERE deleted = 0;
```

---

### Q25. How does SQLite plan queries?

The query planner uses statistics gathered by `ANALYZE`. After significant inserts, run `ANALYZE` to refresh the statistics tables (`sqlite_stat1` etc.).

Inspect plans:

```sql
EXPLAIN QUERY PLAN
SELECT * FROM users WHERE email = ?;
```

Look for `SEARCH` (index) vs `SCAN` (full table). Goal: index-driven for hot queries.

---

### Q26. Auto-indexes — what are they?

If a query joins or filters and no usable index exists, SQLite may build a transient automatic index in memory for the query. Indicated in `EXPLAIN QUERY PLAN` as `AUTOMATIC`. Convenient but a sign you might want a real index.

---

### Q27. How does SQLite store strings — does collation matter?

Collations: `BINARY` (default), `NOCASE`, `RTRIM`. Custom collations can be registered. Indexes are tied to a collation — `WHERE email = ? COLLATE NOCASE` won't use an index built without `COLLATE NOCASE`.

```sql
CREATE INDEX idx_email_nocase ON users(email COLLATE NOCASE);
```

---

## Full-Text Search (FTS5)

### Q28. What is FTS5?

A full-text search virtual table module. The current recommended FTS engine in SQLite (FTS3/4 are legacy).

```sql
CREATE VIRTUAL TABLE docs_fts USING fts5(title, body, tokenize='porter unicode61');

INSERT INTO docs_fts (title, body) VALUES ('SQLite Tutorial', 'Learn SQLite quickly...');

SELECT * FROM docs_fts WHERE docs_fts MATCH 'sqlite NEAR/3 tutorial';
SELECT title, snippet(docs_fts, 1, '<b>', '</b>', '...', 16) FROM docs_fts WHERE docs_fts MATCH 'tutorial';
SELECT title, bm25(docs_fts) AS score FROM docs_fts WHERE docs_fts MATCH 'sqlite' ORDER BY score;
```

Features:
- Tokenizers (`porter`, `unicode61`, `ascii`, custom).
- BM25 ranking out of the box.
- Phrase queries, boolean operators, prefix search, NEAR.
- Snippet extraction and highlighting.
- External-content tables (separate FTS index from base table).

---

### Q29. External-content FTS5 tables?

Best practice for production. Keep base data in a normal table; FTS5 holds only the index, pointing back to the source.

```sql
CREATE TABLE docs (id INTEGER PRIMARY KEY, title TEXT, body TEXT);

CREATE VIRTUAL TABLE docs_fts USING fts5(
  title, body,
  content='docs',
  content_rowid='id'
);

-- Triggers to keep FTS in sync
CREATE TRIGGER docs_ai AFTER INSERT ON docs BEGIN
  INSERT INTO docs_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
END;
CREATE TRIGGER docs_ad AFTER DELETE ON docs BEGIN
  INSERT INTO docs_fts(docs_fts, rowid, title, body) VALUES('delete', old.id, old.title, old.body);
END;
CREATE TRIGGER docs_au AFTER UPDATE ON docs BEGIN
  INSERT INTO docs_fts(docs_fts, rowid, title, body) VALUES('delete', old.id, old.title, old.body);
  INSERT INTO docs_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
END;
```

Saves storage; data isn't duplicated.

---

### Q30. Custom ranking?

`bm25()` accepts column weights:

```sql
SELECT title FROM docs_fts WHERE docs_fts MATCH 'sqlite'
ORDER BY bm25(docs_fts, 5.0, 1.0);   -- title weighted 5x body
```

For heavier customization, FTS5 supports user-defined ranking functions in C / via the auxiliary function API.

---

### Q31. FTS5 vs Lucene/Elasticsearch?

For embedded / single-machine FTS, FTS5 is excellent. For distributed search at scale, fuzzy matching, advanced analyzers, autocomplete suggestions, multi-language stemming — Elasticsearch / OpenSearch / Meilisearch / Atlas Search are still ahead. Pick FTS5 when search is *part* of the app rather than its core.

---

## JSON1 Extension

### Q32. What does JSON1 give you?

Built-in since SQLite 3.38 (no separate extension needed). Provides JSON manipulation functions:

```sql
CREATE TABLE products (id INTEGER PRIMARY KEY, data TEXT);
INSERT INTO products(data) VALUES ('{"name":"shirt","attrs":{"color":"red","sizes":["S","M","L"]}}');

SELECT json_extract(data, '$.name') FROM products;
SELECT data ->> '$.name' FROM products;          -- shorthand (3.38+)
SELECT data -> '$.attrs' FROM products;          -- returns JSON

SELECT * FROM products
WHERE json_extract(data, '$.attrs.color') = 'red';

-- json_each / json_tree for table-valued use
SELECT value FROM json_each(json_extract(data, '$.attrs.sizes'));
```

Functions: `json`, `json_array`, `json_object`, `json_extract`, `json_set`, `json_remove`, `json_patch`, `json_valid`, `json_type`, `json_each`, `json_tree`.

---

### Q33. JSONB in SQLite?

SQLite 3.45 (2024) introduced **JSONB** — a binary JSON storage format. Benefits:
- Faster repeated parsing (parse once, not per query).
- Slightly more compact for many shapes.
- All `json_*` functions accept JSONB.

```sql
CREATE TABLE products (id INTEGER PRIMARY KEY, data BLOB);
INSERT INTO products(data) VALUES (jsonb('{"a":1,"b":[2,3]}'));
SELECT json_extract(data, '$.a') FROM products;
```

For new schemas with frequent JSON access, prefer JSONB.

---

### Q34. Indexing JSON fields?

```sql
CREATE INDEX idx_color ON products(json_extract(data, '$.attrs.color'));

SELECT * FROM products
WHERE json_extract(data, '$.attrs.color') = 'red';   -- uses index
```

Or use a generated column:

```sql
ALTER TABLE products ADD COLUMN color TEXT
  GENERATED ALWAYS AS (json_extract(data, '$.attrs.color')) STORED;
CREATE INDEX idx_color ON products(color);
```

---

## R*Tree (Geospatial)

### Q35. What is the R*Tree module?

A built-in virtual table for indexing N-dimensional rectangles. Used for spatial / range queries.

```sql
CREATE VIRTUAL TABLE places_idx USING rtree(
  id,
  min_lon, max_lon,
  min_lat, max_lat
);

-- For points, set min == max
INSERT INTO places_idx VALUES (1, -73.98, -73.98, 40.75, 40.75);

-- Find places within a bounding box
SELECT id FROM places_idx
WHERE min_lon >= -74 AND max_lon <= -73
  AND min_lat >= 40 AND max_lat <= 41;
```

Combined with the **Geopoly** module for actual polygon containment, you get a respectable geo stack inside SQLite. For real GIS (projections, CRS conversions, complex spatial ops), **SpatiaLite** is the extension to add.

---

## Performance Tuning

### Q36. The most important PRAGMA settings?

```sql
PRAGMA journal_mode = WAL;            -- concurrency
PRAGMA synchronous = NORMAL;          -- safe + fast (FULL is default; OFF is unsafe)
PRAGMA temp_store = MEMORY;           -- temp tables in RAM
PRAGMA mmap_size = 268435456;         -- memory-mapped I/O (256MB)
PRAGMA cache_size = -64000;           -- 64MB page cache (negative = KB)
PRAGMA foreign_keys = ON;             -- off by default (!) — enable per connection
PRAGMA busy_timeout = 5000;           -- wait on lock contention
```

Defaults are conservative for embedded use. Server / web apps benefit from larger cache, mmap, and WAL.

---

### Q37. `synchronous` levels?

| Level | Behavior |
|-------|----------|
| `OFF` | No fsync. Crash = corruption. Don't. |
| `NORMAL` | fsync at WAL checkpoint, not every commit. With WAL, crash-safe. |
| `FULL` (default) | fsync after every commit. |
| `EXTRA` | Additional fsync on the directory. |

For WAL + server workloads, `NORMAL` is the sweet spot — durable up to OS crash, much faster than FULL.

---

### Q38. Why is `synchronous=NORMAL` safe with WAL?

Power loss between commit and next checkpoint may lose **the last few committed transactions**, but the database itself stays consistent. Single-machine apps usually accept this. If absolutely no committed-write loss is acceptable, use `FULL`.

---

### Q39. Bulk insert performance — best practices?

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
BEGIN;
-- Use prepared statement, bind values
INSERT INTO t VALUES (?, ?, ?);    -- repeated 100,000 times
COMMIT;
```

Wrap in a transaction → 100x+ faster than auto-commit. SQLite can do hundreds of thousands of inserts/sec on modern SSDs in WAL mode.

For massive imports: `.import` in `sqlite3` shell, or `INSERT ... SELECT` from an attached temp DB.

---

### Q40. Prepared statements?

Use them. Compiling SQL is non-trivial; prepared statements amortize parse + plan.

```python
stmt = conn.prepare("INSERT INTO t VALUES (?, ?)")
for row in rows:
    stmt.execute(row)
```

Parameter binding also prevents SQL injection.

---

### Q41. Connection-per-thread or shared connection?

SQLite connections are **not thread-safe by default** (depending on build flags / SQLite serialization mode). Recommendation:
- One connection per thread / per worker.
- Each connection sets its own pragmas (`busy_timeout`, etc.).
- For high-concurrency reads, multiple read connections + one write connection works well.

In Go, Rust, Node, Python (with `check_same_thread=False`), libraries handle this — but design with the single-writer rule in mind.

---

### Q42. Vacuum — when and why?

`VACUUM` rebuilds the database file, reclaiming free space and defragmenting. Useful after bulk deletes.

- `VACUUM;` — full rebuild; locks the DB.
- `PRAGMA auto_vacuum = INCREMENTAL;` + `PRAGMA incremental_vacuum(N);` — reclaim N pages without full rebuild.

For long-lived production databases with churn, schedule `VACUUM` during maintenance windows.

---

### Q43. ANALYZE — when?

After significant data changes, run `ANALYZE` so the planner has fresh statistics:

```sql
ANALYZE;
```

`PRAGMA optimize;` (3.18+) is a smart, cheap version that runs ANALYZE only on tables that need it.

---

## Backups and Operations

### Q44. How do you back up SQLite safely?

Several options:

1. **Online backup API** (`sqlite3_backup_*` or `.backup` in CLI) — copy a live database without taking it offline.

```
sqlite3 mydb.db ".backup 'backup.db'"
```

2. **VACUUM INTO** — atomic copy:

```sql
VACUUM INTO 'backup.db';
```

3. **File copy** — only safe with the DB shut down (and with WAL files included). Unsafe on a live DB.

4. **Litestream** — stream WAL changes to S3 / GCS / others, continuous backup with point-in-time recovery.

5. **rsync** — only with `-PRAGMA wal_checkpoint(TRUNCATE);` immediately before, and the DB quiesced.

---

### Q45. What is Litestream?

A standalone tool that watches a SQLite file's WAL and streams changes to remote storage (S3, GCS, SFTP, NFS) in near-real-time. Provides:
- Continuous backup.
- Point-in-time restore (down to seconds).
- No app changes — runs as a sidecar.

Game-changer for self-hosted apps using SQLite — gives you Postgres-grade durability with SQLite's simplicity. Litestream by Ben Johnson (also creator of LiteFS).

---

### Q46. What is LiteFS?

A FUSE filesystem that distributes SQLite database files across machines. Built by Fly.io, also by Ben Johnson. Lets you run SQLite as a primary plus replicas, with the primary handling writes and replicas serving reads.

Architecture:
- One primary node accepts writes.
- Other nodes follow the LTX (Litestream Transaction) stream.
- App reads locally for low latency; writes are forwarded to the primary.

Useful for global edge apps that want SQLite's simplicity with multi-region read latency.

---

### Q47. What is `dbstat`?

A built-in virtual table that exposes per-page statistics. Useful for understanding storage layout, fragmentation, and finding bloat.

```sql
SELECT name, SUM(payload) AS bytes
FROM dbstat
GROUP BY name
ORDER BY bytes DESC;
```

---

### Q48. Migrations — schema changes?

SQLite supports a useful subset of `ALTER TABLE`:
- Rename table.
- Rename column (3.25+).
- Add column.
- Drop column (3.35+).

For more (change column type, add CHECK to existing column), use the **12-step recipe**:
1. `BEGIN`.
2. Create new table with desired schema.
3. Copy data: `INSERT INTO new SELECT ... FROM old`.
4. Drop old table.
5. Rename new to old.
6. Recreate indexes / triggers / views.
7. `COMMIT`.

Modern frameworks (sqlx, Diesel, Prisma, Rails, Django) automate this.

---

## Production at Scale

### Q49. Cloudflare D1, Turso, Cloudflare's distributed SQLite?

- **Cloudflare D1** — managed SQLite at the edge. Each database is a standard SQLite file replicated globally; writes go to a primary region.
- **Turso** — managed libSQL (a fork of SQLite by ChiselStrike, now owned by Turso). Adds replication, embedded replicas, multi-region writes (with caveats).
- **rqlite** — distributed SQLite via Raft consensus. Good for HA configurations but trades some single-node speed.
- **dqlite** — Canonical's distributed SQLite using Raft. Used by LXD.

The pattern: SQLite for the hot path, replication for durability and geographic distribution.

---

### Q50. libSQL — what is it?

A Turso-led fork of SQLite that adds:
- Native server mode (HTTP/SQL protocol).
- Embedded replicas (read locally, replicate from a remote primary).
- WebAssembly user-defined functions.
- Native interface for HTTP and gRPC.
- Bottomless storage (S3 backing).

Drop-in compatible with SQLite at the SQL level; adds remote-friendly surfaces SQLite proper doesn't have.

---

### Q51. When does single-node SQLite stop scaling?

Practical breakpoints:
- **Sustained writes >~1k/sec**: WAL contention or fsync latency dominates. Move to bigger SSD, batch writes, or scale out.
- **Multi-server deployment**: SQLite is single-machine. Use Litestream + read replicas, LiteFS, libSQL embedded replicas, or migrate to Postgres/MySQL.
- **TB-scale data**: still works, but operations (backup, vacuum) get painful. Consider partitioning across multiple SQLite files or moving to a clustered DB.

For many web apps, single-node SQLite is enough up to a few hundred RPS sustained, with millions of users in the database.

---

## SQLite vs Other Databases

### Q52. SQLite vs Postgres for a small web app?

| Concern | SQLite | Postgres |
|---------|--------|----------|
| Setup | Zero | Service to manage |
| Reads | Extremely fast | Fast (with network round-trip) |
| Writes | Single-writer; ~1k/s on SSD | Multi-writer; far higher concurrent throughput |
| Scaling | Single machine | Multi-server, replicas, partitioning |
| Operations | Backups via Litestream; trivial restore | Mature ops, well-known tooling |
| Cost | None | Server + ops |
| Best fit | Single-server apps, edge, embedded | Multi-server apps, complex queries, big data |

For a small or moderate-traffic app, SQLite + Litestream is a legitimate choice. The "always Postgres" reflex isn't always right.

---

### Q53. SQLite vs MySQL?

Same shape as Postgres comparison. MySQL has more surface area (replication, partitioning, multi-engine), more ops overhead. SQLite shines for single-tenant, single-server.

---

### Q54. SQLite vs DuckDB?

Both single-file embedded databases — but **DuckDB is OLAP**, SQLite is **OLTP**. DuckDB stores data column-wise, vectorizes queries, and crushes analytics workloads. SQLite handles transactional row-shaped work much better.

Common pattern: SQLite for the app's transactional data, DuckDB for ad-hoc analytics on the same files (or on Parquet exports).

---

### Q55. SQLite vs Redis for a local cache?

Both work for many local cache cases. SQLite gives you SQL queries, persistence, transactions. Redis is faster for raw key-value at scale, has data structures, pub/sub, TTLs.

For a desktop app's local cache, SQLite usually wins. For a high-throughput shared cache, Redis wins.

---

### Q56. Comparison table

| Feature | SQLite | Postgres | MySQL | MongoDB |
|---------|--------|----------|-------|---------|
| Type | Embedded SQL | Server SQL | Server SQL | Server NoSQL |
| Concurrency | Single writer | Multi-writer | Multi-writer | Multi-writer |
| Setup | None | Moderate | Moderate | Moderate |
| Replication | Litestream / LiteFS | Streaming, logical | Async, semi-sync, group | Replica sets |
| Sharding | No (per-machine) | Citus, app-level | Vitess, app-level | Native |
| Best fit | Local, embedded, single-server | General-purpose RDBMS | General-purpose RDBMS | Document, scale-out |

---

## Real Interview Scenarios

### Scenario 1: "Our mobile app's SQLite database hit 1 GB and queries are slow."

**Diagnose:**
- `PRAGMA page_count;` × `PRAGMA page_size;` for actual size.
- `EXPLAIN QUERY PLAN` on hot queries — `SCAN` is the enemy.
- Run `ANALYZE`.

**Common fixes:**
- Add or refine indexes.
- Use `WITHOUT ROWID` for natural-key tables.
- Move large blobs out (filesystem with reference, or dedicated table to keep main rows narrow).
- Periodic `VACUUM` to reclaim space.
- Consider partitioning by time (separate file per year, etc.).

---

### Scenario 2: "We're getting `SQLITE_BUSY` errors under load."

**Cause:** Default journal mode (`DELETE`) or no `busy_timeout`.

**Fix:**
```sql
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
```

Use `BEGIN IMMEDIATE` for write transactions to fail fast on contention rather than mid-transaction. Keep transactions short. Don't combine read + write in one giant transaction.

---

### Scenario 3: "We're a startup with one server. Should we use SQLite?"

**Yes, often.** A single beefy server with SQLite + WAL + Litestream backing up to S3 can handle surprising traffic. The simplicity wins:
- No DB to manage.
- Backups continuous.
- Local query speed (no network).
- Easy to test (DB is a file).

You'll know when to graduate (sustained write contention, multi-region needs).

---

### Scenario 4: "Need full-text search across 10M documents."

**FTS5 with external content table.** Run a full-text index on title + body, BM25 ranking. Supports tens of millions of docs on a single SQLite file with reasonable hardware.

If you also need fuzzy matching, autocomplete, multi-language analyzers, faceted search → consider Meilisearch, Typesense, or OpenSearch.

---

### Scenario 5: "We're losing data on power loss."

**Default `synchronous=FULL` is durable.** Power loss should not lose committed data on a healthy filesystem.

If using `synchronous=OFF` for performance — that's the cause. Switch to `NORMAL` (safe with WAL) or `FULL` (safe always). Verify the underlying storage actually fsyncs (some cheap SSDs lie about fsync).

---

### Scenario 6: "We need to deploy a globally-distributed app on SQLite."

**Options:**
- **Cloudflare D1** — fully managed at the edge.
- **Turso / libSQL** — embedded replicas in app processes globally; one primary region.
- **LiteFS + Fly.io** — DIY-ish but proven.
- **rqlite** — Raft-based, multi-writer with consensus.

All accept SQLite's single-writer model and route writes to a primary; reads are local at the edge.

---

### Scenario 7: "Migrating from SQLite to Postgres."

**When:** sustained write contention, need for multi-server, complex queries hitting SQLite limits, advanced features (logical replication, partitioning).

**Process:**
1. Map types (SQLite affinity → Postgres strict types).
2. Export with `sqlite3` `.dump` or row-by-row migration script.
3. Tools: `pgloader` handles SQLite → Postgres in one command.
4. Test queries — Postgres planner differs.
5. Plan the cutover (dual-write or scheduled downtime).

---

## Senior SQLite Mantra

1. **SQLite is not a toy — it runs the world.** Don't underestimate it.
2. **WAL + `synchronous=NORMAL` + `busy_timeout` + `foreign_keys=ON` is the production baseline.**
3. **One writer at a time. Design for it, not around it.**
4. **Use STRICT tables for new schemas. Type affinity bites.**
5. **`BEGIN IMMEDIATE` for write transactions. Don't get surprised mid-transaction by `SQLITE_BUSY`.**
6. **FTS5, JSON1, R*Tree are built-in superpowers. Use them.**
7. **Litestream for backups, LiteFS / libSQL / D1 / Turso for distribution.**
8. **`EXPLAIN QUERY PLAN` and `PRAGMA optimize;` are your friends.**
9. **Bulk inserts in transactions. Always.**
10. **Don't put SQLite on NFS / SMB. Use a server in front instead.**
