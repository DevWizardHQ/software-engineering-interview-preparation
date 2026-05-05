# MongoDB Interview Q&A — Basic to Advanced

**Purpose:** Practical MongoDB knowledge for backend and full-stack interviews. Each topic uses a clear question, a plain-language answer, and a runnable example.

---

## Table of Contents

1. MongoDB Basics
2. BSON, Documents, and Collections
3. Schema Design Patterns
4. Indexing
5. Aggregation Pipeline
6. Transactions
7. Replication and Replica Sets
8. Sharding
9. Performance Tuning
10. Change Streams
11. MongoDB Atlas
12. MongoDB vs SQL

---

## 1. MongoDB Basics

## Q1. What is MongoDB?

**Answer:**

MongoDB is a document-oriented NoSQL database. It stores data as BSON (binary JSON) documents inside collections. Unlike a relational database, documents in the same collection can have different fields. MongoDB has built-in support for replication, sharding, and a rich aggregation framework.

```js
// A document
{
  _id: ObjectId("..."),
  name: "Alice",
  email: "alice@example.com",
  addresses: [
    { type: "home",  city: "NYC" },
    { type: "work",  city: "Boston" }
  ]
}
```

## Q2. How does MongoDB terminology compare to SQL?

**Answer:**

| SQL | MongoDB |
|-----|---------|
| Database | Database |
| Table | Collection |
| Row | Document |
| Column | Field |
| Primary key | `_id` |
| Join | `$lookup` (in aggregation) |
| Foreign key | Manual reference or embedding |
| Schema | Optional schema validator |

## Q3. What's new in modern MongoDB (6.x / 7.x / 8.x)?

**Answer:**

- Time-series collections optimized for time-stamped data.
- Queryable encryption — encrypted fields you can still query on.
- Clustered collections — collection physically ordered by a clustered index.
- Atlas Search and Atlas Vector Search — Lucene-backed full-text and vector search.
- New aggregation stages: `$documents`, `$densify`, `$fill`, `$setWindowFields`.
- Online resharding (`reshardCollection`) and `moveCollection`.
- Compound wildcard indexes (7.0).
- 8.0: faster bulk writes, optimizer improvements.

## Q4. What are MongoDB's strengths and weaknesses?

**Answer:**

Strengths:

- Flexible schema fits agile, evolving domains.
- Native horizontal scaling via sharding.
- High write throughput on single-document writes.
- Rich aggregation pipeline.
- Replica sets give automatic failover.

Weaknesses:

- Multi-document transactions exist but are slower than single-doc operations.
- Joins across collections are more expensive than in a relational engine.
- Easy to design poorly (huge documents, unbounded arrays).
- Reporting and ad-hoc analytics are weaker than SQL warehouses.

## Q5. When would you choose MongoDB over PostgreSQL?

**Answer:**

- Document-shaped data with deep nesting (catalogs, profiles, CMS).
- Multi-tenant apps where tenants have different fields.
- Write-heavy event ingestion needing horizontal scale-out.
- Rapid prototyping where the schema is genuinely unknown.

Choose Postgres when relations dominate, you need strong constraints and joins, multi-row transactions are the norm, or you need mature SQL analytics.

---

## 2. BSON, Documents, and Collections

## Q6. What is BSON?

**Answer:**

BSON is MongoDB's binary serialization format for documents. It is similar to JSON but adds types JSON lacks: `ObjectId`, `Date`, `Decimal128`, `Binary`, `Int32`, `Int64`, `Timestamp`, and regular expression. BSON is used for both on-disk storage and the wire protocol.

## Q7. What is `_id`? Why ObjectId?

**Answer:**

Every MongoDB document has a unique `_id`. If you don't supply one, the driver generates an `ObjectId` — a 12-byte value with this layout:

```
| 4 bytes timestamp | 5 bytes random | 3 bytes counter |
```

ObjectIds are roughly time-sortable and globally unique without coordination. You can use any unique value (UUID, slug, integer) — `_id` is just the primary key.

```js
db.users.insertOne({ name: "Alice" });
// _id is auto-generated
```

## Q8. What is the document size limit?

**Answer:**

A single document is limited to 16 MB. If you legitimately need to store larger blobs, use GridFS, which stores metadata in one collection and chunks of the file in another. If your documents are approaching 16 MB, the design is almost always wrong — usually an unbounded array.

