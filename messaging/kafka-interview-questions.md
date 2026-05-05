# Apache Kafka Interview Questions — Basic to Advanced

**Purpose:** Senior-level coverage of Kafka for backend interviews. Covers the log abstraction, partitions, replication, delivery semantics, the Kafka ecosystem (Streams, Connect, Schema Registry), and operational pitfalls.

---

## Table of Contents

1. [Fundamentals](#fundamentals)
2. [Architecture and Components](#architecture-and-components)
3. [Topics, Partitions, Offsets](#topics-partitions-offsets)
4. [Producers — Internals and Tuning](#producers--internals-and-tuning)
5. [Consumers and Consumer Groups](#consumers-and-consumer-groups)
6. [Replication, ISR, Leader Election](#replication-isr-leader-election)
7. [Delivery Semantics](#delivery-semantics)
8. [Idempotence and Transactions](#idempotence-and-transactions)
9. [Retention and Log Compaction](#retention-and-log-compaction)
10. [ZooKeeper vs KRaft](#zookeeper-vs-kraft)
11. [Kafka Ecosystem](#kafka-ecosystem)
12. [Schema Registry](#schema-registry)
13. [Performance Tuning](#performance-tuning)
14. [Monitoring and Operations](#monitoring-and-operations)
15. [Common Patterns](#common-patterns)
16. [Kafka vs Other Brokers](#kafka-vs-other-brokers)
17. [Common Pitfalls](#common-pitfalls)

---

## Fundamentals

### Q1. What is Kafka?

**Answer:** A distributed, partitioned, replicated commit log. Producers append records to the end of partitions; consumers read sequentially by offset. Records are retained based on time/size policies, not on consumption. Consumers can rewind and replay. The "broker" is intentionally dumb: it stores and serves bytes; clients track their own offsets.

The mental model is "a sharded, replicated, durable log file" rather than "a queue."

---

### Q2. How is Kafka different from a traditional queue?

| Property | Queue (RabbitMQ, SQS) | Kafka |
|----------|----------------------|-------|
| Read = consume | Yes — message is removed | No — offset is advanced |
| Replay | No (unless re-published) | Yes — rewind by offset |
| Multiple independent consumers | Each gets a queue or copy | Each consumer group has its own offsets |
| Routing | Rich (exchanges, bindings) | Topic + partition only |
| Per-message ack | Yes | No (offset commit instead) |
| Ordering | Per-queue | Per-partition |
| Retention | Until consumed | Time/size based |

Kafka is a **log**, not a queue. Use it where replay, multi-consumer fan-out, or stream processing matters.

---

### Q3. What guarantees does Kafka provide out of the box?

- **Order within a partition** — strict.
- **Order across partitions** — none.
- **At-least-once delivery** — by default; producers retry, consumers may reprocess.
- **Durability** — replicated and persisted to disk before ack (with `acks=all`).
- **High throughput** — millions of msg/sec on commodity hardware.

---

## Architecture and Components

### Q4. Describe the core architecture.

```
                    ┌────────────┐
producers ────────► │            │
                    │  brokers   │ ──── replicates partitions among themselves
consumers ──────►   │  (cluster) │
                    └────────────┘
                          │
                  metadata coordination
                          │
                  ┌───────┴───────┐
                  │ ZooKeeper or  │
                  │   KRaft       │
                  └───────────────┘
```

| Component | Role |
|-----------|------|
| Broker | A Kafka server, stores partitions |
| Topic | Logical name for a stream of records |
| Partition | An append-only ordered log; the unit of parallelism |
| Offset | Sequential ID of a record within a partition |
| Replica | Copy of a partition on another broker |
| Leader | The replica that handles all reads/writes for a partition |
| Follower | Replica that copies the leader |
| ISR | In-Sync Replica set |
| Producer | Writes records to topics |
| Consumer | Reads records from topics |
| Consumer group | A set of consumers cooperatively consuming a topic |
| Controller | Broker responsible for partition leadership decisions |
| ZooKeeper / KRaft | Cluster metadata coordination |

---

### Q5. What is a Kafka record made of?

```
{
  key:        bytes (optional)
  value:      bytes
  timestamp:  long (event-time or log-append time)
  headers:    list of (key, bytes) pairs
  partition:  int
  offset:     long (assigned by broker)
}
```

The key is critical: it determines partition assignment by default (`hash(key) % numPartitions`).

---

## Topics, Partitions, Offsets

### Q6. What is a partition?

**Answer:** An append-only, ordered log file. A topic has N partitions. Partitions are the unit of:

- **Parallelism** — one consumer in a group reads each partition.
- **Ordering** — order is guaranteed only within a partition.
- **Retention** — log segments roll per-partition.
- **Replication** — each partition has its own replica set.

More partitions → higher parallelism but more files, more leader elections, higher metadata cost. Typical: 10–100 per topic.

---

### Q7. How is a record placed in a partition?

The producer chooses a partition by:

1. **Explicit partition** — `producer.send(new ProducerRecord(topic, partition, key, value))`.
2. **Hash of key** — `partition = hash(key) % numPartitions` (default sticky/murmur2).
3. **Round robin** — when key is null and no partition specified.

Same key → same partition → ordered within that key. This is the foundation of "ordered processing per entity" (per-user, per-account).

---

### Q8. What is an offset?

**Answer:** The monotonically increasing position of a record within a partition. Offsets are partition-local. The consumer commits offsets back to Kafka (or to an external store) as it processes records, so on restart it knows where to resume.

---

### Q9. How do you choose the number of partitions?

Trade-offs:

- **Too few:** caps throughput, limits consumer parallelism.
- **Too many:** more file handles, more leader election overhead, longer recovery on broker restart, slower controller failover.

Rules of thumb:

- Estimate target throughput per partition (often 10 MB/s).
- Plan for future growth — adding partitions doesn't redistribute existing data, and breaks key→partition stability.
- Start with `max(consumer_count, target_throughput / per_partition_throughput)`.
- For most topics 6–24 is plenty. >1000 partitions per cluster is a smell.

---

### Q10. Can you reduce the number of partitions?

**Answer:** No. You can only add. Reducing requires creating a new topic and replaying.

---

### Q11. What happens to ordering when adding partitions?

**Answer:** Existing records stay where they are, but new records hashed to the same key may go to a different partition than before. Ordering by key is broken across the boundary. Plan capacity ahead of time or use a custom partitioner that preserves stability for important keys.

---

## Producers — Internals and Tuning

### Q12. How does the producer work internally?

```
app ──► send() ──► RecordAccumulator (per-partition buffer)
                          │
                  Sender thread
                          │
                          ▼
                  batch ──► broker (leader of partition)
                          │
                          ▼
                  ack ──► future complete
```

`send()` is asynchronous — it returns a `Future`. Records sit in a buffer until either the batch is full (`batch.size`) or `linger.ms` elapses, then the Sender thread flushes.

---

### Q13. Key producer configs to know.

| Config | Effect |
|--------|--------|
| `acks` | 0/1/all — durability vs latency |
| `retries` | Auto-retry on retryable errors |
| `enable.idempotence` | Dedup at the broker per producer/partition |
| `max.in.flight.requests.per.connection` | Concurrency to one broker |
| `batch.size` | Bytes per batch |
| `linger.ms` | Wait time to fill batch |
| `compression.type` | `none`, `gzip`, `snappy`, `lz4`, `zstd` |
| `buffer.memory` | Producer-side buffer size |
| `delivery.timeout.ms` | Total time to give up on a send |
| `transactional.id` | Enables transactions |

---

### Q14. What does `acks` control?

| Value | Meaning |
|-------|---------|
| `acks=0` | Fire and forget. No ack from broker. Lossy. |
| `acks=1` | Leader has written it. Lost if leader fails before replication. |
| `acks=all` (or `-1`) | All in-sync replicas have it. Combined with `min.insync.replicas`, durable. |

For business data: `acks=all` and `min.insync.replicas=2` on RF=3.

---

### Q15. What does `linger.ms` do?

**Answer:** Delays a partial batch for a few milliseconds so it can fill up. A 5–20 ms `linger.ms` typically increases throughput dramatically with negligible latency cost. Without it, every `send()` flushes immediately when not under load.

---

### Q16. What does `max.in.flight.requests.per.connection` mean?

**Answer:** How many unacked batches can be in-flight to one broker. Higher → more throughput. Lower → tighter ordering guarantees on retries. With `enable.idempotence=true` (recommended), you can have up to 5 in-flight without breaking ordering. Without idempotence and `>1` in-flight, a retry can re-order records.

---

## Consumers and Consumer Groups

### Q17. What is a consumer group?

**Answer:** A set of consumers cooperatively consuming a topic. Kafka assigns each partition to exactly one consumer in the group. Adding consumers up to the partition count parallelizes consumption; beyond that, additional consumers sit idle.

```
topic with 4 partitions

Group A: 2 consumers → each gets 2 partitions
Group A: 4 consumers → each gets 1 partition
Group A: 6 consumers → 4 work, 2 idle

Group B (independent) → has its own offsets, full copy
```

Two different groups on the same topic each see every record.

---

### Q18. What is rebalancing?

**Answer:** Reassigning partitions when group membership changes (consumer joins/leaves/crashes) or topic metadata changes (partitions added). The default rebalance is **stop-the-world** — all consumers in the group pause briefly. **Cooperative rebalancing** (incremental) is recommended for large groups (`partition.assignment.strategy=CooperativeStickyAssignor`).

Causes of rebalance churn:

- `session.timeout.ms` too low.
- Long GC pauses.
- Consumer takes longer than `max.poll.interval.ms` to process a batch.
- Frequent restarts.

---

### Q19. What is offset commit and what are the modes?

**Answer:** The consumer tells Kafka "I have processed up to offset X." On restart, the consumer resumes from the committed offset.

| Mode | Description |
|------|-------------|
| Auto-commit (`enable.auto.commit=true`) | Offset committed periodically (`auto.commit.interval.ms`). Risk: commit before processing → loss; or commit after processing crashes. |
| Manual sync (`commitSync`) | Block until commit succeeds. Safer. |
| Manual async (`commitAsync`) | Higher throughput, no retries by default. |
| External store | Commit offsets to your own DB transaction together with side effects — exactly-once locally. |

---

### Q20. What is `auto.offset.reset`?

**Answer:** What to do when no committed offset exists or the offset is out of range:

- `latest` — start from the end (skip backlog).
- `earliest` — start from the beginning (replay everything).
- `none` — throw, force the operator to decide.

---

### Q21. What is `max.poll.interval.ms` and why does it matter?

**Answer:** Maximum time between `poll()` calls. If you take longer (e.g., a slow batch processing loop), Kafka assumes the consumer is dead and triggers a rebalance, which removes you from the group. After rebalance, your offset commit fails and you may reprocess the batch. Tune it to be larger than your worst-case batch processing time.

---

### Q22. Can two consumers in the same group read the same partition?

**Answer:** No. Within one group, each partition is assigned to exactly one consumer. Two different groups can each have a consumer reading the same partition independently.

---

### Q23. How do you achieve consumer parallelism greater than partition count?

**Answer:** You can't, within a single group. Workarounds:

- Increase partitions on the topic.
- Use a "scatter" pattern — consumer reads, dispatches work to a thread pool, then commits offsets only after all dispatched work completes. (Carefully — risks losing messages on crash.)
- Use Kafka Streams which supports parallel processing inside a single application instance.

---

## Replication, ISR, Leader Election

### Q24. What is replication factor?

**Answer:** Number of copies (including the leader) of each partition. RF=3 means one leader and two followers. Configure per-topic. Cluster default `default.replication.factor` and `min.insync.replicas`.

---

### Q25. What is the ISR?

**Answer:** In-Sync Replica set — replicas that are caught up to the leader within `replica.lag.time.max.ms`. The leader is always in the ISR. With `acks=all` and `min.insync.replicas=2`, a write requires 2 ISR members to acknowledge before returning success.

---

### Q26. What happens when a leader fails?

**Answer:**

1. The controller detects the failure (via heartbeat to ZK/KRaft).
2. The controller picks a new leader from the ISR (preferring the "preferred replica" if it's in-sync).
3. Producers and consumers refresh metadata and retry against the new leader.
4. The failed broker, when it returns, becomes a follower and catches up.

**If the ISR is empty** and `unclean.leader.election.enable=true`, an out-of-sync replica may be elected — risking data loss but preserving availability. Default is `false` (CP behavior).

---

### Q27. What is the controller?

**Answer:** A specially-designated broker responsible for cluster-wide decisions: leader elections, partition reassignment, broker membership. With ZooKeeper, exactly one controller exists at a time. With KRaft, there's a quorum of controllers using Raft.

---

### Q28. What's the difference between sync and async replication?

**Answer:** Kafka does sync replication: a write is acknowledged only after followers in the ISR have it (when `acks=all`). There's no "async replica" tier in Kafka. Cross-DC mirroring via MirrorMaker 2 is async, but that's a separate cluster-to-cluster topology.

---

## Delivery Semantics

### Q29. Define at-most-once, at-least-once, exactly-once.

| Semantic | Description | Default in Kafka? |
|----------|-------------|--------------------|
| At-most-once | May lose, never duplicates | If you commit offset before processing |
| At-least-once | May duplicate, never loses | Default |
| Exactly-once | Never lose, never duplicate | With idempotent producer + transactions or with consume-process-produce in a transaction |

---

### Q30. Why is exactly-once hard?

**Answer:** "Process the side effect once" requires atomicity between consuming, processing, producing, and committing offsets. Kafka can guarantee exactly-once **within Kafka** (read from topic A, write to topic B, commit offset, all atomically), but if your side effect is a non-Kafka system (DB, external API), you need additional mechanisms (transactional outbox, idempotency keys).

---

### Q31. How does Kafka achieve exactly-once for a Kafka→Kafka pipeline?

1. **Idempotent producer** — broker dedups by `(producerId, sequenceNumber, partition)`.
2. **Transactions** — group produce-and-commit-offsets into one atomic unit.
3. **Read-committed consumer** — `isolation.level=read_committed` skips aborted records.

```java
producer.initTransactions();
producer.beginTransaction();
producer.send(record1);
producer.send(record2);
producer.sendOffsetsToTransaction(offsets, consumerGroupMetadata);
producer.commitTransaction(); // or abortTransaction()
```

---

## Idempotence and Transactions

### Q32. What does the idempotent producer do?

**Answer:** With `enable.idempotence=true`:

- The producer is assigned a unique producer ID by the broker.
- Each message gets a sequence number per (producer, partition).
- The broker rejects duplicates with the same `(producerId, partition, sequence)`.
- Eliminates duplicates from producer retries (network blips).

It does **not** cover application-level retries (calling `send()` twice from your code). Always pair it with idempotent consumers or transactional sends.

---

### Q33. What's the cost of transactions?

- Higher latency (2-phase commit-style protocol with the transaction coordinator).
- Lower throughput than non-transactional sends.
- More moving parts, more failure modes.

Use transactions for stream processing pipelines that require exactly-once semantics. For most application-level Kafka use, idempotent producer + idempotent consumer (with dedup keys) is enough.

---

## Retention and Log Compaction

### Q34. How does retention work?

Two policies, configurable per topic:

| Setting | Default | Meaning |
|---------|---------|---------|
| `retention.ms` | 7 days | Delete records older than this |
| `retention.bytes` | -1 | Delete oldest segments past this size |
| `cleanup.policy` | `delete` | Delete-based or compact |

Kafka deletes by **segment**, not by record. A segment is a chunk of the log (~1 GB by default). When the entire segment is past retention, it's deleted.

---

### Q35. What is log compaction?

**Answer:** With `cleanup.policy=compact`, Kafka retains at least the most recent value for each key. Older values are eventually removed by the log cleaner. Tombstones (null value) are used to delete a key.

Use cases:

- Materialized state stream (latest user profile per `user_id`).
- Change data capture (latest row state).
- Configuration topics (latest config per key).

The log is "infinite" but bounded — retains one record per unique key.

```
before compaction:  k1=A, k2=X, k1=B, k3=Y, k1=C, k2=Z
after compaction:   k3=Y, k1=C, k2=Z   (latest per key)
```

---

### Q36. Can you mix delete and compact?

**Answer:** Yes — `cleanup.policy=compact,delete`. Compact keeps latest per key, delete still drops segments older than retention. Common for "keep latest, but never older than 30 days" semantics.

---

## ZooKeeper vs KRaft

### Q37. What was ZooKeeper used for in Kafka?

- Cluster membership.
- Controller election.
- Topic metadata (partitions, configs, ACLs).
- Consumer group offsets (until 0.9, now stored in `__consumer_offsets`).

---

### Q38. What is KRaft?

**Answer:** Kafka Raft mode — replaces ZooKeeper with a built-in Raft quorum of controller nodes. Available in 2.8 (preview), production-ready in 3.3, **default in 4.0**, and ZooKeeper is removed.

Benefits:

- Fewer moving parts (one system instead of two).
- Faster controller failover.
- Better metadata scalability — millions of partitions feasible.
- Simpler operations.

---

### Q39. How do you migrate from ZooKeeper to KRaft?

The Kafka project provides a controlled migration:

1. Upgrade brokers to a KRaft-capable version with ZK still in place.
2. Stand up KRaft controller quorum.
3. Run brokers in "migration mode" — both ZK and KRaft.
4. Migrate metadata.
5. Switch brokers to KRaft mode.
6. Decommission ZooKeeper.

Test in non-prod first; the steps are version-specific.

---

## Kafka Ecosystem

### Q40. What is Kafka Connect?

**Answer:** A framework for streaming data between Kafka and external systems (databases, S3, Elasticsearch, JDBC, MongoDB, etc.) using **connectors**.

- **Source connector** — reads from external system, writes to Kafka.
- **Sink connector** — reads from Kafka, writes to external system.

Distributed mode runs connectors as a fault-tolerant cluster. Standalone mode is a single process.

Common connectors: Debezium (CDC), JDBC source/sink, S3 sink, Elasticsearch sink.

---

### Q41. What is Kafka Streams?

**Answer:** A Java library for building stream processing applications on top of Kafka. Concepts:

- **KStream** — stream of records.
- **KTable** — change-log stream materialized as a table.
- **Stateful operations** — joins, aggregations, windows backed by RocksDB and a changelog topic.
- **Exactly-once processing** — via transactions.

It runs as a library inside your application (no separate cluster, unlike Flink/Spark).

```java
KStream<String, Order> orders = builder.stream("orders");
orders.filter((k, v) -> v.amount > 100)
      .mapValues(o -> enrich(o))
      .to("high-value-orders");
```

---

### Q42. What is ksqlDB?

**Answer:** A SQL layer over Kafka Streams. You write SQL against streams and tables; ksqlDB compiles to Streams topology and runs it.

```sql
CREATE STREAM high_value AS
SELECT * FROM orders WHERE amount > 100;

CREATE TABLE order_count_per_user AS
SELECT user_id, COUNT(*) FROM orders GROUP BY user_id;
```

Useful for analysts and quick prototyping; for complex pipelines, Kafka Streams (Java/Scala) gives more control.

---

### Q43. What is MirrorMaker 2?

**Answer:** A Kafka Connect-based tool to replicate topics between Kafka clusters (cross-DC, cluster migration, DR). MM2 supports topic renaming, offset translation between clusters, and ACL replication. Useful for active/passive DR or geo-distributed clusters.

---

## Schema Registry

### Q44. Why use a schema registry?

**Answer:** Kafka stores raw bytes. Without a schema mechanism, every consumer must know the format and handle changes. A schema registry stores schemas (Avro, Protobuf, JSON Schema) by ID and:

- Enforces compatibility (BACKWARD, FORWARD, FULL, NONE).
- Lets producers serialize using a schema and embed the schema ID in the record.
- Lets consumers deserialize by fetching the schema by ID.

Without it, schema evolution becomes a coordination disaster across teams.

---

### Q45. What are the compatibility modes?

| Mode | Reader (new schema) can read records written with old | Writer (new) compatible with old reader |
|------|--------------------------------------------------------|------------------------------------------|
| BACKWARD | Yes | No |
| FORWARD | No | Yes |
| FULL | Yes | Yes |
| NONE | Anything goes | — |

**BACKWARD** is the most common — consumers can be upgraded after producers. Allowed changes: add optional fields, remove fields with defaults.

---

### Q46. Avro vs Protobuf vs JSON Schema?

| Aspect | Avro | Protobuf | JSON Schema |
|--------|------|----------|-------------|
| Encoding | Compact binary | Compact binary | Verbose text |
| Schema stored with data | Schema ID, schema in registry | Schema ID, schema in registry | Schema ID, schema in registry |
| Cross-language | Excellent | Excellent | Excellent |
| Default tooling | Confluent native | Widespread | Easiest to debug |
| Schema evolution | Strong | Strong | Strong |
| Best for | Analytics, big data | Service-to-service typed APIs | Human-readable, debugging |

Avro is the historical default in the Kafka ecosystem; Protobuf is gaining ground.

---

## Performance Tuning

### Q47. How does Kafka achieve such high throughput?

- **Sequential disk I/O** — append-only log; OS page cache and disk are very fast for sequential writes.
- **Zero-copy** — `sendfile()` skips userspace when serving consumers.
- **Batching** — producers batch, brokers batch, consumers batch.
- **Compression** — applied to whole batches, very effective.
- **Partition parallelism** — per-partition disk and network I/O.
- **No per-message ack overhead** — offset-based.

---

### Q48. Producer tuning checklist.

| Tuning | Effect |
|--------|--------|
| `linger.ms=10–20` | Better batching |
| `batch.size=64KB–1MB` | Larger batches |
| `compression.type=zstd` or `lz4` | Smaller payloads, faster decompression than gzip |
| `enable.idempotence=true` | Safer retries, no real cost |
| `acks=all` + `min.insync.replicas=2` | Durability |
| `buffer.memory` sized for your throughput | Avoid back-pressure |
| Reuse one producer instance per app | Producer is thread-safe |

---

### Q49. Consumer tuning checklist.

| Tuning | Effect |
|--------|--------|
| `fetch.min.bytes` | Fewer, fatter fetches |
| `fetch.max.wait.ms` | How long broker waits to fill fetch.min.bytes |
| `max.poll.records` | Batch size per poll |
| `max.poll.interval.ms` | Long enough to handle worst-case batch |
| `session.timeout.ms` | Long enough for GC and slow heartbeats |
| Process records in parallel within poll loop | Throughput per consumer |
| Commit offsets in batches, not per-record | Less coordinator load |

---

### Q50. Broker-side tuning.

- Use multiple disks (`log.dirs=/data1,/data2,...`) — Kafka spreads partitions across disks.
- `num.io.threads`, `num.network.threads` sized to cores.
- `log.segment.bytes` and `log.segment.ms` — segment rolls determine retention granularity.
- File system: XFS or ext4. Avoid network-attached storage with high latency.
- Page cache > heap — keep heap modest (6 GB), let OS use the rest as page cache.

---

## Monitoring and Operations

### Q51. What metrics matter?

| Metric | Why |
|--------|-----|
| Consumer lag (per group/partition) | Are consumers keeping up? |
| Under-replicated partitions | Replication health |
| ISR shrinks / expands | Cluster instability |
| Request latency (p99 produce/fetch) | SLO |
| Bytes in / bytes out per broker | Capacity |
| Active controller count (should be 1) | Controller stability |
| Offline partitions | Critical — data unavailable |
| Disk usage per broker | Capacity planning |
| Log flush latency | Disk health |
| Network throughput per broker | Hot brokers |

Tooling: JMX → Prometheus → Grafana. Confluent Control Center, Burrow (lag), Cruise Control (rebalancing).

---

### Q52. What does "consumer lag" mean and how do you reduce it?

**Answer:** Lag = (latest offset in partition) − (consumer's committed offset). High lag = consumer can't keep up.

Mitigations:

- More consumer instances (up to partition count).
- More partitions (if hot single partition is the bottleneck).
- Faster per-record processing (parallelize downstream calls, reduce DB round-trips).
- Larger fetch batches.
- Offload heavy work to async pools, but be careful not to break offset semantics.
- Bypass slow consumers entirely with a separate "fast lane" topic if a tier needs lower latency.

---

### Q53. What are ISR shrinks and why are they bad?

**Answer:** A follower falls behind by more than `replica.lag.time.max.ms` and leaves the ISR. If too many shrink, you may have:

- A slow disk.
- Broker GC pauses.
- Network saturation.
- Hot leader partition.

Frequent shrinks weaken durability — `acks=all` waits for fewer replicas.

---

### Q54. What's a typical production cluster topology?

```
3 or 5 brokers, RF=3, min.insync.replicas=2
KRaft controller quorum: 3 (separate from data brokers in large clusters)
Schema Registry: 2+ instances, Kafka-backed
Kafka Connect: 3+ workers in distributed mode
MirrorMaker 2: across regions for DR
Monitoring: JMX → Prometheus → Grafana
```

Co-locating brokers and ZK on the same hosts is a smell — they compete for I/O.

---

## Common Patterns

### Q55. Event sourcing with Kafka.

Each domain event is a record on a topic. The current state is a projection built by replaying events. Use compaction for "latest state per entity" topics.

Pros: full audit trail, time travel, easy projections. Cons: requires careful schema evolution, cannot easily delete a single event (needs tombstone + compaction or a "redaction" event).

---

### Q56. Change Data Capture (CDC).

Use Debezium (a Kafka Connect source) to stream every row change from a database transaction log to Kafka. Downstream consumers project this into search indices, caches, analytics.

```
Postgres WAL → Debezium → Kafka topic (per table) → consumers
```

This decouples the operational DB from the read side.

---

### Q57. Outbox pattern.

To publish events atomically with a DB write:

1. App writes the event to an `outbox` table in the same DB transaction as the business write.
2. Debezium tails the WAL and emits the outbox row to Kafka.
3. The outbox row may be deleted asynchronously.

Solves the dual-write problem (DB write + Kafka publish) without distributed transactions.

---

### Q58. Stream-table join.

```
KTable: customers (compacted, keyed by customer_id)
KStream: orders (keyed by customer_id)

orders.join(customers) → enriched orders stream
```

The KTable is materialized in RocksDB on each Streams instance; the join is a local lookup.

---

### Q59. Log aggregation.

Apps write logs to Kafka via Filebeat/Fluentd. Connect sinks them to Elasticsearch / S3 / a data lake. Single pipeline, multiple destinations, replayable.

---

### Q60. Notification system.

Producer publishes notification events. Multiple consumer groups: email service, push service, SMS service, in-app feed. Each gets the full stream independently. Adding a new channel = adding a consumer group, not modifying producers.

---

## Kafka vs Other Brokers

### Q61. Kafka vs RabbitMQ — which to use?

| Workload | Pick |
|----------|------|
| Replay events from any point | Kafka |
| Complex routing rules | RabbitMQ |
| Per-message acks/priorities | RabbitMQ |
| Millions of msg/sec | Kafka |
| Sub-millisecond latency | RabbitMQ |
| Stream processing | Kafka |
| Task queue / RPC | RabbitMQ |
| Long retention with cheap replay | Kafka |
| Few topics, many bindings | RabbitMQ |
| Many consumers fan-out | Kafka |

Many large systems run **both** — RabbitMQ for tasks, Kafka for events.

---

### Q62. Kafka vs Pulsar?

Pulsar separates compute (brokers) from storage (BookKeeper bookies), enabling tiered storage and easier scaling. It supports queue and stream models in one system.

Kafka has a larger ecosystem and is operationally more familiar. Pulsar shines in multi-tenant SaaS or where tiered storage to S3 is critical, though Kafka now supports tiered storage too (KIP-405).

---

### Q63. Kafka vs SQS / Kinesis?

| Aspect | Kafka | Kinesis | SQS |
|--------|-------|---------|-----|
| Hosted | Self or MSK / Confluent Cloud | AWS managed | AWS managed |
| Replay | Yes | Yes (24h–365d) | No |
| Throughput | Highest | High (per-shard limits) | Effectively unlimited |
| Ordering | Per partition | Per shard | FIFO queues only |
| Cost model | Server cost | Per shard-hour | Per request |
| Best for | Self-managed throughput | AWS-native streaming | Simple managed queues |

---

## Common Pitfalls

### Q64. "All my keys go to one partition" — why?

Common causes:

- Keys are not actually unique (e.g., all events have `key=null` or `key="default"`).
- Custom partitioner with a bug.
- Skewed distribution (one user generates 90% of events).

Fix:

- Compose richer keys.
- Use a custom partitioner that hashes evenly.
- Salt hot keys (suffix `:0..N`) and re-key downstream.

---

### Q65. "Consumer rebalances constantly" — why?

- `session.timeout.ms` < `heartbeat.interval.ms` × 3, or too low for GC pauses.
- `max.poll.interval.ms` shorter than worst-case processing time.
- Consumers crashing/restarting frequently.
- Auto-scaling group churning.

Switch to **cooperative rebalancing** to reduce stop-the-world impact.

---

### Q66. "Messages are lost" — what's likely?

- `acks=1` and leader failed.
- `unclean.leader.election.enable=true`.
- Consumer auto-commits offsets before processing finishes.
- Retention purges before consumer reads (lag exceeded retention).
- `min.insync.replicas` not configured; one replica is enough to ack.

---

### Q67. "Messages are duplicated" — what's likely?

- Producer retries without idempotence.
- Consumer crashes after processing but before commit.
- Rebalance happens in the middle of a batch.

Default Kafka is at-least-once. Make consumers idempotent.

---

### Q68. "Topic creation works in test, fails in prod" — why?

- `auto.create.topics.enable=false` in prod (best practice).
- ACLs prevent topic creation.
- Replication factor exceeds available brokers.

In production, manage topics declaratively (Terraform, kafka-topics CLI in CI). Don't auto-create.

---

### Q69. How do you handle schema-breaking changes safely?

1. Configure registry compatibility to BACKWARD (or FULL).
2. Make additive changes — add optional fields with defaults.
3. Deploy consumers first (they tolerate the new schema).
4. Then deploy producers using the new schema.
5. For breaking changes: dual-write to a new topic, migrate consumers, retire old topic.

---

### Q70. When NOT to use Kafka?

- Small workloads where SQS/RabbitMQ would do — Kafka adds operational weight.
- True request/response RPC — gRPC is the right tool.
- Strict per-message latency below 1 ms — RabbitMQ or in-memory queues are better.
- Workloads needing per-message TTL, priority, or per-message ack — Kafka has none of these.
- Tiny payloads at low rate — overkill.

---

### Q71. Senior-level rules of thumb.

- Kafka is a log, not a queue — treat it as one.
- Pick partition count thoughtfully; you can only go up.
- `acks=all`, `min.insync.replicas=2`, `enable.idempotence=true` for any data you care about.
- Default to at-least-once with idempotent consumers; use transactions only when truly needed.
- One producer instance per app — they're thread-safe.
- Compact topics for "latest state per key" use cases.
- Schema registry is non-negotiable at scale.
- Monitor consumer lag, ISR, and offline partitions above all.
- Avoid `unclean.leader.election.enable=true` unless you understand the data-loss trade-off.
- KRaft is the future — plan ZK migrations now.
