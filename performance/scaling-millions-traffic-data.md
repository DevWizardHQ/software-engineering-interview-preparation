# Scaling to Millions — Traffic and Data

**Purpose:** Master scaling for senior interviews — millions of users, millions of requests, billions of rows. Covers capacity planning, horizontal/vertical scaling, sharding, caching tiers, async architecture, geographic distribution, real-time at scale, cost optimization, and case studies for 1M, 10M, and 100M user systems.

---

## Table of Contents

1. [Capacity Planning](#capacity-planning)
2. [Vertical vs Horizontal Scaling](#vertical-vs-horizontal-scaling)
3. [Stateless Services](#stateless-services)
4. [Database Scaling](#database-scaling)
5. [Sharding Strategies](#sharding-strategies)
6. [Caching Tiers](#caching-tiers)
7. [Cache Patterns and Pitfalls](#cache-patterns-and-pitfalls)
8. [Async Processing](#async-processing)
9. [Rate Limiting at Scale](#rate-limiting-at-scale)
10. [CDN Strategies](#cdn-strategies)
11. [Geographic Distribution](#geographic-distribution)
12. [Search at Scale](#search-at-scale)
13. [Media at Scale](#media-at-scale)
14. [Logging and Metrics at Scale](#logging-and-metrics-at-scale)
15. [Real-Time at Scale](#real-time-at-scale)
16. [Cost Optimization](#cost-optimization)
17. [Common Bottleneck Patterns](#common-bottleneck-patterns)
18. [Case Studies](#case-studies)

---

## Capacity Planning

### Q1. How do you estimate traffic?

Always start with a back-of-envelope calculation.

**Inputs:**
- Daily Active Users (DAU)
- Average requests per user per day
- Peak vs average traffic ratio (typically 3–5x, more for consumer apps)
- Read:write ratio
- Average payload sizes

**Example (10M DAU social app):**
- 10M DAU × 30 sessions/day × 5 reqs/session = 1.5B reqs/day
- 1.5B / 86400 ≈ 17,400 req/s average
- Peak (4x) ≈ 70,000 req/s
- 90% reads, 10% writes → 63,000 read req/s, 7,000 write req/s

This ballpark guides every other decision (DB size, cache size, instance count).

---

### Q2. Bandwidth estimation.

Calculate egress bytes/sec — often the most expensive resource.

```
egress = avg_response_size × peak_requests_per_sec
```

10 KB avg response × 70k req/s = 700 MB/s = 5.6 Gbps

A single AWS NAT gateway / typical instance can push ~5–25 Gbps. CDN offloads most of this — without one, you'd need many origin instances just for bandwidth.

---

### Q3. Storage growth.

```
new_data_per_day = active_users × avg_data_created_per_user
yearly_storage = data_per_day × 365 × replication_factor × overhead
```

Plan for 3–5 years, with 30%+ overhead for indexes/WAL/backups.

Common surprises:
- Logs and audit trails — easily 10x the "real" data
- Image/video — if you don't use object storage, your DB explodes
- Soft-deleted rows — bloat over time

---

### Q4. Latency budgets.

A 200 ms total p95 budget for a user request:
- 50 ms DNS + TLS + network (geography-dependent)
- 20 ms load balancer + reverse proxy
- 10 ms framework + middleware
- 80 ms DB / cache lookups
- 20 ms serialization + response
- 20 ms slack

If your DB alone uses 150 ms, the system is unbalanced.

---

### Q5. Read:write ratio drives architecture.

| Ratio | Architecture |
|-------|--------------|
| 1:1 (transactional) | Single primary, modest scaling |
| 10:1 | Read replicas, caching layer |
| 100:1 (most consumer apps) | Aggressive caching, CDN, replica fan-out |
| 1000:1 (read-only feed) | Edge caching, materialized views |
| 1:10 (analytics ingest) | Append-only logs, batched writes |

Optimize for the common case.

---

## Vertical vs Horizontal Scaling

### Q6. When to scale up vs out?

**Scale up first** when:
- One box still has headroom (CPU < 70%, RAM < 80%)
- Workload doesn't parallelize well (single-master DB)
- Scale-out adds complexity not worth it
- Your team can't operationally support more nodes

**Scale out** when:
- Vertical limits hit (256 GB RAM is plenty, 4 TB is exotic and slow)
- Need fault tolerance (single node = single point of failure)
- Need geographic distribution
- Workload is naturally parallel

A single modern box (96 cores, 768 GB RAM, NVMe) handles enormous load. Don't dismiss vertical too quickly.

---

### Q7. The cost curve.

Vertical scaling: cost grows super-linearly (16-core costs 2× 8-core; 128-core costs 32× 8-core).

Horizontal scaling: cost grows linearly + coordination overhead.

Crossover point depends, but at AWS sticker prices, going beyond ~32 vCPU is often less cost-effective than splitting.

---

## Stateless Services

### Q8. What does "stateless" mean?

Each request is independent. The server holds no per-user data between requests. Any instance can handle any request. Sessions go to Redis/DB, not local memory.

Stateless services scale linearly: add nodes, add capacity.

---

### Q9. What state still has to live somewhere?

| Type | Where |
|------|-------|
| User sessions | Redis (TTL'd), JWT (client-held) |
| Auth tokens | DB or Redis (revocable) |
| Shopping cart | Redis or DB |
| Rate limit counters | Redis with atomic operations |
| Locks for critical sections | Redis with `SET NX EX` or DB advisory locks |
| Real-time presence | Redis pub/sub or distributed system |
| Application configuration | Config service or env vars |

Anything that needs to persist or be shared goes to a managed external store.

---

### Q10. JWT vs server sessions.

| | JWT | Session in Redis |
|--|-----|------------------|
| Server state | None | Required |
| Revocation | Hard (need denylist) | Easy (delete key) |
| Size | Larger header | Just session ID |
| Verify cost | Crypto verify | Redis lookup |
| Across services | Easy | Need shared Redis |

For internal microservices, JWT is fine. For consumer auth where revocation matters (logout, security incident), Redis-backed sessions are simpler.

---

### Q11. Sticky sessions — when?

Avoid if possible. Required only for:
- WebSocket connections (route to the right instance)
- Long-running streaming endpoints
- In-process state during a multi-step flow (rare, redesign instead)

Implement via load balancer cookie or hash. Limits scale-out flexibility — you can't drain a node without disrupting users.

---

## Database Scaling

### Q12. Read replicas — pattern overview.

Primary handles writes, replicas serve reads.

```
[App] -- writes --> [Primary] --replication--> [Replica 1, Replica 2, ...]
[App] -- reads --> [Replicas (load-balanced)]
```

Adds read capacity linearly. Doesn't help write capacity.

---

### Q13. Read-after-write consistency.

User submits, then immediately fetches — sees stale data because read went to a replica that hasn't caught up.

Fixes:
- **Read-your-writes consistency:** route the same user's reads to primary for N seconds after a write
- **Wait for sync:** primary returns LSN; replica lookup waits until that LSN is applied
- **Synchronous replication:** strict but slows writes
- **Optimistic UI:** show the just-written data from client memory

Most apps pick the first.

---

### Q14. Replication topologies.

| Topology | Description | Use |
|----------|-------------|-----|
| Single primary, N replicas | Standard | Most apps |
| Cascading replicas | Replicas of replicas | Reduce primary load |
| Multi-region | Replica per region | Geographic reads |
| Multi-master | All accept writes | Special cases (CRDT/last-write-wins) |
| Logical replication | Per-table, cross-version | Migrations, heterogeneous |

Multi-master is rarely worth the conflict-resolution headache for OLTP. Most "active-active" deployments use sharding by region (each region writes its own data).

---

### Q15. Partitioning vs sharding.

| | Partitioning | Sharding |
|--|--------------|----------|
| Where | Within one DB instance | Across multiple instances |
| App view | Single logical table | Application or proxy routes |
| Use | Manage huge tables | Scale beyond one box |
| Cross-key queries | Native | Hard |
| Operational complexity | Modest | Significant |

Partition before you shard. Often partitioning + replication is enough for many workloads.

---

### Q16. Connection pool exhaustion at scale.

100 instances × 50 connections each = 5000 connections to your DB. Most DBs choke at thousands of connections (each one consumes RAM).

Solutions:
- **Connection pooler in front:** PgBouncer (Postgres), ProxySQL (MySQL), RDS Proxy
- **Smaller per-instance pools** — most instances don't need 50
- **Aurora Serverless v2 / Cloud SQL Enterprise Plus** — managed pooling at the DB layer
- **Use prepared statements that survive the pooler** (PgBouncer transaction mode pre-PG14 was an issue)

---

## Sharding Strategies

### Q17. Hash-based sharding.

```
shard = hash(user_id) % N
```

Pros: even distribution, simple.
Cons: rebalancing requires moving most data when N changes (use consistent hashing instead).

---

### Q18. Range-based sharding.

```
shard 1: user_id 0-1M
shard 2: user_id 1M-2M
...
```

Pros: range queries efficient, easy to add new shards (last range).
Cons: hot spot on the newest range (most active users); old shards under-utilized.

Often used for time-series: shard by month.

---

### Q19. Directory-based sharding.

A lookup service maps key → shard. Each user has explicit `shard_id`.

```
SELECT shard_id FROM user_directory WHERE user_id = ?
```

Pros: full flexibility, easy rebalancing.
Cons: extra hop, the directory itself becomes a bottleneck (must be heavily cached).

---

### Q20. Consistent hashing.

Maps keys and shards onto a ring. Adding/removing a shard moves only `1/N` of keys.

```
hash_ring: positions on [0, 2^32)
shard = first node clockwise from hash(key)
```

Used by: Cassandra, DynamoDB, Memcached, Redis Cluster.

With **virtual nodes** (each physical shard occupies many ring positions), distribution is even and rebalancing is smooth.

---

### Q21. Choosing a shard key — checklist.

- **High cardinality** — millions of distinct values
- **Even distribution** — no value 100x more than others
- **Aligned with queries** — most queries hit one shard
- **Stable** — doesn't change for a row
- **Application-meaningful** — derivable without lookup

Bad choices:
- Boolean (only 2 values)
- Status (concentrated values)
- Sequential ID with range sharding (hot spot)
- Country (US dominates)
- Tenant ID without sub-sharding (one giant tenant)

---

### Q22. Cross-shard queries.

The hard part. Strategies:

1. **Avoid them in design:** schema such that 99% of queries hit one shard. Denormalize across shards.
2. **Scatter-gather:** query all shards, combine results. Latency = slowest shard.
3. **Global secondary index:** maintained outside shards (e.g., search engine).
4. **Async aggregation:** ETL all shards into a warehouse for analytics.
5. **Application-level joins:** rarely OK, often slow.

The further you can push the shard key into your data model, the better.

---

### Q23. Resharding without downtime.

The dreaded operation. Approaches:

1. **Double-write:** writes go to both old and new shards
2. **Backfill:** copy historical data to new shards in chunks
3. **Verify:** consistency check between old and new
4. **Switch reads:** gradually move read traffic to new shards
5. **Stop double-writes:** decommission old

Tools: Vitess (MySQL), Citus (Postgres), application-managed (Slack, Notion, etc).

Plan for weeks, not days. Have rollback at every step.

---

## Caching Tiers

### Q24. The cache hierarchy.

```
[Browser cache] → [CDN edge] → [Reverse proxy / Varnish] → [App in-memory] → [Distributed cache (Redis)] → [DB]
```

Each layer absorbs requests. A request that hits browser cache costs nothing; a request that hits DB costs the most.

Goal: maximize hits at the highest layer where correctness allows.

---

### Q25. Browser cache.

```
Cache-Control: public, max-age=31536000, immutable
```

Asset filenames must include hashes (`app.4f7a2b.js`) for cache busting.

For HTML / API responses: shorter max-age + `stale-while-revalidate`. Combine with ETag for revalidation.

---

### Q26. CDN edge cache.

The biggest leverage. A 200 ms origin trip reduced to 20 ms edge serve. CDN absorbs 90%+ of traffic for static, sometimes 50%+ for dynamic.

Setup:
- CDN respects `Cache-Control: s-maxage=...` for shared cache
- Use surrogate keys (Fastly) or cache tags (Cloudflare) for purging
- Serve cookies-free for static assets (cookies bypass cache)
- `Vary` header carefully — `Vary: Accept-Encoding` is fine; `Vary: Cookie` destroys cache hit rate

---

### Q27. Edge compute.

Cloudflare Workers, Vercel Edge, AWS Lambda@Edge — run code at PoPs near users.

Use cases:
- Personalize at the edge (A/B test, geo redirect)
- Auth check (JWT validation) before origin hit
- Stitch responses from multiple origins
- Rewrite URLs for tenant routing

Constraints: limited runtime (V8 isolate), short execution time, no full Node API.

---

### Q28. Reverse proxy cache.

Nginx, Varnish, HAProxy can cache between LB and app.

```nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=app:100m max_size=10g inactive=60m;

location / {
  proxy_cache app;
  proxy_cache_lock on;
  proxy_cache_valid 200 60s;
  proxy_cache_use_stale error timeout updating http_500;
  proxy_pass http://upstream;
}
```

Useful when CDN can't (private network, internal API), or as a stampede protection layer.

---

### Q29. Distributed cache (Redis).

Shared cache across all app instances. Sub-millisecond reads.

Patterns:
- Single Redis: simple, up to ~100k ops/s on a big box
- Redis Sentinel: HA with automatic failover
- Redis Cluster: sharded, scales to millions of ops/s
- Managed (ElastiCache, MemoryDB, Upstash): operational ease

Watch out:
- Network latency (cross-AZ adds 1–2 ms)
- Hot keys (one key getting 100k req/s saturates one shard)
- Connection storms during failover

---

### Q30. Application in-process cache.

Per-instance LRU. Sub-microsecond.

Best for:
- Reference data rarely changing (countries, currencies, feature flags)
- Hot keys with high hit rate
- Reducing Redis round trips for super-hot data

Risk: divergence between instances. Use short TTL or pub/sub for invalidation.

---

## Cache Patterns and Pitfalls

### Q31. Cache-aside (lazy loading).

```python
def get(key):
    val = cache.get(key)
    if val is None:
        val = db.fetch(key)
        cache.set(key, val, ttl=300)
    return val

def update(key, val):
    db.update(key, val)
    cache.delete(key)
```

Pros: simple, only cache what's read.
Cons: cache miss latency hits DB; race during update.

---

### Q32. Read-through.

Cache library fetches from DB on miss. App only knows about cache.

```python
val = cache.get_or_load(key, loader=lambda: db.fetch(key))
```

Pros: cleaner app code.
Cons: cache library coupling.

---

### Q33. Write-through.

Every write goes to cache AND DB synchronously.

```python
def update(key, val):
    db.update(key, val)
    cache.set(key, val, ttl=300)
```

Pros: cache always in sync after write.
Cons: writes are slower (two round trips); if cache write fails, divergence.

---

### Q34. Write-back (write-behind).

Writes go to cache only; async flush to DB.

Pros: huge write throughput.
Cons: data loss if cache crashes before flush. Use only for non-critical metrics, counters, telemetry.

---

### Q35. Cache invalidation strategies.

- **TTL only** — eventual consistency, simplest
- **Explicit on write** — delete key in same transaction (after commit)
- **Pub/sub** — write source publishes invalidations
- **Tag-based** — group keys, purge tag (Cloudflare cache tags, Fastly surrogate keys)
- **Versioned keys** — `user:123:v17`; bumping version makes old cache irrelevant

Critical bug: **invalidate before commit**. Reader caches the pre-commit state. Always invalidate after commit, or use commit hooks / outbox.

---

### Q36. Cache warming.

For predictable spikes (sale launch, sports event), pre-populate the cache.

```python
def warm_cache():
    for key in expected_hot_keys():
        cache.set(key, db.fetch(key), ttl=600)
```

Run as a cron job before traffic hits. Saves you from 1000 cold misses at moment zero.

---

### Q37. Thundering herd / stampede protection.

When a hot key expires, 1000 concurrent requests miss → DB. The DB collapses.

Solutions:
1. **Lock + single-flight:**
   ```
   if cache.lock(key):
       val = db.fetch(); cache.set(key, val); cache.unlock(key)
   else:
       wait briefly, retry cache
   ```
2. **Probabilistic early refresh (XFetch):** refresh slightly before expiry with probability proportional to closeness
3. **Two-tier TTL:** soft (refresh async) + hard (refresh sync)
4. **Stale-while-revalidate:** return stale, refresh in background
5. **Background refresh:** never expire user-facing cache; refresh on schedule

---

### Q38. Negative caching.

Cache the "not found" result too. Otherwise repeat scans for missing keys hammer the DB.

```python
val = cache.get(key)
if val == NULL_SENTINEL: return None
if val: return val
val = db.fetch(key) or NULL_SENTINEL
cache.set(key, val, ttl=60)  # shorter TTL for nulls
return val if val != NULL_SENTINEL else None
```

Especially important under attack (bot probing for non-existent IDs).

---

## Async Processing

### Q39. When to go async.

Anything that:
- Doesn't need to complete before user gets a response
- Takes > 200 ms
- Could fail and retry
- Fans out to many recipients
- Is CPU-heavy

Examples: send email, generate PDF, transcode video, sync to third-party, recompute aggregates, send notification.

Sync API → enqueue job → return 202 Accepted with status URL → background processes job → user polls or gets webhook.

---

### Q40. Queue technologies.

| Tool | Throughput | Latency | Features |
|------|-----------|---------|----------|
| Redis (BullMQ/Sidekiq/Resque) | 10k+/s | ms | Easy, retries, scheduling |
| RabbitMQ | 50k+/s | ms | Routing, exchanges, ACKs |
| SQS | Unlimited (managed) | ~10s p99 | At-least-once, FIFO option |
| Kafka | Millions/s | ms | Event log, replay, retention |
| Pulsar | Millions/s | ms | Like Kafka + multi-tenancy |
| NATS / JetStream | Millions/s | sub-ms | Lightweight, simple |

Pick based on: volume, latency, ordering, replay, ops experience.

---

### Q41. Fan-out patterns.

Push notification to 1M users:

**Naive:** loop, send each — slow, blocks if any fail.

**Fan-out queue:**
```
master job → enqueues 1000 sub-jobs (1k users each)
sub-jobs → enqueue per-user notification
worker pool → processes per-user
```

Each layer multiplies capacity. Failures isolated to small batches.

---

### Q42. Fan-in / aggregation.

Many sources → one consumer.

Patterns:
- **Stream processing:** Kafka topic + consumer group with windowing (Flink, Kafka Streams)
- **Materialized views in DB:** triggers / events + rollup tables
- **Batch ETL:** hourly or daily aggregation

For real-time: stream processor. For analytics: warehouse with batch ETL.

---

### Q43. Outbox pattern.

Atomic write of "send email" with the DB transaction:

```sql
BEGIN;
INSERT INTO orders (...);
INSERT INTO outbox (event_type, payload) VALUES ('order_created', ...);
COMMIT;
```

A separate process polls the outbox, publishes to a queue, and marks rows as sent.

Avoids the "wrote to DB but failed to publish" inconsistency. Standard pattern in event-driven architectures.

---

### Q44. Idempotency keys.

Async retries are inevitable. Make jobs idempotent:

```python
def process(job):
    if processed_set.contains(job.id): return
    do_work(job)
    processed_set.add(job.id, ttl=7d)
```

For outgoing API calls, send `Idempotency-Key: <uuid>` header so server dedupes (Stripe, Square).

---

## Rate Limiting at Scale

### Q45. Token bucket.

Each client has a bucket of N tokens, refilled at rate R per second. Each request consumes 1 token. Empty bucket → 429.

Smooth burst handling: allows short spikes within capacity.

```
local key = KEYS[1]
local now = tonumber(ARGV[1])
local rate = tonumber(ARGV[2])
local capacity = tonumber(ARGV[3])
-- Atomic Lua script in Redis
```

Standard implementations: nginx `limit_req`, AWS API Gateway, Cloudflare, application libraries.

---

### Q46. Sliding window.

Counts requests in a rolling N-second window.

Two implementations:
- **Sliding log:** Redis sorted set of timestamps, count entries in window. Accurate, costly.
- **Sliding counter:** combine current window count with previous window weighted. Approximate, cheap.

Used when fairness within a window matters more than smoothness.

---

### Q47. Distributing rate limits across instances.

Local-only counters fail when traffic distributes across N nodes. User can hit `limit × N`.

Solutions:
- **Shared Redis counter** with atomic INCR + EXPIRE — most common
- **Token bucket in Redis** with Lua script for atomicity
- **Probabilistic local + reconciliation** — each node enforces `limit / N` locally; less accurate but no Redis hit

---

### Q48. What to limit.

- Per-user (most common)
- Per-IP (anonymous, anti-DDoS)
- Per-API-key (B2B)
- Per-endpoint (expensive endpoints have lower limits)
- Per-tier (free/pro/enterprise)
- Globally (protect downstream)

Combine: "100 req/min per user OR 1000 req/min per IP OR 10000 req/min total."

---

### Q49. 429 response best practices.

```
HTTP/1.1 429 Too Many Requests
Retry-After: 60
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1700000000
```

Clients should respect `Retry-After` with backoff and jitter. Document your limits clearly.

---

## CDN Strategies

### Q50. What can a CDN cache?

Static (easy): JS, CSS, images, fonts, video. Long cache, immutable.

Dynamic (depends):
- HTML pages with low personalization (homepage, product page) — short TTL, `stale-while-revalidate`
- API responses for read-heavy data — public + ETag + max-age
- Personalized pages — edge compute or vary intelligently

Don't cache:
- Auth-required user-specific data unless partitioned by user (`Cache-Control: private`)
- POST/PUT responses (most CDNs don't anyway)
- Anything with PII over a shared cache

---

### Q51. Cache key design.

CDN typically keys on URL + Vary headers. Tune:
- Strip irrelevant query params (`utm_*`, session IDs) so all variants share cache
- Vary on `Accept-Encoding` (compression) and `Accept` (image format)
- Don't Vary on `Cookie` for public content

A small change to keying can take hit rate from 60% to 95%.

---

### Q52. Purging.

- **Full purge:** clears everything; nuclear option
- **URL purge:** specific URLs
- **Tag/surrogate-key purge:** content marked with tags is invalidated together (Fastly, Cloudflare Enterprise)
- **Soft purge:** marks stale, serves while revalidating

For e-commerce: tag pages with product IDs. On product update, purge that tag — all dependent pages invalidate.

---

### Q53. Multi-CDN.

Use 2 CDNs (Cloudflare + Fastly, etc) for:
- Resilience (one outage doesn't take you out)
- Best price/performance per region
- Smart routing via DNS or RUM-based balancer

Costs more, more ops complexity. Useful at high scale or for SLA reasons.

---

## Geographic Distribution

### Q54. Latency from a single region.

| Origin | User in same region | Cross-continent |
|--------|---------------------|-----------------|
| US-East | 20-50 ms | 150-300 ms |
| EU | 20-50 ms | 150-300 ms |
| APAC | 20-50 ms | 200-400 ms |

A Sydney user hitting US-East has ~200 ms RTT; a 5-trip API call is a full second wasted on the network alone.

CDN handles static; for dynamic, you need multi-region.

---

### Q55. Multi-region read replicas.

Primary in one region; replicas in others for local reads.

```
[US Primary] ── replicates ──> [EU Replica, APAC Replica]
[EU users] ──reads──> [EU Replica]
[EU users] ──writes──> [US Primary] (cross-region penalty)
```

Acceptable when writes are infrequent and reads dominate.

---

### Q56. Active-active multi-region.

Each region accepts writes, syncs to others.

Approaches:
- **Geo-partitioning:** users belong to a region, write only there. Dynamo, Spanner, CockroachDB.
- **CRDT (Conflict-free Replicated Data Types):** for things like counters, sets.
- **Last-write-wins:** simple but lossy.

Hardest part: cross-region foreign keys. Often denormalize regional data.

---

### Q57. DNS-based routing.

| Method | Behavior |
|--------|----------|
| GeoDNS | Route by user's location |
| Latency-based | Route to lowest-latency region |
| Weighted | Split traffic for canary deploys |
| Failover | Auto-switch on health check failure |

AWS Route 53, Cloudflare DNS, NS1, Akamai DNS provide these.

---

### Q58. Edge functions for personalization.

Run code at every PoP:
- Greet user by detected country
- Show A/B variant
- Check auth before forwarding to origin
- Rewrite static HTML with personalized chunks

Cloudflare Workers, Vercel Edge Functions, Lambda@Edge, Fastly Compute@Edge.

---

## Search at Scale

### Q59. When to use a search engine vs the DB.

Use Elasticsearch / OpenSearch / Algolia when:
- Full-text search with relevance ranking
- Faceted search (filter by attributes)
- Typo tolerance, synonyms
- Aggregations across millions of docs
- Geospatial + text combined
- Autocomplete

For simple `LIKE 'foo%'` on a single column with limited data, the DB is fine.

---

### Q60. Elasticsearch sizing.

Rules of thumb:
- Heap: 50% of RAM, max 32 GB (compressed pointers)
- Shards: aim for 30–50 GB per shard for primary indexes
- Total shards per node: ≤ 600 (less is better)
- Replicas: 1+ for HA
- Don't over-shard small indexes — 1 shard is fine for < 50 GB

Indexing throughput ~5–10k docs/s per node typical; tune `refresh_interval`, `bulk` API for higher.

---

### Q61. Ingesting from DB to search.

Patterns:
1. **Sync on write:** app writes both DB and ES. Risk of divergence.
2. **Outbox + worker:** atomic outbox row, worker indexes async. Reliable.
3. **CDC (Change Data Capture):** Debezium reads DB WAL, streams to ES. No app changes.
4. **Periodic reindex:** batch job, simple but stale.

For consistency-critical search, prefer CDC or outbox.

---

### Q62. Search performance at scale.

Avoid:
- Deep pagination (`from: 100000` is expensive) — use `search_after`
- Wildcards on large fields (`*foo*`) — use ngram tokenization or dedicated autocomplete index
- Sorting on high-cardinality unindexed fields
- Returning all source docs when you only need IDs

Cache hot queries. Pre-aggregate facet counts when possible.

---

## Media at Scale

### Q63. Image pipeline.

```
[User upload] → [Object storage (S3)] → [Image processor (Lambda/CloudFront)] → [CDN] → [User]
```

- Original stored once in S3
- Variants generated on-demand at the CDN/edge (Cloudflare Images, imgix, Vercel) or pre-generated
- WebP/AVIF served via Accept header negotiation
- Long cache + hashed filenames

Storage class: original in Standard or IA; archived in Glacier.

---

### Q64. Video pipeline.

```
[Upload] → [Transcoder (FFmpeg/MediaConvert)] → [HLS/DASH segments] → [Object storage] → [CDN] → [Player]
```

- Adaptive bitrate (multiple resolutions)
- Segment size ~6–10 seconds
- Live: low-latency HLS / WebRTC
- DRM if needed (Widevine, FairPlay)

For UGC at scale: SQS-based job queue, Auto Scaling transcode workers, GPU instances for AV1.

---

### Q65. Object storage best practices.

- **S3 / GCS / Azure Blob** — virtually unlimited, pay per GB and operations
- **Lifecycle rules** — move old data to IA / Glacier / cold storage automatically
- **Versioning** — protect against deletes; cost trade-off
- **Pre-signed URLs** — give temporary access without exposing credentials
- **Multipart upload** — for files > 100 MB
- **Content-Disposition / Content-Type** set correctly for browser handling

---

## Logging and Metrics at Scale

### Q66. Sampling strategies.

100k req/s × 10 KB log per request = 1 GB/s, 86 TB/day. Unaffordable.

Strategies:
- **Trace sampling:** record full traces for 1% of requests (head sampling) or 100% of slow/erroring (tail sampling)
- **Log levels:** info+ in prod, debug only on demand
- **Aggregation:** counters and histograms at app level; ship aggregates not every event
- **Sample low-value events:** "user viewed page" — sample 1%
- **Always log errors and high-value events** in full

---

### Q67. Metrics cardinality.

Cardinality = unique label combinations. Each combo is a separate time series.

Prometheus chokes at 1M+ series. Avoid:
- `user_id` as a label (10M users → 10M series)
- Free-form strings (`error_message="..."`)
- Timestamps in labels

Good labels: HTTP method, status code, route name, region. Limit to 10–100 unique values per label.

---

### Q68. Log aggregation.

- **ELK / OpenSearch:** flexible, powerful, expensive at scale
- **Loki** (Grafana): cheaper, less full-text power
- **CloudWatch Logs / Stackdriver:** managed, expensive
- **DataDog / New Relic / Honeycomb:** observability platforms with structured logs + metrics + traces

For very high volume: ship aggregates to TSDB, sample traces to APM, stream raw logs to S3 + query with Athena/BigQuery.

---

### Q69. Retention.

| Data | Retention |
|------|-----------|
| Metrics (raw) | 7-30 days |
| Metrics (downsampled) | 1+ year |
| Logs (debug/info) | 7-14 days |
| Logs (audit/security) | Years (compliance) |
| Traces | 7-14 days, 100% retention impractical |

Cheap cold storage (S3 Glacier, Archive tier) for compliance retention.

---

## Real-Time at Scale

### Q70. WebSocket clusters.

Each WS connection holds an open TCP. 1M users = 1M sockets.

- Per node: 50k–500k connections (kernel tuning required: `ulimit`, `net.ipv4.tcp_*`)
- Sticky routing (LB → same node) since connection is stateful
- Heartbeats to detect dead connections (every 30 s)
- Backpressure: slow consumers can't be allowed to block

For high scale, dedicated services: ably, Pusher, AWS API Gateway WebSocket, Centrifugo, Phoenix Channels.

---

### Q71. Pub/sub for fan-out.

Server publishes once; all subscribers receive.

Backbones:
- **Redis pub/sub:** simple but no persistence; subscriber misses messages while disconnected
- **Redis Streams:** persistent, consumer groups, replay
- **Kafka:** the gold standard for high-volume
- **NATS:** lightweight, fast
- **MQTT:** IoT, mobile

Push notification fan-out (mobile): push to APNs / FCM in batches; they handle the device fan-out.

---

### Q72. Presence at scale.

"Who's online right now?" — naive per-user state explodes.

Approaches:
- **Heartbeat to Redis:** `SET user:123:online "1" EX 60`. Online = key exists. Cheap, eventual consistency.
- **Pub/sub on connect/disconnect:** events to backend.
- **Approximate (HyperLogLog):** for "active users last 5 min" without exact list.

For social apps with hundreds of millions of users, "online status" is usually approximate by design.

---

## Cost Optimization

### Q73. Rightsizing.

Most cloud bills are wasted because instances are oversized.

Process:
1. Capture utilization (CPU, memory, network) for 2 weeks
2. p95 utilization → that's your "real" need (with 30% headroom)
3. Pick the smallest instance type that fits
4. Re-evaluate quarterly

Tools: AWS Compute Optimizer, GCP Recommendations, Datadog cloud cost management.

---

### Q74. Spot / preemptible instances.

70-90% cheaper than on-demand. Risk: can be terminated with short notice (2 min on AWS).

Use for:
- Stateless workers
- Batch jobs (resume on new instance)
- Build/CI runners
- Auto-scaling groups with mixed spot+on-demand

Don't use for:
- DB primaries
- Anything stateful that's expensive to restart

---

### Q75. Reserved capacity / Savings Plans.

For steady baseline (always-on services), commit 1–3 years for 30–60% savings.

Strategy: cover ~80% of baseline with reserved; spike with on-demand or spot.

---

### Q76. S3 lifecycle and tiering.

```
Standard (hot, $0.023/GB/mo)
   ↓ after 30 days, infrequent access ($0.0125)
Glacier Instant ($0.004)
   ↓ after 90 days
Glacier Flexible ($0.0036)
   ↓ after 180 days
Glacier Deep Archive ($0.00099)
```

Setting lifecycle rules can drop archive bills 95%. Verify retrieval cost before moving data you'll need urgently.

---

### Q77. Egress is the killer.

- AWS to internet: $0.05–$0.09/GB
- Inter-region: $0.02/GB
- Cross-AZ: $0.01/GB (yes, even within a region)

100 TB/month egress = $5000-$9000.

Mitigations:
- CDN (passes through CDN egress, often cheaper)
- Same-AZ traffic when possible
- Negotiate enterprise pricing
- Cloudflare's "no egress fee" is a marketing point but real

---

### Q78. Database costs.

RDS / managed DBs: 30–50% premium over EC2 + self-manage.

Trade-offs:
- Managed: backups, failover, patching, monitoring out of the box
- Self-managed: more knobs, costs less, requires expertise

For hot tables, in-memory (Redis, Aurora I/O Optimized) makes sense per-query but cost analysis needed at scale.

---

## Common Bottleneck Patterns

### Q79. The hot key.

One key gets 100x the traffic of others. Saturates one shard / one Redis node.

Symptoms: one shard at 100% CPU, others idle. p99 spikes.

Fixes:
- Shard the key further (`hot_key:0`, `hot_key:1`, ..., randomize on read/write)
- Read-only replicas of the hot key
- Local cache in front

---

### Q80. The hot row.

Counter being incremented from many writers.

Same symptoms as hot key but in the DB.

Fixes:
- Sharded counter: many rows aggregate to one logical count
- Approximate counter in Redis, periodic flush
- Eventual aggregation (write events, sum later)

---

### Q81. The slow consumer.

Producer at 10k/s, consumer at 1k/s — backlog grows forever.

Fixes:
- Scale consumers (horizontal)
- Optimize consumer logic
- Drop low-value messages (bounded queue, rejection)
- Backpressure on producer

Beware: queue memory full → producer crashes / OOMs upstream system.

---

### Q82. The unfair scheduler.

Free-tier user can hit your API a million times; paying customer is rate-limited because shared queue is full.

Fixes:
- Per-tier queues
- Quotas per user
- QoS tagging

---

### Q83. The thundering herd at startup.

Cluster restarts; 100 nodes all hit DB / cache at once.

Fixes:
- Startup jitter (random sleep 0–30 s before first query)
- Gradual rollout (don't restart all at once)
- Cache warming script

---

### Q84. The cascading failure.

One dependency slow → callers retry → load triples → dependency slower → ...

Fixes:
- Circuit breakers
- Retry budgets (cap retries at % of original requests)
- Bulkheads (separate thread pools per dependency)
- Load shedding (drop low-priority traffic when downstream stresses)

---

### Q85. The runaway query.

Reporting query joins five huge tables; takes 20 minutes; locks tables; everything else slows.

Fixes:
- Statement timeout (`SET statement_timeout = '30s'`)
- Separate replica for analytics
- Move OLAP off the OLTP path entirely

---

## Case Studies

### Q86. Designing for 1M MAU.

Typical: 100k DAU, 5k peak concurrent, 1k req/s peak.

**Stack:**
- 2-4 app instances behind LB
- One DB primary + 1 replica for HA (vertical scale → r6.2xlarge or similar)
- Redis for cache + sessions + queue
- CDN for static assets
- Single region usually fine

**Cost:** $2k-$10k/month for AWS.

**Where it can break:**
- One slow query
- Forgetting to cache
- Unbounded user-generated content

A single competent team can run this comfortably.

---

### Q87. Designing for 10M MAU.

Typical: 1M DAU, 50k peak concurrent, 10k req/s peak.

**Architecture changes:**
- Auto-scaling app fleet (10–50 instances)
- DB primary + 2-3 replicas; partitioning huge tables
- Redis cluster (or Sentinel + replicas)
- Heavy use of CDN + cache for read endpoints
- Async processing for non-critical work
- Possibly multi-AZ deployment
- Search engine separate from DB
- APM + structured logging non-negotiable

**Bottlenecks emerge at:**
- DB write throughput
- Connection pool sizing
- Cache stampede during peaks
- Cost growing faster than revenue

---

### Q88. Designing for 100M MAU.

Typical: 10M DAU, 500k peak concurrent, 100k+ req/s peak.

**Architecture:**
- Microservices (or modular monolith with clear boundaries)
- Sharded DBs (or distributed: Cassandra, Spanner, CockroachDB)
- Multi-region active-active or active-read-replica
- CDN absorbs majority of traffic
- Edge compute for personalization
- Stream processing for events (Kafka)
- Dedicated search infrastructure
- Tiered storage with lifecycle rules
- SRE team + on-call
- Capacity planning, gameday exercises, chaos engineering

**Operational requirements:**
- p99 latency budget at every layer
- Per-tenant noisy-neighbor isolation
- Per-region failover plans
- Cost optimization is its own engineering function

---

### Q89. The minimum viable scale architecture.

Don't over-engineer day one. Many "scale" features can be added when needed:

| Feature | When to add |
|---------|-------------|
| CDN | From day one (cheap, big win) |
| Cache | When DB becomes the bottleneck |
| Read replica | When primary CPU > 60% on reads |
| Async queue | When sync work > 200 ms |
| Multi-region | When users globally complain |
| Sharding | When one DB box can't take it |
| Microservices | When team can't ship monolith |
| Edge compute | When personalization at edge unblocks scale |

Prematurely scaling = wasted money + complexity + bugs. Reactively scaling = late nights. Aim for "just in time."

---

### Q90. Senior signal: "How would you scale this to 100x?"

Don't list buzzwords. Walk through:

1. **Measure baseline:** what's the current capacity? Where does it break first?
2. **Identify constraints:** DB? Network? CPU? Memory?
3. **Cheapest wins first:** caching, query tuning, CDN
4. **Stateless app fleet** if not already
5. **Read scaling:** replicas, caching, CDN
6. **Write scaling:** queue async, partition, eventually shard
7. **Geographic:** multi-region for latency, or accept single-region if users co-located
8. **Cost analysis:** does the architecture make business sense at 100x?
9. **Operational:** can our team run it? Hire, train, automate.
10. **Iterative rollout:** never big-bang.

Senior engineers know that scale is a journey, not a destination. Each step buys time before the next.

---

## Appendix — Numbers to Remember

| Reference | Number |
|-----------|--------|
| L1 / L2 / L3 cache | 0.5 / 7 / 25 ns |
| RAM access | 100 ns |
| SSD random read | 100 µs |
| Same-AZ RTT | 0.5 ms |
| Cross-AZ RTT | 1-2 ms |
| Cross-region RTT | 50-200 ms |
| Cross-continent RTT | 100-300 ms |
| Single Postgres can do | ~50k simple queries/s |
| Single Redis instance | ~100k ops/s |
| Kafka broker | ~1M msg/s |
| Single Node.js process | ~30k req/s (simple) |
| HTTP keep-alive saved | 50-200 ms per connection |
| Browser parallel connections | 6 per origin (HTTP/1.1) |
| TCP slow start | first ~14 KB free, then escalates |
| TLS 1.3 handshake | 1 RTT (vs 2 in TLS 1.2) |

---

## Appendix — When You're Hitting Walls, in Order

1. Add a missing index
2. Add cache
3. Tune queries / N+1
4. Vertical scale (bigger box)
5. Horizontal scale stateless services
6. Read replicas
7. Async non-critical work
8. CDN for read traffic
9. Partition huge tables
10. Shard the DB
11. Multi-region
12. Rewrite hot service in faster language
13. Specialized infrastructure (Kafka, Cassandra, Elasticsearch, custom)

The best scaling decision is the one you didn't have to make yet.