## Q9. Are MongoDB writes atomic?

**Answer:**

Single-document writes are always atomic, including operations on multiple fields and nested arrays inside the same document. This is a deliberate design — the way to make several updates atomic in MongoDB is to embed them in one document. Multi-document atomicity requires explicit transactions.

```js
// Atomic in one document update
db.accounts.updateOne(
  { _id: "A" },
  { $inc: { balance: -100, version: 1 } }
);
```

## Q10. Can you enforce a schema?

**Answer:**

Yes. Collections support JSON Schema validators. "Schemaless" really means "flexible" — production collections should always have one.

```js
db.createCollection("users", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["email", "createdAt"],
      properties: {
        email:     { bsonType: "string", pattern: "^.+@.+$" },
        age:       { bsonType: "int", minimum: 0, maximum: 150 },
        createdAt: { bsonType: "date" }
      }
    }
  },
  validationLevel:  "strict",
  validationAction: "error"
});
```

---

## 3. Schema Design Patterns

## Q11. Should you embed or reference?

**Answer:**

Embed when the data is read together, the child has no life independent of the parent, and the cardinality is bounded. Reference when the child is queried independently, the cardinality is unbounded, or the data is shared.

A simple rule: embed for one-to-few; reference for one-to-many.

```js
// Embed (one user has a few addresses)
{ _id: 1, name: "Alice", addresses: [{ city: "NYC" }, { city: "Boston" }] }

// Reference (one user has many orders)
db.users.findOne({ _id: 1 });
db.orders.find({ userId: 1 });
```

## Q12. What are common MongoDB schema patterns?

**Answer:**

| Pattern | Use case |
|---------|----------|
| Embedded documents | One-to-few related data |
| Subset pattern | Embed top-N items; keep rest in another collection |
| Bucket pattern | Group time-series readings into buckets |
| Computed pattern | Pre-compute totals/counts; update on write |
| Schema versioning | `schemaVersion` field; migrate lazily on read |
| Outlier pattern | Flag and store rare-but-huge documents separately |
| Extended reference | Duplicate hot fields to avoid `$lookup` |
| Tree patterns | Parent ref, ancestor array, materialized path |

## Q13. How do you model many-to-many?

**Answer:**

Three options:

1. Array of IDs on one side (works when arrays stay small).
2. Separate join collection — like a SQL bridge table; needed when the relationship has its own attributes.
3. Embed snapshots — duplicate fields that rarely change.

```js
// Roles array on user (bounded)
{ _id: 1, name: "Alice", roleIds: [101, 102] }

// Separate collection for relationship attributes
db.userRoles.insertOne({ userId: 1, roleId: 101, assignedAt: new Date() });
```

## Q14. What is the bucket pattern?

**Answer:**

Group many small time-series writes into one larger document, keyed by a time bucket. Reduces document count, improves compression, and speeds up range scans.

```js
// Without bucketing — one document per measurement (huge collection)
{ deviceId: "d1", ts: ISODate("2025-01-01T00:00:00Z"), value: 23.1 }

// Bucketed — one document per hour per device
{
  deviceId: "d1",
  hour: ISODate("2025-01-01T00:00:00Z"),
  count: 60,
  measurements: [
    { t:  0, v: 23.1 },
    { t: 60, v: 23.4 }
  ]
}
```

Native time-series collections automate this since 5.0.

```js
db.createCollection("metrics", {
  timeseries: {
    timeField: "ts",
    metaField: "deviceId",
    granularity: "minutes"
  }
});
```

## Q15. What is the outlier pattern?

**Answer:**

When most documents share a clean shape but a few are huge (a celebrity user with millions of followers), flag the outliers and store the bulk in a separate collection. This keeps the common-case query fast.

```js
{ _id: 1, name: "Normal user", followers: [/* a few */] }

{ _id: 2, name: "Celebrity",
  followersCount: 10500000,
  hasOverflow: true,
  followers: [/* truncated, top N */] }

// Full follower list lives in another collection keyed by celebrity id
db.followerOverflow.find({ celebId: 2 });
```

## Q16. Why avoid unbounded arrays?

**Answer:**

Arrays that grow without limit:

- Risk hitting the 16 MB document limit.
- Force every update to rewrite the document and update all index entries.
- Hurt cache locality and overall throughput.

