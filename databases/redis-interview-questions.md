# Redis Interview Questions — Basic to Advanced

**Purpose:** Senior-level Redis knowledge for backend / full-stack interviews. Covers data structures, persistence, replication, cluster, eviction, and real production patterns (cache, sessions, rate limiting, queues, leaderboards, locks).

---

## Table of Contents

1. [Redis Basics](#redis-basics)
2. [Data Structures](#data-structures)
3. [Persistence (RDB and AOF)](#persistence-rdb-and-aof)
4. [Pub/Sub and Streams](#pubsub-and-streams)
5. [Transactions and Lua Scripting](#transactions-and-lua-scripting)
6. [Replication, Sentinel, and Cluster](#replication-sentinel-and-cluster)
7. [Memory and Eviction](#memory-and-eviction)
8. [Production Use Cases](#production-use-cases)
9. [Distributed Locks](#distributed-locks)
10. [Redis vs Memcached](#redis-vs-memcached)
11. [Common Gotchas](#common-gotchas)
12. [Real Interview Scenarios](#real-interview-scenarios)

---

## Redis Basics

### Q1. What is Redis?

In-memory key-value data store. Single-threaded for command execution, very fast (sub-millisecond latency), supports rich data structures, persistence, replication, clustering, pub/sub, streams, scripting. Open-source. Recent versions: 7.x. Note: Redis Inc. relicensed Redis 7.4+ to RSALv2/SSPL; **Valkey** is the Linux Foundation BSD-licensed fork.

---

### Q2. Why is Redis so fast?

- Entirely in memory — no disk on the critical path.
- Single-threaded command execution — no lock contention.
- Optimized data structures (e.g., specialized small-list encoding).
- Non-blocking I/O multiplexing (epoll/kqueue).
- Network round-trip is often the dominant cost — Redis itself responds in microseconds.

Redis 6+ added I/O threads (multiple network threads but command execution still serialized).

---

### Q3. What's new in modern Redis (7.x)?

- **Functions** (server-side libraries, replacing scripts for some uses).
- **Sharded pub/sub** (`SPUBLISH`, `SSUBSCRIBE`) for cluster.
- **ACL v2** with selectors.
- **Streams** maturity, consumer-group reclaim improvements.
- **Multi-part AOF**.
- **`CLIENT NO-EVICT`** and finer eviction tuning.
- **`OBJECT FREQ`** for LFU debugging.
- **`HEXPIRE`** family in 7.4 — TTL on individual hash fields.

---

### Q4. Redis is single-threaded — does that limit throughput?

Yes for CPU-bound work. A single Redis instance scales to ~100k-1M ops/sec depending on workload. Beyond that, you scale horizontally with **Redis Cluster** or by sharding at the app level.

I/O threads (6+) help with network-bound workloads. Heavy CPU commands (huge `LRANGE`, `KEYS *`, big Lua scripts) block everything else.

---

### Q5. What data types does Redis support?

| Type | Use cases |
|------|-----------|
| String | Cache, counters, JSON blobs, bitmaps, HyperLogLog |
| List | Queues, stacks, recent items |
| Hash | Object fields (user profile) |
| Set | Unique items, tags, set algebra |
| Sorted Set (ZSet) | Leaderboards, time-ordered events, priority queues |
| Bitmap | Compact boolean arrays (presence, A/B flags) |
| HyperLogLog | Approximate distinct counts at huge scale |
| Stream | Append-only log, consumer groups |
| Geo | Geospatial indexing (built on sorted sets) |
| Bitfield | Multi-bit counters in one string |
| JSON (module) | Native JSON via RedisJSON / Valkey-JSON |
| Vector (module) | Vector similarity search (RediSearch) |

---

## Data Structures

### Q6. Strings — what can they store?

Anything binary-safe up to **512 MB**. Cache values, integers (atomically incremented), serialized JSON, raw bytes (images small enough), bitmaps.

```
SET user:1 "{\"name\":\"Alice\"}"
GET user:1

INCR pageviews:2025-05-05
INCRBY orders:total 199

SETEX session:abc 1800 "user_id=42"   # with TTL
SET key val EX 60 NX                    # set if not exists, 60s TTL
```

---

### Q7. Lists — how are they implemented?

Doubly-linked list (older) / quicklist (modern: linked list of ziplists/listpacks). Push/pop at either end is O(1).

```
LPUSH queue "job1"
RPUSH queue "job2"
LPOP queue
BRPOP queue 5            # blocking pop with 5s timeout
LRANGE queue 0 -1        # all elements (avoid on huge lists)
LLEN queue
```

Use cases: simple queue, recent items list (cap with `LTRIM`).

---

### Q8. Hashes — when to use?

For storing object-like data with many small fields. Memory-efficient when small (encoded as listpack). Field-level operations.

```
HSET user:1 name "Alice" age 30 city "NYC"
HGET user:1 name
HGETALL user:1
HINCRBY user:1 age 1

# Redis 7.4: per-field expiry
HEXPIRE user:1 60 FIELDS 1 sessionToken
```

Avoid huge hashes (millions of fields) — `HGETALL` becomes expensive and blocks.

---

### Q9. Sets — what are they good for?

Unordered, unique members. O(1) add/remove/test. Built-in set algebra.

```
SADD tags:post:1 "redis" "db" "cache"
SISMEMBER tags:post:1 "redis"
SINTER tags:post:1 tags:post:2     # intersection
SDIFF  tags:post:1 tags:post:2     # difference
SUNION tags:post:1 tags:post:2
SCARD tags:post:1                  # count
```

Use cases: tags, unique-visitors-today, friend lists, ACLs.

---

### Q10. Sorted sets — why are they so useful?

Sets where every member has a score; kept sorted by score. O(log N) add/update/remove. Range queries by score or rank.

```
ZADD leaderboard 1500 "alice" 1800 "bob" 1300 "carol"
ZINCRBY leaderboard 100 "alice"
ZREVRANGE leaderboard 0 9 WITHSCORES         # top 10
ZREVRANK leaderboard "bob"                    # bob's rank
ZRANGEBYSCORE leaderboard 1000 2000           # range by score
ZRANGEBYLEX  alphabet "[a" "[m"               # range by lex when scores equal
```

Use cases: leaderboards, time-series indexes (score = timestamp), priority queues, throttling windows.

---

### Q11. Bitmaps?

Strings interpreted as bit arrays. Massive memory efficiency for boolean state.

```
SETBIT users:active:2025-05-05 12345 1
GETBIT users:active:2025-05-05 12345
BITCOUNT users:active:2025-05-05         # how many active users
BITOP AND ... ...                         # set algebra over days
```

Tracking 100M users for one day = 12.5 MB. Excellent for daily-active tracking, feature flags by user id.

---

### Q12. HyperLogLog?

Probabilistic data structure for counting distinct elements. ~12 KB per HLL gives <1% error for billions of distinct values.

```
PFADD visitors:2025-05-05 "user-1" "user-2" "user-1"
PFCOUNT visitors:2025-05-05
PFMERGE visitors:may 2025-05-01 2025-05-02 ... 2025-05-31
```

Use when you need approximate distinct count (uniques per minute), not exact membership.

---

### Q13. Streams — when use them over lists or pub/sub?

Append-only log with consumer groups, persistence, message acknowledgement, replay.

```
XADD events * type "purchase" userId "42" amount 99
XREAD COUNT 10 STREAMS events 0          # read from start

# Consumer groups (like Kafka)
XGROUP CREATE events processors $ MKSTREAM
XREADGROUP GROUP processors consumer1 COUNT 10 STREAMS events >
XACK events processors <id>
XPENDING events processors                # unacked messages
XCLAIM events processors consumer2 60000 <id>   # take over from dead consumer
```

Versus:
- **Pub/Sub**: fire-and-forget, no persistence, no replay.
- **Lists**: simpler queue but no consumer groups, no acks.
- **Streams**: durable, replayable, parallel consumers — closest to a lightweight Kafka.

---

### Q14. Geo commands?

Stored as sorted sets with geohash scores.

```
GEOADD places 13.361389 38.115556 "Palermo" 15.087269 37.502669 "Catania"
GEODIST places "Palermo" "Catania" km
GEOSEARCH places FROMLONLAT 15 37 BYRADIUS 200 km ASC COUNT 10
```

Practical for "find nearby" features without pulling in PostGIS.

---

### Q15. RedisJSON and RediSearch — what do they add?

Modules (or built-in in Redis Stack):
- **RedisJSON**: native JSON values with path operations (`JSON.SET`, `JSON.GET`, `JSON.ARRAPPEND`).
- **RediSearch**: secondary indexes, full-text search, vector similarity search.

```
JSON.SET user:1 $ '{"name":"Alice","age":30}'
JSON.GET user:1 $.name

FT.CREATE idx:users ON JSON SCHEMA $.name AS name TEXT $.age AS age NUMERIC
FT.SEARCH idx:users "@age:[20 40] alice"
```

Useful for caching JSON without round-tripping serialization, and for in-memory search/vector workloads.

---

## Persistence (RDB and AOF)

### Q16. What persistence options does Redis offer?

| Option | What |
|--------|------|
| RDB | Periodic point-in-time snapshots (binary file) |
| AOF | Append-only log of every write |
| Both (recommended) | RDB for backups, AOF for low data loss |
| None | Pure cache, accept loss |

---

### Q17. How does RDB work?

Fork a child process; the child writes the dataset to disk while the parent serves traffic. Tunable thresholds:

```
save 900 1        # snapshot if 1 key changed in 900s
save 300 10       # snapshot if 10 keys changed in 300s
save 60  10000    # snapshot if 10k keys changed in 60s
```

**Pros:** compact, fast restart, great for backups.
**Cons:** data since the last snapshot is lost on crash. Fork can be expensive on huge datasets (memory copy-on-write).

---

### Q18. How does AOF work?

Every write is appended to an on-disk log. On restart, Redis replays the log.

`appendfsync` policies:
- `always` — fsync after every write (safest, slowest).
- `everysec` — fsync once a second (default; ≤1s data loss).
- `no` — let the OS decide (fastest, biggest loss window).

AOF rewrite compacts the file periodically. Redis 7 introduced **multi-part AOF** (base file + incremental files).

---

### Q19. RDB vs AOF — which to use in production?

**Both, usually.**
- RDB for quick restart and offsite backups.
- AOF (`everysec`) for crash durability.

Redis can replay both on startup; AOF takes precedence for recovery.

For pure caches where data loss is fine, disable both for max performance.

---

### Q20. Can persistence cause latency spikes?

Yes:
- **fork** for RDB or AOF rewrite stalls the process briefly. With huge memory, this can be noticeable.
- AOF `fsync` on slow disk causes write stalls.
- Disable Transparent Huge Pages on Linux — they amplify fork copy-on-write cost.

Mitigations: replicate to a secondary that handles persistence (the primary can run RDB-less); use fast SSD; tune `aof-use-rdb-preamble`.

---

## Pub/Sub and Streams

### Q21. How does Pub/Sub work?

```
# Subscriber
SUBSCRIBE news

# Publisher
PUBLISH news "hello"
```

Fire-and-forget broadcast. **No persistence, no replay, no acks.** If a subscriber is offline, it misses messages. Use only for ephemeral notifications (cache invalidation broadcasts, "new event" pings).

---

### Q22. Pub/Sub in Redis Cluster?

Standard `PUBLISH` replicates across the cluster (broadcast). For scale, **sharded pub/sub** (`SPUBLISH`/`SSUBSCRIBE`, Redis 7) keys messages to specific shards.

For real durable messaging at scale, use Streams or a real broker (Kafka, NATS).

---

### Q23. When to use Streams vs Pub/Sub vs Lists for queues?

| Need | Use |
|------|-----|
| Broadcast, no durability | Pub/Sub |
| Simple FIFO/LIFO queue, single consumer | List + `BRPOP` |
| Durable queue, multiple consumers, acks, replay | Streams + consumer groups |
| Heavy throughput, ordering, multi-region | Real broker (Kafka, etc.) |

---

## Transactions and Lua Scripting

### Q24. Are Redis transactions ACID?

Sort of. `MULTI`/`EXEC` queues commands and runs them atomically (no other client interleaves). But:
- **No rollback** — if a command fails mid-transaction, the rest still execute.
- **No isolation level negotiation** — single-threaded execution gives serialized isolation.
- **Persistence depends on AOF settings.**

```
MULTI
INCR a
INCR b
EXEC
```

Add `WATCH` for optimistic concurrency:

```
WATCH counter
val = GET counter
MULTI
SET counter (val + 1)
EXEC          # fails if counter changed since WATCH
```

---

### Q25. Why use Lua scripts?

- Atomic multi-step logic (better than MULTI for conditional flows).
- Fewer round trips (script runs server-side).
- Reusable via `EVALSHA` with cached SHA.

```lua
-- Atomic "decrement-if-positive"
local v = tonumber(redis.call('GET', KEYS[1]))
if v and v > 0 then
  redis.call('DECR', KEYS[1])
  return 1
end
return 0
```

```
EVAL "<script>" 1 mykey
```

**Caution:** scripts run inline, blocking everything. Keep them short. Long scripts trigger `lua-time-limit`.

---

### Q26. Functions vs scripts (Redis 7)?

Redis Functions are server-side libraries (loaded once with `FUNCTION LOAD`), more maintainable than ad-hoc scripts. Replicate to replicas, persist in RDB/AOF, can be versioned.

```
FUNCTION LOAD "#!lua name=mylib\n redis.register_function('myfn', function(keys, args) ... end)"
FCALL myfn 1 mykey arg1
```

For new code, prefer Functions over `EVAL`.

---

## Replication, Sentinel, and Cluster

### Q27. How does Redis replication work?

Asynchronous primary → replica replication. Replica connects, runs initial sync (RDB snapshot from primary, then continues streaming write commands).

```
# On replica
REPLICAOF primary-host 6379
```

**Properties:**
- Async — replicas can lag.
- Replicas can serve reads (`READONLY` in cluster).
- Failure of replica doesn't impact primary.

---

### Q28. What is Redis Sentinel?

HA solution for non-clustered Redis. Sentinels monitor the primary and replicas, perform automatic failover, and act as a service-discovery endpoint for clients.

- Need at least 3 Sentinels (quorum).
- On primary failure, Sentinels elect a replica as the new primary.
- Clients query Sentinel for the current primary address.

Sentinel is for **single-shard HA**. For horizontal scale, use Cluster.

---

### Q29. What is Redis Cluster?

Built-in horizontal sharding with automatic failover.

- 16384 hash slots distributed across master nodes.
- Key → CRC16 → slot → node.
- Each master has 1+ replicas.
- On master failure, replica is promoted (no Sentinel needed).
- Recommended minimum: **6 nodes** (3 masters + 3 replicas).

```
# Key with hash tag — forces same slot
SET user:{42}:profile "..."
SET user:{42}:settings "..."
# Both keys hash on "42" → same slot → can be in same multi-key op
```

---

### Q30. Limitations of Redis Cluster?

- Multi-key operations only work if all keys map to the same slot (use **hash tags** `{...}`).
- No cross-slot transactions.
- `KEYS`, `SCAN` work per-node — clients must aggregate.
- Pub/Sub is broadcast across cluster (use sharded pub/sub).
- Driver must be cluster-aware.

---

### Q31. How do clients talk to a cluster?

- Client connects to any node, sends a command.
- If wrong node, server replies `MOVED <slot> <host:port>`.
- Client redirects (and caches the slot map).
- During resharding, server may reply `ASK` for in-flight slot moves.

Smart drivers cache the slot map and refresh on `MOVED`.

---

### Q32. Async replication risk — can you lose acked writes?

Yes. Default replication is async. If the primary acks a write and crashes before replicating, the write is lost.

Mitigations:
- `WAIT N timeout` — block until N replicas ack (still not synchronous).
- Use AOF with `appendfsync always` (slow but durable).
- Application-level idempotency.
- For strongly durable storage, Redis isn't the right tool — use a database.

---

## Memory and Eviction

### Q33. What happens when Redis runs out of memory?

Depends on `maxmemory-policy`:

| Policy | Behavior |
|--------|----------|
| `noeviction` (default) | Writes fail with OOM error |
| `allkeys-lru` | Evict least-recently-used across all keys |
| `volatile-lru` | LRU only among keys with TTL |
| `allkeys-lfu` | Least-frequently-used (Redis 4+) |
| `volatile-lfu` | LFU among keys with TTL |
| `allkeys-random` | Random eviction |
| `volatile-random` | Random among keys with TTL |
| `volatile-ttl` | Evict shortest-TTL first |

For caches: `allkeys-lfu` is typically best (frequency-aware).

---

### Q34. LRU vs LFU?

- **LRU** evicts what hasn't been used recently — vulnerable to scan workloads (a one-time scan flushes hot keys).
- **LFU** counts approximate access frequency — resistant to scans, better hit rate for typical caches.

Redis LFU uses a logarithmic counter (Morris counter) — efficient, with decay.

---

### Q35. How does Redis estimate LRU/LFU efficiently?

Sampling. Redis picks N random keys (configurable, default 5) and evicts the worst. Bigger sample → closer to true LRU/LFU, more CPU.

```
maxmemory-samples 10
```

---

### Q36. Memory optimization tips?

- Use the right data structure (small hashes, sets, sorted sets are stored as listpacks — very compact).
- Keep keys short (`u:42:p` vs `users:42:profile`) — saves bytes at scale.
- Use `OBJECT ENCODING <key>` to verify compact encoding (`listpack`, `intset`, `embstr`).
- Keys are stored in the global keyspace dictionary; many short keys still cost overhead.
- Use `MEMORY USAGE <key>` to inspect.
- Run `MEMORY DOCTOR` for diagnostics.
- Avoid huge values — compress (zstd/snappy) at the app or use RedisJSON for structured data.

---

### Q37. What is `maxmemory` and how do you size it?

Hard cap on memory Redis will use. Reserve ~25-30% headroom for:
- Replication backlog buffer.
- Fork copy-on-write during RDB/AOF rewrite.
- Client output buffers.
- Lua script memory.

If you set `maxmemory` to total RAM, fork can OOM-kill Redis.

---

## Production Use Cases

### Q38. Caching pattern — cache-aside (lazy loading)?

```
val = redis.get(key)
if val is None:
    val = db.query(...)
    redis.set(key, val, ex=300)
return val
```

**Pros:** simple, only what's accessed is cached.
**Cons:** cache miss penalty; stale data unless invalidated; thundering herd on popular keys.

---

### Q39. Write-through and write-behind caching?

- **Write-through:** every write goes to cache and DB synchronously. Cache always fresh; writes slower.
- **Write-behind (write-back):** writes to cache immediately, flush to DB asynchronously. Fast writes; data loss risk on crash.

Lazy cache-aside is the most common for read-heavy systems.

---

### Q40. How do you avoid cache stampede?

When a hot key expires and many clients race to recompute:

- **Mutex / lock:** first request rebuilds, others wait.
- **Probabilistic early expiration:** refresh proactively before expiry (XFetch algorithm).
- **Stale-while-revalidate:** return stale value while async refresh happens.
- **Request coalescing** at the app layer.

---

### Q41. Session storage in Redis?

```
SET session:abc123 "user_id=42|role=admin" EX 1800
EXPIRE session:abc123 1800            # extend on activity
DEL session:abc123                    # logout
```

Or hash for per-field updates:

```
HSET session:abc123 user_id 42 role admin
HEXPIRE session:abc123 1800 FIELDS 1 user_id   # 7.4+ per-field TTL
```

Use replication for HA — losing sessions logs everyone out.

---

### Q42. Rate limiting — fixed window?

```
key = "rl:user:42:" + currentMinute
n = INCR key
EXPIRE key 60 NX
if n > 100: reject
```

Simple, but boundary effect: 100 requests at 12:59:59 + 100 at 13:00:00 = 200 in 2 seconds.

---

### Q43. Rate limiting — sliding window log?

```
now = currentTimeMillis
ZREMRANGEBYSCORE rl:user:42 0 (now - 60000)     # drop old
ZCARD rl:user:42                                # current count
ZADD rl:user:42 now <unique-id>
EXPIRE rl:user:42 60
```

Wrap in Lua for atomicity. Accurate but more memory-intensive.

---

### Q44. Rate limiting — token bucket?

State (`tokens`, `lastRefill`) in a hash, updated atomically via Lua. Smooth bursts. Common production choice.

---

### Q45. Leaderboards?

```
ZADD leaderboard 1500 user:42
ZINCRBY leaderboard 10 user:42

# Top 10
ZREVRANGE leaderboard 0 9 WITHSCORES

# User's rank
ZREVRANK leaderboard user:42

# Friend leaderboard (set algebra)
ZINTERSTORE friends:lb 2 leaderboard friends:user:42
```

Sub-millisecond at any scale. Default rank is 0-based.

---

### Q46. Counter / metrics?

```
INCR pageviews:2025-05-05
INCRBY revenue:cents:2025-05-05 199
HINCRBY counters:by-product:42 sales 1
```

Atomic. Combine with periodic flush to a time-series DB (InfluxDB, TimescaleDB, Prometheus pushgateway).

---

### Q47. Job queues?

Simple list-based:

```
LPUSH jobs '{"type":"send_email","id":1}'
BRPOP jobs 30                          # worker blocks for up to 30s
```

For reliability (don't lose jobs on worker crash):

```
# atomic move from queue to processing list
BLMOVE jobs:pending jobs:processing LEFT RIGHT 30
# on success
LREM jobs:processing 1 <job>
```

For full features (acks, retries, parallel consumers, replay): **Redis Streams** with consumer groups, or libraries like BullMQ (Node) / Sidekiq (Ruby) / RQ (Python).

---

## Distributed Locks

### Q48. How do you build a simple lock?

```
SET lock:resource <unique-token> NX EX 30
```

Acquire if not set, with TTL to avoid orphaned locks. Release safely (don't delete someone else's lock):

```lua
-- Lua: delete only if value matches
if redis.call("GET", KEYS[1]) == ARGV[1] then
  return redis.call("DEL", KEYS[1])
else
  return 0
end
```

---

### Q49. What's the issue with Redis locks?

Single-instance Redis: lock is fine until the node fails. After failover, an unsynced replica might not have the lock — two clients could both believe they hold it.

**Redlock** (the multi-instance algorithm) attempts to mitigate: acquire the lock on a majority of N independent Redis nodes, only succeed if you own >N/2.

**Redlock controversy:** Martin Kleppmann argued Redlock isn't safe under clock drift / GC pause assumptions; Antirez (Redis author) responded. **Practical guidance:** for non-critical locks, single-instance Redis with TTL is fine. For correctness-critical locks (financial), use a system designed for consensus (etcd, ZooKeeper, Postgres advisory locks).

---

### Q50. What is fencing? Why do locks need it?

A monotonic token granted with each lock acquisition. Downstream services check the token before acting; reject older tokens.

```
client A: acquires lock, gets fencing token 5
client A: stalls (GC pause)
client A's lease expires → client B acquires lock, gets token 6
client B: writes with token 6
client A: wakes up, attempts write with token 5 → REJECTED
```

Without fencing, stale lock holders can corrupt data despite TTL. Redis doesn't natively provide fencing tokens (you can build one with `INCR`).

---

## Redis vs Memcached

### Q51. Comparison

| Concern | Redis | Memcached |
|---------|-------|-----------|
| Data types | Many | Strings only |
| Persistence | RDB + AOF | None |
| Replication | Yes | No (or via app) |
| Clustering | Native | App-level / proxy |
| Threading | Single-thread + I/O threads | Multi-threaded |
| Eviction | LRU/LFU/etc. | LRU |
| Pub/Sub, scripting, streams | Yes | No |
| Memory efficiency | Good | Slightly better for raw KV |
| Use case | Cache + data structures + queues + lock | Pure cache |

For pure cache at extreme RPS where you don't need anything else, Memcached is leaner. For everything else, Redis.

---

## Common Gotchas

### Q52. `KEYS *` — why never in production?

`KEYS` blocks the server while it scans the entire keyspace. On a million-key DB, this stalls everything for seconds.

**Always use `SCAN`** (cursor-based, incremental).

```
SCAN 0 MATCH "user:*" COUNT 100
```

---

### Q53. Big keys / hot keys?

**Big keys** (e.g., a list with 1M elements) cause:
- Slow operations (`LRANGE`, `DEL` on big keys blocks).
- Replication / migration stalls during cluster resharding.
- Memory imbalance across cluster shards.

**Hot keys** (one key getting 90% of traffic) saturate a single shard, defeat sharding.

Find them: `redis-cli --bigkeys`, `redis-cli --hotkeys` (4.0+), `MEMORY USAGE`.

Mitigate: split big keys (sharded hash), cache hot keys in app memory or replicate to multiple cluster nodes.

---

### Q54. What does `latency-monitor-threshold` do?

```
CONFIG SET latency-monitor-threshold 100   # ms
LATENCY LATEST
LATENCY HISTORY event
```

Tracks operations slower than the threshold, with reasons (fork, AOF fsync, expired keys cycle, etc.). Essential for diagnosing latency spikes.

---

### Q55. Expiry — is it precise?

No. Redis uses two strategies:
- **Lazy expiration:** key checked on access; if expired, removed and treated as missing.
- **Active expiration:** background job samples 20 random keys; deletes any expired; repeats if >25% were expired.

Result: an expired key may persist briefly. For exact timing, don't rely on Redis expiry — track expiration in app logic if needed.

---

### Q56. Connection pool sizing?

Each connection costs memory and a file descriptor. Avoid per-request connections (TLS handshake is expensive).

Typical: pool size = number of concurrent app workers × small multiplier (2-4). Monitor `connected_clients` and `tracking_clients`. Cap at `maxclients`.

---

### Q57. What's the impact of `EXPIRE` on memory?

A key with TTL has slightly more overhead (extra dict entry for expiry). At scale, millions of TTL keys still fit comfortably — TTL doesn't bloat much.

But **massive TTL churn** (constantly expiring/replacing keys) puts pressure on the active-expire cycle. If you see latency, tune `hz` (default 10 hz expire scan).

---

### Q58. `O(N)` commands to avoid?

| Command | Cost | Alternative |
|---------|------|-------------|
| `KEYS *` | O(N) | `SCAN` |
| `HGETALL` huge hash | O(N) | `HSCAN`, smaller hashes |
| `LRANGE 0 -1` huge list | O(N) | Paginate with offsets |
| `SMEMBERS` huge set | O(N) | `SSCAN` |
| `DEL` huge collection | O(N) | `UNLINK` (async free, 4.0+) |
| `FLUSHDB`/`FLUSHALL` | O(N) sync | `FLUSHDB ASYNC` |

`UNLINK` is the safe `DEL`.

---

### Q59. TLS — what should I know?

- Redis supports TLS natively since 6.0.
- Adds CPU + handshake latency; pool wisely.
- Cluster bus traffic should also be TLS (`tls-cluster yes`).
- Managed services (AWS ElastiCache, Azure Cache, GCP Memorystore, Upstash, Redis Cloud) handle this.

---

## Real Interview Scenarios

### Scenario 1: "Cache hit ratio dropped from 95% to 60%."

**Diagnosis:**
1. `INFO stats` → check `keyspace_hits` vs `keyspace_misses`.
2. `INFO memory` → memory near `maxmemory`?
3. Eviction policy: are evictions happening (`evicted_keys`)?
4. Did key cardinality explode? New traffic source spamming unique keys?
5. TTL changed, keys expiring faster?

**Fixes:**
- Increase `maxmemory` or scale out cluster.
- Switch to `allkeys-lfu` if scans are evicting hot keys.
- Cache the right granularity (don't cache things that are unique per request).

---

### Scenario 2: "Random p99 latency spikes every few minutes."

**Likely causes:**
- AOF rewrite or RDB snapshot — fork stall on big memory.
- Slow query (`SLOWLOG GET`).
- Big key operations.
- Network issues.
- Disk fsync stalls.

**Diagnose:**
- `SLOWLOG GET 100`
- `LATENCY LATEST`, `LATENCY DOCTOR`
- `INFO persistence` for last fork time

**Mitigation:** offload persistence to a replica, disable THP, faster disk.

---

### Scenario 3: "A worker pulls jobs but sometimes loses them on crash."

**Cause:** `RPOP/LPOP` removes the job before processing. Crash mid-process → job gone.

**Fix:** atomic move to a "processing" list with `BLMOVE` / `LMOVE`. Workers also recover stale jobs from "processing" by inspecting timestamps. Or use **Streams + consumer groups** which give acks (`XACK`) and reclaim (`XCLAIM`) natively.

---

### Scenario 4: "We need a global rate limit — 1000 req/s across 50 app servers."

**Approach:** centralize counter in Redis. Sliding window log or token bucket via Lua script for atomicity. Make sure the Lua script:
- Reads current state.
- Computes whether the request is allowed.
- Updates state.
- Returns allow/deny.

Pin the rate-limit key to a single cluster slot per dimension. Avoid scatter-gather.

---

### Scenario 5: "Our cluster has unbalanced shards."

**Cause:** hot keys, hash tag overuse (`{tenant1}` everywhere → all keys land on one slot), or a few huge keys.

**Diagnose:**
- `CLUSTER COUNTKEYSINSLOT <slot>` for each slot.
- `redis-cli --bigkeys`, `redis-cli --hotkeys`.

**Fix:** rebalance with `CLUSTER RESHARD`, redesign hash tags so they actually distribute, split big keys.

---

### Scenario 6: "Cache invalidation across multiple regions."

**Approach options:**
- **Pub/Sub on a control channel:** when DB changes, publish; all regional Redis subscribers invalidate. Simple, lossy.
- **Streams with consumer per region:** durable, replayable.
- **Active-active Redis (CRDT-based, Redis Enterprise):** geo-distributed with conflict resolution.
- **Versioned keys:** include a version/epoch in the key; bump version to invalidate.

---

### Scenario 7: "Should we cache the entire user object or per-field?"

**Tradeoffs:**
- Single string (JSON): one round-trip, simple, but read-modify-write requires whole-object replacement.
- Hash: per-field updates, smaller diffs, slightly more memory overhead at very small sizes.
- Hash wins if you frequently update one field of a many-field object.
- JSON via RedisJSON if you need path operations.

---

## Senior Redis Mantra

1. **Right data structure beats clever algorithms.** Sorted sets, bitmaps, HLL, and streams cover surprising amounts of ground.
2. **Single-threaded — don't run O(N) commands on production.** SCAN, UNLINK, paginate.
3. **AOF + RDB for durable workloads, neither for pure cache.**
4. **Cluster needs hash tags for multi-key operations.** Plan key naming.
5. **Replication is async — don't treat Redis as a system of record.**
6. **`allkeys-lfu` is usually the best eviction policy for caches.**
7. **Big keys and hot keys destroy clusters. Hunt them with `--bigkeys` / `--hotkeys`.**
8. **Lua / Functions for atomic multi-step logic. Keep them short.**
9. **Streams beat lists for any queue that matters.**
10. **For correctness-critical locks, Redis is not enough — fencing or a consensus system.**
