# System Design Interview Questions — Senior Level

**Purpose:** Senior-level system design interview preparation. Covers the framework, the foundational concepts, and deep dives into the most-asked design problems.

---

## Table of Contents

1. [How to Approach a System Design Interview](#how-to-approach-a-system-design-interview)
2. [Foundational Concepts](#foundational-concepts)
3. [Capacity Estimation Cheatsheet](#capacity-estimation-cheatsheet)
4. [Caching Strategies](#caching-strategies)
5. [Sharding and Partitioning](#sharding-and-partitioning)
6. [Replication](#replication)
7. [Consistent Hashing](#consistent-hashing)
8. [Load Balancers](#load-balancers)
9. [CDNs](#cdns)
10. [Message Queues and Streams](#message-queues-and-streams)
11. [Leader Election and Distributed Locks](#leader-election-and-distributed-locks)
12. [Rate Limiting Algorithms](#rate-limiting-algorithms)
13. [Design: URL Shortener (bit.ly)](#design-url-shortener-bitly)
14. [Design: Twitter Feed / Activity Feed](#design-twitter-feed--activity-feed)
15. [Design: Chat App (WhatsApp-style)](#design-chat-app-whatsapp-style)
16. [Design: News Aggregator](#design-news-aggregator)
17. [Design: Web Crawler](#design-web-crawler)
18. [Design: Notification System](#design-notification-system)
19. [Design: Rate Limiter](#design-rate-limiter)
20. [Design: Distributed Cache](#design-distributed-cache)
21. [Design: Pastebin](#design-pastebin)
22. [Design: Instagram (Image Sharing)](#design-instagram-image-sharing)
23. [Design: YouTube / Netflix Streaming](#design-youtube--netflix-streaming)
24. [Design: Uber / Lyft Ride Sharing](#design-uber--lyft-ride-sharing)
25. [Design: File Storage (Dropbox / Google Drive)](#design-file-storage-dropbox--google-drive)
26. [Design: Search Autocomplete](#design-search-autocomplete)
27. [Design: Distributed Counter](#design-distributed-counter)
28. [Design: Job Scheduler at Scale](#design-job-scheduler-at-scale)

---

## How to Approach a System Design Interview

### Q1. What's the structure of a 45–60 minute system design interview?

| Stage | Time | What to do |
|-------|------|------------|
| Clarify requirements | 5 min | Functional and non-functional reqs, scope |
| Capacity estimation | 5 min | Read/write QPS, storage, bandwidth |
| API design | 5 min | Endpoints, request/response shapes |
| Data model | 5 min | Entities, relationships, indexes |
| High-level architecture | 10 min | Box-and-arrow diagram |
| Deep dives | 15 min | Pick 1–2 components, show real depth |
| Bottlenecks and trade-offs | 5 min | What breaks first; what you'd improve |

The biggest mistake: jumping into a diagram before understanding requirements. The second biggest: spreading thin instead of going deep.

---

### Q2. What questions should you ask up front?

**Functional:**

- What are the core features? (Read-heavy or write-heavy?)
- Who are the users? Mobile, web, both?
- What does the user actually want to do?
- What's in scope vs out of scope?

**Non-functional:**

- Scale: users, QPS, data size?
- Latency targets: p50, p99?
- Availability: 99.9? 99.99?
- Consistency requirements: strong or eventual?
- Geographic distribution?
- Read vs write ratio?

**Constraints:**

- Existing infra to integrate with?
- Cost sensitivity?
- Time budget?

---

### Q3. How do you estimate capacity quickly?

**The four pillars:**

1. **QPS** — daily active users × actions per user / 86,400 seconds × peak factor.
2. **Storage** — record size × retention.
3. **Bandwidth** — payload size × QPS.
4. **Memory** — hot data × cache hit ratio.

Round generously and show your work. Interviewers want to see whether you can reason about scale, not exact numbers.

---

### Q4. What does a "deep dive" look like?

Pick the most interesting/hard component and go several layers deeper:

- "How does the feed service work?" → "It reads from Redis sorted sets per user."
- "What's the data model in Redis?" → "ZSET keyed by user, members are post IDs, scores are timestamps."
- "How does fan-out happen?" → "On post creation, async worker writes to N follower ZSETs."
- "What if a celebrity has 100M followers?" → "Hybrid: pull at read time for very high-fanout users."
- "What if Redis fails?" → "Replicas + persistence; rebuild from Postgres if needed."

This is what distinguishes senior from junior responses.

---

### Q5. What trade-offs should you always discuss?

- **Consistency vs availability** (CAP).
- **Consistency vs latency** (PACELC).
- **Read vs write optimization** (denormalize for reads, normalize for writes).
- **Push vs pull** (fan-out write vs fan-out read).
- **Synchronous vs asynchronous** (immediate confirmation vs throughput).
- **Build vs buy** (managed service vs self-hosted).

Don't pick a side without explaining the trade-off.

---

## Foundational Concepts

### Q6. Explain the CAP theorem.

**Answer:** In a distributed system experiencing a network partition, you can choose at most two of:

- **Consistency** — every read sees the most recent write.
- **Availability** — every request gets a non-error response.
- **Partition tolerance** — system continues despite network partitions.

In practice, partitions happen, so the real choice is **C or A during a partition**:

- **CP systems:** etcd, Zookeeper, traditional RDBMS in primary-replica with sync replication, MongoDB (default), HBase.
- **AP systems:** Cassandra, DynamoDB (eventually consistent reads), Couchbase, Riak.

---

### Q7. What is PACELC?

**Answer:** An extension of CAP. **If Partition: choose Availability or Consistency. Else: choose Latency or Consistency.**

Even without partitions, you choose between latency (synchronous replication is slower) and consistency. Most real systems are PA/EL or PC/EC.

| System | Position |
|--------|----------|
| Cassandra | PA/EL |
| DynamoDB (default) | PA/EL |
| MongoDB (default) | PC/EC |
| HBase | PC/EC |
| Spanner | PC/EC (claims very high availability) |

---

### Q8. What are ACID and BASE?

**ACID** — strong guarantees from RDBMS:

- Atomicity, Consistency, Isolation, Durability.

**BASE** — properties of many NoSQL systems:

- **B**asically **A**vailable — system responds even under partial failure.
- **S**oft state — state may change without input as replicas converge.
- **E**ventually consistent — given no new writes, eventually all replicas agree.

Pick ACID for transactional correctness; BASE for scale and availability.

---

### Q9. SQL vs NoSQL — when which?

| Aspect | SQL | NoSQL |
|--------|-----|-------|
| Schema | Fixed | Flexible |
| Joins | First-class | Limited or none |
| Transactions | ACID across rows/tables | Often per-document/key |
| Scale model | Vertical, then sharding | Horizontal-native |
| Best for | Transactional, complex queries | High-volume, flexible data |
| Examples | Postgres, MySQL | MongoDB, Cassandra, DynamoDB |

For most CRUD apps with structured data: Postgres. For massive write throughput, time series, or denormalized event/log workloads: NoSQL.

---

### Q10. Strong consistency vs eventual consistency vs causal consistency?

| Model | Guarantee |
|-------|-----------|
| Strong (linearizable) | Reads see the latest write; like a single-machine system |
| Sequential | Operations appear in some total order, same for all observers |
| Causal | If A happens-before B, all observers see A before B |
| Eventual | Eventually all replicas converge; no ordering guarantee |
| Read-your-writes | You see your own writes; others may not yet |
| Monotonic reads | Once you've read X, you won't see an older value |

Senior systems usually pick the weakest model that still serves the use case.

---

## Capacity Estimation Cheatsheet

### Q11. What numbers should you have memorized?

**Time:**

- 1 day = 86,400 seconds (≈ 100k for back-of-envelope).
- 1 month = 2.5 M seconds.
- 1 year = 30 M seconds.

**Latency (Jeff Dean's numbers, rounded):**

| Operation | Latency |
|-----------|---------|
| L1 cache | 1 ns |
| L2 cache | 10 ns |
| Main memory | 100 ns |
| SSD random read | 100 µs |
| HDD seek | 10 ms |
| Network round trip same DC | 0.5 ms |
| Network round trip cross-region | 100 ms |

**Storage:**

- 1 KB ≈ small JSON record.
- 1 MB ≈ medium image, 4–5 minutes of low-quality audio.
- 1 GB ≈ ~20 minutes of HD video, ~1 M small records.
- 1 TB ≈ a billion small records.

**QPS rough orders:**

- Single Postgres: 10–50 k QPS for simple queries.
- Single Redis: 100 k–1 M QPS.
- Single Kafka broker: 100s of MB/s, millions of messages/sec.
- Single load balancer: 100 k+ QPS.

---

### Q12. Walk through a quick capacity estimate for a "Twitter-like" service.

```
DAU:          200 M
Tweets/day:   200 M  (avg 1/user)
Reads/tweet:  100   (timeline views)
                                      
Write QPS:   200M / 86,400 ≈ 2,300 → peak 5,000 QPS
Read QPS:    20B / 86,400 ≈ 230,000 → peak 500,000 QPS

Read:write ratio: 100:1 → read-heavy, cache and fan-out matter

Storage per tweet: 280 chars + metadata ≈ 1 KB
Daily write volume: 200 GB
Yearly: 70 TB (text only)
```

This already tells you: read-optimized architecture, heavy caching, fan-out on write or hybrid.

---

## Caching Strategies

### Q13. What caching strategies exist?

| Strategy | How it works | Pros | Cons |
|----------|--------------|------|------|
| Cache-aside (lazy) | App reads cache; on miss, reads DB and writes cache | Simple, only used data is cached | First read is slow; stale risk |
| Read-through | Cache itself loads from DB on miss | Cleaner app code | Cache must understand DB |
| Write-through | App writes to cache; cache writes to DB sync | Strong consistency | Slower writes |
| Write-behind (write-back) | App writes to cache; cache writes to DB async | Fast writes | Data loss risk if cache crashes |
| Write-around | App writes to DB only; cache populated on read | Avoids cache pollution from rare writes | Reads after writes are slow |
| Refresh-ahead | Cache proactively refreshes hot keys before expiry | Low miss rate for hot data | Complexity |

Cache-aside is the default for most systems. Write-through where consistency matters. Write-behind only when you can tolerate loss.

---

### Q14. What's a cache stampede and how do you prevent it?

**Answer:** When a popular cache key expires, many requests miss simultaneously and all hit the DB at once.

**Mitigations:**

- **Locking / single-flight** — only one request fetches; others wait or get stale.
- **Probabilistic early expiration** — refresh hot keys randomly before TTL ends.
- **Stale-while-revalidate** — serve stale; refresh in background.
- **Bloom filter for nonexistent keys** — avoid hammering DB for keys that don't exist (cache penetration).

---

### Q15. Cache invalidation strategies.

- **TTL** — simplest, eventual freshness.
- **Write-through invalidation** — invalidate or update on write.
- **Event-driven** — DB CDC triggers cache invalidation.
- **Versioned keys** — include version in key; old keys age out.

"There are only two hard things in computer science: cache invalidation and naming things."

---

### Q16. Eviction policies.

| Policy | Behavior | Use case |
|--------|----------|----------|
| LRU | Evict least recently used | General default |
| LFU | Evict least frequently used | Stable hot set |
| FIFO | Evict oldest | Simple |
| Random | Evict any | Fast, simple |
| TTL | Evict expired | Time-bounded data |

Redis supports `allkeys-lru`, `allkeys-lfu`, `volatile-lru` (only TTL keys), etc.

---

## Sharding and Partitioning

### Q17. What is sharding?

**Answer:** Splitting data horizontally across multiple databases. Each shard holds a subset of rows.

| Strategy | How | Pros | Cons |
|----------|-----|------|------|
| Range | by key range (`user_id` 0–100k → shard A) | Range queries efficient | Hot shards likely |
| Hash | hash(key) % N shards | Even distribution | Range queries scatter |
| Geographic | by user's region | Locality | Cross-region queries hard |
| Directory-based | lookup table maps key → shard | Flexible, easy to rebalance | Lookup is single point of failure |
| Consistent hashing | hash ring; minimal reshuffle on resize | Add/remove shards smoothly | More complex |

---

### Q18. What's the resharding problem?

**Answer:** When you outgrow your shard count and need to add more shards, modulus-based sharding requires moving most of the data. Consistent hashing minimizes this. Alternatively, pre-shard — start with many "logical" shards mapped onto few physical nodes; when you grow, move logical shards to new nodes without moving every row.

---

## Replication

### Q19. Replication strategies.

| Strategy | Description |
|----------|-------------|
| Single-leader (primary-replica) | All writes to leader; replicas read-only |
| Multi-leader | Multiple writable nodes; conflicts must be resolved |
| Leaderless (Dynamo-style) | Any node can accept writes; quorum reads/writes |

| Sync style | Trade-off |
|------------|-----------|
| Synchronous | Strong consistency, write waits for replica ack |
| Asynchronous | Fast writes, replicas may lag, possible data loss on failover |
| Semi-synchronous | At least one replica must ack, others async |

Most setups: one sync replica, others async — balance between durability and latency.

---

### Q20. Read replicas — what's the catch?

- **Replication lag** — reads may see stale data.
- **Read-after-write inconsistency** — user updates, immediately reads, sees old data.
- **Replica failure** — failover is non-trivial.
- **Schema migrations** — must run on all replicas in order.

Solutions: route the user's own reads to the primary, or stick to a session token-based lag bound.

---

## Consistent Hashing

### Q21. Explain consistent hashing.

**Answer:** Map both nodes and keys onto a hash ring. Each key is owned by the next node clockwise. Adding or removing a node only affects keys between that node and its predecessor.

```
            Node A
              │
        ┌─────┴─────┐
        │           │
      Node D    Node B
        │           │
        └─────┬─────┘
              │
            Node C

    key K → hash(K) lands here → owned by Node B
```

**Virtual nodes:** each physical node gets multiple positions on the ring → smoother distribution and more balanced rebalancing.

Used in: Cassandra, Dynamo, memcached clients, CDN cache routing.

---

### Q22. Why does consistent hashing matter?

- **Scaling:** add a node, only `1/N` of keys move.
- **Availability:** node failure shifts load to neighbors.
- **No central coordinator** needed.

---

## Load Balancers

### Q23. L4 vs L7 load balancing — review.

| L4 | L7 |
|----|----|
| Routes by IP/port | Routes by HTTP path/header/cookie |
| Faster, less feature-rich | More features, more CPU |
| AWS NLB, HAProxy (TCP) | AWS ALB, Envoy, Nginx |

---

### Q24. Load balancing algorithms.

| Algorithm | When to use |
|-----------|-------------|
| Round robin | Equal-cost, stateless backends |
| Weighted round robin | Heterogeneous backend capacity |
| Least connections | Long-lived connections (WebSocket, DB) |
| Least response time | Latency-sensitive |
| Hash-based (sticky) | Session affinity |
| Power of two choices | Random pair, pick the less loaded — surprisingly effective |

---

### Q25. How do you scale a load balancer itself?

- DNS round-robin to multiple LB instances.
- Anycast IP routing to nearest LB region.
- LB cluster with shared state via gossip (HAProxy + Keepalived, AWS-managed).
- Hardware LBs (F5) for very high throughput.

---

## CDNs

### Q26. What does a CDN do?

**Answer:** Caches static (and increasingly dynamic) content at edge POPs close to users. Benefits:

- Lower latency (geographic proximity).
- Origin protection (most traffic stops at edge).
- DDoS absorption.
- TLS termination at edge.

Examples: Cloudflare, Akamai, Fastly, AWS CloudFront.

---

### Q27. What's pull vs push CDN?

- **Pull:** edge fetches from origin on first miss; auto-cached. Simple, default.
- **Push:** you upload assets directly to the CDN. Used for predictable large files (videos).

---

## Message Queues and Streams

### Q28. When to use a queue vs a stream?

| Workload | Queue (RabbitMQ, SQS) | Stream (Kafka, Pulsar) |
|----------|----------------------|------------------------|
| Task distribution | ✓ | Less natural |
| Pub/sub fan-out | ✓ | ✓ |
| Replay history | ✗ | ✓ |
| Order guarantees | Per queue | Per partition |
| High throughput | Good | Excellent |
| Per-message ack | ✓ | ✗ (offset) |
| Retention | Until consumed | Time/size |

---

## Leader Election and Distributed Locks

### Q29. Why do you need leader election?

For tasks that should run **exactly once** in a cluster: a cron, a scheduled rebalance, a singleton consumer. Multiple nodes coordinate; one is elected leader, others stand by.

Implementations:

- **Zookeeper** ephemeral nodes.
- **etcd / Consul** lease-based.
- **Redis** SETNX with TTL (Redlock — controversial).
- **Kubernetes** leader election library (uses `coordination.k8s.io` Lease).

---

### Q30. What's a distributed lock and what's the catch?

A lock that prevents two nodes from doing the same thing concurrently. Catches:

- Clock skew breaks TTL-based locks.
- Network partition: lock holder thinks it has the lock, but lease expired and another node took it.
- "Fencing tokens" — each lock acquisition gets a monotonically increasing token; downstream rejects writes with older tokens.

**Redlock** has been criticized for unsafe assumptions about clocks. Etcd/Zookeeper-based locks with fencing tokens are safer.

---

## Rate Limiting Algorithms

### Q31. Compare rate limiting algorithms.

| Algorithm | Description | Trade-off |
|-----------|-------------|-----------|
| Fixed window | Count requests per N-second window | Simple but boundary spikes |
| Sliding window log | Store timestamps; count in window | Accurate but memory-heavy |
| Sliding window counter | Approximate sliding using two windows | Good balance |
| Token bucket | Bucket fills at rate r, request takes a token | Allows bursts up to bucket size |
| Leaky bucket | Requests enter bucket; processed at fixed rate | Smooths bursts, drops overflow |

Implementation: usually Redis with Lua scripts (atomic). Sliding window counter is the practical default.

---

### Q32. Where do you apply rate limiting?

- Edge / API gateway — protect from abuse, DDoS.
- Per-user — fair share.
- Per-tenant — multi-tenant fairness.
- Per-endpoint — protect expensive endpoints.
- Outbound to dependencies — protect downstream.

---

## Design: URL Shortener (bit.ly)

### Q33. Functional requirements.

- Shorten a long URL to a short alias.
- Redirect from short to long URL.
- Optional: custom aliases, expiration, analytics.

### Non-functional.

- High availability (redirects must work).
- Low redirect latency (< 50 ms).
- High read:write ratio (~100:1).
- Scale: 100 M new URLs/month, 10 B redirects/month.

### Capacity.

```
Writes: 100M/month → ~40/sec, peak 200/sec
Reads: 10B/month → ~4,000/sec, peak 20,000/sec
Storage: 100M × 12 months × 5 years × 500 bytes = ~3 TB
Bandwidth: reads × payload ~ small
```

### API.

```
POST /api/shorten      { long_url, custom_alias?, ttl? } → { short_url }
GET  /:alias            → 302 to long_url
GET  /api/:alias/stats  → click counts, geography, etc.
```

### Data model.

```
mappings
  alias        VARCHAR(10) PRIMARY KEY
  long_url     TEXT NOT NULL
  user_id      BIGINT
  created_at   TIMESTAMPTZ
  expires_at   TIMESTAMPTZ
```

### Alias generation.

| Approach | Pros | Cons |
|----------|------|------|
| MD5/SHA of URL, take first 7 chars | Deterministic, dedup | Collisions, leaks structure |
| Random base62 (a-zA-Z0-9) | Simple, ~3.5 T combos with 7 chars | Collisions; insert-and-retry |
| Counter encoded to base62 | Sequential, no collision | Predictable (security smell) |
| Distributed sequence (Snowflake-like) | Unique, scalable | Slightly longer |

A common choice: **base62 of an auto-incrementing distributed counter**, with a "key generation service" (KGS) that pre-allocates ranges to app servers.

### Architecture.

```
client ──► CDN (edge cache) ──► LB ──► app servers
                                          │
                          ┌───────────────┼────────────────┐
                          │               │                │
                       Redis        Postgres / Cassandra   Kafka
                       (alias →     (source of truth)      (clicks for
                        long URL)                           analytics)
```

### Scaling.

- Read path served almost entirely from cache; cache hit on Redis is < 1 ms.
- Write path is a small fraction; Postgres is fine.
- Click analytics published to Kafka, processed offline (don't slow down the redirect).
- For multi-region: replicate to read-only Redis in each region.

### Trade-offs.

- Custom aliases must be checked for uniqueness — `INSERT ON CONFLICT` for atomicity.
- Expired URLs: lazy expiration on read, or periodic cleanup job.
- Abuse (phishing): integrate with safe browsing API on insert.

---

## Design: Twitter Feed / Activity Feed

### Q34. Functional requirements.

- Users post tweets (max 280 chars).
- Users follow others.
- Home timeline = posts from people you follow, in reverse chronological (or ranked).
- Notifications, likes, retweets.

### Non-functional.

- Read-heavy (~100:1).
- Low timeline read latency (< 200 ms).
- Eventual consistency on timeline OK (a tweet appearing 1s late is fine).

### Two models for timeline.

| Approach | How | Pros | Cons |
|----------|-----|------|------|
| Pull (fan-out on read) | At read time, query all followees and merge | Cheap on write | Expensive on read; bad for users with many followees |
| Push (fan-out on write) | On post, write to each follower's timeline | Fast read | Expensive write; "celebrity problem" |
| Hybrid | Push for most users; pull for celebrity followees | Best of both | Complex |

**Hybrid is the production answer.** Threshold: if a user has >1M followers, don't fan out on write — their followers pull on read.

### Architecture.

```
post tweet ──► tweet service ──► tweet DB (Cassandra by tweet_id)
                  │
                  └─► fan-out service (async) ──► Redis ZSET per follower
                          │                       (member: tweet_id, score: ts)
                  for celebrity tweets, skip
                                    
read timeline ──► timeline service ──► Redis ZSET (top N)
                                       + pull-merge for celebrity followees
```

### Data model.

```
Cassandra:
  tweets (tweet_id PK, author, text, created_at, ...)
  follows (follower_id PK, followee_id, ...) -- partition by follower
  followers (followee_id PK, follower_id, ...) -- partition by followee

Redis:
  ZSET timeline:{user_id} → top ~800 tweet_ids by ts
```

### Storage.

- Tweets: text content small; media in object store with CDN.
- Hot timelines in Redis, evicted by LRU; rebuild from Cassandra on miss.

### Capacity (rough).

```
500 M MAU, 200 M DAU
Tweets: 500 M/day → 6 k/sec, peak 30 k/sec
Reads: 100x writes → 600 k/sec peak
Avg followers: 200 (median lower; long tail)
Fan-out work: 6 k tweets × 200 = 1.2 M writes/sec to timeline cache (with hybrid limit)
```

### Trade-offs.

- Pure push doesn't scale to celebrities (Justin Bieber problem).
- Pure pull doesn't scale to popular feeds.
- Hybrid threshold tuning is ongoing.
- Ranking (vs pure chronological) introduces ML scoring service in the read path.

---

## Design: Chat App (WhatsApp-style)

### Q35. Functional requirements.

- 1:1 messaging with delivery and read receipts.
- Group chats (small to ~256).
- Online presence.
- Message history sync across devices.
- Optional: media, voice/video calls.

### Non-functional.

- Low latency (< 200 ms for in-region).
- Reliable delivery (at-least-once with dedup).
- End-to-end encryption (Signal protocol).
- Massive scale (billions of users).

### Architecture.

```
mobile/web ── WebSocket ──► gateway tier ──► message service
                                                    │
                                          ┌─────────┼──────────┐
                                          │         │          │
                                   Cassandra    Kafka      presence service
                                  (history)  (events)      (Redis)
                                          
                                          push notifications
                                          ─► APNs / FCM (offline users)
```

- **Gateway tier** holds WebSocket connections. Stateless except for the connection itself.
- **Message service** is the source of truth: persists, delivers, acks.
- **Cassandra** stores message history keyed by (chat_id, ts).
- **Kafka** carries events to push notification, indexing, analytics.
- **Redis** holds presence (last-active timestamp, online set).

### Per-message flow.

1. Client A → gateway (WebSocket).
2. Gateway → message service.
3. Persist in Cassandra.
4. Look up chat participants; for each online participant, route to their gateway.
5. Online: gateway pushes via WebSocket.
6. Offline: enqueue push notification.
7. Client B receives, sends ack.
8. Update message status; deliver receipt to A.

### Data model (Cassandra).

```
messages_by_chat:
  PARTITION KEY: chat_id
  CLUSTERING KEY: (created_at DESC, message_id)
  columns: sender, body, status, ...
```

This gives O(1) read of recent messages in a chat.

### Group chat fan-out.

- Small group (≤ 256): server-side fan-out at message service.
- Large broadcast (channel): pull model — clients query when they open the channel.

### Scaling.

- Shard gateway tier by `user_id` for sticky session.
- Cassandra clusters per region.
- Active-active multi-region with conflict-free design (per-message UUID, server-assigned ts).

### Trade-offs.

- E2E encryption blinds the server; metadata leaks remain (who messaged whom).
- Multi-device sync requires a per-device session, not per-user.
- Read receipts add another fan-out layer.

---

## Design: News Aggregator

### Q36. Functional requirements.

- Crawl news sites and feeds.
- Deduplicate, classify by topic.
- Rank for relevance/freshness.
- Personalized feed per user.

### Architecture.

```
crawlers ─► dedup ─► NLP / classifier ─► search index (Elasticsearch)
   │                                              │
sitemap, RSS                                  user query
   │                                              │
   └────────► CDN cache for source pages          │
                                                  │
ranking service (ML) ◄────────────────────────────┘
```

### Components.

- **Crawlers** — distributed, polite (respect robots.txt and crawl-delay).
- **Dedup** — fingerprint via simhash on content; suppress near-duplicates.
- **Classifier** — NLP categorization, sentiment, entity extraction.
- **Index** — Elasticsearch with topic, time, source filters.
- **Ranker** — combines freshness, source trust, personalization signals.

### Scaling concerns.

- Crawl frontier sharded by domain; politeness per-domain.
- Article store ~10 KB × millions/day → object storage (S3) + DB index of metadata.
- Personalized ranking served per-request; precompute candidate set offline, rank online.

---

## Design: Web Crawler

### Q37. Functional requirements.

- Discover URLs, fetch pages, parse links, repeat.
- Respect robots.txt, crawl-delay, politeness.
- Detect duplicates and cycles.
- Pluggable: extract text, images, structured data.

### Components.

```
seed URLs ─► URL frontier (priority queue)
                      │
              fetcher pool (workers)
                      │
                page store + parser
                      │
              new URLs ─► URL frontier (with dedup filter)
```

### URL frontier.

- Priority queue per host (politeness).
- Round-robin across hosts at the worker level.
- Bounded queue depth per host.
- Persistent (Kafka or DB) so no work lost on restart.

### Deduplication.

- Hash of URL → Bloom filter check + persistent set.
- Content fingerprint (simhash) for near-duplicate pages.

### Storage.

- Raw HTML in object store (S3) compressed.
- Metadata in Postgres or Cassandra.
- Inverted index later (separate indexer reads from object store).

### Scaling.

- Horizontal fetcher fleet.
- DNS resolution cache (huge volume of lookups).
- Per-host concurrency cap to avoid hammering one site.
- Distributed Bloom filter or Redis sets for global dedup.

### Politeness.

- robots.txt cached per host.
- crawl-delay respected.
- Identifying User-Agent.
- Backoff on 429/5xx.

### Trade-offs.

- BFS vs priority crawl (PageRank-like) — trade between coverage and quality.
- Re-crawl frequency by page churn rate.
- Detecting traps (infinite calendar links).

---

## Design: Notification System

### Q38. Functional requirements.

- Multi-channel: push (APNs, FCM), email, SMS, in-app.
- Per-user preferences.
- Templating with variables.
- Throttling and quiet hours.

### Architecture.

```
upstream apps ─► notification API ─► Kafka (notif.requested)
                                          │
                  ┌───────────────────────┼─────────────────────┐
                  │                       │                     │
              push worker            email worker          SMS worker
                  │                       │                     │
                APNs/FCM                SES/SendGrid       Twilio
                                                              
              all workers ─► event log (delivered, failed, opened)
```

### Per-user preferences and dedup.

- Preferences DB: which channels, quiet hours, opt-outs.
- Idempotency key on each notification to prevent duplicates from retries.
- Templating engine with locale support.

### Scaling.

- Workers horizontally scaled per channel.
- External providers have own throttling — respect their rate limits.
- Retry with backoff for transient failures; dead-letter for permanent.

### Trade-offs.

- Email is high latency, batchable.
- Push and SMS are time-sensitive; deliver right away.
- Cost varies wildly per channel — prefer push and in-app where possible.

---

## Design: Rate Limiter

### Q39. Functional requirements.

- Per-user, per-endpoint, per-tenant rate limits.
- Distributed across many app servers.
- Low latency overhead (< 5 ms per check).
- Configurable strategies (token bucket, sliding window).

### Architecture.

```
client ─► gateway ──► rate limiter (Redis Lua script) ─► app
                                  │
                            allow / deny
```

### Token bucket in Redis (Lua, atomic).

```lua
local key = KEYS[1]
local rate = tonumber(ARGV[1])
local capacity = tonumber(ARGV[2])
local now = tonumber(ARGV[3])

local b = redis.call('HMGET', key, 'tokens', 'last')
local tokens = tonumber(b[1]) or capacity
local last = tonumber(b[2]) or now

local delta = math.max(0, now - last) * rate
tokens = math.min(capacity, tokens + delta)

if tokens < 1 then
  return 0
else
  tokens = tokens - 1
  redis.call('HMSET', key, 'tokens', tokens, 'last', now)
  redis.call('EXPIRE', key, 3600)
  return 1
end
```

### Trade-offs.

- Local in-memory limiter is fastest but wrong under multi-instance traffic.
- Centralized Redis is correct but adds a hop. Use a local quota cache that refreshes from Redis at intervals (token-leasing).
- Sliding window log is most accurate but memory-heavy.
- Sliding window counter is the practical compromise.

---

## Design: Distributed Cache

### Q40. Requirements.

- Low-latency get/put (< 1 ms).
- Horizontal scale.
- High availability with replication.
- Eviction policies.
- Optional: persistence.

### Architecture (Memcached / Redis Cluster style).

```
client ─► consistent hashing ─► cache nodes (sharded)
                                       │
                            replication (master ─► replicas)
```

### Key decisions.

- **Sharding:** consistent hashing with virtual nodes.
- **Replication:** primary-replica per shard; failover via sentinel/Redis Cluster gossip.
- **Eviction:** LRU as default, allkeys-lfu for stable hot sets.
- **Persistence:** Redis RDB snapshots + AOF for durability.

### Failure modes.

- Single shard outage → keys on that shard unavailable; reads fail through to origin.
- Cache stampede on cold start → preload, request coalescing.
- Hot key → replicate to multiple shards (consistent hashing with replication factor) or local L1 in app.

### Trade-offs.

- Stronger durability (AOF fsync per write) trades throughput.
- Multi-region cache: usually local-only; cross-region replication for read-only catalog data.

---

## Design: Pastebin

### Q41. Functional requirements.

- Submit text → return short URL.
- View paste at URL.
- Optional: TTL, password protection, syntax highlighting.

### Capacity.

- Light. Most pastes < 10 KB. Reads:writes ~10:1.

### Architecture.

```
POST /paste ─► API ─► object store (S3) for body
                    └─► metadata DB (Postgres): id, created_at, expires_at, owner

GET /:id ─► CDN ─► API ─► object store
```

### Storage choice.

- Bodies in S3 (cheap, scalable, integrates with CDN).
- Metadata in Postgres.

### TTL.

- `expires_at` column; lazy delete on read or scheduled job.
- S3 lifecycle policy can also delete after N days.

### Differences from URL shortener.

- Body is large → object storage rather than DB row.
- Edit/delete flows are richer.
- Syntax highlighting client-side.

---

## Design: Instagram (Image Sharing)

### Q42. Functional requirements.

- Upload photos (and reels/short videos).
- Feed of posts from followed users.
- Likes, comments, direct messages.
- Stories (24h ephemeral).

### Capacity.

```
1B+ MAU
Uploads/day:    100M photos
Reads/upload:   ~100 (feed views)
Storage/photo:  ~200 KB after compression and resizing
Daily storage:  20 TB raw + thumbnails
```

### Architecture.

```
upload ─► API ─► object store (S3) ─► transcoder (resize, format)
                       │                       │
                  metadata DB              CDN distribution
                  (Postgres / Cassandra)
                                                
feed ─► feed service (similar to Twitter feed)
likes/comments ─► counter service
DMs ─► chat service (separate)
```

### Image pipeline.

1. Client uploads original to API (or pre-signed S3 URL).
2. Async worker resizes to standard sizes (thumb, feed, full).
3. Stored in S3 with unique path; pushed to CDN.
4. Metadata (post_id, owner, captions, urls) saved to DB.

### Feed.

- Same hybrid push/pull as Twitter.
- Stories: per-user list with TTL = 24h; lazy deletion.

### Counters.

- Like and view counts: distributed counter service (sharded counters in Redis with periodic reconciliation to DB).

### CDN strategy.

- Images served from CDN with long cache TTL.
- Cache key by `post_id_size`.
- Invalidate via versioning (`/p/abc?v=2`) on edit.

### Trade-offs.

- Original vs derived storage cost — keep the original if storage is cheap; otherwise reconstruct.
- Strict ordering of likes/comments → optimistic UI with eventual server reconciliation.

---

## Design: YouTube / Netflix Streaming

### Q43. Functional requirements.

- Upload video (YouTube) or pre-encoded catalog (Netflix).
- Stream video adaptively (HLS/DASH).
- Recommendations and search.
- Playback state sync across devices.

### Pipeline.

```
upload ─► raw store ─► transcoder farm ─► encoded variants ─► origin storage
                              │            (240p,480p,720p,1080p,4K)
                              │
                           segments (~10s each, HLS chunks)
                              │
                              ▼
                            CDN edges
                              │
                              ▼
                          adaptive client
                          (selects bitrate based on bandwidth)
```

### Adaptive bitrate streaming.

- Video chopped into 2–10 second segments at multiple bitrates.
- Manifest (m3u8 / MPD) lists available variants.
- Client measures throughput, switches up/down as needed.

### Metadata storage.

- Video metadata in Cassandra (high write, simple reads by ID).
- Search index in Elasticsearch.
- Watch state per user (Redis + DB).

### Recommendations.

- Offline ML pipeline (Spark) builds candidate sets.
- Online ranker scores candidates per request.

### CDN strategy.

- Massive — most bandwidth is video. Multi-CDN often used.
- ISP peering for popular content (Netflix Open Connect appliances inside ISPs).

### Capacity (rough).

```
Netflix: ~250 M subs, 1+ hour/day average.
Daily egress: petabytes.
Storage: petabytes of video (multiple variants per title).
```

### Trade-offs.

- Live streaming (Twitch, sports) demands < 5s latency — different architecture (low-latency HLS, WebRTC).
- DRM (Widevine, FairPlay, PlayReady) adds key management complexity.
- Geo-restriction enforcement at CDN edge.

---

## Design: Uber / Lyft Ride Sharing

### Q44. Functional requirements.

- Riders request rides.
- Drivers receive nearby requests.
- Real-time location tracking.
- Surge pricing.
- Trip history, payments.

### Geo-indexing — the core problem.

How to find drivers near a rider?

| Approach | Pros | Cons |
|----------|------|------|
| Geohash | Simple string prefix index | Boundary issues |
| QuadTree | Hierarchical | Tree maintenance |
| H3 (Uber's hex grid) | Uniform cells, easy neighbor lookup | Library dependency |
| R-tree (Postgres PostGIS) | Built-in, ad-hoc queries | DB bottleneck at scale |

Uber publicly uses **H3** — a hexagonal hierarchical grid, with cells of various resolutions.

### Architecture.

```
driver app ─► WebSocket ─► location ingest ─► Redis (geo set per cell)
                                            └─► Kafka (location stream → analytics)

rider app ─► request ride ─► dispatch service
                                  │
                            query drivers in nearby H3 cells
                                  │
                            send offer to top N drivers
                                  │
                            driver accepts ─► trip starts
```

### Real-time tracking during trip.

- Driver pushes location every 4–5 seconds.
- Rider subscribes to driver's stream via WebSocket.
- Server holds the source of truth in Redis with TTL.

### Surge pricing.

- Demand/supply ratio per cell.
- Computed by a stream processor (Flink) on Kafka location streams.
- Multiplier published per cell; dispatch service applies on quote.

### Payments.

- Tokenized cards on file.
- Payment captured at trip end.
- Idempotency key per trip.

### Scaling.

- Sharding by city; few cross-shard queries.
- Reads/writes for location are extreme — Redis with sharding by H3 cell.
- Trip records in Cassandra by `trip_id`.

### Trade-offs.

- Latency vs accuracy of dispatch — dispatch needs to be fast even if not optimal.
- Pre-allocating rides to multiple drivers → race conditions, fairness.
- Network blips for drivers in poor coverage — buffer locally and replay.

---

## Design: File Storage (Dropbox / Google Drive)

### Q45. Functional requirements.

- Upload, download, share files.
- Sync across devices.
- Folder hierarchy.
- Versioning.
- Access control / sharing.

### Architecture.

```
client ─► sync agent ─► API ─► metadata DB (Postgres)
                          │
                          └─► chunk store (S3)

client ◄── notifications ◄── pub/sub when files change
```

### Chunking and dedup.

- File split into ~4 MB chunks.
- Each chunk hashed (SHA-256).
- Hash → chunk store; if hash exists, skip upload (cross-user dedup).
- File = list of chunk hashes; saves bandwidth and storage.

### Sync algorithm.

- Client tracks file metadata locally.
- On change, client computes delta, uploads only changed chunks.
- Server notifies other clients via long-poll or WebSocket.
- Conflict: dual versions saved as `file (1).docx`; resolved manually.

### Metadata model.

```
files
  file_id      UUID PK
  user_id      
  parent_id    UUID  -- folder
  name
  size
  chunk_list   JSON  -- ordered list of chunk hashes
  version
  created_at, updated_at
```

### Storage.

- Chunks in S3 / Blob storage with content-addressable naming.
- Metadata in sharded Postgres.

### Sharing and ACLs.

- Per-file ACL: owner, shared_with[], permissions.
- Group memberships expanded at access-check time.

### Scaling.

- Metadata sharded by user.
- Chunk store is essentially infinite.
- Notifications via pub/sub (Kafka or Redis).

### Trade-offs.

- Dedup leaks information (hash equality reveals same content) — disabled in some privacy-conscious deployments.
- Versioning storage cost — keep recent N versions or last 30 days.
- Offline conflict resolution is hard; CRDT for collaborative real-time edit (Google Docs).

---

## Design: Search Autocomplete

### Q46. Functional requirements.

- Suggest top N completions for a prefix.
- Ranked by popularity / personalization.
- Fast (< 100 ms).
- Update with new search trends.

### Architecture.

```
search frontend ─► autocomplete API ─► trie service (in-memory)
                                          │
                                  popularity scores from
                                  search log aggregation (Spark/Flink)
```

### Data structure.

- **Trie / prefix tree** stores all queries; each node holds top N completions for that prefix (precomputed).
- Memory-friendly compression: use serialized arrays at each prefix node.
- Update via daily/hourly batch from search logs.

### Ranking.

- Frequency × recency.
- Personalization: blend per-user history (lower weight) with global.

### Scaling.

- Shard trie by prefix range across servers.
- Consistent hashing on prefix.
- Replicate read-only.

### Caveats.

- Misspellings → fuzzy match (edit distance, but expensive).
- Trending queries → prioritize recent spikes (sliding window).
- Profanity/spam filter.

---

## Design: Distributed Counter

### Q47. Functional requirements.

- Increment a counter at very high rate (likes, view counts).
- Read the count, possibly slightly stale.
- Per-resource counters (counts for each post).

### Naïve approach and why it fails.

```sql
UPDATE posts SET likes = likes + 1 WHERE id = ?
```

Hot row contention. Single-row writes serialize. Throughput is limited.

### Sharded counter.

Split each counter into N shards. To increment, pick a random shard. To read, sum all shards.

```
counter:post:42:shard:0 = 100
counter:post:42:shard:1 = 102
counter:post:42:shard:2 =  98
                          ----
                  total = 300
```

- Increment scales to N×.
- Read scales down — sum is more work.

### Eventual consistency variant.

- Increment in Redis (`INCR`) — fast.
- Periodically flush to DB (every minute).
- Read from Redis for fresh, fall back to DB for resilience.

### CRDT counter (for multi-region).

- G-Counter (grow-only) — each replica increments locally; merge by per-replica max.
- PN-Counter — supports decrement (G-Counter for inc, another for dec).
- Used in Riak, Cassandra (counters).

### Trade-offs.

- Strong consistency requires single-row write or quorum + locks → slow.
- Approximate count (HyperLogLog) for unique counts — ~1% error, tiny memory.

---

## Design: Job Scheduler at Scale

### Q48. Functional requirements.

- Schedule jobs at specific times (cron-style).
- Schedule one-off "delayed" jobs (run at T).
- Reliable execution (at-least-once).
- Distributed — millions of jobs.
- Cancel / reschedule.

### Architecture.

```
client ─► API ─► job DB (Postgres / DynamoDB)
                       │
              indexed by next_run_at
                       │
              poller(s) ─► claim due jobs (lease)
                       │
              ┌────────┴────────┐
              │                 │
        executor pool       Kafka (job.due)
                                  │
                            consumer apps (the job runs)
```

### Storage and indexing.

```
jobs
  id         UUID
  payload    JSONB
  schedule   cron-string OR run_at TIMESTAMPTZ
  status     PENDING | RUNNING | DONE | FAILED
  next_run_at TIMESTAMPTZ INDEXED
  lease_until TIMESTAMPTZ
  attempts   INT
```

Index on `(status, next_run_at)` lets pollers efficiently `WHERE status='PENDING' AND next_run_at <= NOW()`.

### Claiming jobs.

- Pollers `SELECT ... FOR UPDATE SKIP LOCKED` (Postgres) to claim.
- Or use a lease pattern: set `lease_until=now+30s` atomically.
- If executor crashes, lease expires and another picks up.

### Reliable execution.

- At-least-once. Worker must be idempotent.
- Mark `DONE` after success.
- On failure, increment `attempts`, exponential backoff next_run_at; after N attempts → dead-letter.

### Scaling.

- Shard jobs by hash(job_id) or by tenant.
- Many pollers → less individual load, but contention on hot row range.
- For hyper-scale: Hierarchical Timing Wheels in memory + persistent backing store (used at LinkedIn, Airbnb's Chronos, similar to Quartz).

### Cron jobs.

- After running, compute next_run_at from cron expression and re-insert.
- One scheduler instance must be the canonical "cron evaluator" — leader election ensures single source of truth.

### Trade-offs.

- Polling vs push (timing wheel) — polling is simpler, adds latency floor (poll interval).
- DB as scheduler vs dedicated scheduler — DB is fine to ~100k jobs/min; beyond that, dedicated systems.
- Exactly-once execution requires idempotent job handlers regardless.

---

### Q49. Final senior-level rules of thumb.

- Always start with requirements; don't draw before you understand.
- State assumptions out loud.
- Use ASCII or simple boxes for diagrams; speak the data flow.
- Pick a small number of components and explain why.
- Numbers matter — back-of-envelope estimates earn credibility.
- Discuss bottlenecks before the interviewer asks.
- Always identify the read vs write ratio early — it shapes everything.
- Cache aggressively but invalidate carefully.
- Embrace eventual consistency where the user can't tell.
- Know which DB models which workload (RDBMS, KV, doc, columnar, search, time-series, graph).
- Idempotency is non-negotiable in distributed systems.
- Multi-region is harder than it sounds — only design for it if asked.
- Show trade-offs you considered and why you chose your direction.
- "It depends" is not a cop-out if you immediately follow with the dimensions it depends on.