Cap them with the subset pattern, or move them into a child collection.

---

## 4. Indexing

## Q17. What index types does MongoDB support?

**Answer:**

| Type | Use |
|------|-----|
| Single field | One field |
| Compound | Multiple fields, ordered |
| Multikey | Index on array fields (one entry per element) |
| Text | Full-text search across string fields |
| Geospatial (`2dsphere`, `2d`) | Geographic queries |
| Hashed | Even distribution; common shard key |
| Wildcard | Index unknown / dynamic fields |
| TTL | Auto-expire documents |
| Partial | Index a subset matching a filter |
| Sparse | Skip docs missing the field |
| Unique | Enforce uniqueness |
| Atlas Search / Vector | Lucene-backed (Atlas only) |

```js
db.users.createIndex({ email: 1 }, { unique: true });
db.orders.createIndex({ userId: 1, createdAt: -1 });
db.places.createIndex({ location: "2dsphere" });
```

## Q18. What is the ESR rule for compound indexes?

**Answer:**

Equality, Sort, Range. When designing a compound index, list fields in this order:

1. Fields used with equality.
2. Fields used for sorting.
3. Fields used in range filters.

```js
db.orders.createIndex({ status: 1, createdAt: -1, total: 1 });

// Fits ESR: equality on status, sort on createdAt, range on total
db.orders.find({ status: "shipped", total: { $gt: 100 } })
         .sort({ createdAt: -1 });
```

## Q19. What is a multikey index?

**Answer:**

A multikey index is built on an array field. MongoDB creates one index entry per array element.

```js
db.docs.insertOne({ _id: 1, tags: ["mongo", "db"] });
db.docs.createIndex({ tags: 1 });

// Two index entries: ("mongo", 1), ("db", 1)
db.docs.find({ tags: "mongo" });
```

Caveats:

- Only one indexed field can be an array in a compound multikey index.
- Large arrays can blow up index size.
- Updates to array elements rewrite multiple index entries.

## Q20. What is a TTL index?

**Answer:**

A TTL (time-to-live) index automatically removes documents after a duration. Common uses are sessions, password-reset tokens, and ephemeral logs.

```js
db.sessions.createIndex(
  { lastActivity: 1 },
  { expireAfterSeconds: 1800 }   // 30 minutes
);
```

A background thread runs about every 60 seconds, so deletion is not exact to the second.

## Q21. What is the difference between a partial index and a sparse index?

**Answer:**

A sparse index excludes documents that lack the indexed field. A partial index excludes documents that don't match a filter expression — much more flexible. Prefer partial.

```js
// Sparse: skip docs without phone
db.users.createIndex({ phone: 1 }, { sparse: true });

// Partial: only index active users
db.users.createIndex(
  { email: 1 },
  { partialFilterExpression: { active: true } }
);
```

## Q22. Text index vs Atlas Search?

**Answer:**

- Text index: built into Mongo, simple, one per collection, basic stemming, no relevance tuning.
- Atlas Search: Lucene-based, multiple analyzers, faceting, autocomplete, fuzzy search, synonyms, relevance scoring.

For real production search, use Atlas Search or an external engine like Elasticsearch.

```js
// Built-in text index
db.articles.createIndex({ title: "text", body: "text" });

db.articles.find({ $text: { $search: "machine learning" } });
```

## Q23. How do you do geospatial queries?

**Answer:**

Use a `2dsphere` index for real-world coordinates.

```js
db.places.createIndex({ location: "2dsphere" });

db.places.find({
  location: {
    $near: {
      $geometry: { type: "Point", coordinates: [-73.98, 40.75] },
      $maxDistance: 1000   // meters
    }
  }
});
```

## Q24. How do you check if an index is being used?

**Answer:**

Run `explain("executionStats")` and look at the winning plan and stats.

```js
db.orders.find({ status: "shipped" }).explain("executionStats");
```

What to look for:

- `winningPlan.stage`: `IXSCAN` (good), `COLLSCAN` (bad).
- `executionStats.totalDocsExamined` close to `nReturned` (the closer, the better).
- `executionStats.totalKeysExamined` low.

You can also see usage statistics for every index:

```js
db.orders.aggregate([{ $indexStats: {} }]);
```

## Q25. When does an index hurt?

**Answer:**

