# Scaling for Millions of Users — Interview Q&A Guide

This guide covers capacity planning, vertical vs horizontal scaling, stateless services, database scaling and sharding, caching tiers and patterns, async processing, rate limiting, CDN strategies, geographic distribution, search, media pipelines, observability at scale, real-time systems, cost optimization, and common bottleneck patterns.

---

## Capacity Planning

## Q1. How do you estimate traffic?

**Answer:**

Always start with a back-of-envelope calculation.

Inputs you need:
- Daily Active Users (DAU)
- Average requests per user per day
- Peak vs average ratio (typically 3-5x, more for consumer apps)
- Read:write ratio
- Average payload sizes

Worked example for a 10M DAU social app:

```
10M DAU * 30 sessions/day * 5 reqs/session = 1.5B reqs/day
1.5B / 86400 = ~17,400 req/s average
Peak (4x) = 70,000 req/s
90% reads / 10% writes = 63,000 read/s, 7,000 write/s
```

This ballpark guides every other decision: DB size, cache size, instance count.

## Q2. How do you estimate bandwidth?

**Answer:**

Egress bytes per second is often the most expensive resource.

```
egress = avg_response_size * peak_requests_per_sec
```

Example: 10 KB avg response * 70k req/s = 700 MB/s = 5.6 Gbps.

A single AWS NAT gateway or typical instance can push 5-25 Gbps. A CDN offloads most of this — without one you would need many origin instances just for bandwidth.

## Q3. How do you estimate storage growth?

**Answer:**

```
new_data_per_day = active_users * avg_data_created_per_user
yearly_storage = data_per_day * 365 * replication_factor * overhead
```

Plan for 3-5 years, with 30+ percent overhead for indexes, WAL, and backups.

Common surprises:
- Logs and audit trails — easily 10x the "real" data
- Image and video — if you do not use object storage, your DB explodes
- Soft-deleted rows — bloat over time

## Q4. What does a 200 ms latency budget look like?

**Answer:**

Breaking down a 200 ms p95 user request:

| Phase | Budget |
| --- | --- |
| DNS + TLS + network | 50 ms |
| Load balancer + reverse proxy | 20 ms |
| Framework + middleware | 10 ms |
| DB / cache lookups | 80 ms |
| Serialization + response | 20 ms |
| Slack | 20 ms |

If your DB alone uses 150 ms, the system is unbalanced.

## Q5. How does the read:write ratio drive architecture?

**Answer:**

| Ratio | Architecture |
| --- | --- |
| 1:1 (transactional) | Single primary, modest scaling |
| 10:1 | Read replicas, caching layer |
| 100:1 (most consumer apps) | Aggressive caching, CDN, replica fan-out |
| 1000:1 (read-only feed) | Edge caching, materialized views |
| 1:10 (analytics ingest) | Append-only logs, batched writes |

Optimize for the common case.

---

## Vertical vs Horizontal Scaling

## Q6. When do you scale up vs out?

**Answer:**

Scale up first when:
- One box still has headroom (CPU < 70%, RAM < 80%)
- The workload does not parallelize well (single-master DB)
- Scale-out adds complexity not worth it
- Your team cannot operationally support more nodes

Scale out when:
- Vertical limits hit (256 GB RAM is plenty, 4 TB is exotic and slow)
- You need fault tolerance
- You need geographic distribution
- The workload is naturally parallel

A single modern box (96 cores, 768 GB RAM, NVMe) handles enormous load.

## Q7. What is the cost curve of scaling?

**Answer:**

Vertical scaling: cost grows super-linearly. A 16-core costs 2x an 8-core; a 128-core costs 32x an 8-core.

Horizontal scaling: cost grows linearly plus coordination overhead.

At AWS sticker prices, going beyond about 32 vCPU is often less cost-effective than splitting into multiple instances.

---

## Stateless Services

## Q8. What does "stateless" mean?

**Answer:**

Each request is independent. The server holds no per-user data between requests. Any instance can handle any request. Sessions go to Redis or DB, not local memory.

Stateless services scale linearly: add nodes, add capacity.

```js
// BAD: in-memory session map breaks horizontal scaling
const sessions = new Map();

// GOOD: external session store
import Redis from 'ioredis';
const redis = new Redis();
await redis.set(`session:${id}`, JSON.stringify(data), 'EX', 3600);
```

## Q9. What state still has to live somewhere?

**Answer:**

