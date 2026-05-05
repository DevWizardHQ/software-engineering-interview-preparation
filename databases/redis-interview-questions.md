# Redis Interview Q&A — Basic to Advanced

**Purpose:** Practical Redis knowledge for backend and full-stack interviews. Each topic has a clear question, a plain-language answer, and runnable command examples.

---

## Table of Contents

1. Redis Basics
2. Data Structures
3. Persistence (RDB and AOF)
4. Pub/Sub and Streams
5. Transactions and Lua Scripting
6. Replication, Sentinel, and Cluster
7. Memory and Eviction
8. Production Use Cases
9. Distributed Locks
10. Redis vs Memcached
11. Common Gotchas

---

## 1. Redis Basics

## Q1. What is Redis?

**Answer:**

Redis is an in-memory key-value data store. It is single-threaded for command execution but extremely fast (sub-millisecond latency), and it ships with rich data structures (lists, hashes, sets, sorted sets, streams, bitmaps), persistence, replication, clustering, pub/sub, and a scripting engine.

```
SET name "Alice"
GET name
DEL name
```

Note: Redis Inc. relicensed Redis 7.4+ under RSALv2/SSPL. Valkey is the Linux Foundation BSD-licensed fork — the commands and concepts in this guide apply to both.

## Q2. Why is Redis so fast?

**Answer:**

- Everything is in memory; there is no disk on the critical path.
- Command execution is single-threaded, so no locking is needed inside the server.
- Optimized data structure encodings (small lists become listpacks, small sets become intsets).
- Non-blocking I/O multiplexing (epoll, kqueue).
- The network round-trip is often the dominant cost — the server itself often responds in microseconds.

Redis 6 added I/O threads for the network layer, but command processing is still serialized.

## Q3. What is new in modern Redis (7.x)?

**Answer:**

- Functions — server-side libraries, easier to manage than ad-hoc EVAL scripts.
- Sharded pub/sub (`SPUBLISH` / `SSUBSCRIBE`) for cluster scaling.
- ACL v2 with selectors.
- Streams maturity, including improved consumer-group reclaim.
- Multi-part AOF.
- Per-field TTL on hashes (`HEXPIRE`, 7.4+).
- `CLIENT NO-EVICT` and finer eviction tuning.

## Q4. Does single-threaded mean Redis can't scale?

**Answer:**

A single Redis instance scales to roughly 100k-1M ops/sec depending on workload. Beyond that, scale horizontally with Redis Cluster or app-level sharding. Heavy CPU commands such as huge `LRANGE`, `KEYS *`, or long Lua scripts block everything else, so they should be avoided in production.

## Q5. What data types does Redis support?

**Answer:**

| Type | Use cases |
|------|-----------|
| String | Cache values, counters, JSON blobs, bitmaps |
| List | Queues, stacks, recent items |
| Hash | Object fields (user profile) |
| Set | Unique items, tags, set algebra |
| Sorted Set | Leaderboards, time-ordered events, priority queues |
| Bitmap | Compact boolean arrays |
| HyperLogLog | Approximate distinct counts |
| Stream | Append-only log with consumer groups |
| Geo | Geospatial indexing (built on sorted sets) |
| Bitfield | Multiple counters packed in one string |
| JSON (module) | Native JSON via RedisJSON |
| Vector (module) | Vector similarity search via RediSearch |

---

## 2. Data Structures

## Q6. What can a string store?

**Answer:**

Any binary-safe value up to 512 MB. Use it for cache values, integer counters (atomically incremented), serialized JSON, or small binary blobs.

```
SET user:1 "{\"name\":\"Alice\"}"
GET user:1

INCR pageviews:2025-05-05
INCRBY orders:total 199

# Cache with TTL and only-if-not-exists
SET session:abc "user_id=42" EX 1800 NX
SETEX session:abc 1800 "user_id=42"
```

## Q7. How are lists implemented?

**Answer:**

A modern Redis list is a "quicklist" — a linked list of small array nodes (listpacks). Push and pop at either end are O(1).