- Heavy write workloads — every index multiplies write cost.
- Indexes you never use in queries.
- Multikey indexes on huge arrays.
- Too many overlapping compound indexes.

Periodically inspect `$indexStats` and drop unused indexes.

---

## 5. Aggregation Pipeline

## Q26. What is the aggregation pipeline?

**Answer:**

A sequence of stages, where each stage transforms a stream of documents and feeds the next. It is MongoDB's analog of complex SQL with GROUP BY, JOIN, and window functions.

```js
db.orders.aggregate([
  { $match: { status: "shipped" } },
  { $group: { _id: "$customerId", total: { $sum: "$amount" } } },
  { $sort:  { total: -1 } },
  { $limit: 10 }
]);
```

## Q27. What are common aggregation stages?

**Answer:**

| Stage | Purpose |
|-------|---------|
| `$match` | Filter (early uses indexes) |
| `$project` | Reshape, add or remove fields |
| `$group` | Group and aggregate |
| `$sort` | Sort |
| `$limit` / `$skip` | Pagination |
| `$lookup` | Join with another collection |
| `$unwind` | Flatten array into multiple docs |
| `$facet` | Run sub-pipelines in parallel |
| `$bucket` / `$bucketAuto` | Histogram-style grouping |
| `$addFields` | Add computed fields |
| `$replaceRoot` | Promote nested doc to top level |
| `$merge` / `$out` | Write results to a collection |
| `$setWindowFields` | Window functions (5.0+) |
| `$graphLookup` | Recursive lookups (trees) |

## Q28. Why is `$match` early important?

**Answer:**

`$match` placed at the start of the pipeline can use indexes; later, it filters documents already in memory. The same applies to `$sort` followed by `$limit` — when adjacent and early, the optimizer can push them into an index sort.

```js
// Good: filter first
[ { $match: { date: { $gte: lastWeek } } }, { $group: ... } ]

// Bad: group everything, then filter
[ { $group: ... }, { $match: { date: { $gte: lastWeek } } } ]
```

## Q29. How does `$lookup` work?

**Answer:**

