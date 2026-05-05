# System Design Interview Questions and Answers

A complete pedagogical guide to system design. Each question explains the concept in plain language and pairs it with a working example: a diagram, a schema, a snippet, or a back-of-envelope calculation.

---

## How to Use This Guide

Read each section in order. Foundational concepts (CAP, sharding, caching, consistency) appear before the design exercises. The design questions later in the guide assume you've internalized the building blocks.

---

## 1. How to Approach a System Design Interview

## Q1. What's the structure of a 45-60 minute system design interview?

**Answer:**

A typical interview follows five phases:

1. **Clarify** (5 min): ask about scale, features, constraints.
2. **High-level design** (10 min): boxes and arrows, the major components.
3. **API and data model** (10 min): the contract and the schemas.
4. **Deep dive** (15 min): pick one or two hot areas and design them in detail.
5. **Trade-offs and scaling** (10 min): what breaks at 10x, what you'd change.

The interviewer cares about your reasoning more than the "right" answer.

## Q2. What questions should you ask up front?

**Answer:**

Before you draw anything:

- **Functional**: what features matter for this design? What's out of scope?
- **Scale**: DAU/MAU? Reads/writes per second? Data size? Growth rate?
- **Latency**: p99 budget?
- **Consistency**: read-your-writes? Eventual? Strong?
- **Geography**: single region or global?
- **SLA**: 99.9? 99.99?

Example for a Twitter feed:

```text
- 200M DAU, average 100 tweets read per day, 5 tweets posted per day.
- Read-heavy; reads are 20:1 over writes.
- Eventual consistency on the feed is fine.
- p99 latency 200ms.
- Multi-region.
```

## Q3. How do you estimate capacity quickly?

**Answer:**

Approximate everything to powers of 10. Common conversions:

```text
1 million seconds ≈ 12 days
1 day ≈ 86,400 seconds ≈ 10^5 seconds
QPS = daily requests / 10^5
```

For 200M users posting 5 tweets/day: 1B tweets/day. QPS = 1B / 10^5 = 10K writes/sec average, peak ~30K. Reads at 20:1 = 200K-600K reads/sec.

## Q4. What does a "deep dive" look like?

**Answer:**

Pick the most interesting part of your design and zoom in:

- Detail the data model (tables, indexes, partitioning).
- Walk through one request end-to-end.
- Identify the bottleneck.
- Propose a fix and discuss trade-offs.

A great interviewee notices their own bottleneck and addresses it before being asked.

## Q5. What trade-offs should you always discuss?

**Answer:**

- Consistency vs availability (CAP).
- Latency vs throughput.
- Read-optimized vs write-optimized data model.
- Cost vs performance.
- Complexity vs operational simplicity.

Every design choice is a trade-off; naming them shows seniority.

---

## 2. Foundational Concepts

## Q6. Explain the CAP theorem.

**Answer:**

CAP says that in a distributed system you can have at most two of:

- **Consistency**: every read sees the latest write.
- **Availability**: every request gets a response.
- **Partition tolerance**: the system keeps working despite network splits.

Network partitions happen, so you must tolerate them. The real choice is between **CP** (refuse requests during a partition to stay consistent) and **AP** (accept requests during a partition, reconcile later).

```text
Network partition between [DC-1] and [DC-2]:

CP system: one side refuses writes (e.g. MongoDB primary unreachable -> error).
AP system: both sides accept writes; reconciled when partition heals (e.g. Cassandra).
```

## Q7. What is PACELC?

**Answer:**

CAP only describes behavior during a partition. PACELC extends it: in case of **P**artition, choose **A** or **C**; **E**lse (no partition), choose **L**atency or **C**onsistency.

```text
- DynamoDB: PA/EL  (during partition: available; normally: low latency)
- HBase:    PC/EC  (always consistency)
```

PACELC reflects the daily-life trade-off, not just the rare partition.

## Q8. ACID and BASE?

**Answer:**

| | ACID (relational) | BASE (NoSQL-style) |
| --- | --- | --- |
| Consistency | Strong, transactional | Eventual |
| Availability | Lower priority | First priority |
| Use case | Financial, inventory | High-scale reads/writes |

ACID = Atomicity, Consistency, Isolation, Durability. BASE = Basically Available, Soft state, Eventual consistency.

## Q9. SQL vs NoSQL — when which?