```
LPUSH queue "job1"
RPUSH queue "job2"
LPOP queue
BRPOP queue 5            # blocking pop, 5-second timeout
LRANGE queue 0 -1        # all elements (avoid on huge lists)
LLEN queue
LTRIM queue 0 99         # keep only the most recent 100 items
```

Common uses are simple FIFO queues and bounded "recent items" lists.

## Q8. When should you use a hash?

**Answer:**

For object-shaped data with multiple small fields. Hashes are very memory-efficient when small (encoded as listpack) and let you update individual fields.

```
HSET user:1 name "Alice" age 30 city "NYC"
HGET user:1 name
HGETALL user:1
HINCRBY user:1 age 1

# Per-field expiry (7.4+)
HEXPIRE user:1 60 FIELDS 1 sessionToken
```

Avoid hashes with millions of fields — `HGETALL` on those is expensive and blocks the server.

## Q9. What are sets used for?

**Answer:**

Unordered collections of unique members. O(1) add, remove, and membership test, plus built-in set algebra.

```
SADD tags:post:1 "redis" "db" "cache"
SISMEMBER tags:post:1 "redis"
SCARD tags:post:1                 # count

SINTER tags:post:1 tags:post:2     # intersection
SDIFF  tags:post:1 tags:post:2     # difference
SUNION tags:post:1 tags:post:2
```

Common uses: tags, "users seen today", friend lists, ACLs.

## Q10. Why are sorted sets so useful?

**Answer:**

A sorted set is a set where every member has a numeric score, and members are kept ordered by score. Add/update/remove are O(log N), and you can query by score or by rank.

```
ZADD leaderboard 1500 "alice" 1800 "bob" 1300 "carol"
ZINCRBY leaderboard 100 "alice"

ZREVRANGE leaderboard 0 9 WITHSCORES         # top 10
ZREVRANK  leaderboard "bob"                  # bob's rank (0-based)
ZRANGEBYSCORE leaderboard 1000 2000          # range by score
```

Common uses: leaderboards, time-series indexes (score = timestamp), priority queues, sliding-window rate limiters.

## Q11. What is a bitmap and when is it useful?

**Answer:**

A string interpreted as an array of bits. Extremely memory-efficient for boolean state.

```
SETBIT users:active:2025-05-05 12345 1
GETBIT users:active:2025-05-05 12345
BITCOUNT users:active:2025-05-05
BITOP AND active:both users:active:2025-05-04 users:active:2025-05-05
```

Tracking 100 million users for one day takes only about 12.5 MB. Great for daily-active tracking and per-user feature flags.

## Q12. What is HyperLogLog?

**Answer:**

A probabilistic data structure that estimates the count of distinct elements with about 1% error using only ~12 KB regardless of cardinality.

```
PFADD visitors:2025-05-05 "user-1" "user-2" "user-1"
PFCOUNT visitors:2025-05-05
PFMERGE visitors:may visitors:2025-05-01 visitors:2025-05-02
```

Use it when you need approximate distinct counts at scale (uniques per minute, uniques per region).

## Q13. When do you use Streams instead of Lists or Pub/Sub?

**Answer:**

A Stream is an append-only log with consumer groups, persistence, message acknowledgment, and replay — closest to a lightweight Kafka.

```
XADD events * type "purchase" userId "42" amount 99
XREAD COUNT 10 STREAMS events 0

# Consumer groups
XGROUP CREATE events processors $ MKSTREAM
XREADGROUP GROUP processors consumer1 COUNT 10 STREAMS events >
XACK events processors 1683216900000-0
XPENDING events processors                   # un-acked messages
XCLAIM events processors consumer2 60000 1683216900000-0
```

| Need | Use |
|------|-----|
| Ephemeral broadcast | Pub/Sub |
| Simple queue, single consumer | List + `BRPOP` |
| Durable queue with multiple consumers, acks, replay | Streams |
| Heavy throughput, multi-region, ordering | Real broker (Kafka) |

## Q14. How do Geo commands work?

**Answer:**

Geo data is stored as a sorted set with geohash scores. You can add points and query by distance or radius.

```
GEOADD places 13.361389 38.115556 "Palermo"
GEOADD places 15.087269 37.502669 "Catania"

GEODIST places "Palermo" "Catania" km
GEOSEARCH places FROMLONLAT 15 37 BYRADIUS 200 km ASC COUNT 10
```