`$lookup` performs a left-outer join from the input collection to another collection.

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
]);
```

Index the `foreignField` for performance. For each input document, MongoDB queries the foreign collection — this can be expensive on hot paths. Consider denormalization (extended reference) when `$lookup` becomes the bottleneck.

## Q30. What is the `$unwind` gotcha?

**Answer:**

`$unwind` produces one document per array element. A document with a 100-element array becomes 100 documents.

```js
{ _id: 1, items: ["a", "b", "c"] }
// becomes
{ _id: 1, items: "a" }
{ _id: 1, items: "b" }
{ _id: 1, items: "c" }
```

Use `preserveNullAndEmptyArrays: true` to keep documents with empty or missing arrays:

```js
{ $unwind: { path: "$items", preserveNullAndEmptyArrays: true } }
```

## Q31. What is `$facet`?

**Answer:**

`$facet` runs multiple sub-pipelines on the same input in parallel — perfect for dashboards.

```js
db.products.aggregate([
  {
    $facet: {
      byCategory: [
        { $group: { _id: "$category", count: { $sum: 1 } } }
      ],
      priceBuckets: [
        { $bucket: { groupBy: "$price", boundaries: [0, 50, 100, 500] } }
      ],
      topRated: [
        { $sort: { rating: -1 } },
        { $limit: 5 }
      ]
    }
  }
]);
```

## Q32. What is the difference between `$merge` and `$out`?

**Answer:**

- `$out` overwrites the target collection.
- `$merge` upserts into the target. It supports keep-existing, replace, and fail-on-match modes.

`$merge` is the right tool for incremental materialized views — schedule it nightly to refresh aggregated results.

```js
db.orders.aggregate([
  { $group: { _id: "$customerId", total: { $sum: "$amount" } } },
  { $merge: { into: "customer_totals", whenMatched: "replace" } }
]);
```

## Q33. How do you use window functions?

**Answer:**

`$setWindowFields` (5.0+) provides SQL-like window functions.

```js
db.sales.aggregate([
  {
    $setWindowFields: {
      partitionBy: "$store",
      sortBy: { date: 1 },
      output: {
        runningTotal: {
          $sum: "$amount",
          window: { documents: ["unbounded", "current"] }
        },
        movingAvg7d: {
          $avg: "$amount",
          window: { range: [-6, 0], unit: "day" }
        }
      }
    }
  }
]);
```

## Q34. What are aggregation memory limits?

**Answer:**

Each stage is capped at 100 MB by default. If you exceed it, you get an error unless you set `allowDiskUse: true`, which spills to disk (slower but works).

```js
db.orders.aggregate(pipeline, { allowDiskUse: true });
```

In Atlas, this is usually enabled by default.

---

## 6. Transactions

## Q35. When did MongoDB get transactions?

**Answer:**

- 4.0 — multi-document ACID transactions on replica sets.
- 4.2 — distributed transactions on sharded clusters.

The everyday unit of work in MongoDB is a single-document operation; transactions are an escape hatch for cases that genuinely need multi-document atomicity.

## Q36. How do transactions work?

**Answer:**

You start a session, begin a transaction, perform writes, and commit. If anything fails, you abort.

```js
const session = client.startSession();
try {
  session.startTransaction({
    readConcern:  { level: "snapshot" },
    writeConcern: { w: "majority" }
  });

  await accounts.updateOne(
    { _id: "A" }, { $inc: { balance: -100 } }, { session }
  );
  await accounts.updateOne(
    { _id: "B" }, { $inc: { balance:  100 } }, { session }
  );

  await session.commitTransaction();
} catch (err) {
  await session.abortTransaction();
  throw err;
} finally {
  session.endSession();
}
```

## Q37. What are the limitations of transactions?

**Answer:**

- Default 60-second timeout (`transactionLifetimeLimitSeconds`).
- Slower than single-doc writes — extra coordination.
- Holding locks can cause WriteConflict errors.
- Sharded transactions add cross-shard coordination.

If your design needs transactions on every write, the schema is likely wrong — embed instead.

## Q38. What are read concern and write concern?

**Answer:**

Write concern (`w`):

- `1` — primary acknowledged. Fast.
- `"majority"` — majority of replica set acknowledged. Durable through failover.
- `0` — fire-and-forget. Avoid for important writes.

Read concern:

- `"local"` — fastest, may include uncommitted data.
- `"majority"` — only data committed to majority.
- `"snapshot"` — point-in-time snapshot (transactions).
- `"linearizable"` — strongest, slowest.

For important writes in production: `w: "majority"`.

```js
db.orders.insertOne(doc, { writeConcern: { w: "majority", j: true } });
```

---

## 7. Replication and Replica Sets

## Q39. What is a replica set?

**Answer:**

A group of `mongod` instances maintaining the same data. One primary handles all writes; secondaries replicate from the primary via the oplog. The standard production deployment is 3 nodes (PSS) or 5 nodes (PSSSS). Avoid even-numbered sets — they don't help with quorum.

## Q40. What is the oplog?

**Answer:**

The oplog (operation log) is a capped collection (`local.oplog.rs`) on every replica set member. The primary writes operations to it, and secondaries tail it and apply ops in order. If a secondary falls behind beyond the oplog window, it must do a full resync. Monitor the oplog window.

```js
// Inspect oplog
use local;
db.oplog.rs.find().sort({ $natural: -1 }).limit(1);