| Type | Where |
| --- | --- |
| User sessions | Redis (TTL'd), JWT (client-held) |
| Auth tokens | DB or Redis (revocable) |
| Shopping cart | Redis or DB |
| Rate limit counters | Redis with atomic operations |
| Locks for critical sections | Redis with `SET NX EX` or DB advisory locks |
| Real-time presence | Redis pub/sub or distributed system |
| Application configuration | Config service or env vars |

Anything that needs to persist or be shared goes to a managed external store.

## Q10. JWT vs server sessions — which to use?

**Answer:**

| | JWT | Session in Redis |
| --- | --- | --- |
| Server state | None | Required |
| Revocation | Hard (need denylist) | Easy (delete key) |
| Size | Larger header | Just session ID |
| Verify cost | Crypto verify | Redis lookup |
| Across services | Easy | Need shared Redis |

For internal microservices, JWT is fine. For consumer auth where revocation matters (logout, security incident), Redis-backed sessions are simpler.

## Q11. When are sticky sessions necessary?

**Answer:**

Avoid if possible. Required only for:
- WebSocket connections (route to the right instance)
- Long-running streaming endpoints
- In-process state during a multi-step flow (rare; redesign instead)

Implement via load balancer cookie or hash. Sticky sessions limit scale-out flexibility because you cannot drain a node without disrupting users.

---

## Database Scaling

## Q12. How do read replicas work?

**Answer:**

Primary handles writes; replicas serve reads.

```
[App] -- writes --> [Primary] --replication--> [Replica 1, Replica 2]
[App] -- reads --> [Replicas (load-balanced)]
```

Application config example:

```js
const writePool = new Pool({ host: 'primary.db' });
const readPool = new Pool({ host: 'replica.db' });

async function getUser(id) {
    const r = await readPool.query('SELECT * FROM users WHERE id = $1', [id]);
    return r.rows[0];
}

async function createUser(data) {
    return writePool.query('INSERT INTO users ...', [...]);
}
```

Read replicas add read capacity linearly but do not help write capacity.

## Q13. How do you handle read-after-write consistency?

**Answer:**

A user submits, then immediately fetches, but sees stale data because the read went to a replica that has not caught up.

Strategies:
- **Read-your-writes**: route the same user's reads to the primary for N seconds after a write
- **Wait for sync**: primary returns the LSN; replica lookup waits until that LSN is applied
- **Synchronous replication**: strict but slows writes
- **Optimistic UI**: show the just-written data from client memory

```js
const RECENT_WRITE_TTL_MS = 5000;

async function read(userId, key) {
    const recentlyWrote = await redis.get(`recent_write:${userId}`);
    const pool = recentlyWrote ? writePool : readPool;
    return pool.query(...);
}

async function write(userId, key, value) {
    await writePool.query(...);
    await redis.set(`recent_write:${userId}`, '1', 'PX', RECENT_WRITE_TTL_MS);
}
```

## Q14. What replication topologies exist?

**Answer:**

| Topology | Description | Use |
| --- | --- | --- |
| Single primary, N replicas | Standard | Most apps |
| Cascading replicas | Replicas of replicas | Reduce primary load |
| Multi-region | Replica per region | Geographic reads |
| Multi-master | All accept writes | Special cases (CRDT, last-write-wins) |
| Logical replication | Per-table, cross-version | Migrations, heterogeneous |

Multi-master is rarely worth the conflict-resolution headache for OLTP.

## Q15. Partitioning vs sharding — what is the difference?

**Answer:**

| | Partitioning | Sharding |
| --- | --- | --- |
| Where | Within one DB instance | Across multiple instances |
| App view | Single logical table | Application or proxy routes |
| Use | Manage huge tables | Scale beyond one box |
| Cross-key queries | Native | Hard |
| Operational complexity | Modest | Significant |

Partition before you shard.

## Q16. How does connection pool exhaustion happen at scale?

**Answer:**

100 instances * 50 connections each = 5000 connections to your DB. Most DBs choke at thousands of connections (each one consumes RAM).

Solutions:

```
[App instances] --> [PgBouncer / ProxySQL] --> [Postgres / MySQL]
```

- Connection pooler in front: PgBouncer (Postgres), ProxySQL (MySQL), RDS Proxy
- Smaller per-instance pools — most instances do not need 50
- Aurora Serverless v2 or Cloud SQL Enterprise Plus for managed pooling

```ini
# pgbouncer.ini
[databases]
mydb = host=primary.db port=5432

[pgbouncer]
pool_mode = transaction
default_pool_size = 50
max_client_conn = 5000
```

---

## Sharding Strategies

## Q17. How does hash-based sharding work?

**Answer:**

```
shard = hash(user_id) % N
```

Pros: even distribution, simple.
Cons: rebalancing requires moving most data when N changes. Use consistent hashing instead.

## Q18. How does range-based sharding work?

**Answer:**

```
shard 1: user_id 0-1M
shard 2: user_id 1M-2M
shard 3: user_id 2M-3M
```

Pros: range queries are efficient, easy to add new shards (last range).
Cons: hot spot on the newest range (most active users); old shards under-utilized.

Often used for time-series: shard by month.

## Q19. What is directory-based sharding?

**Answer:**

A lookup service maps each key to a shard. Each user has an explicit `shard_id`.

```sql
SELECT shard_id FROM user_directory WHERE user_id = 42;
-- Then connect to that shard
```

Pros: full flexibility, easy rebalancing.
Cons: extra hop, the directory itself becomes a bottleneck (must be heavily cached).

## Q20. What is consistent hashing?

**Answer:**

Maps keys and shards onto a ring. Adding or removing a shard moves only `1/N` of keys.

```
Ring [0, 2^32):
  Shard A: ring positions {100, 5000, 8000}
  Shard B: ring positions {800, 3000, 9000}
  Key K hashes to 4500 -> assigned to Shard A's 5000 position
```

Used by Cassandra, DynamoDB, Memcached, Redis Cluster. With virtual nodes (each physical shard occupies many ring positions), distribution is even and rebalancing is smooth.

## Q21. What makes a good shard key?

**Answer:**

A good shard key is:
- High cardinality (millions of distinct values)
- Evenly distributed (no value 100x more than others)
- Aligned with queries (most queries hit one shard)
- Stable (does not change for a row)
- Application-meaningful (derivable without lookup)

Bad choices:
- Boolean (only 2 values)
- Status (concentrated values)
- Sequential ID with range sharding (hot spot)
- Country (US dominates)
- Tenant ID without sub-sharding (one giant tenant)

## Q22. How do you handle cross-shard queries?

**Answer:**

The hard part of sharding. Strategies in order of preference:

1. **Avoid them in design** — schema such that 99 percent of queries hit one shard. Denormalize across shards if needed.
2. **Scatter-gather** — query all shards, combine results. Latency equals the slowest shard.
3. **Global secondary index** — maintained outside shards (search engine).
4. **Async aggregation** — ETL all shards into a warehouse for analytics.

```js
// Scatter-gather example
async function searchAcrossShards(query) {
    const results = await Promise.all(
        shards.map((shard) => shard.search(query, { timeout: 200 }))
    );
    return results.flat();
}
```

## Q23. How do you reshard without downtime?

**Answer:**

Steps:

1. **Double-write**: writes go to both old and new shards
2. **Backfill**: copy historical data to new shards in chunks
3. **Verify**: consistency check between old and new
4. **Switch reads**: gradually move read traffic to new shards
5. **Stop double-writes**: decommission old shards

Tools: Vitess (MySQL), Citus (Postgres), or application-managed (Slack, Notion).

Plan for weeks, not days. Have rollback at every step.

---

## Caching Tiers

## Q24. What is the cache hierarchy?

**Answer:**

```
[Browser cache] -> [CDN edge] -> [Reverse proxy / Varnish] -> [App in-memory] -> [Distributed cache (Redis)] -> [DB]
```

Each layer absorbs requests. A request that hits browser cache costs nothing; a request that hits the DB costs the most.

Goal: maximize hits at the highest layer where correctness allows.

## Q25. How do you use the browser cache?

**Answer:**

```
Cache-Control: public, max-age=31536000, immutable
```

Asset filenames must include hashes (`app.4f7a2b.js`) for cache busting.

For HTML or API responses use a shorter `max-age` plus `stale-while-revalidate`. Combine with ETag for revalidation.

## Q26. What can a CDN edge cache?

**Answer:**

The biggest leverage. A 200 ms origin trip becomes 20 ms edge serve. CDN absorbs 90+ percent of traffic for static, sometimes 50+ percent for dynamic.

```
Cache-Control: public, max-age=60, s-maxage=3600, stale-while-revalidate=300
Surrogate-Key: products homepage
```

Tips:
- CDN respects `s-maxage` for shared cache
- Use surrogate keys (Fastly) or cache tags (Cloudflare) for purging
- Serve cookies-free for static assets (cookies bypass cache)
- Be careful with `Vary: Cookie` — destroys cache hit rate

## Q27. What is edge compute?

**Answer:**

Cloudflare Workers, Vercel Edge, AWS Lambda@Edge — run code at PoPs near users.

Use cases:
- Personalize at the edge (A/B test, geo redirect)
- Auth check (JWT validation) before origin hit
- Stitch responses from multiple origins
- Rewrite URLs for tenant routing

```js
// Cloudflare Worker example
export default {
    async fetch(req) {
        const country = req.cf.country;
        const url = new URL(req.url);
        url.pathname = `/${country.toLowerCase()}${url.pathname}`;
        return fetch(url, req);
    },
};
```

Constraints: limited runtime (V8 isolate), short execution time, no full Node API.

## Q28. How do you use a reverse proxy cache?

**Answer:**

Nginx, Varnish, or HAProxy can cache between the LB and the app.

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

`proxy_cache_lock on` is built-in stampede protection. Useful when CDN cannot serve the path (private network, internal API).

## Q29. How do you scale Redis as a distributed cache?

**Answer:**

Patterns:

| Setup | Capacity | HA |
| --- | --- | --- |
| Single Redis | ~100k ops/s | None |
| Redis Sentinel | Same | Automatic failover |
| Redis Cluster | Scales to millions of ops/s | Built-in sharding |
| Managed (ElastiCache, MemoryDB, Upstash) | Varies | Operational ease |

Watch out for:
- Cross-AZ network latency (1-2 ms)
- Hot keys — one key getting 100k req/s saturates one shard
- Connection storms during failover

## Q30. When should you use an in-process cache?

**Answer:**

Per-instance LRU. Sub-microsecond access.

```js
const { LRUCache } = require('lru-cache');
const featureFlags = new LRUCache({ max: 100, ttl: 60_000 });
```

Best for:
- Reference data rarely changing (countries, currencies, feature flags)
- Hot keys with high hit rate
- Reducing Redis round trips for super-hot data

Risk: divergence between instances. Use short TTL or pub/sub for invalidation.

---

## Cache Patterns

## Q31. What is the cache-aside pattern?

**Answer:**

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

Pros: simple, only caches what is read.
Cons: cache miss latency hits the DB; race during update.

## Q32. What is the read-through pattern?

**Answer:**

The cache library fetches from the DB on miss. The app only knows about the cache.

```python
val = cache.get_or_load(key, loader=lambda: db.fetch(key))
```

Pros: cleaner app code.
Cons: cache library coupling.

## Q33. What is the write-through pattern?

**Answer:**

Every write goes to cache AND DB synchronously.

```python
def update(key, val):
    db.update(key, val)
    cache.set(key, val, ttl=300)
```

Pros: cache always in sync after write.
Cons: writes are slower (two round trips); if cache write fails, divergence.

## Q34. What is write-back (write-behind)?

**Answer:**

Writes go to cache only; async flush to DB.

Pros: huge write throughput.
Cons: data loss if cache crashes before flush. Use only for non-critical metrics, counters, telemetry.

## Q35. What are good cache invalidation strategies?

**Answer:**

| Strategy | Description |
| --- | --- |
| TTL only | Eventual consistency, simplest |
| Explicit on write | Delete key in same transaction (after commit) |
| Pub/sub | Write source publishes invalidations |
| Tag-based | Group keys, purge tag (Cloudflare cache tags, Fastly surrogate keys) |
| Versioned keys | `user:123:v17`; bumping version makes old cache irrelevant |

Critical bug: invalidating before commit. Reader caches the pre-commit state.

```python
# WRONG: invalidate before commit
cache.delete(f"user:{id}")
db.commit()

# RIGHT: invalidate after commit
db.commit()
cache.delete(f"user:{id}")
```

## Q36. How do you warm a cache?

**Answer:**

For predictable spikes (sale launch, sports event), pre-populate the cache.

```python
def warm_cache():
    for key in expected_hot_keys():
        cache.set(key, db.fetch(key), ttl=600)

# Run as a cron job before traffic hits
```

Saves you from 1000 cold misses at moment zero.

## Q37. How do you protect against thundering herd?

**Answer:**

When a hot key expires, 1000 concurrent requests miss and hit the DB. The DB collapses.

Solutions:

```python
# 1. Lock + single-flight
def get_with_lock(key, ttl):
    val = cache.get(key)
    if val: return val
    if cache.set(f"lock:{key}", "1", nx=True, ex=10):
        try:
            val = db.fetch(key)
            cache.set(key, val, ex=ttl)
            return val
        finally:
            cache.delete(f"lock:{key}")
    else:
        time.sleep(0.05)
        return get_with_lock(key, ttl)
```

Other patterns:
- Probabilistic early refresh (XFetch) — refresh slightly before expiry with rising probability
- Two-tier TTL — soft (refresh async) + hard (refresh sync)
- Stale-while-revalidate
- Background refresh on schedule

## Q38. Why is negative caching important?

**Answer:**

Cache the "not found" result. Otherwise repeat scans for missing keys hammer the DB.

```python
NULL_SENTINEL = '__NULL__'

def get(key):
    val = cache.get(key)
    if val == NULL_SENTINEL: return None
    if val: return val
    val = db.fetch(key) or NULL_SENTINEL
    cache.set(key, val, ttl=60)   # shorter TTL for nulls
    return None if val == NULL_SENTINEL else val
```

Especially important under attack (bot probing for non-existent IDs).

---

## Async Processing

## Q39. When should you go async?

**Answer:**

Anything that:
- Does not need to complete before the user gets a response
- Takes more than 200 ms
- Could fail and retry
- Fans out to many recipients
- Is CPU-heavy

Examples: send email, generate PDF, transcode video, sync to third party, recompute aggregates, send notification.

```
Sync API -> enqueue job -> 202 Accepted with status URL
                        -> background processes job
                        -> user polls or gets webhook
```

## Q40. How do queue technologies compare?

**Answer:**

| Tool | Throughput | Latency | Features |
| --- | --- | --- | --- |
| Redis (BullMQ, Sidekiq) | 10k+/s | ms | Easy, retries, scheduling |
| RabbitMQ | 50k+/s | ms | Routing, exchanges, ACKs |
| SQS | Unlimited (managed) | ~10s p99 | At-least-once, FIFO option |
| Kafka | Millions/s | ms | Event log, replay, retention |
| Pulsar | Millions/s | ms | Like Kafka with multi-tenancy |
| NATS / JetStream | Millions/s | sub-ms | Lightweight, simple |

Pick based on volume, latency, ordering, replay, and ops experience.

## Q41. What are fan-out patterns?

**Answer:**

Push notification to 1M users.

Naive: loop and send each — slow, blocks if any fail.

Fan-out queue:

```
master job -> enqueues 1000 sub-jobs (1k users each)
sub-jobs -> enqueue per-user notifications
worker pool -> processes per-user
```

```js
// BullMQ example
async function fanOut(userIds) {
    const batches = chunk(userIds, 1000);
    for (const batch of batches) {
        await batchQueue.add('notify-batch', { userIds: batch });
    }
}

new Worker('notify-batch', async (job) => {
    for (const userId of job.data.userIds) {
        await notifyQueue.add('notify-one', { userId });
    }
});
```

Each layer multiplies capacity. Failures isolated to small batches.

## Q42. How do you do fan-in / aggregation?

**Answer:**

Many sources, one consumer.

Patterns:
- **Stream processing**: Kafka topic + consumer group with windowing (Flink, Kafka Streams)
- **Materialized views in DB**: triggers or events plus rollup tables
- **Batch ETL**: hourly or daily aggregation

For real-time use a stream processor. For analytics use a warehouse with batch ETL.

## Q43. What is the outbox pattern?

**Answer:**

Atomic write of "send email" with the DB transaction:

```sql
BEGIN;
INSERT INTO orders (id, total, ...) VALUES (...);
INSERT INTO outbox (event_type, payload) VALUES ('order_created', '{...}');
COMMIT;
```

A separate worker polls the outbox, publishes to a queue, and marks rows as sent.

```js
async function publishOutbox() {
    const rows = await db.query(`
        SELECT id, event_type, payload FROM outbox
        WHERE published_at IS NULL ORDER BY id LIMIT 100
    `);
    for (const row of rows.rows) {
        await queue.publish(row.event_type, row.payload);
        await db.query('UPDATE outbox SET published_at = NOW() WHERE id = $1', [row.id]);
    }
}
```

Avoids the "wrote to DB but failed to publish" inconsistency.

## Q44. How do you use idempotency keys?

**Answer:**

Async retries are inevitable. Make jobs idempotent:

```python
def process(job):
    if processed_set.contains(job.id): return
    do_work(job)
    processed_set.add(job.id, ttl=7*86400)
```

For outgoing API calls, send `Idempotency-Key: <uuid>` so the server dedupes (Stripe, Square, etc.).

```js
await fetch('https://api.stripe.com/v1/charges', {
    method: 'POST',
    headers: {
        'Idempotency-Key': crypto.randomUUID(),
        'Authorization': `Bearer ${apiKey}`,
    },
    body: ...,
});
```

---

## Rate Limiting

## Q45. How does the token bucket algorithm work?

**Answer:**

Each client has a bucket of N tokens, refilled at rate R per second. Each request consumes 1 token. An empty bucket returns 429.

Smooth burst handling: allows short spikes within capacity.

```lua
-- Atomic Lua script in Redis for token bucket
local key = KEYS[1]
local now = tonumber(ARGV[1])
local rate = tonumber(ARGV[2])
local capacity = tonumber(ARGV[3])
local cost = tonumber(ARGV[4])

local last = tonumber(redis.call('HGET', key, 'last') or now)
local tokens = tonumber(redis.call('HGET', key, 'tokens') or capacity)

local elapsed = now - last
tokens = math.min(capacity, tokens + elapsed * rate)
last = now

if tokens >= cost then
    tokens = tokens - cost
    redis.call('HSET', key, 'last', last, 'tokens', tokens)
    redis.call('EXPIRE', key, 3600)
    return 1
else
    return 0
end
```

Standard implementations: nginx `limit_req`, AWS API Gateway, Cloudflare, application libraries.

## Q46. What is sliding window rate limiting?

**Answer:**

Counts requests in a rolling N-second window.

Two implementations:
- **Sliding log**: Redis sorted set of timestamps, count entries in window. Accurate but costly.
- **Sliding counter**: combine current window count with previous window weighted by elapsed time. Approximate, cheap.

Used when fairness within a window matters more than smoothness.

## Q47. How do you distribute rate limits across instances?

**Answer:**

Local-only counters fail when traffic distributes across N nodes. A user can hit `limit * N`.

Solutions:
- Shared Redis counter with atomic INCR + EXPIRE — most common
- Token bucket in Redis with Lua script for atomicity
- Probabilistic local plus reconciliation — each node enforces `limit / N` locally

```js
async function check(userId) {
    const key = `rl:${userId}:${Math.floor(Date.now() / 60000)}`;
    const count = await redis.incr(key);
    if (count === 1) await redis.expire(key, 60);
    return count <= 100;
}
```

## Q48. What dimensions should you rate-limit on?

**Answer:**

- Per user (most common)
- Per IP (anonymous, anti-DDoS)
- Per API key (B2B)
- Per endpoint (expensive endpoints get lower limits)
- Per tier (free, pro, enterprise)
- Globally (protect downstream)

Combine: "100 req/min per user OR 1000 req/min per IP OR 10000 req/min total."

## Q49. What does a good 429 response look like?

**Answer:**

```
HTTP/1.1 429 Too Many Requests
Retry-After: 60
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1700000000
Content-Type: application/json

{"error": "rate_limit_exceeded", "retry_after": 60}
```

Clients should respect `Retry-After` with backoff and jitter. Document your limits clearly.

---

## CDN

## Q50. What can a CDN cache?

**Answer:**

Static (easy): JS, CSS, images, fonts, video. Long cache, immutable.

Dynamic (depends):
- HTML pages with low personalization (homepage, product page) — short TTL plus `stale-while-revalidate`
- API responses for read-heavy data — public, ETag, max-age
- Personalized pages — edge compute or vary intelligently

Do not cache:
- Auth-required user-specific data unless partitioned by user (`Cache-Control: private`)
- POST or PUT responses
- Anything with PII over a shared cache

## Q51. How do you design cache keys for a CDN?

**Answer:**

CDN typically keys on URL plus Vary headers. Tune:
- Strip irrelevant query params (`utm_*`, session IDs) so all variants share cache
- `Vary: Accept-Encoding` for compression and `Vary: Accept` for image format
- Do not `Vary: Cookie` for public content

```
# Cloudflare Page Rules: ignore utm parameters
*.example.com/* -> Cache Level: Cache Everything
                -> Origin Cache Control: On
                -> Ignore Query String for: utm_source, utm_medium
```

A small change to keying can take hit rate from 60 percent to 95 percent.

## Q52. How do you purge a CDN cache?

**Answer:**

| Method | When |
| --- | --- |
| Full purge | Nuclear option |
| URL purge | Specific URLs |
| Tag / surrogate-key purge | Content marked with tags is invalidated together |
| Soft purge | Marks stale, serves while revalidating |

For e-commerce, tag pages with product IDs. On product update, purge that tag and all dependent pages invalidate.

```js
// Fastly: tag responses
res.setHeader('Surrogate-Key', `product-${id} category-${categoryId}`);

// Then purge by tag
await fetch('https://api.fastly.com/service/SVC/purge', {
    method: 'POST',
    headers: { 'Surrogate-Key': `product-${id}`, 'Fastly-Key': key },
});
```

## Q53. When should you use multi-CDN?

**Answer:**

Use 2 CDNs (Cloudflare plus Fastly, etc.) for:
- Resilience (one outage does not take you out)
- Best price-performance per region
- Smart routing via DNS or RUM-based balancer

Costs more, more ops complexity. Useful at high scale or for SLA reasons.

---

## Geographic Distribution

## Q54. What is the latency from a single region?

**Answer:**

| Origin | Same region | Cross-continent |
| --- | --- | --- |
| US-East | 20-50 ms | 150-300 ms |
| EU | 20-50 ms | 150-300 ms |
| APAC | 20-50 ms | 200-400 ms |

A Sydney user hitting US-East has ~200 ms RTT. A 5-trip API call wastes a full second on the network alone.

CDN handles static assets; for dynamic, you need multi-region.

## Q55. How do multi-region read replicas work?

**Answer:**

Primary in one region; replicas in others for local reads.

```
[US Primary] -- replicates --> [EU Replica, APAC Replica]
[EU users] --reads--> [EU Replica]
[EU users] --writes--> [US Primary]   (cross-region penalty)
```

Acceptable when writes are infrequent and reads dominate.

## Q56. What is active-active multi-region?

**Answer:**

Each region accepts writes and syncs to others.

Approaches:
- **Geo-partitioning**: users belong to a region, write only there. Examples: Dynamo, Spanner, CockroachDB.
- **CRDT (Conflict-free Replicated Data Types)**: for things like counters, sets.
- **Last-write-wins**: simple but lossy.

The hardest part: cross-region foreign keys. Often denormalize regional data.

## Q57. What DNS-based routing methods exist?

**Answer:**

| Method | Behavior |
| --- | --- |
| GeoDNS | Route by user's location |
| Latency-based | Route to lowest-latency region |
| Weighted | Split traffic for canary deploys |
| Failover | Auto-switch on health check failure |

Providers: AWS Route 53, Cloudflare DNS, NS1, Akamai DNS.

## Q58. How do edge functions enable personalization?

**Answer:**

Run code at every PoP:
- Greet user by detected country
- Show A/B variant
- Check auth before forwarding to origin
- Rewrite static HTML with personalized chunks

```js
// Cloudflare Worker
export default {
    async fetch(req) {
        const country = req.cf.country;
        const isAB = req.cf.colo.startsWith('S');
        const res = await fetch(req);
        const html = (await res.text())
            .replace('<!--country-->', country)
            .replace('<!--variant-->', isAB ? 'B' : 'A');
        return new Response(html, res);
    },
};
```

---

## Search at Scale

## Q59. When should you use a search engine vs the DB?

**Answer:**

Use Elasticsearch, OpenSearch, or Algolia when:
- Full-text search with relevance ranking
- Faceted search (filter by attributes)
- Typo tolerance, synonyms
- Aggregations across millions of documents
- Geospatial plus text combined
- Autocomplete

For simple `LIKE 'foo%'` on a single column with limited data, the DB is fine.

## Q60. How do you size Elasticsearch?

**Answer:**

- Heap: 50 percent of RAM, max 32 GB (compressed pointers)
- Shards: aim for 30-50 GB per shard for primary indexes
- Total shards per node: <= 600 (less is better)
- Replicas: 1 or more for HA
- Do not over-shard small indexes — 1 shard is fine for under 50 GB

Indexing throughput is typically ~5-10k docs/s per node; tune `refresh_interval` and use the `bulk` API for higher throughput.

```yaml
# elasticsearch.yml
indices.memory.index_buffer_size: 30%
thread_pool.write.queue_size: 10000
```

## Q61. How do you ingest data from DB to search?

**Answer:**

Patterns:

1. **Sync on write**: app writes both DB and ES. Risk of divergence.
2. **Outbox plus worker**: atomic outbox row, worker indexes async. Reliable.
3. **CDC (Change Data Capture)**: Debezium reads DB WAL, streams to ES. No app changes.
4. **Periodic reindex**: batch job, simple but stale.

For consistency-critical search, prefer CDC or outbox.

```yaml
# Debezium Postgres connector example
connector.class: io.debezium.connector.postgresql.PostgresConnector
plugin.name: pgoutput
publication.name: dbz_publication
slot.name: debezium
```

## Q62. How do you keep search fast at scale?

**Answer:**

Avoid:

```json
// SLOW: deep pagination
{ "from": 100000, "size": 20 }

// FAST: search_after with sort
{ "size": 20, "sort": [{"id": "asc"}], "search_after": [12345] }
```

- Wildcards on large fields (`*foo*`) — use ngram tokenization or a dedicated autocomplete index
- Sorting on high-cardinality unindexed fields
- Returning all source docs when you only need IDs

Cache hot queries. Pre-aggregate facet counts when possible.

---

## Media at Scale

## Q63. What does an image pipeline look like?

**Answer:**

```
[User upload] -> [Object storage (S3)] -> [Image processor (Lambda/CloudFront)]
              -> [CDN] -> [User]
```

- Original stored once in S3
- Variants generated on-demand at the CDN or edge (Cloudflare Images, imgix, Vercel)
- WebP/AVIF served via Accept header negotiation
- Long cache plus hashed filenames

Storage class: original in Standard or IA; archived in Glacier.

## Q64. What does a video pipeline look like?

**Answer:**

```
[Upload] -> [Transcoder (FFmpeg / MediaConvert)] -> [HLS/DASH segments]
         -> [Object storage] -> [CDN] -> [Player]
```

- Adaptive bitrate (multiple resolutions)
- Segment size 6-10 seconds
- Live: low-latency HLS or WebRTC
- DRM if needed (Widevine, FairPlay)

For UGC at scale, use SQS-based job queues, auto-scaling transcode workers, GPU instances for AV1.

## Q65. What are best practices for object storage?

**Answer:**

- S3 / GCS / Azure Blob — virtually unlimited, pay per GB and operations
- Lifecycle rules — move old data to IA, Glacier, or cold storage automatically
- Versioning — protect against deletes (cost trade-off)
- Pre-signed URLs — temporary access without exposing credentials
- Multipart upload for files over 100 MB
- Set `Content-Disposition` and `Content-Type` for browser handling

```js
// AWS SDK pre-signed URL
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const s3 = new S3Client({ region: 'us-east-1' });
const url = await getSignedUrl(s3,
    new GetObjectCommand({ Bucket: 'my-bucket', Key: 'doc.pdf' }),
    { expiresIn: 3600 });
```

---

## Logging and Metrics

## Q66. What sampling strategies should you use at scale?

**Answer:**

100k req/s * 10 KB log per request = 1 GB/s, 86 TB/day. Unaffordable.

Strategies:
- **Trace sampling**: record full traces for 1 percent of requests (head sampling) or 100 percent of slow/erroring (tail sampling)
- **Log levels**: info+ in prod, debug only on demand
- **Aggregation**: counters and histograms at app level; ship aggregates not every event
- **Sample low-value events**: "user viewed page" sampled at 1 percent
- **Always log errors and high-value events** in full

## Q67. Why does metrics cardinality matter?

**Answer:**

Cardinality is the number of unique label combinations. Each combo is a separate time series. Prometheus chokes at 1M+ series.

```python
# BAD: user_id as a label -> 10M users -> 10M series
metric.labels(user_id=user.id, endpoint='/api/x').inc()

# GOOD: low-cardinality labels
metric.labels(method='GET', status='200', endpoint='/api/x').inc()
```

Avoid free-form strings, timestamps, or any field with millions of unique values as labels.

## Q68. What are the log aggregation options?

**Answer:**

| Tool | Pros | Cons |
| --- | --- | --- |
| ELK / OpenSearch | Flexible, powerful | Expensive at scale |
| Loki (Grafana) | Cheap | Less full-text power |
| CloudWatch Logs | Managed | Expensive |
| DataDog / New Relic / Honeycomb | Logs + metrics + traces | Cost |

For very high volume: ship aggregates to TSDB, sample traces to APM, stream raw logs to S3 plus query with Athena or BigQuery.

## Q69. What are typical retention windows?

**Answer:**

| Data | Retention |
| --- | --- |
| Metrics (raw) | 7-30 days |
| Metrics (downsampled) | 1+ year |
| Logs (debug, info) | 7-14 days |
| Logs (audit, security) | Years (compliance) |
| Traces | 7-14 days, 100 percent retention impractical |

Use cheap cold storage (S3 Glacier, Archive tier) for compliance retention.

---

## Real-Time at Scale

## Q70. How do you scale WebSocket clusters?

**Answer:**

Each WS connection holds an open TCP. 1M users = 1M sockets.

- Per node: 50k-500k connections (kernel tuning required: `ulimit`, `net.ipv4.tcp_*`)
- Sticky routing (LB to same node) since the connection is stateful
- Heartbeats to detect dead connections (every 30 s)
- Backpressure — slow consumers cannot block

```js
// Node WebSocket server with heartbeat
import { WebSocketServer } from 'ws';

const wss = new WebSocketServer({ port: 3000 });

wss.on('connection', (ws) => {
    ws.isAlive = true;
    ws.on('pong', () => { ws.isAlive = true; });
});

setInterval(() => {
    wss.clients.forEach((ws) => {
        if (!ws.isAlive) return ws.terminate();
        ws.isAlive = false;
        ws.ping();
    });
}, 30000);
```

For high scale, use dedicated services: Ably, Pusher, AWS API Gateway WebSocket, Centrifugo, Phoenix Channels.

## Q71. How do you fan out with pub/sub?

**Answer:**

Server publishes once; all subscribers receive.

| Backbone | Strengths |
| --- | --- |
| Redis pub/sub | Simple but no persistence |
| Redis Streams | Persistent, consumer groups, replay |
| Kafka | Gold standard for high-volume |
| NATS | Lightweight, fast |
| MQTT | IoT, mobile |

For mobile push notification fan-out: push to APNs or FCM in batches; they handle the device fan-out.

## Q72. How do you handle presence at scale?

**Answer:**

"Who is online right now?" — naive per-user state explodes.

```js
// Heartbeat to Redis
async function heartbeat(userId) {
    await redis.set(`user:${userId}:online`, '1', 'EX', 60);
}

async function isOnline(userId) {
    return Boolean(await redis.exists(`user:${userId}:online`));
}
```

Other approaches:
- Pub/sub on connect/disconnect events to backend
- Approximate (HyperLogLog) for "active users last 5 min" without exact list

For social apps with hundreds of millions of users, online status is usually approximate by design.

---

## Cost Optimization

## Q73. How do you rightsize cloud instances?

**Answer:**

Most cloud bills are wasted because instances are oversized.

Process:
1. Capture utilization (CPU, memory, network) for 2 weeks
2. p95 utilization is your real need (with 30 percent headroom)
3. Pick the smallest instance type that fits
4. Re-evaluate quarterly

Tools: AWS Compute Optimizer, GCP Recommendations, Datadog cloud cost management.

## Q74. When should you use spot or preemptible instances?

**Answer:**

70-90 percent cheaper than on-demand. Risk: can be terminated with short notice (2 minutes on AWS).

Use for:
- Stateless workers
- Batch jobs (resume on new instance)
- Build / CI runners
- Auto-scaling groups with mixed spot plus on-demand

Do not use for:
- DB primaries
- Anything stateful that is expensive to restart

## Q75. How do you use Reserved Instances or Savings Plans?

**Answer:**

For steady baseline (always-on services), commit 1-3 years for 30-60 percent savings.

Strategy: cover ~80 percent of baseline with reserved; spike with on-demand or spot.

## Q76. How do S3 lifecycle rules save money?

**Answer:**

```
Standard ($0.023/GB/mo)
   -- after 30 days --> Standard-IA ($0.0125)
   -- after 90 days --> Glacier Instant ($0.004)
   -- after 180 days --> Glacier Flexible ($0.0036)
   -- after 1 year --> Glacier Deep Archive ($0.00099)
```

Example:

```json
{
    "Rules": [{
        "ID": "archive-old-logs",
        "Status": "Enabled",
        "Filter": { "Prefix": "logs/" },
        "Transitions": [
            { "Days": 30, "StorageClass": "STANDARD_IA" },
            { "Days": 90, "StorageClass": "GLACIER" }
        ],
        "Expiration": { "Days": 365 }
    }]
}
```

Setting lifecycle rules can drop archive bills 95 percent. Verify retrieval cost before moving data you will need urgently.

## Q77. Why is egress the cost killer?

**Answer:**

- AWS to internet: $0.05-$0.09/GB
- Inter-region: $0.02/GB
- Cross-AZ: $0.01/GB (yes, even within a region)

100 TB/month egress = $5,000-$9,000.

Mitigations:
- CDN (passes through CDN egress, often cheaper)
- Same-AZ traffic when possible
- Negotiate enterprise pricing
- Cloudflare's "no egress fee" is real

## Q78. What are the trade-offs of managed vs self-managed databases?

**Answer:**

Managed (RDS, Cloud SQL): 30-50 percent premium over EC2 plus self-manage.

| | Managed | Self-managed |
| --- | --- | --- |
| Backups, failover, patching | Out of the box | DIY |
| Monitoring | Built-in | Configure |
| Cost | Higher | Lower |
| Expertise needed | Less | More |
| Tuning knobs | Limited | Full |

For hot tables, in-memory (Redis, Aurora I/O Optimized) makes sense per-query. Run cost analysis at scale.

---

## Common Bottlenecks

## Q79. What is the hot key problem?

**Answer:**

One key gets 100x the traffic of others, saturating one shard or one Redis node.

Symptoms: one shard at 100 percent CPU while others are idle. p99 spikes.

Fixes:

```js
// Shard the hot key further
async function readHotKey() {
    const i = Math.floor(Math.random() * 16);
    return await redis.get(`hot_key:shard:${i}`);
}

async function writeHotKey(value) {
    await Promise.all(
        Array.from({ length: 16 }, (_, i) => redis.set(`hot_key:shard:${i}`, value))
    );
}
```

Other fixes: read-only replicas of the hot key; local cache in front.

## Q80. What is the hot row problem?

**Answer:**

A counter being incremented from many writers becomes a serialization point.

```sql
-- BAD: 10k writers all hitting one row
UPDATE counters SET count = count + 1 WHERE id = 1;
```

Fixes:

```sql
-- Sharded counter
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

Or increment in Redis and persist asynchronously:

```js
const total = await redis.incr(`post:${id}:views`);
if (total % 100 === 0) {
    await db.query('UPDATE posts SET views = $1 WHERE id = $2', [total, id]);
}
```

## Q81. What is the slow consumer problem?

**Answer:**

Producer at 10k/s, consumer at 1k/s — backlog grows forever.

Fixes:
- Scale consumers horizontally
- Optimize consumer logic
- Drop low-value messages (bounded queue, rejection)
- Backpressure on producer

Beware: a queue that fills memory crashes the producer or OOMs the upstream system.

## Q82. What is the unfair scheduler problem?

**Answer:**

A free-tier user can hit your API a million times; a paying customer is rate-limited because the shared queue is full.

Fixes:
- Per-tier queues
- Quotas per user
- QoS tagging

```js
// Per-tier queues
const criticalQueue = new Queue('jobs:critical');
const standardQueue = new Queue('jobs:standard');
const lowQueue = new Queue('jobs:low');

await getQueueForTier(user.tier).add('process', payload);
```

## Q83. What is the thundering herd at startup?

**Answer:**

The cluster restarts; 100 nodes all hit DB or cache at once.

Fixes:

```js
// Startup jitter
const jitter = Math.random() * 30_000;
await new Promise((r) => setTimeout(r, jitter));
await warmCache();
```

- Gradual rollout (do not restart all at once)
- Cache warming script

## Q84. What is the cascading failure pattern?

**Answer:**

One dependency slows. Callers retry. Load triples. Dependency slower. More retries. Cascade.

Fixes:
- Circuit breakers
- Retry budgets (cap retries at percentage of original requests)
- Bulkheads (separate thread pools per dependency)
- Load shedding (drop low-priority traffic when downstream stresses)

```js
const CircuitBreaker = require('opossum');
const breaker = new CircuitBreaker(callDownstream, {
    timeout: 3000,
    errorThresholdPercentage: 50,
    resetTimeout: 30_000,
});
breaker.fallback(() => ({ items: [], fallback: true }));
```

## Q85. What is the runaway query problem?

**Answer:**

A reporting query joins five huge tables, takes 20 minutes, locks tables, slows everything else.

Fixes:

```sql
-- Set a statement timeout per session
SET statement_timeout = '30s';

-- Or per role
ALTER ROLE analytics_user SET statement_timeout = '60s';
```

Move analytics off the OLTP path entirely:
- Separate replica for analytics
- ETL to a warehouse (Snowflake, ClickHouse)

---

## Case Studies

## Q86. How do you design for 1M MAU?

**Answer:**

Typical: 100k DAU, 5k peak concurrent, 1k req/s peak.

Stack:
- 2-4 app instances behind LB
- One DB primary + 1 replica for HA (vertical scale to r6.2xlarge or similar)
- Redis for cache, sessions, queue
- CDN for static assets
- Single region usually fine

Cost: $2k-$10k per month for AWS.

Where it can break:
- One slow query
- Forgetting to cache
- Unbounded user-generated content

A single competent team can run this comfortably.

## Q87. How do you design for 10M MAU?

**Answer:**

Typical: 1M DAU, 50k peak concurrent, 10k req/s peak.

Architecture changes:
- Auto-scaling app fleet (10-50 instances)
- DB primary plus 2-3 replicas; partitioning huge tables
- Redis cluster (or Sentinel + replicas)
- Heavy use of CDN + cache for read endpoints
- Async processing for non-critical work
- Multi-AZ deployment
- Search engine separate from DB
- APM and structured logging non-negotiable

Bottlenecks emerge at:
- DB write throughput
- Connection pool sizing
- Cache stampede during peaks
- Cost growing faster than revenue

## Q88. How do you design for 100M MAU?

**Answer:**

Typical: 10M DAU, 500k peak concurrent, 100k+ req/s peak.

Architecture:
- Microservices (or modular monolith with clear boundaries)
- Sharded DBs (or distributed: Cassandra, Spanner, CockroachDB)
- Multi-region active-active or active read-replica
- CDN absorbs majority of traffic
- Edge compute for personalization
- Stream processing for events (Kafka)
- Dedicated search infrastructure
- Tiered storage with lifecycle rules
- SRE team plus on-call
- Capacity planning, gameday exercises, chaos engineering

Operational requirements:
- p99 latency budget at every layer
- Per-tenant noisy-neighbor isolation
- Per-region failover plans
- Cost optimization is its own engineering function

## Q89. What is a minimum viable scale architecture?

**Answer:**

Do not over-engineer day one. Many "scale" features can be added when needed.

| Feature | When to add |
| --- | --- |
| CDN | From day one (cheap, big win) |
| Cache | When DB becomes the bottleneck |
| Read replica | When primary CPU exceeds 60% on reads |
| Async queue | When sync work exceeds 200 ms |
| Multi-region | When users globally complain |
| Sharding | When one DB box cannot take it |
| Microservices | When team cannot ship monolith |
| Edge compute | When personalization at edge unblocks scale |

Premature scaling means wasted money plus complexity plus bugs. Reactive scaling means late nights. Aim for "just in time."

## Q90. How would you scale a system to 100x?

**Answer:**

Walk through:

1. **Measure baseline**: what is the current capacity? Where does it break first?
2. **Identify constraints**: DB? Network? CPU? Memory?
3. **Cheapest wins first**: caching, query tuning, CDN
4. **Stateless app fleet** if not already
5. **Read scaling**: replicas, caching, CDN
6. **Write scaling**: queue async, partition, eventually shard
7. **Geographic**: multi-region for latency, or accept single-region if users co-located
8. **Cost analysis**: does the architecture make business sense at 100x?
9. **Operational**: can our team run it? Hire, train, automate.
10. **Iterative rollout**: never big-bang.

Each step buys time before the next.

---

## Appendix — Numbers to Remember

| Reference | Number |
| --- | --- |
| L1 / L2 / L3 cache | 0.5 / 7 / 25 ns |
| RAM access | 100 ns |
| SSD random read | 100 us |
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
| TLS 1.3 handshake | 1 RTT (vs 2 in TLS 1.2) |

---

## Appendix — When You Are Hitting Walls, in Order

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

The best scaling decision is the one you did not have to make yet.