Practical for "find nearby" features without bringing in PostGIS.

## Q15. What do RedisJSON and RediSearch add?

**Answer:**

Optional modules (built into Redis Stack):

- RedisJSON — native JSON values with path operations.
- RediSearch — secondary indexes, full-text search, vector similarity search.

```
JSON.SET user:1 $ '{"name":"Alice","age":30}'
JSON.GET user:1 $.name

FT.CREATE idx:users ON JSON SCHEMA $.name AS name TEXT $.age AS age NUMERIC
FT.SEARCH idx:users "@age:[20 40] alice"
```

---

## 3. Persistence (RDB and AOF)

## Q16. What persistence options does Redis offer?

**Answer:**

| Option | What it does |
|--------|--------------|
| RDB | Periodic point-in-time binary snapshots |
| AOF | Append-only log of every write |
| Both | Recommended for durable workloads |
| None | Pure cache; accept loss |

## Q17. How does RDB work?

**Answer:**

Redis forks a child process; the child writes a snapshot of the dataset to disk while the parent continues serving traffic. Thresholds in the config control when snapshots happen.

```
# redis.conf
save 900 1        # snapshot if 1 key changed in 900 seconds
save 300 10       # snapshot if 10 keys changed in 300 seconds
save 60  10000    # snapshot if 10k keys changed in 60 seconds
```

Pros: compact files, fast restart, ideal for backups.
Cons: data since the last snapshot is lost on a crash. The fork can be expensive on huge datasets.

## Q18. How does AOF work?

**Answer:**

Every write is appended to an on-disk log. On restart, Redis replays the log to rebuild state.

The `appendfsync` policy controls how often the log is fsynced to disk:

| Setting | Behavior |
|---------|----------|
| `always` | fsync on every write — safest, slowest |
| `everysec` | fsync once a second — default; up to 1s loss |
| `no` | let the OS decide — fastest, biggest loss window |

AOF rewrite compacts the log periodically. Redis 7 added multi-part AOF (a base file plus incremental files).

## Q19. RDB or AOF — which should you use in production?

**Answer:**

Use both for durable workloads.

- RDB gives quick restarts and convenient offsite backups.
- AOF (`everysec`) limits crash data loss to about one second.

Redis can replay both at startup; AOF takes precedence for recovery. For pure caches where data loss is acceptable, disable both for maximum performance.

## Q20. Can persistence cause latency spikes?

**Answer:**

Yes. The fork for an RDB snapshot or AOF rewrite stalls the process briefly. With huge memory, the stall can be noticeable. AOF fsyncs on slow disks can also cause write stalls. Disable Transparent Huge Pages on Linux — they amplify fork copy-on-write cost. A common mitigation is to do persistence on a replica and keep the primary RDB-less.

---

## 4. Pub/Sub and Streams

## Q21. How does Pub/Sub work?

**Answer:**

```
# Subscriber
SUBSCRIBE news

# Publisher
PUBLISH news "hello"
```

Pub/Sub is fire-and-forget broadcast. There is no persistence, no replay, and no acknowledgment. If a subscriber is offline when a message is published, it misses the message. Use only for ephemeral notifications such as cache invalidation broadcasts.

## Q22. How does Pub/Sub behave in Redis Cluster?

**Answer:**

Standard `PUBLISH` is broadcast across the entire cluster, which doesn't scale. Redis 7 added sharded pub/sub (`SPUBLISH` / `SSUBSCRIBE`), which routes messages by hash slot like normal keys. For durable messaging at scale, use Streams or a real broker.

## Q23. When should you use Streams vs Pub/Sub vs Lists for queues?

**Answer:**

| Need | Choice |
|------|--------|
| Broadcast, no durability | Pub/Sub |
| Simple FIFO queue, one consumer | List + `BRPOP` |
| Durable queue, parallel consumers, acks, replay | Streams + consumer groups |
| Multi-region, ordering, very high throughput | Real broker (Kafka, NATS) |

---

## 5. Transactions and Lua Scripting