**Answer:**

| Need | Choose |
| --- | --- |
| Complex joins, transactions | SQL (Postgres, MySQL) |
| Flexible schema, document-based | Document DB (MongoDB) |
| Time series | Time series DB (TimescaleDB, InfluxDB) |
| Wide-column with massive write throughput | Cassandra, ScyllaDB |
| Key-value at low latency | Redis, DynamoDB |
| Graph traversal | Neo4j, Neptune |

SQL is usually the right default. Reach for NoSQL only when the workload clearly demands it.

## Q10. Strong vs eventual vs causal consistency?

**Answer:**

- **Strong**: after a write completes, every subsequent read returns it.
- **Eventual**: reads will return the latest value eventually.
- **Causal**: if A happened before B, every node that sees B also sees A.

```text
Eventual: User posts 'X', friend immediately refreshes, may not see 'X'.
Causal:   If you see "Bob replied to Alice's post", you must also see Alice's post.
```

Most social systems are eventually consistent. Banking is strong. Causal is a useful middle ground.

---

## 3. Capacity Estimation Cheatsheet

## Q11. What numbers should you have memorized?

**Answer:**

```text
Latency:
  L1 cache:               1 ns
  L2 cache:               7 ns
  RAM access:           100 ns
  SSD random read:       100,000 ns (100 us)
  Network round-trip in DC: 500,000 ns (0.5 ms)
  HDD seek:           10,000,000 ns (10 ms)
  Cross-continent:    150,000,000 ns (150 ms)

Throughput:
  HDD sequential:    100 MB/s
  SSD sequential:    500 MB/s - 3 GB/s
  Gigabit network:   125 MB/s
  10 Gbps network:   1.25 GB/s

Sizes:
  KB = 10^3,  MB = 10^6,  GB = 10^9,  TB = 10^12
  1 day = 86,400 sec ~ 10^5 sec
```

## Q12. Walk through a quick capacity estimate for a Twitter-like service.

**Answer:**

Assumptions: 200M DAU, 5 tweets/day each, 100 reads/day each, 200B per tweet.

```text
Writes/day:  200M * 5  = 1B  -> ~12K/s avg, ~30K/s peak
Reads/day:   200M * 100= 20B -> ~250K/s avg, ~600K/s peak
Storage/day: 1B * 200B = 200 GB -> ~70 TB/year
```

