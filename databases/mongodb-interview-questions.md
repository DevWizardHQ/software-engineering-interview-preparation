# MongoDB Interview Questions — Basic to Advanced

**Purpose:** Senior-level MongoDB knowledge for backend / full-stack interviews. Covers document modeling, indexing, aggregation, transactions, replication, sharding, performance tuning, and operations on Atlas.

---

## Table of Contents

1. [MongoDB Basics](#mongodb-basics)
2. [BSON, Documents, and Collections](#bson-documents-and-collections)
3. [Schema Design Patterns](#schema-design-patterns)
4. [Indexing in MongoDB](#indexing-in-mongodb)
5. [The Aggregation Pipeline](#the-aggregation-pipeline)
6. [Transactions in MongoDB](#transactions-in-mongodb)
7. [Replication and Replica Sets](#replication-and-replica-sets)
8. [Sharding](#sharding)
9. [Performance Tuning](#performance-tuning)
10. [Change Streams and Real-time](#change-streams-and-real-time)
11. [MongoDB Atlas](#mongodb-atlas)
12. [MongoDB vs SQL](#mongodb-vs-sql)
13. [Real Interview Scenarios](#real-interview-scenarios)

---

## MongoDB Basics

### Q1. What is MongoDB?

A document-oriented NoSQL database that stores data as BSON (binary JSON) documents inside collections. Schema-flexible, distributed by design (replication and sharding built-in), with a rich query language and aggregation framework. Current major version is 7.x (8.0 GA in 2024).

---

### Q2. MongoDB terminology vs SQL?

| SQL | MongoDB |
|-----|---------|
| Database | Database |
| Table | Collection |
| Row | Document |
| Column | Field |
| Primary key | `_id` |
| Join | `$lookup` (aggregation) |
| Index | Index |
| Foreign key | Manual reference or embedded |
| Schema | Optional schema validator |

---

### Q3. What's new in modern MongoDB (6.x / 7.x / 8.0)?

- **Time series collections** (5.0+, improved in 6.x and 7.x) — optimized storage for time-stamped data.
- **Queryable encryption** (6.0 GA) — encrypted fields you can still query on.
- **Clustered collections** (5.3+) — collection stored ordered by a clustered index.
- **Atlas Search** and **Atlas Vector Search** — Lucene-backed full-text and vector search, hosted.
- **`$documents`, `$densify`, `$fill`, `$setWindowFields`** in the aggregation pipeline.
- **Improved `$lookup`** performance with foreign-key indexes (concurrent execution in 7.0).
- **Compound wildcard indexes** in 7.0.
- **MongoDB 8.0:** faster bulk writes, improved query optimizer, sharding improvements (moveCollection), TLS 1.3 by default.

---

### Q4. MongoDB strengths and weaknesses?

**Strengths:**
- Flexible schema fits agile, evolving domains.
- Native horizontal scaling via sharding.
- High write throughput on single-document writes.
- Rich query language and aggregation pipeline.
- Built-in replication for HA.

**Weaknesses:**
- Multi-document transactions exist but are slower and not designed as the default operation.
- Joins across collections are expensive compared to relational engines.
- Easy to design yourself into performance corners (huge documents, unbounded arrays).
- Reporting and ad-hoc analytics are weaker than mature OLAP / SQL warehouses.

---

### Q5. When would you choose MongoDB over PostgreSQL?

- Document-shaped data with deeply nested structures (catalogs, profiles, CMS).
- Multi-tenant apps where tenants have varying schemas.
- Write-heavy event ingestion with horizontal scale-out from day one.
- Rapid prototyping where the schema is genuinely unknown.

Pick Postgres when relations dominate, you need strong constraints, complex joins, ACID across many rows, mature analytics, or transactional integrity is core.

---

## BSON, Documents, and Collections

### Q6. What is BSON?

Binary JSON. MongoDB's storage and wire format. Adds types JSON lacks: `ObjectId`, `Date`, `Decimal128`, `Binary`, `Int32`, `Int64`, `Timestamp`, `Regex`. More compact than JSON for some types, less compact for others (it adds length prefixes).

---

### Q7. What is `_id`? Why ObjectId?

Every document has a unique `_id`. If not provided, MongoDB generates an `ObjectId` (12 bytes):

```
4 bytes timestamp | 5 bytes random | 3 bytes counter
```

**Properties:**
- Roughly time-sortable (the timestamp prefix).
- Globally unique without coordination.
- Smaller than UUID (12 vs 16 bytes).

You can use any unique value (UUID, slug, integer) — `_id` is just a primary key.

---

### Q8. Document size limit?

**16 MB per document.** Hard limit. If you legitimately need larger blobs, use **GridFS** (chunks the file into a metadata + chunks collection).

But if you're approaching 16 MB, your schema is almost certainly wrong — unbounded arrays are usually the culprit.

---

### Q9. Are MongoDB writes atomic?

**Single-document writes are atomic.** Including operations on multiple fields and arrays inside one document. That's a deliberate design choice — embed what must change together.

Multi-document atomicity requires explicit transactions (since 4.0 for replica sets, 4.2 for sharded clusters).

---

### Q10. Schema validation in a "schemaless" database?

Collections can enforce JSON Schema:

```js
db.createCollection("users", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["email", "createdAt"],
      properties: {
        email: { bsonType: "string", pattern: "^.+@.+$" },
        age:   { bsonType: "int", minimum: 0, maximum: 150 },
        createdAt: { bsonType: "date" }
      }
    }
  },
  validationLevel: "strict",   // or "moderate"
  validationAction: "error"     // or "warn"
})
```

**Senior take:** "schemaless" means *flexible*, not *no schema*. Production collections should always have a validator.

---

## Schema Design Patterns

### Q11. Embed or reference?

**Embed when:**
- Data is read together most of the time.
- Child has no life independent of the parent.
- Cardinality is bounded and small (one-to-few).

**Reference when:**
- Child is queried independently.
- Cardinality is unbounded (one-to-many or many-to-many).
- Data is shared across parents.
- Embedding would push past 16 MB or cause unbounded growth.

Rule of thumb: **prefer embedding for one-to-few; reference for one-to-many.**

---

### Q12. Common MongoDB schema design patterns?

| Pattern | When to use |
|--------|-------------|
| Embedded documents | One-to-few related data |
| Subset pattern | Embed top-N items (recent reviews, latest comments), keep rest in another collection |
| Bucket pattern | Group time-series readings into buckets per hour/day |
| Computed pattern | Pre-compute totals/counts, update on write |
| Schema versioning | `schemaVersion` field per document, migrate lazily on read |
| Outlier pattern | 99% of documents are small, a few are huge — flag and store outliers separately |
| Extended reference | Duplicate hot fields from referenced doc to avoid joins |
| Tree patterns | Parent ref, child refs, ancestor array, materialized path |

---

### Q13. How do you model many-to-many in MongoDB?

Three options:
1. Array of references on one or both sides — fine when arrays stay small.
2. Separate join collection — like a SQL bridge table; necessary when relationship has its own attributes.
3. Embed snapshots — duplicate read-relevant fields if they rarely change.

```js
// Users hold roleIds; bounded — fine
{ _id: 1, name: "Alice", roleIds: [101, 102] }

// Roles hold no userIds (avoid unbounded growth)
{ _id: 101, name: "admin" }
```

---

### Q14. What's the bucket pattern?

Useful for time series and high-frequency writes.

```js
// Without bucketing — one doc per measurement (huge collection)
{ deviceId: "d1", ts: ISODate("2025-01-01T00:00:00Z"), value: 23.1 }

// Bucketed — one doc per hour per device
{
  deviceId: "d1",
  hour: ISODate("2025-01-01T00:00:00Z"),
  count: 60,
  measurements: [
    { t: 0,  v: 23.1 },
    { t: 60, v: 23.4 },
    ...
  ]
}
```

Reduces document count, leverages compression, faster range scans. Native **time series collections** automate this since 5.0.

---

### Q15. What is the outlier pattern?

Most documents fit a clean shape; a few don't (a celebrity user with 10M followers, a bestseller with 100K reviews). Flag those:

```js
{ _id: ..., followersCount: 10500000, hasOverflow: true }
// Followers stored in separate collection keyed by celebrity id.
```

Keeps the common-case query fast and prevents one outlier from bloating the schema.

---

### Q16. Avoid unbounded arrays?

Yes. Arrays that grow without bound:
- Risk hitting the 16 MB limit.
- Slow down because every update rewrites the document (and all its indexes).
- Hurt cache locality.

Cap them (subset pattern) or move to a child collection.

---

## Indexing in MongoDB

### Q17. Index types in MongoDB?

| Type | Purpose |
|------|---------|
| Single field | Index on one field |
| Compound | Index on multiple fields, ordered |
| Multikey | Index on array fields (one entry per array element) |
| Text | Full-text search across string fields |
| Geospatial (`2d`, `2dsphere`) | Geographic queries |
| Hashed | Even distribution, used as shard key |
| Wildcard | Index unknown / dynamic fields |
| TTL | Auto-expire documents |
| Partial | Index a subset matching a filter |
| Sparse | Skip docs missing the field |
| Unique | Enforce uniqueness |
| Clustered (5.3+) | Collection physically ordered by index |
| Atlas Search / Vector | Lucene-backed text and vector indexes (Atlas only) |

---

### Q18. ESR rule for compound indexes?

**Equality, Sort, Range.** When designing a compound index, list fields in this order:

1. Fields used with equality (`status: "active"`).
2. Fields used for sorting (`createdAt`).
3. Fields used in range filters (`price < 100`).

```js
db.orders.createIndex({ status: 1, createdAt: -1, total: 1 })
// Good for: { status: "shipped" } sorted by createdAt desc, total range
```

---

### Q19. What is a multikey index?

Index on an array field. One index entry per array element.

```js
{ _id: 1, tags: ["mongo", "db"] }
db.docs.createIndex({ tags: 1 })
// Two index entries: ("mongo", _id), ("db", _id)
```

Caveats:
- Compound multikey: only one indexed field can be an array.
- Big arrays explode the index — measure.
- Updates to array elements rewrite multiple index entries.

---

### Q20. TTL indexes?

Auto-delete documents after a duration.

```js
db.sessions.createIndex(
  { lastActivity: 1 },
  { expireAfterSeconds: 1800 }   // 30 min
)
```

A background thread runs ~every 60s and removes expired docs. Use cases: sessions, password reset tokens, ephemeral logs, idempotency keys.

**Gotcha:** the field must be a Date. TTL deletion isn't precise — expect lag of up to a minute.

---

### Q21. Partial vs sparse indexes?

```js
// Sparse: index docs that have the field
db.users.createIndex({ phone: 1 }, { sparse: true })

// Partial: index docs matching a filter (more flexible)
db.users.createIndex(
  { email: 1 },
  { partialFilterExpression: { active: true } }
)
```

**Partial supersedes sparse** — prefer partial. Smaller, faster indexes for specific query patterns.

---

### Q22. Text index vs Atlas Search?

- **Text index:** built-in, simple, single text index per collection, basic stemming, no relevance tuning.
- **Atlas Search:** Lucene-based, multiple analyzers, faceting, autocomplete, fuzzy, synonyms, relevance scoring.

Production search at any real scale → Atlas Search (or external like Elasticsearch/OpenSearch).

---

### Q23. Geospatial indexes?

```js
db.places.createIndex({ location: "2dsphere" })

db.places.find({
  location: {
    $near: {
      $geometry: { type: "Point", coordinates: [-73.98, 40.75] },
      $maxDistance: 1000   // meters
    }
  }
})
```

`2dsphere` for real-world coordinates (great-circle math). `2d` for flat-plane legacy.

---

### Q24. How do you tell if an index is being used?

```js
db.orders.find({ status: "shipped" }).explain("executionStats")
```

Look for:
- `winningPlan.stage`: `IXSCAN` (good), `COLLSCAN` (bad).
- `executionStats.totalDocsExamined` vs `nReturned` (closer is better).
- `executionStats.totalKeysExamined` (lower is better).

```js
// Index usage stats
db.orders.aggregate([{ $indexStats: {} }])
```

---

### Q25. When does an index hurt?

- Heavy write workloads — every index adds write cost.
- High-cardinality arrays exploding multikey indexes.
- Indexing fields you never filter on.
- Compound indexes whose prefixes overlap (redundant).
- Too many indexes (memory pressure, planner overhead).

Periodically drop unused indexes (`$indexStats` shows usage counts).

---

## The Aggregation Pipeline

### Q26. What is the aggregation pipeline?

A sequence of stages, each transforming a stream of documents.

```js
db.orders.aggregate([
  { $match: { status: "shipped" } },
  { $group: { _id: "$customerId", total: { $sum: "$amount" } } },
  { $sort: { total: -1 } },
  { $limit: 10 }
])
```

Stages run in order. The output of one stage feeds the next.

---

### Q27. Common aggregation stages?

| Stage | Purpose |
|-------|---------|
| `$match` | Filter (early = uses indexes) |
| `$project` | Reshape, add/remove fields |
| `$group` | Group + aggregate |
| `$sort` | Sort |
| `$limit` / `$skip` | Pagination |
| `$lookup` | Join with another collection |
| `$unwind` | Flatten array into multiple docs |
| `$facet` | Run sub-pipelines in parallel |
| `$bucket` / `$bucketAuto` | Histogram-style grouping |
| `$addFields` | Add computed fields |
| `$replaceRoot` | Promote nested doc to root |
| `$merge` / `$out` | Write results to a collection |
| `$setWindowFields` | Window functions (5.0+) |
| `$densify` / `$fill` | Fill time-series gaps (5.1+) |
| `$graphLookup` | Recursive lookups (trees) |

---

### Q28. Why is `$match` early so important?

`$match` placed at the start of the pipeline can use indexes; placed later, it filters docs already in memory. Same for `$sort` + `$limit` — the optimizer may push them down if they appear together.

```js
// Good: filter first, group reduced set
[ { $match: { date: { $gte: lastWeek } } }, { $group: ... } ]

// Bad: group everything, then filter
[ { $group: ... }, { $match: { date: { $gte: lastWeek } } } ]
```

---

### Q29. `$lookup` — how does it work, and what are its limits?

Left outer join from one collection to another.

```js
db.orders.aggregate([
  {
    $lookup: {
      from: "customers",
      localField: "customerId",
      foreignField: "_id",
      as: "customer"
    }
  },
  { $unwind: "$customer" }
])
```

**Caveats:**
- For each input document, MongoDB queries the foreign collection — index the `foreignField`.
- Sharded `$lookup` got better in 5.1 (foreign collection can be sharded since then).
- Avoid `$lookup` in high-throughput hot paths if you can denormalize.

The pipelined form (`pipeline:` instead of `localField/foreignField`) lets you filter / project before the join.

---

### Q30. `$unwind` gotcha?

`$unwind` produces one document per array element. A doc with a 100-element array becomes 100 docs.

```js
{ _id: 1, items: [a, b, c] }
// becomes
{ _id: 1, items: a }
{ _id: 1, items: b }
{ _id: 1, items: c }
```

Use `preserveNullAndEmptyArrays: true` to keep docs with empty/missing arrays.

Aggregation memory limit (100 MB per stage) can be hit when unwinding huge arrays. Add `allowDiskUse: true` if needed.

---

### Q31. `$facet` — what's it for?

Runs multiple sub-pipelines in parallel on the same input. Useful for dashboards.

```js
db.products.aggregate([
  {
    $facet: {
      "byCategory":    [ { $group: { _id: "$category", count: { $sum: 1 } } } ],
      "priceBuckets":  [ { $bucket: { groupBy: "$price", boundaries: [0, 50, 100, 500] } } ],
      "topRated":      [ { $sort: { rating: -1 } }, { $limit: 5 } ]
    }
  }
])
```

One pass over the input, several aggregations.

---

### Q32. `$merge` vs `$out`?

- `$out` — overwrites the target collection.
- `$merge` — upserts into the target. Supports keep-existing, replace, fail-on-match.

`$merge` is the right tool for incremental materialized views (run nightly to refresh aggregates).

---

### Q33. Window functions in aggregation?

Since 5.0:

```js
db.sales.aggregate([
  {
    $setWindowFields: {
      partitionBy: "$store",
      sortBy: { date: 1 },
      output: {
        runningTotal: { $sum: "$amount", window: { documents: ["unbounded", "current"] } },
        movingAvg7d:  { $avg: "$amount", window: { range: [-6, 0], unit: "day" } }
      }
    }
  }
])
```

Equivalent to SQL window functions. Big addition for analytics inside MongoDB.

---

### Q34. Aggregation memory limits?

Each stage is capped at 100 MB by default. Hit the cap → error unless `allowDiskUse: true` (disk spill, slower).

```js
db.collection.aggregate(pipeline, { allowDiskUse: true })
```

In Atlas, defaults are usually `true`. On-prem, you control it.

---

## Transactions in MongoDB

### Q35. When did MongoDB get transactions?

- **4.0** — multi-document ACID transactions on replica sets.
- **4.2** — distributed transactions on sharded clusters.
- Any modern app uses them sparingly when needed.

---

### Q36. How do transactions work in MongoDB?

```js
const session = client.startSession()
try {
  session.startTransaction({ readConcern: { level: "snapshot" }, writeConcern: { w: "majority" } })

  await accounts.updateOne({ _id: "A" }, { $inc: { balance: -100 } }, { session })
  await accounts.updateOne({ _id: "B" }, { $inc: { balance:  100 } }, { session })

  await session.commitTransaction()
} catch (err) {
  await session.abortTransaction()
  throw err
} finally {
  session.endSession()
}
```

Snapshot isolation, multi-document, multi-collection, multi-shard.

---

### Q37. Transaction limitations / costs?

- Default 60-second timeout (`transactionLifetimeLimitSeconds`).
- Slower than single-doc writes — extra coordination.
- Hold locks → can cause write conflicts.
- Sharded transactions add cross-shard coordination.
- If your design needs transactions on every write, your schema is probably wrong (embed!).

The first design move in Mongo is "can I make this a single-document write?" Transactions are the escape hatch.

---

### Q38. Read concern and write concern?

**Write concern (`w`):**
- `1` — primary acknowledged (default for some drivers, fast, less safe).
- `"majority"` — majority of replica set acknowledged (durable through failover).
- `0` — fire and forget (don't use for anything important).

**Read concern:**
- `"local"` — fastest, may read uncommitted data.
- `"majority"` — only data committed to majority.
- `"snapshot"` — point-in-time snapshot (transactions).
- `"linearizable"` — strongest, slowest.

Production default for important writes: `w: "majority"`.

---

## Replication and Replica Sets

### Q39. What is a replica set?

A group of `mongod` instances maintaining the same data. One primary, multiple secondaries. Writes go to the primary, replicate via the **oplog** (operation log) to secondaries.

Standard production deployment is **3 nodes** (PSS) or **5 nodes** (PSSSS). Avoid even-numbered sets — they don't help with quorum.

---

### Q40. What is the oplog?

A capped collection (`local.oplog.rs`) on each replica-set member. The primary writes operations to the oplog; secondaries tail it and apply ops.

- Sized by `--oplogSize` or auto-sized to ~5% of free disk.
- A secondary that falls behind the oplog window must do a full resync.
- Oplog window monitoring is essential.

---

### Q41. How does failover work?

1. Members heartbeat every 2 seconds.
2. Primary unreachable for `electionTimeoutMillis` (default 10s).
3. An eligible secondary calls an election.
4. Majority of members vote — new primary.
5. Drivers detect topology change and route writes to new primary (default retryable writes resend).

Typical failover: 10–30 seconds of write unavailability.

---

### Q42. Read preferences?

| Preference | Reads from |
|------------|------------|
| `primary` (default) | Primary only |
| `primaryPreferred` | Primary; fall back to secondary |
| `secondary` | Secondary only |
| `secondaryPreferred` | Secondary; fall back to primary |
| `nearest` | Lowest network latency member |

Reading from secondaries scales reads but secondaries can be stale. Use tags to route to specific replicas (e.g., analytics workloads on a dedicated secondary).

---

### Q43. Arbiter — should you use one?

An arbiter votes in elections but holds no data. Useful only for budget reasons (PSA: primary-secondary-arbiter).

**Avoid in production for important data.** PSA can lose data on certain failure scenarios because you only have one full data-bearing secondary. Use PSS instead.

---

### Q44. Hidden / delayed members?

- **Hidden:** invisible to clients, used for backups or analytics without competing for query traffic.
- **Delayed:** intentionally lags behind primary by N seconds. Recovery option for "oops, I dropped the wrong collection."

---

## Sharding

### Q45. What is sharding?

Horizontal partitioning across multiple shards. Each shard is itself a replica set. A `mongos` router directs queries based on the shard key.

Architecture:
- **Config servers** (replica set) — hold cluster metadata.
- **Shards** (replica sets) — hold data.
- **mongos** — stateless routers; clients connect through them.

---

### Q46. What is a shard key?

The field(s) MongoDB uses to distribute documents across shards. Choosing it well is the most important sharding decision.

**Good shard key:**
- High cardinality (many distinct values).
- Even distribution of writes (avoids hot shards).
- Used by most queries (so queries target one or few shards).
- Monotonically *non*-increasing (or use hashed sharding).

**Bad shard keys:** `createdAt` (all writes hit one shard), low-cardinality fields (`status`).

---

### Q47. Hashed vs ranged sharding?

- **Ranged (default):** chunks based on key ranges. Range queries on the shard key are efficient. Risk: hotspots if key is monotonic.
- **Hashed:** key is hashed before placement. Even distribution but range queries scatter to all shards.

Often paired: hashed sharding for ingest spread; queries target by app-specific routing.

---

### Q48. Compound and zone sharding?

- **Compound shard keys** — distribute by multiple fields. Common: `{ tenantId: 1, _id: 1 }` (multi-tenant apps).
- **Zone sharding** — pin specific key ranges to specific shards. Useful for geo-locality (EU data on EU shards).

---

### Q49. Resharding?

Pre-5.0, changing the shard key was painful. **5.0+ supports `reshardCollection`** — online resharding to a new key. 7.0+ adds `moveCollection`. Plan ahead, but you have an escape hatch now.

---

### Q50. How do queries work across shards?

- **Targeted query:** includes the shard key → mongos sends to one shard.
- **Scatter-gather:** doesn't include shard key → mongos hits every shard, merges results.

Scatter-gather destroys throughput at scale. **Design queries to include the shard key.**

---

## Performance Tuning

### Q51. How do you find slow queries?

```js
// Set profiler to capture queries > 100ms
db.setProfilingLevel(1, { slowms: 100 })

// Inspect
db.system.profile.find({ millis: { $gt: 100 } }).sort({ ts: -1 })
```

Atlas: Performance Advisor and Query Profiler in the UI.

---

### Q52. `explain()` modes?

```js
db.coll.find(...).explain("queryPlanner")    // plan only
db.coll.find(...).explain("executionStats")  // run + collect timing
db.coll.find(...).explain("allPlansExecution") // all candidate plans
```

For aggregations: `db.coll.aggregate(pipeline, { explain: true })`.

---

### Q53. Common MongoDB performance pitfalls?

- COLLSCAN on hot queries → missing index.
- Compound index in wrong order (violates ESR).
- Ever-growing arrays inside documents.
- Updates that make documents grow → moves on disk (less of an issue with WiredTiger but still affects index entries).
- Too many indexes → write amplification.
- `$lookup` in tight loops where denormalizing would be cheaper.
- Not bounding pagination → deep `skip` is O(n).

---

### Q54. How do you paginate efficiently?

`skip` is O(n). Don't use it past a few thousand.

**Cursor-based pagination:**
```js
// Page 1
db.posts.find({}).sort({ _id: -1 }).limit(20)

// Page 2 — pass last _id
db.posts.find({ _id: { $lt: lastIdFromPage1 } }).sort({ _id: -1 }).limit(20)
```

Stable, fast at any depth. Indexes on the sort key.

---

### Q55. Working set and memory?

WiredTiger caches data and indexes in memory. Default cache: ~50% of (RAM - 1GB). Working set = data + indexes touched by hot queries.

If working set fits in cache → fast. If not → page faults, slow.

```js
db.serverStatus().wiredTiger.cache
```

Indicators of memory pressure: high `bytes read into cache`, low `pages evicted` ratio, high page-fault rate.

---

### Q56. Connection pooling?

The driver maintains a pool. Defaults are usually fine, but on serverless / Lambda, watch for connection storms — set `maxPoolSize` low and reuse the client across invocations.

For Mongo Atlas serverless / shared tier, monitor connection limits closely.

---

## Change Streams and Real-time

### Q57. What are change streams?

A real-time event stream of insert/update/delete/replace events on a collection, database, or deployment. Built on the oplog. Requires a replica set (or sharded cluster).

```js
const stream = db.orders.watch([{ $match: { "fullDocument.status": "paid" } }])
for await (const event of stream) {
  console.log(event.operationType, event.fullDocument)
}
```

---

### Q58. Use cases for change streams?

- Real-time UI updates.
- Cache invalidation.
- Driving downstream pipelines (search index, data warehouse).
- Cross-region replication via app code.
- Outbox pattern alternative.

Change streams give you `resumeToken` for replay-after-crash semantics.

---

### Q59. Change streams vs polling?

Polling: query every N seconds. Wastes resources, lags. Change streams: server pushes only on actual changes. Always prefer change streams for real-time work.

---

## MongoDB Atlas

### Q60. What is Atlas?

MongoDB's managed cloud service (AWS, GCP, Azure). Handles provisioning, backups, monitoring, scaling, security, and updates.

Atlas-only features:
- **Atlas Search** (Lucene-backed FTS).
- **Atlas Vector Search** (vector embeddings, for AI / RAG).
- **Atlas Data Federation** (query S3, other DBs alongside Mongo).
- **Atlas Triggers / Functions** — serverless code on DB events.
- **Online Archive** — tier cold data to cheaper storage.

---

### Q61. Atlas backup options?

- **Continuous Cloud Backup** — point-in-time recovery, granular.
- **Snapshot backup** — periodic snapshots.
- **On-demand snapshots** for ad-hoc.

Restore tested regularly is the only backup that works. PIT to a 1-second granularity is the standard for critical workloads.

---

### Q62. How do you secure MongoDB in production?

- TLS on wire (default in Atlas, configure on-prem).
- SCRAM auth or X.509 / LDAP / Kerberos.
- Per-database roles.
- IP allowlisting / private endpoint (PrivateLink, VPC peering).
- Encryption at rest.
- **Client-side field-level encryption** for sensitive fields (PCI/PII).
- **Queryable encryption** (6.0+) — encrypted-but-searchable.
- Audit logs.
- No public-internet exposure with default users (the Mongo ransomware era was caused by this).

---

## MongoDB vs SQL

### Q63. ACID — is MongoDB ACID?

Single-document ops: yes (always).
Multi-document: yes since 4.0 with explicit transactions.
Sharded multi-document: yes since 4.2.

Comparing apples to apples: a Postgres / MySQL transaction is the everyday unit; a Mongo transaction is the *occasional* unit.

---

### Q64. Joins — do you really need them?

In MongoDB, you avoid joins by embedding or using the extended-reference pattern. Where SQL would join 5 tables, MongoDB might serve a single document.

When you do need joins: `$lookup`. Performance is acceptable for moderate scale, painful for hot paths at high scale.

---

### Q65. When does Postgres beat MongoDB?

- Strong relational invariants (referential integrity, complex foreign keys).
- Heavy analytics and reporting.
- Multi-row transactions are the norm, not the exception.
- Mature SQL tooling needed (BI tools, ORMs, migrations).
- Need flexible JSONB inside an otherwise-relational schema (Postgres JSONB is excellent).

---

### Q66. Comparison table

| Concern | MongoDB | PostgreSQL |
|---------|---------|------------|
| Schema | Flexible / per-doc | Strict / migrations |
| Joins | `$lookup`, mostly avoided | Native, optimal |
| Horizontal scale | Native sharding | Logical / Citus / partition by app |
| Replication | Replica sets, automatic failover | Streaming, more setup |
| Transactions | Single-doc default; multi-doc available | First-class everywhere |
| Aggregations | Aggregation pipeline | SQL + window functions |
| Full-text | Atlas Search | `tsvector` / extensions |
| JSON support | Native (BSON) | JSONB (excellent) |
| Operational maturity | Strong (Atlas) | Strong (RDS, Cloud SQL) |
| Best fit | Document-shaped, flexible, sharded | Relational, mixed workloads |

---

## Real Interview Scenarios

### Scenario 1: "We have 500 GB of orders. Reads are fast for recent orders, slow for old ones."

**Diagnosis:** Working set bigger than RAM. Old orders force disk reads.

**Fixes:**
- TTL or Online Archive for orders > 2 years (move cold data out of hot cache).
- Time-series collection or bucketed storage.
- Add a covered index for the most common query so the engine never reads the document.
- Shard by `{ customerId: "hashed" }` if cross-customer access is naturally partitioned.

---

### Scenario 2: "Inserts started failing with WriteConflict during a spike."

**Cause:** Multi-document transactions hitting the same documents, retrying, hitting `transactionLifetimeLimitSeconds`.

**Fixes:**
- Reduce contention — make hot documents smaller (split).
- Use single-doc operators where possible (`$inc`, atomic).
- Smaller, faster transactions (don't do I/O between operations).
- Implement retry with backoff in the driver (drivers have retryable writes; transactions need manual retry on transient errors).

---

### Scenario 3: "Our dashboard query takes 30 seconds."

**Approach:**
1. `explain("executionStats")` on the aggregation.
2. Is `$match` early enough? Are indexes used?
3. `$lookup` on un-indexed `foreignField` — index it.
4. Big `$group` with high cardinality — push down to a `$merge` materialized view, refresh on a schedule.
5. Atlas: turn on Query Profiler.

---

### Scenario 4: "Our shard cluster has one shard at 90% utilization, others at 20%."

**Cause:** Shard key skew. All writes for one tenant or hot key landing on one shard.

**Fixes:**
- Verify chunk distribution: `sh.status()`.
- Check shard key cardinality and write distribution.
- Reshard to a better key (5.0+: `reshardCollection`).
- Zone sharding for unbalanced tenants (move heavy tenants to dedicated shards).

---

### Scenario 5: "We need to record clicks at 50,000 events/sec."

**Design:**
- Time series collection or bucket pattern.
- Hashed shard key for write distribution.
- Avoid indexes you won't query on — every index is a write multiplier.
- Async writes from app to a queue (Kafka), batch insert from a consumer.
- Roll up to materialized aggregates with `$merge` for dashboards, instead of querying raw events.

---

### Scenario 6: "An ALTER-equivalent migration on 100M documents will take hours."

**Approach:**
- MongoDB has no true "ALTER" — schema migrations are app-level.
- Use the **schema versioning pattern**: write new docs in v2, migrate old docs lazily on read.
- For backfills, run in batches with `bulkWrite`, throttled, off-peak.
- Avoid `db.collection.updateMany({}, ...)` on huge collections — chunk by `_id` ranges.

---

## Senior MongoDB Mantra

1. **Embed for one-to-few, reference for one-to-many.**
2. **Single-document atomicity is the design unit. Transactions are the escape hatch.**
3. **ESR for compound indexes. Always.**
4. **Shard key choice is forever-ish — pick for cardinality, distribution, and query targeting.**
5. **`$match` early, indexes everywhere they help, `$lookup` only when you must.**
6. **Bound your arrays. Bound your documents. 16 MB is a wall, not a goal.**
7. **TTL indexes for ephemeral data. Time series collections for time series.**
8. **Read from secondaries to scale reads, but accept staleness.**
9. **Atlas Search for production text search. Atlas Vector Search for embeddings.**
10. **Test PIT restores quarterly. Backups you haven't restored aren't backups.**