## Q24. Are Redis transactions ACID?

**Answer:**

Partly. `MULTI` / `EXEC` queues commands and runs them atomically — no other client interleaves between them. But:

- There is no rollback. If a command fails mid-transaction, later commands still run.
- Persistence depends on AOF settings.

```
MULTI
INCR a
INCR b
EXEC
```

`WATCH` adds optimistic concurrency:

```
WATCH counter
val = GET counter
MULTI
SET counter (val + 1)
EXEC          # fails if counter changed since WATCH
```

## Q25. Why use Lua scripts?

**Answer:**

For atomic multi-step logic that is hard to express with `MULTI`. The script runs server-side in a single shot, so it eliminates round trips and races.

```lua
-- Atomic "decrement if positive"
local v = tonumber(redis.call("GET", KEYS[1]))
if v and v > 0 then
  redis.call("DECR", KEYS[1])
  return 1
end
return 0
```

```
EVAL "<script>" 1 mykey
```

Keep scripts short — they block all other commands while running.

## Q26. What are Functions and how are they different from scripts?

**Answer:**

Functions (Redis 7) are server-side libraries, loaded once with `FUNCTION LOAD`, replicated to replicas, and persisted across restarts. They are easier to manage than ad-hoc EVAL scripts.

```
FUNCTION LOAD "#!lua name=mylib
redis.register_function('myfn', function(keys, args) ... end)"

FCALL myfn 1 mykey arg1
```

Prefer Functions over `EVAL` for new code.

---

## 6. Replication, Sentinel, and Cluster

## Q27. How does Redis replication work?

**Answer:**

Asynchronous primary-to-replica replication. The replica connects, receives an initial RDB snapshot, then continues streaming write commands.

```
# On the replica
REPLICAOF primary-host 6379

# Promote a replica back to primary
REPLICAOF NO ONE
```

Replicas can serve reads. Failure of a replica does not impact the primary.

## Q28. What is Redis Sentinel?

**Answer:**

A high-availability solution for non-clustered Redis. Sentinels monitor the primary and replicas, perform automatic failover, and act as a service-discovery endpoint for clients. Use at least three Sentinels so they have a quorum. Sentinel handles single-shard HA; for horizontal scale, use Redis Cluster.

## Q29. What is Redis Cluster?

**Answer:**

Built-in horizontal sharding with automatic failover.

- 16384 hash slots are distributed across master nodes.
- Each key hashes to a slot via CRC16.
- Each master has at least one replica.
- On master failure, a replica is promoted automatically (no Sentinel needed).
- Recommended minimum: six nodes (three masters and three replicas).

```
# Hash tag forces multiple keys into the same slot
SET user:{42}:profile "..."
SET user:{42}:settings "..."
# Both keys hash on "42" → same slot → can be in one MULTI / Lua script
```

## Q30. What are the limitations of Redis Cluster?

**Answer:**

- Multi-key operations only work when all keys map to the same slot. Use hash tags `{...}` to group related keys.
- No cross-slot transactions.
- `KEYS` and `SCAN` work per node — clients aggregate results.
- Pub/Sub is broadcast across the cluster (use sharded pub/sub instead).
- Drivers must be cluster-aware.

## Q31. How do clients talk to a cluster?

**Answer:**

A client connects to any node and sends a command. If the node is wrong, the server replies `MOVED <slot> <host:port>`; the client redirects and caches the slot map. During resharding, the server may reply `ASK` for in-flight slot moves. Smart drivers cache the slot map and refresh on `MOVED`.

## Q32. Can you lose acknowledged writes with async replication?

**Answer:**

Yes. By default, replication is asynchronous. If the primary acknowledges a write and crashes before replicating it, the write is lost. Mitigations include `WAIT N timeout` (wait for N replicas), AOF with `appendfsync always` (slow but durable), and application-level idempotency. For strong durability, Redis is not the right tool — use a database.

---

## 7. Memory and Eviction

## Q33. What happens when Redis runs out of memory?

**Answer:**

Behavior depends on `maxmemory-policy`:

| Policy | Behavior |
|--------|----------|
| `noeviction` (default) | Writes fail with an OOM error |
| `allkeys-lru` | Evict the least-recently-used key from any key |
| `volatile-lru` | LRU only among keys with TTL |
| `allkeys-lfu` | Evict the least-frequently-used key (recommended for caches) |
| `volatile-lfu` | LFU among keys with TTL |
| `allkeys-random` | Random eviction |
| `volatile-random` | Random among keys with TTL |
| `volatile-ttl` | Evict the key with the shortest TTL |

```
CONFIG SET maxmemory 8gb
CONFIG SET maxmemory-policy allkeys-lfu
```

## Q34. LRU vs LFU?

**Answer:**

- LRU evicts what hasn't been used recently — vulnerable to scan workloads where a one-time pass over many keys flushes hot keys.
- LFU counts approximate access frequency — resistant to scans and usually gives a better hit rate for typical caches.

Redis LFU uses a logarithmic counter (Morris counter) with decay.

## Q35. How does Redis estimate LRU/LFU efficiently?

**Answer:**

By sampling. Redis picks N random keys (default 5) and evicts the worst one. A larger sample is closer to true LRU/LFU but uses more CPU.

```
CONFIG SET maxmemory-samples 10
```

## Q36. What are some memory optimization tips?

**Answer:**

- Choose the right data structure — small hashes, sets, and sorted sets use compact encodings (listpack, intset).
- Keep keys short (`u:42:p` rather than `users:42:profile`) — saves bytes at scale.
- Inspect encoding with `OBJECT ENCODING <key>`.
- Use `MEMORY USAGE <key>` and `MEMORY DOCTOR` for diagnostics.
- Compress large values at the application layer.

## Q37. How do you size `maxmemory`?

**Answer:**

`maxmemory` is the hard cap on memory Redis uses. Reserve about 25-30% headroom for the replication backlog buffer, fork copy-on-write during RDB/AOF rewrite, client output buffers, and Lua memory. If you set `maxmemory` to total system RAM, the fork can OOM-kill Redis.

---

## 8. Production Use Cases

## Q38. How does cache-aside (lazy loading) work?

**Answer:**

The application checks the cache, falls back to the database on a miss, and populates the cache for next time.

```python
val = redis.get(key)
if val is None:
    val = db.query(...)
    redis.set(key, val, ex=300)
return val
```

Pros: simple, only what's accessed gets cached.
Cons: cache miss penalty, possible thundering herd on hot keys, manual invalidation.

## Q39. What about write-through and write-behind caching?

**Answer:**

- Write-through — every write goes to cache and database synchronously. Cache always fresh; writes are slower.
- Write-behind (write-back) — writes hit the cache immediately and flush to the database asynchronously. Fast writes; data loss risk on crash.

For most read-heavy systems, lazy cache-aside is the simplest and most common.

## Q40. How do you avoid cache stampede?

**Answer:**

When a hot key expires, many clients race to recompute it. Strategies:

- Mutex / lock — first request rebuilds, others wait.
- Probabilistic early expiration (XFetch) — refresh proactively before expiry.
- Stale-while-revalidate — serve stale value while a single async refresh runs.
- Request coalescing in the application.

```python
# Simple lock to serialize rebuilds
if redis.set(f"lock:{key}", "1", nx=True, ex=10):
    val = db.query(...)
    redis.set(key, val, ex=300)
    redis.delete(f"lock:{key}")
```

## Q41. How do you store sessions in Redis?

**Answer:**

```
SET session:abc123 "user_id=42|role=admin" EX 1800
EXPIRE session:abc123 1800            # extend on activity
DEL session:abc123                    # logout
```

Or use a hash for per-field updates:

```
HSET session:abc123 user_id 42 role admin
EXPIRE session:abc123 1800
```

Use replication for HA — losing sessions logs everyone out.

## Q42. How do you implement fixed-window rate limiting?

**Answer:**

Increment a counter keyed by user and current minute, expire after the window.

```
key = "rl:user:42:" + currentMinute
INCR key
EXPIRE key 60 NX
# reject if value > 100
```

Simple but has a boundary effect — 100 requests at 12:59:59 plus 100 at 13:00:00 means 200 requests in two seconds.