rs.printReplicationInfo();
```

## Q41. How does failover work?

**Answer:**

1. Members heartbeat every 2 seconds.
2. If the primary is unreachable for `electionTimeoutMillis` (default 10 s), an eligible secondary calls an election.
3. Majority of votes selects a new primary.
4. Drivers detect the topology change and route writes to the new primary; retryable writes resend automatically.

A typical failover takes 10-30 seconds of write unavailability.

## Q42. What are read preferences?

**Answer:**

| Preference | Reads from |
|------------|------------|
| `primary` (default) | Primary only |
| `primaryPreferred` | Primary; fall back to secondary |
| `secondary` | Secondary only |
| `secondaryPreferred` | Secondary; fall back to primary |
| `nearest` | Lowest network latency |

```js
db.orders.find({ ... }).readPref("secondaryPreferred");
```

Reading from secondaries scales reads but data may be stale. Use tags to direct heavy analytic reads to a dedicated secondary.

## Q43. Should you use an arbiter?

**Answer:**

An arbiter votes in elections but holds no data. Avoid arbiters in production for important data. PSA (primary-secondary-arbiter) can lose writes in some failure scenarios because there is only one full data-bearing secondary. Use PSS instead.

## Q44. What are hidden and delayed members?

**Answer:**

- Hidden — not visible to clients; useful for backups or analytics without competing with application traffic.
- Delayed — intentionally lags behind the primary by N seconds. A safety net for "I dropped the wrong collection" recovery.

---

## 8. Sharding

## Q45. What is sharding?

**Answer:**

Sharding partitions data horizontally across multiple shards. Each shard is itself a replica set. A `mongos` router routes queries based on the shard key.

Architecture:

- Config servers (replica set) — hold cluster metadata.
- Shards (replica sets) — hold data.
- mongos — stateless router; clients connect through it.

## Q46. What is a shard key?

**Answer:**

The field or fields MongoDB uses to distribute documents across shards. A good shard key:

- Has high cardinality.
- Distributes writes evenly.
- Is included in most queries (so queries target one shard).
- Is not monotonically increasing (or use hashed sharding).

Bad shard keys: `createdAt` alone (all writes hit one shard), low-cardinality fields like `status`.

```js
sh.shardCollection("shop.orders", { customerId: "hashed" });
```

## Q47. Hashed vs ranged sharding?

**Answer:**

- Ranged (default) — chunks based on key ranges. Range queries on the shard key are efficient. Risk: hotspots if the key is monotonic.
- Hashed — key is hashed before placement. Even distribution but range queries scatter to all shards.

Common pattern: hashed sharding for ingest spread; queries target by app-specific routing.

## Q48. What are compound and zone sharding?

**Answer:**

- Compound shard key — distribute by multiple fields. Common in multi-tenant apps: `{ tenantId: 1, _id: 1 }`.
- Zone sharding — pin specific key ranges to specific shards. Useful for geo-locality (EU data on EU shards).

```js
sh.addShardToZone("shard-eu",   "EU");
sh.updateZoneKeyRange("shop.users",
  { region: "EU" }, { region: "EU￿" }, "EU");
```

## Q49. Can you change a shard key after the fact?

**Answer:**

Before 5.0, this was painful. Since 5.0, `reshardCollection` performs online resharding to a new key. 7.0 adds `moveCollection`. Plan ahead, but you have an escape hatch.

```js
db.adminCommand({ reshardCollection: "shop.orders", key: { tenantId: 1, _id: 1 } });
```

## Q50. How do queries work across shards?

**Answer:**

- Targeted query — includes the shard key; mongos sends to one shard.
- Scatter-gather — does not include the shard key; mongos hits every shard and merges results.

Scatter-gather destroys throughput at scale. Design queries to include the shard key.

---

## 9. Performance Tuning

## Q51. How do you find slow queries?

**Answer:**

Enable the database profiler.

```js
// Capture queries slower than 100 ms
db.setProfilingLevel(1, { slowms: 100 });

// Inspect captured slow ops
db.system.profile.find({ millis: { $gt: 100 } }).sort({ ts: -1 });
```

Atlas users get the Performance Advisor and Query Profiler in the UI.

## Q52. What are the `explain()` modes?

**Answer:**

```js
db.coll.find(...).explain("queryPlanner");      // plan only
db.coll.find(...).explain("executionStats");    // run + collect timing
db.coll.find(...).explain("allPlansExecution"); // all candidates

db.coll.aggregate(pipeline, { explain: true });
```

## Q53. What are common MongoDB performance pitfalls?

**Answer:**

- COLLSCAN on hot queries — missing index.
- Compound index in wrong order (violates ESR).
- Unbounded arrays inside documents.
- Too many indexes — write amplification.
- `$lookup` in tight loops where embedding would be cheaper.
- Deep `skip` pagination — O(n).

## Q54. How do you paginate efficiently?

**Answer:**

`skip` reads and discards every skipped document. Use cursor-based pagination instead.

```js
// Page 1
const page1 = db.posts.find({}).sort({ _id: -1 }).limit(20).toArray();

// Page 2 — pass last _id from page 1
const lastId = page1[page1.length - 1]._id;
const page2 = db.posts.find({ _id: { $lt: lastId } })
                      .sort({ _id: -1 })
                      .limit(20)
                      .toArray();