Now you know reads are 20:1 over writes (cache the timeline) and yearly storage stays modest (don't over-engineer storage; do over-engineer reads).

---

## 4. Caching Strategies

## Q13. What caching strategies exist?

**Answer:**

| Strategy | How it works |
| --- | --- |
| Cache-aside | App reads cache; on miss reads DB and populates cache |
| Read-through | Cache loads from DB on miss automatically |
| Write-through | Writes go to cache and DB synchronously |
| Write-back | Writes go to cache; flushed to DB later |
| Write-around | Writes skip cache, populate on read |

Cache-aside is the most common; you control everything explicitly.

```js
async function getUser(id) {
  const cached = await redis.get(`user:${id}`);
  if (cached) return JSON.parse(cached);
  const user = await db.users.find(id);
  await redis.setex(`user:${id}`, 300, JSON.stringify(user));
  return user;
}
```

## Q14. What's a cache stampede and how do you prevent it?

**Answer:**

When a hot cache key expires, thousands of requests miss simultaneously and hit the DB at once.

Mitigations:

1. **Lock**: only one request rebuilds the cache; others wait.
2. **Probabilistic early refresh**: refresh randomly before expiry.
3. **Stale-while-revalidate**: serve stale, refresh in background.

```js
const lockKey = `lock:user:${id}`;
const got = await redis.set(lockKey, '1', 'NX', 'EX', 5);
if (got) {
  const user = await db.users.find(id);
  await redis.setex(`user:${id}`, 300, JSON.stringify(user));
  await redis.del(lockKey);
}
```

## Q15. Cache invalidation strategies.

**Answer:**

- **TTL**: simple, eventual.
- **Write-through invalidation**: app deletes cache on write.
- **Version key**: bump a version; cache key includes version, so old keys are abandoned.
- **Event-driven**: pub/sub event invalidates all servers' caches.

"There are only two hard things in computer science: cache invalidation and naming things." — true.

## Q16. Eviction policies.

**Answer:**

| Policy | Strategy |
| --- | --- |
| LRU | Evict least recently used |
| LFU | Evict least frequently used |
| FIFO | Evict oldest first |
| TTL | Evict by expiration |
| Random | Random victim |

Redis defaults to `noeviction` (errors on full); switch to `allkeys-lru` for a general-purpose cache.

---

## 5. Sharding and Partitioning

## Q17. What is sharding?

**Answer:**

Sharding splits data across multiple databases so each holds a subset. Each query goes to the shard owning that data. Used when one database can't hold or serve all the data.

```text
Shard 1: user_id 0-99,999    -> db-1
Shard 2: user_id 100K-199K   -> db-2
Shard 3: user_id 200K-299K   -> db-3
```

Common strategies:

- **Range**: split by ranges (good for sequential queries, bad if traffic skews).
- **Hash**: `shard = hash(key) % N` (uniform distribution).
- **Consistent hashing**: minimal data movement when N changes.
- **Geographic**: shard by region for data residency.

## Q18. What's the resharding problem?

**Answer:**

Hash-mod sharding moves most of the data when you change N. Consistent hashing minimizes movement (only a fraction). Use vnodes (many small partitions) so capacity changes redistribute smoothly.

---

## 6. Replication

## Q19. Replication strategies.

**Answer:**

| Type | Behavior |
| --- | --- |
| Single leader (primary-replica) | One writer; replicas serve reads |
| Multi-leader | Multiple writers (multi-region); conflicts possible |
| Leaderless (Dynamo, Cassandra) | Any node accepts writes; quorum reads/writes |

Single leader is the default in MySQL/Postgres. Multi-leader and leaderless trade consistency for availability.

## Q20. Read replicas — what's the catch?

**Answer:**

Read replicas reduce load on the primary but lag behind it (replication is async). A user who just wrote may not see their own change if the next read goes to a replica. Mitigations:

- Route reads after writes to the primary for a window.
- Pin a session to one replica.
- Wait for replica to catch up before reading.

---

## 7. Consistent Hashing

## Q21. Explain consistent hashing.

**Answer:**

Map nodes and keys to points on a circle. To find a key's owner, walk clockwise from the key to the next node. Adding/removing a node only moves keys near that node.

```text
   N1 (hash=10)
       |
       v
+---*-------*------*-----*-+
   K1=15   K2=40  N2=50  K3=60
                          |
                          v
   N2 takes K2 and K3; N1 keeps K1.
```

To balance load, give each node many "virtual nodes" on the ring.

```python
import bisect, hashlib

def h(s):
    return int(hashlib.md5(s.encode()).hexdigest(), 16)

class Ring:
    def __init__(self, nodes, vnodes=100):
        self.ring = []
        for n in nodes:
            for v in range(vnodes):
                self.ring.append((h(f"{n}-{v}"), n))
        self.ring.sort()

    def get(self, key):
        i = bisect.bisect(self.ring, (h(key),))
        return self.ring[i % len(self.ring)][1]
```

## Q22. Why does consistent hashing matter?

**Answer:**

When you scale a cache or shard cluster, naive `hash(k) % N` invalidates almost everything. Consistent hashing moves only `1/N` of keys. Used in DynamoDB, Cassandra, memcached clients, and CDNs.

---

## 8. Load Balancers

## Q23. L4 vs L7 load balancing — review.

**Answer:**

- **L4**: TCP/UDP only; routes by IP/port. Fast, simple.
- **L7**: HTTP-aware; routes by path, host, header. Supports retries, request shaping.

Use L7 for HTTP services and gRPC. Use L4 for raw TCP or extreme throughput.

## Q24. Load balancing algorithms.

**Answer:**

| Algorithm | Behavior |
| --- | --- |
| Round-robin | Rotates through backends |
| Least connections | Picks backend with fewest active conns |
| Least response time | Picks fastest backend |
| Hash | Same key goes to same backend (sticky) |
| Power of two choices | Pick 2 random, pick the less loaded |

"Power of two" is surprisingly good for randomized routing.

## Q25. How do you scale a load balancer itself?

**Answer:**

DNS round-robin to multiple LB IPs, or anycast. For high traffic, use multiple LBs behind the same VIP, with the kernel/SmartNIC distributing traffic (e.g. Maglev, IPVS).

---

## 9. CDNs

## Q26. What does a CDN do?

**Answer:**

A CDN caches your content (images, JS, video, increasingly API responses) at edge locations near users. Requests hit the nearest edge, not your origin. Reduces latency dramatically and offloads origin traffic.

```text
[user in Tokyo] -> [edge in Tokyo] -> (miss) -> [origin in Virginia]
                                    -> (hit)  -> served from Tokyo edge
```

CDNs also do DDoS protection, TLS termination, and image optimization.

## Q27. Pull vs push CDN?

**Answer:**

- **Pull**: CDN fetches from origin on first miss; caches on demand. Default for most sites.
- **Push**: you proactively upload assets to the CDN. Useful for large files where you want zero misses.

---

## 10. Message Queues and Streams

## Q28. When to use a queue vs a stream?

**Answer:**

| | Queue (RabbitMQ, SQS) | Stream (Kafka, Kinesis) |
| --- | --- | --- |
| Consumption | One consumer per message | Many consumers replay log |
| Retention | Removed when consumed | Retained for days |
| Ordering | Per-queue (limited) | Per-partition (strong) |
| Replay | No | Yes |
| Use | Background jobs | Event sourcing, analytics |

Use a queue for "do this work once". Use a stream for "many systems need the same events".

---

## 11. Leader Election and Distributed Locks

## Q29. Why do you need leader election?

**Answer:**

Some tasks must run on exactly one node (a cron job, a master writer, a coordinator). Leader election picks one and detects when it dies. Tools: ZooKeeper, etcd, Consul, Redis Redlock (with caution).

```js
// etcd leader election
const lease = await etcd.lease(10);
const election = lease.election('cron-leader');
await election.campaign(myId);
// I am the leader; do leader work
election.on('error', () => exit());
```

## Q30. What's a distributed lock and what's the catch?

**Answer:**

A lock that multiple machines respect. Implemented with a key-value store with TTL.

The catch: lock holder may pause (GC, network blip) longer than the TTL. The lock expires; another holder takes it; the original wakes up and thinks it still has the lock. Two writers — disaster.

Mitigation: use **fencing tokens** (each lock acquisition gets a monotonically increasing number; the resource rejects writes with a stale token).

---

## 12. Rate Limiting Algorithms

## Q31. Compare rate limiting algorithms.

**Answer:**

| Algorithm | Behavior |
| --- | --- |
| Fixed window | Count per minute; resets at minute boundary |
| Sliding window log | Store every request timestamp |
| Sliding window counter | Hybrid: weighted average of two fixed windows |
| Token bucket | Bucket fills at R tokens/sec; each request consumes one |
| Leaky bucket | Requests drain at constant rate; queue overflow rejects |

Token bucket is the most popular: simple, allows short bursts, easy to implement in Redis.

## Q32. Where do you apply rate limiting?

**Answer:**

- **Edge / CDN**: stop floods early.
- **API gateway**: per API key.
- **Per service**: defend internal capacity.
- **Per user**: prevent abuse.

Combine layers; one is never enough.

---

## 13. Design: URL Shortener (bit.ly)

## Q33. Design a URL shortener.

**Answer:**

**Functional requirements:**

- Shorten a long URL to a short alias.
- Redirect alias → long URL.
- Track click counts.

**Non-functional:**

- 100M URLs/day created (about 1.2K/s).
- 10:1 read/write ratio (12K/s redirects).
- Latency under 100ms.
- Aliases never break.

**Capacity:**

```text
Writes: 100M/day -> ~1.2K/s
Reads:  10x writes -> ~12K/s
Storage: 100M * 500B/url = 50GB/day, ~18TB/year
Aliases: 6 chars in base62 = 62^6 ≈ 56B; enough for years
```

**API:**

```http
POST /shorten { "url": "https://very/long/url" }
=> { "alias": "abc123" }

GET /abc123
=> 302 Location: https://very/long/url
```

**Data model:**

```sql
CREATE TABLE urls (
  alias VARCHAR(7) PRIMARY KEY,
  long_url TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  user_id BIGINT,
  click_count BIGINT DEFAULT 0
);
CREATE INDEX urls_created_at ON urls(created_at);
```

**Alias generation:** options:

1. Hash long URL → take first 7 base62 chars; collisions → retry.
2. Pre-generated alias pool, pick next available (avoids hot-key on counter).
3. Snowflake-style ID, encode to base62.

**Architecture:**

```text
[client] -> [CDN] -> [LB] -> [API servers]
                                  |
                       +----------+----------+
                       v                     v
                    [Redis cache]         [DB primary]
                                          [DB replicas]
                                              |
                                        [analytics stream]
```

Reads: alias -> Redis -> DB on miss. Writes: insert in DB, push to Redis on first read.

**Scaling:** read traffic dwarfs writes; cache in Redis with high hit rate. Redirect path avoids DB on cache hit. Click counts go to a stream; aggregator updates DB asynchronously.

**Trade-offs:**

- Hash-based aliases mean same URL → same alias (good for dedup).
- Pre-generated pool avoids hot writes but needs a worker to refill.
- Analytics async means click counts lag; OK.

---

## 14. Design: Twitter Feed / Activity Feed

## Q34. Design a Twitter-like feed.

**Answer:**

**Functional:**

- Post a tweet.
- Follow/unfollow users.
- See a feed of tweets from followed users.

**Non-functional:**

- 200M DAU.
- Reads dominate (20:1 over writes).
- p99 200ms for feed load.

**Two models for timeline:**

1. **Pull (fan-out on read)**: at read time, query tweets from all followed users and merge. Bad for users following thousands; query is expensive.
2. **Push (fan-out on write)**: when you tweet, write the tweet to the feed cache of every follower. Read is just a list lookup; very fast. Bad for celebrities (one tweet = millions of writes).

Use **hybrid**: push for normal users, pull for celebrity tweets, merge at read.

**Architecture:**

```text
[client] -> [CDN] -> [LB] -> [feed-api]
                              /        \
                             v          v
                   [tweet store]    [feed cache (Redis)]
                       (Cassandra)
                             |
                             v
                       [fanout worker] consumes 'tweet.created' events
                             |
                       updates each follower's feed cache
```

**Data model:**

```text
tweets table (Cassandra):
  PARTITION KEY: user_id
  CLUSTERING KEY: tweet_id (time-sortable)
  fields: text, media_urls, ts

follows table:
  user_id, follower_id

feed cache:
  Redis ZSET per user: feed:{user_id} -> (tweet_id, ts)
```

**Storage:** 1B tweets/day * 300B = 300 GB/day, 100+ TB/year. Use Cassandra for unbounded write throughput.

**Capacity:** 12K writes/s, 200K reads/s. Each feed read is one Redis ZRANGE on the user's feed cache. Backed by replicated Cassandra for misses.

**Trade-offs:**

- Hybrid model handles both common users and celebrities.
- Eventual consistency: a follower may not see a tweet for a few seconds.
- Feed cache is huge; cap at last 800 tweets per user.

---

## 15. Design: Chat App (WhatsApp-style)

## Q35. Design a chat app.

**Answer:**

**Functional:**

- 1:1 and group chats.
- Real-time delivery.
- Read receipts and typing indicators.
- Persistence of message history.

**Non-functional:**

- 1B users, 50B messages/day.
- p99 delivery latency under 500ms.
- Survives network drops.

**Architecture:**

```text
[mobile client]
   |
   |-- WebSocket --> [edge gateway]
                          |
                          v
                    [chat service]
                       |       |
                       v       v
                  [message DB]  [presence cache]
                  (Cassandra)   (Redis)
                       |
                       v
                 [pubsub bus] (Redis or Kafka)
                       |
            fan out to recipient gateways
```

**Per-message flow:**

1. Sender's client sends message over WebSocket.
2. Edge gateway forwards to chat service.
3. Chat service writes to Cassandra (durable).
4. Publishes to pub/sub channel for recipient.
5. Recipient's gateway delivers via WebSocket.
6. Acks and receipts flow back the same way.

**Data model (Cassandra):**

```text
messages:
  PARTITION KEY: conversation_id
  CLUSTERING KEY: message_id (time-sortable)
  fields: sender_id, body, ts, type
```

Partition by conversation so all messages for a chat are together; clustering by id lets you page recent messages.

**Group chat fan-out:** for small groups, fan out per recipient. For large groups, write once and have recipients pull.

**Scaling:**

- Sticky WebSocket sessions to edge gateways.
- Redis pub/sub for cross-gateway routing.
- Cassandra horizontally scales writes.

**Trade-offs:**

- E2E encryption changes the model: server can't index or analyze content.
- Read receipts and typing are best-effort; don't store typing state.

---

## 16. Design: News Aggregator

## Q36. Design a news aggregator.

**Answer:**

**Functional:** crawl thousands of sources, dedup, rank, serve a feed.

**Architecture:**

```text
[scheduler] --> [crawler workers] --> [parsed articles topic]
                                            |
                                            v
                                     [dedup service] (sim-hash, MinHash)
                                            |
                                            v
                                      [enrichment] (categorize, NLP)
                                            |
                                            v
                                   [search index + DB]
                                            |
                                            v
                                       [feed API]
```

**Scaling concerns:**

- Politeness: respect `robots.txt` and per-host rate limits.
- Dedup at scale: use MinHash on content shingles, then exact compare.
- Hot topics: shard work by topic so one event doesn't overwhelm a single shard.

---

## 17. Design: Web Crawler

## Q37. Design a web crawler.

**Answer:**

**Functional:** crawl billions of pages, extract content, rank.

**Components:**

```text
[seed URLs] -> [URL frontier] -> [DNS resolver]
                                       |
                                       v
                              [fetcher pool] -> [parser]
                                                   |
                                                   +-- new URLs back to frontier
                                                   |
                                                   v
                                          [content store]
```

**URL frontier:** priority queue with politeness (per-host token buckets). Hash URL to a host bucket; hosts processed by separate workers.

**Deduplication:** Bloom filter for "have we seen this URL?" + content-level hash for "have we seen this content?".

**Storage:** raw HTML in S3/GCS, parsed text in document store, links in graph DB or wide-column.

**Scaling:** thousands of fetchers in parallel, distributed frontier (e.g. Kafka topic per host shard).

**Politeness:** crawl-delay, robots.txt, rate limits per host, retry-after handling.

---

## 18. Design: Notification System

## Q38. Design a notification system.

**Answer:**

**Functional:** send notifications via email, SMS, push to billions of users.

**Architecture:**

```text
[upstream services] -> [notification API] -> [Kafka topic]
                                                  |
                                +-----------------+-----------------+
                                v                 v                 v
                          [email worker]    [push worker]    [SMS worker]
                                                  |
                                          [provider APIs]
```

**Per-user preferences and dedup:**

- Store preferences per user per channel.
- Use an idempotency key on every notification request to dedup retries.
- A "last sent" cache prevents notification storms (e.g. don't send 50 push notifications in a minute).

**Scaling:** each channel scales independently. Failures in SMS don't block email. Provider rate limits handled per worker pool.

---

## 19. Design: Rate Limiter

## Q39. Design a distributed rate limiter.

**Answer:**

**Functional:** allow N requests per user per minute across a fleet of servers.

**Architecture:** centralized counter in Redis; every server checks before serving.

**Token bucket in Redis (Lua, atomic):**

```lua
-- KEYS[1] = bucket key
-- ARGV[1] = capacity, ARGV[2] = refill_rate, ARGV[3] = now
local capacity = tonumber(ARGV[1])
local rate = tonumber(ARGV[2])
local now = tonumber(ARGV[3])

local data = redis.call('HMGET', KEYS[1], 'tokens', 'ts')
local tokens = tonumber(data[1]) or capacity
local ts = tonumber(data[2]) or now

local elapsed = now - ts
tokens = math.min(capacity, tokens + elapsed * rate)
local allowed = tokens >= 1

if allowed then tokens = tokens - 1 end

redis.call('HMSET', KEYS[1], 'tokens', tokens, 'ts', now)
redis.call('EXPIRE', KEYS[1], 60)
return allowed and 1 or 0
```

**Trade-offs:** Redis is a single point of failure (mitigate with Redis Cluster); local fallback can allow brief over-quota during Redis outages; sliding window log gives better accuracy at higher cost.

---

## 20. Design: Distributed Cache

## Q40. Design a Redis-like distributed cache.

**Answer:**

**Functional:** key-value, GET/SET/DEL, TTL, eviction, replication.

**Architecture:**

```text
Clients -> consistent-hash-aware client lib -> [shard 1] [shard 2] [shard 3]
                                                   |        |        |
                                                replicas  replicas  replicas
```

- Consistent hashing for key placement.
- Each shard has a primary + replicas (failover).
- LRU eviction per shard.
- Replication: async to followers, optionally sync for critical keys.

**Trade-offs:** AP system (eventual consistency); writes can be lost during failover; sync replication adds latency.

---

## 21. Design: Photo Sharing (Instagram)

## Q42. Design a photo-sharing service.

**Answer:**

**Capacity:** 500M users, 100M photos/day, ~2B reads/day.

**Architecture:**

```text
[client] -> [CDN] -> [LB] -> [API]
                                |
                +---------------+---------------+
                v               v               v
        [photo metadata]  [photo blob]    [feed cache]
        (Postgres)        (S3)            (Redis)
                                |
                                v
                       [image pipeline] (resize, watermark)
                       producer/consumer via Kafka
```

**Image pipeline:**

1. Client uploads original to S3.
2. Metadata row created.
3. `photo.uploaded` event triggers transcoding to multiple resolutions (thumb, medium, full).
4. CDN URLs returned to client.

**Feed:** same hybrid push/pull as Twitter (Q34).

**Counters:** likes/views written via stream; aggregated periodically; eventually consistent.

**CDN strategy:** cache thumbnails aggressively (immutable URLs); originals signed with short expiry.

---

## 22. Design: YouTube / Netflix Streaming

## Q43. Design a video streaming service.

**Answer:**

**Pipeline (upload → playback):**

1. Upload original video to object storage.
2. Transcoder produces multiple bitrates and HLS/DASH segments.
3. Segments uploaded to origin storage.
4. CDN distributes globally.
5. Metadata indexed for search.

```text
[creator]    [viewer]
   |             |
   v             v
[upload API] [video page]
   |             |
   v             v
[blob store]  [CDN edge] -- (miss) --> [origin]
   |
   v
[transcoder workers]
   |
   v
[manifest + segments to origin]
```

**Adaptive bitrate streaming:** the player measures bandwidth and switches to higher/lower bitrate per segment. HLS/DASH packages 2-10s segments at multiple resolutions; the manifest lists them.

**Metadata storage:** Postgres for catalog, Elasticsearch for search, Redis for trending.

**Recommendations:** offline batch (Spark/ML) writes per-user candidates; online ranker re-ranks on view.

**CDN strategy:** popular content pre-pushed to edges; long-tail pulled on first miss; massive caches (multi-PB).

---

## 23. Design: Uber / Lyft Ride Sharing

## Q44. Design a ride-sharing service.

**Answer:**

**Geo-indexing — the core problem:**

Match a rider to nearby drivers in milliseconds.

- Use **geohash** or **H3** to bucket the world into cells.
- Drivers send location every 5s; updates the geo index.
- Rider request: query "drivers in cells [a, b, c]" and rank by ETA.

```text
Driver location -> [geo service]
                       |
                       v
              [Redis Geo / Cassandra geo index]
```

**Architecture:**

```text
[driver app] -> [location API] -> [stream] -> [geo index]
[rider app] -> [match service] -> [geo index] -> top N drivers
                       |
                       v
                  [trip service] -> [trip DB]
                       |
                       v
                  [pricing, payments, notifications]
```

**Real-time tracking:** WebSocket or low-frequency HTTP polling from rider; backend pushes driver position updates from the geo stream.

**Surge pricing:** tracks demand vs supply per cell; multiplier applied at matching time.

**Payments:** async after trip ends; idempotent and retried.

**Scaling:**

- Shard geo index by region.
- Match service stateless; horizontal scale.
- Trip DB partitioned by trip id.

---

## 24. Design: File Storage (Dropbox / Google Drive)

## Q45. Design a cloud file storage service.

**Answer:**

**Architecture:**

```text
[client]
  |
  v
[chunker] -> upload chunks via signed URLs to [object store]
  |
  v
[metadata API] -> records file -> chunk mapping in Postgres
```

**Chunking and dedup:**

- Split files into 4 MB chunks.
- Hash each chunk; if it already exists, skip the upload (dedup).
- File metadata stores ordered list of chunk hashes.

**Sync algorithm:**

- Client watches local folder.
- On change, compute new chunks; diff against last known.
- Upload changed chunks; PATCH metadata.
- Server pushes changes to other devices via WebSocket.

**Metadata model:**

```sql
files (id, owner_id, path, version)
file_chunks (file_id, idx, chunk_hash)
chunks (hash, size, storage_url)
```

**Storage:** S3 / GCS; metadata in Postgres (sharded by owner).

**Sharing and ACLs:** ACL table per file; gateway checks before signing URLs.

---

## 25. Design: Search Autocomplete

## Q46. Design a search autocomplete service.

**Answer:**

**Architecture:**

```text
[client] --keystroke--> [autocomplete API] -> [trie service] -> [Redis trie / sorted set]
                                                    |
                                              periodic rebuild from
                                              [search log analytics]
```

**Data structure:** a trie keyed on prefix, leaves storing top-N suggestions sorted by score (e.g. recent search frequency).

**Ranking:** weight by query frequency, recency, personalization. Periodic batch job updates scores.

**Scaling:** trie is small enough to fit in memory across shards. CDN caches popular prefixes.

**Caveats:** misspellings (use edit distance), personalization (per-user trie segment), regional differences.

---

## 26. Design: Distributed Counter

## Q47. Design a high-throughput counter (e.g. likes).

**Answer:**

**Naive approach and why it fails:** a single row with `UPDATE counts SET v=v+1`. At 100K/s every write contends on one row; lock contention destroys throughput.

**Sharded counter:**

```text
counter_shards table:
  counter_id, shard_id, value
  PRIMARY KEY (counter_id, shard_id)

To increment: pick a random shard 0..N, UPDATE that row.
To read: SUM all shards.
```

Splits contention across N shards; reads slightly more expensive but parallelizable.

**Eventual consistency variant:** writes go to a stream; aggregator periodically updates a snapshot. Reads return snapshot + recent stream window.

**CRDT counter (multi-region):** use a Grow-only Counter (PN-Counter for inc/dec) where each replica increments locally and replicas merge by taking max per replica id.

**Trade-offs:**

- Sharded counter: stronger consistency, more shards needed at higher write rates.
- Stream-aggregated: best for very high writes (likes, views), accepts staleness.
- CRDT: needed for multi-master writes.

---

## 27. Design: Job Scheduler at Scale

## Q48. Design a distributed job scheduler.

**Answer:**

**Functional:** schedule one-off and recurring jobs across thousands of workers, retry on failure, observability.

**Architecture:**

```text
[user / API] -> [scheduler service] -> [job DB]
                       |
              periodic poll for due jobs
                       |
                       v
                  [work queue (Kafka/Redis)]
                       |
                       v
                  [worker pool]
                       |
                       v
                  job execution; status -> DB
```

**Storage and indexing:**

```sql
jobs (id, run_at, status, payload, attempts, max_attempts, last_error, version)
INDEX jobs_run_at ON jobs(run_at) WHERE status='pending';
```

**Claiming jobs:** workers must atomically claim. Use `SELECT ... FOR UPDATE SKIP LOCKED` (Postgres) or a Lua script in Redis.

```sql
SELECT id FROM jobs
 WHERE status='pending' AND run_at <= now()
 ORDER BY run_at LIMIT 10 FOR UPDATE SKIP LOCKED;
UPDATE jobs SET status='running', started_at=now() WHERE id IN (...);
```

**Reliable execution:** worker takes a heartbeat lease. If lease expires (worker crashed), another worker can re-claim. Idempotent handlers required.

**Cron jobs:** stored as recurrence rule + last/next run; scheduler computes next run after each completion.

**Scaling:**

- Partition the jobs table by tenant or hash.
- Run multiple scheduler instances; they coordinate via leader election or partition ownership.

**Trade-offs:**

- Polling vs streaming: polling is simple; streaming reduces latency at cost of complexity.
- At-least-once execution requires idempotent jobs.

---

## 28. Final Senior-Level Rules of Thumb

## Q49. Wrap-up principles.

**Answer:**

- Start with constraints, not solutions.
- Estimate before designing; numbers drive choices.
- Default to boring tech; add complexity only when justified.
- Cache aggressively but plan for invalidation.
- Async where you can; sync where you must.
- Idempotent handlers, retries with backoff, timeouts on every call.
- Replicate data; expect failures.
- Consistency is a spectrum; pick the weakest level your product can tolerate.
- Observability (logs, metrics, traces) from day one.
- Capacity plan for 10x; design for 100x only when you're already at 10x.