## Q43. How do you implement sliding-window log rate limiting?

**Answer:**

Use a sorted set keyed by user, with timestamps as scores. Drop old entries, count current, add new — wrap in Lua for atomicity.

```
now = currentTimeMillis
ZREMRANGEBYSCORE rl:user:42 0 (now - 60000)
ZCARD rl:user:42
ZADD rl:user:42 now <unique-id>
EXPIRE rl:user:42 60
```

More accurate but uses more memory than fixed window.

## Q44. How does token bucket rate limiting work?

**Answer:**

Store the current token count and last refill time in a hash. On each request, refill based on elapsed time, decrement if a token is available, otherwise reject. Implement the read-modify-write atomically with Lua. Token bucket smooths out bursts and is a common production choice.

## Q45. How do you build a leaderboard?

**Answer:**

A sorted set is exactly the right tool.

```
ZADD leaderboard 1500 user:42
ZINCRBY leaderboard 10 user:42

# Top 10
ZREVRANGE leaderboard 0 9 WITHSCORES

# Rank of a specific user
ZREVRANK leaderboard user:42

# Friend leaderboard via set algebra
ZINTERSTORE friends:lb 2 leaderboard friends:user:42
```

Sub-millisecond at any scale.

## Q46. How do you store counters and metrics?

**Answer:**

```
INCR pageviews:2025-05-05
INCRBY revenue:cents:2025-05-05 199
HINCRBY counters:by-product:42 sales 1
```

All atomic. For long-term storage, periodically flush to a time-series database (TimescaleDB, InfluxDB, Prometheus).

## Q47. How do you build a job queue?

**Answer:**

A simple list-based queue:

```
LPUSH jobs '{"type":"send_email","id":1}'
BRPOP jobs 30                          # worker blocks up to 30s
```

To not lose jobs on worker crash, atomically move to a "processing" list:

```
BLMOVE jobs:pending jobs:processing LEFT RIGHT 30
# do the work...
LREM jobs:processing 1 <job-payload>
```

For full features (acks, retries, parallel consumers, replay), use Redis Streams with consumer groups, or an established library like BullMQ, Sidekiq, or RQ.

---

## 9. Distributed Locks

## Q48. How do you build a simple lock?

**Answer:**

`SET key value NX EX seconds` acquires the lock atomically with a TTL. Release safely by checking the value first (with Lua):

```
SET lock:resource <unique-token> NX EX 30
```

```lua
-- Release only if the token matches
if redis.call("GET", KEYS[1]) == ARGV[1] then
  return redis.call("DEL", KEYS[1])
else
  return 0
end
```

The TTL prevents an orphaned lock if the holder crashes.

## Q49. What is the issue with Redis locks?

**Answer:**

A single Redis lock is only as reliable as a single Redis instance. After failover, a freshly promoted replica may not yet have the lock — two clients can believe they hold it.

The Redlock algorithm tries to mitigate this by acquiring the lock on a majority of N independent Redis nodes. Critics (Martin Kleppmann) have argued Redlock isn't safe under clock drift and GC pauses; Redis's author has responded.

Practical guidance: for non-critical mutual exclusion, single-instance Redis with TTL is fine. For correctness-critical work (financial), use a system designed for consensus — etcd, ZooKeeper, or PostgreSQL advisory locks.

## Q50. What is fencing and why do locks need it?

**Answer:**

A fencing token is a monotonically increasing number granted with each lock acquisition. Downstream services check the token before acting and reject older tokens. This protects against stale lock holders that wake up after their TTL has expired.

```
client A: acquires lock, gets fencing token 5
client A: stalls (long GC pause)
TTL expires, client B acquires lock, gets token 6
client B: writes with token 6
client A: wakes up, attempts write with token 5  -> REJECTED
```

Redis doesn't natively provide fencing tokens, but you can build one with `INCR`.

---

## 10. Redis vs Memcached

## Q51. How does Redis compare to Memcached?

**Answer:**