```

## Q55. How does the working set relate to memory?

**Answer:**

WiredTiger caches data and indexes. The default cache is roughly 50% of (RAM minus 1 GB). The "working set" is the data and indexes touched by hot queries. If the working set fits in cache, queries are fast; if it doesn't, MongoDB reads from disk.

```js
db.serverStatus().wiredTiger.cache;
```

Indicators of memory pressure include high "bytes read into cache" and a high page-fault rate.

## Q56. How does connection pooling work?

**Answer:**

The driver maintains a pool. Defaults are usually fine, but on serverless platforms watch for connection storms — set `maxPoolSize` low and reuse the client across invocations.

```js
const client = new MongoClient(uri, { maxPoolSize: 10, minPoolSize: 1 });
```

---

## 10. Change Streams

## Q57. What is a change stream?

**Answer:**

A real-time event stream of insert, update, delete, and replace events on a collection, database, or whole deployment. Built on the oplog; requires a replica set or sharded cluster.

```js
const stream = db.orders.watch([
  { $match: { "fullDocument.status": "paid" } }
]);
for await (const event of stream) {
  console.log(event.operationType, event.fullDocument);
}
```

## Q58. What are change stream use cases?

**Answer:**

- Real-time UI updates.
- Cache invalidation.
- Driving downstream pipelines (search index, data warehouse).
- Cross-region replication via app code.
- An alternative to the outbox pattern.

Change streams expose a `resumeToken` so you can resume after a crash.

## Q59. Change streams vs polling?

**Answer:**

Polling queries the database every N seconds. It wastes resources and adds latency. Change streams push only when something actually changes. Always prefer change streams for real-time work.

---

## 11. MongoDB Atlas

## Q60. What is Atlas?

**Answer:**

MongoDB's managed cloud service on AWS, GCP, and Azure. It handles provisioning, backups, monitoring, scaling, security, and updates. Atlas-only features include Atlas Search, Atlas Vector Search, Data Federation, Triggers/Functions, and Online Archive.

## Q61. What are Atlas backup options?

**Answer:**

- Continuous Cloud Backup — point-in-time recovery at second granularity.
- Snapshot backup — periodic snapshots.
- On-demand snapshots for ad-hoc points.

Tested restores are the only backups that count.

## Q62. How do you secure MongoDB in production?

**Answer:**

- TLS on the wire (default in Atlas).
- SCRAM authentication or X.509 / LDAP / Kerberos.
- Per-database roles.
- IP allowlist or private endpoint (PrivateLink, VPC peering).
- Encryption at rest.
- Client-side field-level encryption for sensitive fields.
- Queryable encryption (6.0+) for encrypted-but-searchable fields.
- Audit logs.
- Never expose to the public internet with default users.

---

## 12. MongoDB vs SQL

## Q63. Is MongoDB ACID?

**Answer:**

Single-document operations are always ACID. Multi-document transactions are ACID since 4.0 (4.2 for sharded clusters). The difference from a SQL database is everyday usage: in SQL, multi-row transactions are routine; in MongoDB, single-document atomicity is the design unit and multi-document transactions are the occasional escape hatch.

## Q64. Do you need joins in MongoDB?

**Answer:**

Often you replace joins with embedding or extended references. Where SQL joins five tables, MongoDB might serve a single document. When you do need a join, `$lookup` works for moderate scale but becomes a bottleneck on hot paths at high scale.

## Q65. When does PostgreSQL beat MongoDB?

**Answer:**

- Strong relational invariants (foreign keys, complex constraints).
- Heavy analytics and reporting.
- Multi-row transactions are routine.
- Mature SQL tooling needed (BI tools, ORMs).
- A mostly-relational schema with some flexible JSONB fields — Postgres JSONB is excellent.

## Q66. Compare MongoDB and PostgreSQL.

**Answer:**

| Concern | MongoDB | PostgreSQL |
|---------|---------|------------|
| Schema | Flexible, per-document | Strict, migrations |
| Joins | `$lookup`, mostly avoided | Native, optimal |
| Horizontal scale | Native sharding | Logical replication, Citus, app-level partition |
| Replication | Replica sets, automatic failover | Streaming, more setup |
| Transactions | Single-doc default; multi-doc available | First-class everywhere |
| Aggregations | Aggregation pipeline | SQL + window functions |
| Full-text | Atlas Search | `tsvector` and extensions |
| JSON support | Native (BSON) | JSONB (excellent) |
| Best fit | Document-shaped, flexible, sharded | Relational, mixed workloads |