| Concern | Redis | Memcached |
|---------|-------|-----------|
| Data types | Many | Strings only |
| Persistence | RDB + AOF | None |
| Replication | Yes | No (or app-managed) |
| Clustering | Native | App-level / proxy |
| Threading | Single-thread + I/O threads | Multi-threaded |
| Eviction | LRU / LFU / etc. | LRU |
| Pub/Sub, scripting, streams | Yes | No |
| Memory efficiency | Good | Slightly better for raw KV |

For a pure cache at extreme RPS where you don't need anything else, Memcached is leaner. For everything else, Redis.

---

## 11. Common Gotchas

## Q52. Why never run `KEYS *` in production?

**Answer:**

`KEYS` blocks the server while it scans the entire keyspace. On a million-key database, this stalls everything for seconds. Always use `SCAN`, which is cursor-based and incremental.

```
SCAN 0 MATCH "user:*" COUNT 100
# server returns a new cursor; iterate until cursor is 0
```

## Q53. What are big keys and hot keys?

**Answer:**

- A big key is a single key holding a very large value (a list with a million elements). Operations such as `LRANGE` or `DEL` on big keys block the server. Big keys also cause replication and migration stalls.
- A hot key is one key receiving the bulk of traffic — it saturates a single shard and defeats sharding.

Find them with:

```
redis-cli --bigkeys
redis-cli --hotkeys      # 4.0+
MEMORY USAGE <key>
```

Mitigate by splitting big keys (use a sharded hash) and replicating hot keys to multiple shards or to in-process caches.

## Q54. What does `latency-monitor-threshold` do?

**Answer:**

Tracks operations slower than a threshold, with reasons (fork stall, AOF fsync, expired-keys cycle).

```
CONFIG SET latency-monitor-threshold 100   # ms
LATENCY LATEST
LATENCY HISTORY event
LATENCY DOCTOR
```

Essential for diagnosing latency spikes.

## Q55. Is key expiry precise?

**Answer:**

No. Redis uses two strategies:

- Lazy expiration — a key is checked when accessed; if expired, it is deleted and treated as missing.
- Active expiration — a background job samples 20 random keys, deletes any expired, and repeats if more than 25% were expired.

An expired key may persist briefly. For exact timing, track expiration in application logic.

## Q56. How do you size the connection pool?

**Answer:**

Each connection costs memory and a file descriptor. Avoid opening a connection per request — TLS handshakes are expensive. A typical pool size is the number of concurrent application workers times a small multiplier (2-4). Monitor `connected_clients` against `maxclients`.

## Q57. What is the impact of `EXPIRE` on memory?

**Answer:**

A key with a TTL has slightly more overhead because of an extra entry in the expiry dictionary. At normal scales, this is negligible. Massive TTL churn (constantly expiring and replacing keys) does pressure the active-expire cycle. If you see latency, tune `hz` (default 10).

## Q58. What O(N) commands should you avoid?

**Answer:**

| Command | Cost | Alternative |
|---------|------|-------------|
| `KEYS *` | O(N) | `SCAN` |
| `HGETALL` on huge hash | O(N) | `HSCAN` or smaller hashes |
| `LRANGE 0 -1` on huge list | O(N) | Paginate |
| `SMEMBERS` on huge set | O(N) | `SSCAN` |
| `DEL` on huge collection | O(N) | `UNLINK` (async free) |
| `FLUSHDB` / `FLUSHALL` | O(N) sync | `FLUSHDB ASYNC` |

`UNLINK` is the safe `DEL` — it frees memory in the background.

## Q59. What should you know about TLS?

**Answer:**

Redis has supported TLS natively since 6.0. TLS adds CPU and handshake latency, so pool connections wisely. In a cluster, encrypt the cluster bus too with `tls-cluster yes`. Managed services (AWS ElastiCache, Azure Cache, GCP Memorystore, Upstash, Redis Cloud) handle all of this for you.

## Q60. How do you find slow Redis commands?

**Answer:**

The slowlog tracks commands that exceed a threshold.

```
CONFIG SET slowlog-log-slower-than 10000   # microseconds (10 ms)
SLOWLOG GET 100
SLOWLOG RESET
```

Combined with `LATENCY DOCTOR` and `--bigkeys`, this is the standard toolkit for diagnosing performance issues.
